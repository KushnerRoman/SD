# Google OAuth, Gmail, and Calendar Localhost Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace simulated operational data with a persistent, manager-authorized personal Google integration that imports real Gmail, creates technician Calendar invitations, and accepts signed localhost service reports while preserving all Site records.

**Architecture:** FastAPI owns OAuth, encrypted credentials, Google providers, background synchronization, outbox delivery, and report tokens. Flutter consumes explicit connection/sync state through the existing repository boundary. SQLite remains authoritative for local business state; Gmail and Calendar identifiers make synchronization idempotent.

**Tech Stack:** Python 3.12, FastAPI, SQLAlchemy 2, SQLite, Authlib/google-auth-compatible OAuth primitives, cryptography/Fernet, httpx, pytest, Flutter/Dart, Material 3, flutter_test.

## Global Constraints

- Preserve every existing Site record.
- Delete all demo emails, service calls, visits, technicians, activities, notifications, and simulated calendar records.
- Remove automatic seed loading and Reset Demo Data behavior.
- Run only at `http://127.0.0.1:8765` in this phase.
- Use one manager-owned personal Google account and one manager-owned Security Depot service calendar.
- Gmail access is read-only; do not modify, label, archive, trash, delete, or send mail.
- Technicians are event guests and do not receive shared-calendar edit permission.
- Technician report links are opened on the manager's computer during localhost testing.
- Synchronize every 90 seconds and through Sync Now; do not add public webhooks.
- Never commit OAuth credentials, encryption keys, refresh tokens, or real Gmail content.

---

### Task 1: Site-Preserving Cleanup and Empty Startup

**Files:**
- Create: `backend/app/cleanup.py`
- Create: `backend/scripts/clear_demo_data.py`
- Modify: `backend/app/main.py`
- Modify: `backend/app/seed_loader.py`
- Modify: `backend/app/schemas.py`
- Modify: `backend/tests/test_seed_loader.py`
- Create: `backend/tests/test_cleanup.py`
- Modify: `app/security_depot_fsm/lib/features/settings/settings_screen.dart`

**Interfaces:**
- Produces: `cleanup_operational_data(session: Session) -> CleanupResult` with before/after counts.
- Produces: explicit command `python backend/scripts/clear_demo_data.py --confirm-delete-operational-data`.

- [ ] **Step 1: Write failing cleanup tests**

```python
def test_cleanup_preserves_sites_and_deletes_everything_else(session):
    site_ids = {row.id for row in session.query(Site).all()}
    result = cleanup_operational_data(session)
    assert {row.id for row in session.query(Site).all()} == site_ids
    assert result.after == {"sites": len(site_ids), "jobs": 0, "visits": 0,
                            "emails": 0, "technicians": 0,
                            "activities": 0, "notifications": 0}
```

Also assert startup on an empty database creates schema but does not seed jobs/emails/technicians, and remove tests expecting reset-demo data.

- [ ] **Step 2: Run red tests**

Run: `backend\.venv\Scripts\pytest.exe backend\tests\test_cleanup.py backend\tests\test_seed_loader.py -q`

Expected: FAIL because `cleanup_operational_data` is missing and startup still seeds demo data.

- [ ] **Step 3: Implement ordered cleanup and explicit CLI guard**

Delete notifications → activities → calendar/outbox rows → visits → jobs → email → technicians → connection/sync state. Keep Sites untouched. The CLI exits nonzero unless the exact confirmation flag is present and prints JSON counts.

- [ ] **Step 4: Remove startup/reset seed behavior**

Remove `reset_and_load_seed` from startup and delete `/admin/reset-demo`. Replace Settings reset UI with Google Connection placeholder state.

- [ ] **Step 5: Verify and commit**

Run: `backend\.venv\Scripts\pytest.exe backend\tests -q`

Expected: PASS.

Commit: `git commit -am "feat: preserve sites and remove demo operations data"`

### Task 2: OAuth Configuration and Encrypted Credentials

**Files:**
- Modify: `backend/pyproject.toml`
- Modify: `backend/uv.lock`
- Create: `backend/.env.example`
- Modify: `.gitignore`
- Create: `backend/app/google/config.py`
- Create: `backend/app/google/oauth.py`
- Create: `backend/app/google/__init__.py`
- Modify: `backend/app/models.py`
- Modify: `backend/app/schemas.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/test_google_oauth.py`

**Interfaces:**
- Produces: `GoogleSettings.from_env()`, `CredentialCipher.encrypt/decrypt`, `GoogleOAuthService.authorization_url`, `exchange_code`, `refresh_access_token`, and `revoke`.
- Produces routes: `GET /auth/google/start`, `GET /auth/google/callback`, `POST /auth/google/disconnect`, `GET /google/connection`.

- [ ] **Step 1: Write failing OAuth and encryption tests**

Test missing-config reporting without secret values, state/PKCE generation, wrong-state rejection, callback token exchange through `httpx.MockTransport`, encrypted-at-rest refresh tokens, refresh, revoke, and disconnected/connected/expired schemas.

```python
def test_refresh_token_is_not_stored_in_plaintext(session, oauth_service):
    oauth_service.store_tokens(session, account_email="manager@gmail.com",
                               refresh_token="secret-refresh")
    record = session.query(GoogleCredential).one()
    assert b"secret-refresh" not in record.encrypted_refresh_token
    assert oauth_service.load_refresh_token(record) == "secret-refresh"
```

- [ ] **Step 2: Run red tests**

Run: `backend\.venv\Scripts\pytest.exe backend\tests\test_google_oauth.py -q`

Expected: FAIL for missing Google modules/models.

- [ ] **Step 3: Implement configuration, OAuth, and credential model**

Use environment-only secrets, constant-time state comparison, PKCE S256, `access_type=offline`, `prompt=consent` only when no refresh token exists, authenticated encryption, and narrow configured scopes.

- [ ] **Step 4: Implement HTTP routes and safe connection schema**

Never return tokens/secrets. Callback redirects to `/web/#/settings?google=connected` on success and a non-sensitive error code on failure.

- [ ] **Step 5: Verify and commit**

Run: `backend\.venv\Scripts\pytest.exe backend\tests\test_google_oauth.py -q`

Expected: PASS.

Commit: `git commit -am "feat: add secure Google OAuth connection"`

### Task 3: Real Gmail Read-Only Synchronization

**Files:**
- Create: `backend/app/google/gmail.py`
- Create: `backend/app/google/mime_parser.py`
- Create: `backend/app/google/sync.py`
- Modify: `backend/app/models.py`
- Modify: `backend/app/schemas.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/fixtures/gmail_messages.py`
- Create: `backend/tests/test_gmail_sync.py`

**Interfaces:**
- Produces: `GmailProvider.list_recent`, `list_history`, `get_message`; `parse_gmail_message(payload) -> NormalizedMessage`; `GoogleSyncCoordinator.sync_gmail(session) -> SyncCounts`.
- Produces routes: `POST /google/sync`, `GET /google/sync-status`.

- [ ] **Step 1: Write failing MIME and synchronization tests**

Cover plain text, HTML fallback stripping, multipart alternative, nested MIME, encoded headers, attachment metadata without body downloads, pagination, 90-day query, history IDs, duplicate message IDs, deleted messages, and revoked/quota/network errors.

```python
def test_initial_sync_is_idempotent(session, gmail_provider):
    coordinator.sync_gmail(session)
    coordinator.sync_gmail(session)
    assert session.query(EmailMessage).filter_by(provider_id="msg-1").count() == 1
```

- [ ] **Step 2: Run red tests**

Run: `backend\.venv\Scripts\pytest.exe backend\tests\test_gmail_sync.py -q`

Expected: FAIL for missing provider/parser/coordinator.

- [ ] **Step 3: Implement HTTP provider and MIME normalization**

Request `format=full`, store provider/thread/history identifiers, headers, normalized text, labels, received time, and attachment names/sizes only.

- [ ] **Step 4: Implement initial and incremental sync**

Use `newer_than:90d` for initial import and `users.history.list` thereafter. Persist history only after a successful page sequence. Map 401/403/429/5xx into typed sync errors.

- [ ] **Step 5: Add Sync Now/status routes and verify**

Run: `backend\.venv\Scripts\pytest.exe backend\tests\test_gmail_sync.py -q`

Expected: PASS.

Commit: `git commit -am "feat: synchronize real Gmail inbox"`

### Task 4: Calendar Provider, Outbox, and Invitations

**Files:**
- Create: `backend/app/google/calendar.py`
- Create: `backend/app/google/outbox.py`
- Modify: `backend/app/models.py`
- Modify: `backend/app/schemas.py`
- Modify: `backend/app/workflows.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/test_calendar_sync.py`
- Modify: `backend/tests/test_workflows.py`

**Interfaces:**
- Produces: `CalendarProvider.list_calendars`, `create_service_calendar`, `insert_event`, `update_event`, `get_changed_events`.
- Produces: `enqueue_calendar_operation(session, visit, operation)` and `process_calendar_outbox(session, provider)`.

- [ ] **Step 1: Write failing calendar/outbox tests**

Test service-calendar selection/creation, stable event IDs, site location, instructions, technician attendee, `sendUpdates=all`, signed report URL, update-with-etag, 412 conflict refresh, ambiguous-timeout retry, and no duplicate events.

```python
def test_dispatch_commits_local_visit_before_calendar_delivery(session):
    job = dispatch_from_email(session, payload)
    assert job.visits[0].calendar_event_id == ""
    assert session.query(CalendarOutbox).filter_by(visit_id=job.visits[0].id,
                                                   status="pending").one()
```

- [ ] **Step 2: Run red tests**

Run: `backend\.venv\Scripts\pytest.exe backend\tests\test_calendar_sync.py backend\tests\test_workflows.py -q`

Expected: FAIL for missing calendar/outbox contracts.

- [ ] **Step 3: Implement Calendar provider and settings**

Persist selected calendar ID, event ID, etag, last sync token, and timestamps. Use the visit-derived stable event ID and attendee email.

- [ ] **Step 4: Replace direct simulated event creation with outbox enqueueing**

Dispatch stays successful locally when Google is down. Outbox uses bounded exponential retry, stores safe error text, and marks authorization errors for reconnect.

- [ ] **Step 5: Verify and commit**

Run: `backend\.venv\Scripts\pytest.exe backend\tests\test_calendar_sync.py backend\tests\test_workflows.py -q`

Expected: PASS.

Commit: `git commit -am "feat: deliver real Calendar invitations"`

### Task 5: Signed Localhost Technician Reports

**Files:**
- Create: `backend/app/report_tokens.py`
- Create: `backend/app/report_pages.py`
- Modify: `backend/app/models.py`
- Modify: `backend/app/workflows.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/test_report_links.py`
- Modify: `backend/tests/test_calendar_sync.py`

**Interfaces:**
- Produces: `issue_report_token(session, visit) -> str`, `resolve_report_token(session, raw_token) -> Visit`, `close_report_token`.
- Produces routes/pages: `GET /report/{token}`, `POST /report/{token}`.

- [ ] **Step 1: Write failing report-token and page tests**

Test 256-bit random tokens, SHA-256 hashes at rest, neutral invalid response, closed/revoked token rejection, required duration/work/follow-up, completion transaction, notification, history, and Calendar update outbox enqueueing.

- [ ] **Step 2: Run red tests**

Run: `backend\.venv\Scripts\pytest.exe backend\tests\test_report_links.py -q`

Expected: FAIL for missing report modules.

- [ ] **Step 3: Implement token lifecycle and minimal responsive report page**

Render escaped server-side HTML with no manager navigation. POST uses CSRF tied to the token session and validates all structured fields.

- [ ] **Step 4: Update event builder with signed localhost URL**

Use configured public base `http://127.0.0.1:8765`; never embed customer/job data in the URL.

- [ ] **Step 5: Verify and commit**

Run: `backend\.venv\Scripts\pytest.exe backend\tests\test_report_links.py backend\tests\test_calendar_sync.py -q`

Expected: PASS.

Commit: `git commit -am "feat: add signed technician report links"`

### Task 6: Background Synchronizer and Flutter Google Connection

**Files:**
- Create: `backend/app/google/scheduler.py`
- Modify: `backend/app/main.py`
- Modify: `app/security_depot_fsm/lib/domain/models.dart`
- Modify: `app/security_depot_fsm/lib/data/field_service_repository.dart`
- Modify: `app/security_depot_fsm/lib/data/api_field_service_repository.dart`
- Rewrite: `app/security_depot_fsm/lib/features/settings/settings_screen.dart`
- Modify: `app/security_depot_fsm/lib/features/dashboard/dashboard_screen.dart`
- Create: `app/security_depot_fsm/test/google_connection_test.dart`
- Create: `backend/tests/test_scheduler.py`

**Interfaces:**
- Produces: one non-overlapping 90-second local scheduler lifecycle.
- Produces Flutter `GoogleConnectionState`, `SyncStatus`, `getGoogleConnection`, `startGoogleConnection`, `disconnectGoogle`, `syncGoogleNow`.

- [ ] **Step 1: Write failing scheduler and Flutter repository/widget tests**

Test one startup task, 90-second cadence through fake clock, overlap prevention, shutdown cancellation, connection states, safe errors, Connect/Reconnect/Disconnect, Sync Now, last/next sync, and empty operational dashboard after cleanup.

- [ ] **Step 2: Run red tests**

Run backend: `backend\.venv\Scripts\pytest.exe backend\tests\test_scheduler.py -q`

Run Flutter: `flutter test test/google_connection_test.dart test/api_repository_test.dart`

Expected: FAIL for missing scheduler/state/repository methods.

- [ ] **Step 3: Implement FastAPI lifespan scheduler**

Replace deprecated startup event with lifespan context, perform schema setup, start one async task, use a non-blocking lock, and cancel cleanly.

- [ ] **Step 4: Implement Flutter contracts and Connection UI**

Open `/auth/google/start` in the current browser, poll connection status after callback, expose manual sync, and require confirmation before disconnect.

- [ ] **Step 5: Verify and commit**

Run both focused suites. Expected: PASS.

Commit: `git commit -am "feat: add Google connection and scheduled sync"`

### Task 7: Real-Data UX, Documentation, and End-to-End Verification

**Files:**
- Modify: `app/security_depot_fsm/lib/features/inbox/inbox_screen.dart`
- Modify: `app/security_depot_fsm/lib/features/calendar_demo/calendar_demo_screen.dart`
- Modify: `app/security_depot_fsm/lib/features/technicians/technicians_screen.dart`
- Modify: `app/security_depot_fsm/lib/main.dart`
- Modify: `app/security_depot_fsm/README.md`
- Modify: `backend/README.md`
- Create: `docs/google-localhost-setup.md`
- Modify: `app/security_depot_fsm/test/widget_test.dart`

**Interfaces:**
- Consumes all prior backend and Flutter contracts.
- Produces exact Google Cloud setup, cleanup, startup, connect, test-email, dispatch, report, restart, and disconnect instructions.

- [ ] **Step 1: Write failing empty/real-data widget tests**

Assert no demo/reset wording, disconnected setup guidance, empty inbox before connect, imported real messages after sync, technician Gmail validation, pending/synced Calendar badges, and report-link copy/open action.

- [ ] **Step 2: Update real-data states and remove simulated Calendar mode**

Rename Calendar Demo to Calendar, show local/queued/synced/failed states, and retain manager preview without implying Google guest editing.

- [ ] **Step 3: Write exact setup documentation**

Document API enablement, External audience, test/personal-use warning, redirect URI, required environment variables, Fernet key generation, cleanup command, startup, consent, sync, and safe credential rotation. Do not include real addresses or credentials.

- [ ] **Step 4: Run complete automated verification**

Run: `backend\.venv\Scripts\pytest.exe backend\tests -q`

Run: `flutter analyze`

Run: `flutter test`

Run: `flutter build web --base-href /web/`

Expected: all tests PASS, analysis has no issues, and build succeeds.

- [ ] **Step 5: Run explicit cleanup against the local database**

First back up `backend/security_depot.db`, print counts, then run:

`backend\.venv\Scripts\python.exe backend\scripts\clear_demo_data.py --confirm-delete-operational-data`

Verify Site IDs/count are unchanged and every other operational count is zero.

- [ ] **Step 6: Perform real-account manual validation with user-provided credentials**

The manager creates the Google Cloud client and local environment file. Connect the intended account, sync selected real emails, add a test technician, dispatch one event, open its localhost report link, submit completion, restart FastAPI, confirm persistence, then disconnect and confirm sync stops.

- [ ] **Step 7: Commit**

Commit: `git commit -am "test: verify localhost Google integration"`
