# Task 6 Report: Background Synchronizer and Google Connection

## Result

- Added a single FastAPI lifespan-owned scheduler that runs immediately and every 90 seconds, skips overlapping runs, survives provider errors, and cancels cleanly.
- Lifespan creates the schema only; it does not load demo seeds.
- Disconnected installations safely no-op. Connected runs refresh once, coordinate Gmail first, then deliver the Calendar outbox.
- Added Flutter Google connection/sync models and repository API calls.
- Replaced Settings with a Google Connection screen supporting current-window OAuth, callback polling, reconnect, manual sync, sync timestamps, safe errors, and confirmed disconnect.
- Preserved Sites and added an explicit empty operational dashboard state.

## TDD evidence

Red:

`backend\.venv\Scripts\pytest.exe backend\tests\test_scheduler.py -q`

Failed during collection with `ModuleNotFoundError: No module named 'app.google.scheduler'`, confirming the new scheduler contract was absent.

Green:

- Backend focused + adjacent Google suites: 44 passed.
- Flutter Google connection + existing API repository suites: 8 passed.

## Self-review

- Scheduler task ownership is singular and idempotent.
- Lock uses non-blocking pre-check and cannot leave a held lock after exceptions.
- Cancellation is re-raised and awaited.
- Provider credentials/tokens never enter Flutter responses or UI.
- HTTP failures surface a stable user-facing message.
- OAuth navigation uses `_self` for the current web browser and bounded polling.
- No demo seed call was introduced in lifespan.

## Concerns

- Existing backend tests emit pre-existing `datetime.utcnow()` and TestClient deprecation warnings.

## Review remediation (2026-07-12)

- Manual Sync Now now executes the same Gmail-then-Calendar composite operation as the scheduler and reports both Gmail counts and Calendar deliveries.
- Settings loads connection and prior sync status together on every construction/reload; prior timestamps and safe error codes are visible before a manual sync.
- Current-window OAuth does not poll on the instance `_self` destroys. The callback marker reload creates a fresh Settings instance, performs the complete initial fetch, then uses a bounded, dispose-cancelled two-second poll until connected, error, or timeout.
- Connect, sync, and disconnect failures are converted to stable UI messages with mounted checks around asynchronous refreshes.
- Scheduler ownership now uses an atomic event-loop claim flag, survives exceptions, skips overlap, starts idempotently, and waits for in-flight async/threaded work before lifespan exit.
- Added red/green coverage for composite sync, one-task lifespan ownership, fake 90-second cadence, exception survival, overlap skip, in-flight async and threaded shutdown, initial status display, combined result display, reload navigation, and safe connect errors.

Review verification: full backend suite 77 tests (after updating the intentional response contract), full Flutter suite 37 tests, and Flutter analyze.

## Final compliance remediation (2026-07-12)

- Added literal callback polling in the new post-redirect Flutter instance. Normal entry still performs one refresh; `google=connected` triggers at most 30 timer-driven retries, and disposal cancels the timer before any further repository refresh.
- Replaced callable sleep-stub cadence verification with an injected asyncio-compatible clock. The fake clock advances 89 seconds without a run, then one additional second to prove the 90-second boundary deterministically.
