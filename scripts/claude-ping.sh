#!/usr/bin/env bash
set -euo pipefail

# Source shell profile to ensure claude is in PATH (needed for cron/launchd)
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.bash_profile"; do
    if [ -f "$rc" ]; then
        source "$rc" 2>/dev/null || true
        break
    fi
done

MODEL="${CLAUDE_PING_MODEL:-claude-haiku-4-5-20251001}"
PING_DIR="$HOME/.claude-ping"
LOG_FILE="$PING_DIR/claude-ping.log"

mkdir -p "$PING_DIR"

timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

echo "[$(timestamp)] Pinging Claude (model: $MODEL)..." >> "$LOG_FILE"

if claude -p "hi" --model "$MODEL" > /dev/null 2>&1; then
    echo "[$(timestamp)] Done." >> "$LOG_FILE"
else
    echo "[$(timestamp)] Failed (exit code: $?). Check claude CLI auth." >> "$LOG_FILE"
fi

# Log rotation: keep last 500 lines if file exceeds 1MB
if [ -f "$LOG_FILE" ]; then
    file_size=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$file_size" -gt 1048576 ]; then
        tail -500 "$LOG_FILE" > "$LOG_FILE.tmp"
        mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
fi
