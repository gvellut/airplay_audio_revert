// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AudioMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        // The background worker - same as before
        .executableTarget(
            name: "AudioMonitorHelper",
            linkerSettings: [
                .linkedFramework("CoreAudio")
            ]
        ),
        // The new, windowless launcher application
        .executableTarget(
            name: "AudioMonitorLauncher",
            dependencies: [],
            linkerSettings: [
                // It needs AppKit to behave like an application
                .linkedFramework("AppKit")
            ]
        ),
    ]
)
