from __future__ import annotations

from datetime import datetime, timedelta
from hashlib import sha256

from sqlalchemy import select

from app.google.calendar import CalendarAuthorizationError, CalendarConflictError, CalendarNetworkError
from app.models import CalendarOutbox, GoogleCalendarSettings, Visit

SIGNED_REPORT_URL_PLACEHOLDER = "{{SIGNED_REPORT_URL}}"


def stable_event_id(visit_id: str) -> str:
    return "visit" + sha256(visit_id.encode()).hexdigest()[:32]


def enqueue_calendar_operation(session, visit: Visit, operation: str) -> CalendarOutbox:
    existing = session.scalar(select(CalendarOutbox).where(CalendarOutbox.visit_id == visit.id, CalendarOutbox.status == "pending"))
    if existing: return existing
    item = CalendarOutbox(visit=visit, operation=operation)
    session.add(item)
    return item


def _event(visit):
    return {"id": stable_event_id(visit.id), "summary": visit.job.title,
            "location": visit.site.address,
            "description": f"{visit.job.description}\n\nTechnician report: {SIGNED_REPORT_URL_PLACEHOLDER}",
            "start": {"dateTime": visit.start_datetime.isoformat()}, "end": {"dateTime": visit.end_datetime.isoformat()},
            "attendees": [{"email": visit.technician.email}]}


def _calendar_id(session, provider):
    settings = session.get(GoogleCalendarSettings, 1)
    if settings is None:
        settings = GoogleCalendarSettings(id=1); session.add(settings)
    if not settings.calendar_id:
        calendars = provider.list_calendars()
        match = next((x for x in calendars if x.get("summary") == "Security Depot Service"), None)
        settings.calendar_id = (match or provider.create_service_calendar())["id"]
    return settings.calendar_id


def process_calendar_outbox(session, provider) -> int:
    delivered = 0
    items = session.scalars(select(CalendarOutbox).where(CalendarOutbox.status == "pending").order_by(CalendarOutbox.id)).all()
    for item in items:
        if item.next_attempt_at and item.next_attempt_at > datetime.utcnow():
            continue
        visit = item.visit; event = _event(visit)
        try:
            calendar_id = _calendar_id(session, provider)
            if visit.calendar_event_id:
                try:
                    result = provider.update_event(calendar_id, visit.calendar_event_id, event, visit.calendar_etag)
                except CalendarConflictError:
                    current = provider.get_event(calendar_id, visit.calendar_event_id)
                    result = provider.update_event(calendar_id, visit.calendar_event_id, event, current.get("etag", ""))
            else:
                try:
                    result = provider.insert_event(calendar_id, event)
                except CalendarNetworkError:
                    # The POST may have committed before the transport failed. A retry with
                    # the same client-supplied ID resolves as 409/get instead of duplicating.
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
