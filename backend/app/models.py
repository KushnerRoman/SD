from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, LargeBinary, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Site(Base):
    __tablename__ = "sites"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(255), index=True)
    normalized_name: Mapped[str] = mapped_column(String(255), default="")
    address: Mapped[str] = mapped_column(String(500), default="")
    slack_channel: Mapped[str] = mapped_column(String(255), default="")
    source: Mapped[str] = mapped_column(String(255), default="")
    needs_manual_review: Mapped[bool] = mapped_column(Boolean, default=False)
    customer: Mapped[str] = mapped_column(String(255), default="")
    contact_name: Mapped[str] = mapped_column(String(255), default="")
    contact_phone: Mapped[str] = mapped_column(String(64), default="")
    contact_email: Mapped[str] = mapped_column(String(255), default="")
    access_notes: Mapped[str] = mapped_column(Text, default="")
    systems_notes: Mapped[str] = mapped_column(Text, default="")

    jobs: Mapped[list["Job"]] = relationship(back_populates="site")
    visits: Mapped[list["Visit"]] = relationship(back_populates="site")


class Technician(Base):
    __tablename__ = "technicians"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(255), index=True)
    email: Mapped[str] = mapped_column(String(255), default="")
    initials: Mapped[str] = mapped_column(String(16), default="")
    phone: Mapped[str] = mapped_column(String(64), default="")
    skills: Mapped[str] = mapped_column(Text, default="")
    working_hours: Mapped[str] = mapped_column(String(255), default="Mon-Fri 08:00-17:00")
    calendar_color: Mapped[str] = mapped_column(String(32), default="#2F74C0")
    active: Mapped[bool] = mapped_column(Boolean, default=True)

    jobs: Mapped[list["Job"]] = relationship(back_populates="assigned_technician")
    visits: Mapped[list["Visit"]] = relationship(back_populates="technician")


class Job(Base):
    __tablename__ = "jobs"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    site_id: Mapped[str | None] = mapped_column(String(64), ForeignKey("sites.id"), nullable=True)
    site_name: Mapped[str] = mapped_column(String(255), default="")
    job_number: Mapped[str] = mapped_column(String(64), default="")
    title: Mapped[str] = mapped_column(String(500), index=True)
    job_type: Mapped[str] = mapped_column(String(64), default="Service Call")
    priority: Mapped[str] = mapped_column(String(64), default="Medium")
    status: Mapped[str] = mapped_column(String(64), index=True, default="Scheduled")
    assigned_technician_id: Mapped[str | None] = mapped_column(String(64), ForeignKey("technicians.id"), nullable=True)
    first_seen_date: Mapped[str] = mapped_column(String(32), default="")
    last_seen_date: Mapped[str] = mapped_column(String(32), default="")
    description: Mapped[str] = mapped_column(Text, default="")
    details: Mapped[str] = mapped_column(Text, default="")
    needs_parts: Mapped[bool] = mapped_column(Boolean, default=False)
    needs_return_visit: Mapped[bool] = mapped_column(Boolean, default=False)
    needs_manager_review: Mapped[bool] = mapped_column(Boolean, default=False)
    confidence: Mapped[str] = mapped_column(String(64), default="")
    category: Mapped[str] = mapped_column(String(64), default="Other")
    source_email_id: Mapped[str | None] = mapped_column(String(64), ForeignKey("email_messages.id"), nullable=True)

    site: Mapped[Site | None] = relationship(back_populates="jobs")
    assigned_technician: Mapped[Technician | None] = relationship(back_populates="jobs")
    visits: Mapped[list["Visit"]] = relationship(back_populates="job")
    calendar_details: Mapped[list["CalendarDetail"]] = relationship(back_populates="job", cascade="all, delete-orphan")
    activities: Mapped[list["ActivityEntry"]] = relationship(back_populates="job", cascade="all, delete-orphan", order_by="ActivityEntry.created_at")


class Visit(Base):
    __tablename__ = "visits"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    job_id: Mapped[str | None] = mapped_column(String(64), ForeignKey("jobs.id"), nullable=True)
    site_id: Mapped[str | None] = mapped_column(String(64), ForeignKey("sites.id"), nullable=True)
    technician_id: Mapped[str | None] = mapped_column(String(64), ForeignKey("technicians.id"), nullable=True)
    technician_name: Mapped[str] = mapped_column(String(255), default="")
    start_datetime: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    end_datetime: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    duration_minutes: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(64), default="Unknown")
    work_summary: Mapped[str] = mapped_column(Text, default="")
    parts_status: Mapped[str] = mapped_column(String(64), default="No Parts Mentioned")
    needs_manual_review: Mapped[bool] = mapped_column(Boolean, default=False)
    materials_used: Mapped[str] = mapped_column(Text, default="")
    follow_up_notes: Mapped[str] = mapped_column(Text, default="")
    calendar_event_id: Mapped[str] = mapped_column(String(64), default="")
    calendar_etag: Mapped[str] = mapped_column(String(255), default="")
    calendar_updated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    job: Mapped[Job | None] = relationship(back_populates="visits")
    site: Mapped[Site | None] = relationship(back_populates="visits")
    technician: Mapped[Technician | None] = relationship(back_populates="visits")
    outbox_items: Mapped[list["CalendarOutbox"]] = relationship(back_populates="visit", cascade="all, delete-orphan")
    report_tokens: Mapped[list["ReportToken"]] = relationship(back_populates="visit", cascade="all, delete-orphan")


class ReportToken(Base):
    __tablename__ = "report_tokens"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    visit_id: Mapped[str] = mapped_column(String(64), ForeignKey("visits.id"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    csrf_hash: Mapped[str] = mapped_column(String(64), default="")
    expires_at: Mapped[datetime] = mapped_column(DateTime)
    closed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    visit: Mapped[Visit] = relationship(back_populates="report_tokens")


class GoogleCalendarSettings(Base):
    __tablename__ = "google_calendar_settings"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)
    calendar_id: Mapped[str] = mapped_column(String(255), default="")
    sync_token: Mapped[str] = mapped_column(Text, default="")
    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class CalendarOutbox(Base):
    __tablename__ = "calendar_outbox"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    visit_id: Mapped[str] = mapped_column(String(64), ForeignKey("visits.id"), index=True)
    operation: Mapped[str] = mapped_column(String(32), default="upsert")
    status: Mapped[str] = mapped_column(String(32), default="pending", index=True)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    next_attempt_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    last_error: Mapped[str] = mapped_column(String(255), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    visit: Mapped[Visit] = relationship(back_populates="outbox_items")


class CalendarDetail(Base):
    __tablename__ = "calendar_details"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    job_id: Mapped[str] = mapped_column(String(64), ForeignKey("jobs.id"), index=True)
    calendar_event_id: Mapped[str] = mapped_column(String(64), index=True)
    uid: Mapped[str] = mapped_column(String(255), default="")
    summary: Mapped[str] = mapped_column(String(500), default="")
    start_datetime: Mapped[str] = mapped_column(String(64), default="")
    end_datetime: Mapped[str] = mapped_column(String(64), default="")
    location: Mapped[str] = mapped_column(String(500), default="")
    description: Mapped[str] = mapped_column(Text, default="")

    job: Mapped[Job] = relationship(back_populates="calendar_details")


class EmailMessage(Base):
    __tablename__ = "email_messages"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    provider_id: Mapped[str | None] = mapped_column(String(255), unique=True, index=True, nullable=True)
    history_id: Mapped[str] = mapped_column(String(255), default="")
    thread_id: Mapped[str] = mapped_column(String(64), default="")
    sender: Mapped[str] = mapped_column(String(255), index=True)
    recipients: Mapped[str] = mapped_column(Text, default="")
    subject: Mapped[str] = mapped_column(String(500), index=True)
    body: Mapped[str] = mapped_column(Text, default="")
    received_at: Mapped[datetime] = mapped_column(DateTime, index=True)
    labels: Mapped[str] = mapped_column(Text, default="Inbox")
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    attachment_names: Mapped[str] = mapped_column(Text, default="")
    linked_job_id: Mapped[str | None] = mapped_column(String(64), nullable=True)


class ActivityEntry(Base):
    __tablename__ = "activity_entries"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    job_id: Mapped[str] = mapped_column(String(64), ForeignKey("jobs.id"), index=True)
    event_type: Mapped[str] = mapped_column(String(64), index=True)
    message: Mapped[str] = mapped_column(Text)
    actor: Mapped[str] = mapped_column(String(255), default="Manager")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    job: Mapped[Job] = relationship(back_populates="activities")


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    job_id: Mapped[str | None] = mapped_column(String(64), ForeignKey("jobs.id"), nullable=True, index=True)
    visit_id: Mapped[str | None] = mapped_column(String(64), ForeignKey("visits.id"), nullable=True)
    kind: Mapped[str] = mapped_column(String(64), index=True)
    title: Mapped[str] = mapped_column(String(500))
    message: Mapped[str] = mapped_column(Text, default="")
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)


class GoogleCredential(Base):
    __tablename__ = "google_credentials"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    account_email: Mapped[str] = mapped_column(String(320), unique=True)
    encrypted_refresh_token: Mapped[bytes] = mapped_column(LargeBinary)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    gmail_history_id: Mapped[str | None] = mapped_column(String(255), nullable=True)


class GoogleSyncState(Base):
    __tablename__ = "google_sync_states"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    gmail_history_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[str] = mapped_column(String(32), default="never")
    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    last_error: Mapped[str] = mapped_column(String(64), default="")
