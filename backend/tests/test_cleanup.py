from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.cleanup import cleanup_operational_data
from app.database import Base
from app.models import ActivityEntry, Job, Notification, Site, Visit
from app.seed_loader import load_seed_file, reset_and_load_seed


def _populated_session() -> Session:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    reset_and_load_seed(session, load_seed_file())
    job = session.query(Job).first()
    visit = session.query(Visit).first()
    assert job is not None
    assert visit is not None
    session.add(ActivityEntry(job_id=job.id, event_type="test", message="test"))
    session.add(Notification(job_id=job.id, visit_id=visit.id, kind="test", title="test"))
    session.commit()
    return session


def test_cleanup_preserves_sites_and_deletes_everything_else():
    with _populated_session() as session:
        site_ids = {row.id for row in session.query(Site).all()}

        result = cleanup_operational_data(session)

        assert {row.id for row in session.query(Site).all()} == site_ids
        assert result.after == {
            "sites": len(site_ids),
            "jobs": 0,
            "visits": 0,
            "emails": 0,
            "technicians": 0,
            "activities": 0,
            "notifications": 0,
        }
        assert result.before["jobs"] > 0
        assert result.before["visits"] > 0
        assert result.before["emails"] > 0
        assert result.before["technicians"] > 0
        assert result.before["activities"] == 1
        assert result.before["notifications"] == 1


def test_cleanup_cli_requires_exact_confirmation_flag(tmp_path: Path):
    database_path = tmp_path / "guarded.db"
    env = {**os.environ, "DATABASE_URL": f"sqlite+pysqlite:///{database_path.as_posix()}"}

    result = subprocess.run(
        [sys.executable, "scripts/clear_demo_data.py"],
        cwd=Path(__file__).resolve().parents[1],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode != 0
    assert not database_path.exists()


def test_cleanup_cli_prints_json_counts_for_isolated_database(tmp_path: Path):
    database_path = tmp_path / "confirmed.db"
    engine = create_engine(f"sqlite+pysqlite:///{database_path.as_posix()}")
    Base.metadata.create_all(engine)
    with sessionmaker(bind=engine)() as session:
        reset_and_load_seed(session, load_seed_file())
        expected_sites = session.query(Site).count()
    engine.dispose()
    env = {**os.environ, "DATABASE_URL": f"sqlite+pysqlite:///{database_path.as_posix()}"}

    result = subprocess.run(
        [sys.executable, "scripts/clear_demo_data.py", "--confirm-delete-operational-data"],
        cwd=Path(__file__).resolve().parents[1],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0
    counts = json.loads(result.stdout)
    assert counts["after"] == {
        "sites": expected_sites,
        "jobs": 0,
        "visits": 0,
        "emails": 0,
        "technicians": 0,
        "activities": 0,
        "notifications": 0,
    }

