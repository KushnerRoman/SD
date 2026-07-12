from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path

import httpx
from fastapi import Depends, FastAPI, HTTPException
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.database import create_schema, get_session
from app.google.config import GoogleSettings
from app.google.oauth import CredentialCipher, GoogleOAuthService, OAuthStateError
from app.models import EmailMessage, GoogleCredential, Job, Notification, Site, Technician, Visit
from app.schemas import DashboardSummary, DispatchCreate, EmailMessageOut, GoogleConnectionOut, JobCreate, JobOut, JobUpdate, NotificationOut, SiteCreate, SiteOut, SiteUpdate, TechnicianCreate, TechnicianOut, TechnicianReportCreate, TechnicianUpdate, VisitCreate, VisitOut, VisitUpdate
from app.seed_loader import load_seed_file, reset_and_load_seed
from app.workflows import WorkflowConflict, WorkflowValidationError, convert_email_to_service_call, submit_technician_report

app = FastAPI(title="Security Depot FSM Mock API", version="0.1.0")

WEB_BUILD_DIR = Path(__file__).resolve().parents[2] / "app" / "security_depot_fsm" / "build" / "web"

_google_oauth_service: GoogleOAuthService | None = None


def get_google_oauth_service() -> GoogleOAuthService:
    global _google_oauth_service
    if _google_oauth_service is None:
        settings = GoogleSettings.from_env()
        _google_oauth_service = GoogleOAuthService(settings, CredentialCipher(settings.token_encryption_key))
    return _google_oauth_service


@app.on_event("startup")
def startup() -> None:
    create_schema()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/auth/google/start", include_in_schema=False)
def google_auth_start(
    session: Session = Depends(get_session),
    oauth: GoogleOAuthService = Depends(get_google_oauth_service),
) -> RedirectResponse:
    credential = session.query(GoogleCredential).first()
    return RedirectResponse(oauth.authorization_url(has_refresh_token=credential is not None))


@app.get("/auth/google/callback", include_in_schema=False)
def google_auth_callback(
    code: str | None = None,
    state: str | None = None,
    error: str | None = None,
    session: Session = Depends(get_session),
    oauth: GoogleOAuthService = Depends(get_google_oauth_service),
) -> RedirectResponse:
    if error is not None:
        safe_code = "access_denied" if error == "access_denied" else "provider_error"
        return RedirectResponse(f"/web/#/settings?google=error&code={safe_code}")
    if not code or not state:
        return RedirectResponse("/web/#/settings?google=error&code=missing_parameters")
    try:
        tokens = oauth.exchange_code(code=code, state=state)
        refresh_token = tokens.get("refresh_token")
        access_token = tokens.get("access_token")
        existing_credential = session.query(GoogleCredential).first()
        if not refresh_token and existing_credential is not None:
            refresh_token = oauth.load_refresh_token(existing_credential)
        if not refresh_token or not access_token:
            return RedirectResponse("/web/#/settings?google=error&code=incomplete_response")
        account_email = oauth.account_email(access_token)
        expires_at = datetime.utcnow() + timedelta(seconds=int(tokens.get("expires_in", 3600)))
        oauth.store_tokens(
            session,
            account_email=account_email,
            refresh_token=refresh_token,
            expires_at=expires_at,
        )
        return RedirectResponse("/web/#/settings?google=connected")
    except OAuthStateError:
        return RedirectResponse("/web/#/settings?google=error&code=invalid_state")
    except (httpx.HTTPError, ValueError):
        return RedirectResponse("/web/#/settings?google=error&code=exchange_failed")


@app.post("/auth/google/disconnect")
def google_auth_disconnect(
    session: Session = Depends(get_session),
    oauth: GoogleOAuthService = Depends(get_google_oauth_service),
) -> dict[str, str]:
    credential = session.query(GoogleCredential).first()
    if credential is not None:
        token = oauth.load_refresh_token(credential)
        try:
            oauth.revoke(token)
        except httpx.HTTPError:
            pass
        session.delete(credential)
        session.commit()
    return {"status": "disconnected"}


@app.get("/google/connection", response_model=GoogleConnectionOut)
def google_connection(session: Session = Depends(get_session)) -> GoogleConnectionOut:
    credential = session.query(GoogleCredential).first()
    if credential is None:
        return GoogleConnectionOut(status="disconnected")
    status = "expired" if credential.expires_at and credential.expires_at <= datetime.utcnow() else "connected"
    return GoogleConnectionOut(
        status=status,
        account_email=credential.account_email,
        expires_at=credential.expires_at,
    )


@app.get("/", include_in_schema=False)
def web_root() -> RedirectResponse:
    return RedirectResponse(url="/web/")


@app.post("/admin/load-seed")
def load_seed(session: Session = Depends(get_session)) -> dict[str, int]:
    return reset_and_load_seed(session, load_seed_file())


@app.get("/emails", response_model=list[EmailMessageOut])
def list_emails(session: Session = Depends(get_session)) -> list[EmailMessage]:
    return list(session.scalars(select(EmailMessage).order_by(EmailMessage.received_at.desc())))


@app.get("/emails/{email_id}", response_model=EmailMessageOut)
def get_email(email_id: str, session: Session = Depends(get_session)) -> EmailMessage:
    message = session.get(EmailMessage, email_id)
    if message is None:
        raise HTTPException(status_code=404, detail="Email not found")
    return message


@app.post("/dispatch/from-email", response_model=JobOut)
def dispatch_from_email(payload: DispatchCreate, session: Session = Depends(get_session)) -> Job:
    try:
        return convert_email_to_service_call(session, payload)
    except WorkflowConflict as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    except WorkflowValidationError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error


@app.get("/notifications", response_model=list[NotificationOut])
def list_notifications(session: Session = Depends(get_session)) -> list[Notification]:
    return list(session.scalars(select(Notification).order_by(Notification.created_at.desc())))


@app.patch("/notifications/{notification_id}/read", response_model=NotificationOut)
def read_notification(notification_id: int, session: Session = Depends(get_session)) -> Notification:
    notification = session.get(Notification, notification_id)
    if notification is None:
        raise HTTPException(status_code=404, detail="Notification not found")
    notification.is_read = True
    session.commit()
    session.refresh(notification)
    return notification


@app.post("/visits/{visit_id}/report", response_model=VisitOut)
def technician_report(visit_id: str, payload: TechnicianReportCreate, session: Session = Depends(get_session)) -> Visit:
    try:
        return submit_technician_report(session, visit_id, payload)
    except WorkflowValidationError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error


@app.get("/dashboard/summary", response_model=DashboardSummary)
def dashboard_summary(session: Session = Depends(get_session)) -> DashboardSummary:
    total_jobs = session.scalar(select(func.count()).select_from(Job)) or 0
    completed = session.scalar(select(func.count()).select_from(Job).where(Job.status == "Completed")) or 0
    return DashboardSummary(
        total_jobs=total_jobs,
        open_jobs=total_jobs - completed,
        new_jobs=_count_status(session, "New"),
        in_progress=_count_status(session, "In Progress"),
        waiting_parts=_count_status(session, "Waiting for Parts") + _count_status(session, "Waiting Parts"),
        completed=completed,
        needs_manager_review=_count_status(session, "Need Manager Review") + _count_status(session, "Manager Review"),
    )


@app.get("/sites", response_model=list[SiteOut])
def list_sites(session: Session = Depends(get_session)) -> list[Site]:
    return list(session.scalars(select(Site).order_by(Site.name)))


@app.post("/sites", response_model=SiteOut)
def create_site(payload: SiteCreate, session: Session = Depends(get_session)) -> Site:
    existing = session.get(Site, payload.id)
    if existing is not None:
        raise HTTPException(status_code=409, detail="Site already exists")

    site = Site(
        id=payload.id,
        name=payload.name,
        normalized_name=_normalize_name(payload.name),
        address=payload.address,
        slack_channel=payload.slack_channel,
        source=payload.source,
        needs_manual_review=payload.needs_manual_review,
    )
    session.add(site)
    session.commit()
    session.refresh(site)
    return site


@app.patch("/sites/{site_id}", response_model=SiteOut)
def update_site(site_id: str, payload: SiteUpdate, session: Session = Depends(get_session)) -> Site:
    site = session.get(Site, site_id)
    if site is None:
        raise HTTPException(status_code=404, detail="Site not found")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(site, field, value)
    session.commit()
    session.refresh(site)
    return site


@app.get("/technicians", response_model=list[TechnicianOut])
def list_technicians(session: Session = Depends(get_session)) -> list[Technician]:
    return list(session.scalars(select(Technician).order_by(Technician.name)))


@app.post("/technicians", response_model=TechnicianOut)
def create_technician(payload: TechnicianCreate, session: Session = Depends(get_session)) -> Technician:
    existing = session.get(Technician, payload.id)
    if existing is not None:
        raise HTTPException(status_code=409, detail="Technician already exists")

    technician = Technician(
        id=payload.id,
        name=payload.name,
        email=payload.email,
        initials=payload.initials,
    )
    session.add(technician)
    session.commit()
    session.refresh(technician)
    return technician


@app.patch("/technicians/{technician_id}", response_model=TechnicianOut)
def update_technician(technician_id: str, payload: TechnicianUpdate, session: Session = Depends(get_session)) -> Technician:
    technician = session.get(Technician, technician_id)
    if technician is None:
        raise HTTPException(status_code=404, detail="Technician not found")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(technician, field, value)
    session.commit()
    session.refresh(technician)
    return technician


@app.get("/jobs", response_model=list[JobOut])
def list_jobs(session: Session = Depends(get_session)) -> list[Job]:
    return list(session.scalars(
        select(Job)
        .options(selectinload(Job.calendar_details))
        .order_by(Job.status, Job.first_seen_date, Job.title)
    ))


@app.post("/jobs", response_model=JobOut)
def create_job(payload: JobCreate, session: Session = Depends(get_session)) -> Job:
    existing = session.get(Job, payload.id)
    if existing is not None:
        raise HTTPException(status_code=409, detail="Job already exists")

    site_id = payload.site_id if payload.site_id and session.get(Site, payload.site_id) is not None else None
    technician_id = (
        payload.assigned_technician_id
        if payload.assigned_technician_id and session.get(Technician, payload.assigned_technician_id) is not None
        else None
    )
    job = Job(
        id=payload.id,
        site_id=site_id,
        site_name=payload.site_name,
        job_number=payload.job_number,
        title=payload.title,
        job_type=payload.job_type,
        priority=payload.priority,
        status=payload.status,
        assigned_technician_id=technician_id,
        first_seen_date=payload.first_seen_date,
        last_seen_date=payload.last_seen_date,
        description=payload.description,
        details=payload.details or payload.description,
        needs_parts=False,
        needs_return_visit=False,
        needs_manager_review=False,
        confidence="manual",
    )
    session.add(job)
    session.commit()
    session.refresh(job)
    return job


@app.get("/jobs/{job_id}", response_model=JobOut)
def get_job(job_id: str, session: Session = Depends(get_session)) -> Job:
    job = session.scalar(select(Job).where(Job.id == job_id).options(selectinload(Job.calendar_details)))
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")
    return job


@app.patch("/jobs/{job_id}", response_model=JobOut)
def update_job(job_id: str, update: JobUpdate, session: Session = Depends(get_session)) -> Job:
    job = session.scalar(select(Job).where(Job.id == job_id).options(selectinload(Job.calendar_details)))
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")

    for field, value in update.model_dump(exclude_unset=True).items():
        setattr(job, field, value)
    session.commit()
    session.refresh(job)
    return job


@app.get("/visits", response_model=list[VisitOut])
def list_visits(session: Session = Depends(get_session)) -> list[Visit]:
    return list(session.scalars(select(Visit).order_by(Visit.start_datetime, Visit.id)))


@app.post("/visits", response_model=VisitOut)
def create_or_update_visit(payload: VisitCreate, session: Session = Depends(get_session)) -> Visit:
    visit = session.get(Visit, payload.id)
    if visit is None:
        visit = Visit(id=payload.id)
        session.add(visit)

    _apply_visit_payload(visit, payload.model_dump(exclude_unset=True), session, update_job_from_visit_status=False)
    session.commit()
    session.refresh(visit)
    return visit


@app.patch("/visits/{visit_id}", response_model=VisitOut)
def update_visit(visit_id: str, payload: VisitUpdate, session: Session = Depends(get_session)) -> Visit:
    visit = session.get(Visit, visit_id)
    if visit is None:
        raise HTTPException(status_code=404, detail="Visit not found")

    _apply_visit_payload(visit, payload.model_dump(exclude_unset=True), session, update_job_from_visit_status=True)
    session.commit()
    session.refresh(visit)
    return visit


def _count_status(session: Session, status: str) -> int:
    return session.scalar(select(func.count()).select_from(Job).where(Job.status == status)) or 0


def _job_status_from_visit_status(status: str) -> str:
    normalized = status.lower()
    if "not" in normalized:
        return "In Progress"
    if "complete" in normalized:
        return "Completed"
    if "return" in normalized:
        return "Need Return Visit"
    if "waiting" in normalized:
        return "Waiting for Parts"
    if "access" in normalized or "review" in normalized:
        return "Need Manager Review"
    return "In Progress"


def _apply_visit_payload(visit: Visit, values: dict, session: Session, *, update_job_from_visit_status: bool) -> None:
    for field, value in values.items():
        setattr(visit, field, value)

    if visit.technician_id:
        technician = session.get(Technician, visit.technician_id)
        visit.technician_name = technician.name if technician is not None else visit.technician_name

    if visit.start_datetime and visit.end_datetime:
        visit.duration_minutes = max(0, int((visit.end_datetime - visit.start_datetime).total_seconds() // 60))

    if visit.job_id:
        job = session.get(Job, visit.job_id)
        if job is not None:
            if visit.site_id is None:
                visit.site_id = job.site_id
            if visit.technician_id:
                job.assigned_technician_id = visit.technician_id
            if visit.start_datetime:
                job.first_seen_date = visit.start_datetime.date().isoformat()
            if visit.end_datetime:
                job.last_seen_date = visit.end_datetime.date().isoformat()
            if update_job_from_visit_status and visit.status:
                job.status = _job_status_from_visit_status(visit.status)
            elif not update_job_from_visit_status:
                job.status = "Scheduled"


def _normalize_name(value: str) -> str:
    return " ".join(value.lower().split())


if WEB_BUILD_DIR.exists():
    app.mount("/web", StaticFiles(directory=WEB_BUILD_DIR, html=True), name="web")
