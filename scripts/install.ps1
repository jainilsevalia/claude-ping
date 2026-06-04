param(
    [int]$IntervalHours = 5
)

$ErrorActionPreference = "Stop"

# Self-elevate if not running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -IntervalHours $IntervalHours"
    exit
}

Write-Host ""
Write-Host "claude-ping installer (Windows)" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Check if claude CLI is available
$claudePath = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claudePath) {
    Write-Host "ERROR: 'claude' CLI not found in PATH." -ForegroundColor Red
    Write-Host "Install Claude Code first: https://docs.anthropic.com/en/docs/claude-code" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Found claude CLI at: $claudePath" -ForegroundColor Green

# Create install directory
$installDir = Join-Path $env:USERPROFILE ".claude-ping"
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# Copy ping script
$scriptSource = Join-Path $PSScriptRoot "claude-ping.ps1"
$scriptDest = Join-Path $installDir "claude-ping.ps1"
Copy-Item -Path $scriptSource -Destination $scriptDest -Force
Write-Host "[OK] Installed ping script to: $scriptDest" -ForegroundColor Green

# Remove existing task if present
$existingTask = Get-ScheduledTask -TaskName "ClaudePing" -ErrorAction SilentlyContinue
if ($existingTask) {
    Unregister-ScheduledTask -TaskName "ClaudePing" -Confirm:$false
    Write-Host "[OK] Removed existing ClaudePing task" -ForegroundColor Yellow
}

# Create scheduled task
$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptDest`""

$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Hours $IntervalHours) `
    -RepetitionDuration ([TimeSpan]::MaxValue)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask `
    -TaskName "ClaudePing" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Pings Claude Code CLI every ${IntervalHours}h to optimize rate limit window alignment" | Out-Null

Write-Host "[OK] Scheduled task 'ClaudePing' created (every ${IntervalHours}h)" -ForegroundColor Green

# Show summary
$nextRun = (Get-Date).AddHours($IntervalHours).ToString("yyyy-MM-dd HH:mm:ss")
Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "  Interval:  every ${IntervalHours} hours"
Write-Host "  Script:    $scriptDest"
Write-Host "  Log:       $installDir\claude-ping.log"
Write-Host "  Next ping: ~$nextRun"
Write-Host ""
Write-Host "To uninstall: .\scripts\uninstall.ps1" -ForegroundColor Gray
