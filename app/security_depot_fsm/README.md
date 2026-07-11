# Security Depot Operations Command Center

Persistent field-service demo for managers. It includes a mixed Gmail-style inbox, email-to-service-call dispatch, schedule and workload views, sites, technicians, service history, and a simulated Google Calendar technician reporting flow.

## Run the complete demo

From the repository root:

```powershell
cd app\security_depot_fsm
flutter build web --base-href /web/
cd ..\..\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8765
```

Open `http://127.0.0.1:8765/web/`. SQLite data is stored in `backend/security_depot.db` and survives restarts. Settings → Reset demo data restores the original scenario.

## Suggested walkthrough

1. Open Inbox and choose one of the bold service-request messages.
2. Select Create service call, confirm the site and technician, then assign it.
3. Verify the call appears in Jobs, Schedule, and the selected technician's Calendar Demo.
4. Open the calendar event and submit time spent, work performed, materials, and result.
5. Review the updated dashboard, notification count, job status, and History screen.

The Google connections are simulated in this phase. Real Google OAuth, Gmail, and Calendar APIs are intentionally deferred.
