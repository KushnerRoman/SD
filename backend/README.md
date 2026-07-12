# Security Depot local API

FastAPI serves the persistent SQLite operations API and the built Flutter web application at `http://127.0.0.1:8765/web/`.

From the repository root:

```powershell
backend\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8765
```

Useful read endpoints include `/health`, `/dashboard/summary`, `/jobs`, `/sites`, `/technicians`, and `/visits`. Operational writes require the application workflows; destructive maintenance is CLI-only and confirmation-guarded.

Run the complete backend suite with:

```powershell
backend\.venv\Scripts\pytest.exe backend\tests -q
```

For Google Cloud configuration, exact OAuth scopes and redirect URI, environment variables, guarded cleanup, startup, consent, real-email validation, credential rotation, and disconnect, follow [Google localhost setup](../docs/google-localhost-setup.md).
