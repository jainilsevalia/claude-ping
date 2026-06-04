#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/.claude-ping"
TASK_NAME="com.claude-ping"

echo ""
echo "claude-ping uninstaller (macOS/Linux)"
echo "======================================"
echo ""

OS="$(uname -s)"

if [ "$OS" = "Darwin" ]; then
    # macOS: remove launchd agent
    PLIST_PATH="$HOME/Library/LaunchAgents/${TASK_NAME}.plist"
    if launchctl list "$TASK_NAME" > /dev/null 2>&1; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        echo "[OK] Unloaded launchd agent"
    else
        echo "[--] No launchd agent found"
    fi
    if [ -f "$PLIST_PATH" ]; then
        rm "$PLIST_PATH"
        echo "[OK] Removed $PLIST_PATH"
    fi
else
    # Linux: remove cron entry
    if crontab -l 2>/dev/null | grep -q "claude-ping"; then
        (crontab -l 2>/dev/null | grep -v "claude-ping") | crontab -
        echo "[OK] Removed cron entry"
    else
        echo "[--] No cron entry found"
    fi
fi

# Remove install directory
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "[OK] Removed $INSTALL_DIR"
else
    echo "[--] No install directory found"
fi

echo ""
echo "Uninstall complete."
