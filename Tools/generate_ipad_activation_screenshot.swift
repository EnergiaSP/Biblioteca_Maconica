import AppKit
import Foundation

let width = 2064
let height = 2752
let output = URL(fileURLWithPath: "AppStoreConnect_Midia/iPad_Final_2064x2752/03-ativacao-ipad.png")
let iconURL = URL(fileURLWithPath: "Assets.xcassets/AppLaunchIcon.imageset/AppLaunchIcon.png")

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
}

func pointY(_ y: CGFloat, _ size: CGFloat) -> CGFloat {
    CGFloat(height) - y - (size * 1.22)
}

func drawText(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, fill: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font(size, weight: weight),
        .foregroundColor: fill
    ]
    text.draw(at: CGPoint(x: x, y: pointY(y, size)), withAttributes: attrs)
}

func drawCentered(_ text: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, fill: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font(size, weight: weight),
        .foregroundColor: fill
    ]
    let measured = text.size(withAttributes: attrs)
    text.draw(at: CGPoint(x: (CGFloat(width) - measured.width) / 2, y: pointY(y, size)), withAttributes: attrs)
}

func roundedRect(_ rect: CGRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1) {
    let flipped = CGRect(x: rect.minX, y: CGFloat(height) - rect.minY - rect.height, width: rect.width, height: rect.height)
    let path = NSBezierPath(roundedRect: flipped, xRadius: radius, yRadius: radius)
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
NSBezierPath(ovalIn: CGRect(x: 560, y: CGFloat(height) - 220 - 920, width: 920, height: 920)).fill()
color(20, 90, 120, 0.13).setFill()
NSBezierPath(ovalIn: CGRect(x: -340, y: CGFloat(height) - 1580 - 820, width: 820, height: 820)).fill()

drawText("20:29", x: 150, y: 62, size: 42, weight: .semibold, fill: .white)
roundedRect(CGRect(x: 856, y: 38, width: 352, height: 82), radius: 44, fill: .black)
drawText("•••", x: 1630, y: 62, size: 38, weight: .bold, fill: color(235, 235, 235))
drawText("Wi-Fi", x: 1710, y: 64, size: 28, weight: .semibold, fill: color(235, 235, 235))
roundedRect(CGRect(x: 1880, y: 62, width: 72, height: 34), radius: 12, fill: color(236, 236, 236))

if let icon = NSImage(contentsOf: iconURL) {
    let rect = CGRect(x: 906, y: 288, width: 252, height: 252)
    let flipped = CGRect(x: rect.minX, y: CGFloat(height) - rect.minY - rect.height, width: rect.width, height: rect.height)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: flipped, xRadius: 54, yRadius: 54).addClip()
    icon.draw(in: flipped)
    NSGraphicsContext.restoreGraphicsState()
}

drawCentered("Breviário Maçônico", y: 594, size: 78, weight: .bold, fill: .white)
drawCentered("Leitura diária maçônica", y: 694, size: 42, weight: .semibold, fill: color(235, 194, 92))

roundedRect(CGRect(x: 420, y: 830, width: 1224, height: 650), radius: 34, fill: color(22, 25, 28, 0.94), stroke: color(76, 74, 70), lineWidth: 2)
drawText("Código de ativação", x: 480, y: 890, size: 36, weight: .bold, fill: .white)
roundedRect(CGRect(x: 480, y: 982, width: 1104, height: 94), radius: 18, fill: color(246, 246, 246))
drawText("Digite o código", x: 516, y: 1010, size: 36, weight: .medium, fill: color(116, 116, 116))
roundedRect(CGRect(x: 480, y: 1138, width: 1104, height: 96), radius: 22, fill: color(194, 145, 55))
drawCentered("Ativar", y: 1162, size: 40, weight: .bold, fill: .black)
drawText("Acesso restrito autorizado por código diário.", x: 480, y: 1290, size: 30, weight: .medium, fill: color(218, 218, 218))
drawText("Após a ativação, todos os recursos ficam disponíveis.", x: 480, y: 1338, size: 30, weight: .medium, fill: color(218, 218, 218))

let features = [
    ("Leitura diária completa", "Textos, notas de rodapé e navegação por data."),
    ("Comentários e favoritos", "Salve reflexões, marque leituras e acompanhe progresso."),
    ("Exportação e compartilhamento", "Gere PDF premium e compartilhe a leitura do dia.")
]

var y: CGFloat = 1605
for (title, subtitle) in features {
    roundedRect(CGRect(x: 420, y: y, width: 1224, height: 204), radius: 24, fill: color(12, 28, 38), stroke: color(24, 86, 116), lineWidth: 2)
    color(0, 159, 220).setFill()
    NSBezierPath(ovalIn: CGRect(x: 476, y: CGFloat(height) - (y + 64) - 64, width: 64, height: 64)).fill()
    drawText(title, x: 590, y: y + 48, size: 34, weight: .bold, fill: .white)
    drawText(subtitle, x: 590, y: y + 100, size: 28, weight: .regular, fill: color(205, 217, 222))
    y += 246
}

drawCentered("Breviário Maçônico", y: 2450, size: 34, weight: .bold, fill: color(235, 194, 92))
drawCentered("Acesso institucional protegido", y: 2502, size: 28, weight: .regular, fill: color(220, 220, 220))

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Nao foi possivel gerar PNG")
}

try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: output)
print(output.path)
