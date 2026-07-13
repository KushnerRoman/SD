# Local Manager Login and Google Setup Wizard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a secure localhost manager login and first-run Google credential wizard so the manager can configure and enter the Operations Command Center without PowerShell secrets.

**Architecture:** FastAPI owns password verification, opaque browser sessions, protected local key storage, encrypted Google application configuration, and route authorization. Flutter asks a small setup-status API which of four entry screens to show, then uses the existing repository only after authentication. Existing Google providers receive settings from a configuration repository rather than reading normal runtime configuration directly from environment variables.

**Tech Stack:** Python 3.11+, FastAPI, SQLAlchemy, Argon2id via `argon2-cffi`, `cryptography` Fernet, Windows DPAPI via `ctypes`, SQLite, Flutter/Dart, Material 3, pytest, Flutter widget tests.

## Global Constraints

- Localhost origin is exactly `http://127.0.0.1:8765`.
- Google redirect URI is exactly `http://127.0.0.1:8765/auth/google/callback`.
- There is one manager account and no username field.
- Password minimum length is 12 characters; plaintext passwords are never stored or logged.
- Browser sessions expire after 12 hours or 30 minutes of inactivity and use an `HttpOnly`, `SameSite=Strict` session cookie.
- The master key is protected for the current Windows user with DPAPI; no production fallback key is stored in source.
- Google Client Secret, refresh token, authorization code, session token, and encryption key must never appear in API responses or logs.
- Sites and all existing operational data must remain unchanged.
- Public access is limited to health, setup bootstrap, login, OAuth callback completion, static web assets, and opaque technician report links.

---

## File Structure

- Create `backend/app/auth.py`: password hashing, opaque session issuance, expiry, and revocation.
- Create `backend/app/local_secrets.py`: DPAPI adapter and Fernet-backed secret encryption.
- Create `backend/app/setup.py`: first-run state and encrypted Google application configuration repository.
- Modify `backend/app/models.py`: add manager, session, and Google application configuration tables.
- Modify `backend/app/schemas.py`: setup/login/configuration request and response types.
- Modify `backend/app/main.py`: setup/auth endpoints, route protection, and dynamic Google service creation.
- Modify `backend/app/google/config.py`: construct validated settings from decrypted stored values.
- Modify `backend/app/report_tokens.py`: obtain signing material through the local secret store.
- Create `backend/tests/test_manager_auth.py`, `test_local_secrets.py`, and `test_setup_api.py`.
- Create `app/security_depot_fsm/lib/features/auth/auth_models.dart`: bootstrap state models.
- Create `app/security_depot_fsm/lib/features/auth/auth_api.dart`: unauthenticated setup/login calls.
- Create `app/security_depot_fsm/lib/features/auth/auth_gate.dart`: four-state application entry controller.
- Create `app/security_depot_fsm/lib/features/auth/create_password_screen.dart`, `login_screen.dart`, and `google_setup_screen.dart`.
- Modify `app/security_depot_fsm/lib/main.dart`: start at `AuthGate` and build `AppShell` only when authenticated/configured.
- Modify repository interfaces/settings screen for logout and credential replacement.
- Create Flutter unit/widget tests for bootstrap parsing and all entry states.

---

### Task 1: Persisted Manager Password and Opaque Sessions

**Files:**
- Modify: `backend/pyproject.toml`
- Modify: `backend/app/models.py`
- Create: `backend/app/auth.py`
- Test: `backend/tests/test_manager_auth.py`

**Interfaces:**
- Produces: `ManagerAuthService.initialize_password(session, password)`, `login(session, password, client_key) -> str`, `authenticate(session, raw_token) -> ManagerSession | None`, `logout(session, raw_token) -> None`.
- Produces models: `ManagerAccount(id, password_hash, created_at, updated_at)` and `ManagerSession(id, token_hash, created_at, last_seen_at, expires_at, revoked_at)`.

- [ ] **Step 1: Add failing password and session tests**

```python
def test_password_is_hashed_and_initialization_is_one_time(db_session):
    service = ManagerAuthService()
    service.initialize_password(db_session, "a-correct-horse-password")
    account = db_session.get(ManagerAccount, 1)
    assert account.password_hash != "a-correct-horse-password"
    with pytest.raises(SetupAlreadyComplete):
        service.initialize_password(db_session, "another-long-password")

def test_session_has_absolute_and_idle_expiry(db_session, clock):
    service = ManagerAuthService(now=clock.now)
    service.initialize_password(db_session, "a-correct-horse-password")
    token = service.login(db_session, "a-correct-horse-password", "127.0.0.1")
    assert service.authenticate(db_session, token) is not None
    clock.advance(minutes=31)
    assert service.authenticate(db_session, token) is None
```

- [ ] **Step 2: Run tests and confirm the missing-module failure**

Run: `cd backend; .\.venv\Scripts\python.exe -m pytest tests/test_manager_auth.py -q`

Expected: FAIL because `app.auth` and the manager models do not exist.

- [ ] **Step 3: Add Argon2id, models, and minimal service**

Add `argon2-cffi>=23.1.0` to dependencies. Implement password validation and SHA-256 token hashing:

```python
PASSWORD_MIN_LENGTH = 12
SESSION_ABSOLUTE_TTL = timedelta(hours=12)
SESSION_IDLE_TTL = timedelta(minutes=30)

def _token_hash(raw_token: str) -> str:
    return hashlib.sha256(raw_token.encode("ascii")).hexdigest()

def login(self, session: Session, password: str, client_key: str) -> str:
    account = session.get(ManagerAccount, 1)
    if account is None or not self.password_hasher.verify(account.password_hash, password):
        self._record_failure(client_key)
        raise InvalidCredentials("Invalid manager password")
    raw_token = secrets.token_urlsafe(48)
    now = self.now()
    session.add(ManagerSession(token_hash=_token_hash(raw_token), created_at=now,
        last_seen_at=now, expires_at=now + SESSION_ABSOLUTE_TTL))
    session.commit()
    return raw_token
```

`authenticate` rejects revoked, absolute-expired, and idle-expired rows, updates `last_seen_at`, and never stores the raw token. `logout` sets `revoked_at`.

- [ ] **Step 4: Verify focused tests pass**

Run: `cd backend; .\.venv\Scripts\python.exe -m pytest tests/test_manager_auth.py -q`

Expected: all tests PASS, including invalid password, minimum length, logout, idle expiry, absolute expiry, and raw-token absence.

- [ ] **Step 5: Commit the authentication unit**

```powershell
git add backend/pyproject.toml backend/uv.lock backend/app/models.py backend/app/auth.py backend/tests/test_manager_auth.py
git commit -m "feat: add local manager authentication"
```

### Task 2: Windows-Protected Local Secret Store

**Files:**
- Create: `backend/app/local_secrets.py`
- Create: `backend/tests/test_local_secrets.py`
- Modify: `.gitignore`

**Interfaces:**
- Produces protocol `KeyProtector.protect(bytes) -> bytes` and `unprotect(bytes) -> bytes`.
- Produces `WindowsDpapiProtector`, `LocalSecretStore.load_or_create_cipher() -> Fernet`, `encrypt(str) -> bytes`, and `decrypt(bytes) -> str`.

- [ ] **Step 1: Write failing store tests with an injected fake protector**

```python
class FakeProtector:
    def protect(self, value: bytes) -> bytes: return b"protected:" + value
    def unprotect(self, value: bytes) -> bytes: return value.removeprefix(b"protected:")

def test_master_key_persists_but_plaintext_does_not(tmp_path):
    store = LocalSecretStore(tmp_path / "master-key.dpapi", FakeProtector())
    encrypted = store.encrypt("google-client-secret")
    assert b"google-client-secret" not in encrypted
    assert LocalSecretStore(tmp_path / "master-key.dpapi", FakeProtector()).decrypt(encrypted) == "google-client-secret"
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd backend; .\.venv\Scripts\python.exe -m pytest tests/test_local_secrets.py -q`

Expected: FAIL because `LocalSecretStore` is undefined.

- [ ] **Step 3: Implement DPAPI and authenticated encryption**

Use `CryptProtectData`/`CryptUnprotectData` through `ctypes.windll.crypt32`, write the protected key with exclusive creation, and restrict normal configuration to Windows:

```python
class LocalSecretStore:
    def load_or_create_cipher(self) -> Fernet:
        if self.path.exists():
            key = self.protector.unprotect(self.path.read_bytes())
        else:
            key = Fernet.generate_key()
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self.path.write_bytes(self.protector.protect(key))
        return Fernet(key)
```

Store the key under `backend/.local/master-key.dpapi`; add `backend/.local/` to `.gitignore`. Convert DPAPI/cipher failures to `LocalSecretError` without including secret values.

- [ ] **Step 4: Run local-secret tests**

Run: `cd backend; .\.venv\Scripts\python.exe -m pytest tests/test_local_secrets.py -q`

Expected: PASS for create/reopen, ciphertext corruption, failed protector, and plaintext absence.

- [ ] **Step 5: Commit**

```powershell
git add .gitignore backend/app/local_secrets.py backend/tests/test_local_secrets.py
git commit -m "feat: protect local application secrets"
```

### Task 3: First-Run, Login, Logout, and Route Protection API

**Files:**
- Create: `backend/app/setup.py`
- Modify: `backend/app/models.py`
- Modify: `backend/app/schemas.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/test_setup_api.py`

**Interfaces:**
- Produces `GET /setup/status`, `POST /setup/password`, `POST /auth/login`, `POST /auth/logout`, `POST /setup/google`.
- Produces `GoogleAppConfiguration(id, encrypted_client_id, encrypted_client_secret, client_id_suffix, created_at, updated_at)`.
- Consumes `ManagerAuthService` and `LocalSecretStore` from Tasks 1-2.

- [ ] **Step 1: Write failing API-state and protection tests**

```python
def test_bootstrap_moves_through_four_states(client):
    assert client.get("/setup/status").json()["state"] == "create_password"
    response = client.post("/setup/password", json={"password": "a-correct-horse-password", "confirmation": "a-correct-horse-password"})
    assert response.status_code == 201
    assert client.get("/setup/status").json()["state"] == "login"
    login = client.post("/auth/login", json={"password": "a-correct-horse-password"})
    assert "manager_session=" in login.headers["set-cookie"]
    assert client.get("/setup/status").json()["state"] == "google_setup"

def test_manager_api_requires_session(client):
    assert client.get("/sites").status_code == 401
    assert client.get("/health").status_code == 200
    assert client.get("/report/not-a-token").status_code != 401
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd backend; .\.venv\Scripts\python.exe -m pytest tests/test_setup_api.py -q`

Expected: FAIL because setup routes do not exist and `/sites` is unprotected.

- [ ] **Step 3: Implement schemas, endpoints, cookie, and authorization middleware**

Return only non-secret bootstrap data:

```python
class SetupStatusOut(BaseModel):
    state: Literal["create_password", "login", "google_setup", "ready"]
    redirect_uri: str = "http://127.0.0.1:8765/auth/google/callback"
    client_id_hint: str | None = None
```

Set the session cookie with `httponly=True`, `samesite="strict"`, `secure=False`, `path="/"`, and no persistent `max_age`, making it a browser-session cookie. Add middleware that permits `/health`, `/setup/status`, `/setup/password`, `/auth/login`, `/auth/google/callback`, `/report/*`, and `/web/*`; all other API paths require a valid cookie. Ensure first-run password creation is permitted only while no manager exists.

- [ ] **Step 4: Verify setup API tests**

Run: `cd backend; .\.venv\Scripts\python.exe -m pytest tests/test_setup_api.py -q`

Expected: PASS for all four bootstrap states, cookie attributes, logout, duplicate setup rejection, neutral login error, protected CRUD, public report access, and data preservation.

- [ ] **Step 5: Commit**

```powershell
git add backend/app/setup.py backend/app/models.py backend/app/schemas.py backend/app/main.py backend/tests/test_setup_api.py
git commit -m "feat: add protected first-run setup API"
```

### Task 4: Supply Existing Google Services from Encrypted Configuration

**Files:**
- Modify: `backend/app/google/config.py`
- Modify: `backend/app/main.py`
- Modify: `backend/app/report_tokens.py`
- Modify: `backend/tests/test_google_oauth.py`
- Modify: `backend/tests/test_report_links.py`
- Modify: `backend/tests/test_setup_api.py`

**Interfaces:**
- Produces `GoogleConfigurationRepository.get_settings(session) -> GoogleSettings` and `replace(session, client_id, client_secret, password)`.
- Consumes encrypted `GoogleAppConfiguration` and local master cipher.

- [ ] **Step 1: Add failing stored-configuration tests**

```python
def test_oauth_start_uses_stored_google_configuration(authenticated_client, google_config):
    google_config.save("stored.apps.googleusercontent.com", "stored-secret")
    response = authenticated_client.get("/auth/google/start")
    assert response.status_code == 307
    assert "stored.apps.googleusercontent.com" in response.headers["location"]
    assert "stored-secret" not in response.headers["location"]

def test_replacing_credentials_requires_password_and_preserves_sites(authenticated_client, seeded_site):
    response = authenticated_client.put("/setup/google", json={"client_id": "new.apps.googleusercontent.com", "client_secret": "new-secret", "manager_password": "wrong-password"})
    assert response.status_code == 403
    assert authenticated_client.get(f"/sites/{seeded_site.id}").status_code == 200
```

- [ ] **Step 2: Run focused tests and confirm failure**

Run: `cd backend; .\.venv\Scripts\python.exe -m pytest tests/test_google_oauth.py tests/test_report_links.py tests/test_setup_api.py -q`

Expected: FAIL because OAuth still depends on environment variables.

- [ ] **Step 3: Refactor service creation and signing-key access**

Add `GoogleSettings.from_values(client_id, client_secret, redirect_uri, token_encryption_key)` and keep `from_env()` only behind `SECURITY_DEPOT_CONFIG_MODE=environment` for tests. Build `GoogleOAuthService` per request/sync run from decrypted configuration. Derive report signing material from the local master cipher using the existing domain-separated HMAC; do not return key bytes through an endpoint. Replacing credentials verifies the manager password, revokes/deletes the current Google credential, stores replacements atomically, and preserves all operational tables.

- [ ] **Step 4: Verify Google, report, and setup suites**

Run: `cd backend; .\.venv\Scripts\python.exe -m pytest tests/test_google_oauth.py tests/test_gmail_sync.py tests/test_calendar_sync.py tests/test_report_links.py tests/test_setup_api.py -q`

Expected: all selected tests PASS with stored configuration and explicit environment test mode.

- [ ] **Step 5: Commit**

```powershell
git add backend/app/google/config.py backend/app/main.py backend/app/report_tokens.py backend/tests/test_google_oauth.py backend/tests/test_report_links.py backend/tests/test_setup_api.py
git commit -m "feat: load Google OAuth from encrypted setup"
```

### Task 5: Flutter Bootstrap Client and Four-State Authentication Gate

**Files:**
- Create: `app/security_depot_fsm/lib/features/auth/auth_models.dart`
- Create: `app/security_depot_fsm/lib/features/auth/auth_api.dart`
- Create: `app/security_depot_fsm/lib/features/auth/auth_gate.dart`
- Create: `app/security_depot_fsm/lib/features/auth/create_password_screen.dart`
- Create: `app/security_depot_fsm/lib/features/auth/login_screen.dart`
- Create: `app/security_depot_fsm/lib/features/auth/google_setup_screen.dart`
- Modify: `app/security_depot_fsm/lib/main.dart`
- Create: `app/security_depot_fsm/test/auth_gate_test.dart`
- Create: `app/security_depot_fsm/test/auth_api_test.dart`

**Interfaces:**
- Produces `AuthApi.getStatus()`, `createPassword(password, confirmation)`, `login(password)`, `saveGoogleCredentials(clientId, clientSecret)`, and `logout()`.
- Produces enum `BootstrapState { createPassword, login, googleSetup, ready }`.

- [ ] **Step 1: Write failing parsing and widget-state tests**

```dart
testWidgets('shows manager login for login state', (tester) async {
  await tester.pumpWidget(MaterialApp(home: AuthGate(api: FakeAuthApi(BootstrapState.login), appBuilder: (_) => const Text('Command Center'))));
  await tester.pumpAndSettle();
  expect(find.text('Manager Login'), findsOneWidget);
  expect(find.text('Command Center'), findsNothing);
});

testWidgets('collects Google credentials without showing secret after save', (tester) async {
  final api = FakeAuthApi(BootstrapState.googleSetup);
  var completed = false;
  await tester.pumpWidget(MaterialApp(home: GoogleSetupScreen(
    api: api,
    redirectUri: 'http://127.0.0.1:8765/auth/google/callback',
    onComplete: () => completed = true,
  )));
  await tester.enterText(find.byKey(const Key('google-client-id')), 'test.apps.googleusercontent.com');
  await tester.enterText(find.byKey(const Key('google-client-secret')), 'test-secret');
  await tester.tap(find.text('Save Google Credentials'));
  await tester.pumpAndSettle();
  expect(api.savedClientId, 'test.apps.googleusercontent.com');
  expect(api.savedClientSecret, 'test-secret');
  expect(completed, isTrue);
  expect(find.text('test-secret'), findsNothing);
});
```

- [ ] **Step 2: Run tests and confirm missing-class failure**

Run: `cd app\security_depot_fsm; flutter test test/auth_gate_test.dart test/auth_api_test.dart`

Expected: FAIL because authentication UI and models do not exist.

- [ ] **Step 3: Implement bootstrap API and screens**

`AuthGate` fetches `/setup/status`, displays a progress indicator during loading, and switches exactly on `BootstrapState`. Password and Client Secret fields use `obscureText: true`. The Google screen displays the fixed redirect URI with copy action, validates `.apps.googleusercontent.com` as a helpful warning rather than a hard requirement, and disables its submit button while saving. On ready, construct the existing `ApiFieldServiceRepository` and `AppShell`.

- [ ] **Step 4: Verify Flutter auth tests**

Run: `cd app\security_depot_fsm; flutter test test/auth_gate_test.dart test/auth_api_test.dart`

Expected: PASS for four states, password mismatch, API errors, disabled duplicate submission, secret obscuring, and ready transition.

- [ ] **Step 5: Commit**

```powershell
git add app/security_depot_fsm/lib/features/auth app/security_depot_fsm/lib/main.dart app/security_depot_fsm/test/auth_gate_test.dart app/security_depot_fsm/test/auth_api_test.dart
git commit -m "feat: add manager setup and login screens"
```

### Task 6: Settings Logout and Credential Replacement

**Files:**
- Modify: `app/security_depot_fsm/lib/data/field_service_repository.dart`
- Modify: `app/security_depot_fsm/lib/data/api_field_service_repository.dart`
- Modify: `app/security_depot_fsm/lib/features/settings/settings_screen.dart`
- Modify: `app/security_depot_fsm/lib/main.dart`
- Modify: `app/security_depot_fsm/test/google_connection_test.dart`
- Create: `app/security_depot_fsm/test/settings_security_test.dart`

**Interfaces:**
- Adds repository methods `replaceGoogleCredentials(...)` and `logoutManager()`.
- `AppShell` consumes `VoidCallback onLoggedOut` and returns to `AuthGate` after successful logout.

- [ ] **Step 1: Write failing Settings interaction tests**

```dart
testWidgets('logout returns control to authentication gate', (tester) async {
  var loggedOut = false;
  await tester.pumpWidget(MaterialApp(home: SettingsScreen(repository: fakeRepository, onLoggedOut: () => loggedOut = true)));
  await tester.tap(find.text('Log Out'));
  await tester.pumpAndSettle();
  expect(loggedOut, isTrue);
});
```

Add a replacement test that verifies a password confirmation dialog, calls the API once, never renders the stored secret, and changes the connection state to disconnected.

- [ ] **Step 2: Run and confirm failure**

Run: `cd app\security_depot_fsm; flutter test test/settings_security_test.dart test/google_connection_test.dart`

Expected: FAIL because settings lacks security actions.

- [ ] **Step 3: Implement repository calls and Settings cards**

Add a Security card with redacted Client ID, Replace Google Credentials, and Log Out. Credential replacement requires current manager password plus new Client ID/Secret and uses `PUT /setup/google`. Logout uses `POST /auth/logout`, then invokes `onLoggedOut`. Preserve existing Google Connect, Sync Now, and Disconnect behavior.

- [ ] **Step 4: Run focused and complete Flutter tests**

Run: `cd app\security_depot_fsm; flutter test`

Expected: all Flutter tests PASS.

- [ ] **Step 5: Commit**

```powershell
git add app/security_depot_fsm/lib/data app/security_depot_fsm/lib/features/settings/settings_screen.dart app/security_depot_fsm/lib/main.dart app/security_depot_fsm/test
git commit -m "feat: add manager security settings"
```

### Task 7: Recovery Documentation and Full Verification

**Files:**
- Modify: `docs/google-localhost-setup.md`
- Create: `backend/scripts/reset_manager_access.py`
- Create: `backend/tests/test_reset_manager_access.py`

**Interfaces:**
- Produces guarded command `python backend/scripts/reset_manager_access.py --database <absolute-path> --confirm-reset-manager-access`.

- [ ] **Step 1: Write failing recovery preservation test**

```python
def test_reset_removes_only_auth_and_google_authorization(session, seeded_site, seeded_job):
    reset_manager_access(session)
    assert session.get(Site, seeded_site.id) is not None
    assert session.get(Job, seeded_job.id) is not None
    assert session.query(ManagerAccount).count() == 0
    assert session.query(ManagerSession).count() == 0
    assert session.query(GoogleCredential).count() == 0
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd backend; .\.venv\Scripts\python.exe -m pytest tests/test_reset_manager_access.py -q`

Expected: FAIL because the recovery function does not exist.

- [ ] **Step 3: Implement guarded recovery and update setup documentation**

The script requires an absolute database path, refuses to run without the exact confirmation flag, prints before/after counts, deletes only manager sessions/account, Google credential/sync/calendar authorization settings, and encrypted Google application configuration, and leaves Sites/jobs/visits/email/history untouched. Documentation replaces normal environment-variable setup with: start backend, open `/web/`, create password, copy redirect URI into Google Cloud, enter Client ID/Secret, and select Connect Google. Keep environment mode in a clearly labeled automated-test section.

- [ ] **Step 4: Run complete verification**

```powershell
cd backend
.\.venv\Scripts\python.exe -m pytest -q
cd ..\app\security_depot_fsm
flutter analyze
flutter test
flutter build web --base-href /web/
```

Expected: backend suite has zero failures; Flutter analyze reports no issues; Flutter tests have zero failures; production web build exits 0.

- [ ] **Step 5: Manually verify localhost flow without entering real secrets**

Start FastAPI, open `http://127.0.0.1:8765/web/`, confirm Create Manager Password on an isolated test database, create a test password, confirm Manager Login in a fresh browser session, confirm Google Setup displays the exact redirect URI, and confirm unauthenticated `/sites` returns 401. Do not submit a real Google Client Secret during automated/manual verification.

- [ ] **Step 6: Commit documentation and recovery**

```powershell
git add docs/google-localhost-setup.md backend/scripts/reset_manager_access.py backend/tests/test_reset_manager_access.py
git commit -m "docs: add manager setup and recovery workflow"
```

---

## Completion Checklist

- [ ] Re-read `docs/superpowers/specs/2026-07-12-local-manager-setup-design.md` and map every acceptance criterion to a passing automated or manual check.
- [ ] Run `git diff --check` and inspect `git status --short` without staging unrelated user files.
- [ ] Confirm no real password, Client Secret, token, Gmail address, DPAPI blob, `.env`, SQLite database, or `backend/.local/` file is tracked.
- [ ] Run the complete backend and Flutter verification commands again immediately before reporting completion.
