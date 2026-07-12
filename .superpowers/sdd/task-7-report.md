# Task 7 report

## Status

Implemented real-data UX, Calendar delivery/report controls, Gmail technician validation, exact localhost Google setup documentation, and end-to-end automated verification.

## Changes

- Renamed the user-facing Calendar feature and its source class/path; removed user-facing placeholder-mode language.
- Inbox now describes imported Gmail and provides a disconnected/empty path to Settings and Sync Now.
- Technician create/update rejects blank, malformed, and non-Gmail invitation addresses without saving.
- Visits expose `local`, `pending`, `synced`, or `failed` Calendar delivery state plus an optional signed localhost report URL. Calendar renders Local/Queued/Synced/Failed badges and copy/open actions when a URL is available.
- Removed the unused `CalendarNetworkError` import.
- Added exact Google Cloud External OAuth, API, scope, redirect, environment, Fernet-key, guarded cleanup, startup, consent, real-email validation, persistence, rotation, and disconnect instructions without real credentials or addresses.

## TDD evidence

The focused widget suite was first run with new assertions and failed on the old Calendar label, missing empty-inbox guidance, and missing Gmail validation. Minimal UI changes made those cases green. A Calendar repository fixture then verifies a Synced badge and report copy/open actions.

## Fresh verification

- `backend\.venv\Scripts\pytest.exe backend\tests -q` — PASS, 78 tests; 375 existing deprecation warnings.
- `flutter analyze` — PASS, no issues.
- `flutter test` — PASS, 41 tests.
- `flutter build web --base-href /web/` — PASS, built `build\web`.
- `git diff --check` — PASS after removing the extra trailing blank line.

## External/operator prerequisites not performed

- No command touched `backend/security_depot.db`. The destructive cleanup is documented with mandatory stop, path inspection, backup, before/after counts, explicit confirmation flag, and Site invariant checks. The root/operator must perform it only after backup and confirmation.
- No live OAuth, Gmail, Calendar invitation, report submission, restart-persistence, or disconnect validation was attempted. The exact procedure is documented, but requires user-provided Google Cloud credentials and the intended test accounts.

## Self-review and concerns

- Dispatch/outbox enqueue owns signed report-token creation. `GET /visits` only reconstructs an existing active token when `TOKEN_ENCRYPTION_KEY` is valid and otherwise returns no report URL; it never creates or mutates token state.
- Localhost report links work only on the FastAPI host, not a technician phone or remote computer; documentation makes this limitation explicit.
- Backend tests retain pre-existing `datetime.utcnow()` and TestClient dependency warnings; no failures result.
- Changing `TOKEN_ENCRYPTION_KEY` invalidates encrypted Google credentials and report links by design; the rotation sequence explicitly requires disconnect/reconnect.

## Review follow-up

Addressed all Task 7 review findings with focused red-green tests:

- Backend now normalizes raw outbox `delivered` to `synced` and `reconnect` to `failed`, while preserving `pending` and `failed`; Flutter defensively performs the same normalization and repository tests use the real raw strings.
- Added executable, read-only `backend/scripts/print_counts.py`, backed by an isolated-database test. Its JSON contains sorted Site IDs, Site count, and every operational count. Documentation captures before/after JSON and provides exact `Compare-Object` and count-inspection commands.
- Calendar copy/open behavior is injected and widget-tested by tapping both controls and asserting the exact signed report URI passed to each callback.
- Dispatch/enqueue now issues the report token. `GET /visits` only reconstructs an existing active token and performs no commit or mutation. Regression coverage compares the full token record across repeated GETs and verifies a dispatched token resolves, closes, and is then rejected.

Fresh follow-up verification after the lifecycle assertion:

- `backend\.venv\Scripts\pytest.exe backend\tests\test_operations_api.py backend\tests\test_cleanup.py -q` — PASS, 7 tests (36 warnings).
- `backend\.venv\Scripts\pytest.exe backend\tests -q` — PASS, 80 tests (404 existing deprecation warnings).
- `flutter analyze` — PASS, no issues.
- `flutter test` — PASS, 43 tests.
- `flutter build web --base-href /web/` — PASS, built `build\web`.

## Final cleanup-count follow-up

- Expanded cleanup counts and `print_counts.py` JSON to cover every deleted operational table: jobs, visits, emails, technicians, activities, notifications, Calendar details, report tokens, Calendar outbox, Calendar settings, Google credentials, and Google sync state.
- Cleanup now explicitly removes Google credential and sync-state rows as operational integration state while preserving Sites.
- The isolated cleanup test populates every operational table, proves all before-counts are nonzero, runs cleanup, proves every after-count is zero, and verifies sorted Site IDs are unchanged.
- Documentation now includes an executable PowerShell assertion that fails if Site count changes or any non-Site count remains.
- Final focused command `backend\.venv\Scripts\pytest.exe backend\tests\test_cleanup.py -q` — PASS, 6 tests (24 warnings).
- Final full command `backend\.venv\Scripts\pytest.exe backend\tests -q` — PASS, 80 tests (413 existing deprecation warnings).
- Flutter was not rerun for this final follow-up because no Flutter source or tests changed after the prior clean 43-test/analyze/build verification.

## Whole-branch integration review

- Removed `/admin/load-seed`, seed-loader imports from the API, and operational loading from `scripts/init_db.py`; startup and the legacy script are schema-only.
- Manual and scheduled composite synchronization share one nonblocking process lock, so a manual request returns a safe conflict instead of overlapping an automatic run.
- Replaced broad Calendar event scope with least-privilege `calendar.app.created` plus readonly calendar-list access; documentation and OAuth tests assert the exact scope set.
- Reconnect outbox rows retry after authorization returns using the same stable event ID, preventing duplicates.
- Composite status records safe operation codes (`calendar.authorization`, `calendar.quota`, `calendar.sync`, or `calendar.delivery`) and no longer reports success when Calendar delivery fails.
- Gmail and Calendar inspect structured 403 reasons to distinguish retryable quota/rate limits from authorization/scope failures without exposing provider bodies.
- Completed reports accept empty follow-up notes; Incomplete and Return Required continue to require them.
- Composite synchronization now polls changed events for the app-created service calendar, persists initial/incremental sync tokens, handles pagination and expired cursors, and applies changes only to events whose stable app-managed ID matches a known visit.
- Removed an unused generic outbox exception binding.

Verification: focused integration suites 70 passed; full backend suite 88 passed (429 existing deprecation warnings). No Flutter files changed.

## Calendar ownership re-review

- Fresh integration state now always creates the service calendar through the current OAuth application; summary/name matching was removed, so an arbitrary manually or other-client-created owned calendar cannot be adopted.
- `GoogleCalendarSettings.calendar_id` remains the sole persisted restart identity.
- Added regressions for arbitrary same-name owner calendars, changed-event multi-page pagination/final cursor persistence, and HTTP 410 cursor invalidation followed by a full resync and replacement cursor.
- Focused `backend\.venv\Scripts\pytest.exe backend\tests\test_calendar_sync.py -q` — PASS, 15 tests (86 warnings).
- Full `backend\.venv\Scripts\pytest.exe backend\tests -q` — PASS, 91 tests (442 existing deprecation warnings).
