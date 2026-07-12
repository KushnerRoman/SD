from datetime import datetime, timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.models import CalendarOutbox, EmailMessage, Job, Notification, Site, Technician, Visit
from app.schemas import DispatchCreate, TechnicianReportCreate
from app.workflows import WorkflowConflict, WorkflowValidationError, convert_email_to_service_call, submit_technician_report


@pytest.fixture()
def session(monkeypatch):
    monkeypatch.setenv("TOKEN_ENCRYPTION_KEY", "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA=")
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine)
    with factory() as value:
        value.add(Site(id="site-1", name="North Tower", address="1 King St"))
        value.add(Technician(id="tech-1", name="Mike", email="mike@example.com", initials="MK", active=True))
        value.add(EmailMessage(id="mail-1", sender="client@example.com", recipients="service@example.com", subject="Lobby camera offline", body="Camera has been down since Friday", received_at=datetime(2026, 7, 11, 8)))
        value.commit()
        yield value


def dispatch_payload(**changes):
    values = dict(
        email_id="mail-1", site_id="site-1", title="Lobby camera offline",
        category="Cameras/CCTV", priority="Urgent", technician_id="tech-1",
        scheduled_start=datetime(2026, 7, 13, 9), scheduled_end=datetime(2026, 7, 13, 10),
        instructions="Inspect and restore lobby camera.",
    )
    values.update(changes)
    return DispatchCreate(**values)


def test_email_conversion_creates_linked_job_visit_and_activity(session):
    job = convert_email_to_service_call(session, dispatch_payload())
    assert job.source_email_id == "mail-1"
    assert job.status == "Scheduled"
    assert job.category == "Cameras/CCTV"
    visit = session.query(Visit).filter_by(job_id=job.id).one()
    assert visit.calendar_event_id == ""
    assert session.query(CalendarOutbox).filter_by(visit_id=visit.id, status="pending").one()
    assert session.get(EmailMessage, "mail-1").linked_job_id == job.id
    assert [item.event_type for item in job.activities] == ["created", "scheduled"]


def test_duplicate_email_conversion_is_rejected(session):
    convert_email_to_service_call(session, dispatch_payload())
    with pytest.raises(WorkflowConflict, match="already linked"):
        convert_email_to_service_call(session, dispatch_payload())


def test_invalid_time_range_is_rejected(session):
    with pytest.raises(WorkflowValidationError, match="later"):
        convert_email_to_service_call(session, dispatch_payload(scheduled_end=datetime(2026, 7, 13, 8)))


def test_report_updates_job_and_creates_notification(session):
    job = convert_email_to_service_call(session, dispatch_payload())
    visit = session.query(Visit).filter_by(job_id=job.id).one()
    report = TechnicianReportCreate(status="Completed", duration_minutes=75, work_performed="Re-terminated camera cable and restored video.", materials_used="2 RJ45 ends", follow_up_notes="")
    submit_technician_report(session, visit.id, report)
    assert session.get(Job, job.id).status == "Completed"
    assert session.get(Visit, visit.id).duration_minutes == 75
    assert session.query(Notification).filter_by(job_id=job.id).one().kind == "completed"


def test_return_required_report_requires_follow_up(session):
    job = convert_email_to_service_call(session, dispatch_payload())
    visit = session.query(Visit).filter_by(job_id=job.id).one()
    report = TechnicianReportCreate(status="Return Required", duration_minutes=30, work_performed="Diagnosed failed camera.", materials_used="", follow_up_notes="")
    with pytest.raises(WorkflowValidationError, match="Follow-up"):
        submit_technician_report(session, visit.id, report)
