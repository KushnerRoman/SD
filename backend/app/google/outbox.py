from __future__ import annotations

from datetime import datetime, timedelta
from hashlib import sha256

from sqlalchemy import select

from app.google.calendar import CalendarAuthorizationError, CalendarConflictError
from app.models import CalendarOutbox, GoogleCalendarSettings, Visit

REPORT_PUBLIC_BASE = "http://127.0.0.1:8765"


def stable_event_id(visit_id: str) -> str:
    return "visit" + sha256(visit_id.encode()).hexdigest()[:32]


def enqueue_calendar_operation(session, visit: Visit, operation: str) -> CalendarOutbox:
    existing = session.scalar(select(CalendarOutbox).where(CalendarOutbox.visit_id == visit.id, CalendarOutbox.status == "pending"))
    if existing: return existing
    item = CalendarOutbox(visit=visit, operation=operation)
    session.add(item)
    return item


def _event(session, visit):
    from app.report_tokens import issue_report_token
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
        calendars = provider.list_calendars()
        match = next((x for x in calendars if isinstance(x, dict) and x.get("summary") == "Security Depot Service" and x.get("accessRole") == "owner"), None)
        settings.calendar_id = (match or provider.create_service_calendar())["id"]
    return settings.calendar_id


def process_calendar_outbox(session, provider) -> int:
    delivered = 0
    items = session.scalars(select(CalendarOutbox).where(CalendarOutbox.status == "pending").order_by(CalendarOutbox.id)).all()
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
        except Exception as error:
            item.attempts += 1
            item.next_attempt_at = datetime.utcnow() + timedelta(seconds=min(300, 2 ** item.attempts))
            item.last_error = "Calendar delivery failed"
            if item.attempts >= 5:
                item.status = "failed"
        item.updated_at = datetime.utcnow()
        session.commit()
    return delivered
