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
            Image(systemName: store.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var store: MixerStore?

    func applicationWillTerminate(_ notification: Notification) {
        // Desfaz os taps para que nenhum app fique mudo depois que saímos.
        MainActor.assumeIsolated { store?.shutdown() }
    }
}
