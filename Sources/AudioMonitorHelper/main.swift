import CoreAudio
import Foundation
import OSLog

@main
struct AudioMonitorHelper {

    static let logger = Logger(subsystem: "com.user.audiomonitor", category: "AudioService")

    static func main() async {
        logger.info("AudioMonitorHelper service starting up.")

        var preferredDeviceID: AudioDeviceID?
        var preferredDeviceName: String?

        // Determine the preferred device, avoiding AirPlay at startup.
        if let (initialDeviceID, initialDeviceName) = getDefaultOutputDevice(),
            getDeviceTransportType(deviceID: initialDeviceID) != "airp"
        {
            // The current device is not AirPlay, so use it as preferred.
            preferredDeviceID = initialDeviceID
            preferredDeviceName = initialDeviceName
            logger.info(
                "Initial audio device is not AirPlay. Setting '\(preferredDeviceName ?? "Unknown")' as preferred device."
            )
        } else {
            // Current device is AirPlay or couldn't be determined. Fall back to a suitable device.
            if getDeviceTransportType(deviceID: getDefaultOutputDevice()?.id ?? 0) == "airp" {
                logger.warning(
                    "Initial audio device is an AirPlay device. Falling back to Bluetooth or built-in speakers."
                )
            }
            // Prioritize Bluetooth, then built-in.
            if let (id, name) = findFirstAvailableDevice(transportTypes: ["blue", "bltn"]) {
                preferredDeviceID = id
                preferredDeviceName = name
            }
        }

        guard var finalDeviceID = preferredDeviceID, var finalDeviceName = preferredDeviceName
        else {
            logger.error("CRITICAL: Could not establish a preferred audio device. Exiting.")
            return
        }

        logger.info("Preferred device set to: '\(finalDeviceName)'")

        let stream = createDefaultDeviceWatcherStream()
        logger.info("Successfully registered audio device listener. Monitoring for changes...")

        for await _ in stream {
            guard let (currentDeviceID, currentDeviceName) = getDefaultOutputDevice() else {
                continue
            }

            if getDeviceTransportType(deviceID: currentDeviceID) == "airp" {
                // The new device is an AirPlay device.
                if currentDeviceID != finalDeviceID {
                    logger.log(
                        "Default audio output changed to AirPlay device: '\(currentDeviceName ?? "Unknown")'"
                    )
                    logger.notice("Switching back to preferred device...")
                    setDefaultOutputDevice(deviceID: finalDeviceID)
                    logger.info("Audio output switched back to: '\(finalDeviceName)'")
                }
            } else {
                // The new device is NOT an AirPlay device. Update our preferred device.
                if currentDeviceID != finalDeviceID {
                    finalDeviceID = currentDeviceID
                    finalDeviceName = currentDeviceName ?? "Unknown"
                    logger.info(
                        "Default audio device changed to a non-AirPlay device. Updating preferred device to: '\(finalDeviceName)'"
                    )
                }
            }
        }
    }

    // --- Helper Functions with Deprecation Fix ---

    static func createDefaultDeviceWatcherStream() -> AsyncStream<Void> {
        AsyncStream { continuation in
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain  // DEPRECATION FIX
            )

            let status = AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, nil
            ) { _, _ in
                continuation.yield(())
            }

            if status != noErr {
                logger.error("Failed to add property listener. Status: \(status).")
                continuation.finish()
            }
        }
    }

    static func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)  // DEPRECATION FIX
        var deviceName: CFString = "" as CFString
        var propertySize = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &deviceName) {
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, $0)
        }
        return status == noErr ? (deviceName as String) : nil
    }

    static func getDeviceTransportType(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)  // DEPRECATION FIX
        var transportType = UInt32(0)
        var propertySize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &propertySize, &transportType)
        if status == noErr {
            return String(
                format: "%c%c%c%c", (transportType >> 24) & 0xFF, (transportType >> 16) & 0xFF,
                (transportType >> 8) & 0xFF, transportType & 0xFF
            ).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    static func findFirstAvailableDevice(transportTypes: [String]) -> (
        id: AudioDeviceID, name: String
    )? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var propertySize: UInt32 = 0
        guard
            AudioObjectGetPropertyDataSize(
                AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize) == noErr
        else { return nil }
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs
            ) == noErr
        else { return nil }

        for transportType in transportTypes {
            for deviceID in deviceIDs {
                if getDeviceTransportType(deviceID: deviceID) == transportType {
                    // Check if it's an output device
                    var outputAddress = AudioObjectPropertyAddress(
                        mSelector: kAudioDevicePropertyStreamConfiguration,
                        mScope: kAudioObjectPropertyScopeOutput, mElement: 0)
                    var bufferListSize: UInt32 = 0
                    AudioObjectGetPropertyDataSize(
                        deviceID, &outputAddress, 0, nil, &bufferListSize)
                    if bufferListSize > 0 {
                        if let deviceName = getDeviceName(deviceID: deviceID) {
                            return (deviceID, deviceName)
                        }
                    }
                }
            }
        }
        return nil
    }

    static func findBuiltInDeviceID() -> AudioDeviceID? {
        return findFirstAvailableDevice(transportTypes: ["bltn"])?.id
    }

    static func setDefaultOutputDevice(deviceID: AudioDeviceID) {
        var newDeviceID = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, propertySize, &newDeviceID)
    }

    static func getDefaultOutputDevice() -> (id: AudioDeviceID, name: String?)? {
        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceID)
                == noErr
        else { return nil }
        return (deviceID, getDeviceName(deviceID: deviceID))
    }
}
