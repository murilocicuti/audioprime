import CoreAudio
import Foundation

/// Ganho lido pela thread de áudio. Escritas/leituras de Float são atômicas na prática em arm64/x86_64.
final class GainBox: @unchecked Sendable {
    var target: Float
    var current: Float
    init(_ value: Float) { target = value; current = value }
}

/// Intercepta o áudio de um app e o reproduz, com ganho aplicado, no dispositivo de saída escolhido.
///
/// Pipeline: process tap (muta o app no destino original enquanto é lido)
///   → dispositivo agregado privado (tap como entrada + saída real como subdispositivo)
///   → IOProc que copia entrada → saída multiplicando pelo ganho.
final class AppTap {
    static let aggregateUIDPrefix = "com.murilo.audioprime.aggregate."

    let processObjects: [AudioObjectID]
    let outputUID: String
    let gain: GainBox

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "com.murilo.audioprime.io", qos: .userInteractive)

    init(processObjects: [AudioObjectID], outputUID: String, gain: Float) throws {
        self.processObjects = processObjects
        self.outputUID = outputUID
        self.gain = GainBox(gain)
        do {
            try start()
        } catch {
            stop()
            throw error
        }
    }

    deinit { stop() }

    func setGain(_ value: Float) { gain.target = value }

    private func start() throws {
        let description = CATapDescription(stereoMixdownOfProcesses: processObjects)
        description.uuid = UUID()
        description.name = "AudioPrime"
        description.isPrivate = true
        description.muteBehavior = .mutedWhenTapped

        try check(AudioHardwareCreateProcessTap(description, &tapID), String(localized: "Couldn’t capture this app’s audio."))

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "AudioPrime",
            kAudioAggregateDeviceUIDKey: Self.aggregateUIDPrefix + UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: description.uuid.uuidString,
            ]],
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), String(localized: "Couldn’t connect to the audio output."))

        let gain = self.gain
        try check(AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, queue) { _, input, _, output, _ in
            AppTap.render(input: input, output: output, gain: gain)
        }, String(localized: "Couldn’t prepare audio processing."))
        try check(AudioDeviceStart(aggregateID, ioProcID), String(localized: "Couldn’t start audio."))
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            if let ioProcID {
                AudioDeviceStop(aggregateID, ioProcID)
                AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }
        ioProcID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    /// Thread de tempo real: sem alocações nem locks. Assume Float32 (formato padrão do HAL).
    private static func render(input: UnsafePointer<AudioBufferList>, output: UnsafeMutablePointer<AudioBufferList>, gain: GainBox) {
        let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outputs = UnsafeMutableAudioBufferListPointer(output)

        var inputChannels = 0
        for buffer in inputs { inputChannels += Int(buffer.mNumberChannels) }

        let target = gain.target
        var current = gain.current
        var firstFrames = 0
        if let first = outputs.first, first.mNumberChannels > 0 {
            firstFrames = Int(first.mDataByteSize) / (MemoryLayout<Float>.size * Int(first.mNumberChannels))
        }
        let step = firstFrames > 0 ? (target - current) / Float(firstFrames) : 0

        var channelBase = 0
        for buffer in outputs {
            let channels = Int(buffer.mNumberChannels)
            guard channels > 0, let data = buffer.mData?.assumingMemoryBound(to: Float.self) else {
                channelBase += channels
                continue
            }
            let frames = Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * channels)
            for channel in 0..<channels {
                var g = gain.current
                let source = channelBase + channel
                for frame in 0..<frames {
                    g += step
                    let sample = source < inputChannels ? Self.sample(inputs, channel: source, frame: frame) : 0
                    data[frame * channels + channel] = sample * g
                }
                current = g
            }
            channelBase += channels
        }
        gain.current = firstFrames > 0 ? current : target
    }

    private static func sample(_ buffers: UnsafeMutableAudioBufferListPointer, channel: Int, frame: Int) -> Float {
        var base = 0
        for buffer in buffers {
            let channels = Int(buffer.mNumberChannels)
            if channel < base + channels {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { return 0 }
                let frames = Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * channels)
                return frame < frames ? data[frame * channels + (channel - base)] : 0
            }
            base += channels
        }
        return 0
    }
}
