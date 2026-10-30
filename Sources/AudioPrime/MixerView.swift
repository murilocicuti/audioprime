import SwiftUI

struct MixerView: View {
    @EnvironmentObject private var store: MixerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            systemSection
            Divider()
            appsSection
            if !store.conflictingApps.isEmpty {
                notice(conflictMessage, symbol: "info.circle.fill", color: .blue)
            }
            if let error = store.lastError {
                errorBanner(error)
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 8) {
            WaveMarkShape()
                .fill(.primary)
                .frame(width: 22, height: 22 * WaveMark.aspect)
                .opacity(store.isEnabled ? 1 : 0.35)
                .animation(.easeOut(duration: 0.2), value: store.isEnabled)
            Text("AudioPrime").font(.headline)
            Spacer()
            Toggle("Sound controls", isOn: $store.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .help("Turn per-app volume and output on or off")
        }
    }

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Output").font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary).frame(width: 20)
                Slider(value: Binding(
                    get: { Double(store.systemVolume) },
                    set: { store.setSystemVolume(Float($0)) }
                ), in: 0...1)
                Text(percent(store.systemVolume)).monospacedDigit().frame(width: 38, alignment: .trailing)
            }
            Menu {
                ForEach(store.outputs) { device in
                    Button {
                        store.setSystemOutput(device)
                    } label: {
                        if device.id == store.defaultOutput {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Text(device.name)
                        }
                    }
                }
            } label: {
                Label(store.defaultOutputName, systemImage: "hifispeaker")
            }
            .menuStyle(.borderlessButton)
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Apps").font(.subheadline).foregroundStyle(.secondary)
            let apps = store.visibleApps
            if apps.isEmpty {
                Text("No apps are playing audio.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else if apps.count <= Self.maxRowsWithoutScroll {
                appList(apps)
            } else {
                // No painel do MenuBarExtra a ScrollView não tem altura ideal e colapsa; por isso altura fixa.
                ScrollView { appList(apps) }
                    .frame(height: 360)
            }
        }
        .disabled(!store.isEnabled)
        .opacity(store.isEnabled ? 1 : 0.5)
    }

    private static let maxRowsWithoutScroll = 6

    private var conflictMessage: String {
        let names = store.conflictingApps.joined(separator: ", ")
        return store.conflictingApps.count > 1
            ? String(localized: "\(names) also control app audio. Using both at once can leave apps muted or at the wrong volume.")
            : String(localized: "\(names) also controls app audio. Using both at once can leave apps muted or at the wrong volume.")
    }

    private func appList(_ apps: [AudioApp]) -> some View {
        VStack(spacing: 12) {
            ForEach(apps) { app in
                AppRow(app: app)
            }
        }
    }

    private func notice(_ message: String, symbol: String, color: Color) -> some View {
        HStack(alignment: .top) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(message).font(.caption).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(message).font(.caption).fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button { store.lastError = nil } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Open at login", isOn: Binding(
                get: { store.launchAtLogin },
                set: { store.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.checkbox)
            HStack {
                Button("Reset volumes and outputs") { store.resetAll() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.link)
            HStack(spacing: 4) {
                Text("v\(Brand.version) · Made by")
                Link(Brand.author, destination: Brand.authorURL)
                Spacer()
                Link("GitHub", destination: Brand.repositoryURL)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
    }
}

private struct AppRow: View {
    @EnvironmentObject private var store: MixerStore
    let app: AudioApp

    var body: some View {
        let setting = store.setting(for: app)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let icon = app.icon {
                    Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                }
                Text(app.name).lineLimit(1)
                Spacer()
                outputMenu(setting)
            }
            HStack(spacing: 8) {
                Button { store.toggleMute(app) } label: {
                    Image(systemName: setting.muted || setting.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                .help(setting.muted ? "Unmute" : "Mute")
                Slider(value: Binding(
                    get: { Double(setting.muted ? 0 : setting.volume) },
                    set: { store.setVolume(Float($0), for: app) }
                ), in: 0...1)
                Text(percent(setting.muted ? 0 : setting.volume))
                    .monospacedDigit()
                    .frame(width: 38, alignment: .trailing)
            }
        }
    }

    private func outputMenu(_ setting: AppSetting) -> some View {
        Menu {
            Button {
                store.setOutput(nil, for: app)
            } label: {
                if setting.outputUID == nil {
                    Label("System default", systemImage: "checkmark")
                } else {
                    Text("System default")
                }
            }
            Divider()
            ForEach(store.outputs) { device in
                Button {
                    store.setOutput(device.uid, for: app)
                } label: {
                    if setting.outputUID == device.uid {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
                }
            }
        } label: {
            Text(outputLabel(setting)).font(.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func outputLabel(_ setting: AppSetting) -> String {
        guard let uid = setting.outputUID else { return String(localized: "Default") }
        return store.outputs.first { $0.uid == uid }?.name ?? String(localized: "Disconnected")
    }
}

private func percent(_ value: Float) -> String {
    "\(Int((value * 100).rounded()))%"
}
