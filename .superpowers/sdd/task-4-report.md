# Task 4 Report: Calendar Provider, Outbox, and Invitations

## Result

Implemented a mocked-HTTP Google Calendar provider, durable SQLite outbox, stable visit-derived Google event IDs, invitation delivery, optimistic concurrency reconciliation, ambiguous-timeout idempotency, and cleanup support. Dispatch now commits the local job/visit and a pending outbox row without requiring Google availability.

## Red / Green Evidence

### Initial RED

Command:

`backend\.venv\Scripts\pytest.exe backend\tests\test_calendar_sync.py backend\tests\test_workflows.py -q`

Result: collection failed as expected because `app.google.calendar` and `CalendarOutbox` did not exist.

### Retry-bound RED

Command:

`backend\.venv\Scripts\pytest.exe backend\tests\test_calendar_sync.py -q`

Result: `test_backoff_skips_not_due_work_and_stops_after_five_attempts` failed because a future-dated item was attempted. This established the due-time/max-attempt regression before implementation.

### Focused GREEN

Command:

`backend\.venv\Scripts\pytest.exe backend\tests\test_calendar_sync.py backend\tests\test_workflows.py -q`

Result: `9 passed` (warnings only).

### Full GREEN

Command:

`backend\.venv\Scripts\pytest.exe backend\tests -q`

Result before final retry-bound addition: `56 passed`. The final focused suite was rerun after the addition. Existing warnings are primarily project-wide `datetime.utcnow()` and FastAPI startup deprecations.

## Implementation Notes

- `CalendarProvider` implements calendar listing/creation, event insertion/update, event retrieval, and changed-event listing using injectable `httpx.Client`.
- Event IDs are deterministic Google-safe IDs derived from SHA-256 of the visit ID. Client-assigned IDs make retries idempotent.
- Event payload uses the exact site address, dispatch instructions, technician email attendee, `sendUpdates=all`, and `{{SIGNED_REPORT_URL}}` as the Task 5 integration placeholder.
- A 412 refreshes the remote event/etag and retries with `If-Match`.
- An ambiguous insert timeout retries with the identical event ID; a 409 resolves by retrieving that event, preventing duplicates.
- Outbox failures use capped exponential delay, skip work not yet due, stop after five attempts, store generic safe error text, and use a distinct `reconnect` state for authorization failures.
- `/google/calendar/deliver` uses the existing encrypted refresh-token flow to construct an authorized Calendar provider.
- SQLite additive migration adds visit etag/timestamp columns. New tables are created through metadata.
- Cleanup deletes calendar outbox/settings before visits and preserves Sites and the existing cleanup result shape.

## Self-review

- All network behavior in tests uses `httpx.MockTransport`; no live Google calls occur.
- Dispatch transaction ordering is local model + outbox flush, then one commit.
- Existing UI/API visit and cleanup contracts remain compatible.
- `git diff --check` passed (line-ending conversion notices only).

## Concerns

- The report URL is intentionally a placeholder contract until Task 5 supplies signing/rendering.
- Delivery is exposed as an explicit endpoint; production scheduling/worker orchestration is outside this task.
- Existing naive UTC datetime usage emits Python 3.12 deprecation warnings and should be migrated project-wide rather than piecemeal.

## Review Follow-up

The initial review identified three gaps. Each was reproduced with a failing test before correction:

- A shared/read-only calendar with the service-calendar summary was incorrectly reused. Selection now requires both the exact summary and `accessRole == "owner"`; otherwise a new owned calendar is created.
- An ambiguous insert timeout issued an immediate second POST. It now records an attempt and future `next_attempt_at`, returns, skips the row until due, and performs the stable-ID retry later. A later 409 retrieves the existing stable-ID event. The five-attempt terminal bound remains enforced.
- Calendar list/create accepted unclassified 4xx or malformed JSON, which could leak provider behavior as `KeyError`/decode errors. All non-special 4xx responses now raise a safe `CalendarError`, and response shape/JSON is validated without exposing provider payloads.

Review RED command: `backend\.venv\Scripts\pytest.exe backend\tests\test_calendar_sync.py -q`

Review RED result: 3 failed (`ambiguous timeout`, `shared same-name calendar`, and `safe bad-response classification`).

Review GREEN result: 6 passed in the Calendar suite.
