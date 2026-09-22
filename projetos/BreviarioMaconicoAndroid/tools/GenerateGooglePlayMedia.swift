import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let media = root.appendingPathComponent("GooglePlay_Midia")
let phone = media.appendingPathComponent("phone")
let backup = media.appendingPathComponent("backup_nome_antigo")

try? FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)

let phoneNames = [
    "01-home-phone-1080x1920.jpg",
    "02-leitura-phone-1080x1920.jpg",
    "03-ativacao-phone-1080x1920.jpg",
]

for name in phoneNames {
    let source = phone.appendingPathComponent(name)
    let target = backup.appendingPathComponent(name)
    if FileManager.default.fileExists(atPath: source.path),
       !FileManager.default.fileExists(atPath: target.path) {
        try? FileManager.default.copyItem(at: source, to: target)
    }
}

func imageContext(width: Int, height: Int, draw: (NSGraphicsContext) -> Void) -> NSImage {
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    if let context = NSGraphicsContext.current {
        draw(context)
    }
    image.unlockFocus()
    return image
}

func saveJpeg(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.95])
    else {
        throw NSError(domain: "GenerateGooglePlayMedia", code: 1)
    }
    try data.write(to: url)
}

func drawText(_ text: String, x: CGFloat, yFromTop: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 0
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]
    let attr = NSAttributedString(string: text, attributes: attrs)
    attr.draw(at: NSPoint(x: x, y: 1920 - yFromTop - size * 1.18))
}

func fillRounded(_ rect: NSRect, radius: CGFloat, color: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    color.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

func patchTop(of url: URL) throws {
    guard let base = NSImage(contentsOf: url) else { return }
    let image = imageContext(width: 1080, height: 1920) { context in
        base.draw(in: NSRect(x: 0, y: 0, width: 1080, height: 1920))
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.01, green: 0.02, blue: 0.03, alpha: 1),
            NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.07, alpha: 1),
        ])!
        gradient.draw(in: NSRect(x: 0, y: 1920 - 560, width: 1080, height: 560), angle: -90)
        NSColor(calibratedRed: 0.02, green: 0.22, blue: 0.28, alpha: 0.20).setFill()
        NSBezierPath(ovalIn: NSRect(x: 650, y: 1560, width: 620, height: 500)).fill()
        NSColor(calibratedRed: 0.02, green: 0.14, blue: 0.19, alpha: 0.22).setFill()
        NSBezierPath(ovalIn: NSRect(x: -260, y: 990, width: 700, height: 620)).fill()
        drawText("Home", x: 52, yFromTop: 94, size: 78, weight: .bold, color: .white)
        drawText("Breviário Maçônico", x: 42, yFromTop: 282, size: 82, weight: .bold, color: NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.04, alpha: 1))
        drawText("Autor: Kennyo Ismail", x: 42, yFromTop: 474, size: 42, weight: .semibold, color: NSColor(calibratedWhite: 0.76, alpha: 1))
    }
    try saveJpeg(image, to: url)
}

func drawSymbol(in rect: NSRect) {
    fillRounded(rect, radius: 42, color: NSColor(calibratedRed: 0.03, green: 0.05, blue: 0.08, alpha: 1), stroke: NSColor(calibratedWhite: 0.32, alpha: 1), lineWidth: 2)
    let gold = NSColor(calibratedRed: 0.85, green: 0.64, blue: 0.22, alpha: 1)
    gold.setStroke()
    let path = NSBezierPath()
    path.lineWidth = 8
    path.move(to: NSPoint(x: rect.midX, y: rect.maxY - 22))
    path.line(to: NSPoint(x: rect.minX + 34, y: rect.minY + 24))
    path.move(to: NSPoint(x: rect.midX, y: rect.maxY - 22))
    path.line(to: NSPoint(x: rect.maxX - 34, y: rect.minY + 24))
    path.move(to: NSPoint(x: rect.minX + 32, y: rect.minY + 24))
    path.line(to: NSPoint(x: rect.maxX - 32, y: rect.minY + 24))
    path.stroke()
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "Georgia-Bold", size: 96) ?? NSFont.boldSystemFont(ofSize: 96),
        .foregroundColor: gold,
    ]
    let g = NSAttributedString(string: "G", attributes: attrs)
    g.draw(at: NSPoint(x: rect.midX - 32, y: rect.midY - 46))
}

func centered(_ text: String, yFromTop: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let attr = NSAttributedString(string: text, attributes: attrs)
    let width = attr.size().width
    attr.draw(at: NSPoint(x: (1080 - width) / 2, y: 1920 - yFromTop - size * 1.18))
}

func recreateActivation(url: URL) throws {
    let image = imageContext(width: 1080, height: 1920) { _ in
        let bg = NSGradient(colors: [
            NSColor(calibratedRed: 0.02, green: 0.02, blue: 0.02, alpha: 1),
            NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.10, alpha: 1),
        ])!
        bg.draw(in: NSRect(x: 0, y: 0, width: 1080, height: 1920), angle: -90)
        NSColor(calibratedRed: 0.60, green: 0.42, blue: 0.12, alpha: 0.22).setStroke()
        for i in 0..<3 {
            let inset = CGFloat(120 + i * 70)
            let path = NSBezierPath(ovalIn: NSRect(x: inset, y: 920 + inset / 3, width: 1080 - inset * 2, height: 780 - inset / 2))
            path.lineWidth = 20
            path.stroke()
        }
        drawSymbol(in: NSRect(x: 445, y: 1634, width: 190, height: 190))
        centered("Breviário Maçônico", yFromTop: 338, size: 66, weight: .bold, color: .white)
        centered("Leitura diária maçônica", yFromTop: 410, size: 36, weight: .bold, color: NSColor(calibratedRed: 0.85, green: 0.64, blue: 0.22, alpha: 1))
        fillRounded(NSRect(x: 80, y: 880, width: 920, height: 520), radius: 28, color: NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.15, alpha: 1), stroke: NSColor(calibratedWhite: 0.42, alpha: 1), lineWidth: 3)
        drawText("Código de ativação", x: 120, yFromTop: 575, size: 34, weight: .bold, color: .white)
        fillRounded(NSRect(x: 120, y: 1200, width: 840, height: 80), radius: 14, color: .white)
        drawText("Digite o código", x: 148, yFromTop: 659, size: 30, weight: .regular, color: NSColor(calibratedWhite: 0.48, alpha: 1))
        fillRounded(NSRect(x: 120, y: 1050, width: 840, height: 80), radius: 16, color: NSColor(calibratedRed: 0.85, green: 0.64, blue: 0.22, alpha: 1))
        centered("Ativar", yFromTop: 810, size: 32, weight: .bold, color: .black)
        drawText("Acesso restrito autorizado por código diário.", x: 120, yFromTop: 930, size: 27, weight: .regular, color: NSColor(calibratedWhite: 0.92, alpha: 1))
        drawText("Após a ativação, todos os recursos ficam disponíveis.", x: 120, yFromTop: 972, size: 27, weight: .bold, color: NSColor(calibratedWhite: 0.92, alpha: 1))
        let items = [
            ("Leitura diária completa", "Textos, notas de rodapé e navegação por data."),
            ("Comentários e favoritos", "Salve reflexões, marque leituras e acompanhe progresso."),
            ("Exportação e compartilhamento", "Gere PDF premium e compartilhe a leitura do dia."),
        ]
        var yTop: CGFloat = 1160
        for item in items {
            fillRounded(NSRect(x: 80, y: 1920 - yTop - 170, width: 920, height: 170), radius: 18, color: NSColor(calibratedRed: 0.02, green: 0.18, blue: 0.24, alpha: 1), stroke: NSColor(calibratedRed: 0.0, green: 0.61, blue: 0.78, alpha: 1), lineWidth: 2)
            NSColor(calibratedRed: 0.0, green: 0.74, blue: 0.90, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 118, y: 1920 - yTop - 115, width: 60, height: 60)).fill()
            drawText(item.0, x: 198, yFromTop: yTop + 38, size: 31, weight: .bold, color: .white)
            drawText(item.1, x: 198, yFromTop: yTop + 88, size: 24, weight: .regular, color: NSColor(calibratedWhite: 0.87, alpha: 1))
            yTop += 205
        }
        centered("Breviário Maçônico", yFromTop: 1825, size: 30, weight: .bold, color: NSColor(calibratedRed: 0.85, green: 0.64, blue: 0.22, alpha: 1))
    }
    try saveJpeg(image, to: url)
}

try patchTop(of: phone.appendingPathComponent("01-home-phone-1080x1920.jpg"))
try patchTop(of: phone.appendingPathComponent("02-leitura-phone-1080x1920.jpg"))
try recreateActivation(url: phone.appendingPathComponent("03-ativacao-phone-1080x1920.jpg"))

for name in phoneNames {
    if let image = NSImage(contentsOf: phone.appendingPathComponent(name)) {
        print("\(name): \(Int(image.size.width))x\(Int(image.size.height))")
    }
}
print("Backup: \(backup.path)")
