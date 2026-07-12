from datetime import datetime, timedelta

import httpx
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.google.calendar import CalendarError, CalendarProvider
from app.google.outbox import process_calendar_outbox, stable_event_id
from app.models import CalendarOutbox, GoogleCalendarSettings, Job, Site, Technician, Visit


def make_session():
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def seed(session):
    site = Site(id="site-1", name="North Tower", address="1 King St")
    tech = Technician(id="tech-1", name="Mike", email="mike@example.com")
    job = Job(id="job-1", title="Camera repair", description="Inspect camera", site=site, assigned_technician=tech)
    visit = Visit(id="visit_ABC-123", job=job, site=site, technician=tech,
                  start_datetime=datetime(2026, 7, 13, 9), end_datetime=datetime(2026, 7, 13, 10))
    session.add_all([job, visit, CalendarOutbox(visit=visit, operation="upsert")]); session.commit()
    return visit


def test_provider_creates_service_calendar_and_event_with_invitation_fields():
    requests = []
    def handler(request):
        requests.append(request)
        if request.url.path.endswith("/users/me/calendarList"):
            return httpx.Response(200, json={"items": []})
        if request.url.path.endswith("/calendars"):
            return httpx.Response(200, json={"id": "service@example.com"})
        return httpx.Response(200, json={"id": stable_event_id("visit_ABC-123"), "etag": '"v1"'})
    session = make_session(); visit = seed(session)
    provider = CalendarProvider("token", http_client=httpx.Client(transport=httpx.MockTransport(handler)))
    assert process_calendar_outbox(session, provider) == 1
    settings = session.get(GoogleCalendarSettings, 1)
    assert settings.calendar_id == "service@example.com"
    event_request = requests[-1]
    body = __import__("json").loads(event_request.content)
    assert body["id"] == stable_event_id(visit.id)
    assert body["location"] == "1 King St"
    assert "Inspect camera" in body["description"]
    assert "http://127.0.0.1:8765/report/" in body["description"]
    assert "North Tower" not in body["description"].split("Technician report: ")[1]
    assert body["attendees"] == [{"email": "mike@example.com"}]
    assert event_request.url.params["sendUpdates"] == "all"
    assert visit.calendar_event_id == stable_event_id(visit.id) and visit.calendar_etag == '"v1"'


def test_412_refreshes_etag_and_retries_update():
    calls = []
    def handler(request):
        calls.append(request)
        if request.method == "PATCH" and len([x for x in calls if x.method == "PATCH"]) == 1:
            return httpx.Response(412)
        if request.method == "GET" and "/events/" in request.url.path:
            return httpx.Response(200, json={"id": stable_event_id("visit_ABC-123"), "etag": '"fresh"'})
        return httpx.Response(200, json={"id": stable_event_id("visit_ABC-123"), "etag": '"v2"'})
    session = make_session(); visit = seed(session)
    visit.calendar_event_id = stable_event_id(visit.id); visit.calendar_etag = '"old"'
    session.add(GoogleCalendarSettings(id=1, calendar_id="cal")); session.commit()
    process_calendar_outbox(session, CalendarProvider("token", http_client=httpx.Client(transport=httpx.MockTransport(handler))))
    assert visit.calendar_etag == '"v2"'
    assert [r.headers.get("if-match") for r in calls if r.method == "PATCH"] == ['"old"', '"fresh"']


def test_ambiguous_timeout_retries_without_duplicate_event():
    inserts = 0
    def handler(request):
        nonlocal inserts
        if request.method == "POST":
            inserts += 1
            if inserts == 1: raise httpx.ReadTimeout("unknown", request=request)
            return httpx.Response(409)
        if request.method == "GET": return httpx.Response(200, json={"id": stable_event_id("visit_ABC-123"), "etag": '"exists"'})
        return httpx.Response(200, json={})
    session = make_session(); visit = seed(session)
    session.add(GoogleCalendarSettings(id=1, calendar_id="cal")); session.commit()
    provider = CalendarProvider("token", http_client=httpx.Client(transport=httpx.MockTransport(handler)))
    process_calendar_outbox(session, provider)
    assert inserts == 1
    item = session.query(CalendarOutbox).one()
    assert item.status == "pending" and item.attempts == 1 and item.next_attempt_at
    item.next_attempt_at = datetime.utcnow() - timedelta(seconds=1); session.commit()
    process_calendar_outbox(session, provider)
    assert inserts == 2
    assert visit.calendar_event_id == stable_event_id(visit.id)
    assert session.query(CalendarOutbox).one().status == "delivered"


def test_backoff_skips_not_due_work_and_stops_after_five_attempts():
    calls = 0
    def handler(request):
        nonlocal calls
        calls += 1
        raise httpx.ConnectError("secret upstream detail", request=request)
    session = make_session(); seed(session)
    item = session.query(CalendarOutbox).one()
    item.next_attempt_at = datetime.utcnow() + timedelta(minutes=1); session.commit()
    provider = CalendarProvider("token", http_client=httpx.Client(transport=httpx.MockTransport(handler)))
    assert process_calendar_outbox(session, provider) == 0 and calls == 0
    item.next_attempt_at = None; item.attempts = 4; session.commit()
    process_calendar_outbox(session, provider)
    assert item.status == "failed" and item.attempts == 5
    assert item.last_error == "Calendar delivery failed"


def test_shared_same_name_calendar_is_not_reused():
    created = 0
    def handler(request):
        nonlocal created
        if request.url.path.endswith("/users/me/calendarList"):
            return httpx.Response(200, json={"items": [{"id": "shared", "summary": "Security Depot Service", "accessRole": "reader"}]})
        if request.url.path.endswith("/calendars"):
            created += 1
            return httpx.Response(200, json={"id": "owned"})
        return httpx.Response(200, json={"id": stable_event_id("visit_ABC-123"), "etag": '"v1"'})
    session = make_session(); seed(session)
    process_calendar_outbox(session, CalendarProvider("token", http_client=httpx.Client(transport=httpx.MockTransport(handler))))
    assert created == 1
    assert session.get(GoogleCalendarSettings, 1).calendar_id == "owned"


def test_calendar_list_and_create_classify_bad_responses_safely():
    for status, body in [(400, {"error": {"message": "sensitive"}}), (200, None)]:
        def handler(request, status=status, body=body):
            if body is None: return httpx.Response(status, content=b"not-json")
            return httpx.Response(status, json=body)
        provider = CalendarProvider("token", http_client=httpx.Client(transport=httpx.MockTransport(handler)))
        for operation in (provider.list_calendars, provider.create_service_calendar):
            with __import__("pytest").raises(CalendarError, match="Calendar rejected the request|invalid response") as raised:
                operation()
            assert "sensitive" not in str(raised.value)
