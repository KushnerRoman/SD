from __future__ import annotations

from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app import main
from app.database import Base
from app.models import EmailMessage, Job, Site, Technician


def test_startup_creates_schema_without_seeding_operational_data(monkeypatch):
    engine = create_engine("sqlite+pysqlite:///:memory:")
    session_factory = sessionmaker(bind=engine)
    monkeypatch.setattr(main, "create_schema", lambda: Base.metadata.create_all(engine))

    main.startup()

    with session_factory() as session:
        assert session.query(Site).count() == 0
        assert session.query(Job).count() == 0
        assert session.query(EmailMessage).count() == 0
        assert session.query(Technician).count() == 0


def test_reset_demo_endpoint_is_removed():
    assert not any(route.path == "/admin/reset-demo" for route in main.app.routes)
    assert not any(route.path == "/admin/load-seed" for route in main.app.routes)


def test_legacy_init_script_is_schema_only():
    source = (Path(__file__).parents[1] / "scripts" / "init_db.py").read_text()
    assert "seed_loader" not in source
    assert "reset_and_load_seed" not in source
