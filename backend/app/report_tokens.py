from __future__ import annotations

import hashlib
import secrets
from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import ReportToken, Visit


class ReportTokenError(ValueError):
    pass


UNAVAILABLE = "Report link is unavailable"


def _hash(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def issue_report_token(session: Session, visit: Visit) -> str:
    now = datetime.utcnow()
    for row in session.scalars(select(ReportToken).where(
        ReportToken.visit_id == visit.id, ReportToken.closed_at.is_(None), ReportToken.revoked_at.is_(None)
    )):
        row.revoked_at = now
    raw = secrets.token_urlsafe(32)
    session.add(ReportToken(visit=visit, token_hash=_hash(raw), expires_at=now + timedelta(days=30)))
    session.flush()
    return raw


def resolve_report_token(session: Session, raw_token: str) -> Visit:
    row = session.scalar(select(ReportToken).where(ReportToken.token_hash == _hash(raw_token)))
    now = datetime.utcnow()
    if row is None or row.closed_at is not None or row.revoked_at is not None or row.expires_at <= now:
        raise ReportTokenError(UNAVAILABLE)
    return row.visit


def token_record(session: Session, raw_token: str) -> ReportToken:
    resolve_report_token(session, raw_token)
    return session.scalar(select(ReportToken).where(ReportToken.token_hash == _hash(raw_token)))


def close_report_token(session: Session, raw_token: str) -> None:
    row = token_record(session, raw_token)
    row.closed_at = datetime.utcnow()
    session.flush()
