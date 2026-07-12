from __future__ import annotations

import hashlib
import hmac
import base64
import os
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


def _signing_key() -> bytes:
    return os.getenv("REPORT_TOKEN_SIGNING_KEY", "security-depot-local-report-token-v1").encode()


def _derive(visit_id: str, nonce: str) -> str:
    digest = hmac.new(_signing_key(), f"report:{visit_id}:{nonce}".encode(), hashlib.sha256).digest()
    return base64.urlsafe_b64encode(digest).rstrip(b"=").decode()


def csrf_token_for(raw_token: str) -> str:
    digest = hmac.new(_signing_key(), f"csrf:{raw_token}".encode(), hashlib.sha256).digest()
    return base64.urlsafe_b64encode(digest).rstrip(b"=").decode()


def issue_report_token(session: Session, visit: Visit) -> str:
    now = datetime.utcnow()
    existing = session.scalar(select(ReportToken).where(
        ReportToken.visit_id == visit.id, ReportToken.closed_at.is_(None), ReportToken.revoked_at.is_(None)
    ).order_by(ReportToken.id.desc()))
    if existing is not None and existing.expires_at > now and existing.nonce:
        raw = _derive(visit.id, existing.nonce)
        if hmac.compare_digest(existing.token_hash, _hash(raw)):
            return raw
    nonce = secrets.token_urlsafe(32)
    raw = _derive(visit.id, nonce)
    session.add(ReportToken(visit=visit, nonce=nonce, token_hash=_hash(raw), expires_at=now + timedelta(days=30)))
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
