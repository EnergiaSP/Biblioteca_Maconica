import AppKit
import CoreGraphics
import CoreText
import Darwin
import Foundation
import PDFKit
import Vision

struct Config {
    var inputDir = "ImportacaoLivrosPDF"
    var outputDir = "ImportacaoLivrosPDF_OCR"
    var filePath: String?
    var limit: Int?
    var force = false
    var maxImageSide: CGFloat = 1200
    var preserveSearchablePDFs = true
}

struct ReportRow: Codable {
    let arquivo: String
    let status: String
    let paginas: Int
    let paginasOCR: Int
    let paginasSemTextoVisual: Int
    let paginasSomenteImagem: Int
    let palavrasReconhecidas: Int
    let tamanhoOrigemMB: Double
    let tamanhoOCRMB: Double
    let observacao: String
}

func parseArgs() -> Config {
    var config = Config()
    var args = Array(CommandLine.arguments.dropFirst())
    while args.isEmpty == false {
        let arg = args.removeFirst()
        switch arg {
        case "--input":
            if let value = args.first {
                config.inputDir = value
                args.removeFirst()
            }
        case "--output":
            if let value = args.first {
                config.outputDir = value
                args.removeFirst()
            }
        case "--file":
            if let value = args.first {
                config.filePath = value
                args.removeFirst()
            }
        case "--limit":
            if let value = args.first {
                config.limit = Int(value)
                args.removeFirst()
            }
        case "--force":
            config.force = true
        case "--ocr-all":
            config.preserveSearchablePDFs = false
        case "--max-image-side":
            if let value = args.first, let parsed = Double(value) {
                config.maxImageSide = CGFloat(parsed)
                args.removeFirst()
            }
        default:
            break
        }
    }
    return config
}

func roundedMB(_ bytes: UInt64) -> Double {
    ((Double(bytes) / 1024.0 / 1024.0) * 100).rounded() / 100
}

func fileSizeMB(_ url: URL) -> Double {
    let values = try? url.resourceValues(forKeys: [.fileSizeKey])
    return roundedMB(UInt64(values?.fileSize ?? 0))
}

func log(_ message: String) {
    print(message)
    fflush(stdout)
}

func renderPage(_ page: CGPDFPage, maxSide: CGFloat) -> CGImage? {
    let box = page.getBoxRect(.mediaBox)
    guard box.width > 0, box.height > 0 else { return nil }
    let scale = min(maxSide / max(box.width, box.height), 3.0)
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
        let red = pixels[index]
        let green = pixels[index + 1]
        let blue = pixels[index + 2]
        if red < 245 || green < 245 || blue < 245 {
            nonWhitePixels += 1
        }
    }

    let nonWhiteRatio = Double(nonWhitePixels) / Double(width * height)
    return nonWhiteRatio < 0.0025
}

func searchableTextStats(_ url: URL) -> (pages: Int, pagesWithText: Int, chars: Int)? {
    guard let document = PDFDocument(url: url) else { return nil }
    let pages = document.pageCount
    var pagesWithText = 0
    var chars = 0

    for index in 0..<pages {
        guard let page = document.page(at: index) else { continue }
        let text = page.string?.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.count >= 20 {
            pagesWithText += 1
        }
        chars += text.count
    }

    return (pages, pagesWithText, chars)
}

func blankPagesWithoutSearchableText(_ url: URL) -> (blankPages: [Int], nonBlankPages: [Int]) {
    guard let document = PDFDocument(url: url), let source = CGPDFDocument(url as CFURL) else {
        return ([], [])
    }

    var blankPages: [Int] = []
    var nonBlankPages: [Int] = []

    for index in 0..<document.pageCount {
        let text = document.page(at: index)?.string?
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard text.count < 20 else { continue }

        let pageNumber = index + 1
        if let page = source.page(at: pageNumber),
           let image = renderPage(page, maxSide: 900),
           pageLooksBlank(image) {
            blankPages.append(pageNumber)
        } else {
            nonBlankPages.append(pageNumber)
        }
    }

    return (blankPages, nonBlankPages)
}

func hasReliableSearchableText(_ url: URL) -> Bool {
    guard let stats = searchableTextStats(url), stats.pages > 0 else { return false }
    let pageCoverage = Double(stats.pagesWithText) / Double(stats.pages)
    let minimumChars = max(300, stats.pages * 60)
    return pageCoverage >= 0.80 && stats.chars >= minimumChars
}

func recognizeText(in image: CGImage) throws -> [VNRecognizedTextObservation] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    let preferredLanguages = ["pt-BR", "en-US", "es-ES", "fr-FR"]
    let supportedLanguages = (try? request.supportedRecognitionLanguages()) ?? preferredLanguages
    request.recognitionLanguages = preferredLanguages.filter { supportedLanguages.contains($0) }
    request.customWords = [
        "Maçonaria", "Maçônico", "Maçônica", "maçom", "maçons", "Loja", "Oriente",
        "Aprendiz", "Companheiro", "Mestre", "Rito", "Escocês", "Simbologia",
        "Ritualística", "Acácia", "Esquadro", "Compasso"
    ]

    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try handler.perform([request])
    return request.results ?? []
}

func drawOriginalPage(_ page: CGPDFPage, in context: CGContext) {
    let box = page.getBoxRect(.mediaBox)
    context.saveGState()
    let transform = page.getDrawingTransform(.mediaBox, rect: box, rotate: 0, preserveAspectRatio: true)
    context.concatenate(transform)
    context.drawPDFPage(page)
    context.restoreGState()
}

func pdfPageInfo(for box: CGRect) -> CFDictionary {
    var mediaBox = box
    let mediaBoxData = Data(bytes: &mediaBox, count: MemoryLayout<CGRect>.size) as CFData
    return [kCGPDFContextMediaBox as String: mediaBoxData] as CFDictionary
}

func drawInvisibleText(_ observations: [VNRecognizedTextObservation], pageSize: CGSize, in context: CGContext) -> Int {
    var words = 0
    context.saveGState()
    context.setFillColor(NSColor.black.withAlphaComponent(0.01).cgColor)

    for observation in observations {
        guard let candidate = observation.topCandidates(1).first else { continue }
        let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { continue }

        words += text.split { $0.isWhitespace || $0.isNewline }.count
        let box = observation.boundingBox
        let rect = CGRect(
            x: box.minX * pageSize.width,
            y: box.minY * pageSize.height,
            width: max(2, box.width * pageSize.width),
            height: max(2, box.height * pageSize.height)
        )
        let fontSize = max(4, min(18, rect.height * 0.70))
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            kCTFontAttributeName as NSAttributedString.Key: font,
            kCTForegroundColorAttributeName as NSAttributedString.Key: NSColor.black.withAlphaComponent(0.01).cgColor
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: rect.minX, y: rect.midY - fontSize * 0.35)
        CTLineDraw(line, context)
    }

    context.restoreGState()
    return words
}

func convertPDF(input: URL, output: URL, config: Config) -> ReportRow {
    let sourceSize = fileSizeMB(input)

    if config.preserveSearchablePDFs, hasReliableSearchableText(input) {
        do {
            if FileManager.default.fileExists(atPath: output.path) {
                try FileManager.default.removeItem(at: output)
            }
            try FileManager.default.copyItem(at: input, to: output)
            let stats = searchableTextStats(input)
            let visualTextGaps = blankPagesWithoutSearchableText(input)
            let status = visualTextGaps.nonBlankPages.isEmpty ? "ja_possui_ocr_preservado" : "ocr_parcial"
            let observation: String
            if visualTextGaps.nonBlankPages.isEmpty {
                if visualTextGaps.blankPages.isEmpty {
                    observation = "Arquivo ja possui texto pesquisavel. Copiado sem recompressao para manter menor tamanho e qualidade original."
                } else {
                    observation = "Arquivo ja possui texto pesquisavel. Copiado sem recompressao para manter menor tamanho e qualidade original. Paginas em branco/sem texto visual preservadas sem OCR: \(visualTextGaps.blankPages.map(String.init).joined(separator: ", "))."
                }
            } else {
                let blankText = visualTextGaps.blankPages.isEmpty ? "" : " Paginas em branco/sem texto visual preservadas: \(visualTextGaps.blankPages.map(String.init).joined(separator: ", "))."
                observation = "Arquivo ja possui texto pesquisavel, mas algumas paginas com conteudo visual nao possuem texto pesquisavel: \(visualTextGaps.nonBlankPages.map(String.init).joined(separator: ", ")).\(blankText) Revisar antes da importacao final."
            }
            return ReportRow(
                arquivo: input.lastPathComponent,
                status: status,
                paginas: stats?.pages ?? 0,
                paginasOCR: stats?.pagesWithText ?? 0,
                paginasSemTextoVisual: visualTextGaps.blankPages.count,
                paginasSomenteImagem: visualTextGaps.nonBlankPages.count,
                palavrasReconhecidas: 0,
                tamanhoOrigemMB: sourceSize,
                tamanhoOCRMB: fileSizeMB(output),
                observacao: observation
            )
        } catch {
            return ReportRow(
                arquivo: input.lastPathComponent,
                status: "falha",
                paginas: 0,
                paginasOCR: 0,
                paginasSemTextoVisual: 0,
                paginasSomenteImagem: 0,
                palavrasReconhecidas: 0,
                tamanhoOrigemMB: sourceSize,
                tamanhoOCRMB: 0,
                observacao: "Falha ao copiar PDF ja pesquisavel: \(error.localizedDescription)"
            )
        }
    }

    guard let source = CGPDFDocument(input as CFURL) else {
        return ReportRow(
            arquivo: input.lastPathComponent,
            status: "falha",
            paginas: 0,
            paginasOCR: 0,
            paginasSemTextoVisual: 0,
            paginasSomenteImagem: 0,
            palavrasReconhecidas: 0,
            tamanhoOrigemMB: sourceSize,
            tamanhoOCRMB: 0,
            observacao: "Nao foi possivel abrir o PDF original."
        )
    }

    let pageCount = source.numberOfPages
    guard let consumer = CGDataConsumer(url: output as CFURL) else {
        return ReportRow(
            arquivo: input.lastPathComponent,
            status: "falha",
            paginas: pageCount,
            paginasOCR: 0,
            paginasSemTextoVisual: 0,
            paginasSomenteImagem: 0,
            palavrasReconhecidas: 0,
            tamanhoOrigemMB: sourceSize,
            tamanhoOCRMB: 0,
            observacao: "Nao foi possivel criar o arquivo de saida."
        )
    }

    var mediaBox = source.page(at: 1)?.getBoxRect(.mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        return ReportRow(
            arquivo: input.lastPathComponent,
            status: "falha",
            paginas: pageCount,
            paginasOCR: 0,
            paginasSemTextoVisual: 0,
            paginasSomenteImagem: 0,
            palavrasReconhecidas: 0,
            tamanhoOrigemMB: sourceSize,
            tamanhoOCRMB: 0,
            observacao: "Nao foi possivel iniciar o PDF OCR."
        )
    }

    var ocrPages = 0
    var wordCount = 0
    var blankPages: [Int] = []
    var visualOnlyPages: [Int] = []
    var missingPages: [Int] = []

    for pageIndex in 1...pageCount {
        autoreleasepool {
            guard let page = source.page(at: pageIndex) else { return }
            let box = page.getBoxRect(.mediaBox)
            pdfContext.beginPDFPage(pdfPageInfo(for: box))
            drawOriginalPage(page, in: pdfContext)

            if let image = renderPage(page, maxSide: config.maxImageSide) {
                if let observations = try? recognizeText(in: image), observations.isEmpty == false {
                    ocrPages += 1
                    wordCount += drawInvisibleText(observations, pageSize: box.size, in: pdfContext)
                    log("pagina \(pageIndex)/\(pageCount): OCR reconhecido | paginas OCR \(ocrPages) | paginas sem texto \(blankPages.count) | faltam \(pageCount - pageIndex)")
                } else if pageLooksBlank(image) {
                    blankPages.append(pageIndex)
                    log("pagina \(pageIndex)/\(pageCount): pagina em branco/sem texto visual | paginas OCR \(ocrPages) | paginas sem texto \(blankPages.count) | faltam \(pageCount - pageIndex)")
                } else {
                    visualOnlyPages.append(pageIndex)
                    log("pagina \(pageIndex)/\(pageCount): pagina visual/ilustracao sem texto detectavel | paginas OCR \(ocrPages) | paginas sem texto \(blankPages.count) | paginas somente imagem \(visualOnlyPages.count) | faltam \(pageCount - pageIndex)")
                }
            } else {
                missingPages.append(pageIndex)
                log("pagina \(pageIndex)/\(pageCount): pagina nao renderizada para OCR | paginas OCR \(ocrPages) | paginas sem texto \(blankPages.count) | faltam \(pageCount - pageIndex)")
            }

            pdfContext.endPDFPage()
        }
    }

    pdfContext.closePDF()
    let outputSize = fileSizeMB(output)
    let status = missingPages.isEmpty ? "ocr_concluido" : (ocrPages > 0 ? "ocr_parcial" : "sem_texto_reconhecido")
    let observation: String
    if status == "ocr_concluido" {
        if blankPages.isEmpty {
            if visualOnlyPages.isEmpty {
                observation = "PDF convertido mantendo a pagina original, sem rasterizar o arquivo final, e adicionando camada de texto pesquisavel."
            } else {
                observation = "PDF convertido mantendo a pagina original, sem rasterizar o arquivo final, e adicionando camada de texto pesquisavel. Paginas somente imagem/sem texto detectavel preservadas: \(visualOnlyPages.map(String.init).joined(separator: ", "))."
            }
        } else {
            let blankPageList = blankPages.map(String.init).joined(separator: ", ")
            let visualText = visualOnlyPages.isEmpty ? "" : " Paginas somente imagem/sem texto detectavel preservadas: \(visualOnlyPages.map(String.init).joined(separator: ", "))."
            observation = "PDF convertido mantendo a pagina original, sem rasterizar o arquivo final, e adicionando camada de texto pesquisavel. Paginas em branco/sem texto visual preservadas sem OCR: \(blankPageList).\(visualText)"
        }
    } else if status == "ocr_parcial" {
        let missingPageList = missingPages.map(String.init).joined(separator: ", ")
        let blankText = blankPages.isEmpty ? "" : " Paginas em branco/sem texto visual preservadas: \(blankPages.map(String.init).joined(separator: ", "))."
        observation = "Algumas paginas com conteudo visual nao tiveram texto reconhecido: \(missingPageList).\(blankText) Revisar antes da importacao final."
    } else {
        observation = "Nao houve texto reconhecido; revisar qualidade do PDF original."
    }

    return ReportRow(
        arquivo: input.lastPathComponent,
        status: status,
        paginas: pageCount,
        paginasOCR: ocrPages,
        paginasSemTextoVisual: blankPages.count,
        paginasSomenteImagem: visualOnlyPages.count,
        palavrasReconhecidas: wordCount,
        tamanhoOrigemMB: sourceSize,
        tamanhoOCRMB: outputSize,
        observacao: observation
    )
}

func csvEscape(_ value: String) -> String {
    "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
}

let config = parseArgs()
let fm = FileManager.default
let inputDir = URL(fileURLWithPath: config.inputDir)
let outputDir = URL(fileURLWithPath: config.outputDir)
let reportDir = outputDir.appendingPathComponent("_relatorios")
try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)
try fm.createDirectory(at: reportDir, withIntermediateDirectories: true)

var pdfs = (try fm.contentsOfDirectory(at: inputDir, includingPropertiesForKeys: nil))
    .filter { $0.pathExtension.lowercased() == "pdf" }
    .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
if let filePath = config.filePath {
    pdfs = [URL(fileURLWithPath: filePath)]
}
if let limit = config.limit {
    pdfs = Array(pdfs.prefix(limit))
}

var report: [ReportRow] = []
for (index, input) in pdfs.enumerated() {
    let output = outputDir.appendingPathComponent(input.lastPathComponent)
    if fm.fileExists(atPath: output.path), config.force == false {
        report.append(ReportRow(
            arquivo: input.lastPathComponent,
            status: "ja_existia",
            paginas: 0,
            paginasOCR: 0,
            paginasSemTextoVisual: 0,
            paginasSomenteImagem: 0,
            palavrasReconhecidas: 0,
            tamanhoOrigemMB: fileSizeMB(input),
            tamanhoOCRMB: fileSizeMB(output),
            observacao: "Arquivo OCR ja existe na pasta de saida."
        ))
        log("[\(index + 1)/\(pdfs.count)] ja existia: \(input.lastPathComponent)")
        continue
    }

    log("[\(index + 1)/\(pdfs.count)] OCR: \(input.lastPathComponent)")
    let row = convertPDF(input: input, output: output, config: config)
    report.append(row)
    log("  -> \(row.status), paginas OCR \(row.paginasOCR)/\(row.paginas), paginas sem texto \(row.paginasSemTextoVisual), paginas somente imagem \(row.paginasSomenteImagem), palavras \(row.palavrasReconhecidas)")
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(report).write(to: reportDir.appendingPathComponent("relatorio_ocr_conversao.json"))

var csv = "arquivo,status,paginas,paginasOCR,paginasSemTextoVisual,paginasSomenteImagem,palavrasReconhecidas,tamanhoOrigemMB,tamanhoOCRMB,observacao\n"
for row in report {
    csv += [
        csvEscape(row.arquivo),
        row.status,
        String(row.paginas),
        String(row.paginasOCR),
        String(row.paginasSemTextoVisual),
        String(row.paginasSomenteImagem),
        String(row.palavrasReconhecidas),
        String(format: "%.2f", row.tamanhoOrigemMB),
        String(format: "%.2f", row.tamanhoOCRMB),
        csvEscape(row.observacao)
    ].joined(separator: ",") + "\n"
}
try csv.write(to: reportDir.appendingPathComponent("relatorio_ocr_conversao.csv"), atomically: true, encoding: .utf8)

let resumo = Dictionary(grouping: report, by: { $0.status }).mapValues { $0.count }
let resumoData = try JSONSerialization.data(withJSONObject: resumo, options: [.prettyPrinted, .sortedKeys])
try resumoData.write(to: reportDir.appendingPathComponent("resumo_ocr_conversao.json"))
log(String(data: resumoData, encoding: .utf8) ?? "{}")
