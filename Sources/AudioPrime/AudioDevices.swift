import CoreAudio
import Foundation

struct OutputDevice: Identifiable, Hashable {
    let id: AudioObjectID
    let uid: String
    let name: String
}

enum AudioDevices {
    /// Volume "virtual" principal do dispositivo ('vmvc'), o mesmo que o slider do macOS usa.
    static let virtualMainVolume = AudioObjectPropertySelector(0x766D_7663) // 'vmvc'

    static func outputDevices() -> [OutputDevice] {
        CA.array(CA.system, CA.address(kAudioHardwarePropertyDevices), of: AudioObjectID.self).compactMap { id in
            let transport = CA.get(id, CA.address(kAudioDevicePropertyTransportType), default: UInt32(0))
            guard transport != kAudioDeviceTransportTypeAggregate || !isOurs(id) else { return nil }
            let streams = CA.array(id, CA.address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput), of: AudioStreamID.self)
            guard !streams.isEmpty,
                  let uid = CA.string(id, kAudioDevicePropertyDeviceUID),
                  let name = CA.string(id, kAudioObjectPropertyName) else { return nil }
            return OutputDevice(id: id, uid: uid, name: name)
        }
    }

    static func isOurs(_ id: AudioObjectID) -> Bool {
        CA.string(id, kAudioDevicePropertyDeviceUID)?.hasPrefix(AppTap.aggregateUIDPrefix) ?? false
    }

    static func defaultOutput() -> AudioObjectID {
        CA.get(CA.system, CA.address(kAudioHardwarePropertyDefaultOutputDevice), default: AudioObjectID(kAudioObjectUnknown))
    }

    static func setDefaultOutput(_ id: AudioObjectID) throws {
        try CA.set(CA.system, CA.address(kAudioHardwarePropertyDefaultOutputDevice), id)
    }

    private static func volumeAddress() -> AudioObjectPropertyAddress {
        CA.address(virtualMainVolume, scope: kAudioObjectPropertyScopeOutput)
    }

    static func volume(of device: AudioObjectID) -> Float? {
        guard CA.has(device, volumeAddress()) else { return nil }
        return CA.getOptional(device, volumeAddress(), as: Float32.self)
    }

    static func setVolume(_ volume: Float, of device: AudioObjectID) {
        guard CA.isSettable(device, volumeAddress()) else { return }
        try? CA.set(device, volumeAddress(), Float32(volume))
    }
}
