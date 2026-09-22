import AppKit
import Foundation

struct Shot {
    let width: Int
    let height: Int
    let output: String
    let kind: Kind
}

enum Kind {
    case homePhone
    case leituraPhone
    case acessoPhone
    case homePad
    case leituraPad
    case acessoPad
    case homeWatch
    case lidoWatch
    case resumoWatch
}

let iconURL = URL(fileURLWithPath: "Assets.xcassets/AppLaunchIcon.imageset/AppLaunchIcon.png")
let title = "Breviário Maçônico"

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
}

final class Canvas {
    let width: CGFloat
    let height: CGFloat
    let image: NSImage

    init(width: Int, height: Int) {
        self.width = CGFloat(width)
        self.height = CGFloat(height)
        self.image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
    }

    func finish(to output: String) throws {
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Nao foi possivel gerar PNG")
        }

        let url = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: url)
        print(url.path)
    }

    func y(_ top: CGFloat, _ h: CGFloat) -> CGFloat {
        height - top - h
    }

    func background() {
        let context = NSGraphicsContext.current!.cgContext
        let colors = [color(4, 6, 8).cgColor, color(7, 23, 31).cgColor, color(3, 4, 5).cgColor] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.58, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])

        color(194, 145, 55, 0.16).setFill()
        NSBezierPath(ovalIn: CGRect(x: width * 0.62, y: y(height * 0.06, width * 0.62), width: width * 0.62, height: width * 0.62)).fill()
        color(0, 125, 170, 0.12).setFill()
        NSBezierPath(ovalIn: CGRect(x: -width * 0.30, y: y(height * 0.58, width * 0.58), width: width * 0.58, height: width * 0.58)).fill()
    }

    func rect(_ rect: CGRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1) {
        let flipped = CGRect(x: rect.minX, y: y(rect.minY, rect.height), width: rect.width, height: rect.height)
        let path = NSBezierPath(roundedRect: flipped, xRadius: radius, yRadius: radius)
        fill.setFill()
        path.fill()
        if let stroke {
            stroke.setStroke()
            path.lineWidth = lineWidth
            path.stroke()
        }
    }

    func circle(x: CGFloat, top: CGFloat, size: CGFloat, fill: NSColor) {
        fill.setFill()
        NSBezierPath(ovalIn: CGRect(x: x, y: y(top, size), width: size, height: size)).fill()
    }

    func text(_ value: String, x: CGFloat, top: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, fill: NSColor, width maxWidth: CGFloat? = nil, align: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = align
        paragraph.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font(size, weight: weight),
            .foregroundColor: fill,
            .paragraphStyle: paragraph
        ]
        let drawWidth = maxWidth ?? (width - x * 2)
        value.draw(in: CGRect(x: x, y: y(top, size * 1.34), width: drawWidth, height: size * 4.0), withAttributes: attrs)
    }

    func centered(_ value: String, top: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, fill: NSColor) {
        text(value, x: 0, top: top, size: size, weight: weight, fill: fill, width: width, align: .center)
    }

    func icon(centerX: CGFloat, top: CGFloat, size: CGFloat, radius: CGFloat) {
        guard let icon = NSImage(contentsOf: iconURL) else {
            return
        }
        let rect = CGRect(x: centerX - size / 2, y: top, width: size, height: size)
        let flipped = CGRect(x: rect.minX, y: y(rect.minY, rect.height), width: rect.width, height: rect.height)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: flipped, xRadius: radius, yRadius: radius).addClip()
        icon.draw(in: flipped)
        NSGraphicsContext.restoreGraphicsState()
    }

    func hiddenTextLines(x: CGFloat, top: CGFloat, widths: [CGFloat], height lineHeight: CGFloat, gap: CGFloat) {
        for (index, lineWidth) in widths.enumerated() {
            let lineTop = top + CGFloat(index) * (lineHeight + gap)
            rect(
                CGRect(x: x, y: lineTop, width: lineWidth, height: lineHeight),
                radius: lineHeight / 2,
                fill: color(214, 222, 226, 0.22)
            )
        }
    }
}

func drawStatus(_ c: Canvas, compact: Bool = false) {
    c.text("20:29", x: compact ? 36 : 128, top: compact ? 22 : 54, size: compact ? 18 : 42, weight: .semibold, fill: .white)
    if compact == false {
        c.rect(CGRect(x: c.width / 2 - 176, y: 36, width: 352, height: 82), radius: 44, fill: .black)
        c.text("Wi-Fi", x: c.width - 304, top: 60, size: 28, weight: .semibold, fill: color(235, 235, 235), width: 120)
        c.rect(CGRect(x: c.width - 202, y: 58, width: 68, height: 34), radius: 12, fill: color(236, 236, 236))
    }
}

func drawPhoneHome(_ c: Canvas) {
    drawStatus(c)
    c.text("Home", x: 46, top: 270, size: 72, weight: .bold, fill: .white)
    c.text(title, x: 36, top: 430, size: 62, weight: .bold, fill: color(255, 211, 0), width: 1120)
    c.text("Leitura diária, comentários, favoritos e estudos maçônicos.", x: 40, top: 585, size: 32, weight: .medium, fill: color(198, 205, 210), width: 1100)

    c.rect(CGRect(x: 34, y: 720, width: 1216, height: 270), radius: 24, fill: color(2, 18, 24), stroke: color(16, 56, 74))
    c.text("Breviário Maçônico", x: 98, top: 790, size: 42, weight: .bold, fill: .white)
    c.text("Leitura diária maçônica com recursos de estudo.", x: 98, top: 858, size: 30, fill: color(196, 203, 208))
    c.text("Selecionado", x: 98, top: 918, size: 28, weight: .semibold, fill: color(235, 194, 92))

    drawFeatureList(c, start: 1065, width: 1216)
}

func drawPhoneReading(_ c: Canvas) {
    drawStatus(c)
    c.text("Leitura", x: 46, top: 270, size: 72, weight: .bold, fill: .white)
    c.text(title, x: 46, top: 410, size: 44, weight: .bold, fill: color(255, 211, 0))
    c.text("08 de junho", x: 46, top: 505, size: 34, weight: .semibold, fill: color(196, 203, 208))
    c.text("Leitura do dia", x: 46, top: 570, size: 44, weight: .bold, fill: color(255, 211, 0))
    c.rect(CGRect(x: 34, y: 680, width: 1216, height: 900), radius: 24, fill: color(2, 18, 24), stroke: color(16, 56, 74))
    c.hiddenTextLines(
        x: 96,
        top: 762,
        widths: [1040, 980, 1088, 930, 1015, 870, 1045, 760],
        height: 28,
        gap: 25
    )
    c.text("Notas de rodapé", x: 96, top: 1280, size: 30, weight: .bold, fill: color(235, 194, 92))
    c.hiddenTextLines(
        x: 96,
        top: 1348,
        widths: [850, 720],
        height: 22,
        gap: 18
    )
    drawBottomTabs(c)
}

func drawPhoneAccess(_ c: Canvas) {
    drawStatus(c)
    c.icon(centerX: c.width / 2, top: 330, size: 224, radius: 48)
    c.centered(title, top: 630, size: 64, weight: .bold, fill: .white)
    c.centered("Acesso institucional protegido", top: 714, size: 36, weight: .semibold, fill: color(235, 194, 92))
    c.rect(CGRect(x: 96, y: 860, width: 1092, height: 650), radius: 32, fill: color(22, 25, 28, 0.94), stroke: color(76, 74, 70), lineWidth: 2)
    c.text("Código de ativação", x: 142, top: 916, size: 34, weight: .bold, fill: .white)
    c.rect(CGRect(x: 142, y: 996, width: 1000, height: 92), radius: 18, fill: color(246, 246, 246))
    c.text("Digite o código", x: 174, top: 1023, size: 34, weight: .medium, fill: color(116, 116, 116))
    c.rect(CGRect(x: 142, y: 1140, width: 1000, height: 94), radius: 22, fill: color(194, 145, 55))
    c.centered("Ativar", top: 1164, size: 38, weight: .bold, fill: .black)
    c.text("Após a ativação, todos os recursos ficam disponíveis.", x: 142, top: 1290, size: 28, weight: .medium, fill: color(218, 218, 218))
    drawFeatureList(c, start: 1640, width: 1092)
}

func drawPadHome(_ c: Canvas) {
    drawStatus(c)
    c.text("Home", x: 118, top: 260, size: 78, weight: .bold, fill: .white)
    c.text(title, x: 118, top: 420, size: 78, weight: .bold, fill: color(255, 211, 0), width: 1600)
    c.text("Leitura diária, estudos, comentários e exportações.", x: 122, top: 535, size: 34, fill: color(198, 205, 210), width: 1600)
    c.rect(CGRect(x: 120, y: 700, width: 1824, height: 280), radius: 28, fill: color(2, 18, 24), stroke: color(16, 56, 74))
    c.text("Breviário Maçônico", x: 190, top: 770, size: 48, weight: .bold, fill: .white)
    c.text("Leitura diária maçônica com recursos de estudo.", x: 190, top: 845, size: 32, fill: color(196, 203, 208))
    c.text("Selecionado", x: 190, top: 910, size: 28, weight: .semibold, fill: color(235, 194, 92))
    drawFeatureList(c, start: 1080, width: 1824, x: 120)
}

func drawPadReading(_ c: Canvas) {
    drawStatus(c)
    c.text("Leitura", x: 118, top: 260, size: 78, weight: .bold, fill: .white)
    c.text(title, x: 118, top: 410, size: 54, weight: .bold, fill: color(255, 211, 0))
    c.rect(CGRect(x: 120, y: 590, width: 1824, height: 1160), radius: 28, fill: color(2, 18, 24), stroke: color(16, 56, 74))
    c.text("08 de junho", x: 190, top: 670, size: 36, weight: .semibold, fill: color(196, 203, 208))
    c.text("Leitura do dia", x: 190, top: 745, size: 52, weight: .bold, fill: color(255, 211, 0))
    c.hiddenTextLines(
        x: 190,
        top: 875,
        widths: [1510, 1410, 1580, 1320, 1490, 1250, 1540, 1180],
        height: 32,
        gap: 28
    )
    c.text("Notas de rodapé", x: 190, top: 1280, size: 34, weight: .bold, fill: color(235, 194, 92))
    c.hiddenTextLines(x: 190, top: 1350, widths: [1320, 1040], height: 26, gap: 22)
}

func drawPadAccess(_ c: Canvas) {
    drawStatus(c)
    c.icon(centerX: c.width / 2, top: 288, size: 252, radius: 54)
    c.centered(title, top: 594, size: 76, weight: .bold, fill: .white)
    c.centered("Acesso institucional protegido", top: 694, size: 42, weight: .semibold, fill: color(235, 194, 92))
    c.rect(CGRect(x: 420, y: 830, width: 1224, height: 650), radius: 34, fill: color(22, 25, 28, 0.94), stroke: color(76, 74, 70), lineWidth: 2)
    c.text("Código de ativação", x: 480, top: 890, size: 36, weight: .bold, fill: .white)
    c.rect(CGRect(x: 480, y: 982, width: 1104, height: 94), radius: 18, fill: color(246, 246, 246))
    c.text("Digite o código", x: 516, top: 1010, size: 36, weight: .medium, fill: color(116, 116, 116))
    c.rect(CGRect(x: 480, y: 1138, width: 1104, height: 96), radius: 22, fill: color(194, 145, 55))
    c.centered("Ativar", top: 1162, size: 40, weight: .bold, fill: .black)
    c.text("Após a ativação, todos os recursos ficam disponíveis.", x: 480, top: 1290, size: 30, weight: .medium, fill: color(218, 218, 218))
    drawFeatureList(c, start: 1605, width: 1224, x: 420)
}

func drawFeatureList(_ c: Canvas, start: CGFloat, width: CGFloat, x: CGFloat = 34) {
    let features = [
        ("Leituras diárias", "Textos completos com notas de rodapé."),
        ("Estudo e organização", "Favoritos, comentários e progresso."),
        ("Exportação premium", "PDF e compartilhamento da leitura.")
    ]

    var top = start
    for (heading, subheading) in features {
        c.rect(CGRect(x: x, y: top, width: width, height: 190), radius: 22, fill: color(3, 25, 34), stroke: color(15, 86, 116))
        c.circle(x: x + 42, top: top + 58, size: 58, fill: color(0, 159, 220))
        c.text(heading, x: x + 132, top: top + 62, size: 34, weight: .bold, fill: .white, width: width - 170)
        c.text(subheading, x: x + 132, top: top + 116, size: 28, fill: color(205, 217, 222), width: width - 170)
        top += 230
    }
}

func drawBottomTabs(_ c: Canvas) {
    c.rect(CGRect(x: 46, y: 2388, width: 1192, height: 150), radius: 72, fill: color(8, 41, 61), stroke: color(0, 100, 150))
    c.text("Home", x: 130, top: 2442, size: 27, weight: .semibold, fill: color(0, 166, 255), width: 150, align: .center)
    c.text("Leitura", x: 360, top: 2442, size: 27, weight: .semibold, fill: .white, width: 160, align: .center)
    c.text("Breviário", x: 590, top: 2442, size: 27, weight: .semibold, fill: .white, width: 180, align: .center)
    c.text("Índice", x: 830, top: 2442, size: 27, weight: .semibold, fill: .white, width: 150, align: .center)
    c.text("Mais", x: 1050, top: 2442, size: 27, weight: .semibold, fill: .white, width: 140, align: .center)
}

func drawWatch(_ c: Canvas, mode: Kind) {
    drawStatus(c, compact: true)
    c.icon(centerX: c.width / 2, top: 42, size: 74, radius: 18)
    c.text(title, x: 34, top: 132, size: 22, weight: .bold, fill: .white)
    c.text(mode == .lidoWatch ? "Marcado como lido" : "Leitura do dia", x: 34, top: 166, size: 17, weight: .semibold, fill: color(235, 194, 92))
    c.rect(CGRect(x: 30, y: 214, width: 362, height: 168), radius: 26, fill: color(10, 30, 40), stroke: color(20, 100, 135))
    c.text(mode == .resumoWatch ? "Resumo no Watch" : "Breviário Maçônico", x: 58, top: 246, size: 22, weight: .bold, fill: .white)
    c.text("Acompanhe a leitura diária, marque como lida e abra o texto completo no iPhone.", x: 58, top: 286, size: 16, fill: color(220, 230, 234))
    c.rect(CGRect(x: 72, y: 404, width: 278, height: 58), radius: 20, fill: color(194, 145, 55))
    c.text(mode == .lidoWatch ? "Lido" : "Abrir leitura", x: 72, top: 420, size: 20, weight: .bold, fill: .black, width: 278, align: .center)
}

let shots = [
    Shot(width: 1284, height: 2778, output: "AppStoreConnect_Midia/iPhone_Final_1284x2778/01-home-iphone.png", kind: .homePhone),
    Shot(width: 1284, height: 2778, output: "AppStoreConnect_Midia/iPhone_Final_1284x2778/02-leitura-iphone.png", kind: .leituraPhone),
    Shot(width: 1284, height: 2778, output: "AppStoreConnect_Midia/iPhone_Final_1284x2778/03-ativacao-iphone.png", kind: .acessoPhone),
    Shot(width: 2064, height: 2752, output: "AppStoreConnect_Midia/iPad_Final_2064x2752/01-home-ipad.png", kind: .homePad),
    Shot(width: 2064, height: 2752, output: "AppStoreConnect_Midia/iPad_Final_2064x2752/02-leitura-ipad.png", kind: .leituraPad),
    Shot(width: 2064, height: 2752, output: "AppStoreConnect_Midia/iPad_Final_2064x2752/03-ativacao-ipad.png", kind: .acessoPad),
    Shot(width: 422, height: 514, output: "AppStoreConnect_Midia/AppleWatch_Final_422x514/01-home-watch.png", kind: .homeWatch),
    Shot(width: 422, height: 514, output: "AppStoreConnect_Midia/AppleWatch_Final_422x514/02-lido-watch.png", kind: .lidoWatch),
    Shot(width: 422, height: 514, output: "AppStoreConnect_Midia/AppleWatch_Final_422x514/03-resumo-watch.png", kind: .resumoWatch)
]

for shot in shots {
    let canvas = Canvas(width: shot.width, height: shot.height)
    canvas.background()
    switch shot.kind {
    case .homePhone:
        drawPhoneHome(canvas)
    case .leituraPhone:
        drawPhoneReading(canvas)
    case .acessoPhone:
        drawPhoneAccess(canvas)
    case .homePad:
        drawPadHome(canvas)
    case .leituraPad:
        drawPadReading(canvas)
    case .acessoPad:
        drawPadAccess(canvas)
    case .homeWatch, .lidoWatch, .resumoWatch:
        drawWatch(canvas, mode: shot.kind)
    }
    try canvas.finish(to: shot.output)
}
