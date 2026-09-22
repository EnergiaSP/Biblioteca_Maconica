import AppKit
import Foundation

let size = 1024
let canvas = NSImage(size: NSSize(width: size, height: size))

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(red: red, green: green, blue: blue, alpha: alpha)
}

func path(points: [NSPoint], close: Bool = true) -> NSBezierPath {
    let result = NSBezierPath()
    guard let first = points.first else {
        return result
    }

    result.move(to: first)
    for point in points.dropFirst() {
        result.line(to: point)
    }
    if close {
        result.close()
    }
    return result
}

func thickLine(from start: NSPoint, to end: NSPoint, width: CGFloat) -> NSBezierPath {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let length = max(sqrt(dx * dx + dy * dy), 1)
    let nx = -dy / length * width / 2
    let ny = dx / length * width / 2

    return path(points: [
        NSPoint(x: start.x + nx, y: start.y + ny),
        NSPoint(x: end.x + nx, y: end.y + ny),
        NSPoint(x: end.x - nx, y: end.y - ny),
        NSPoint(x: start.x - nx, y: start.y - ny)
    ])
}

func drawShadowed(blur: CGFloat = 28, offsetY: CGFloat = -16, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: offsetY)
    shadow.shadowBlurRadius = blur
    shadow.shadowColor = color(0, 0, 0, 0.72)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

func fillGold(_ shape: NSBezierPath, angle: CGFloat) {
    let gold = NSGradient(colorsAndLocations:
        (color(0.42, 0.23, 0.04), 0.00),
        (color(0.88, 0.56, 0.13), 0.18),
        (color(1.00, 0.91, 0.48), 0.39),
        (color(0.78, 0.45, 0.09), 0.60),
        (color(1.00, 0.84, 0.30), 0.78),
        (color(0.48, 0.27, 0.05), 1.00)
    )!
    gold.draw(in: shape, angle: angle)

    color(1.00, 0.93, 0.58, 0.86).setStroke()
    shape.lineWidth = 3
    shape.stroke()

    color(0.05, 0.035, 0.02, 0.70).setStroke()
    shape.lineWidth = 8
    shape.stroke()
}

func drawRulerMarks(from start: NSPoint, to end: NSPoint, count: Int) {
    for index in 1..<count {
        let t = CGFloat(index) / CGFloat(count)
        let x = start.x + (end.x - start.x) * t
        let y = start.y + (end.y - start.y) * t
        let mark = thickLine(
            from: NSPoint(x: x - 10, y: y + 18),
            to: NSPoint(x: x + 14, y: y - 18),
            width: index % 2 == 0 ? 8 : 5
        )
        color(0.18, 0.10, 0.02, 0.45).setFill()
        mark.fill()
    }
}

canvas.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)
NSGradient(colorsAndLocations:
    (color(0.01, 0.01, 0.012), 0.0),
    (color(0.035, 0.040, 0.045), 0.52),
    (color(0.0, 0.0, 0.0), 1.0)
)!.draw(in: rect, angle: -35)

let blueGlow = NSBezierPath(ovalIn: NSRect(x: 308, y: 250, width: 408, height: 456))
NSGradient(colorsAndLocations:
    (color(0.00, 0.88, 1.00, 0.52), 0.0),
    (color(0.00, 0.22, 0.70, 0.22), 0.46),
    (color(0.00, 0.00, 0.00, 0.00), 1.0)
)!.draw(in: blueGlow, angle: 90)

let verticalRay = thickLine(from: NSPoint(x: 512, y: 216), to: NSPoint(x: 512, y: 746), width: 10)
color(0.13, 0.68, 1.0, 0.78).setFill()
verticalRay.fill()
let horizontalRay = thickLine(from: NSPoint(x: 292, y: 486), to: NSPoint(x: 732, y: 486), width: 8)
color(0.16, 0.78, 1.0, 0.55).setFill()
horizontalRay.fill()

let leftSquare = thickLine(from: NSPoint(x: 150, y: 352), to: NSPoint(x: 512, y: 212), width: 82)
let rightSquare = thickLine(from: NSPoint(x: 512, y: 212), to: NSPoint(x: 874, y: 352), width: 82)
drawShadowed {
    fillGold(leftSquare, angle: 18)
    fillGold(rightSquare, angle: 162)
}

drawRulerMarks(from: NSPoint(x: 178, y: 362), to: NSPoint(x: 494, y: 238), count: 8)
drawRulerMarks(from: NSPoint(x: 530, y: 238), to: NSPoint(x: 846, y: 362), count: 8)

let leftCompass = thickLine(from: NSPoint(x: 500, y: 842), to: NSPoint(x: 230, y: 174), width: 48)
let rightCompass = thickLine(from: NSPoint(x: 524, y: 842), to: NSPoint(x: 794, y: 174), width: 48)
drawShadowed {
    fillGold(leftCompass, angle: 75)
    fillGold(rightCompass, angle: 105)
}

let leftEdge = thickLine(from: NSPoint(x: 500, y: 812), to: NSPoint(x: 246, y: 188), width: 12)
let rightEdge = thickLine(from: NSPoint(x: 524, y: 812), to: NSPoint(x: 778, y: 188), width: 12)
color(0.92, 0.92, 0.86, 0.86).setFill()
leftEdge.fill()
rightEdge.fill()

let hingeTop = NSBezierPath(ovalIn: NSRect(x: 442, y: 810, width: 140, height: 96))
drawShadowed(blur: 20, offsetY: -10) {
    fillGold(hingeTop, angle: 25)
}
let hingeGroove = NSBezierPath(ovalIn: NSRect(x: 474, y: 834, width: 76, height: 42))
color(0.04, 0.035, 0.03, 0.68).setFill()
hingeGroove.fill()
color(1.0, 0.88, 0.42, 0.56).setStroke()
hingeGroove.lineWidth = 3
hingeGroove.stroke()

let leftPoint = path(points: [
    NSPoint(x: 208, y: 184),
    NSPoint(x: 246, y: 184),
    NSPoint(x: 228, y: 112)
])
let rightPoint = path(points: [
    NSPoint(x: 778, y: 184),
    NSPoint(x: 816, y: 184),
    NSPoint(x: 796, y: 112)
])
fillGold(leftPoint, angle: 90)
fillGold(rightPoint, angle: 90)

let letterShadow = NSShadow()
letterShadow.shadowOffset = NSSize(width: 0, height: -12)
letterShadow.shadowBlurRadius = 20
letterShadow.shadowColor = color(0, 0, 0, 0.78)

let letterAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "Times New Roman Bold", size: 262) ?? NSFont.systemFont(ofSize: 262, weight: .black),
    .foregroundColor: color(1.0, 0.79, 0.22),
    .strokeColor: color(0.10, 0.065, 0.015),
    .strokeWidth: -3.0,
    .shadow: letterShadow
]
let letter = NSString(string: "G")
let letterSize = letter.size(withAttributes: letterAttributes)
letter.draw(
    at: NSPoint(x: (CGFloat(size) - letterSize.width) / 2 + 4, y: 350),
    withAttributes: letterAttributes
)

let innerSpark = NSBezierPath(ovalIn: NSRect(x: 470, y: 436, width: 86, height: 86))
NSGradient(colorsAndLocations:
    (color(0.90, 1.0, 1.0, 0.96), 0.0),
    (color(0.0, 0.88, 1.0, 0.72), 0.38),
    (color(0.0, 0.12, 0.65, 0.0), 1.0)
)!.draw(in: innerSpark, angle: 0)

let diagonalShine = NSBezierPath()
diagonalShine.move(to: NSPoint(x: 188, y: 706))
diagonalShine.curve(
    to: NSPoint(x: 818, y: 306),
    controlPoint1: NSPoint(x: 382, y: 812),
    controlPoint2: NSPoint(x: 710, y: 676)
)
diagonalShine.lineWidth = 26
color(1, 1, 1, 0.09).setStroke()
diagonalShine.stroke()

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let representation = NSBitmapImageRep(data: tiff),
      let png = representation.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "GenerateAppIcon", code: 1)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try png.write(to: output)
