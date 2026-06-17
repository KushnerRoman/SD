# SD Jobber Operations Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the SD Operations Core MVP: Outlook-style email intake, inbox triage, job/visit creation, operations dashboard, and technician visit updates.

**Architecture:** Extend the existing FastAPI backend and Flutter app rather than replacing them. Add focused backend units for email intake, matching, triage actions, and activity logging; then expose those through repository methods and an SD Inbox screen in Flutter.

**Tech Stack:** Python 3.12, FastAPI, SQLAlchemy, Pydantic, pytest, Flutter/Dart, Material 3, package:http, flutter_test.

---

## File Structure

Backend files to modify:
- `backend/app/models.py` - Add EmailMessage, Request, Contact, PartNeed, Attachment, ActivityLog, and sync metadata models.
- `backend/app/schemas.py` - Add Pydantic schemas for inbox records, triage actions, activity logs, expanded dashboard summary, and visit scheduling.
- `backend/app/main.py` - Add API endpoints for inbox, triage, activity, schedule-first visit creation, and expanded dashboard counts.
- `backend/app/seed_loader.py` - Load email/request/activity seed data from the existing seed file when present.
- `backend/tests/test_api.py` - Add API tests for inbox listing, deduplication, triage actions, and dashboard email counts.
- `backend/tests/test_email_matching.py` - Create unit tests for deterministic site/contact/job matching.
- `backend/app/email_matching.py` - Create deterministic matching helpers that return scored suggestions.
- `backend/app/outlook_intake.py` - Create provider-agnostic normalization and deduplication helpers for Microsoft Graph message payloads.

Flutter files to modify:
- `app/security_depot_fsm/lib/domain/models.dart` - Add EmailMessage, EmailTriageStatus, EmailSuggestion, and ActivityLog domain models; expand DashboardSummary.
- `app/security_depot_fsm/lib/data/field_service_repository.dart` - Add inbox and triage repository methods.
- `app/security_depot_fsm/lib/data/api_field_service_repository.dart` - Map backend inbox endpoints into Dart models.
- `app/security_depot_fsm/lib/data/mock_field_service_repository.dart` - Add in-memory inbox data and triage behavior.
- `app/security_depot_fsm/lib/data/seed_field_service_repository.dart` - Add seed-backed inbox data where seed records exist.
- `app/security_depot_fsm/lib/main.dart` - Add SD Inbox to the navigation rail/bar.
- `app/security_depot_fsm/lib/features/dashboard/dashboard_screen.dart` - Show untriaged emails and review counts.
- `app/security_depot_fsm/lib/features/inbox/inbox_screen.dart` - Create SD Inbox triage UI.
- `app/security_depot_fsm/test/api_repository_test.dart` - Add API mapping tests for email inbox.
- `app/security_depot_fsm/test/domain_models_test.dart` - Add domain model tests for email status labels.
- `app/security_depot_fsm/test/widget_test.dart` - Add navigation smoke test for SD Inbox.

Docs:
- `docs/superpowers/specs/2026-06-17-sd-jobber-operations-core-design.md` - Reference only; do not rewrite during implementation unless requirements change.

---

### Task 1: Backend Email Intake Models

**Files:**
- Modify: `backend/app/models.py`
- Modify: `backend/app/schemas.py`
- Test: `backend/tests/test_api.py`

- [ ] **Step 1: Write the failing API model test**

Append this test to `backend/tests/test_api.py`:

```python
def test_api_lists_email_inbox_records():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    def override_session() -> Generator[Session, None, None]:
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_session] = override_session
    try:
        client = TestClient(app)
        response = client.post(
            "/inbox/emails",
            json={
                "provider": "outlook",
                "provider_message_id": "msg-001",
                "conversation_id": "conv-001",
                "internet_message_id": "<msg-001@customer.test>",
                "sender_name": "Jordan Customer",
                "sender_email": "jordan@example.com",
                "recipients": "service@securitydepot.test",
                "subject": "Camera offline at 100 Main",
                "received_at": "2026-06-17T14:00:00",
                "body_preview": "The lobby camera is offline.",
                "body_text": "The lobby camera is offline at 100 Main Street.",
                "attachment_count": 0,
            },
        )
        assert response.status_code == 200
        assert response.json()["triage_status"] == "Untriaged"

        inbox = client.get("/inbox/emails")
        assert inbox.status_code == 200
        assert len(inbox.json()) == 1
        assert inbox.json()[0]["subject"] == "Camera offline at 100 Main"
        assert inbox.json()[0]["sender_email"] == "jordan@example.com"
    finally:
        app.dependency_overrides.clear()
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
cd backend
uv run pytest tests/test_api.py::test_api_lists_email_inbox_records -v
```

Expected: FAIL with 404 for `POST /inbox/emails` or missing model/schema errors.

- [ ] **Step 3: Add backend models**

In `backend/app/models.py`, update the imports:

```python
from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
```

Add these classes after `CalendarDetail`:

```python
class EmailMessage(Base):
    __tablename__ = "email_messages"
    __table_args__ = (
        UniqueConstraint("provider", "provider_message_id", name="uq_email_provider_message"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    provider: Mapped[str] = mapped_column(String(64), default="outlook", index=True)
    provider_message_id: Mapped[str] = mapped_column(String(255), index=True)
    conversation_id: Mapped[str] = mapped_column(String(255), default="", index=True)
    internet_message_id: Mapped[str] = mapped_column(String(255), default="")
    sender_name: Mapped[str] = mapped_column(String(255), default="")
    sender_email: Mapped[str] = mapped_column(String(255), default="", index=True)
    recipients: Mapped[str] = mapped_column(Text, default="")
    subject: Mapped[str] = mapped_column(String(500), default="", index=True)
    received_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    body_preview: Mapped[str] = mapped_column(Text, default="")
    body_text: Mapped[str] = mapped_column(Text, default="")
    attachment_count: Mapped[int] = mapped_column(Integer, default=0)
    triage_status: Mapped[str] = mapped_column(String(64), default="Untriaged", index=True)
    suggested_site_id: Mapped[str | None] = mapped_column(String(64), ForeignKey("sites.id"), nullable=True)
    linked_site_id: Mapped[str | None] = mapped_column(String(64), ForeignKey("sites.id"), nullable=True)
    linked_job_id: Mapped[str | None] = mapped_column(String(64), ForeignKey("jobs.id"), nullable=True)
    linked_visit_id: Mapped[str | None] = mapped_column(String(64), ForeignKey("visits.id"), nullable=True)
    linked_technician_id: Mapped[str | None] = mapped_column(String(64), ForeignKey("technicians.id"), nullable=True)
    needs_manual_review: Mapped[bool] = mapped_column(Boolean, default=False)


class ActivityLog(Base):
    __tablename__ = "activity_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    entity_type: Mapped[str] = mapped_column(String(64), index=True)
    entity_id: Mapped[str] = mapped_column(String(255), index=True)
    action: Mapped[str] = mapped_column(String(255))
    detail: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
```

- [ ] **Step 4: Add backend schemas**

In `backend/app/schemas.py`, add these classes before `DashboardSummary`:

```python
class EmailMessageCreate(BaseModel):
    provider: str = "outlook"
    provider_message_id: str
    conversation_id: str = ""
    internet_message_id: str = ""
    sender_name: str = ""
    sender_email: str = ""
    recipients: str = ""
    subject: str = ""
    received_at: datetime | None = None
    body_preview: str = ""
    body_text: str = ""
    attachment_count: int = 0


class EmailMessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    provider: str
    provider_message_id: str
    conversation_id: str
    internet_message_id: str
    sender_name: str
    sender_email: str
    recipients: str
    subject: str
    received_at: datetime | None
    body_preview: str
    body_text: str
    attachment_count: int
    triage_status: str
    suggested_site_id: str | None
    linked_site_id: str | None
    linked_job_id: str | None
    linked_visit_id: str | None
    linked_technician_id: str | None
    needs_manual_review: bool


class ActivityLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    entity_type: str
    entity_id: str
    action: str
    detail: str
    created_at: datetime
```

- [ ] **Step 5: Add inbox create/list endpoints**

In `backend/app/main.py`, extend imports:

```python
from sqlalchemy.exc import IntegrityError
from app.models import ActivityLog, EmailMessage, Job, Site, Technician, Visit
from app.schemas import ActivityLogOut, DashboardSummary, EmailMessageCreate, EmailMessageOut, JobCreate, JobOut, JobUpdate, SiteCreate, SiteOut, SiteUpdate, TechnicianCreate, TechnicianOut, TechnicianUpdate, VisitCreate, VisitOut, VisitUpdate
```

Add these endpoints after `load_seed`:

```python
@app.get("/inbox/emails", response_model=list[EmailMessageOut])
def list_email_inbox(session: Session = Depends(get_session)) -> list[EmailMessage]:
    return list(session.scalars(select(EmailMessage).order_by(EmailMessage.received_at.desc(), EmailMessage.id.desc())))


@app.post("/inbox/emails", response_model=EmailMessageOut)
def create_email_message(payload: EmailMessageCreate, session: Session = Depends(get_session)) -> EmailMessage:
    existing = session.scalar(
        select(EmailMessage).where(
            EmailMessage.provider == payload.provider,
            EmailMessage.provider_message_id == payload.provider_message_id,
        )
    )
    if existing is not None:
        return existing

    message = EmailMessage(**payload.model_dump())
    session.add(message)
    session.flush()
    session.add(ActivityLog(
        entity_type="EmailMessage",
        entity_id=str(message.id),
        action="email_received",
        detail=f"{message.sender_email}: {message.subject}",
    ))
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        duplicate = session.scalar(
            select(EmailMessage).where(
                EmailMessage.provider == payload.provider,
                EmailMessage.provider_message_id == payload.provider_message_id,
            )
        )
        if duplicate is None:
            raise
        return duplicate
    session.refresh(message)
    return message
```

- [ ] **Step 6: Run test to verify it passes**

Run:

```powershell
cd backend
uv run pytest tests/test_api.py::test_api_lists_email_inbox_records -v
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add backend/app/models.py backend/app/schemas.py backend/app/main.py backend/tests/test_api.py
git commit -m "feat: add email inbox backend models"
```

---

### Task 2: Outlook Normalization and Deduplication

**Files:**
- Create: `backend/app/outlook_intake.py`
- Test: `backend/tests/test_outlook_intake.py`

- [ ] **Step 1: Write failing normalization tests**

Create `backend/tests/test_outlook_intake.py`:

```python
from app.outlook_intake import normalize_graph_message


def test_normalize_graph_message_extracts_operational_fields():
    payload = {
        "id": "AAMk-test",
        "conversationId": "conv-test",
        "internetMessageId": "<internet@test>",
        "subject": "Door reader down",
        "receivedDateTime": "2026-06-17T14:00:00Z",
        "bodyPreview": "Reader at front door stopped working.",
        "body": {"content": "<p>Reader at front door stopped working.</p>"},
        "from": {"emailAddress": {"name": "Alex Client", "address": "alex@client.test"}},
        "toRecipients": [
            {"emailAddress": {"name": "Service", "address": "service@securitydepot.test"}}
        ],
        "hasAttachments": True,
    }

    normalized = normalize_graph_message(payload)

    assert normalized["provider"] == "outlook"
    assert normalized["provider_message_id"] == "AAMk-test"
    assert normalized["conversation_id"] == "conv-test"
    assert normalized["sender_name"] == "Alex Client"
    assert normalized["sender_email"] == "alex@client.test"
    assert normalized["recipients"] == "service@securitydepot.test"
    assert normalized["subject"] == "Door reader down"
    assert normalized["body_preview"] == "Reader at front door stopped working."
    assert normalized["body_text"] == "Reader at front door stopped working."
    assert normalized["attachment_count"] == 1
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
cd backend
uv run pytest tests/test_outlook_intake.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'app.outlook_intake'`.

- [ ] **Step 3: Implement normalization helper**

Create `backend/app/outlook_intake.py`:

```python
from __future__ import annotations

import re
from html import unescape
from typing import Any


def normalize_graph_message(payload: dict[str, Any]) -> dict[str, Any]:
    sender = payload.get("from", {}).get("emailAddress", {}) or {}
    recipients = payload.get("toRecipients", []) or []
    recipient_addresses = [
        item.get("emailAddress", {}).get("address", "")
        for item in recipients
        if item.get("emailAddress", {}).get("address")
    ]
    body_content = (payload.get("body", {}) or {}).get("content", "")

    return {
        "provider": "outlook",
        "provider_message_id": str(payload.get("id", "")),
        "conversation_id": str(payload.get("conversationId", "")),
        "internet_message_id": str(payload.get("internetMessageId", "")),
        "sender_name": str(sender.get("name", "")),
        "sender_email": str(sender.get("address", "")).lower(),
        "recipients": ", ".join(address.lower() for address in recipient_addresses),
        "subject": str(payload.get("subject", "")),
        "received_at": _normalize_datetime(payload.get("receivedDateTime")),
        "body_preview": str(payload.get("bodyPreview", "")),
        "body_text": _html_to_text(body_content),
        "attachment_count": 1 if payload.get("hasAttachments") else 0,
    }


def _normalize_datetime(value: Any) -> str | None:
    if not value:
        return None
    text = str(value)
    return text.replace("Z", "+00:00")


def _html_to_text(value: str) -> str:
    without_tags = re.sub(r"<[^>]+>", " ", value)
    collapsed = re.sub(r"\s+", " ", unescape(without_tags)).strip()
    return collapsed
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
cd backend
uv run pytest tests/test_outlook_intake.py -v
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add backend/app/outlook_intake.py backend/tests/test_outlook_intake.py
git commit -m "feat: normalize outlook email payloads"
```

---

### Task 3: Deterministic Email Matching

**Files:**
- Create: `backend/app/email_matching.py`
- Test: `backend/tests/test_email_matching.py`

- [ ] **Step 1: Write failing matching tests**

Create `backend/tests/test_email_matching.py`:

```python
from app.email_matching import EmailCandidate, SiteCandidate, suggest_site_matches


def test_suggest_site_matches_scores_address_and_name():
    email = EmailCandidate(
        sender_email="manager@acme.test",
        subject="Front camera offline at 100 Main",
        body_text="Please repair the lobby camera at 100 Main Street.",
    )
    sites = [
        SiteCandidate(id="site_main", name="100 Main", address="100 Main Street", slack_channel="#100-main"),
        SiteCandidate(id="site_oak", name="Oak Plaza", address="9 Oak Road", slack_channel="#oak"),
    ]

    matches = suggest_site_matches(email, sites)

    assert matches[0].site_id == "site_main"
    assert matches[0].score >= 70
    assert "address" in matches[0].reasons


def test_suggest_site_matches_returns_empty_for_low_confidence():
    email = EmailCandidate(
        sender_email="unknown@example.test",
        subject="Question",
        body_text="Can someone call me back?",
    )
    sites = [SiteCandidate(id="site_oak", name="Oak Plaza", address="9 Oak Road", slack_channel="#oak")]

    assert suggest_site_matches(email, sites) == []
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
cd backend
uv run pytest tests/test_email_matching.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'app.email_matching'`.

- [ ] **Step 3: Implement matcher**

Create `backend/app/email_matching.py`:

```python
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class EmailCandidate:
    sender_email: str
    subject: str
    body_text: str


@dataclass(frozen=True)
class SiteCandidate:
    id: str
    name: str
    address: str
    slack_channel: str = ""


@dataclass(frozen=True)
class SiteMatch:
    site_id: str
    score: int
    reasons: tuple[str, ...]


def suggest_site_matches(email: EmailCandidate, sites: list[SiteCandidate], *, minimum_score: int = 40) -> list[SiteMatch]:
    haystack = _normalize(" ".join([email.sender_email, email.subject, email.body_text]))
    matches: list[SiteMatch] = []

    for site in sites:
        score = 0
        reasons: list[str] = []
        name = _normalize(site.name)
        address = _normalize(site.address)
        slack = _normalize(site.slack_channel.replace("#", " "))

        if name and name in haystack:
            score += 45
            reasons.append("site_name")
        if address and address in haystack:
            score += 70
            reasons.append("address")
        if slack and slack in haystack:
            score += 25
            reasons.append("slack_channel")

        street_number = address.split(" ", 1)[0] if address else ""
        if street_number and len(street_number) >= 2 and street_number in haystack and "address" not in reasons:
            score += 15
            reasons.append("partial_address")

        if score >= minimum_score:
            matches.append(SiteMatch(site_id=site.id, score=score, reasons=tuple(reasons)))

    return sorted(matches, key=lambda match: match.score, reverse=True)


def _normalize(value: str) -> str:
    return " ".join(value.lower().replace(",", " ").replace(".", " ").split())
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
cd backend
uv run pytest tests/test_email_matching.py -v
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add backend/app/email_matching.py backend/tests/test_email_matching.py
git commit -m "feat: add deterministic email site matching"
```

---

### Task 4: Inbox Triage API

**Files:**
- Modify: `backend/app/schemas.py`
- Modify: `backend/app/main.py`
- Test: `backend/tests/test_api.py`

- [ ] **Step 1: Write failing triage test**

Append this test to `backend/tests/test_api.py`:

```python
def test_api_links_email_to_site_and_creates_job():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    def override_session() -> Generator[Session, None, None]:
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_session] = override_session
    try:
        client = TestClient(app)
        site_response = client.post(
            "/sites",
            json={"id": "site_main", "name": "100 Main", "address": "100 Main Street"},
        )
        assert site_response.status_code == 200
        email_response = client.post(
            "/inbox/emails",
            json={
                "provider_message_id": "msg-triage-001",
                "sender_email": "manager@client.test",
                "subject": "Camera offline",
                "body_text": "Camera offline at 100 Main Street.",
                "received_at": "2026-06-17T14:00:00",
            },
        )
        email_id = email_response.json()["id"]

        link_response = client.post(
            f"/inbox/emails/{email_id}/triage",
            json={"action": "create_job", "site_id": "site_main", "technician_id": "tech_roman"},
        )

        assert link_response.status_code == 200
        updated_email = link_response.json()["email"]
        created_job = link_response.json()["job"]
        assert updated_email["triage_status"] == "Job Candidate"
        assert updated_email["linked_site_id"] == "site_main"
        assert updated_email["linked_job_id"] == created_job["id"]
        assert created_job["site_id"] == "site_main"
        assert created_job["title"] == "Camera offline"
    finally:
        app.dependency_overrides.clear()
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
cd backend
uv run pytest tests/test_api.py::test_api_links_email_to_site_and_creates_job -v
```

Expected: FAIL with 404 for `/inbox/emails/{id}/triage`.

- [ ] **Step 3: Add triage schemas**

In `backend/app/schemas.py`, add:

```python
class EmailTriageAction(BaseModel):
    action: str
    site_id: str | None = None
    job_id: str | None = None
    visit_id: str | None = None
    technician_id: str | None = None


class EmailTriageResult(BaseModel):
    email: EmailMessageOut
    job: JobOut | None = None
    visit: VisitOut | None = None
```

- [ ] **Step 4: Add triage endpoint**

In `backend/app/main.py`, add imports:

```python
from datetime import datetime
from app.schemas import EmailTriageAction, EmailTriageResult
```

Add this endpoint after `create_email_message`:

```python
@app.post("/inbox/emails/{email_id}/triage", response_model=EmailTriageResult)
def triage_email(email_id: int, payload: EmailTriageAction, session: Session = Depends(get_session)) -> EmailTriageResult:
    email = session.get(EmailMessage, email_id)
    if email is None:
        raise HTTPException(status_code=404, detail="Email not found")

    created_job: Job | None = None
    created_visit: Visit | None = None

    if payload.site_id and session.get(Site, payload.site_id) is None:
        raise HTTPException(status_code=404, detail="Site not found")
    if payload.technician_id and session.get(Technician, payload.technician_id) is None:
        payload.technician_id = None

    email.linked_site_id = payload.site_id or email.linked_site_id
    email.linked_technician_id = payload.technician_id or email.linked_technician_id

    if payload.action == "link_site":
        email.triage_status = "Matched to Site"
    elif payload.action == "ignore":
        email.triage_status = "Ignored"
    elif payload.action == "link_job":
        if not payload.job_id or session.get(Job, payload.job_id) is None:
            raise HTTPException(status_code=404, detail="Job not found")
        email.linked_job_id = payload.job_id
        email.triage_status = "Linked to Existing Job"
    elif payload.action == "create_job":
        job_id = f"job_email_{email.id}"
        existing_job = session.get(Job, job_id)
        if existing_job is None:
            site = session.get(Site, payload.site_id) if payload.site_id else None
            created_job = Job(
                id=job_id,
                site_id=site.id if site else None,
                site_name=site.name if site else "",
                job_number="",
                title=email.subject or "Email request",
                job_type="Service Call",
                priority="Medium",
                status="New",
                assigned_technician_id=payload.technician_id,
                first_seen_date=_date_text(email.received_at),
                last_seen_date=_date_text(email.received_at),
                description=email.body_preview or email.body_text,
                details=email.body_text or email.body_preview,
                needs_parts=False,
                needs_return_visit=False,
                needs_manager_review=False,
                confidence="email_triage",
            )
            session.add(created_job)
        else:
            created_job = existing_job
        email.linked_job_id = job_id
        email.triage_status = "Job Candidate"
    else:
        raise HTTPException(status_code=400, detail="Unsupported triage action")

    session.add(ActivityLog(
        entity_type="EmailMessage",
        entity_id=str(email.id),
        action=f"triage_{payload.action}",
        detail=f"site={email.linked_site_id or ''} job={email.linked_job_id or ''}",
    ))
    session.commit()
    session.refresh(email)
    if created_job is not None:
        session.refresh(created_job)
    if created_visit is not None:
        session.refresh(created_visit)
    return EmailTriageResult(email=email, job=created_job, visit=created_visit)
```

Add helper near `_normalize_name` or at the bottom:

```python
def _date_text(value: datetime | None) -> str:
    return value.date().isoformat() if value else ""
```

- [ ] **Step 5: Run test to verify it passes**

Run:

```powershell
cd backend
uv run pytest tests/test_api.py::test_api_links_email_to_site_and_creates_job -v
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add backend/app/schemas.py backend/app/main.py backend/tests/test_api.py
git commit -m "feat: add email triage actions"
```

---

### Task 5: Expanded Dashboard Counts

**Files:**
- Modify: `backend/app/schemas.py`
- Modify: `backend/app/main.py`
- Test: `backend/tests/test_api.py`

- [ ] **Step 1: Write failing dashboard test**

Append this test to `backend/tests/test_api.py`:

```python
def test_dashboard_summary_includes_email_attention_counts():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    def override_session() -> Generator[Session, None, None]:
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_session] = override_session
    try:
        client = TestClient(app)
        client.post("/inbox/emails", json={"provider_message_id": "msg-open", "subject": "Open"})
        client.post("/inbox/emails", json={"provider_message_id": "msg-review", "subject": "Review"})
        review_email_id = client.get("/inbox/emails").json()[0]["id"]
        client.post(f"/inbox/emails/{review_email_id}/triage", json={"action": "ignore"})

        summary = client.get("/dashboard/summary")

        assert summary.status_code == 200
        assert summary.json()["untriaged_emails"] == 1
        assert "needs_return_visit" in summary.json()
    finally:
        app.dependency_overrides.clear()
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
cd backend
uv run pytest tests/test_api.py::test_dashboard_summary_includes_email_attention_counts -v
```

Expected: FAIL because `untriaged_emails` is missing.

- [ ] **Step 3: Expand DashboardSummary schema**

In `backend/app/schemas.py`, change `DashboardSummary` to:

```python
class DashboardSummary(BaseModel):
    total_jobs: int
    open_jobs: int
    new_jobs: int
    in_progress: int
    waiting_parts: int
    completed: int
    needs_manager_review: int
    needs_return_visit: int = 0
    untriaged_emails: int = 0
    needs_site_match: int = 0
```

- [ ] **Step 4: Expand dashboard endpoint**

In `backend/app/main.py`, update `dashboard_summary` return:

```python
    return DashboardSummary(
        total_jobs=total_jobs,
        open_jobs=total_jobs - completed,
        new_jobs=_count_status(session, "New"),
        in_progress=_count_status(session, "In Progress"),
        waiting_parts=_count_status(session, "Waiting for Parts") + _count_status(session, "Waiting Parts"),
        completed=completed,
        needs_manager_review=_count_status(session, "Need Manager Review") + _count_status(session, "Manager Review"),
        needs_return_visit=_count_status(session, "Need Return Visit"),
        untriaged_emails=session.scalar(select(func.count()).select_from(EmailMessage).where(EmailMessage.triage_status == "Untriaged")) or 0,
        needs_site_match=session.scalar(select(func.count()).select_from(Visit).where(Visit.site_id.is_(None))) or 0,
    )
```

- [ ] **Step 5: Run test to verify it passes**

Run:

```powershell
cd backend
uv run pytest tests/test_api.py::test_dashboard_summary_includes_email_attention_counts -v
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add backend/app/schemas.py backend/app/main.py backend/tests/test_api.py
git commit -m "feat: add operations attention counts"
```

---

### Task 6: Flutter Domain and Repository Contract

**Files:**
- Modify: `app/security_depot_fsm/lib/domain/models.dart`
- Modify: `app/security_depot_fsm/lib/data/field_service_repository.dart`
- Test: `app/security_depot_fsm/test/domain_models_test.dart`

- [ ] **Step 1: Write failing domain test**

Append this test to `app/security_depot_fsm/test/domain_models_test.dart`:

```dart
test('email triage status labels match operations workflow', () {
  expect(EmailTriageStatus.untriaged.label, 'Untriaged');
  expect(EmailTriageStatus.matchedToSite.label, 'Matched to Site');
  expect(EmailTriageStatus.jobCandidate.label, 'Job Candidate');
  expect(EmailTriageStatus.linkedToExistingJob.label, 'Linked to Existing Job');
  expect(EmailTriageStatus.ignored.label, 'Ignored');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
cd app/security_depot_fsm
flutter test test/domain_models_test.dart
```

Expected: FAIL because `EmailTriageStatus` is not defined.

- [ ] **Step 3: Add Dart domain models**

In `app/security_depot_fsm/lib/domain/models.dart`, add after `JobSource`:

```dart
enum EmailTriageStatus {
  untriaged,
  needsReview,
  matchedToSite,
  jobCandidate,
  linkedToExistingJob,
  linkedToVisit,
  ignored,
}

extension EmailTriageStatusLabel on EmailTriageStatus {
  String get label => switch (this) {
        EmailTriageStatus.untriaged => 'Untriaged',
        EmailTriageStatus.needsReview => 'Needs Review',
        EmailTriageStatus.matchedToSite => 'Matched to Site',
        EmailTriageStatus.jobCandidate => 'Job Candidate',
        EmailTriageStatus.linkedToExistingJob => 'Linked to Existing Job',
        EmailTriageStatus.linkedToVisit => 'Linked to Visit',
        EmailTriageStatus.ignored => 'Ignored',
      };
}
```

Add after `Site`:

```dart
class EmailMessage {
  const EmailMessage({
    required this.id,
    required this.senderName,
    required this.senderEmail,
    required this.subject,
    required this.receivedAt,
    required this.bodyPreview,
    required this.status,
    this.linkedSiteId,
    this.linkedJobId,
    this.linkedVisitId,
    this.linkedTechnicianId,
  });

  final int id;
  final String senderName;
  final String senderEmail;
  final String subject;
  final DateTime? receivedAt;
  final String bodyPreview;
  final EmailTriageStatus status;
  final String? linkedSiteId;
  final String? linkedJobId;
  final String? linkedVisitId;
  final String? linkedTechnicianId;

  EmailMessage copyWith({
    EmailTriageStatus? status,
    String? linkedSiteId,
    String? linkedJobId,
    String? linkedVisitId,
    String? linkedTechnicianId,
  }) {
    return EmailMessage(
      id: id,
      senderName: senderName,
      senderEmail: senderEmail,
      subject: subject,
      receivedAt: receivedAt,
      bodyPreview: bodyPreview,
      status: status ?? this.status,
      linkedSiteId: linkedSiteId ?? this.linkedSiteId,
      linkedJobId: linkedJobId ?? this.linkedJobId,
      linkedVisitId: linkedVisitId ?? this.linkedVisitId,
      linkedTechnicianId: linkedTechnicianId ?? this.linkedTechnicianId,
    );
  }
}
```

- [ ] **Step 4: Expand repository contract**

In `app/security_depot_fsm/lib/data/field_service_repository.dart`, update `DashboardSummary`:

```dart
class DashboardSummary {
  const DashboardSummary({
    required this.newJobs,
    required this.inProgress,
    required this.waitingParts,
    required this.completed,
    this.needsReturnVisit = 0,
    this.untriagedEmails = 0,
    this.needsSiteMatch = 0,
  });

  final int newJobs;
  final int inProgress;
  final int waitingParts;
  final int completed;
  final int needsReturnVisit;
  final int untriagedEmails;
  final int needsSiteMatch;
}
```

Add methods to `FieldServiceRepository`:

```dart
  Future<List<EmailMessage>> getEmailInbox();

  Future<void> triageEmail({
    required int emailId,
    required String action,
    String? siteId,
    String? jobId,
    String? visitId,
    String? technicianId,
  });
```

- [ ] **Step 5: Run test to verify it passes**

Run:

```powershell
cd app/security_depot_fsm
flutter test test/domain_models_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add app/security_depot_fsm/lib/domain/models.dart app/security_depot_fsm/lib/data/field_service_repository.dart app/security_depot_fsm/test/domain_models_test.dart
git commit -m "feat: add email inbox domain models"
```

---

### Task 7: Flutter API Repository Email Mapping

**Files:**
- Modify: `app/security_depot_fsm/lib/data/api_field_service_repository.dart`
- Test: `app/security_depot_fsm/test/api_repository_test.dart`

- [ ] **Step 1: Write failing API repository test**

Append this test to `app/security_depot_fsm/test/api_repository_test.dart`:

```dart
test('API repository maps email inbox records', () async {
  final client = _FakeClient((request) async {
    if (request.url.path == '/inbox/emails') {
      return http.Response(jsonEncode([
        {
          'id': 7,
          'sender_name': 'Jordan Customer',
          'sender_email': 'jordan@example.com',
          'subject': 'Camera offline',
          'received_at': '2026-06-17T14:00:00',
          'body_preview': 'Lobby camera offline',
          'triage_status': 'Untriaged',
          'linked_site_id': null,
          'linked_job_id': null,
          'linked_visit_id': null,
          'linked_technician_id': null
        }
      ]), 200);
    }
    return http.Response('{}', 404);
  });
  final repository = ApiFieldServiceRepository(
    baseUrl: Uri.parse('http://localhost:8000'),
    client: client,
  );

  final inbox = await repository.getEmailInbox();

  expect(inbox.single.id, 7);
  expect(inbox.single.subject, 'Camera offline');
  expect(inbox.single.status, EmailTriageStatus.untriaged);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
cd app/security_depot_fsm
flutter test test/api_repository_test.dart
```

Expected: FAIL because `getEmailInbox` is not implemented.

- [ ] **Step 3: Implement API repository methods**

In `ApiFieldServiceRepository.getDashboardSummary`, include new fields:

```dart
      needsReturnVisit: _readInt(json, 'needs_return_visit'),
      untriagedEmails: _readInt(json, 'untriaged_emails'),
      needsSiteMatch: _readInt(json, 'needs_site_match'),
```

Add methods inside `ApiFieldServiceRepository`:

```dart
  @override
  Future<List<EmailMessage>> getEmailInbox() async {
    final json = await _getList('/inbox/emails');
    return json.map(_emailMessageFromJson).toList();
  }

  @override
  Future<void> triageEmail({
    required int emailId,
    required String action,
    String? siteId,
    String? jobId,
    String? visitId,
    String? technicianId,
  }) async {
    final response = await _client.post(
      baseUrl.resolve('/inbox/emails/$emailId/triage'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'action': action,
        if (siteId != null) 'site_id': siteId,
        if (jobId != null) 'job_id': jobId,
        if (visitId != null) 'visit_id': visitId,
        if (technicianId != null) 'technician_id': technicianId,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'API POST /inbox/emails/$emailId/triage failed: ${response.statusCode} ${response.body}');
    }
  }
```

Add helper functions near other JSON mappers:

```dart
EmailMessage _emailMessageFromJson(Map<String, dynamic> json) {
  return EmailMessage(
    id: _readInt(json, 'id'),
    senderName: _readString(json, 'sender_name'),
    senderEmail: _readString(json, 'sender_email'),
    subject: _readString(json, 'subject'),
    receivedAt: _dateTimeOrNull(_readString(json, 'received_at')),
    bodyPreview: _readString(json, 'body_preview'),
    status: _emailStatusFromText(_readString(json, 'triage_status')),
    linkedSiteId: _nullableString(json, 'linked_site_id'),
    linkedJobId: _nullableString(json, 'linked_job_id'),
    linkedVisitId: _nullableString(json, 'linked_visit_id'),
    linkedTechnicianId: _nullableString(json, 'linked_technician_id'),
  );
}

EmailTriageStatus _emailStatusFromText(String value) {
  return EmailTriageStatus.values.firstWhere(
    (status) => status.label.toLowerCase() == value.toLowerCase(),
    orElse: () => EmailTriageStatus.needsReview,
  );
}

DateTime? _dateTimeOrNull(String value) {
  if (value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value.toString().isEmpty) return null;
  return value.toString();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
cd app/security_depot_fsm
flutter test test/api_repository_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add app/security_depot_fsm/lib/data/api_field_service_repository.dart app/security_depot_fsm/test/api_repository_test.dart
git commit -m "feat: map email inbox API in Flutter"
```

---

### Task 8: Flutter Mock and Seed Repository Support

**Files:**
- Modify: `app/security_depot_fsm/lib/data/mock_field_service_repository.dart`
- Modify: `app/security_depot_fsm/lib/data/seed_field_service_repository.dart`
- Test: `app/security_depot_fsm/test/repository_test.dart`
- Test: `app/security_depot_fsm/test/seed_repository_test.dart`

- [ ] **Step 1: Write failing repository test**

Append this test to `app/security_depot_fsm/test/repository_test.dart`:

```dart
test('mock repository exposes and triages inbox emails', () async {
  final repository = MockFieldServiceRepository();

  final inbox = await repository.getEmailInbox();
  expect(inbox, isNotEmpty);
  final first = inbox.first;

  await repository.triageEmail(emailId: first.id, action: 'ignore');

  final updated = await repository.getEmailInbox();
  expect(
    updated.firstWhere((email) => email.id == first.id).status,
    EmailTriageStatus.ignored,
  );
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
cd app/security_depot_fsm
flutter test test/repository_test.dart
```

Expected: FAIL because mock repository methods are missing.

- [ ] **Step 3: Implement mock repository inbox**

In `MockFieldServiceRepository`, add a private list field:

```dart
  final List<EmailMessage> _emails = [
    EmailMessage(
      id: 1,
      senderName: 'Jordan Customer',
      senderEmail: 'jordan@example.com',
      subject: 'Camera offline at 100 Main',
      receivedAt: DateTime(2026, 6, 17, 9, 30),
      bodyPreview: 'The lobby camera is offline at 100 Main Street.',
      status: EmailTriageStatus.untriaged,
    ),
  ];
```

Add methods:

```dart
  @override
  Future<List<EmailMessage>> getEmailInbox() async => List.unmodifiable(_emails);

  @override
  Future<void> triageEmail({
    required int emailId,
    required String action,
    String? siteId,
    String? jobId,
    String? visitId,
    String? technicianId,
  }) async {
    final index = _emails.indexWhere((email) => email.id == emailId);
    if (index == -1) return;
    final status = switch (action) {
      'ignore' => EmailTriageStatus.ignored,
      'link_site' => EmailTriageStatus.matchedToSite,
      'link_job' => EmailTriageStatus.linkedToExistingJob,
      'create_job' => EmailTriageStatus.jobCandidate,
      _ => EmailTriageStatus.needsReview,
    };
    _emails[index] = _emails[index].copyWith(
      status: status,
      linkedSiteId: siteId,
      linkedJobId: jobId,
      linkedVisitId: visitId,
      linkedTechnicianId: technicianId,
    );
  }
```

- [ ] **Step 4: Update seed repository minimally**

In `SeedFieldServiceRepository`, add methods that delegate to the same in-memory pattern. If the class already wraps parsed seed data, add:

```dart
  final List<EmailMessage> _emails = [];

  @override
  Future<List<EmailMessage>> getEmailInbox() async => List.unmodifiable(_emails);

  @override
  Future<void> triageEmail({
    required int emailId,
    required String action,
    String? siteId,
    String? jobId,
    String? visitId,
    String? technicianId,
  }) async {
    final index = _emails.indexWhere((email) => email.id == emailId);
    if (index == -1) return;
    final status = action == 'ignore'
        ? EmailTriageStatus.ignored
        : action == 'create_job'
            ? EmailTriageStatus.jobCandidate
            : action == 'link_site'
                ? EmailTriageStatus.matchedToSite
                : EmailTriageStatus.needsReview;
    _emails[index] = _emails[index].copyWith(status: status, linkedSiteId: siteId);
  }
```

If `SeedFieldServiceRepository` already has a constructor, initialize `_emails` with one sample Outlook-like message in that constructor.

- [ ] **Step 5: Run tests to verify they pass**

Run:

```powershell
cd app/security_depot_fsm
flutter test test/repository_test.dart test/seed_repository_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add app/security_depot_fsm/lib/data/mock_field_service_repository.dart app/security_depot_fsm/lib/data/seed_field_service_repository.dart app/security_depot_fsm/test/repository_test.dart
git commit -m "feat: support inbox in local repositories"
```

---

### Task 9: SD Inbox Screen and Navigation

**Files:**
- Create: `app/security_depot_fsm/lib/features/inbox/inbox_screen.dart`
- Modify: `app/security_depot_fsm/lib/main.dart`
- Test: `app/security_depot_fsm/test/widget_test.dart`

- [ ] **Step 1: Write failing navigation widget test**

Append this test to `app/security_depot_fsm/test/widget_test.dart`:

```dart
testWidgets('app shell exposes SD Inbox navigation', (tester) async {
  await tester.pumpWidget(SecurityDepotApp(
    repositoryLoader: Future<FieldServiceRepository>.value(MockFieldServiceRepository()),
  ));
  await tester.pumpAndSettle();

  expect(find.text('Inbox'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
cd app/security_depot_fsm
flutter test test/widget_test.dart
```

Expected: FAIL because Inbox navigation is missing.

- [ ] **Step 3: Create Inbox screen**

Create `app/security_depot_fsm/lib/features/inbox/inbox_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../data/field_service_repository.dart';
import '../../domain/models.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.repository});

  final FieldServiceRepository repository;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late Future<List<EmailMessage>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getEmailInbox();
  }

  Future<void> _triage(EmailMessage email, String action) async {
    await widget.repository.triageEmail(emailId: email.id, action: action);
    if (mounted) {
      setState(() => _future = widget.repository.getEmailInbox());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<EmailMessage>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final emails = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SD Inbox',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Outlook messages waiting to be linked to sites, jobs, visits, or technicians.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.separated(
                    itemCount: emails.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final email = emails[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      email.subject,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                                  ),
                                  Chip(label: Text(email.status.label)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('${email.senderName} <${email.senderEmail}>'),
                              const SizedBox(height: 8),
                              Text(email.bodyPreview, style: const TextStyle(color: Color(0xFF475569))),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilledButton.tonal(
                                    onPressed: () => _triage(email, 'link_site'),
                                    child: const Text('Match Site'),
                                  ),
                                  FilledButton(
                                    onPressed: () => _triage(email, 'create_job'),
                                    child: const Text('Create Job'),
                                  ),
                                  TextButton(
                                    onPressed: () => _triage(email, 'ignore'),
                                    child: const Text('Ignore'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Add navigation**

In `app/security_depot_fsm/lib/main.dart`, add import:

```dart
import 'features/inbox/inbox_screen.dart';
```

Update `screens` to include Inbox after Dashboard:

```dart
      DashboardScreen(repository: widget.repository),
      InboxScreen(repository: widget.repository),
      ScheduleScreen(repository: widget.repository),
      JobsScreen(repository: widget.repository),
      SitesScreen(repository: widget.repository),
      TechniciansScreen(repository: widget.repository),
      VisitUpdateScreen(repository: widget.repository),
```

Add matching `NavigationRailDestination` after Dashboard:

```dart
                    NavigationRailDestination(
                        icon: Icon(Icons.inbox_outlined),
                        label: Text('Inbox')),
```

Add matching mobile `NavigationDestination` after Dashboard:

```dart
                    NavigationDestination(
                        icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
```

- [ ] **Step 5: Run widget test to verify it passes**

Run:

```powershell
cd app/security_depot_fsm
flutter test test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add app/security_depot_fsm/lib/features/inbox/inbox_screen.dart app/security_depot_fsm/lib/main.dart app/security_depot_fsm/test/widget_test.dart
git commit -m "feat: add SD inbox screen"
```

---

### Task 10: Dashboard Operations Attention UI

**Files:**
- Modify: `app/security_depot_fsm/lib/features/dashboard/dashboard_screen.dart`
- Test: `app/security_depot_fsm/test/widget_test.dart`

- [ ] **Step 1: Write failing dashboard widget test**

Append this test to `app/security_depot_fsm/test/widget_test.dart`:

```dart
testWidgets('dashboard shows inbox attention metric', (tester) async {
  await tester.pumpWidget(SecurityDepotApp(
    repositoryLoader: Future<FieldServiceRepository>.value(MockFieldServiceRepository()),
  ));
  await tester.pumpAndSettle();

  expect(find.text('Untriaged Emails'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
cd app/security_depot_fsm
flutter test test/widget_test.dart
```

Expected: FAIL because dashboard does not render `Untriaged Emails`.

- [ ] **Step 3: Add dashboard metric tiles**

In `dashboard_screen.dart`, add these tiles after Waiting Parts:

```dart
                  _MetricTile(
                      label: 'Return Visits',
                      value: summary.needsReturnVisit,
                      color: const Color(0xFF7C3AED)),
                  _MetricTile(
                      label: 'Untriaged Emails',
                      value: summary.untriagedEmails,
                      color: const Color(0xFF0F766E)),
```

Change the subtitle text from:

```dart
subtitle: 'Real-time overview using temporary local data',
```

to:

```dart
subtitle: 'Operations overview for jobs, visits, parts, and Outlook intake',
```

- [ ] **Step 4: Ensure mock summary returns inbox counts**

In `MockFieldServiceRepository.getDashboardSummary`, include:

```dart
      untriagedEmails: _emails.where((email) => email.status == EmailTriageStatus.untriaged).length,
      needsReturnVisit: _jobs.where((job) => job.status == JobStatus.needReturnVisit).length,
      needsSiteMatch: _visits.where((visit) => visit.siteId.isEmpty).length,
```

- [ ] **Step 5: Run widget test to verify it passes**

Run:

```powershell
cd app/security_depot_fsm
flutter test test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add app/security_depot_fsm/lib/features/dashboard/dashboard_screen.dart app/security_depot_fsm/lib/data/mock_field_service_repository.dart app/security_depot_fsm/test/widget_test.dart
git commit -m "feat: show operations attention metrics"
```

---

### Task 11: Full Verification

**Files:**
- No code changes expected.

- [ ] **Step 1: Run backend tests**

Run:

```powershell
cd backend
uv run pytest
```

Expected: all backend tests PASS.

- [ ] **Step 2: Run Flutter tests**

Run:

```powershell
cd app/security_depot_fsm
flutter test
```

Expected: all Flutter tests PASS.

- [ ] **Step 3: Run Flutter analyzer**

Run:

```powershell
cd app/security_depot_fsm
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Start backend**

Run:

```powershell
cd backend
uv run uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Expected: server starts and `/health` returns `{"status":"ok"}`.

- [ ] **Step 5: Run Flutter web**

In a second terminal:

```powershell
cd app/security_depot_fsm
flutter run -d chrome --web-port 3000
```

Expected: app opens at `http://localhost:3000`, navigation includes Dashboard, Inbox, Schedule, Jobs, Sites, Techs, Visit.

- [ ] **Step 6: Manual smoke test**

In the app:
- Open Dashboard and confirm `Untriaged Emails` appears.
- Open Inbox and confirm at least one Outlook-like email appears in seed/mock mode.
- Click `Create Job` on an email.
- Confirm the email status changes to `Job Candidate`.
- Open Jobs and confirm the created job appears when using API-backed mode.

- [ ] **Step 7: Final commit if verification changes documentation or seed data**

If verification required small doc or seed changes:

```powershell
git add <changed-files>
git commit -m "test: verify SD operations core"
```

If no files changed, do not create an empty commit.

---

## Self-Review Notes

Spec coverage:
- Outlook intake is covered by Tasks 1, 2, 4, 5, 7, 9, and 10.
- Email-to-site/job triage is covered by Tasks 3 and 4.
- Operations hub navigation is covered by Task 9.
- Dashboard attention metrics are covered by Task 10.
- Technician visit updates already exist in the codebase and are protected by existing visit tests; this plan does not redesign that screen.
- Quotes, invoices, payments, client portal, AI receptionist, and GPS routing remain out of scope as approved in the spec.

Implementation sequencing:
- Backend API becomes usable before Flutter depends on it.
- Flutter repository contract changes precede UI changes.
- Each task has focused tests and a commit boundary.
