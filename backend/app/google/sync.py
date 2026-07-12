from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.google.mime_parser import parse_gmail_message
from app.models import EmailMessage, GoogleCredential, GoogleSyncState


@dataclass(frozen=True)
class SyncCounts:
    added: int = 0
    updated: int = 0
    deleted: int = 0


class GoogleSyncCoordinator:
    def __init__(self, gmail_provider) -> None:
        self.gmail = gmail_provider

    def sync_gmail(self, session: Session) -> SyncCounts:
        state = session.get(GoogleSyncState, 1)
        if state is None:
            state = GoogleSyncState(id=1, status="never")
            session.add(state)
        credential = session.scalar(select(GoogleCredential).limit(1))
        cursor = credential.gmail_history_id if credential else state.gmail_history_id
        try:
            if cursor:
                history = self.gmail.list_history(cursor)
                message_ids, deleted_ids, next_cursor = history.message_ids, history.deleted_ids, history.history_id
            else:
                message_ids, deleted_ids, next_cursor = self.gmail.list_recent(), [], cursor
            added = updated = 0
            for message_id in dict.fromkeys(message_ids):
                normalized = parse_gmail_message(self.gmail.get_message(message_id))
                if normalized.history_id and (
                    not next_cursor or int(normalized.history_id) > int(next_cursor)
                ):
                    next_cursor = normalized.history_id
                record = session.scalar(select(EmailMessage).where(EmailMessage.provider_id == normalized.provider_id))
                if record is None:
                    record = EmailMessage(id=f"gmail:{normalized.provider_id}", provider_id=normalized.provider_id)
                    session.add(record); added += 1
                else: updated += 1
                record.thread_id = normalized.thread_id
                record.history_id = normalized.history_id
                record.sender = normalized.sender; record.recipients = normalized.recipients
                record.subject = normalized.subject; record.body = normalized.body
                record.received_at = normalized.received_at; record.labels = ",".join(normalized.labels)
                record.is_read = "UNREAD" not in normalized.labels
                record.attachment_names = json.dumps([{"name": n, "size": s} for n, s in normalized.attachments])
            deleted = 0
            for message_id in dict.fromkeys(deleted_ids):
                record = session.scalar(select(EmailMessage).where(EmailMessage.provider_id == message_id))
                if record is not None: session.delete(record); deleted += 1
            if next_cursor:
                state.gmail_history_id = next_cursor
                if credential: credential.gmail_history_id = next_cursor
            state.status = "ok"; state.last_synced_at = datetime.utcnow(); state.last_error = ""
            session.commit()
            return SyncCounts(added, updated, deleted)
        except Exception as error:
            session.rollback()
            state = session.get(GoogleSyncState, 1) or GoogleSyncState(id=1)
            state.status = "error"; state.last_error = type(error).__name__; session.add(state); session.commit()
            raise
