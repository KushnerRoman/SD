# Google OAuth, Gmail, and Calendar Localhost Integration Design

## Purpose

Replace the simulated Google services and all non-site demo data with a real manager-owned personal Google account integration. The first production-like version runs only on the manager's Windows computer at localhost and uses selected real Gmail messages and real Calendar invitations for validation.

## Validated Decisions

- Preserve every existing Site record.
- Permanently remove all demo emails, service calls, visits, technicians, activities, notifications, simulated calendar records, and reset-demo behavior.
- Use one manager-owned personal Google account.
- The manager owns a dedicated Security Depot service calendar and invites technicians as event guests.
- Technicians submit structured reports through signed report links inside events; they do not receive permission to edit the shared calendar.
- During this localhost phase, the manager opens technician report links on the manager's computer to simulate field completion.
- Synchronize automatically every 90 seconds and expose Sync Now.
- No public webhook, tunnel, public hosting, or phone-accessible report link is included in this phase.

## Google Cloud Configuration

The application uses a Google Cloud project with Gmail API and Google Calendar API enabled. The OAuth audience is External because the account is a standard personal Google account.

The local web OAuth client uses:

- authorized origin: `http://127.0.0.1:8765`;
- redirect URI: `http://127.0.0.1:8765/auth/google/callback`.

Development begins with the manager's Gmail address as the only authorized/test account. If Google Testing mode causes refresh-token expiry after seven days, the personal-use project is moved to an appropriate production publishing state while remaining limited to the manager's account. An unverified-app warning may remain for personal-use access. Google API user-data policies still apply.

## OAuth and Secret Storage

FastAPI owns the OAuth authorization-code flow and requests offline access. OAuth state and PKCE protect the redirect exchange.

Configuration is provided through local environment variables:

- `GOOGLE_CLIENT_ID`;
- `GOOGLE_CLIENT_SECRET`;
- `GOOGLE_REDIRECT_URI`;
- `TOKEN_ENCRYPTION_KEY`.

The repository includes an example environment file with names and instructions but no credentials. The real environment file and SQLite token data are ignored by Git.

The refresh token is encrypted at rest using authenticated encryption. `TOKEN_ENCRYPTION_KEY` must be a valid 32-byte Fernet key and remain stable across restarts. A domain-separated report-link signing key is derived from it with HMAC-SHA256; there is no source-code fallback secret. Missing or invalid key material fails closed before report-token issuance. Access tokens remain in memory and are refreshed as required. Disconnect Google revokes the token when possible and removes the local encrypted credential record.

## Requested Permissions

The application requests identity/email, Gmail read-only access, and the narrowest Calendar permissions that support creating or selecting the application-managed service calendar and creating/updating its events and attendees.

The integration does not send, modify, label, archive, trash, or delete Gmail messages. Gmail data is used only to display the mixed inbox and create manager-selected service calls.

## Data Preservation and Cleanup

A one-time cleanup migration runs explicitly through an administrative command before connecting Google. It deletes data in foreign-key-safe order:

1. notifications;
2. activity entries;
3. calendar details and synchronization outbox records;
4. visits;
5. jobs/service calls;
6. imported email messages;
7. technicians;
8. Google connection and synchronization state.

The migration does not delete or modify Sites. It reports before/after counts and requires explicit command confirmation. Automatic demo seeding on startup and the Reset Demo Data endpoint/UI are removed.

After cleanup, first startup shows the preserved Sites and empty operational screens until Google is connected and technicians are added.

## Components

### Google Connection

Settings becomes Google Connection and displays disconnected, connecting, connected, expired/revoked, and error states. It exposes Connect Google, Reconnect, Disconnect, Sync Now, account email, selected service calendar, last successful sync, next scheduled sync, and the latest error.

### Google OAuth Service

This backend unit creates authorization URLs, validates state, exchanges authorization codes, encrypts/decrypts refresh tokens, refreshes access tokens, and revokes authorization.

### Gmail Provider

This provider lists and retrieves real messages, converts MIME payloads into normalized plain-text bodies, extracts attachment metadata without downloading attachment contents, and uses Gmail history IDs for incremental synchronization.

The initial sync imports messages from the previous 90 days. The mixed inbox keeps ordinary messages and service requests together. The manager manually chooses which message becomes a service call.

### Calendar Provider

The manager either selects an existing dedicated service calendar or creates one through the application. Dispatch creates a Calendar event with a stable application-generated event identifier, site address in `location`, problem/instructions in the description, the assigned technician as an attendee, and `sendUpdates=all`.

The provider stores Google event IDs, etags, and synchronization timestamps. Updating assignment or schedule updates the same event rather than creating another one.

### Synchronization Coordinator

One coordinator runs on startup and every 90 seconds while FastAPI is active. Sync Now calls the same idempotent operation. A process-level lock prevents overlapping local runs.

The coordinator:

1. validates the connection and refreshes access;
2. performs initial or incremental Gmail sync;
3. fetches changed application-managed Calendar events;
4. processes pending event-create/update outbox work;
5. records counts, last success, next run, and errors.

Push notifications are deferred because localhost cannot receive Google's public HTTPS callbacks.

### Calendar Outbox

Dispatch commits the service call, visit, report token, and a pending Calendar operation locally. The synchronizer processes the operation and stores the resulting event identity. Retriable failures remain pending with attempt count and error. Idempotency keys prevent duplicate Google events after ambiguous network failures.

### Technician Report Links

Each visit owns a random nonce and a stable opaque 256-bit report token derived from that nonce, visit ID, and the domain-separated signing key. Only the nonce and SHA-256 token digest are stored; database fields and repository source are insufficient to reconstruct the bearer token. The event contains a URL such as `http://127.0.0.1:8765/report/<token>`.

The report page exposes only the assigned visit's relevant site, schedule, contact, instructions, and structured result form. It captures Completed, Incomplete, or Return Required; duration; work performed; materials; and follow-up notes. Incomplete and Return Required require follow-up text.

Tokens become unusable after the visit is closed or manually revoked. Localhost links are intentionally usable only from the manager's computer in this phase.

## Workflow

1. The manager opens Google Connection and selects Connect Google.
2. Google displays consent for the manager's account and redirects to localhost.
3. The app stores the encrypted refresh token and performs a 90-day Gmail sync.
4. The manager reviews the mixed real inbox and chooses a message.
5. The dispatch form uses an existing Site and a manager-created real technician Gmail address.
6. Saving creates the local service call and queues Calendar creation.
7. The coordinator creates the event and invites the technician.
8. For localhost testing, the manager opens the report link from the event on the same computer.
9. Submitting the report updates the visit, service-call history, notification, and Calendar event status text.

## Validation and Error Handling

- The OAuth callback rejects missing, expired, or mismatched state and PKCE values.
- Missing configuration produces a setup checklist without exposing secret values.
- Gmail and Calendar 401 responses mark authorization as needing reconnection after one refresh attempt.
- 403 quota/permission errors are surfaced with the affected API and operation.
- 429 and retriable 5xx errors use bounded exponential backoff and remain visible in sync status.
- Message IDs, history IDs, Calendar event IDs, and outbox idempotency keys are unique.
- Invalid or expired report tokens return a neutral error without revealing whether a customer/job exists.
- Existing local records remain usable during Google outages.
- Failed synchronization never falls back to simulated data.

## Testing

Automated backend tests use mocked Google token, Gmail, and Calendar HTTP responses. They cover:

- OAuth state, PKCE, callback, encrypted token storage, refresh, revoke, and reconnect;
- Gmail MIME parsing, 90-day initial sync, history sync, duplicate messages, deleted-message handling, and pagination;
- Calendar selection/creation, stable event creation, attendee invitations, updates, etags, outbox retry, and idempotency;
- report-token generation, hashing, expiry/closure, validation, completion, and Calendar update enqueueing;
- cleanup migration preserving Sites while deleting every other operational record;
- disconnected, revoked, quota, network, and partial-sync behavior.

Flutter tests cover Google Connection states, Sync Now, empty post-cleanup screens, real inbox display, dispatch, Calendar status, and report-page validation.

Manual validation uses the manager's real account:

1. connect OAuth;
2. confirm only the intended account/scopes;
3. import selected real emails;
4. add a technician Gmail address;
5. dispatch an event and verify its invitation/calendar content;
6. open the localhost report link;
7. submit completion;
8. confirm matching local and Calendar state;
9. restart FastAPI and confirm credentials/data persist;
10. disconnect and confirm syncing stops.

## Research Basis

- Gmail server-side OAuth supports offline access and refresh-token storage: https://developers.google.com/workspace/gmail/api/auth/web-server
- Gmail scopes must be minimized and may require verification depending on sensitivity and publishing: https://developers.google.com/workspace/gmail/api/auth/scopes
- External Testing projects are limited to listed test users and test authorizations can expire after seven days: https://support.google.com/cloud/answer/15549945
- Personal-use applications with fewer than 100 users can qualify for verification exceptions while still following user-data policy: https://support.google.com/cloud/answer/13464323
- Calendar event creation can invite attendees and send updates: https://developers.google.com/workspace/calendar/api/guides/create-events
- Calendar push notifications require a public HTTPS webhook and are therefore deferred: https://developers.google.com/workspace/calendar/api/guides/push

## Out of Scope

- public hosting, HTTPS webhook callbacks, Gmail push notifications, or Calendar watch channels;
- technicians opening report links from phones or remote computers;
- technician Google OAuth or permission to modify the shared calendar;
- Gmail write actions;
- automatic AI classification or automatic conversion of emails;
- downloading or storing Gmail attachment bodies;
- more than one connected manager account.

## Acceptance Criteria

The phase is accepted when Sites remain intact; all other demo data and reset behavior are gone; the manager can connect a personal Google account through localhost OAuth; real mixed Gmail messages synchronize without duplicates; a selected message becomes a service call; dispatch creates one invited Calendar event; the localhost report link submits a structured result; the app, history, notification, and Calendar event update consistently; synchronization survives restart; and disconnect stops access.
