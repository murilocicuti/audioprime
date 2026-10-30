import AppKit
import CoreAudio
import Darwin

/// Um app visível (ex.: Chrome) com todos os objetos de processo de áudio que pertencem a ele
/// (ex.: os processos auxiliares que realmente tocam o som).
struct AudioApp: Identifiable {
    let id: String              // bundle ID do app "dono"
    let name: String
    let icon: NSImage?
    var processObjects: [AudioObjectID]
    var isPlaying: Bool
}

enum AudioProcesses {
    private typealias ResponsibleFn = @convention(c) (pid_t) -> pid_t
    /// `responsibility_get_pid_responsible_for_pid` mapeia helpers (WebContent, renderers) para o app que os abriu.
    private static let responsibleFor: ResponsibleFn? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid") else { return nil }
        return unsafeBitCast(symbol, to: ResponsibleFn.self)
    }()

    static let systemSoundsID = "local.audioprime.system-sounds"

    static func currentApps() -> [AudioApp] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let objects = CA.array(CA.system, CA.address(kAudioHardwarePropertyProcessObjectList), of: AudioObjectID.self)
        let running = NSWorkspace.shared.runningApplications
        var apps: [String: AudioApp] = [:]

        for object in objects {
            let pid = CA.get(object, CA.address(kAudioProcessPropertyPID), default: pid_t(-1))
            guard pid > 0, pid != ownPID else { continue }
            let playing = CA.get(object, CA.address(kAudioProcessPropertyIsRunningOutput), default: UInt32(0)) != 0
            let bundleID = CA.string(object, kAudioProcessPropertyBundleID) ?? ""

            let owner = owningApp(pid: pid, bundleID: bundleID, running: running)
            let key: String
            let name: String
            let icon: NSImage?
            if let owner, let ownerID = owner.bundleIdentifier {
                key = ownerID
                name = owner.localizedName ?? ownerID
                icon = owner.icon
            } else if bundleID.contains("systemsound") || processName(pid) == "systemsoundserverd" {
                key = systemSoundsID
                name = "Sons do sistema"
                icon = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: nil)
            } else {
                // Processos de sistema sem app associado (coreaudiod, etc.) ficam de fora.
                continue
            }

            if var existing = apps[key] {
                existing.processObjects.append(object)
                existing.isPlaying = existing.isPlaying || playing
                apps[key] = existing
            } else {
                apps[key] = AudioApp(id: key, name: name, icon: icon, processObjects: [object], isPlaying: playing)
            }
        }
        return apps.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func owningApp(pid: pid_t, bundleID: String, running: [NSRunningApplication]) -> NSRunningApplication? {
        if let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular { return app }
        if let responsibleFor {
            let responsible = responsibleFor(pid)
            if responsible > 0, responsible != pid,
               let app = NSRunningApplication(processIdentifier: responsible), app.activationPolicy == .regular {
                return app
            }
        }
        // Fallback: helper cujo bundle ID começa com o do app (com.google.Chrome.helper → com.google.Chrome).
        return running
            .filter { $0.activationPolicy == .regular && !($0.bundleIdentifier ?? "").isEmpty && bundleID.hasPrefix($0.bundleIdentifier!) }
            .max { ($0.bundleIdentifier?.count ?? 0) < ($1.bundleIdentifier?.count ?? 0) }
    }

    private static func processName(_ pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        proc_name(pid, &buffer, UInt32(buffer.count))
        return String(cString: buffer)
    }
}
