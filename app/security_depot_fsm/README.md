# Security Depot Operations Command Center

Persistent field-service application for managers, including email-to-service-call dispatch, scheduling, sites, technicians, service history, and technician reporting.

## Run the application

From the repository root:

```powershell
cd app\security_depot_fsm
flutter build web --base-href /web/
cd ..\..\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8765
```

Open `http://127.0.0.1:8765/web/`. SQLite data is stored in `backend/security_depot.db` and survives restarts. If the API is unavailable, the app shows a connection error instead of loading demo data.

## Suggested walkthrough

1. Open Inbox and choose a service-request message.
2. Select Create service call, confirm the site and technician, then assign it.
3. Verify the call appears in Jobs and Schedule.
4. Open the visit and submit time spent, work performed, materials, and result.
5. Review the updated dashboard, notification count, job status, and History screen.

Google connection setup is shown as disconnected until OAuth is configured.
