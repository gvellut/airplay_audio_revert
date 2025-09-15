import AppKit
import OSLog

let logger = Logger(subsystem: "com.user.audiomonitor", category: "Launcher")

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.info("Launcher started. Attempting to launch helper...")

        // Assume the helper is in Contents/MacOS alongside the launcher
        let bundleURL = Bundle.main.bundleURL
        let helperURL = bundleURL.appending(path: "Contents/MacOS/AudioMonitorHelper")

        // Check if helper is already running to avoid launching duplicates
        let processName = "AudioMonitorHelper"
        let runningApps = NSWorkspace.shared.runningApplications
        let isAlreadyRunning = runningApps.contains { $0.localizedName == processName }

        if isAlreadyRunning {
            logger.warning("Helper process is already running. Launcher will exit.")
        } else {
            do {
                try Process.run(helperURL, arguments: [])
                logger.info("Successfully launched helper process.")
            } catch {
                logger.error(
                    "Failed to launch helper: \(error.localizedDescription, privacy: .public)")
            }
        }

        logger.info("Launcher has completed its task. Exiting.")
        NSApplication.shared.terminate(self)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
