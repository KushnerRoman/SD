# Security Depot FSM Mock API

Temporary FastAPI backend for the Security Depot field service management system.

## What It Does

- Uses MySQL for the temporary development database.
- Loads the generated historical data from:
  `../app/security_depot_fsm/assets/data/seed_data.json`
- Preserves full calendar descriptions/details inside each Job.
- Exposes mock API endpoints for the Flutter app.

## Start MySQL

From the project root:

```powershell
docker compose up -d mysql
```

If Docker reports that the Docker Desktop pipe is missing, open Docker Desktop first and wait until it is running.

The container maps MySQL to host port `3307` to avoid conflicts with any existing local MySQL server.

## Load Data

From `backend/`:

```powershell
uv run python scripts/init_db.py
```

Expected counts:

```text
sites: 130
jobs: 115
visits: 180
calendar_details: > 0
```

## Run API

From `backend/`:

```powershell
uv run uvicorn app.main:app --reload --host 127.0.0.1 --port 8765
```

Useful endpoints:

- `GET http://127.0.0.1:8765/health`
- `POST http://127.0.0.1:8765/admin/load-seed`
- `GET http://127.0.0.1:8765/dashboard/summary`
- `GET http://127.0.0.1:8765/jobs`
- `GET http://127.0.0.1:8765/jobs/{job_id}`
- `PATCH http://127.0.0.1:8765/jobs/{job_id}`
- `GET http://127.0.0.1:8765/sites`
- `GET http://127.0.0.1:8765/technicians`
- `GET http://127.0.0.1:8765/visits`

## Run Tests

Tests use SQLite in-memory, so they do not require Docker or MySQL.

```powershell
uv run pytest -q
```
