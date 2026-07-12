from datetime import datetime

import httpx
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

from app.database import Base
from app.database import get_session
from app.google.gmail import GmailNetworkError, GmailProvider, GmailQuotaError, GmailRevokedError
from app.google.mime_parser import parse_gmail_message
from app.google.sync import GoogleSyncCoordinator
from app.models import EmailMessage, GoogleCredential
from app.main import app, get_google_sync_coordinator
from tests.fixtures.gmail_messages import PLAIN, encoded


@pytest.fixture
def session():
    engine = create_engine("sqlite+pysqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    with Session(engine) as value:
        yield value


def test_parses_headers_plain_html_nested_and_attachment_metadata():
    raw = dict(PLAIN)
    raw["payload"] = {**PLAIN["payload"], "mimeType": "multipart/mixed", "body": {}, "parts": [
        {"mimeType": "multipart/alternative", "body": {}, "parts": [
            {"mimeType": "text/html", "body": {"data": encoded("<p>Fallback &amp; safe</p>")}},
            {"mimeType": "text/plain", "body": {"data": encoded("Preferred text")}},
        ]},
        {"mimeType": "application/pdf", "filename": "work.pdf", "body": {"attachmentId": "never-fetch", "size": 42}},
    ]}
    parsed = parse_gmail_message(raw)
    assert parsed.subject == "Service ✓"
    assert parsed.body == "Preferred text"
    assert parsed.attachments == [("work.pdf", 42)]


def test_html_fallback_strips_markup():
    raw = dict(PLAIN)
    raw["payload"] = {**PLAIN["payload"], "mimeType": "text/html", "body": {"data": encoded("<p>Hello<br>world &amp; team</p>")}}
    assert parse_gmail_message(raw).body == "Hello\nworld & team"


def test_provider_paginates_and_uses_read_only_full_requests():
    requests = []
    def handler(request):
        requests.append(request)
        if request.url.path.endswith("/messages"):
            return httpx.Response(200, json={"messages": [{"id": "a"}], "nextPageToken": "next"} if len(requests) == 1 else {"messages": [{"id": "b"}], "resultSizeEstimate": 2})
        return httpx.Response(200, json=PLAIN)
    provider = GmailProvider("token", http_client=httpx.Client(transport=httpx.MockTransport(handler)))
    assert provider.list_recent() == ["a", "b"]
    assert requests[0].url.params["q"] == "newer_than:90d"
    assert requests[1].url.params["pageToken"] == "next"
    provider.get_message("msg-1")
    assert requests[-1].url.params["format"] == "full"


@pytest.mark.parametrize(("status", "error"), [(401, GmailRevokedError), (403, GmailRevokedError), (429, GmailQuotaError), (500, GmailNetworkError)])
def test_provider_maps_safe_typed_errors(status, error):
    provider = GmailProvider("secret", http_client=httpx.Client(transport=httpx.MockTransport(lambda r: httpx.Response(status, text="provider secret"))))
    with pytest.raises(error) as raised:
        provider.list_recent()
    assert "provider secret" not in str(raised.value)


def test_initial_sync_is_idempotent(session):
    class Provider:
        def list_recent(self): return ["msg-1"]
        def get_message(self, message_id): return PLAIN
        def list_history(self, history_id):
            from app.google.gmail import HistoryResult
            return HistoryResult([], [], history_id)
    counts = GoogleSyncCoordinator(Provider()).sync_gmail(session)
    GoogleSyncCoordinator(Provider()).sync_gmail(session)
    assert counts.added == 1
    assert session.query(EmailMessage).filter_by(provider_id="msg-1").count() == 1
    assert session.query(GoogleCredential).count() == 0


def test_initial_sync_persists_message_history_for_incremental_followup(session):
    calls = []
    class Provider:
        def list_recent(self): calls.append("recent"); return ["msg-1"]
        def get_message(self, message_id): return PLAIN
        def list_history(self, history_id):
            from app.google.gmail import HistoryResult
            calls.append(("history", history_id)); return HistoryResult([], [], "13")
    coordinator = GoogleSyncCoordinator(Provider())
    coordinator.sync_gmail(session)
    coordinator.sync_gmail(session)
    assert calls == ["recent", ("history", "12")]


def test_sync_routes_return_counts_and_safe_status(session):
    class Coordinator:
        def sync_gmail(self, db):
            from app.google.sync import SyncCounts
            return SyncCounts(2, 1, 0)
    app.dependency_overrides[get_google_sync_coordinator] = lambda: Coordinator()
    app.dependency_overrides[get_session] = lambda: session
    try:
        response = TestClient(app).post("/google/sync")
        assert response.json() == {"added": 2, "updated": 1, "deleted": 0}
        status = TestClient(app).get("/google/sync-status").json()
        assert "token" not in str(status).lower()
    finally:
        app.dependency_overrides.clear()
