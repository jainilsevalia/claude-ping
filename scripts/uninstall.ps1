$ErrorActionPreference = "Stop"

# Self-elevate if not running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    exit
}

Write-Host ""
Write-Host "claude-ping uninstaller (Windows)" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Remove scheduled task
$task = Get-ScheduledTask -TaskName "ClaudePing" -ErrorAction SilentlyContinue
if ($task) {
    Unregister-ScheduledTask -TaskName "ClaudePing" -Confirm:$false
    Write-Host "[OK] Removed scheduled task 'ClaudePing'" -ForegroundColor Green
} else {
    Write-Host "[--] No scheduled task 'ClaudePing' found" -ForegroundColor Gray
}

# Remove install directory
$installDir = Join-Path $env:USERPROFILE ".claude-ping"
if (Test-Path $installDir) {
    Remove-Item -Path $installDir -Recurse -Force
    Write-Host "[OK] Removed $installDir" -ForegroundColor Green
} else {
    Write-Host "[--] No install directory found" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Uninstall complete." -ForegroundColor Green
