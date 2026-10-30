import AppKit
import SwiftUI

@main
struct AudioPrimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = MixerStore()

    var body: some Scene {
        MenuBarExtra {
            MixerView()
                .environmentObject(store)
                .onAppear { delegate.store = store }
        } label: {
            MenuBarLabel(animator: store.menuBar)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Observa só o animador, para que os quadros da animação não redesenhem o painel.
private struct MenuBarLabel: View {
    @ObservedObject var animator: MenuBarAnimator

    var body: some View {
        Image(nsImage: animator.image)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var store: MixerStore?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Duas instâncias criariam taps concorrentes no mesmo app; a mais nova sai.
        let me = NSRunningApplication.current
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0.processIdentifier != me.processIdentifier }
        if !others.isEmpty { exit(0) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Desfaz os taps para que nenhum app fique mudo depois que saímos.
        MainActor.assumeIsolated { store?.shutdown() }
    }
}
