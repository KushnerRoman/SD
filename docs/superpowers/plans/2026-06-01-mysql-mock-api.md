# MySQL Mock API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a temporary FastAPI + MySQL backend that stores the generated historical Security Depot data and exposes job/site/technician/visit endpoints for the Flutter app.

**Architecture:** MySQL is provided by Docker Compose. FastAPI uses SQLAlchemy models and can load seed data from `app/security_depot_fsm/assets/data/seed_data.json`. Tests use SQLite in-memory so API behavior can be verified even if Docker Desktop is not running.

**Tech Stack:** Python, FastAPI, SQLAlchemy, PyMySQL, MySQL 8, Docker Compose, pytest.

---

## Tasks

1. Regenerate seed JSON so each Job contains full calendar text/details from source events.
2. Create backend Python package and SQLAlchemy models.
3. Create seed loader that upserts sites, technicians, jobs, and visits.
4. Create FastAPI endpoints for dashboard summary, jobs, sites, technicians, visits, and job updates.
5. Create Docker Compose for MySQL.
6. Add tests for seed loading and API behavior.
7. Run tests and document how to start MySQL/API.
