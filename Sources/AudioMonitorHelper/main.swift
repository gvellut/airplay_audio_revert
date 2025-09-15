import CoreAudio
import Foundation
import OSLog

@main
struct AudioMonitorHelper {

    static let logger = Logger(subsystem: "com.user.audiomonitor", category: "AudioService")

    static func main() async {
        logger.info("AudioMonitorHelper service starting up.")

        guard let builtInDeviceID = findBuiltInDeviceID(),
            let builtInDeviceName = getDeviceName(deviceID: builtInDeviceID)
        else {
            logger.error("CRITICAL: Could not find built-in audio device. Exiting.")
            return
        }
        logger.info("Found built-in speakers: '\(builtInDeviceName)'")

        let stream = createDefaultDeviceWatcherStream()
        logger.info("Successfully registered audio device listener. Monitoring for changes...")

        for await _ in stream {
            handleDeviceChange(
                builtInDeviceID: builtInDeviceID, builtInDeviceName: builtInDeviceName)
        }
    }

    static func handleDeviceChange(builtInDeviceID: AudioDeviceID, builtInDeviceName: String) {
        guard let (currentDeviceID, _) = getDefaultOutputDevice() else { return }

        if let transportType = getDeviceTransportType(deviceID: currentDeviceID),
            let deviceName = getDeviceName(deviceID: currentDeviceID)
        {

            logger.log("Default audio output changed to: '\(deviceName)' (Type: \(transportType))")

            if transportType == "airp" {
                logger.notice("AirPlay device detected. Switching back to built-in speakers...")
                setDefaultOutputDevice(deviceID: builtInDeviceID)
                logger.info("Audio output switched back to: '\(builtInDeviceName)'")
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

    static func findBuiltInDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)  // DEPRECATION FIX
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
        for deviceID in deviceIDs {
            if getDeviceTransportType(deviceID: deviceID) == "bltn" {
                var outputAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyStreamConfiguration,
                    mScope: kAudioObjectPropertyScopeOutput, mElement: 0)
                var bufferListSize: UInt32 = 0
                AudioObjectGetPropertyDataSize(deviceID, &outputAddress, 0, nil, &bufferListSize)
                if bufferListSize > 0 { return deviceID }
            }
        }
        return nil
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
