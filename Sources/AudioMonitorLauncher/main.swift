import AppKit
import OSLog
import ServiceManagement

let logger = Logger(subsystem: "com.user.audiomonitor", category: "Launcher")

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.info("Launcher started.")

        do {
            // Check the current status of the background service
            let service = SMAppService.loginItem(
                identifier: "com.user.audiomonitor.AudioMonitorHelper")

            if service.status == .enabled {
                logger.info("Background service is already enabled. Nothing to do.")
            } else {
                // If not enabled, register and enable it.
                try service.register()
                logger.info("Successfully registered and enabled the background service.")
            }
        } catch {
            logger.error(
                "Failed to register background service: \(error.localizedDescription, privacy: .public)"
            )
        }

        logger.info("Launcher has completed its task. Exiting.")
        NSApplication.shared.terminate(self)
    }

}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
