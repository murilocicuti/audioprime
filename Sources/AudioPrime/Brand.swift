import AppKit
import SwiftUI

enum Brand {
    static let author = "Murilo Cicuti"
    static let authorURL = URL(string: "https://www.linkedin.com/in/murilocicuti")!
    static let repositoryURL = URL(string: "https://github.com/murilocicuti/audioprime")!

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// Ícone da barra de menus: a marca como imagem-modelo (o macOS ajusta a cor ao tema).
    /// Desativado, vira só o contorno.
    static func menuBarImage(enabled: Bool) -> NSImage {
        let height: CGFloat = 15
        let size = NSSize(width: (height / WaveMark.aspect).rounded(), height: height)
        let image = NSImage(size: size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let inset = enabled ? rect : rect.insetBy(dx: 0.6, dy: 0.6)
            ctx.addPath(WaveMark.path(in: inset))
            if enabled {
                ctx.setFillColor(NSColor.black.cgColor)
                ctx.fillPath()
            } else {
                ctx.setStrokeColor(NSColor.black.cgColor)
                ctx.setLineWidth(1.1)
                ctx.setLineJoin(.round)
                ctx.strokePath()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = enabled ? "AudioPrime" : "AudioPrime (desativado)"
        return image
    }
}

/// A marca como Shape do SwiftUI, para usar no painel.
struct WaveMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(WaveMark.path(in: rect))
    }
}
