import AppKit
import QuartzCore

/// Ícone da barra de menus. Quando um app começa a tocar, os lóbulos da marca ondulam
/// suavemente por alguns segundos e voltam ao repouso.
///
/// Animação contínua foi descartada: cada quadro faz o AppKit redesenhar o item da barra
/// de menus (≈5% de CPU a 4 fps, ≈15% a 20 fps), e apps como o Discord mantêm um canal de
/// áudio aberto mesmo em silêncio. Um pulso curto custa praticamente zero na média.
@MainActor
final class MenuBarAnimator: ObservableObject {
    @Published private(set) var image = Brand.menuBarImage(enabled: true)

    var isEnabled = true {
        didSet {
            guard isEnabled != oldValue else { return }
            stop()
            image = Brand.menuBarImage(enabled: isEnabled)
        }
    }

    private static let framesPerSecond: Double = 20
    private static let pulseDuration: Double = 2.6
    private var timer: Timer?
    private var pulseStart: CFTimeInterval = 0

    func pulse() {
        guard isEnabled, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        pulseStart = CACurrentMediaTime()
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1 / Self.framesPerSecond, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.01
        // .common mantém a animação enquanto o painel ou um menu está aberto.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let elapsed = CACurrentMediaTime() - pulseStart
        guard elapsed < Self.pulseDuration else {
            stop()
            image = Brand.menuBarImage(enabled: isEnabled)
            return
        }
        // Envelope sin²: entra e sai devagar, sem trancos.
        let envelope = pow(sin(.pi * elapsed / Self.pulseDuration), 2)
        image = Brand.menuBarImage(enabled: true, motion: WaveMark.Motion(time: CGFloat(elapsed * 1.6), intensity: CGFloat(envelope)))
    }
}
