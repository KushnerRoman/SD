# Local Manager Login and Google Setup Wizard Design

## Purpose

Replace command-line secret configuration with a secure first-run experience for the manager's Windows computer. The manager opens the Operations Command Center in a browser, creates one local password, enters the Google OAuth application credentials, and connects the test Gmail account. Later browser sessions require only the local manager password.

## Validated Decisions

- The application remains available only at `http://127.0.0.1:8765` during this phase.
- There is one manager account and no username field.
- The manager signs in once per browser session.
- Google Client ID and Client Secret are entered through the application rather than PowerShell.
- The Google redirect URI is fixed and displayed as `http://127.0.0.1:8765/auth/google/callback`; it is not editable.
- Existing Sites and operational data remain unchanged.
- The existing Gmail, Calendar, synchronization, and technician-report workflows remain unchanged after configuration.

## First-Run Experience

When no manager password exists, every manager UI route displays a first-run setup screen. The screen asks for a new password and confirmation, explains that it protects access on this computer, and enforces a minimum length of 12 characters. The password is never displayed or logged after submission.

After password creation, the same setup flow asks for:

- Google OAuth Client ID;
- Google OAuth Client Secret.

It also shows the fixed authorized redirect URI with a copy action and concise Google Cloud instructions. Saving valid-looking credentials completes local configuration and opens the Google Connection page. The manager then selects Connect Google and completes Google's OAuth consent in the browser.

The setup flow reports missing or malformed fields without echoing the Client Secret. It does not attempt to validate the credentials by transmitting them anywhere except Google's OAuth endpoints when the manager selects Connect Google.

## Authentication and Sessions

The backend stores one password verifier using Argon2id with a unique random salt. It never stores the plaintext password or a reversible password value.

Successful login creates a random opaque session token. Only its hash is stored in SQLite. The browser receives the token in an `HttpOnly`, `SameSite=Strict` cookie scoped to the localhost application. The cookie is not marked `Secure` during HTTP localhost development because that would prevent the browser from sending it; production hosting must use HTTPS and a Secure cookie.

Sessions expire after 12 hours or 30 minutes of inactivity, whichever occurs first. Logout revokes the current session. Restarting FastAPI does not invalidate an otherwise valid session, but closing the browser session removes its session cookie. Password verification failures use a small per-client exponential delay and return the same neutral error.

All manager API endpoints require authentication except health checks, first-run status/setup, login, Google OAuth callback state completion, static web assets, and opaque technician report-link endpoints. OAuth start, disconnect, Gmail sync, operational CRUD, and configuration changes require an authenticated manager session.

## Local Secret Storage

The application generates a random 32-byte master encryption key on first setup. On Windows, that key is protected for the current Windows user with Data Protection API (DPAPI) and stored in a local application configuration file excluded from Git. Google Client Secret, refresh tokens, and report-link signing material are encrypted with authenticated encryption derived from that master key.

The SQLite database stores encrypted Google configuration values and a non-secret Client ID display suffix. API responses expose only whether configuration exists and a redacted Client ID. The Client Secret, encryption key, refresh token, authorization code, and session tokens are never returned to Flutter, written to logs, or included in errors.

If Windows-protected storage cannot be initialized, setup fails closed with a local recovery message. There is no source-code or environment fallback encryption key. The existing environment-variable mode is retained only for automated tests and explicitly enabled development runs; normal startup uses the local protected configuration.

## Settings and Recovery

Settings includes:

- Google configured/not configured status;
- redacted Client ID;
- connected Google account and synchronization status;
- Replace Google Credentials;
- Disconnect Google;
- Log Out.

Replacing credentials requires the manager password again, disconnects the current Google authorization, encrypts the replacement values, and requires a new OAuth connection. It does not delete Sites, emails, jobs, visits, technicians, or history.

There is no password-reset email because the app is local and has no external identity provider. A documented command-line recovery procedure can reset only manager authentication and Google authorization after an explicit database backup. It must not delete Sites or operational records.

## Backend Components

- `ManagerAuthService`: password initialization and verification, session creation, expiry, revocation, and rate limiting.
- `LocalSecretStore`: Windows DPAPI protection of the application master key and authenticated encryption of configuration secrets.
- `SetupService`: first-run state, one-time password creation, credential validation, and configuration replacement.
- Authentication dependency/middleware: protects manager API routes while preserving public report links and OAuth callback behavior.
- Configuration repository: supplies decrypted Google settings to the existing OAuth and synchronization services without exposing secrets to API callers.

These units have narrow interfaces so authentication, storage, and Google behavior can be tested independently.

## Flutter Screens

Flutter chooses its entry screen from `/setup/status`:

1. password not initialized: Create Manager Password;
2. password initialized but browser unauthenticated: Manager Login;
3. authenticated but Google credentials missing: Google Setup;
4. authenticated and configured: Operations Command Center.

The Google Setup screen uses password-type controls for the Client Secret, prevents accidental double submission, and includes exact Google Cloud field labels. Authentication expiry sends the manager to Login without deleting unsaved local form text until the manager chooses to discard it.

## Error Handling

- Setup creation is atomic; a partial failure leaves first-run state recoverable.
- Duplicate first-run submissions cannot replace an existing manager password.
- Invalid login, expired session, and revoked session return neutral authentication errors.
- Missing Google configuration disables Connect Google and shows the setup action.
- A corrupted or undecryptable local key blocks Google operations without deleting encrypted data.
- Sensitive request fields are excluded from structured request logging.
- Existing records remain readable after Google disconnection or configuration errors.

## Testing

Backend tests cover password hashing, first-run exclusivity, login success/failure, session expiry and inactivity, logout, route protection, cookie attributes, throttling, DPAPI-store abstraction, encryption round trips, corrupted ciphertext, redaction, credential replacement, OAuth callback exceptions, and preservation of operational data.

Flutter tests cover all four entry states, password validation, login errors, Google credential entry/redaction, logout, expired-session navigation, and the existing connected/disconnected Google states.

Manual localhost validation covers first launch, browser-session login, server restart persistence, logout, OAuth connection with the personal Gmail test account, mail synchronization, Calendar dispatch, replacement credentials, and recovery documentation.

## Out of Scope

- multiple managers, usernames, roles, password-reset email, or remote identity providers;
- access from another computer or technician phone;
- public hosting, HTTPS, production cookie policy, or cloud secret managers;
- automatic Google Cloud project or OAuth client creation;
- storing the manager password in the browser;
- changing or deleting existing Sites or operational records.

## Acceptance Criteria

On a fresh local configuration, the manager can open `/web/`, create a local password, enter Google OAuth credentials, and connect the personal Gmail test account without setting PowerShell environment variables. A later browser session requires the manager password, while server restarts preserve encrypted configuration and valid database state. Unauthenticated users cannot access manager data or manager actions. Secrets never appear in API responses or logs. Existing Sites and operational records remain intact.
