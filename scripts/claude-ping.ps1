param(
    [string]$Model = $env:CLAUDE_PING_MODEL
)

if (-not $Model) {
    $Model = "claude-haiku-4-5-20251001"
}

$pingDir = Join-Path $env:USERPROFILE ".claude-ping"
$logFile = Join-Path $pingDir "claude-ping.log"

if (-not (Test-Path $pingDir)) {
    New-Item -ItemType Directory -Path $pingDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $logFile -Value "[$timestamp] Pinging Claude (model: $Model)..."

try {
    claude -p "hi" --model $Model 2>&1 | Out-Null
    $exitCode = $LASTEXITCODE
} catch {
    $exitCode = 1
}

$timestamp2 = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
if ($exitCode -eq 0) {
    Add-Content -Path $logFile -Value "[$timestamp2] Done."
} else {
    Add-Content -Path $logFile -Value "[$timestamp2] Failed (exit code: $exitCode). Check claude CLI auth."
}

# Log rotation: keep last 500 lines if file exceeds 1MB
if ((Test-Path $logFile) -and (Get-Item $logFile).Length -gt 1MB) {
    $lines = Get-Content $logFile -Tail 500
    $lines | Set-Content $logFile
}
