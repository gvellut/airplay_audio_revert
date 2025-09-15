#!/bin/bash
set -e
# --- Configuration ---
HELPER_NAME="AudioMonitorHelper"
APP_NAME="AudioMonitor.app"
INSTALL_DIR="$HOME/Applications"
APP_PATH="$INSTALL_DIR/$APP_NAME"

echo "Step 1: Removing the .app from Login Items..."
osascript -e "tell application \"System Events\" to delete login item \"$APP_NAME\"" 2>/dev/null || true

echo "Step 2: Stopping any running helper process..."
pkill -f "$HELPER_NAME" || true

echo "Step 3: Deleting the application bundle..."
rm -rf "$APP_PATH"

echo ""
echo "✅ Uninstallation complete."