# Google localhost setup

Use placeholder values below. Never commit a client secret, token key, account address, or `.env` file.

## 1. Configure Google Cloud

1. Create or select a Google Cloud project.
2. Enable **Gmail API** and **Google Calendar API**.
3. Configure the OAuth consent screen with **External** audience. While the app remains in Testing, add only the intended personal account as a test user. Google may show an unverified-app warning; this localhost configuration is for personal/testing use, not public production use.
4. Request exactly these scopes: `openid`, `email`, `https://www.googleapis.com/auth/gmail.readonly`, `https://www.googleapis.com/auth/calendar.app.created`, and `https://www.googleapis.com/auth/calendar.calendarlist.readonly`. The app-created scope permits creating and managing only calendars created by this application.
5. Create an OAuth 2.0 **Web application** client and add the exact authorized redirect URI `http://127.0.0.1:8765/auth/google/callback`. `localhost`, another port, and a trailing slash are different redirect URIs.

## 2. Set the local environment

In the PowerShell session that starts FastAPI, set all four required variables:

```powershell
$env:GOOGLE_CLIENT_ID='<client-id-from-google-cloud>'
$env:GOOGLE_CLIENT_SECRET='<client-secret-from-google-cloud>'
$env:GOOGLE_REDIRECT_URI='http://127.0.0.1:8765/auth/google/callback'
$env:TOKEN_ENCRYPTION_KEY='<generated-fernet-key>'
```

Generate the Fernet key once, store it in a local secret manager, and reuse it across restarts:

```powershell
backend\.venv\Scripts\python.exe -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

Rotating `GOOGLE_CLIENT_SECRET` requires updating the environment and restarting FastAPI. Rotating `TOKEN_ENCRYPTION_KEY` invalidates encrypted Google credentials and existing report links: disconnect first, retain a backup, set the new key, restart, and reconnect.

## 3. Guarded operational cleanup

Cleanup preserves Sites but permanently removes other operational records. Stop FastAPI first. Do not run these commands until the operator has inspected the database path, made a backup, printed counts, and explicitly confirmed deletion.

```powershell
Copy-Item backend\security_depot.db backend\security_depot.db.pre-google-backup
backend\.venv\Scripts\python.exe backend\scripts\print_counts.py | Tee-Object -FilePath backend\counts-before.json
backend\.venv\Scripts\python.exe backend\scripts\clear_demo_data.py --confirm-delete-operational-data
backend\.venv\Scripts\python.exe backend\scripts\print_counts.py | Tee-Object -FilePath backend\counts-after.json
$before = Get-Content -Raw backend\counts-before.json | ConvertFrom-Json
$after = Get-Content -Raw backend\counts-after.json | ConvertFrom-Json
Compare-Object $before.site_ids $after.site_ids
$after.counts | ConvertTo-Json
$nonSiteCounts = $after.counts.PSObject.Properties | Where-Object Name -ne 'sites'
if ($before.site_count -ne $after.site_count -or ($nonSiteCounts.Value | Where-Object { $_ -ne 0 })) { throw 'Cleanup count verification failed' }
```

`Compare-Object` must print no differences. The final command fails unless `site_count` matches and every non-Site table is zero, including Calendar details/outbox/settings, report tokens, Google credentials, and Google sync state. Restore the backup and investigate if any invariant fails.

## 4. Build and start

```powershell
cd app\security_depot_fsm
flutter build web --base-href /web/
cd ..\..\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8765
```

Open `http://127.0.0.1:8765/web/`. In Settings select **Connect Google**, choose only the intended test account, review the exact scopes, and approve consent. Select **Sync Now**. Before connection, Inbox correctly contains no imported mail.

## 5. Real-account validation

Send a harmless service-request email from a non-sensitive test address to the connected mailbox; never put a real address in source or screenshots. Sync and verify one imported message, create a technician using the intended Gmail invitation address, create a service call, and dispatch it. Calendar should progress from Local/Queued to Synced (or Failed with a retryable error). Open or copy the localhost technician report link from Calendar on this same computer, submit a completion, and verify the job, history, notification, and event update.

Restart FastAPI with the same environment variables and confirm the connection and records persist. Finally choose **Disconnect** in Settings, confirm, then verify later Sync attempts do not import mail or deliver Calendar work.

The localhost report URL is not reachable from a technician's phone or another computer. Calendar guests are invitation recipients, not editors of the manager-owned service calendar.
