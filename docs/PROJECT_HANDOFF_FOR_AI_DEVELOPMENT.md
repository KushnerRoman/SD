# Security Depot Project Handoff for AI-Assisted Development

Generated from local repository inspection on 2026-09-09.

This document is intended for the next developer and their AI coding assistant. It summarizes what this repository contains, what is actively used, what appears historical or generated, what has already been implemented, and where the next work should start.

## Executive Summary

The repository currently contains two main product tracks:

1. **Security Depot Operations Command Center**
   - Flutter web app in `app/security_depot_fsm`.
   - FastAPI and SQLite backend in `backend`.
   - This is the active field-service management application.
   - It supports jobs, sites, technicians, visits, email-driven dispatch, Google OAuth, Gmail read-only sync, Google Calendar delivery, and signed technician report links.

2. **Security Depot Gateway**
   - A customized `go2rtc` fork in `go2rtc-fork`.
   - This is a Windows site-PC gateway for cameras/NVR integration.
   - It provides a local setup UI, ONVIF/DW Spectrum compatibility, camera scanning/provisioning, generated go2rtc YAML, fallback video, and installer packaging.

There are also historical data-import scripts, planning documents, duplicated source documents, generated cache folders, and a not-yet-implemented website redesign plan.

## Current Git State

At inspection time, the tracked worktree is clean after excluding generated cache folders. The only non-cache untracked item found was:

- `sd-log-crop.png`

There is a lot of churn under `.gocache`, `.codex-remote-attachments`, and `tmp`. These should be treated as local/generated workspace artifacts, not product work.

Recommended before handoff:

- Do not commit `.gocache`, `tmp`, `.codex-remote-attachments`, local databases, logs, or virtual environments.
- Decide whether `sd-log-crop.png` is useful evidence/documentation. If not, leave it untracked or move it out of the repo.
- Consider adding `.gocache/`, `.gotmp/`, `tmp/`, and `.codex-remote-attachments/` to `.gitignore` if they are not intentionally tracked.

## Active Application: Operations Command Center

### Frontend

Location:

- `app/security_depot_fsm`

Technology:

- Flutter / Dart
- Material 3
- `http`
- `url_launcher`

Main entry point:

- `app/security_depot_fsm/lib/main.dart`

Current runtime behavior:

- The app starts by creating `ApiFieldServiceRepository`.
- It pings `/dashboard/summary` with a 2-second timeout.
- If the backend is unavailable, it shows a connection error.
- On web, API calls resolve against `Uri.base`, so the built Flutter app is intended to be served by the backend under `/web/`.
- On non-web platforms, API calls target `http://127.0.0.1:8765`.

Screens currently wired into the app shell:

- Dashboard
- Inbox
- Schedule
- Jobs
- Sites
- Technicians
- Visit
- History
- Calendar
- Settings

Repository implementations:

- `ApiFieldServiceRepository`: active production path.
- `MockFieldServiceRepository`: used by Flutter tests and local widget scenarios.
- `SeedFieldServiceRepository`: historical/static JSON seed path; useful for tests and data import validation, but not the current runtime path in `main.dart`.

Important note:

- `assets/data/seed_data.json` is still listed in `pubspec.yaml` and used by `SeedFieldServiceRepository` tests. Do not delete it unless the tests and historical import path are deliberately removed.

### Backend

Location:

- `backend`

Technology:

- Python 3.11+
- FastAPI
- SQLAlchemy 2
- SQLite by default
- httpx
- cryptography/Fernet
- pytest

Main entry point:

- `backend/app/main.py`

Default database:

- `backend/security_depot.db`
- Overridable with `DATABASE_URL`.
- Local database files are ignored by `.gitignore`.

Backend startup:

- `create_schema()` creates tables and runs additive SQLite migrations.
- Startup no longer seeds demo operations data automatically.
- FastAPI lifespan starts a Google sync scheduler.

Useful run command:

```powershell
cd app\security_depot_fsm
flutter build web --base-href /web/
cd ..\..\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8765
```

Open:

```text
http://127.0.0.1:8765/web/
```

Core API areas:

- Health: `/health`
- Static Flutter app: `/web/`
- Google auth: `/auth/google/start`, `/auth/google/callback`, `/auth/google/disconnect`
- Google sync: `/google/connection`, `/google/sync`, `/google/sync-status`, `/google/calendar/deliver`
- Inbox: `/emails`, `/emails/{email_id}`
- Dispatch workflow: `/dispatch/from-email`
- Notifications: `/notifications`, `/notifications/{id}/read`
- Technician report API/page: `/visits/{id}/report`, `/report/{token}`
- CRUD: `/sites`, `/technicians`, `/jobs`, `/visits`

Key backend modules:

- `app/database.py`: engine, sessions, schema creation, additive SQLite upgrades.
- `app/models.py`: SQLAlchemy models for sites, jobs, visits, email, notifications, Google credentials, calendar outbox, report tokens.
- `app/schemas.py`: Pydantic request/response models.
- `app/workflows.py`: email-to-service-call and technician-report workflows.
- `app/cleanup.py`: guarded operational cleanup logic that preserves sites.
- `app/seed_loader.py`: seed loading and legacy import utilities.
- `app/report_tokens.py`: signed report-link token lifecycle.
- `app/report_pages.py`: server-rendered technician report pages.
- `app/google/*`: Google OAuth, Gmail, Calendar, outbox, sync coordinator, scheduler, config.

Backend scripts:

- `backend/scripts/init_db.py`: schema-only initialization.
- `backend/scripts/clear_demo_data.py`: guarded cleanup of operational data. Requires `--confirm-delete-operational-data`.
- `backend/scripts/print_counts.py`: database count inspection.

Google configuration:

- Current implemented mode expects environment variables:
  - `GOOGLE_CLIENT_ID`
  - `GOOGLE_CLIENT_SECRET`
  - `GOOGLE_REDIRECT_URI`
  - `TOKEN_ENCRYPTION_KEY`
- Required redirect URI:
  - `http://127.0.0.1:8765/auth/google/callback`
- Detailed instructions are in `docs/google-localhost-setup.md`.

Security caveat:

- There is no implemented manager login/auth gate in the current code. A plan exists for local manager login and encrypted Google setup, but the files described in that plan are not present. See "Planned But Not Implemented".

## Active Product Track: Security Depot Gateway

Location:

- `go2rtc-fork`

Technology:

- Go
- Customized fork of `github.com/AlexxIT/go2rtc`
- Windows installer packaging with Inno Setup
- PowerShell installer/start/stop scripts

Main entry point:

- `go2rtc-fork/main.go`

Security Depot integration entry points:

- `go2rtc-fork/internal/api/security_depot.go`
- `go2rtc-fork/internal/securitydepot/*`
- `go2rtc-fork/www/security-depot.html`
- `go2rtc-fork/packaging/security-depot/*`

Gateway API surface:

- `api/security-depot/site`
- `api/security-depot/workspace`
- `api/security-depot/draft`
- `api/security-depot/scan`
- `api/security-depot/recommend`
- `api/security-depot/preview`
- `api/security-depot/apply`
- `api/security-depot/restart`
- `api/security-depot/rollback`
- `api/security-depot/health`
- `api/security-depot/provisioning/scan`
- `api/security-depot/provisioning/test`
- `api/security-depot/provisioning/name`
- `api/security-depot/network/interfaces`
- `api/security-depot/network/apply`

Gateway purpose:

- Install a local Security Depot Gateway on a Windows site PC.
- Scan Hikvision/NVR/direct-camera sources.
- Expose selected channels to DW Spectrum as ONVIF devices.
- Generate and apply go2rtc YAML.
- Preserve camera secrets in workspace state.
- Provide fallback media for failed streams.
- Build a Windows installer.

Important runtime paths:

- ProgramData root: `C:\ProgramData\Security Depot Gateway`
- Config: `C:\ProgramData\Security Depot Gateway\config\go2rtc.yaml`
- Site/workspace/identity state lives under the same ProgramData root.

Gateway build command:

```powershell
cd go2rtc-fork
.\packaging\security-depot\scripts\build-installer.ps1
```

Build requirements:

- Go toolchain
- Inno Setup 6 compiler
- Clean tracked worktree for production builds
- FFmpeg preparation script must succeed

Focused gateway tests/build script currently runs:

```powershell
go test ./internal/app ./internal/securitydepot ./internal/api ./internal/onvif ./pkg/onvif ./internal/service ./internal/ffmpeg ./pkg/ffmpeg -count=1
go vet -stdmethods=false ./internal/app ./internal/securitydepot ./internal/api ./internal/onvif ./pkg/onvif ./internal/service ./internal/ffmpeg ./pkg/ffmpeg
go build -buildvcs=false -trimpath -ldflags <release-flags> -o outputs\SecurityDepotGateway.exe .
```

## Historical / Auxiliary Areas

### Data Import Scripts

Location:

- `scripts/historical_dataset`
- root scripts `build_slack_active_channels.mjs`, `build_slack_channel_addresses.mjs`

Purpose:

- Parse historical calendar and Slack/source data.
- Build review artifacts and seed data.
- Support early MVP dataset creation.

Current status:

- These are not part of the current normal app runtime.
- Tests still exist under `tests/historical_dataset`.
- Keep them if future imports or auditability matter. Archive them only after confirming no future historical re-import is needed.

Important note:

- There is a `package-lock.json` but no root `package.json` found during inspection. That makes root Node script setup ambiguous. If these scripts still matter, recreate or recover the root `package.json` or document how dependencies are installed.

### Root `internal/securitydepot`

Location:

- `internal/securitydepot`

Current status:

- Contains Go files/tests similar in theme to the gateway code.
- There is no root `go.mod` found, while the active Go module is under `go2rtc-fork`.
- This likely predates or was split from the active `go2rtc-fork/internal/securitydepot` implementation.

Recommendation:

- Treat as likely historical unless a developer can show a current build/test path that imports it.
- Do not delete blindly. Compare it against `go2rtc-fork/internal/securitydepot` first if cleanup is planned.

### Archived Gateway Test Package

Location:

- `go2rtc-removed-for-first-client-test-20260626-220126`

Contents:

- Old `go2rtc.exe` binaries/zips
- `go2rtc.yaml`
- `security-depot-site.json`
- backup JSON/YAML files
- fallback video

Current status:

- Appears to be a preserved client-test artifact.
- Not active runtime source.

Recommendation:

- Move to external archive/storage if repository size or clarity matters.
- Keep only if it is needed as evidence of the first client test package.

### Documents Folder Duplication

Locations:

- `docs/*`
- `documents/*`

Current status:

- `documents` appears to duplicate early discovery/product/architecture source documents and an `.ics` file.
- `docs` is the canonical developer documentation location now.

Recommendation:

- Treat `docs` as canonical.
- Keep `documents` only if it is an original-source archive.

### Generated / Local Artifacts

Likely generated or local-only:

- `.gocache`
- `.gotmp` if present
- `tmp`
- `.codex-remote-attachments`
- `node_modules`
- `outputs`
- `backend/.venv`
- `backend/.pytest_cache`
- `backend/app/__pycache__`
- `backend/tests/__pycache__`
- `backend/*.db`
- `*.pyc`
- `*.log`

These should not be committed.

## Planned But Not Implemented

### Local Manager Login and Google Setup Wizard

Plan:

- `docs/superpowers/plans/2026-07-12-local-manager-setup.md`

Spec:

- `docs/superpowers/specs/2026-07-12-local-manager-setup-design.md`

Status:

- Planned only.
- Expected files such as `backend/app/auth.py`, `backend/app/local_secrets.py`, `backend/app/setup.py`, and Flutter `features/auth/*` are not present.
- Current backend still uses Google secrets from environment variables.
- Current app has no manager login gate.

This is likely the highest-priority next feature if the software will be used beyond trusted localhost/manual testing.

### Security Depot Marketing Website Redesign

Plan:

- `docs/superpowers/plans/2026-07-13-security-depot-redesign.md`

Spec:

- `docs/superpowers/specs/2026-07-13-security-depot-redesign-design.md`

Status:

- Planned only.
- The planned app directory `app/security_depot_web` was not found.
- This is separate from the Operations Command Center and should remain isolated if implemented.

## Completed Work From Git History

Recent history indicates these completed milestones:

- Project baseline and operations-core design.
- Flutter MVP shell.
- Historical dataset review/import tooling.
- Persistent dispatch workflow.
- Operations Command Center demo.
- Google integration design and implementation plan.
- Site-preserving cleanup and removal of demo operations startup behavior.
- Secure Google OAuth connection.
- Real Gmail read-only synchronization.
- Calendar invitations through outbox delivery.
- Signed technician report links.
- Background Google sync scheduler.
- Several hardening passes:
  - OAuth callback handling.
  - Gmail incremental synchronization.
  - Calendar outbox delivery.
  - Stable report links across retries.
  - Report signing key derivation.
  - Google sync lifecycle/status.
  - Cleanup table counts.
  - Composite Google synchronization.
  - Isolation of app-created service calendar.
- Documentation/planning for local manager setup and Security Depot website redesign.

## Verification Commands

Use these before claiming a change is complete.

Backend:

```powershell
cd backend
.\.venv\Scripts\python.exe -m pytest tests -q
```

Flutter:

```powershell
cd app\security_depot_fsm
flutter analyze
flutter test
flutter build web --base-href /web/
```

Gateway:

```powershell
cd go2rtc-fork
go test ./internal/app ./internal/securitydepot ./internal/api ./internal/onvif ./pkg/onvif ./internal/service ./internal/ffmpeg ./pkg/ffmpeg -count=1
go vet -stdmethods=false ./internal/app ./internal/securitydepot ./internal/api ./internal/onvif ./pkg/onvif ./internal/service ./internal/ffmpeg ./pkg/ffmpeg
```

Gateway installer:

```powershell
cd go2rtc-fork
.\packaging\security-depot\scripts\build-installer.ps1
```

Historical dataset scripts:

```powershell
node --test tests\historical_dataset
```

Caveat:

- The root Node setup is unclear because `package-lock.json` exists but `package.json` was not found.

## Recommended Next Development Order

1. **Clean handoff state**
   - Update `.gitignore` for generated folders if desired.
   - Decide what to do with `sd-log-crop.png`.
   - Do not include cache/temp artifacts in handoff commits.

2. **Run full verification**
   - Backend tests.
   - Flutter analyze/test/build.
   - Gateway focused Go tests if gateway work will continue.

3. **Implement manager login and first-run setup**
   - Start from `docs/superpowers/plans/2026-07-12-local-manager-setup.md`.
   - This addresses the current trusted-localhost/authentication gap.

4. **Clarify data lifecycle**
   - Decide whether the product should use live Google only, historical seeds only for tests, or both.
   - Keep site data preservation as a hard rule.

5. **Separate product tracks**
   - Treat `backend` + `app/security_depot_fsm` as the FSM app.
   - Treat `go2rtc-fork` as the camera gateway.
   - Do not cross-wire the marketing website plan into either unless there is an explicit product decision.

6. **Optional repository cleanup**
   - Archive old gateway test package.
   - Reconcile duplicated docs in `documents`.
   - Resolve root Node script dependency setup.
   - Compare and remove root `internal/securitydepot` only after confirming it is obsolete.

## AI Development Guidance

Give the next AI assistant this instruction before development:

```text
You are working in the Security Depot repository. First read docs/PROJECT_HANDOFF_FOR_AI_DEVELOPMENT.md, app/security_depot_fsm/README.md, backend/README.md, docs/google-localhost-setup.md, and any relevant plan/spec under docs/superpowers. Do not edit code until you have identified whether the task belongs to the FSM app, backend, gateway, historical dataset tooling, or planned website. Preserve user data and site records. Do not commit secrets, local databases, cache folders, generated binaries, or temp files.
```

For FSM work:

- Prefer changes through the repository boundary in `FieldServiceRepository`.
- Keep backend state authoritative in SQLite.
- Write/adjust backend tests for workflow/API behavior.
- Write/adjust Flutter tests for repository parsing and UI behavior.

For gateway work:

- Work inside `go2rtc-fork`.
- Keep Security Depot-specific behavior in `internal/securitydepot`, `internal/api/security_depot.go`, `www/security-depot.html`, and `packaging/security-depot`.
- Run focused Go tests before installer builds.

For cleanup work:

- Do not delete historical or archive-like folders without confirming their business value.
- Document any removal in a commit message and in this handoff document.

## Known Risks / Gaps

- No current manager authentication for the Operations Command Center.
- Google configuration currently depends on environment variables, not a first-run UI.
- Root Node historical tooling has a lockfile but no `package.json`.
- `docker-compose.yml` defines MySQL, but the active backend defaults to SQLite. MySQL appears historical or future-facing unless `DATABASE_URL` is configured.
- Gateway and FSM are in the same repository but are operationally separate products.
- Generated/local folders are noisy in `git status` and can distract an AI worker.
- The planned website redesign is not implemented; do not assume `app/security_depot_web` exists.

## Files That Are Safe To Read First

- `app/security_depot_fsm/README.md`
- `backend/README.md`
- `docs/google-localhost-setup.md`
- `docs/QA_Test_Plan_MVP_v0.1.md`
- `docs/superpowers/plans/2026-07-12-local-manager-setup.md`
- `docs/superpowers/plans/2026-07-13-security-depot-redesign.md`
- `go2rtc-fork/packaging/security-depot/README.txt`
- `go2rtc-fork/packaging/security-depot/docs/Installation-and-Operations-Guide.md`

