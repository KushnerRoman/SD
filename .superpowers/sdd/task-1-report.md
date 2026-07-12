# Task 1 Report: Site-Preserving Cleanup and Empty Startup

## Status

DONE_WITH_CONCERNS

Implementation commit: `bfa5eb8df5d63ccb1940fe2faaf7327ee5b5074a`

## Files changed

- `backend/app/cleanup.py` — adds `cleanup_operational_data(session)` and before/after counts.
- `backend/scripts/clear_demo_data.py` — adds an exact-flag guarded cleanup CLI with JSON output.
- `backend/app/main.py` — startup now creates schema only; `/admin/reset-demo` is removed.
- `backend/app/seed_loader.py` — reuses the site-preserving operational cleanup and no longer deletes Sites.
- `backend/app/schemas.py` — adds `CleanupResult`.
- `backend/tests/test_cleanup.py` — covers Site preservation, operational deletion, and guarded CLI behavior using only isolated databases.
- `backend/tests/test_seed_loader.py` — replaces demo-reset expectations with empty-startup and removed-route assertions.
- `app/security_depot_fsm/lib/features/settings/settings_screen.dart` — replaces demo/reset controls with disconnected Google placeholders.

## TDD red evidence

The brief's command could not run verbatim because this linked worktree has no `backend/.venv`. PowerShell first rejected the relative executable path. I then used the existing repository backend virtual environment by absolute path:

```powershell
& 'C:\Users\kushn\OneDrive\Documents\SD\backend\.venv\Scripts\pytest.exe' backend\tests\test_cleanup.py backend\tests\test_seed_loader.py -q
```

Result: collection failed with the intended missing-feature error:

```text
ModuleNotFoundError: No module named 'app.cleanup'
1 error in 1.03s
```

No production implementation existed when this failure was observed.

## Green evidence

Focused suite after implementation:

```powershell
& 'C:\Users\kushn\OneDrive\Documents\SD\backend\.venv\Scripts\pytest.exe' backend\tests\test_cleanup.py backend\tests\test_seed_loader.py -q
```

Result: `5 passed, 4 warnings in 3.03s`.

Full backend suite:

```powershell
& 'C:\Users\kushn\OneDrive\Documents\SD\backend\.venv\Scripts\pytest.exe' backend\tests -q
```

Final result: `17 passed, 19 warnings in 4.81s`.

Flutter static analysis and full test suite:

```powershell
Push-Location app\security_depot_fsm
flutter analyze
flutter test
Pop-Location
```

Final result: `No issues found!` and `33 tests passed`.

Repository hygiene:

```powershell
git diff --check
```

Result: exit 0; Git emitted only line-ending conversion notices while staging.

## Cleanup behavior reviewed

Deletion order is notifications, activities, calendar details, visits, jobs, email messages, and technicians. Sites are not included in any delete statement. Counts cover sites, jobs, visits, emails, technicians, activities, and notifications before and after cleanup. The cleanup commits once after the ordered deletes.

The seed loader now invokes the same cleanup boundary and adds only missing seed Sites, so existing Site records and their values are retained. Startup no longer opens a session or loads seed data. The explicit `/admin/load-seed` endpoint remains available, while the reset-demo endpoint and Settings reset action are gone.

The CLI rejects every argument list except the single exact confirmation flag and does not initialize a session before validating it. Tests execute it only with temporary SQLite paths supplied through `DATABASE_URL`; the real `backend/security_depot.db` was never passed to or modified by the cleanup script.

## Self-review

- Confirmed Site IDs before and after cleanup are identical.
- Confirmed all modeled operational rows are removed.
- Confirmed the guard failure does not even create the temporary database file.
- Confirmed confirmed execution emits parseable JSON with expected after-counts.
- Confirmed startup creates tables in an isolated in-memory database but leaves Sites, jobs, emails, and technicians empty.
- Confirmed `/admin/reset-demo` is absent from registered routes.
- Confirmed the Settings screen has no reset action and represents Gmail/Calendar as not connected.
- Removed a now-unused `SessionLocal` import and resolved all analyzer infos introduced during the edit.

## Concerns

- The current model set has no outbox, Google connection, or sync-state tables. Therefore this task cannot yet issue deletes for those future tables; they must be added to the ordered cleanup when their models land.
- Backend verification reports existing dependency/framework deprecation warnings (`httpx`/Starlette compatibility, FastAPI `on_event`, and `datetime.utcnow`). They do not fail tests and were outside this task's scope.
- The linked worktree lacks its own `backend/.venv`, so verification used the sibling checkout's existing backend virtual environment.
