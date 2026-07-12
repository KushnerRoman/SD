from __future__ import annotations

import base64
import hashlib
from datetime import datetime, timedelta
from urllib.parse import parse_qs, urlparse

import httpx
import pytest
from cryptography.fernet import Fernet
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_session
from app.google.config import GoogleConfigurationError, GoogleSettings
from app.google.oauth import CredentialCipher, GoogleOAuthService, OAuthStateError
from app.main import app, get_google_oauth_service
from app.models import GoogleCredential


@pytest.fixture
def settings() -> GoogleSettings:
    return GoogleSettings(
        client_id="test-client.apps.googleusercontent.com",
        client_secret="test-client-secret",
        redirect_uri="http://127.0.0.1:8765/auth/google/callback",
        token_encryption_key=Fernet.generate_key().decode(),
    )


@pytest.fixture
def session_factory():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine, autoflush=False, autocommit=False)


@pytest.fixture
def session(session_factory):
    with session_factory() as value:
        yield value


def test_missing_configuration_reports_names_without_values(monkeypatch):
    for name in ("GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET", "GOOGLE_REDIRECT_URI", "TOKEN_ENCRYPTION_KEY"):
        monkeypatch.delenv(name, raising=False)

    with pytest.raises(GoogleConfigurationError) as raised:
        GoogleSettings.from_env()

    message = str(raised.value)
    for name in ("GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET", "GOOGLE_REDIRECT_URI", "TOKEN_ENCRYPTION_KEY"):
        assert name in message
    assert "secret" not in message.lower().replace("GOOGLE_CLIENT_SECRET".lower(), "")


def test_authorization_url_generates_state_and_pkce(settings):
    service = GoogleOAuthService(settings, CredentialCipher(settings.token_encryption_key))

    url = service.authorization_url(has_refresh_token=False)
    query = parse_qs(urlparse(url).query)

    assert query["access_type"] == ["offline"]
    assert query["prompt"] == ["consent"]
    assert query["code_challenge_method"] == ["S256"]
    assert query["scope"] == [" ".join(settings.scopes)]
    pending = service.pending_authorizations[query["state"][0]]
    expected = base64.urlsafe_b64encode(hashlib.sha256(pending.code_verifier.encode()).digest()).rstrip(b"=").decode()
    assert query["code_challenge"] == [expected]


def test_authorization_url_omits_consent_when_refresh_token_exists(settings):
    service = GoogleOAuthService(settings, CredentialCipher(settings.token_encryption_key))
    query = parse_qs(urlparse(service.authorization_url(has_refresh_token=True)).query)
    assert "prompt" not in query


def test_exchange_rejects_wrong_state_without_http_request(settings):
    calls = []
    client = httpx.Client(transport=httpx.MockTransport(lambda request: calls.append(request)))
    service = GoogleOAuthService(settings, CredentialCipher(settings.token_encryption_key), http_client=client)
    service.authorization_url(has_refresh_token=False)

    with pytest.raises(OAuthStateError):
        service.exchange_code(code="code", state="wrong-state")
    assert calls == []


def test_exchange_code_uses_pkce_and_mocked_transport(settings):
    captured = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["form"] = parse_qs(request.content.decode())
        return httpx.Response(200, json={"access_token": "access", "refresh_token": "refresh", "expires_in": 3600})

    service = GoogleOAuthService(
        settings,
        CredentialCipher(settings.token_encryption_key),
        http_client=httpx.Client(transport=httpx.MockTransport(handler)),
    )
    state = parse_qs(urlparse(service.authorization_url(has_refresh_token=False)).query)["state"][0]
    tokens = service.exchange_code(code="auth-code", state=state)

    assert tokens["access_token"] == "access"
    assert captured["form"]["code_verifier"]
    assert captured["form"]["client_secret"] == ["test-client-secret"]
    assert state not in service.pending_authorizations


def test_refresh_token_is_not_stored_in_plaintext(session, settings):
    service = GoogleOAuthService(settings, CredentialCipher(settings.token_encryption_key))
    service.store_tokens(session, account_email="manager@gmail.com", refresh_token="secret-refresh")
    record = session.query(GoogleCredential).one()
    assert b"secret-refresh" not in record.encrypted_refresh_token
    assert service.load_refresh_token(record) == "secret-refresh"


def test_refresh_and_revoke_use_mocked_http(settings):
    requests = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        if request.url.path.endswith("/token"):
            return httpx.Response(200, json={"access_token": "new-access", "expires_in": 3600})
        return httpx.Response(200)

    service = GoogleOAuthService(
        settings,
        CredentialCipher(settings.token_encryption_key),
        http_client=httpx.Client(transport=httpx.MockTransport(handler)),
    )
    assert service.refresh_access_token("refresh-secret")["access_token"] == "new-access"
    service.revoke("refresh-secret")
    assert len(requests) == 2
    assert b"refresh-secret" in requests[0].content
    assert parse_qs(requests[1].url.query.decode())["token"] == ["refresh-secret"]


def test_account_email_comes_from_userinfo_without_exposing_access_token(settings):
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["authorization"] == "Bearer access-secret"
        return httpx.Response(200, json={"email": "manager@gmail.com"})

    service = GoogleOAuthService(
        settings,
        CredentialCipher(settings.token_encryption_key),
        http_client=httpx.Client(transport=httpx.MockTransport(handler)),
    )
    assert service.account_email("access-secret") == "manager@gmail.com"


def test_connection_route_returns_safe_disconnected_connected_and_expired_states(session_factory, settings):
    service = GoogleOAuthService(settings, CredentialCipher(settings.token_encryption_key))

    def override_session():
        with session_factory() as value:
            yield value

    app.dependency_overrides[get_session] = override_session
    app.dependency_overrides[get_google_oauth_service] = lambda: service
    try:
        client = TestClient(app)
        assert client.get("/google/connection").json() == {"status": "disconnected", "account_email": None, "expires_at": None}

        with session_factory() as db:
            service.store_tokens(db, account_email="manager@gmail.com", refresh_token="never-return-me")
        connected = client.get("/google/connection").json()
        assert connected["status"] == "connected"
        assert connected["account_email"] == "manager@gmail.com"
        assert "token" not in str(connected).lower()

        with session_factory() as db:
            record = db.query(GoogleCredential).one()
            record.expires_at = datetime.utcnow() - timedelta(seconds=1)
            db.commit()
        assert client.get("/google/connection").json()["status"] == "expired"
    finally:
        app.dependency_overrides.clear()


def test_start_callback_and_disconnect_routes_do_not_return_tokens(session_factory, settings):
    def token_handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/userinfo"):
            assert request.headers["authorization"] == "Bearer access-never-return"
            return httpx.Response(200, json={"email": "manager@gmail.com"})
        if request.url.path.endswith("/token"):
            return httpx.Response(
                200,
                json={
                    "access_token": "access-never-return",
                    "refresh_token": "refresh-never-return",
                    "expires_in": 3600,
                },
            )
        return httpx.Response(200)

    service = GoogleOAuthService(
        settings,
        CredentialCipher(settings.token_encryption_key),
        http_client=httpx.Client(transport=httpx.MockTransport(token_handler)),
    )

    def override_session():
        with session_factory() as value:
            yield value

    app.dependency_overrides[get_session] = override_session
    app.dependency_overrides[get_google_oauth_service] = lambda: service
    try:
        client = TestClient(app, follow_redirects=False)
        start = client.get("/auth/google/start")
        state = parse_qs(urlparse(start.headers["location"]).query)["state"][0]
        callback = client.get(f"/auth/google/callback?code=abc&state={state}")
        assert callback.headers["location"] == "/web/#/settings?google=connected"
        assert "never-return" not in callback.text

        disconnected = client.post("/auth/google/disconnect")
        assert disconnected.json() == {"status": "disconnected"}
        with session_factory() as db:
            assert db.query(GoogleCredential).count() == 0
    finally:
        app.dependency_overrides.clear()


def test_callback_wrong_state_redirects_with_safe_error(settings):
    service = GoogleOAuthService(settings, CredentialCipher(settings.token_encryption_key))
    app.dependency_overrides[get_google_oauth_service] = lambda: service
    try:
        response = TestClient(app, follow_redirects=False).get("/auth/google/callback?code=abc&state=wrong")
        assert response.headers["location"] == "/web/#/settings?google=error&code=invalid_state"
        assert "abc" not in response.headers["location"]
    finally:
        app.dependency_overrides.clear()
