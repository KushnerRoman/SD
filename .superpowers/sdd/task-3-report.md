# Task 3 report

## Result

Implemented a read-only Gmail HTTP provider, recursive MIME normalization, initial 90-day and incremental history synchronization, idempotent provider-ID persistence, safe typed errors, and sync/status API routes. No live Google request or mailbox was used.

## TDD evidence

- RED: `backend\.venv\Scripts\pytest.exe backend\tests\test_gmail_sync.py -q`
  - collection failed with `ModuleNotFoundError: app.google.gmail`, as expected before implementation.
- RED (routes): same command
  - collection failed because `get_google_sync_coordinator` did not exist, as expected.
- GREEN: `backend\.venv\Scripts\pytest.exe backend\tests\test_gmail_sync.py -q`
  - `9 passed`.
- Regression: `backend\.venv\Scripts\pytest.exe backend\tests -q`
  - `44 passed`.

All Gmail HTTP behavior in tests uses `httpx.MockTransport`; attachment bodies are never requested.

## Commits

- See final task response (commit created after this report).

## Self-review

- Provider always requests Gmail message `format=full` and uses only bearer authorization over the existing OAuth refresh path.
- Initial sync query is exactly `newer_than:90d`; list and history pagination are exhausted before cursor commit.
- Provider IDs have a database uniqueness constraint and coordinator-side upsert/deduplication.
- MIME traversal prefers plain text, falls back to stripped HTML, decodes encoded headers, and records attachment name/size only.
- History deletions remove local messages. Sync failures roll back message/cursor mutations and store only the safe exception class name.
- Existing Sites routes and models were not removed or behaviorally changed; the complete backend suite passes.

## Concerns

- SQLAlchemy `create_all` does not migrate a pre-existing SQLite database. Existing installations need a migration/rebuild to add the new email/credential columns; clean databases and all automated tests are correct.
- The repository already emits datetime/FastAPI deprecation warnings; this task does not introduce a functional failure from them.

## Review remediation

- RED: `backend\.venv\Scripts\pytest.exe backend\tests\test_gmail_sync.py -q` failed at collection because `upgrade_sqlite_schema` did not exist.
- Added chronological history operations across pages, final-state reduction (add/delete and delete/re-add), no fetch for final deletions, and safe fetch-time 404 handling.
- Added mailbox profile checkpointing so an empty initial import transitions to incremental history.
- Added additive SQLite startup migration for Gmail columns and unique provider index; a legacy-schema fixture verifies Site rows survive.
- Added Content-Type charset decoding with safe UTF-8 fallback and an ISO-8859-1 fixture.
- Added mocked tests for history pagination/types/order, deleted/raced messages, rollback/checkpoint integrity, empty mailbox profile, OAuth refresh-to-provider integration, and old-schema migration.
- GREEN focused: `backend\.venv\Scripts\pytest.exe backend\tests\test_gmail_sync.py -q` -> `17 passed`.
- GREEN full: `backend\.venv\Scripts\pytest.exe backend\tests -q` -> `52 passed`.
- `git diff --check` -> exit 0 (line-ending advisory only).

Review concern resolved: existing SQLite installations are now upgraded additively at startup without dropping or rebuilding operational tables. Remaining output consists of pre-existing datetime/FastAPI/httpx deprecation warnings.

## Initial-sync race remediation

- RED: `backend\.venv\Scripts\pytest.exe backend\tests\test_gmail_sync.py::test_initial_checkpoint_precedes_listing_and_replays_arrival_during_import -q` -> failed because calls began `list, profile` instead of `profile, list`.
- The initial path now captures the mailbox profile history ID before `messages.list` or any message fetch, keeps that exact pre-list checkpoint throughout the import, and persists it only with the successful import commit.
- A deterministic fixture injects a message after checkpoint capture and proves the immediately following incremental history sync imports it.
- GREEN focused: `backend\.venv\Scripts\pytest.exe backend\tests\test_gmail_sync.py -q` -> `18 passed`.
- GREEN full: `backend\.venv\Scripts\pytest.exe backend\tests -q` -> `53 passed`.
- `git diff --check` -> exit 0 (line-ending advisory only).
