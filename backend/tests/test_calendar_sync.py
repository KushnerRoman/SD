from datetime import datetime, timedelta

import httpx
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.google.calendar import CalendarAuthorizationError, CalendarError, CalendarProvider, CalendarQuotaError
from app.google.outbox import process_calendar_outbox, stable_event_id, sync_calendar_changes
from app.models import CalendarOutbox, GoogleCalendarSettings, Job, Site, Technician, Visit
from app.report_tokens import resolve_report_token
from app.main import _perform_google_sync
from app.models import GoogleSyncState

TEST_KEY = __import__("base64").urlsafe_b64encode(b"A" * 32).decode()


@pytest.fixture(autouse=True)
def report_secret(monkeypatch):
    monkeypatch.setenv("TOKEN_ENCRYPTION_KEY", TEST_KEY)


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
    urls = []
    def handler(request):
        nonlocal inserts
        if request.method == "POST":
            inserts += 1
            urls.append(__import__("json").loads(request.content)["description"].split("Technician report: ")[1])
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
    assert urls[0] == urls[1]
    assert resolve_report_token(session, urls[0].rsplit("/", 1)[1]).id == visit.id
    assert visit.calendar_event_id == stable_event_id(visit.id)
    assert session.query(CalendarOutbox).one().status == "delivered"


def test_delivered_link_stays_valid_after_calendar_update():
    urls = []
    def handler(request):
        if request.method in ("POST", "PATCH") and "/events" in request.url.path:
            urls.append(__import__("json").loads(request.content)["description"].split("Technician report: ")[1])
            return httpx.Response(200, json={"id": stable_event_id("visit_ABC-123"), "etag": f'"v{len(urls)}"'})
        return httpx.Response(200, json={"items": []} if request.method == "GET" else {"id": "cal"})
    session = make_session(); visit = seed(session)
    provider = CalendarProvider("token", http_client=httpx.Client(transport=httpx.MockTransport(handler)))
    process_calendar_outbox(session, provider)
    first_token = urls[0].rsplit("/", 1)[1]
    session.add(CalendarOutbox(visit=visit, operation="upsert")); session.commit()
    process_calendar_outbox(session, provider)
    assert urls == [urls[0], urls[0]]
    assert resolve_report_token(session, first_token).id == visit.id


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


def test_composite_sync_status_reports_calendar_delivery_failure():
    session = make_session(); seed(session)
    class Gmail:
        def sync_gmail(self, db):
            from app.google.sync import SyncCounts
            state = GoogleSyncState(id=1, status="ok"); db.merge(state); db.commit()
            return SyncCounts()
    provider = CalendarProvider("token", http_client=httpx.Client(transport=httpx.MockTransport(
        lambda request: (_ for _ in ()).throw(httpx.ConnectError("secret", request=request)))))
    with pytest.raises(CalendarError): _perform_google_sync(session, Gmail(), provider)
    state = session.get(GoogleSyncState, 1)
    assert state.status == "error" and state.last_error == "calendar.delivery"


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


def test_reconnect_outbox_is_retried_after_authorization_returns():
    session = make_session(); visit = seed(session)
    item = session.query(CalendarOutbox).one(); item.status = "reconnect"
    session.add(GoogleCalendarSettings(id=1, calendar_id="cal")); session.commit()
    provider = CalendarProvider("token", http_client=httpx.Client(transport=httpx.MockTransport(
        lambda request: httpx.Response(200, json={"id": stable_event_id(visit.id), "etag": '"ok"'}))))
    assert process_calendar_outbox(session, provider) == 1
    assert item.status == "delivered" and visit.calendar_event_id


def test_changed_calendar_events_use_sync_token_and_ignore_foreign_events():
    session = make_session(); visit = seed(session)
    visit.calendar_event_id = stable_event_id(visit.id)
    settings = GoogleCalendarSettings(id=1, calendar_id="cal", sync_token="old")
    session.add(settings); session.commit()
    seen = []
    def handler(request):
        seen.append(dict(request.url.params))
        return httpx.Response(200, json={"items": [
            {"id": "foreign", "etag": '"x"'},
            {"id": visit.calendar_event_id, "etag": '"new"',
             "start": {"dateTime": "2026-07-13T11:00:00"},
             "end": {"dateTime": "2026-07-13T12:00:00"}},
        ], "nextSyncToken": "new-token"})
    provider = CalendarProvider("token", http_client=httpx.Client(transport=httpx.MockTransport(handler)))
    assert sync_calendar_changes(session, provider) == 1
    assert seen == [{"syncToken": "old"}]
    assert settings.sync_token == "new-token" and visit.calendar_etag == '"new"'
    assert visit.start_datetime.hour == 11


@pytest.mark.parametrize(("status", "reason", "error"), [
    (403, "rateLimitExceeded", CalendarQuotaError),
    (403, "insufficientPermissions", CalendarAuthorizationError),
])
def test_calendar_403_reason_distinguishes_quota_from_authorization(status, reason, error):
    provider = CalendarProvider("token", http_client=httpx.Client(transport=httpx.MockTransport(
        lambda request: httpx.Response(status, json={"error": {"errors": [{"reason": reason}]}}))))
    with pytest.raises(error): provider.list_calendars()


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
