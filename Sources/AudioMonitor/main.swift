import CoreAudio
import Foundation

// --- Helper Functions to Interact with CoreAudio ---

// Function to get the name of an audio device
func getDeviceName(deviceID: AudioDeviceID) -> String? {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster
    )

    var deviceName: CFString = "" as CFString
    var propertySize = UInt32(MemoryLayout<CFString>.size)

    let status = withUnsafeMutablePointer(to: &deviceName) {
        $0.withMemoryRebound(to: UnsafeMutableRawPointer.self, capacity: 1) {
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, $0.pointee)
        }
    }
    if status == noErr {
        return deviceName as String
    }
    return nil
}

// Function to get the transport type of an audio device (e.g., 'airp' for AirPlay, 'bltn' for Built-In)
func getDeviceTransportType(deviceID: AudioDeviceID) -> String? {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyTransportType,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster
    )

    var transportType = UInt32(0)
    var propertySize = UInt32(MemoryLayout<UInt32>.size)

    let status = AudioObjectGetPropertyData(
        deviceID, &address, 0, nil, &propertySize, &transportType)
    if status == noErr {
        // Convert the 4-character code to a string
        return String(
            format: "%c%c%c%c",
            (transportType >> 24) & 0xFF,
            (transportType >> 16) & 0xFF,
            (transportType >> 8) & 0xFF,
            transportType & 0xFF
        ).trimmingCharacters(in: .whitespaces)
    }
    return nil
}

// Function to find the ID of the built-in output device
func findBuiltInDeviceID() -> AudioDeviceID? {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster
    )

    var propertySize: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize)
    if status != noErr { return nil }

    let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

    status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs)
    if status != noErr { return nil }

    for deviceID in deviceIDs {
        if getDeviceTransportType(deviceID: deviceID) == "bltn" {
            // Check if it has output channels
            var outputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: 0
            )
            var bufferListSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(deviceID, &outputAddress, 0, nil, &bufferListSize)
            if bufferListSize > 0 {
                return deviceID
            }
        }
    }
    return nil
}

// Function to set the default output device
func setDefaultOutputDevice(deviceID: AudioDeviceID) {
    var newDeviceID = deviceID
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster
    )
    let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
    AudioObjectSetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, propertySize, &newDeviceID)
}

// --- Main Logic ---

// Find the built-in device ID once at the start
guard let builtInDeviceID = findBuiltInDeviceID(),
    let builtInDeviceName = getDeviceName(deviceID: builtInDeviceID)
else {
    print("Error: Could not find built-in audio device.")
    exit(1)
}
print("Found built-in speakers: '\(builtInDeviceName)'")

// This is the function that will be called when an audio device changes
let propertyListener: AudioObjectPropertyListenerBlock = {
    (inObjectID, inAddresses) in
    var defaultOutputDeviceID: AudioDeviceID = 0
    var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster
    )

    // Get the current default output device
    AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize,
        &defaultOutputDeviceID)

    if let transportType = getDeviceTransportType(deviceID: defaultOutputDeviceID),
        let deviceName = getDeviceName(deviceID: defaultOutputDeviceID)
    {

        print("Default audio output changed to: '\(deviceName)' (Type: \(transportType))")

        // Check if the new device is an AirPlay device
        if transportType == "airp" {
            print("AirPlay device detected. Switching back to built-in speakers...")
            setDefaultOutputDevice(deviceID: builtInDeviceID)
            print("Audio output switched back to: '\(builtInDeviceName)'")
        }
    }
}

// Register our listener to be notified of changes to the default output device
var address = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMaster
)

let status = AudioObjectAddPropertyListenerBlock(
    AudioObjectID(kAudioObjectSystemObject), &address, nil, propertyListener)

if status == noErr {
    print("Successfully registered audio device listener. Monitoring for changes...")
    print("Press Ctrl+C to exit.")
    // Keep the script running to listen for events
    RunLoop.main.run()
} else {
    print("Error: Could not add property listener. Status: \(status)")
}
