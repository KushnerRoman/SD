$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$backend = Join-Path $root "backend"
$app = Join-Path $root "app\security_depot_fsm"

Push-Location $app
flutter build web --base-href /web/
Pop-Location

Push-Location $backend
uv run python scripts\init_db.py
Pop-Location

$connections = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
foreach ($connection in $connections) {
  Stop-Process -Id $connection.OwningProcess -Force -ErrorAction SilentlyContinue
}

Start-Process `
  -FilePath "uv" `
  -ArgumentList @("run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000") `
  -WorkingDirectory $backend `
  -WindowStyle Hidden `
  -RedirectStandardOutput "C:\tmp\sd_api.log" `
  -RedirectStandardError "C:\tmp\sd_api.err.log"

Start-Sleep -Seconds 4

$health = Invoke-RestMethod -Uri "http://127.0.0.1:8000/health"
if ($health.status -ne "ok") {
  throw "API health check failed"
}

try {
  tailscale serve --bg 8000
  tailscale serve status
} catch {
  Write-Host "Tailscale Serve was not enabled. Check that Tailscale is logged in and connected, then run:"
  Write-Host "tailscale serve --bg 8000"
}

Write-Host "Local web app: http://127.0.0.1:8000/web/"
