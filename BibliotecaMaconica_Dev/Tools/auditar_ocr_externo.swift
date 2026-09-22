import AppKit
import CoreGraphics
import Darwin
import Foundation
import PDFKit
import Vision

struct SourceReportRow: Codable {
    let arquivo: String
    let status: String
}

struct AuditRow: Codable {
    let arquivo: String
    let statusOriginal: String
    let statusAuditoria: String
    let paginas: Int
    let paginasComTextoPesquisavel: Int
    let paginasSemTextoVisual: [Int]
    let paginasSomenteImagem: [Int]
    let paginasComTextoVisualSemOCR: [Int]
    let paginasNaoRenderizadas: [Int]
    let observacao: String
}

func csvEscape(_ value: String) -> String {
    "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
}

func normalizedText(_ text: String?) -> String {
    (text ?? "")
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func log(_ message: String) {
    print(message)
    fflush(stdout)
}

func renderPage(_ page: CGPDFPage, maxSide: CGFloat = 1200) -> CGImage? {
    let box = page.getBoxRect(.mediaBox)
    guard box.width > 0, box.height > 0 else { return nil }
    let scale = min(maxSide / max(box.width, box.height), 2.0)
    let width = max(1, Int((box.width * scale).rounded()))
    let height = max(1, Int((box.height * scale).rounded()))
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        return nil
    }

    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.scaleBy(x: scale, y: scale)
    let transform = page.getDrawingTransform(.mediaBox, rect: box, rotate: 0, preserveAspectRatio: true)
    context.concatenate(transform)
    context.drawPDFPage(page)
    return context.makeImage()
}

func pageLooksBlank(_ image: CGImage) -> Bool {
    let width = 64
    let height = 64
    var pixels = [UInt8](repeating: 255, count: width * height * 4)
    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return false
    }

    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .low
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    var nonWhitePixels = 0
    for index in stride(from: 0, to: pixels.count, by: 4) {
        if pixels[index] < 245 || pixels[index + 1] < 245 || pixels[index + 2] < 245 {
            nonWhitePixels += 1
        }
    }

    return Double(nonWhitePixels) / Double(width * height) < 0.0025
}

func imageHasRecognizableText(_ image: CGImage) -> Bool {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .fast
    request.usesLanguageCorrection = false
    request.minimumTextHeight = 0.01

    do {
        try VNImageRequestHandler(cgImage: image, orientation: .up, options: [:]).perform([request])
    } catch {
        return false
    }

    let recognized = (request.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: " ")

    let letters = recognized.unicodeScalars.filter {
        CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0)
    }.count
    return letters >= 12
}

func audit(fileURL: URL, originalStatus: String) -> AuditRow {
    guard let pdf = PDFDocument(url: fileURL), let cgPDF = CGPDFDocument(fileURL as CFURL) else {
        return AuditRow(
            arquivo: fileURL.lastPathComponent,
            statusOriginal: originalStatus,
            statusAuditoria: "falha_leitura_pdf",
            paginas: 0,
            paginasComTextoPesquisavel: 0,
            paginasSemTextoVisual: [],
            paginasSomenteImagem: [],
            paginasComTextoVisualSemOCR: [],
            paginasNaoRenderizadas: [],
            observacao: "Nao foi possivel abrir o PDF para auditoria."
        )
    }

    var searchablePages = 0
    var blankPages: [Int] = []
    var imageOnlyPages: [Int] = []
    var visualTextWithoutOCRPages: [Int] = []
    var renderFailures: [Int] = []

    for pageIndex in 0..<pdf.pageCount {
        let pageNumber = pageIndex + 1
        let text = normalizedText(pdf.page(at: pageIndex)?.string)
        if text.count >= 20 {
            searchablePages += 1
            continue
        }

        guard let cgPage = cgPDF.page(at: pageNumber), let image = renderPage(cgPage) else {
            renderFailures.append(pageNumber)
            continue
        }

        if pageLooksBlank(image) {
            blankPages.append(pageNumber)
        } else if imageHasRecognizableText(image) {
            visualTextWithoutOCRPages.append(pageNumber)
        } else {
            imageOnlyPages.append(pageNumber)
        }
    }

    let status: String
    let observation: String
    if renderFailures.isEmpty == false {
        status = "revisar_renderizacao"
        observation = "Algumas paginas nao puderam ser renderizadas para auditoria."
    } else if visualTextWithoutOCRPages.isEmpty {
        status = "pronto_auditado"
        observation = "Todas as paginas com texto possuem camada pesquisavel; paginas brancas ou somente imagem foram preservadas."
    } else {
        status = "reprocessar"
        observation = "Ha paginas com texto visual sem camada pesquisavel; reprocessar antes da importacao fiel."
    }

    return AuditRow(
        arquivo: fileURL.lastPathComponent,
        statusOriginal: originalStatus,
        statusAuditoria: status,
        paginas: pdf.pageCount,
        paginasComTextoPesquisavel: searchablePages,
        paginasSemTextoVisual: blankPages,
        paginasSomenteImagem: imageOnlyPages,
        paginasComTextoVisualSemOCR: visualTextWithoutOCRPages,
        paginasNaoRenderizadas: renderFailures,
        observacao: observation
    )
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDir = root.appendingPathComponent("ImportacaoLivrosPDF_OCR")
let reportDir = outputDir.appendingPathComponent("_relatorios")
let sourceReportURL = reportDir.appendingPathComponent("relatorio_ocr_seguro.json")
let data = try Data(contentsOf: sourceReportURL)
let sourceRows = try JSONDecoder().decode([SourceReportRow].self, from: data)

var auditRows: [AuditRow] = []
let total = sourceRows.count
for (index, sourceRow) in sourceRows.enumerated() {
    let fileURL = outputDir.appendingPathComponent(sourceRow.arquivo)
    log("[\(index + 1)/\(total)] auditando: \(sourceRow.arquivo)")
    let row = audit(fileURL: fileURL, originalStatus: sourceRow.status)
    auditRows.append(row)
    log("  -> \(row.statusAuditoria): texto \(row.paginasComTextoPesquisavel)/\(row.paginas), brancas \(row.paginasSemTextoVisual.count), imagens \(row.paginasSomenteImagem.count), texto sem OCR \(row.paginasComTextoVisualSemOCR.count)")
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(auditRows).write(to: reportDir.appendingPathComponent("auditoria_ocr_externo.json"), options: .atomic)

var csv = "arquivo,statusOriginal,statusAuditoria,paginas,paginasComTextoPesquisavel,paginasSemTextoVisual,paginasSomenteImagem,paginasComTextoVisualSemOCR,paginasNaoRenderizadas,observacao\n"
for row in auditRows {
    csv += [
        csvEscape(row.arquivo),
        row.statusOriginal,
        row.statusAuditoria,
        String(row.paginas),
        String(row.paginasComTextoPesquisavel),
        csvEscape(row.paginasSemTextoVisual.map(String.init).joined(separator: " ")),
        csvEscape(row.paginasSomenteImagem.map(String.init).joined(separator: " ")),
        csvEscape(row.paginasComTextoVisualSemOCR.map(String.init).joined(separator: " ")),
        csvEscape(row.paginasNaoRenderizadas.map(String.init).joined(separator: " ")),
        csvEscape(row.observacao)
    ].joined(separator: ",") + "\n"
}
try csv.write(to: reportDir.appendingPathComponent("auditoria_ocr_externo.csv"), atomically: true, encoding: .utf8)

let summary = Dictionary(grouping: auditRows, by: { $0.statusAuditoria }).mapValues { $0.count }
let summaryData = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
try summaryData.write(to: reportDir.appendingPathComponent("resumo_auditoria_ocr_externo.json"))
log(String(data: summaryData, encoding: .utf8) ?? "{}")
