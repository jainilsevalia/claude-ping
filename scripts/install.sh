#!/usr/bin/env bash
set -euo pipefail

INTERVAL_HOURS="${1:-5}"
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

# Detect OS
OS="$(uname -s)"

if [ "$OS" = "Darwin" ]; then
    # macOS: use launchd
    PLIST_PATH="$HOME/Library/LaunchAgents/${TASK_NAME}.plist"
    INTERVAL_SECONDS=$((INTERVAL_HOURS * 3600))

    # Unload existing agent if present
    if launchctl list "$TASK_NAME" > /dev/null 2>&1; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        echo "[OK] Removed existing launchd agent"
    fi

    # Resolve PATH for launchd context
    CLAUDE_DIR="$(dirname "$CLAUDE_PATH")"
    LAUNCH_PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$CLAUDE_DIR:$HOME/.claude/bin"

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

    launchctl load "$PLIST_PATH"
    echo "[OK] Launchd agent loaded (every ${INTERVAL_HOURS}h)"

else
    # Linux: use cron
    CRON_ENTRY="0 */${INTERVAL_HOURS} * * * /bin/bash $INSTALL_DIR/claude-ping.sh"

    # Remove existing claude-ping entries, add new one
    (crontab -l 2>/dev/null | grep -v "claude-ping" || true; echo "$CRON_ENTRY") | crontab -
    echo "[OK] Cron entry added (every ${INTERVAL_HOURS}h)"
fi

echo ""
echo "Installation complete!"
echo "  Interval:  every ${INTERVAL_HOURS} hours"
echo "  Script:    $INSTALL_DIR/claude-ping.sh"
echo "  Log:       $INSTALL_DIR/claude-ping.log"
echo ""
echo "To uninstall: bash scripts/uninstall.sh"
