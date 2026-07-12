from __future__ import annotations

import json
import os
import subprocess
import sys
from copy import deepcopy
from datetime import datetime
from pathlib import Path

import pytest
from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, sessionmaker

from app.cleanup import cleanup_operational_data, operational_snapshot
from app.database import Base
from app.models import ActivityEntry, CalendarOutbox, GoogleCalendarSettings, GoogleCredential, GoogleSyncState, Job, Notification, ReportToken, Site, Technician, Visit
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
    session.add(CalendarOutbox(visit_id=visit.id, operation="update"))
    session.add(GoogleCalendarSettings(id=1, calendar_id="service"))
    session.add(ReportToken(visit_id=visit.id, token_hash="hash", nonce="nonce", expires_at=datetime(2030, 1, 1)))
    session.add(GoogleCredential(account_email="placeholder@example.invalid", encrypted_refresh_token=b"encrypted"))
    session.add(GoogleSyncState(id=1, status="ok"))
    session.commit()
    return session


def test_operational_snapshot_is_read_only_and_includes_site_ids():
    with _populated_session() as session:
        before_new = set(session.new)
        snapshot = operational_snapshot(session)
        assert snapshot["site_count"] == len(snapshot["site_ids"])
        assert snapshot["counts"]["jobs"] > 0
        assert set(session.new) == before_new
        assert not session.dirty and not session.deleted


def test_print_counts_script_reads_isolated_database(tmp_path):
    database = tmp_path / "counts.db"
    engine = create_engine(f"sqlite+pysqlite:///{database}")
    Base.metadata.create_all(engine)
    with sessionmaker(bind=engine)() as session:
        session.add_all([Site(id="site-b", name="B"), Site(id="site-a", name="A")])
        session.commit()
    env = {**os.environ, "DATABASE_URL": f"sqlite+pysqlite:///{database}"}
    completed = subprocess.run(
        [sys.executable, "scripts/print_counts.py"], cwd=Path(__file__).parents[1],
        env=env, text=True, capture_output=True, check=True,
    )
    assert json.loads(completed.stdout) == {
        "site_count": 2,
        "site_ids": ["site-a", "site-b"],
        "counts": {"sites": 2, "jobs": 0, "visits": 0, "emails": 0,
                   "technicians": 0, "activities": 0, "notifications": 0,
                   "calendar_details": 0, "report_tokens": 0,
                   "calendar_outbox": 0, "google_calendar_settings": 0,
                   "google_credentials": 0, "google_sync_states": 0},
    }


def test_cleanup_preserves_sites_and_deletes_everything_else():
    with _populated_session() as session:
        site_ids = {row.id for row in session.query(Site).all()}

        result = cleanup_operational_data(session)

        assert {row.id for row in session.query(Site).all()} == site_ids
        operational_keys = {
            "jobs", "visits", "emails", "technicians", "activities",
            "notifications", "calendar_details", "report_tokens",
            "calendar_outbox", "google_calendar_settings",
            "google_credentials", "google_sync_states",
        }
        assert set(result.after) == {"sites", *operational_keys}
        assert result.after["sites"] == len(site_ids)
        assert all(result.before[key] > 0 for key in operational_keys)
        assert all(result.after[key] == 0 for key in operational_keys)


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
    assert counts["after"]["sites"] == expected_sites
    assert all(value == 0 for key, value in counts["after"].items() if key != "sites")


def test_failed_seed_reset_rolls_back_cleanup_and_preserves_operational_data():
    with _populated_session() as session:
        original_job_ids = {row.id for row in session.query(Job).all()}
        original_technician_ids = {
            row.id for row in session.query(Technician).all()
        }
        invalid_seed = deepcopy(load_seed_file())
        invalid_seed["technicians"].append(invalid_seed["technicians"][0])

        with pytest.raises(IntegrityError):
            reset_and_load_seed(session, invalid_seed)

        assert {row.id for row in session.query(Job).all()} == original_job_ids
        assert {
            row.id for row in session.query(Technician).all()
        } == original_technician_ids
