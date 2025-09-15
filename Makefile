# --- Configuration ---
CONFIG_FILE = app_config.env
include $(CONFIG_FILE)

BUILD_MODE ?= release
ifeq ($(BUILD_MODE),debug)
    SWIFT_BUILD_FLAGS =
    SWIFT_BUILD_DIR = .build/debug
else
    SWIFT_BUILD_FLAGS = -c release
    SWIFT_BUILD_DIR = .build/release
endif

# --- Paths and Artifacts ---
APP_BUILD_DIR = .build/appBuild/$(BUILD_MODE)
APP_BUNDLE = $(APP_BUILD_DIR)/$(APP_NAME).app

ALL_SWIFT_FILES = $(shell find Sources -name '*.swift')

LAUNCHER_EXE_NAME = AudioMonitorLauncher
HELPER_EXE_NAME = AudioMonitorHelper
SWIFT_LAUNCHER_EXE = $(SWIFT_BUILD_DIR)/$(LAUNCHER_EXE_NAME)
SWIFT_HELPER_EXE = $(SWIFT_BUILD_DIR)/$(HELPER_EXE_NAME)

BUNDLE_MACOS_DIR = $(APP_BUNDLE)/Contents/MacOS
BUNDLE_LOGINITEMS_DIR = $(APP_BUNDLE)/Contents/Library/LoginItems
HELPER_APP_BUNDLE = $(BUNDLE_LOGINITEMS_DIR)/$(HELPER_EXE_NAME).app

# Define temporary locations for the generated plists, next to the .app bundle
TEMP_LAUNCHER_PLIST = $(APP_BUILD_DIR)/launcher.plist.tmp
TEMP_HELPER_PLIST = $(APP_BUILD_DIR)/helper.plist.tmp

# Define the final locations for the plists inside the .app bundle
FINAL_LAUNCHER_PLIST = $(APP_BUNDLE)/Contents/Info.plist
FINAL_HELPER_PLIST = $(HELPER_APP_BUNDLE)/Contents/Info.plist

LAUNCHER_PLIST_TEMPLATE = Info.plist.launcher.template
HELPER_PLIST_TEMPLATE = Info.plist.helper.template

FINAL_INSTALL_DIR = $(HOME)/Applications
FINAL_APP_PATH = $(FINAL_INSTALL_DIR)/$(APP_NAME).app

.PHONY: all app debug install uninstall clean

# --- Main Targets ---
all: app

app: $(APP_BUNDLE)

debug:
	@$(MAKE) BUILD_MODE=debug app

install: app
	@echo "--- Installing application to $(FINAL_INSTALL_DIR) ---"
	@mkdir -p $(FINAL_INSTALL_DIR)
	@rm -rf $(FINAL_APP_PATH)
	@cp -R $(APP_BUNDLE) $(FINAL_INSTALL_DIR)/
	@echo ""
	@echo "--- ✅ Installation complete ---"
	@echo "--- IMPORTANT: To activate the background service, please run '$(APP_NAME)' from your Applications folder ONCE. ---"

uninstall:
	@echo "--- Unregistering and disabling the background service ---"
	@echo "--- Stopping any running helper process ---"
	@pkill -f $(HELPER_EXE_NAME) || true
	@echo "--- Deleting application bundle ---"
	@rm -rf $(FINAL_APP_PATH)
	@echo "--- ✅ Uninstallation complete ---"

# --- Build Recipes ---

# RECIPE 1: The App Bundle.
# Depends on the EXECUTABLES and the TEMPORARY plist files.
$(APP_BUNDLE): $(SWIFT_LAUNCHER_EXE) $(SWIFT_HELPER_EXE) $(TEMP_LAUNCHER_PLIST) $(TEMP_HELPER_PLIST)
	@echo "--- Assembling application bundle: $(APP_BUNDLE) ---"
	# Start with a completely clean slate
	@rm -rf $(APP_BUNDLE)
	# Create the full directory structure
	@mkdir -p $(BUNDLE_MACOS_DIR)
	@mkdir -p $(HELPER_APP_BUNDLE)/Contents/MacOS
	# Copy the pre-built executables and plists into the new bundle
	@cp $(SWIFT_LAUNCHER_EXE) $(BUNDLE_MACOS_DIR)/
	@cp $(SWIFT_HELPER_EXE) $(HELPER_APP_BUNDLE)/Contents/MacOS/
	@cp $(TEMP_LAUNCHER_PLIST) $(FINAL_LAUNCHER_PLIST)
	@cp $(TEMP_HELPER_PLIST) $(FINAL_HELPER_PLIST)
	@echo "--- Applying an ad-hoc signature to the app bundle ---"
	@codesign --force --deep --sign "My Swift Dev Cert" $(APP_BUNDLE)
	@echo "--- ✅ App bundle created successfully ---"

# RECIPE 2: The Swift Executables.
$(SWIFT_LAUNCHER_EXE) $(SWIFT_HELPER_EXE): $(ALL_SWIFT_FILES)
	@echo "--- Building Swift executables (if needed)... ---"
	@swift build $(SWIFT_BUILD_FLAGS)

# RECIPE 3: The TEMPORARY Launcher plist.
# THIS RECIPE IS NOW UPDATED
$(TEMP_LAUNCHER_PLIST): $(LAUNCHER_PLIST_TEMPLATE) $(CONFIG_FILE)
	@echo "--- Generating temporary Launcher Info.plist ---"
	@mkdir -p $(APP_BUILD_DIR)
	@sed -e 's/__LAUNCHER_BUNDLE_ID__/$(LAUNCHER_BUNDLE_ID)/g' \
	     -e 's/__HELPER_BUNDLE_ID__/$(HELPER_BUNDLE_ID)/g' \
	     $(LAUNCHER_PLIST_TEMPLATE) > $(TEMP_LAUNCHER_PLIST)

# RECIPE 4: The TEMPORARY Helper plist.
$(TEMP_HELPER_PLIST): $(HELPER_PLIST_TEMPLATE) $(CONFIG_FILE)
	@echo "--- Generating temporary Helper Info.plist ---"
	@mkdir -p $(APP_BUILD_DIR)
	@sed -e 's/__HELPER_BUNDLE_ID__/$(HELPER_BUNDLE_ID)/g' \
	     $(HELPER_PLIST_TEMPLATE) > $(TEMP_HELPER_PLIST)

clean:
	@echo "--- Cleaning up all build artifacts ---"
	@swift package clean
	@rm -rf .build/appBuild
	@echo "--- ✅ Cleanup complete ---"