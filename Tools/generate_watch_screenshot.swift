import AppKit
import Foundation

let width = 422
let height = 514
let output = URL(fileURLWithPath: "AppStoreConnect_Midia/AppleWatch_Final_422x514/03-resumo-watch.png")
let iconURL = URL(fileURLWithPath: "Assets.xcassets/AppLaunchIcon.imageset/AppLaunchIcon.png")

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
}

func drawText(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, fill: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byTruncatingTail
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font(size, weight: weight),
        .foregroundColor: fill,
        .paragraphStyle: paragraph
    ]
    text.draw(in: CGRect(x: x, y: CGFloat(height) - y - (size * 1.35), width: CGFloat(width) - x * 2, height: size * 1.45), withAttributes: attrs)
}

func roundedRect(_ rect: CGRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil) {
    let flipped = CGRect(x: rect.minX, y: CGFloat(height) - rect.minY - rect.height, width: rect.width, height: rect.height)
    let path = NSBezierPath(roundedRect: flipped, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

let context = NSGraphicsContext.current!.cgContext
let colors = [color(5, 7, 9).cgColor, color(15, 18, 22).cgColor, color(4, 4, 5).cgColor] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])

color(194, 145, 55, 0.20).setFill()
NSBezierPath(ovalIn: CGRect(x: 80, y: CGFloat(height) - 48 - 260, width: 260, height: 260)).fill()

if let icon = NSImage(contentsOf: iconURL) {
    let rect = CGRect(x: 170, y: 34, width: 82, height: 82)
    let flipped = CGRect(x: rect.minX, y: CGFloat(height) - rect.minY - rect.height, width: rect.width, height: rect.height)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: flipped, xRadius: 20, yRadius: 20).addClip()
    icon.draw(in: flipped)
    NSGraphicsContext.restoreGraphicsState()
}

drawText("Breviário Maçônico", x: 42, y: 132, size: 26, weight: .bold, fill: .white)
drawText("Leitura do dia", x: 42, y: 168, size: 18, weight: .semibold, fill: color(235, 194, 92))

roundedRect(CGRect(x: 30, y: 214, width: 362, height: 168), radius: 26, fill: color(10, 30, 40), stroke: color(20, 100, 135))
drawText("Resumo no Watch", x: 58, y: 246, size: 23, weight: .bold, fill: .white)
drawText("Acompanhe a leitura diária, marque como lida e abra o texto completo no iPhone.", x: 58, y: 286, size: 16, weight: .regular, fill: color(220, 230, 234))

roundedRect(CGRect(x: 72, y: 404, width: 278, height: 58), radius: 20, fill: color(194, 145, 55))
drawText("Abrir leitura", x: 132, y: 420, size: 20, weight: .bold, fill: .black)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Nao foi possivel gerar PNG")
}

try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: output)
print(output.path)
