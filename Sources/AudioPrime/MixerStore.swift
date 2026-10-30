import AppKit
import Combine
import CoreAudio
import ServiceManagement

struct AppSetting: Codable, Equatable {
    var volume: Float = 1
    var muted = false
    /// nil = segue a saída padrão do sistema.
    var outputUID: String?

    var isDefault: Bool { volume >= 0.999 && !muted && outputUID == nil }
}

@MainActor
final class MixerStore: ObservableObject {
    @Published private(set) var apps: [AudioApp] = []
    @Published private(set) var outputs: [OutputDevice] = []
    @Published private(set) var defaultOutput = AudioObjectID(kAudioObjectUnknown)
    @Published private(set) var settings: [String: AppSetting] = [:]
    @Published var systemVolume: Float = 0
    @Published var lastError: String?
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.enabled); reconcile() }
    }
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    /// Outros apps que também interceptam áudio por app e podem disputar o mesmo som.
    @Published private(set) var conflictingApps: [String] = []

    private static let knownMixers: [String: String] = [
        "com.rogueamoeba.soundsource": "SoundSource",
        "com.bearisdriving.BGM.App": "Background Music",
        "com.bitgapp.eqmac": "eqMac",
        "com.galambastwins.apoo": "Apoo",
    ]

    private var taps: [String: AppTap] = [:]
    private var timer: Timer?
    private var listeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var observers: [NSObjectProtocol] = []

    private enum Keys {
        static let settings = "appSettings"
        static let enabled = "enabled"
    }

    init() {
        isEnabled = UserDefaults.standard.object(forKey: Keys.enabled) as? Bool ?? true
        if let data = UserDefaults.standard.data(forKey: Keys.settings),
           let saved = try? JSONDecoder().decode([String: AppSetting].self, from: data) {
            settings = saved
        }
        refresh()
        startObserving()
    }

    // MARK: - Consultas para a UI

    func setting(for app: AudioApp) -> AppSetting { settings[app.id] ?? AppSetting() }

    /// Apps tocando agora, ou com ajustes ativos (para não "sumirem" quando silenciados).
    var visibleApps: [AudioApp] {
        apps.filter { $0.isPlaying || !(settings[$0.id]?.isDefault ?? true) }
    }

    var defaultOutputName: String {
        outputs.first { $0.id == defaultOutput }?.name ?? "Nenhuma saída"
    }

    // MARK: - Ações

    func setVolume(_ volume: Float, for app: AudioApp) {
        update(app) { $0.volume = volume; if volume > 0 { $0.muted = false } }
    }

    func toggleMute(_ app: AudioApp) {
        update(app) { $0.muted.toggle() }
    }

    func setOutput(_ uid: String?, for app: AudioApp) {
        update(app) { $0.outputUID = uid }
    }

    func setSystemOutput(_ device: OutputDevice) {
        do {
            try AudioDevices.setDefaultOutput(device.id)
        } catch {
            lastError = "Não foi possível mudar a saída. Tente nos Ajustes do Sistema."
        }
        refresh()
    }

    func setSystemVolume(_ volume: Float) {
        systemVolume = volume
        AudioDevices.setVolume(volume, of: defaultOutput)
    }

    func resetAll() {
        settings = [:]
        save()
        reconcile()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            lastError = "Não foi possível alterar o início automático: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func shutdown() {
        taps.values.forEach { $0.stop() }
        taps.removeAll()
    }

    private func update(_ app: AudioApp, _ change: (inout AppSetting) -> Void) {
        var setting = settings[app.id] ?? AppSetting()
        change(&setting)
        settings[app.id] = setting.isDefault ? nil : setting
        save()
        reconcile()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Keys.settings)
        }
    }

    // MARK: - Estado do Core Audio

    func refresh() {
        outputs = AudioDevices.outputDevices()
        defaultOutput = AudioDevices.defaultOutput()
        systemVolume = AudioDevices.volume(of: defaultOutput) ?? systemVolume
        apps = AudioProcesses.currentApps()
        conflictingApps = NSWorkspace.shared.runningApplications
            .compactMap { $0.bundleIdentifier.flatMap { Self.knownMixers[$0] } }
            .sorted()
        reconcile()
    }

    /// Cria, atualiza ou desfaz os taps para que o estado real corresponda às configurações.
    private func reconcile() {
        let defaultUID = outputs.first { $0.id == defaultOutput }?.uid
        var wanted: Set<String> = []

        for app in apps {
            guard isEnabled, let setting = settings[app.id], !setting.isDefault, let defaultUID else { continue }
            let chosenUID = setting.outputUID.flatMap { uid in outputs.contains { $0.uid == uid } ? uid : nil }
            let outputUID = chosenUID ?? defaultUID
            let gain: Float = setting.muted ? 0 : setting.volume
            // Saída escolhida desconectada e volume normal: não há o que fazer, deixa o app tocar sozinho.
            if gain >= 0.999 && outputUID == defaultUID { continue }
            wanted.insert(app.id)

            let processes = app.processObjects.sorted()
            if let tap = taps[app.id], tap.outputUID == outputUID, tap.processObjects == processes {
                tap.setGain(gain)
                continue
            }
            taps[app.id]?.stop()
            taps[app.id] = nil
            do {
                taps[app.id] = try AppTap(processObjects: processes, outputUID: outputUID, gain: gain)
            } catch {
                lastError = "\(app.name): \(error.localizedDescription) Verifique a permissão de áudio em Ajustes do Sistema › Privacidade."
            }
        }

        for id in taps.keys where !wanted.contains(id) {
            taps[id]?.stop()
            taps[id] = nil
        }
    }

    private func startObserving() {
        let selectors = [
            kAudioHardwarePropertyProcessObjectList,
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultOutputDevice,
        ]
        for selector in selectors {
            var address = CA.address(selector)
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor in self?.refresh() }
            }
            if AudioObjectAddPropertyListenerBlock(CA.system, &address, .main, block) == noErr {
                listeners.append((CA.system, address, block))
            }
        }

        // "Está tocando" não tem notificação agregada; um polling leve mantém a lista atual.
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }

        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didWakeNotification,
        ]
        for name in names {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        // Desfaz os taps antes de dormir; ao acordar, refresh() os recria com os dispositivos atuais.
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.shutdown() }
        })
    }
}
