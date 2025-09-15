// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AudioMonitor",
    platforms: [
        .macOS(.v10_15)  // Specify macOS as the platform
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // A target can depend on other targets in this package and products in packages this package depends on.
        .executableTarget(
            name: "AudioMonitor",
            linkerSettings: [
                // This is the crucial part: it tells the linker to include the CoreAudio framework.
                .linkedFramework("CoreAudio")
            ]
        )
    ]
)
