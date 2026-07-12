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

- Listing visits issues or reuses a signed report token only when `TOKEN_ENCRYPTION_KEY` is valid; with missing configuration the API safely returns no report URL. This makes Calendar actions configuration-dependent as intended.
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
