# Task 5 Report: Signed Localhost Technician Reports

## Status

Implemented signed technician report links, isolated server-rendered report pages, CSRF protection, atomic report completion, and Calendar update enqueueing.

## Implementation

- Added 256-bit URL-safe random report tokens with SHA-256-only persistence, expiry, closure, and revocation.
- Added neutral responses for invalid, expired, closed, and revoked links.
- Added escaped, responsive `GET /report/{token}` and `POST /report/{token}` pages without application/manager navigation.
- Bound POST CSRF validation to both the report-token record and an HttpOnly SameSite cookie.
- Reused `submit_technician_report` workflow validation and made its completion/history/notification/outbox mutations commit atomically with token closure.
- Replaced the Calendar placeholder with `http://127.0.0.1:8765/report/{random-token}`. Tokens are minted in-memory per delivery attempt and prior live tokens are revoked, so raw tokens are never stored.
- Extended operational cleanup to delete report tokens before visits while preserving Sites. Existing additive schema creation creates the new table for legacy SQLite databases.

## TDD Evidence

Red command:

`backend\.venv\Scripts\pytest.exe backend\tests\test_report_links.py -q`

Result: collection failed as expected because `ReportToken` and report modules did not exist.

Focused green command:

`backend\.venv\Scripts\pytest.exe backend\tests\test_report_links.py backend\tests\test_calendar_sync.py -q`

Result: `11 passed`.

Full regression command:

`backend\.venv\Scripts\pytest.exe backend\tests -q`

Result: `64 passed`.

Diff validation:

`git diff --check`

Result: exit 0, no whitespace errors.

## Self-review

- Confirmed Calendar URLs contain no customer, site, job, or visit identifiers.
- Confirmed only token digests are persisted and CSRF comparison uses constant-time comparison.
- Confirmed failure paths rollback workflow mutations, and token closure shares the successful transaction.
- Confirmed cleanup ordering respects foreign keys and does not delete Sites.

## Concerns

- The suite reports existing FastAPI/Starlette and naive-UTC deprecation warnings; there are no test failures.

## Review Fix: Stable Retry Links and Multi-tab CSRF

The original implementation minted and revoked a token on every Calendar delivery attempt, and replaced a single CSRF digest on every GET. Review correctly identified that retries invalidated delivered links and a second tab invalidated the first form.

- Added a random 256-bit per-report nonce and derive the stable opaque 256-bit token with HMAC-SHA256 over visit ID plus nonce.
- Persist only the nonce and SHA-256 token digest; the raw token remains absent from storage but can be re-derived for Calendar retries and updates.
- Reuse active tokens during delivery rather than revoking them. Closure/revocation remains an explicit lifecycle action.
- Added an additive SQLite migration for the nonce column.
- Replaced rotating stored CSRF state with a stable token-bound HMAC value, still requiring the matching HttpOnly SameSite cookie and hidden form value.
- Added regression coverage proving failed retry URL identity and continued validity, delivered-link validity after a later Calendar update, CSRF tamper rejection, and successful first-form submission after two GETs.

Review-fix red result:

`backend\.venv\Scripts\pytest.exe backend\tests\test_report_links.py backend\tests\test_calendar_sync.py -q`

Result before implementation: `4 failed, 9 passed`, specifically stable token, two-GET CSRF, retry URL identity, and post-update link validity.

Review-fix focused green result: `13 passed`.

Review-fix full regression result: `66 passed`.

Remaining concern: `REPORT_TOKEN_SIGNING_KEY` must remain stable across application restarts. The localhost development default is deterministic; deployments should set and retain an environment-specific value. Existing deprecation warnings remain unchanged in nature.
