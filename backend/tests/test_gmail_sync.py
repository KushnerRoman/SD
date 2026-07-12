from datetime import datetime

import httpx
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

from app.database import Base, upgrade_sqlite_schema
from app.database import get_session
from app.google.gmail import GmailMessageNotFound, GmailNetworkError, GmailProvider, GmailQuotaError, GmailRevokedError, HistoryResult
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


def test_parser_respects_part_charset():
    raw = dict(PLAIN)
    raw["payload"] = {**PLAIN["payload"], "mimeType": "text/plain", "headers": [{"name": "Content-Type", "value": "text/plain; charset=iso-8859-1"}], "body": {"data": __import__("base64").urlsafe_b64encode("café".encode("iso-8859-1")).decode()}}
    assert parse_gmail_message(raw).body == "café"


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


def test_history_paginates_and_preserves_event_order():
    requests = []
    def handler(request):
        requests.append(request)
        if len(requests) == 1:
            return httpx.Response(200, json={"history": [{"messagesAdded": [{"message": {"id": "a"}}]}, {"messagesDeleted": [{"message": {"id": "a"}}]}], "nextPageToken": "p2", "historyId": "11"})
        return httpx.Response(200, json={"history": [{"messagesDeleted": [{"message": {"id": "b"}}]}, {"messagesAdded": [{"message": {"id": "b"}}]}], "historyId": "12"})
    result = GmailProvider("token", http_client=httpx.Client(transport=httpx.MockTransport(handler))).list_history("10")
    assert result.operations == [("add", "a"), ("delete", "a"), ("delete", "b"), ("add", "b")]
    assert requests[1].url.params["pageToken"] == "p2"
    assert requests[0].url.params.get_list("historyTypes") == ["messageAdded", "messageDeleted"]


@pytest.mark.parametrize(("status", "error"), [(401, GmailRevokedError), (403, GmailRevokedError), (429, GmailQuotaError), (500, GmailNetworkError)])
def test_provider_maps_safe_typed_errors(status, error):
    provider = GmailProvider("secret", http_client=httpx.Client(transport=httpx.MockTransport(lambda r: httpx.Response(status, text="provider secret"))))
    with pytest.raises(error) as raised:
        provider.list_recent()
    assert "provider secret" not in str(raised.value)


def test_initial_sync_is_idempotent(session):
    class Provider:
        def list_recent(self): return ["msg-1"]
        def current_history_id(self): return "12"
        def get_message(self, message_id): return PLAIN
        def list_history(self, history_id):
            from app.google.gmail import HistoryResult
            return HistoryResult([], history_id)
    counts = GoogleSyncCoordinator(Provider()).sync_gmail(session)
    GoogleSyncCoordinator(Provider()).sync_gmail(session)
    assert counts.added == 1
    assert session.query(EmailMessage).filter_by(provider_id="msg-1").count() == 1
    assert session.query(GoogleCredential).count() == 0


def test_initial_sync_persists_message_history_for_incremental_followup(session):
    calls = []
    class Provider:
        def list_recent(self): calls.append("recent"); return ["msg-1"]
        def current_history_id(self): return "12"
        def get_message(self, message_id): return PLAIN
        def list_history(self, history_id):
            from app.google.gmail import HistoryResult
            calls.append(("history", history_id)); return HistoryResult([], "13")
    coordinator = GoogleSyncCoordinator(Provider())
    coordinator.sync_gmail(session)
    coordinator.sync_gmail(session)
    assert calls == ["recent", ("history", "12")]


def test_empty_initial_sync_uses_mailbox_history_checkpoint(session):
    class Provider:
        def list_recent(self): return []
        def current_history_id(self): return "50"
        def list_history(self, history_id): assert history_id == "50"; return HistoryResult([], "51")
    coordinator = GoogleSyncCoordinator(Provider())
    coordinator.sync_gmail(session); coordinator.sync_gmail(session)


def test_initial_checkpoint_precedes_listing_and_replays_arrival_during_import(session):
    calls = []
    class Provider:
        def current_history_id(self): calls.append("profile"); return "100"
        def list_recent(self): calls.append("list"); return ["msg-1"]
        def get_message(self, message_id):
            calls.append(("get", message_id))
            return {**PLAIN, "id": message_id, "historyId": "100" if message_id == "msg-1" else "101"}
        def list_history(self, history_id):
            calls.append(("history", history_id))
            return HistoryResult([("add", "msg-arrived")], "101")
    coordinator = GoogleSyncCoordinator(Provider())
    coordinator.sync_gmail(session)
    coordinator.sync_gmail(session)
    assert calls == ["profile", "list", ("get", "msg-1"), ("history", "100"), ("get", "msg-arrived")]
    assert session.query(EmailMessage).filter_by(provider_id="msg-arrived").count() == 1


def test_incremental_final_state_and_404_race(session):
    existing = EmailMessage(id="gmail:a", provider_id="a", sender="", subject="", received_at=datetime.utcnow())
    session.add(existing); session.commit()
    fetched = []
    class Provider:
        def list_history(self, history_id): return HistoryResult([("add", "a"), ("delete", "a"), ("delete", "b"), ("add", "b"), ("add", "gone")], "20")
        def get_message(self, message_id):
            fetched.append(message_id)
            if message_id == "gone": raise GmailMessageNotFound("gone")
            return {**PLAIN, "id": message_id}
    from app.models import GoogleSyncState
    session.add(GoogleSyncState(id=1, gmail_history_id="10", status="ok")); session.commit()
    GoogleSyncCoordinator(Provider()).sync_gmail(session)
    assert fetched == ["b", "gone"]
    assert session.query(EmailMessage).filter_by(provider_id="a").count() == 0
    assert session.query(EmailMessage).filter_by(provider_id="b").count() == 1
    assert session.get(GoogleSyncState, 1).gmail_history_id == "20"


def test_failed_incremental_rolls_back_messages_and_checkpoint(session):
    from app.models import GoogleSyncState
    session.add(GoogleSyncState(id=1, gmail_history_id="10", status="ok")); session.commit()
    class Provider:
        def list_history(self, history_id): return HistoryResult([("add", "x")], "20")
        def get_message(self, message_id): raise GmailNetworkError("safe")
    with pytest.raises(GmailNetworkError): GoogleSyncCoordinator(Provider()).sync_gmail(session)
    assert session.query(EmailMessage).count() == 0
    assert session.get(GoogleSyncState, 1).gmail_history_id == "10"


def test_upgrade_old_sqlite_schema_preserves_rows(tmp_path):
    engine = create_engine(f"sqlite+pysqlite:///{tmp_path / 'old.db'}")
    with engine.begin() as connection:
        connection.exec_driver_sql("CREATE TABLE sites (id VARCHAR(64) PRIMARY KEY, name VARCHAR(255))")
        connection.exec_driver_sql("INSERT INTO sites VALUES ('s1', 'Preserved')")
        connection.exec_driver_sql("CREATE TABLE email_messages (id VARCHAR(64) PRIMARY KEY)")
        connection.exec_driver_sql("CREATE TABLE google_credentials (id INTEGER PRIMARY KEY)")
    upgrade_sqlite_schema(engine)
    with engine.connect() as connection:
        assert connection.exec_driver_sql("SELECT name FROM sites WHERE id='s1'").scalar() == "Preserved"
        assert {row[1] for row in connection.exec_driver_sql("PRAGMA table_info(email_messages)")} >= {"provider_id", "history_id"}
        assert "gmail_history_id" in {row[1] for row in connection.exec_driver_sql("PRAGMA table_info(google_credentials)")}


def test_coordinator_dependency_refreshes_token_into_provider(session, monkeypatch):
    from cryptography.fernet import Fernet
    from app.google.config import GoogleSettings
    from app.google.oauth import CredentialCipher, GoogleOAuthService
    seen = {}
    settings = GoogleSettings("client", "secret", "http://127.0.0.1:8765/auth/google/callback", Fernet.generate_key().decode())
    oauth = GoogleOAuthService(settings, CredentialCipher(settings.token_encryption_key), http_client=httpx.Client(transport=httpx.MockTransport(lambda request: httpx.Response(200, json={"access_token": "fresh-access"}))))
    oauth.store_tokens(session, account_email="ops@example.com", refresh_token="encrypted-refresh")
    monkeypatch.setattr("app.main.GmailProvider", lambda token: seen.setdefault("provider", token) or object())
    coordinator = get_google_sync_coordinator(session, oauth)
    assert seen["provider"] == "fresh-access"
    assert coordinator.gmail == "fresh-access"


def test_sync_routes_return_counts_and_safe_status(session):
    class Coordinator:
        def sync_gmail(self, db):
            from app.google.sync import SyncCounts
            return SyncCounts(2, 1, 0)
    app.dependency_overrides[get_google_sync_coordinator] = lambda: Coordinator()
    from app.main import get_calendar_provider
    app.dependency_overrides[get_calendar_provider] = lambda: object()
    from app import main
    original = main.process_calendar_outbox
    main.process_calendar_outbox = lambda db, provider: 0
    app.dependency_overrides[get_session] = lambda: session
    try:
        response = TestClient(app).post("/google/sync")
        assert response.json() == {"status": "ok", "added": 2, "updated": 1, "deleted": 0, "calendar_delivered": 0}
        status = TestClient(app).get("/google/sync-status").json()
        assert "token" not in str(status).lower()
    finally:
        main.process_calendar_outbox = original
        app.dependency_overrides.clear()
