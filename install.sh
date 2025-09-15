#!/bin/bash
set -e

# --- Configuration ---
LAUNCHER_NAME="AudioMonitorLauncher"
HELPER_NAME="AudioMonitorHelper"
APP_NAME="AudioMonitor.app"

# Build/staging directory, kept within the project's .build folder
APP_BUILD_DIR=".build/appBuild"
# The final, user-facing installation directory
FINAL_INSTALL_DIR="$HOME/Applications"

# The full path to the .app bundle in the staging area
STAGED_APP_PATH="$APP_BUILD_DIR/$APP_NAME"
# The full path to the .app bundle in its final destination
FINAL_APP_PATH="$FINAL_INSTALL_DIR/$APP_NAME"

echo "Step 1: Building both launcher and helper for release..."
swift build -c release

echo "Step 2: Creating a clean staging directory at $APP_BUILD_DIR..."
# Clean up the entire staging directory from any previous build
rm -rf "$APP_BUILD_DIR"
# Create the required directory structure for the .app bundle inside the staging area
mkdir -p "$STAGED_APP_PATH/Contents/MacOS"

echo "Step 3: Copying executables into the staging .app bundle..."
# Copy BOTH the launcher and the helper into the same directory inside the staged app
cp ".build/release/$LAUNCHER_NAME" "$STAGED_APP_PATH/Contents/MacOS/"
cp ".build/release/$HELPER_NAME" "$STAGED_APP_PATH/Contents/MacOS/"

echo "Step 4: Creating a proper Info.plist in the staging .app bundle..."
# This Info.plist makes the app a background-only agent (no Dock icon).
cat << EOF > "$STAGED_APP_PATH/Contents/Info.plist"
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

# --- NEW STEP ---
echo "Step 5: Applying an ad-hoc signature to the app bundle..."
codesign --force --deep --sign "My Swift Dev Cert" "$STAGED_APP_PATH"

echo "Step 6: Installing the completed app to $FINAL_INSTALL_DIR..."
mkdir -p "$FINAL_INSTALL_DIR"
rm -rf "$FINAL_APP_PATH"
cp -R "$STAGED_APP_PATH" "$FINAL_INSTALL_DIR/"

echo "Step 7: Adding the installed application to Login Items..."
osascript -e "tell application \"System Events\" to delete login item \"$APP_NAME\"" 2>/dev/null || true
osascript -e "tell application \"System Events\" to make new login item at end with properties {path:\"$FINAL_APP_PATH\", hidden:false}"

echo ""
echo "✅ Installation complete."
echo "$APP_NAME has been signed, installed, and added to your Login Items."