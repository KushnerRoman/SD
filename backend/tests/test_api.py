from __future__ import annotations

from collections.abc import Generator

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_session
from app.main import app
from app.seed_loader import load_seed_file, reset_and_load_seed


def test_api_lists_and_updates_jobs():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    with session_factory() as session:
        reset_and_load_seed(session, load_seed_file())

    def override_session() -> Generator[Session, None, None]:
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_session] = override_session
    try:
        client = TestClient(app)
        summary = client.get("/dashboard/summary")
        assert summary.status_code == 200
        assert summary.json()["total_jobs"] == 115

        jobs = client.get("/jobs")
        assert jobs.status_code == 200
        first_job = jobs.json()[0]
        assert first_job["details"]
        assert first_job["calendar_details"]

        update = client.patch(
            f"/jobs/{first_job['id']}",
            json={
                "title": "Edited from API test",
                "status": "In Progress",
                "priority": "Urgent",
                "assigned_technician_id": "tech_dex",
            },
        )
        assert update.status_code == 200
        assert update.json()["title"] == "Edited from API test"
        assert update.json()["assigned_technician_id"] == "tech_dex"

        completed_job = next(job for job in client.get("/jobs").json() if job["status"] == "Completed")
        completed_update = client.patch(
            f"/jobs/{completed_job['id']}",
            json={
                "title": "Edited completed job",
                "status": "Need Manager Review",
                "priority": "High",
                "assigned_technician_id": "tech_mike",
                "first_seen_date": "2026-06-01",
                "last_seen_date": "2026-06-01",
            },
        )
        assert completed_update.status_code == 200
        assert completed_update.json()["title"] == "Edited completed job"
        assert completed_update.json()["status"] == "Need Manager Review"
        assert completed_update.json()["assigned_technician_id"] == "tech_mike"
    finally:
        app.dependency_overrides.clear()


def test_api_creates_and_updates_technician():
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
        create_response = client.post(
            "/technicians",
            json={"id": "tech_sam", "name": "Sam", "email": "sam@securitydepot.ca", "initials": "SM"},
        )
        assert create_response.status_code == 200

        update_response = client.patch(
            "/technicians/tech_sam",
            json={"name": "Sam Installer", "email": "sam.installer@securitydepot.ca", "initials": "SI"},
        )
        assert update_response.status_code == 200
        updated = update_response.json()
        assert updated["name"] == "Sam Installer"
        assert updated["email"] == "sam.installer@securitydepot.ca"

        technicians = client.get("/technicians").json()
        assert any(technician["id"] == "tech_sam" for technician in technicians)
    finally:
        app.dependency_overrides.clear()


def test_api_updates_sites_and_visits():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    with session_factory() as session:
        reset_and_load_seed(session, load_seed_file())

    def override_session() -> Generator[Session, None, None]:
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_session] = override_session
    try:
        client = TestClient(app)
        site = client.get("/sites").json()[0]
        site_response = client.patch(
            f"/sites/{site['id']}",
            json={"name": "Edited Site", "address": "123 Edited Street", "slack_channel": "#edited"},
        )
        assert site_response.status_code == 200
        assert site_response.json()["name"] == "Edited Site"

        visit = client.get("/visits").json()[0]
        visit_response = client.patch(
            f"/visits/{visit['id']}",
            json={
                "status": "Completed",
                "work_summary": "Finished work",
                "parts_status": "Parts Used",
                "technician_id": "tech_dex",
                "start_datetime": "2026-06-01T14:00:00",
                "end_datetime": "2026-06-01T15:00:00",
            },
        )
        assert visit_response.status_code == 200
        assert visit_response.json()["work_summary"] == "Finished work"
        assert visit_response.json()["status"] == "Completed"
        assert visit_response.json()["technician_id"] == "tech_dex"
        assert visit_response.json()["duration_minutes"] == 60
    finally:
        app.dependency_overrides.clear()


def test_api_creates_sites_and_jobs():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    with session_factory() as session:
        reset_and_load_seed(session, load_seed_file())

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
            json={"id": "site_manual", "name": "Manual Site", "address": "99 Manual Road", "slack_channel": "#manual"},
        )
        assert site_response.status_code == 200
        assert site_response.json()["id"] == "site_manual"

        job_response = client.post(
            "/jobs",
            json={
                "id": "job_manual",
                "site_id": "site_manual",
                "site_name": "Manual Site",
                "title": "Manual service call",
                "job_type": "Service Call",
                "priority": "Medium",
                "status": "New",
                "assigned_technician_id": "tech_roman",
                "first_seen_date": "2026-06-01",
                "last_seen_date": "2026-06-01",
                "description": "Created manually.",
                "details": "Created manually.",
            },
        )
        assert job_response.status_code == 200
        assert job_response.json()["title"] == "Manual service call"
    finally:
        app.dependency_overrides.clear()


def test_api_schedules_visit_and_updates_job_assignment():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    with session_factory() as session:
        reset_and_load_seed(session, load_seed_file())

    def override_session() -> Generator[Session, None, None]:
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_session] = override_session
    try:
        client = TestClient(app)
        job = client.get("/jobs").json()[0]
        response = client.post(
            "/visits",
            json={
                "id": f"visit_{job['id']}",
                "job_id": job["id"],
                "site_id": job["site_id"],
                "technician_id": "tech_dex",
                "start_datetime": "2026-06-01T14:00:00",
                "end_datetime": "2026-06-01T15:00:00",
                "status": "Not Completed",
                "work_summary": "",
                "parts_status": "No Parts Used",
            },
        )
        assert response.status_code == 200
        assert response.json()["technician_id"] == "tech_dex"
        assert response.json()["duration_minutes"] == 60

        updated_job = client.get(f"/jobs/{job['id']}").json()
        assert updated_job["assigned_technician_id"] == "tech_dex"
        assert updated_job["status"] == "Scheduled"
    finally:
        app.dependency_overrides.clear()
