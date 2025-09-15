# =============================================================================
# Makefile for AudioMonitor
#
# Targets:
#   make app          - Build the .app bundle in release mode (default).
#   make debug        - Build the .app bundle in debug mode.
#   make install      - Build the release .app and install it to ~/Applications.
#   make uninstall    - Remove the app and its Login Item.
#   make clean        - Remove all build artifacts.
# =============================================================================

# --- Configuration ---
# Load configuration from file
CONFIG_FILE = app_config.env
include $(CONFIG_FILE)

# Build configuration (debug or release). Can be overridden from command line.
# Example: make BUILD_MODE=debug app
BUILD_MODE ?= release
ifeq ($(BUILD_MODE),debug)
    SWIFT_BUILD_FLAGS =
    SWIFT_BUILD_DIR = .build/debug
else
    SWIFT_BUILD_FLAGS = -c release
    SWIFT_BUILD_DIR = .build/release
endif

# --- Paths and Artifacts ---
# Staging directory for the .app bundle
APP_BUILD_DIR = .build/appBuild/$(BUILD_MODE)
APP_BUNDLE = $(APP_BUILD_DIR)/$(APP_NAME).app

# Source directories
ALL_SWIFT_FILES = $(shell find Sources -name '*.swift')

# Swift build artifacts
LAUNCHER_EXE_NAME = AudioMonitorLauncher
HELPER_EXE_NAME = AudioMonitorHelper
SWIFT_LAUNCHER_EXE = $(SWIFT_BUILD_DIR)/$(LAUNCHER_EXE_NAME)
SWIFT_HELPER_EXE = $(SWIFT_BUILD_DIR)/$(HELPER_EXE_NAME)

# A sentinel file to track if the Swift build is complete for the current sources
BUILD_SENTINEL = $(SWIFT_BUILD_DIR)/.build_complete

# Bundle paths
BUNDLE_MACOS_DIR = $(APP_BUNDLE)/Contents/MacOS
BUNDLE_PLIST = $(APP_BUNDLE)/Contents/Info.plist
PLIST_TEMPLATE = Info.plist.template

# Final installation paths
FINAL_INSTALL_DIR = $(HOME)/Applications
FINAL_APP_PATH = $(FINAL_INSTALL_DIR)/$(APP_NAME).app

# Phony targets are actions, not files
.PHONY: all app debug install uninstall clean build

# --- Main Targets ---

# Default target
all: app

# Build the application bundle
app: $(APP_BUNDLE)

# Convenience target to build in debug mode
debug:
	@$(MAKE) BUILD_MODE=debug app

# Build, sign, install, and register the application
install: app
	@echo "--- Installing application to $(FINAL_INSTALL_DIR) ---"
	@mkdir -p $(FINAL_INSTALL_DIR)
	@rm -rf $(FINAL_APP_PATH)
	@cp -R $(APP_BUNDLE) $(FINAL_INSTALL_DIR)/
	@echo "--- Adding application to Login Items ---"
	@osascript -e 'tell application "System Events" to delete login item "$(APP_NAME)"' 2>/dev/null || true
	@osascript -e 'tell application "System Events" to make new login item at end with properties {path:"$(FINAL_APP_PATH)", hidden:false}'
	@echo "--- ✅ Installation complete ---"

# Uninstall the application and remove it from Login Items
uninstall:
	@echo "--- Removing application from Login Items ---"
	@osascript -e 'tell application "System Events" to delete login item "$(APP_NAME)"' 2>/dev/null || true
	@echo "--- Stopping any running helper process ---"
	@pkill -f $(HELPER_EXE_NAME) || true
	@echo "--- Deleting application bundle ---"
	@rm -rf $(FINAL_APP_PATH)
	@echo "--- ✅ Uninstallation complete ---"

# --- Build Recipes ---

# Create the .app bundle. This depends on the Swift build being complete and the Info.plist being generated.
$(APP_BUNDLE): $(BUILD_SENTINEL) $(BUNDLE_PLIST)
	@echo "--- Creating application bundle: $(APP_BUNDLE) ---"
	@mkdir -p $(BUNDLE_MACOS_DIR)
	@cp $(SWIFT_LAUNCHER_EXE) $(BUNDLE_MACOS_DIR)/
	@cp $(SWIFT_HELPER_EXE) $(BUNDLE_MACOS_DIR)/
	@echo "--- Applying an ad-hoc signature to the app bundle ---"
	@codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "--- ✅ App bundle created successfully ---"

# Generate the Info.plist from the template and config file.
# If the template or config changes, this target will be rebuilt.
$(BUNDLE_PLIST): $(PLIST_TEMPLATE) $(CONFIG_FILE)
	@echo "--- Generating Info.plist ---"
	@mkdir -p $(APP_BUNDLE)/Contents
	@sed -e 's/__FINAL_EXE_NAME__/$(FINAL_EXE_NAME)/g' \
	     -e 's/__BUNDLE_ID__/$(BUNDLE_ID)/g' \
	     $(PLIST_TEMPLATE) > $(BUNDLE_PLIST)

# Build the Swift executables. This depends on all .swift source files.
# If any source file changes, this target will be rebuilt.
# It creates a sentinel file to signify that the build is done.
$(BUILD_SENTINEL): $(ALL_SWIFT_FILES)
	@echo "--- Building Swift executables in $(BUILD_MODE) mode ---"
	@swift build $(SWIFT_BUILD_FLAGS)
	@touch $(BUILD_SENTINEL)

# Clean up all build artifacts
clean:
	@echo "--- Cleaning up all build artifacts ---"
	@swift package clean
	@rm -rf .build/appBuild
	@echo "--- ✅ Cleanup complete ---"