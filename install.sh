#!/bin/bash
set -e

# --- Configuration ---
LAUNCHER_NAME="AudioMonitorLauncher"
HELPER_NAME="AudioMonitorHelper"
APP_NAME="AudioMonitor.app"
INSTALL_DIR="$HOME/Applications"
APP_PATH="$INSTALL_DIR/$APP_NAME"
MACOS_DIR="$APP_PATH/Contents/MacOS"
PLIST_PATH="$APP_PATH/Contents/Info.plist"

echo "Step 1: Building both launcher and helper for release..."
swift build -c release

echo "Step 2: Creating the .app bundle structure..."
rm -rf "$APP_PATH"
mkdir -p "$MACOS_DIR"

echo "Step 3: Copying executables into the .app bundle..."
cp ".build/release/$LAUNCHER_NAME" "$MACOS_DIR/"
cp ".build/release/$HELPER_NAME" "$MACOS_DIR/"

echo "Step 4: Creating a proper Info.plist for the launcher..."
# This is the key to making the app a true background agent.
# LSUIElement=1 tells macOS not to show the app in the Dock.
cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>$LAUNCHER_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>com.user.audiomonitor.launcher</string>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>
EOF

echo "Step 5: Adding the .app to Login Items..."
osascript -e "tell application \"System Events\" to make new login item at end with properties {path:\"$APP_PATH\", hidden:false}"

echo ""
echo "✅ Installation complete."
echo "$APP_NAME has been installed to $INSTALL_DIR and added to your Login Items."