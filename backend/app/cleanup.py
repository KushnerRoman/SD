from __future__ import annotations

from sqlalchemy import delete
from sqlalchemy.orm import Session

from app import models
from app.schemas import CleanupResult


def cleanup_operational_data(
    session: Session, *, commit: bool = True
) -> CleanupResult:
    before = _counts(session)

    session.execute(delete(models.ReportToken))
    session.execute(delete(models.CalendarOutbox))
    session.execute(delete(models.GoogleCalendarSettings))
    session.execute(delete(models.Notification))
    session.execute(delete(models.ActivityEntry))
    session.execute(delete(models.CalendarDetail))
    session.execute(delete(models.Visit))
    session.execute(delete(models.Job))
    session.execute(delete(models.EmailMessage))
    session.execute(delete(models.Technician))
    if commit:
        session.commit()
    else:
        session.flush()

    return CleanupResult(before=before, after=_counts(session))


def _counts(session: Session) -> dict[str, int]:
    return {
        "sites": session.query(models.Site).count(),
        "jobs": session.query(models.Job).count(),
        "visits": session.query(models.Visit).count(),
        "emails": session.query(models.EmailMessage).count(),
        "technicians": session.query(models.Technician).count(),
        "activities": session.query(models.ActivityEntry).count(),
        "notifications": session.query(models.Notification).count(),
    }


def operational_snapshot(session: Session) -> dict:
    site_ids = list(session.scalars(
        session.query(models.Site.id).order_by(models.Site.id).statement
    ))
    return {
        "site_count": len(site_ids),
        "site_ids": site_ids,
        "counts": _counts(session),
    }
