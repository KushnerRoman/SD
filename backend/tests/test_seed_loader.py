from __future__ import annotations

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.models import EmailMessage, Job, Technician
from app.seed_loader import load_seed_file, reset_and_load_seed


def test_seed_loader_imports_historical_data_with_job_details():
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)

    with session_factory() as session:
      counts = reset_and_load_seed(session, load_seed_file())
      job = session.query(Job).first()

    assert counts["sites"] == 130
    assert counts["jobs"] == 115
    assert counts["visits"] == 180
    assert counts["calendar_details"] > 0
    assert job is not None
    assert job.details
    assert "Event:" in job.details


def test_seed_loader_distributes_jobs_across_technicians():
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)

    with session_factory() as session:
      reset_and_load_seed(session, load_seed_file())
      assigned_ids = {row[0] for row in session.query(Job.assigned_technician_id).distinct().all()}

    assert len(assigned_ids) >= 3


def test_seed_loader_adds_mixed_inbox_and_six_technicians():
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)

    with session_factory() as session:
      counts = reset_and_load_seed(session, load_seed_file())
      subjects = {message.subject for message in session.query(EmailMessage).all()}
      technicians = session.query(Technician).all()

    assert counts["emails"] >= 8
    assert len(technicians) == 6
    assert "Lobby intercom not calling concierge" in subjects
    assert "Updated holiday hours" in subjects
