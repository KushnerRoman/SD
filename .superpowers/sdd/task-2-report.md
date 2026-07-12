# Task 2 Report: Secure Google OAuth Configuration and Encrypted Credentials

## Outcome

Implemented environment-only Google OAuth configuration, PKCE S256 and constant-time OAuth state validation, Fernet-authenticated refresh-token encryption, mocked token/refresh/revoke/userinfo HTTP interactions, persistent credential metadata, safe connection schemas, and the required FastAPI routes. No Sites code or data was modified.

## Files

- Added `backend/app/google/__init__.py`, `config.py`, and `oauth.py`.
- Added `backend/tests/test_google_oauth.py`.
- Added `backend/.env.example` with placeholders only.
- Updated `backend/app/models.py`, `schemas.py`, and `main.py`.
- Added `cryptography` to `backend/pyproject.toml` and regenerated `backend/uv.lock` with `uv add`.
- Updated `.gitignore` for real local environment files.

## TDD Evidence

### Initial RED

Command requested by the brief:

```powershell
backend\.venv\Scripts\pytest.exe backend\tests\test_google_oauth.py -q
```

Result: PowerShell could not resolve the relative executable because the worktree did not yet contain `backend/.venv`.

Shared environment retry:

```powershell
& '..\..\backend\.venv\Scripts\pytest.exe' backend\tests\test_google_oauth.py -q
```

Result: collection failed with `ModuleNotFoundError: No module named 'cryptography'`, establishing the missing encryption dependency.

After adding the required dependency:

```powershell
.\backend\.venv\Scripts\pytest.exe backend\tests\test_google_oauth.py -q
```

Result: collection failed with `ModuleNotFoundError: No module named 'app.google'`, the expected missing-feature failure.

### First GREEN

```powershell
.\backend\.venv\Scripts\pytest.exe backend\tests\test_google_oauth.py -q
```

Result: `10 passed, 26 warnings in 5.53s`.

### Self-review RED/GREEN

Self-review identified that a normal Google token response does not contain `account_email`. A new mocked-userinfo test was added before implementation.

RED command/result:

```powershell
.\backend\.venv\Scripts\pytest.exe backend\tests\test_google_oauth.py -q
```

Result: `2 failed, 9 passed`; failures were missing `GoogleOAuthService.account_email` and callback redirecting with `incomplete_response`.

GREEN command/result:

```powershell
.\backend\.venv\Scripts\pytest.exe backend\tests\test_google_oauth.py -q
```

Result: `11 passed, 26 warnings in 3.47s`.

## Security and Interface Review

- Required secrets are read only from environment variables; missing configuration names are reported without values.
- The redirect URI is constrained to exactly `http://127.0.0.1:8765/auth/google/callback`.
- Authorization uses random state, random verifier, PKCE S256, offline access, and consent only for first connection.
- State is time-limited, single-use, and matched with `hmac.compare_digest`.
- Refresh tokens use Fernet authenticated encryption at rest; tests verify plaintext is absent from the database value and decryption round-trips.
- Token, refresh, revoke, and userinfo calls use `httpx`; automated tests use only `httpx.MockTransport` and no network OAuth.
- API response schemas expose only status, account email, and expiry metadata. Tokens are neither returned nor logged.
- Callback errors use non-sensitive codes and never echo code, state, token, or provider response details.
- Disconnect attempts revocation and removes the local credential even if remote revocation fails.
- Configured scopes are identity/email, Gmail read-only, Calendar events, and Calendar list read-only.

## Verification

Pre-final full-suite command:

```powershell
.\backend\.venv\Scripts\pytest.exe backend\tests -q
```

Result before the userinfo refinement: `28 passed, 44 warnings in 8.59s`.

Final verification:

```powershell
.\backend\.venv\Scripts\pytest.exe backend\tests\test_google_oauth.py -q
.\backend\.venv\Scripts\pytest.exe backend\tests -q
git diff --check
```

Results: focused OAuth suite `11 passed, 26 warnings in 3.10s`; full backend suite `29 passed, 44 warnings in 8.96s`; `git diff --check` exited 0 with no whitespace errors (only Git's existing LF-to-CRLF notices).

## Self-review

- Confirmed no source or example file contains real credentials.
- Confirmed no access or refresh token field exists in `GoogleConnectionOut`.
- Confirmed routes do not modify Sites.
- Confirmed mocked HTTP covers code exchange, access refresh, identity lookup, and revocation.
- Confirmed encrypted records persist only refresh-token ciphertext and safe metadata.

## Concerns

- The repository already emits Starlette/FastAPI and naive-UTC deprecation warnings. They do not fail tests and are not introduced as functional failures by this task.
- OAuth pending state is process-local, appropriate for this specified single-process localhost phase; a multi-process/public deployment would require a shared short-lived state store.

## Review Remediation

Commit: `0bf298d fix: harden Google OAuth callback handling`.

### Root Causes and Fixes

- Repeat authorization assumed every successful token response included a refresh token. The callback now decrypts and retains the existing stored refresh token when Google omits a replacement; first connection still rejects a response without one.
- Required callback arguments caused FastAPI to return a provider-facing 422 before application normalization. `code`, `state`, and provider `error` are optional at the HTTP boundary and denial, missing parameters, invalid state, incomplete response, and exchange failure map to fixed non-sensitive redirect codes.
- Revocation sent the refresh token in the URL query. It now uses an `application/x-www-form-urlencoded` POST body.
- `hmac.compare_digest` on arbitrary non-ASCII strings raised `TypeError`. State now passes an ASCII/length/allowed-character guard and constant-time comparison operates on bytes; malformed input raises `OAuthStateError`.

### Review RED Evidence

Command:

```powershell
.\backend\.venv\Scripts\pytest.exe backend\tests\test_google_oauth.py -q
```

Result: `7 failed, 10 passed, 37 warnings in 6.72s`. The failures reproduced all review findings: query-based revoke, reconnect `incomplete_response`, three callback 422 cases, non-ASCII service `TypeError`, and non-ASCII callback exception.

### Review GREEN Evidence

Focused command:

```powershell
.\backend\.venv\Scripts\pytest.exe backend\tests\test_google_oauth.py -q
```

Result: `17 passed, 39 warnings in 6.19s`.

Full regression and diff commands:

```powershell
.\backend\.venv\Scripts\pytest.exe backend\tests -q
git diff --check
```

Results: `35 passed, 57 warnings in 10.00s`; `git diff --check` exited 0 with no whitespace errors (only repository LF-to-CRLF notices).

### Remediation Self-review

- Verified first connect without a refresh token remains a fixed `incomplete_response` redirect.
- Verified reconnect without a new refresh token preserves the decrypted original token while updating account email and expiry metadata.
- Verified provider descriptions and malformed callback values are never reflected in redirect URLs.
- Verified revoke requests have no token query and carry the token only in a form-encoded body.
- Verified non-ASCII input cannot reach `compare_digest` as text and is normalized to the safe invalid-state redirect.
- No access or refresh token was added to a response or log.
