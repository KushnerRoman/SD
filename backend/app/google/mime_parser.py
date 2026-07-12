from __future__ import annotations

import base64
import html
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from email.header import decode_header, make_header


@dataclass(frozen=True)
class NormalizedMessage:
    provider_id: str
    thread_id: str
    history_id: str
    sender: str
    recipients: str
    subject: str
    body: str
    labels: list[str]
    received_at: datetime
    attachments: list[tuple[str, int]]


def _decode_data(value: str | None) -> str:
    if not value:
        return ""
    try:
        return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4)).decode("utf-8", errors="replace")
    except (ValueError, TypeError):
        return ""


def _header(value: str) -> str:
    try:
        return str(make_header(decode_header(value)))
    except (LookupError, UnicodeError):
        return value


def _html_text(value: str) -> str:
    value = re.sub(r"(?i)<br\s*/?>|</p\s*>", "\n", value)
    value = re.sub(r"(?s)<(script|style).*?>.*?</\1>", "", value)
    return re.sub(r"<[^>]+>", "", html.unescape(value)).strip()


def parse_gmail_message(message: dict) -> NormalizedMessage:
    payload = message.get("payload") or {}
    headers = {str(item.get("name", "")).lower(): _header(str(item.get("value", ""))) for item in payload.get("headers", [])}
    plain: list[str] = []
    rich: list[str] = []
    attachments: list[tuple[str, int]] = []

    def walk(part: dict) -> None:
        filename = str(part.get("filename") or "")
        body = part.get("body") or {}
        if filename:
            attachments.append((filename, int(body.get("size") or 0)))
            return
        mime = str(part.get("mimeType") or "").lower()
        text = _decode_data(body.get("data"))
        if mime == "text/plain" and text:
            plain.append(text.strip())
        elif mime == "text/html" and text:
            rich.append(_html_text(text))
        for child in part.get("parts") or []:
            walk(child)

    walk(payload)
    millis = int(message.get("internalDate") or 0)
    received_at = datetime.fromtimestamp(millis / 1000, tz=timezone.utc).replace(tzinfo=None)
    return NormalizedMessage(
        provider_id=str(message.get("id") or ""), thread_id=str(message.get("threadId") or ""),
        history_id=str(message.get("historyId") or ""), sender=headers.get("from", ""),
        recipients=headers.get("to", ""), subject=headers.get("subject", ""),
        body="\n\n".join(plain or rich), labels=[str(v) for v in message.get("labelIds") or []],
        received_at=received_at, attachments=attachments,
    )
