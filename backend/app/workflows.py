from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy.orm import Session

from app.models import ActivityEntry, EmailMessage, Job, Notification, Site, Technician, Visit
from app.google.outbox import enqueue_calendar_operation
from app.schemas import DispatchCreate, TechnicianReportCreate


class WorkflowConflict(ValueError):
    pass


class WorkflowValidationError(ValueError):
    pass


def convert_email_to_service_call(session: Session, payload: DispatchCreate) -> Job:
    email = session.get(EmailMessage, payload.email_id)
    if email is None:
        raise WorkflowValidationError("Email not found")
    if email.linked_job_id:
        raise WorkflowConflict("Email is already linked to a service call")
    site = session.get(Site, payload.site_id)
    technician = session.get(Technician, payload.technician_id)
    if site is None:
        raise WorkflowValidationError("Site not found")
    if technician is None or not technician.active:
        raise WorkflowValidationError("An active technician is required")
    if payload.scheduled_end <= payload.scheduled_start:
        raise WorkflowValidationError("Scheduled end must be later than start")
    if not payload.title.strip() or not payload.instructions.strip():
        raise WorkflowValidationError("Title and instructions are required")

    token = uuid4().hex[:10]
    job = Job(
        id=f"job_{token}", site_id=site.id, site_name=site.name, title=payload.title.strip(),
        job_type="Service Call", category=payload.category, priority=payload.priority,
        status="Scheduled", assigned_technician_id=technician.id,
        first_seen_date=payload.scheduled_start.date().isoformat(), last_seen_date=payload.scheduled_end.date().isoformat(),
        description=payload.instructions.strip(), details=payload.instructions.strip(), source_email_id=email.id,
        confidence="manager",
    )
    visit = Visit(
        id=f"visit_{token}", job=job, site=site, technician=technician, technician_name=technician.name,
        start_datetime=payload.scheduled_start, end_datetime=payload.scheduled_end,
        duration_minutes=int((payload.scheduled_end - payload.scheduled_start).total_seconds() // 60),
        status="Scheduled", calendar_event_id="",
    )
    job.activities.extend([
        ActivityEntry(event_type="created", message=f"Created from email: {email.subject}"),
        ActivityEntry(event_type="scheduled", message=f"Assigned to {technician.name} for {payload.scheduled_start:%b %d, %Y %H:%M}"),
    ])
    email.linked_job_id = job.id
    session.add_all([job, visit])
    session.flush()
    enqueue_calendar_operation(session, visit, "upsert")
    session.commit()
    session.refresh(job)
    return job


def submit_technician_report(session: Session, visit_id: str, payload: TechnicianReportCreate) -> Visit:
    visit = session.get(Visit, visit_id)
    if visit is None or visit.job is None:
        raise WorkflowValidationError("Visit not found")
    if payload.duration_minutes <= 0:
        raise WorkflowValidationError("Time spent must be greater than zero")
    if not payload.work_performed.strip():
        raise WorkflowValidationError("Work performed is required")
    if payload.status in {"Incomplete", "Return Required"} and not payload.follow_up_notes.strip():
        raise WorkflowValidationError("Follow-up notes are required")
    status_map = {"Completed": "Completed", "Incomplete": "Incomplete", "Return Required": "Return Required"}
    if payload.status not in status_map:
        raise WorkflowValidationError("Invalid report status")

    visit.status = payload.status
    visit.duration_minutes = payload.duration_minutes
    visit.work_summary = payload.work_performed.strip()
    visit.materials_used = payload.materials_used.strip()
    visit.follow_up_notes = payload.follow_up_notes.strip()
    visit.job.status = status_map[payload.status]
    visit.job.activities.append(ActivityEntry(
        event_type="technician_report", actor=visit.technician_name or "Technician",
        message=f"{payload.status}: {payload.work_performed.strip()}",
    ))
    kind = {"Completed": "completed", "Incomplete": "incomplete", "Return Required": "return_required"}[payload.status]
    session.add(Notification(
        job_id=visit.job_id, visit_id=visit.id, kind=kind,
        title=f"{payload.status}: {visit.job.title}",
        message=f"{visit.technician_name} reported {payload.duration_minutes} minutes. {payload.work_performed.strip()}",
    ))
    session.commit()
    session.refresh(visit)
    return visit
