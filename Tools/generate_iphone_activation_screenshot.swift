import AppKit
import Foundation

let width = 1284
let height = 2778
let output = URL(fileURLWithPath: "AppStoreConnect_Midia/iPhone_Final_1284x2778/03-ativacao-iphone.png")
let iconURL = URL(fileURLWithPath: "Assets.xcassets/AppLaunchIcon.imageset/AppLaunchIcon.png")

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
}

func drawText(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, fill: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font(size, weight: weight),
        .foregroundColor: fill,
        .paragraphStyle: paragraph
    ]
    text.draw(at: CGPoint(x: x, y: CGFloat(height) - y - (size * 1.22)), withAttributes: attrs)
}

func drawCentered(_ text: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, fill: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font(size, weight: weight),
        .foregroundColor: fill
    ]
    let measured = text.size(withAttributes: attrs)
    text.draw(at: CGPoint(x: (CGFloat(width) - measured.width) / 2, y: CGFloat(height) - y - (size * 1.22)), withAttributes: attrs)
}

func roundedRect(_ rect: CGRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1) {
    let flippedRect = CGRect(x: rect.minX, y: CGFloat(height) - rect.minY - rect.height, width: rect.width, height: rect.height)
    let path = NSBezierPath(roundedRect: flippedRect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

let context = NSGraphicsContext.current!.cgContext
let colors = [color(7, 9, 11).cgColor, color(26, 18, 8).cgColor, color(5, 5, 5).cgColor] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])

color(180, 132, 44, 0.18).setFill()
NSBezierPath(ovalIn: CGRect(x: 220, y: CGFloat(height) - 230 - 844, width: 844, height: 844)).fill()
color(20, 90, 120, 0.13).setFill()
NSBezierPath(ovalIn: CGRect(x: -260, y: CGFloat(height) - 1770 - 740, width: 740, height: 740)).fill()

drawText("20:29", x: 172, y: 56, size: 42, weight: .semibold, fill: .white)
roundedRect(CGRect(x: 466, y: 36, width: 352, height: 82), radius: 44, fill: .black)
drawText("•••", x: 900, y: 58, size: 38, weight: .bold, fill: color(235, 235, 235))
drawText("Wi-Fi", x: 980, y: 60, size: 28, weight: .semibold, fill: color(235, 235, 235))
roundedRect(CGRect(x: 1082, y: 58, width: 68, height: 34), radius: 12, fill: color(236, 236, 236))

if let icon = NSImage(contentsOf: iconURL) {
    let iconRect = CGRect(x: 530, y: 342, width: 224, height: 224)
    let flippedIconRect = CGRect(x: iconRect.minX, y: CGFloat(height) - iconRect.minY - iconRect.height, width: iconRect.width, height: iconRect.height)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: flippedIconRect, xRadius: 48, yRadius: 48).addClip()
    icon.draw(in: flippedIconRect)
    NSGraphicsContext.restoreGraphicsState()
}

drawCentered("Breviário Maçônico", y: 630, size: 68, weight: .bold, fill: .white)
drawCentered("Leitura diária maçônica", y: 714, size: 38, weight: .semibold, fill: color(235, 194, 92))

roundedRect(CGRect(x: 96, y: 860, width: 1092, height: 650), radius: 32, fill: color(22, 25, 28, 0.94), stroke: color(76, 74, 70), lineWidth: 2)
drawText("Código de ativação", x: 142, y: 916, size: 34, weight: .bold, fill: .white)
roundedRect(CGRect(x: 142, y: 996, width: 1000, height: 92), radius: 18, fill: color(246, 246, 246))
drawText("Digite o código", x: 174, y: 1023, size: 34, weight: .medium, fill: color(116, 116, 116))
roundedRect(CGRect(x: 142, y: 1140, width: 1000, height: 94), radius: 22, fill: color(194, 145, 55))
drawCentered("Ativar", y: 1164, size: 38, weight: .bold, fill: .black)
drawText("Acesso restrito autorizado por código diário.", x: 142, y: 1290, size: 28, weight: .medium, fill: color(218, 218, 218))
drawText("Após a ativação, todos os recursos ficam disponíveis.", x: 142, y: 1336, size: 28, weight: .medium, fill: color(218, 218, 218))

let features = [
    ("Leitura diária completa", "Textos, notas de rodapé e navegação por data."),
    ("Comentários e favoritos", "Salve reflexões, marque leituras e acompanhe progresso."),
    ("Exportação e compartilhamento", "Gere PDF premium e compartilhe a leitura do dia.")
]

var y: CGFloat = 1640
for (title, subtitle) in features {
    roundedRect(CGRect(x: 96, y: y, width: 1092, height: 210), radius: 24, fill: color(12, 28, 38), stroke: color(24, 86, 116), lineWidth: 2)
    color(0, 159, 220).setFill()
    NSBezierPath(ovalIn: CGRect(x: 138, y: CGFloat(height) - (y + 62) - 64, width: 64, height: 64)).fill()
    drawText(title, x: 236, y: y + 48, size: 34, weight: .bold, fill: .white)
    drawText(subtitle, x: 236, y: y + 100, size: 28, weight: .regular, fill: color(205, 217, 222))
    y += 246
}

drawCentered("Breviário Maçônico", y: 2480, size: 34, weight: .bold, fill: color(235, 194, 92))
drawCentered("Acesso institucional protegido", y: 2534, size: 28, weight: .regular, fill: color(220, 220, 220))

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Nao foi possivel gerar PNG")
}

try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: output)
print(output.path)
