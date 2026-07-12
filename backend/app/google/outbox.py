from __future__ import annotations

from datetime import datetime, timedelta
from hashlib import sha256

from sqlalchemy import select

from app.google.calendar import CalendarAuthorizationError, CalendarConflictError, CalendarSyncTokenExpired
from app.models import CalendarOutbox, GoogleCalendarSettings, Visit
from app.report_tokens import issue_report_token

REPORT_PUBLIC_BASE = "http://127.0.0.1:8765"


def stable_event_id(visit_id: str) -> str:
    return "visit" + sha256(visit_id.encode()).hexdigest()[:32]


def enqueue_calendar_operation(session, visit: Visit, operation: str) -> CalendarOutbox:
    issue_report_token(session, visit)
    existing = session.scalar(select(CalendarOutbox).where(CalendarOutbox.visit_id == visit.id, CalendarOutbox.status == "pending"))
    if existing: return existing
    item = CalendarOutbox(visit=visit, operation=operation)
    session.add(item)
    return item


def _event(session, visit):
    report_url = f"{REPORT_PUBLIC_BASE}/report/{issue_report_token(session, visit)}"
    return {"id": stable_event_id(visit.id), "summary": visit.job.title,
            "location": visit.site.address,
            "description": f"{visit.job.description}\n\nTechnician report: {report_url}",
            "start": {"dateTime": visit.start_datetime.isoformat()}, "end": {"dateTime": visit.end_datetime.isoformat()},
            "attendees": [{"email": visit.technician.email}]}


def _calendar_id(session, provider):
    settings = session.get(GoogleCalendarSettings, 1)
    if settings is None:
        settings = GoogleCalendarSettings(id=1); session.add(settings)
    if not settings.calendar_id:
        settings.calendar_id = provider.create_service_calendar()["id"]
    return settings.calendar_id


def process_calendar_outbox(session, provider) -> int:
    delivered = 0
    items = session.scalars(select(CalendarOutbox).where(CalendarOutbox.status.in_(("pending", "reconnect"))).order_by(CalendarOutbox.id)).all()
    for item in items:
        if item.next_attempt_at and item.next_attempt_at > datetime.utcnow():
            continue
        visit = item.visit; event = _event(session, visit)
        try:
            calendar_id = _calendar_id(session, provider)
            if visit.calendar_event_id:
                try:
                    result = provider.update_event(calendar_id, visit.calendar_event_id, event, visit.calendar_etag)
                except CalendarConflictError:
                    current = provider.get_event(calendar_id, visit.calendar_event_id)
                    result = provider.update_event(calendar_id, visit.calendar_event_id, event, current.get("etag", ""))
            else:
                # A later due retry uses the identical client-supplied ID. If the
                # ambiguous POST committed, Calendar returns 409 and the provider
                # retrieves that event instead of creating a duplicate.
                result = provider.insert_event(calendar_id, event)
            visit.calendar_event_id = result.get("id", event["id"])
            visit.calendar_etag = result.get("etag", "")
            visit.calendar_updated_at = datetime.utcnow()
            item.status = "delivered"; item.last_error = ""; delivered += 1
        except CalendarAuthorizationError:
            item.status = "reconnect"; item.last_error = "Google authorization is no longer valid"
        except Exception:
            item.attempts += 1
            item.next_attempt_at = datetime.utcnow() + timedelta(seconds=min(300, 2 ** item.attempts))
            item.last_error = "Calendar delivery failed"
            if item.attempts >= 5:
                item.status = "failed"
        item.updated_at = datetime.utcnow()
        session.commit()
    return delivered


def sync_calendar_changes(session, provider) -> int:
    settings = session.get(GoogleCalendarSettings, 1)
    if settings is None or not settings.calendar_id:
        return 0
    changed = 0
    page_token = None
    while True:
        try:
            page = provider.get_changed_events(settings.calendar_id, settings.sync_token or None, page_token)
        except CalendarSyncTokenExpired:
            settings.sync_token = ""
            session.commit()
            page_token = None
            page = provider.get_changed_events(settings.calendar_id, None, None)
        for event in page.get("items", []):
            event_id = event.get("id")
            visit = session.scalar(select(Visit).where(Visit.calendar_event_id == event_id))
            if visit is None or event_id != stable_event_id(visit.id):
                continue
            visit.calendar_etag = str(event.get("etag") or visit.calendar_etag)
            for field, attribute in (("start", "start_datetime"), ("end", "end_datetime")):
                text = (event.get(field) or {}).get("dateTime")
                if text:
                    setattr(visit, attribute, datetime.fromisoformat(text.replace("Z", "+00:00")).replace(tzinfo=None))
            if event.get("status") == "cancelled":
                visit.status = "Not Completed"
                visit.work_summary = "Calendar event cancelled"
            changed += 1
        page_token = page.get("nextPageToken")
        if not page_token:
            settings.sync_token = str(page.get("nextSyncToken") or settings.sync_token)
            session.commit()
            return changed
