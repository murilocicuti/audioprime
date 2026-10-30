// Gera os arquivos de identidade visual a partir de WaveMark.swift.
// Uso: scripts/brand.sh (compila este arquivo junto com Sources/AudioPrime/WaveMark.swift).
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let outDir = URL(fileURLWithPath: args.count > 1 ? args[1] : "brand")
let iconsetDir = URL(fileURLWithPath: args.count > 2 ? args[2] : "build/AppIcon.iconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

// MARK: - Paleta

struct Palette {
    static let paper = CGColor(red: 0.965, green: 0.961, blue: 0.953, alpha: 1)      // #F6F5F3
    static let paperShade = CGColor(red: 0.894, green: 0.890, blue: 0.878, alpha: 1) // #E4E3E0
    static let ink = CGColor(red: 0.078, green: 0.078, blue: 0.086, alpha: 1)        // #141416
    static let inkSoft = CGColor(red: 0.176, green: 0.176, blue: 0.188, alpha: 1)    // #2D2D30
    static let night = CGColor(red: 0.071, green: 0.071, blue: 0.078, alpha: 1)      // #121214
    static let nightLift = CGColor(red: 0.137, green: 0.137, blue: 0.149, alpha: 1)  // #232326
}

// MARK: - Utilidades

func context(_ width: Int, _ height: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    return ctx
}

func savePNG(_ ctx: CGContext, _ url: URL) {
    let image = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

/// Superelipse (n ≈ 5) — aproxima o "squircle" de cantos contínuos dos ícones do macOS.
func squircle(_ rect: CGRect, n: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = pow(abs(c), 2 / n) * a * (c < 0 ? -1 : 1)
        let y = pow(abs(s), 2 / n) * b * (s < 0 ? -1 : 1)
        let p = CGPoint(x: rect.midX + x, y: rect.midY + y)
        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
    }
    path.closeSubpath()
    return path
}

func linearGradient(_ ctx: CGContext, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// Grão sutil, como papel — dá a textura suave da referência.
func grain(_ ctx: CGContext, in rect: CGRect, alpha: CGFloat, seed: UInt64 = 7) {
    var state = seed
    func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) & 0xFFFF) / 65535
    }
    let cell: CGFloat = max(1, rect.width / 512)
    var y = rect.minY
    while y < rect.maxY {
        var x = rect.minX
        while x < rect.maxX {
            let v = next()
            ctx.setFillColor(gray: v > 0.5 ? 1 : 0, alpha: alpha * abs(v - 0.5) * 2)
            ctx.fill(CGRect(x: x, y: y, width: cell, height: cell))
            x += cell
        }
        y += cell
    }
}

// MARK: - Ícone do app

func drawAppIcon(size: Int) -> CGContext {
    let ctx = context(size, size)
    let s = CGFloat(size)
    // Grade de ícones do macOS: corpo de 824/1024 com margem para a sombra.
    let body = CGRect(x: s * 100 / 1024, y: s * 100 / 1024, width: s * 824 / 1024, height: s * 824 / 1024)
    let shape = squircle(body)

    // Sombra suave sob o corpo.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 10 / 1024), blur: s * 28 / 1024,
                  color: CGColor(gray: 0, alpha: 0.28))
    ctx.addPath(shape)
    ctx.setFillColor(Palette.paper)
    ctx.fillPath()
    ctx.restoreGState()

    // Fundo: papel claro com leve gradiente vertical e grão.
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    linearGradient(ctx, [Palette.paper, Palette.paperShade], from: CGPoint(x: 0, y: body.maxY), to: CGPoint(x: 0, y: body.minY))
    if size >= 128 { grain(ctx, in: body, alpha: 0.035) }
    ctx.restoreGState()

    // Borda interna clara (realce de vidro) e contorno escuro muito leve.
    ctx.saveGState()
    ctx.addPath(squircle(body.insetBy(dx: s * 2 / 1024, dy: s * 2 / 1024)))
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.7))
    ctx.setLineWidth(max(1, s * 3 / 1024))
    ctx.strokePath()
    ctx.addPath(shape)
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.08))
    ctx.setLineWidth(max(0.5, s * 1.5 / 1024))
    ctx.strokePath()
    ctx.restoreGState()

    // Marca: tinta grafite com gradiente sutil e uma sombra bem curta.
    let markWidth = body.width * 0.56
    let markRect = CGRect(x: body.midX - markWidth / 2, y: body.midY - markWidth * WaveMark.aspect / 2,
                          width: markWidth, height: markWidth * WaveMark.aspect)
    let mark = WaveMark.path(in: markRect, flipped: true)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 6 / 1024), blur: s * 14 / 1024, color: CGColor(gray: 0, alpha: 0.18))
    ctx.addPath(mark)
    ctx.setFillColor(Palette.ink)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(mark)
    ctx.clip()
    linearGradient(ctx, [Palette.inkSoft, Palette.ink], from: CGPoint(x: 0, y: markRect.maxY), to: CGPoint(x: 0, y: markRect.minY))
    ctx.restoreGState()
    return ctx
}

let iconSizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, size) in iconSizes {
    savePNG(drawAppIcon(size: size), iconsetDir.appendingPathComponent("\(name).png"))
}
savePNG(drawAppIcon(size: 1024), outDir.appendingPathComponent("icon-1024.png"))
savePNG(drawAppIcon(size: 512), outDir.appendingPathComponent("icon-512.png"))

// MARK: - Favicons

func drawFavicon(size: Int) -> CGContext {
    let ctx = context(size, size)
    let s = CGFloat(size)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil))
    ctx.setFillColor(Palette.night)
    ctx.fillPath()
    let w = s * 0.72
    ctx.addPath(WaveMark.path(in: CGRect(x: (s - w) / 2, y: (s - w * WaveMark.aspect) / 2, width: w, height: w * WaveMark.aspect), flipped: true))
    ctx.setFillColor(Palette.paper)
    ctx.fillPath()
    return ctx
}
savePNG(drawFavicon(size: 32), outDir.appendingPathComponent("favicon-32.png"))
savePNG(drawFavicon(size: 180), outDir.appendingPathComponent("apple-touch-icon.png"))

// MARK: - SVG

func svgPath(width: CGFloat) -> String {
    var d = ""
    for (i, p) in WaveMark.outline(samples: 240).enumerated() {
        d += String(format: "%@%.2f %.2f", i == 0 ? "M" : "L", p.x * width, p.y * width)
    }
    return d + "Z"
}

func writeSVG(_ name: String, fill: String, background: String? = nil, size: CGFloat = 512) {
    let markWidth = size * 0.62
    let offsetX = (size - markWidth) / 2
    let offsetY = (size - markWidth * WaveMark.aspect) / 2
    var svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(Int(size)) \(Int(size))\" width=\"\(Int(size))\" height=\"\(Int(size))\">\n"
    if let background {
        svg += "  <rect width=\"\(Int(size))\" height=\"\(Int(size))\" rx=\"\(Int(size * 0.22))\" fill=\"\(background)\"/>\n"
    }
    svg += "  <path transform=\"translate(\(offsetX) \(offsetY))\" fill=\"\(fill)\" d=\"\(svgPath(width: markWidth))\"/>\n</svg>\n"
    try! svg.write(to: outDir.appendingPathComponent(name), atomically: true, encoding: .utf8)
}
writeSVG("mark-ink.svg", fill: "#141416")
writeSVG("mark-paper.svg", fill: "#F6F5F3")
writeSVG("favicon.svg", fill: "#F6F5F3", background: "#121214")

// MARK: - Logotipo (marca + nome) e banner social

func drawText(_ ctx: CGContext, _ text: String, font: NSFont, color: CGColor, at point: CGPoint, kern: CGFloat = 0) -> CGFloat {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: NSColor(cgColor: color)!, .kern: kern,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    ctx.textPosition = point
    CTLineDraw(line, ctx)
    return CTLineGetTypographicBounds(line, nil, nil, nil)
}

func font(_ name: String, _ size: CGFloat, fallbackWeight: NSFont.Weight) -> NSFont {
    NSFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: fallbackWeight)
}

func drawLogo(dark: Bool) -> CGContext {
    let width = 1010, height = 320
    let ctx = context(width, height)
    let ink = dark ? Palette.paper : Palette.ink
    let markHeight: CGFloat = 150
    let markWidth = markHeight / WaveMark.aspect
    let markRect = CGRect(x: 40, y: (CGFloat(height) - markHeight) / 2, width: markWidth, height: markHeight)
    ctx.addPath(WaveMark.path(in: markRect, flipped: true))
    ctx.setFillColor(ink)
    ctx.fillPath()
    _ = drawText(ctx, "AudioPrime", font: font("AvenirNext-DemiBold", 132, fallbackWeight: .semibold), color: ink,
                 at: CGPoint(x: markRect.maxX + 48, y: CGFloat(height) / 2 - 46), kern: -2)
    return ctx
}
savePNG(drawLogo(dark: false), outDir.appendingPathComponent("logo-light.png"))
savePNG(drawLogo(dark: true), outDir.appendingPathComponent("logo-dark.png"))

func drawSocialPreview() -> CGContext {
    let width: CGFloat = 1280, height: CGFloat = 640
    let ctx = context(Int(width), Int(height))
    let rect = CGRect(x: 0, y: 0, width: width, height: height)
    linearGradient(ctx, [Palette.nightLift, Palette.night], from: CGPoint(x: 0, y: height), to: .zero)
    grain(ctx, in: rect, alpha: 0.05, seed: 11)

    let markHeight: CGFloat = 170
    let markWidth = markHeight / WaveMark.aspect
    let markRect = CGRect(x: (width - markWidth) / 2, y: 340, width: markWidth, height: markHeight)
    ctx.addPath(WaveMark.path(in: markRect, flipped: true))
    ctx.setFillColor(Palette.paper)
    ctx.fillPath()

    func centered(_ text: String, _ font: NSFont, _ color: CGColor, y: CGFloat, kern: CGFloat = 0) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .kern: kern]
        let w = CTLineGetTypographicBounds(CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes)), nil, nil, nil)
        _ = drawText(ctx, text, font: font, color: color, at: CGPoint(x: (width - w) / 2, y: y), kern: kern)
    }
    centered("AudioPrime", font("AvenirNext-DemiBold", 84, fallbackWeight: .semibold), Palette.paper, y: 220, kern: -1)
    centered("O volume de cada app, do seu jeito.", font("AvenirNext-Regular", 34, fallbackWeight: .regular),
             CGColor(gray: 1, alpha: 0.62), y: 160)
    centered("Gratuito  ·  Código aberto  ·  macOS", font("AvenirNext-Medium", 22, fallbackWeight: .medium),
             CGColor(gray: 1, alpha: 0.38), y: 92, kern: 1.5)
    return ctx
}
savePNG(drawSocialPreview(), outDir.appendingPathComponent("social-preview.png"))

print("OK: \(outDir.path)")
