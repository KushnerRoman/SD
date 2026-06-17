from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
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

    jobs: Mapped[list["Job"]] = relationship(back_populates="site")
    visits: Mapped[list["Visit"]] = relationship(back_populates="site")


class Technician(Base):
    __tablename__ = "technicians"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(255), index=True)
    email: Mapped[str] = mapped_column(String(255), default="")
    initials: Mapped[str] = mapped_column(String(16), default="")

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

    site: Mapped[Site | None] = relationship(back_populates="jobs")
    assigned_technician: Mapped[Technician | None] = relationship(back_populates="jobs")
    visits: Mapped[list["Visit"]] = relationship(back_populates="job")
    calendar_details: Mapped[list["CalendarDetail"]] = relationship(back_populates="job", cascade="all, delete-orphan")


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

    job: Mapped[Job | None] = relationship(back_populates="visits")
    site: Mapped[Site | None] = relationship(back_populates="visits")
    technician: Mapped[Technician | None] = relationship(back_populates="visits")


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
