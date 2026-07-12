from datetime import datetime, timedelta
from hashlib import sha256

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_session
from app.main import app
from app.models import ActivityEntry, CalendarOutbox, Job, Notification, ReportToken, Site, Technician, Visit
from app.report_tokens import ReportTokenError, close_report_token, issue_report_token, resolve_report_token

TEST_KEY = __import__("base64").urlsafe_b64encode(b"A" * 32).decode()


@__import__("pytest").fixture(autouse=True)
def report_secret(monkeypatch):
    monkeypatch.setenv("TOKEN_ENCRYPTION_KEY", TEST_KEY)


def make_session():
    engine = create_engine("sqlite+pysqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def seed(session):
    site = Site(id="site-1", name="<script>alert(1)</script>", address="1 Main")
    tech = Technician(id="tech-1", name="Taylor <Tech>", email="t@example.com")
    job = Job(id="job-1", title="Camera & alarm", site=site, assigned_technician=tech, status="Scheduled")
    visit = Visit(id="visit-1", job=job, site=site, technician=tech, technician_name=tech.name, status="Scheduled")
    session.add(visit); session.commit()
    return visit


def client_for(session):
    def override():
        yield session
    app.dependency_overrides[get_session] = override
    return TestClient(app)


def test_token_is_256_bit_random_and_only_sha256_hash_is_stored():
    session = make_session(); visit = seed(session)
    first = issue_report_token(session, visit); second = issue_report_token(session, visit)
    assert first == second and len(__import__("base64").urlsafe_b64decode(first + "==")) == 32
    rows = session.query(ReportToken).all()
    assert len(rows) == 1 and rows[0].token_hash not in (first, second) and len(rows[0].token_hash) == 64
    assert rows[0].token_hash == sha256(second.encode()).hexdigest()
    assert rows[0].revoked_at is None and rows[0].nonce not in first


def test_missing_or_invalid_secret_fails_before_token_issuance(monkeypatch):
    from app.report_tokens import ReportTokenConfigurationError
    session = make_session(); visit = seed(session)
    for value in (None, "short", "replace-with-fernet-key"):
        if value is None: monkeypatch.delenv("TOKEN_ENCRYPTION_KEY", raising=False)
        else: monkeypatch.setenv("TOKEN_ENCRYPTION_KEY", value)
        with __import__("pytest").raises(ReportTokenConfigurationError, match="configuration is unavailable"):
            issue_report_token(session, visit)
        assert session.query(ReportToken).count() == 0


def test_distinct_strong_secrets_derive_distinct_tokens_for_same_visit_nonce(monkeypatch):
    from app.report_tokens import _derive
    nonce = "persisted-random-nonce"
    monkeypatch.setenv("TOKEN_ENCRYPTION_KEY", __import__("base64").urlsafe_b64encode(b"B" * 32).decode())
    first = _derive("visit-1", nonce)
    monkeypatch.setenv("TOKEN_ENCRYPTION_KEY", __import__("base64").urlsafe_b64encode(b"C" * 32).decode())
    assert _derive("visit-1", nonce) != first


def test_production_source_contains_no_report_signing_secret_constant():
    from pathlib import Path
    source = (Path(__file__).parents[1] / "app" / "report_tokens.py").read_text()
    assert "security-depot-local-report-token-v1" not in source
    assert 'os.getenv("REPORT_TOKEN_SIGNING_KEY"' not in source


def test_resolve_rejects_invalid_expired_closed_and_revoked_neutrally():
    session = make_session(); visit = seed(session); token = issue_report_token(session, visit)
    for action in ("invalid", "expired", "closed", "revoked"):
        if action == "expired": session.query(ReportToken).filter_by(token_hash=sha256(token.encode()).hexdigest()).one().expires_at = datetime.utcnow() - timedelta(seconds=1)
        elif action == "closed": close_report_token(session, token)
        elif action == "revoked": session.query(ReportToken).filter_by(token_hash=sha256(token.encode()).hexdigest()).one().revoked_at = datetime.utcnow()
        session.commit()
        with __import__("pytest").raises(ReportTokenError, match="Report link is unavailable"):
            resolve_report_token(session, "wrong" if action == "invalid" else token)
        if action != "revoked": token = issue_report_token(session, visit)


def test_report_page_is_escaped_isolated_and_responsive():
    session = make_session(); token = issue_report_token(session, seed(session)); session.commit(); client = client_for(session)
    response = client.get(f"/report/{token}")
    assert response.status_code == 200
    assert "<script>alert(1)</script>" not in response.text and "&lt;script&gt;" in response.text
    assert "manager" not in response.text.lower() and "viewport" in response.text
    assert "csrf_token" in response.text and response.cookies.get("report_csrf")


def test_invalid_links_have_same_neutral_response():
    session = make_session(); token = issue_report_token(session, seed(session)); close_report_token(session, token); session.commit()
    client = client_for(session)
    invalid = client.get("/report/not-a-token"); closed = client.get(f"/report/{token}")
    assert invalid.status_code == closed.status_code == 404 and invalid.text == closed.text


def test_post_requires_csrf_and_structured_fields_then_completes_atomically():
    session = make_session(); visit = seed(session); token = issue_report_token(session, visit); session.commit(); client = client_for(session)
    page = client.get(f"/report/{token}")
    csrf = page.cookies["report_csrf"]
    base = {"csrf_token": csrf, "status": "Completed", "duration_minutes": "45", "work_performed": "Replaced camera", "materials_used": "Camera", "follow_up_notes": ""}
    assert client.post(f"/report/{token}", data={**base, "csrf_token": "bad"}).status_code == 403
    for field in ("duration_minutes", "work_performed"):
        assert client.post(f"/report/{token}", data={**base, field: ""}).status_code == 422
    response = client.post(f"/report/{token}", data=base)
    assert response.status_code == 200 and "Report submitted" in response.text
    session.refresh(visit)
    assert (visit.status, visit.job.status, visit.duration_minutes) == ("Completed", "Completed", 45)
    assert session.query(Notification).filter_by(visit_id=visit.id).count() == 1
    assert session.query(ActivityEntry).filter_by(job_id=visit.job_id, event_type="technician_report").count() == 1
    assert session.query(CalendarOutbox).filter_by(visit_id=visit.id, status="pending").count() == 1
    stored = session.query(ReportToken).filter_by(token_hash=sha256(token.encode()).hexdigest()).one()
    assert stored.closed_at is not None


def test_two_gets_do_not_invalidate_first_form_csrf():
    session = make_session(); visit = seed(session); token = issue_report_token(session, visit); session.commit(); client = client_for(session)
    first = client.get(f"/report/{token}"); first_csrf = first.cookies["report_csrf"]
    second = client.get(f"/report/{token}")
    assert second.cookies["report_csrf"] == first_csrf
    response = client.post(f"/report/{token}", data={
        "csrf_token": first_csrf, "status": "Completed", "duration_minutes": "20",
        "work_performed": "Tested system", "materials_used": "None", "follow_up_notes": "None",
    })
    assert response.status_code == 200
