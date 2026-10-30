import CoreGraphics
import Foundation

/// A marca do AudioPrime: uma onda sonora espelhada, com lóbulos arredondados alternados
/// acima e abaixo do eixo e pontas afiladas. Fonte única para o ícone da barra de menus,
/// o ícone do app e os arquivos em brand/.
enum WaveMark {
    /// Altura / largura da marca.
    static let aspect: CGFloat = 0.8

    private struct Lobe { let center: CGFloat; let width: CGFloat; let height: CGFloat }

    // Coordenadas normalizadas: x de 0 a 1, alturas relativas à largura.
    private static let upper = [
        Lobe(center: 0.15, width: 0.068, height: 0.20),
        Lobe(center: 0.36, width: 0.076, height: 0.40),
        Lobe(center: 0.64, width: 0.076, height: 0.40),
        Lobe(center: 0.85, width: 0.068, height: 0.20),
    ]
    private static let lower = [
        Lobe(center: 0.25, width: 0.070, height: 0.22),
        Lobe(center: 0.50, width: 0.078, height: 0.40),
        Lobe(center: 0.75, width: 0.070, height: 0.22),
    ]
    /// Meia-espessura do "corpo" que une os lóbulos.
    private static let body: CGFloat = 0.062
    /// Comprimento das pontas afiladas em cada extremidade.
    private static let tip: CGFloat = 0.11

    /// Estado da animação: `time` em segundos e `intensity` de 0 (marca parada) a 1.
    struct Motion {
        var time: CGFloat
        var intensity: CGFloat
    }

    /// Altura do lóbulo num instante: cada um "respira" para baixo (nunca passa da altura
    /// em repouso, então a marca não sai da área) com ritmo e fase próprios.
    private static func height(of lobe: Lobe, _ motion: Motion?) -> CGFloat {
        guard let motion, motion.intensity > 0 else { return lobe.height }
        let rate = 0.45 + 0.4 * (lobe.center * 7.3).truncatingRemainder(dividingBy: 1)
        let wave = 0.5 + 0.5 * sin(2 * .pi * rate * motion.time + lobe.center * 11)
        let depth: CGFloat = lobe.height > 0.3 ? 0.24 : 0.32
        return lobe.height * (1 - motion.intensity * depth * wave)
    }

    private static func profile(_ x: CGFloat, _ lobes: [Lobe], _ motion: Motion?) -> CGFloat {
        // Ponta côncava (cresce ~u²) que termina em zero nas extremidades.
        let u = min(min(x, 1 - x) / tip, 1)
        let taper = u * u * (3 - 2 * u)
        var value = body * taper
        for lobe in lobes {
            let d = abs(x - lobe.center) / lobe.width
            // Gaussiana generalizada (p = 3): lóbulo encorpado com topo arredondado.
            value = smoothMax(value, height(of: lobe, motion) * exp(-pow(d, 3)), k: 0.075)
        }
        return value * taper.squareRoot()
    }

    private static func smoothMax(_ a: CGFloat, _ b: CGFloat, k: CGFloat) -> CGFloat {
        let h = max(k - abs(a - b), 0) / k
        return max(a, b) + h * h * k * 0.25
    }

    /// Pontos do contorno (sentido horário) em coordenadas normalizadas,
    /// com y crescendo para baixo e o eixo da onda em y = aspect / 2.
    static func outline(samples: Int = 480, motion: Motion? = nil) -> [CGPoint] {
        let mid = aspect / 2
        var points: [CGPoint] = []
        for i in 0...samples {
            let x = CGFloat(i) / CGFloat(samples)
            points.append(CGPoint(x: x, y: mid - profile(x, upper, motion)))
        }
        for i in stride(from: samples - 1, to: 0, by: -1) {
            let x = CGFloat(i) / CGFloat(samples)
            points.append(CGPoint(x: x, y: mid + profile(x, lower, motion)))
        }
        return points
    }

    /// Caminho da marca ajustado (centralizado, proporção mantida) ao retângulo.
    static func path(in rect: CGRect, flipped: Bool = false, motion: Motion? = nil, samples: Int = 480) -> CGPath {
        let scale = min(rect.width, rect.height / aspect)
        let origin = CGPoint(x: rect.midX - scale / 2, y: rect.midY - scale * aspect / 2)
        let path = CGMutablePath()
        for (i, p) in outline(samples: samples, motion: motion).enumerated() {
            let y = flipped ? aspect - p.y : p.y
            let point = CGPoint(x: origin.x + p.x * scale, y: origin.y + y * scale)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
