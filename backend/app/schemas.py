from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class SiteOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    normalized_name: str
    address: str
    slack_channel: str
    source: str
    needs_manual_review: bool


class SiteUpdate(BaseModel):
    name: str | None = None
    address: str | None = None
    slack_channel: str | None = None
    source: str | None = None
    needs_manual_review: bool | None = None


class SiteCreate(BaseModel):
    id: str
    name: str
    address: str = ""
    slack_channel: str = ""
    source: str = "Manual"
    needs_manual_review: bool = False


class TechnicianOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    email: str
    initials: str


class TechnicianCreate(BaseModel):
    id: str
    name: str
    email: str = ""
    initials: str = ""


class TechnicianUpdate(BaseModel):
    name: str | None = None
    email: str | None = None
    initials: str | None = None


class CalendarDetailOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    calendar_event_id: str
    uid: str
    summary: str
    start_datetime: str
    end_datetime: str
    location: str
    description: str


class JobOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    site_id: str | None
    site_name: str
    job_number: str
    title: str
    job_type: str
    priority: str
    status: str
    assigned_technician_id: str | None
    first_seen_date: str
    last_seen_date: str
    description: str
    details: str
    needs_parts: bool
    needs_return_visit: bool
    needs_manager_review: bool
    confidence: str
    calendar_details: list[CalendarDetailOut] = []


class JobUpdate(BaseModel):
    site_id: str | None = None
    site_name: str | None = None
    title: str | None = None
    description: str | None = None
    details: str | None = None
    status: str | None = None
    priority: str | None = None
    assigned_technician_id: str | None = None
    first_seen_date: str | None = None
    last_seen_date: str | None = None


class JobCreate(BaseModel):
    id: str
    site_id: str | None = None
    site_name: str = ""
    job_number: str = ""
    title: str
    job_type: str = "Service Call"
    priority: str = "Medium"
    status: str = "New"
    assigned_technician_id: str | None = None
    first_seen_date: str = ""
    last_seen_date: str = ""
    description: str = ""
    details: str = ""


class VisitOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    job_id: str | None
    site_id: str | None
    technician_id: str | None
    technician_name: str
    start_datetime: datetime | None
    end_datetime: datetime | None
    duration_minutes: int
    status: str
    work_summary: str
    parts_status: str
    needs_manual_review: bool


class VisitUpdate(BaseModel):
    status: str | None = None
    work_summary: str | None = None
    parts_status: str | None = None
    technician_id: str | None = None
    start_datetime: datetime | None = None
    end_datetime: datetime | None = None


class VisitCreate(BaseModel):
    id: str
    job_id: str | None = None
    site_id: str | None = None
    technician_id: str | None = None
    start_datetime: datetime | None = None
    end_datetime: datetime | None = None
    status: str = "Not Completed"
    work_summary: str = ""
    parts_status: str = "No Parts Used"


class DashboardSummary(BaseModel):
    total_jobs: int
    open_jobs: int
    new_jobs: int
    in_progress: int
    waiting_parts: int
    completed: int
    needs_manager_review: int
