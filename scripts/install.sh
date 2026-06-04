#!/usr/bin/env bash
set -euo pipefail

INTERVAL_HOURS="${1:-5}"
if ! [[ "$INTERVAL_HOURS" =~ ^[0-9]+$ ]] || [ "$INTERVAL_HOURS" -lt 1 ] || [ "$INTERVAL_HOURS" -gt 24 ]; then
    echo "ERROR: Interval must be a number between 1 and 24 (hours)."
    exit 1
fi

START_AT="${2:-}"
if [ -n "$START_AT" ]; then
    if ! [[ "$START_AT" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        echo "ERROR: --start-at must be in HH:MM format (24-hour, e.g. 04:00)."
        exit 1
    fi
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.claude-ping"
TASK_NAME="com.claude-ping"

echo ""
echo "claude-ping installer (macOS/Linux)"
echo "===================================="
echo ""

# Check if claude CLI is available
CLAUDE_PATH=""
for p in "$(command -v claude 2>/dev/null || true)" "$HOME/.claude/bin/claude" "/usr/local/bin/claude"; do
    if [ -n "$p" ] && [ -x "$p" ]; then
        CLAUDE_PATH="$p"
        break
    fi
done

if [ -z "$CLAUDE_PATH" ]; then
    echo "ERROR: 'claude' CLI not found in PATH."
    echo "Install Claude Code first: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
fi
echo "[OK] Found claude CLI at: $CLAUDE_PATH"

# Create install directory
mkdir -p "$INSTALL_DIR"

# Copy ping script
cp "$SCRIPT_DIR/claude-ping.sh" "$INSTALL_DIR/claude-ping.sh"
chmod +x "$INSTALL_DIR/claude-ping.sh"
echo "[OK] Installed ping script to: $INSTALL_DIR/claude-ping.sh"

# Build hour list from --start-at + interval (used by macOS and Linux when START_AT is set)
build_hour_list() {
    local start_hour=$1
    local start_minute=$2
    local interval=$3
    local h=$start_hour
    HOUR_LIST=""
    while true; do
        HOUR_LIST="${HOUR_LIST:+$HOUR_LIST,}$h"
        h=$(( (h + interval) % 24 ))
        [ "$h" -eq "$start_hour" ] && break
    done
    START_MINUTE=$start_minute
}

# Detect OS
OS="$(uname -s)"

if [ "$OS" = "Darwin" ]; then
    # macOS: use launchd
    PLIST_PATH="$HOME/Library/LaunchAgents/${TASK_NAME}.plist"

    # Unload existing agent if present
    if launchctl list "$TASK_NAME" > /dev/null 2>&1; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        echo "[OK] Removed existing launchd agent"
    fi

    # Resolve PATH for launchd context
    CLAUDE_DIR="$(dirname "$CLAUDE_PATH")"
    LAUNCH_PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$CLAUDE_DIR:$HOME/.claude/bin"

    if [ -n "$START_AT" ]; then
        # Parse start time and build calendar interval entries
        START_HOUR=$((10#${START_AT%%:*}))
        START_MIN=$((10#${START_AT##*:}))
        build_hour_list "$START_HOUR" "$START_MIN" "$INTERVAL_HOURS"

        # Generate StartCalendarInterval XML entries
        CALENDAR_ENTRIES=""
        IFS=',' read -ra HOURS <<< "$HOUR_LIST"
        for h in "${HOURS[@]}"; do
            CALENDAR_ENTRIES="${CALENDAR_ENTRIES}        <dict>
            <key>Hour</key>
            <integer>${h}</integer>
            <key>Minute</key>
            <integer>${START_MIN}</integer>
        </dict>
"
        done

        SCHEDULE_BLOCK="    <key>StartCalendarInterval</key>
    <array>
${CALENDAR_ENTRIES}    </array>"

        cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${TASK_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${INSTALL_DIR}/claude-ping.sh</string>
    </array>
${SCHEDULE_BLOCK}
    <key>StandardOutPath</key>
    <string>${INSTALL_DIR}/launchd-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${INSTALL_DIR}/launchd-stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>${LAUNCH_PATH}</string>
        <key>HOME</key>
        <string>${HOME}</string>
    </dict>
</dict>
</plist>
EOF
    else
        INTERVAL_SECONDS=$((INTERVAL_HOURS * 3600))
        cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${TASK_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${INSTALL_DIR}/claude-ping.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>${INTERVAL_SECONDS}</integer>
    <key>StandardOutPath</key>
    <string>${INSTALL_DIR}/launchd-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${INSTALL_DIR}/launchd-stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>${LAUNCH_PATH}</string>
        <key>HOME</key>
        <string>${HOME}</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
    fi

    launchctl load "$PLIST_PATH"
    echo "[OK] Launchd agent loaded (every ${INTERVAL_HOURS}h)"

else
    # Linux: use cron
    if [ -n "$START_AT" ]; then
        START_HOUR=$((10#${START_AT%%:*}))
        START_MIN=$((10#${START_AT##*:}))
        build_hour_list "$START_HOUR" "$START_MIN" "$INTERVAL_HOURS"
        CRON_ENTRY="${START_MIN} ${HOUR_LIST} * * * /bin/bash \"${INSTALL_DIR}/claude-ping.sh\" # claude-code-ping"
    else
        CRON_ENTRY="0 */${INTERVAL_HOURS} * * * /bin/bash \"${INSTALL_DIR}/claude-ping.sh\" # claude-code-ping"
    fi

    # Remove existing claude-code-ping entries (matched by trailing comment), add new one
    (crontab -l 2>/dev/null | grep -v "# claude-code-ping" || true; echo "$CRON_ENTRY") | crontab -
    echo "[OK] Cron entry added (every ${INTERVAL_HOURS}h)"
fi

echo ""
echo "Installation complete!"
echo "  Interval:  every ${INTERVAL_HOURS} hours"
if [ -n "$START_AT" ]; then
    echo "  Start at:  ${START_AT}"
    echo "  Schedule:  minute ${START_MIN}, hours ${HOUR_LIST}"
fi
echo "  Script:    $INSTALL_DIR/claude-ping.sh"
echo "  Log:       $INSTALL_DIR/claude-ping.log"
echo ""
echo "To uninstall: bash scripts/uninstall.sh"
