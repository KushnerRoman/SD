from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any

from sqlalchemy import delete
from sqlalchemy.orm import Session

from app import models


DEFAULT_SEED_PATH = Path(__file__).resolve().parents[2] / "app" / "security_depot_fsm" / "assets" / "data" / "seed_data.json"


def load_seed_file(path: Path = DEFAULT_SEED_PATH) -> dict[str, Any]:
    return json.loads(path.resolve().read_text(encoding="utf-8"))


def reset_and_load_seed(session: Session, seed: dict[str, Any]) -> dict[str, int]:
    session.execute(delete(models.CalendarDetail))
    session.execute(delete(models.Visit))
    session.execute(delete(models.Job))
    session.execute(delete(models.Site))
    session.execute(delete(models.Technician))
    session.flush()

    for site in seed.get("sites", []):
        session.add(models.Site(
            id=str(site.get("id", "")),
            name=str(site.get("name", "")),
            normalized_name=str(site.get("normalizedName", "")),
            address=str(site.get("address", "")),
            slack_channel=str(site.get("slackChannel", "")),
            source=str(site.get("source", "")),
            needs_manual_review=bool(site.get("needsManualReview", False)),
        ))

    for technician in seed.get("technicians", []):
        session.add(models.Technician(
            id=str(technician.get("id", "")),
            name=str(technician.get("name", "")),
            email=str(technician.get("email", "")),
            initials=str(technician.get("initials", "")),
        ))

    session.flush()

    known_site_ids = {site.id for site in session.query(models.Site.id).all()}
    known_technician_ids = [tech.id for tech in session.query(models.Technician.id).order_by(models.Technician.id).all()]
    job_technician_ids: dict[str, str | None] = {}

    for index, job in enumerate(seed.get("jobs", [])):
        site_id = str(job.get("siteId", "")) or None
        if site_id not in known_site_ids:
            site_id = None
        assigned_technician_id = known_technician_ids[index % len(known_technician_ids)] if known_technician_ids else None
        job_technician_ids[str(job.get("id", ""))] = assigned_technician_id
        session.add(models.Job(
            id=str(job.get("id", "")),
            site_id=site_id,
            site_name=str(job.get("siteName", "")),
            job_number=str(job.get("jobNumber", "")),
            title=str(job.get("title", "")),
            job_type=str(job.get("type", "Service Call")),
            priority=str(job.get("priority", "Medium")),
            status=str(job.get("status", "Scheduled")),
            assigned_technician_id=assigned_technician_id,
            first_seen_date=str(job.get("firstSeenDate", "")),
            last_seen_date=str(job.get("lastSeenDate", "")),
            description=str(job.get("details") or job.get("title") or ""),
            details=str(job.get("details", "")),
            needs_parts=bool(job.get("needsParts", False)),
            needs_return_visit=bool(job.get("needsReturnVisit", False)),
            needs_manager_review=bool(job.get("needsManagerReview", False)),
            confidence=str(job.get("confidence", "")),
        ))

    session.flush()

    known_job_ids = {job.id for job in session.query(models.Job.id).all()}
    for job in seed.get("jobs", []):
        job_id = str(job.get("id", ""))
        if job_id not in known_job_ids:
            continue
        for detail in job.get("rawCalendarDetails", []):
            session.add(models.CalendarDetail(
                job_id=job_id,
                calendar_event_id=str(detail.get("calendarEventId", "")),
                uid=str(detail.get("uid", "")),
                summary=str(detail.get("summary", "")),
                start_datetime=str(detail.get("startDateTime", "")),
                end_datetime=str(detail.get("endDateTime", "")),
                location=str(detail.get("location", "")),
                description=str(detail.get("description", "")),
            ))

    for index, visit in enumerate(seed.get("visits", [])):
        job_id = str(visit.get("jobId", "")) or None
        site_id = str(visit.get("siteId", "")) or None
        if job_id not in known_job_ids:
            job_id = None
        if site_id not in known_site_ids:
            site_id = None
        technician_id = job_technician_ids.get(job_id or "") or (known_technician_ids[index % len(known_technician_ids)] if known_technician_ids else None)
        session.add(models.Visit(
            id=str(visit.get("id", "")),
            job_id=job_id,
            site_id=site_id,
            technician_id=technician_id,
            technician_name=str(visit.get("technicianName", "")),
            start_datetime=_parse_datetime(str(visit.get("startDateTime", ""))),
            end_datetime=_parse_datetime(str(visit.get("endDateTime", ""))),
            duration_minutes=int(visit.get("durationMinutes") or 0),
            status=str(visit.get("status", "Unknown")),
            work_summary=str(visit.get("workSummary", "")),
            parts_status=str(visit.get("partsStatus", "No Parts Mentioned")),
            needs_manual_review=bool(visit.get("needsManualReview", False)),
        ))

    session.commit()

    return {
        "sites": session.query(models.Site).count(),
        "technicians": session.query(models.Technician).count(),
        "jobs": session.query(models.Job).count(),
        "visits": session.query(models.Visit).count(),
        "calendar_details": session.query(models.CalendarDetail).count(),
    }


def _parse_datetime(value: str) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).replace(tzinfo=None)
    except ValueError:
        return None
