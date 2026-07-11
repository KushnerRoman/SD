from __future__ import annotations

from pathlib import Path

from fastapi import Depends, FastAPI, HTTPException
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.database import create_schema, get_session
from app.models import EmailMessage, Job, Notification, Site, Technician, Visit
from app.schemas import DashboardSummary, DispatchCreate, EmailMessageOut, JobCreate, JobOut, JobUpdate, NotificationOut, SiteCreate, SiteOut, SiteUpdate, TechnicianCreate, TechnicianOut, TechnicianReportCreate, TechnicianUpdate, VisitCreate, VisitOut, VisitUpdate
from app.seed_loader import load_seed_file, reset_and_load_seed
from app.workflows import WorkflowConflict, WorkflowValidationError, convert_email_to_service_call, submit_technician_report

app = FastAPI(title="Security Depot FSM Mock API", version="0.1.0")

WEB_BUILD_DIR = Path(__file__).resolve().parents[2] / "app" / "security_depot_fsm" / "build" / "web"


@app.on_event("startup")
def startup() -> None:
    create_schema()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/", include_in_schema=False)
def web_root() -> RedirectResponse:
    return RedirectResponse(url="/web/")


@app.post("/admin/load-seed")
def load_seed(session: Session = Depends(get_session)) -> dict[str, int]:
    return reset_and_load_seed(session, load_seed_file())


@app.post("/admin/reset-demo")
def reset_demo(session: Session = Depends(get_session)) -> dict[str, int]:
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
