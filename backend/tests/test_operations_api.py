from collections.abc import Generator
from datetime import datetime

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_session
from app.main import app
from app.models import EmailMessage, Site, Technician


def test_operations_api_dispatch_report_and_notifications():
    engine = create_engine("sqlite+pysqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine)
    with factory() as session:
        session.add(Site(id="site-1", name="North Tower", address="1 King St"))
        session.add(Technician(id="tech-1", name="Mike", email="mike@example.com", initials="MK", active=True))
        session.add(EmailMessage(id="mail-1", sender="client@example.com", recipients="service@example.com", subject="Camera offline", body="Lobby camera is down", received_at=datetime(2026, 7, 11, 8)))
        session.commit()

    def override() -> Generator[Session, None, None]:
        with factory() as session:
            yield session

    app.dependency_overrides[get_session] = override
    try:
        client = TestClient(app)
        assert client.get("/emails").json()[0]["subject"] == "Camera offline"
        dispatched = client.post("/dispatch/from-email", json={
            "email_id": "mail-1", "site_id": "site-1", "title": "Camera offline",
            "category": "Cameras/CCTV", "priority": "Urgent", "technician_id": "tech-1",
            "scheduled_start": "2026-07-13T09:00:00", "scheduled_end": "2026-07-13T10:00:00",
            "instructions": "Restore camera",
        })
        assert dispatched.status_code == 200
        visit = client.get("/visits").json()[0]
        report = client.post(f"/visits/{visit['id']}/report", json={
            "status": "Completed", "duration_minutes": 45, "work_performed": "Replaced connector",
            "materials_used": "RJ45", "follow_up_notes": "",
        })
        assert report.status_code == 200
        assert client.get("/notifications").json()[0]["kind"] == "completed"
    finally:
        app.dependency_overrides.clear()
