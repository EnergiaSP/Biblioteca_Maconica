import Foundation
import PDFKit
import Vision

@main
struct AuditImport {

    static func main() throws {
        let caminhoPDF = CommandLine.arguments.dropFirst().first ?? "Breviario maconico OCR.pdf"
        let url = URL(fileURLWithPath: caminhoPDF)

        guard let pdf = PDFDocument(url: url) else {
            print("ERRO: nao foi possivel abrir o PDF em \(caminhoPDF)")
            exit(1)
        }

        var textoOCR = ""
        var paginasSemTexto: [Int] = []
        var caracteresPorPagina: [(pagina: Int, caracteres: Int)] = []

        for indice in 0..<pdf.pageCount {
            let paginaNumero = indice + 1
            let pagina = pdf.page(at: indice)
            var textoPagina = ""
            let textoPDFKit = pagina?.string ?? ""

            if paginaNumero <= 367,
               let cgPDF = CGPDFDocument(url as CFURL),
               let cgPage = cgPDF.page(at: paginaNumero) {
                textoPagina = try reconhecerTextoOCR(cgPage: cgPage)
            }

            if textoPDFKit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                paginasSemTexto.append(paginaNumero)
            }

            if textoPagina.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                textoPagina = textoPDFKit
            }

            caracteresPorPagina.append((
                paginaNumero,
                textoPagina.trimmingCharacters(in: .whitespacesAndNewlines).count
            ))
            textoOCR += "\n--- PAGINA \(paginaNumero) ---\n"
            textoOCR += textoPagina
            textoOCR += "\n"
        }

        let dados = BreviarioImportService.importar(textoOCR: textoOCR)
        let datas = dados.itens.map(\.data)
        let datasValidas = datas.filter { $0 != "00/00" }
        let datasDuplicadas = Dictionary(grouping: datasValidas, by: { $0 })
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        let itensSemTexto = dados.itens.filter {
            $0.texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let itensComRodape = dados.itens.filter {
            ($0.rodape ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
        let itensComPagina = dados.itens.filter { $0.pagina != nil }
        let entradasIndiceComLink = dados.indiceRemissivo.filter { $0.datas.isEmpty == false }
        let datasEsperadas = Set((1...12).flatMap { mes in
            (1...31).map { dia in
                String(format: "%02d/%02d", dia, mes)
            }
        })
        let datasAusentes = datasEsperadas
            .subtracting(Set(datasValidas))
            .sorted()
        let possiveisQuebras = dados.itens.filter { item in
            item.texto.contains("-\n") || item.texto.contains("\n") && item.texto.contains(".\n")
        }

        print("PDF: \(url.lastPathComponent)")
        print("Paginas do PDF: \(pdf.pageCount)")
        print("Paginas sem texto selecionavel: \(paginasSemTexto.count)")
        if paginasSemTexto.isEmpty == false {
            print("Paginas sem texto selecionavel (primeiras 20): \(paginasSemTexto.prefix(20).map(String.init).joined(separator: ", "))")
        }
        print("Caracteres extraidos: \(textoOCR.count)")
        print("Itens importados: \(dados.itens.count)")
        print("Datas validas importadas: \(Set(datasValidas).count)")
        print("Datas duplicadas: \(datasDuplicadas.count)")
        if datasDuplicadas.isEmpty == false {
            print("Datas duplicadas (primeiras 30): \(datasDuplicadas.prefix(30).joined(separator: ", "))")
        }
        print("Itens com pagina vinculada: \(itensComPagina.count)")
        print("Itens sem texto: \(itensSemTexto.count)")
        print("Itens com rodape: \(itensComRodape.count)")
        print("Entradas do indice: \(dados.indiceRemissivo.count)")
        print("Entradas do indice com link para data: \(entradasIndiceComLink.count)")
        print("Datas ausentes dentro de calendario bruto 31x12: \(datasAusentes.count)")
        print("Possiveis quebras residuais de paragrafo: \(possiveisQuebras.count)")

        print("\nAmostra dos 5 primeiros itens:")
        for item in dados.itens.prefix(5) {
            let amostra = item.texto
                .replacingOccurrences(of: "\n", with: " / ")
                .prefix(280)
            print("- \(item.data) p.\(item.pagina.map(String.init) ?? "?") \(item.titulo): \(amostra)")
        }

        print("\nAmostra de indice:")
        for entrada in dados.indiceRemissivo.prefix(10) {
            let datas = entrada.datas.isEmpty ? "sem link" : entrada.datas.joined(separator: ", ")
            print("- \(entrada.termo) | pags. \(entrada.paginasFormatadas) | \(datas)")
        }

        let saida = URL(fileURLWithPath: "DerivedData/import-audit-output.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let dadosJSON = try encoder.encode(dados)
        try FileManager.default.createDirectory(
            at: saida.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try dadosJSON.write(to: saida, options: .atomic)
        print("\nJSON de auditoria: \(saida.path)")
    }

    private static func reconhecerTextoOCR(cgPage: CGPDFPage) throws -> String {
        let bounds = cgPage.getBoxRect(.mediaBox)
        let escala: CGFloat = 3
        let largura = Int(bounds.width * escala)
        let altura = Int(bounds.height * escala)

        guard let contexto = CGContext(
            data: nil,
            width: largura,
            height: altura,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return ""
        }

        contexto.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        contexto.fill(CGRect(x: 0, y: 0, width: largura, height: altura))
        contexto.saveGState()
        contexto.scaleBy(x: escala, y: escala)
        contexto.drawPDFPage(cgPage)
        contexto.restoreGState()

        guard let cgImage = contexto.makeImage() else {
            return ""
        }

        var observacoesReconhecidas: [VNRecognizedTextObservation] = []
        let request = VNRecognizeTextRequest { request, _ in
            let resultados = request.results as? [VNRecognizedTextObservation] ?? []
            observacoesReconhecidas = resultados
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.01

        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        return textoReconhecido(
            observacoes: observacoesReconhecidas,
            linhaRodape: detectarLinhaRodape(cgImage: cgImage)
        )
    }

    private static func textoReconhecido(
        observacoes: [VNRecognizedTextObservation],
        linhaRodape: CGFloat?
    ) -> String {
        let linhas = observacoes
            .compactMap { observacao -> (texto: String, frame: CGRect)? in
                guard let texto = observacao.topCandidates(1).first?.string else {
                    return nil
                }

                return (texto, observacao.boundingBox)
            }
            .sorted { primeira, segunda in
                if abs(primeira.frame.midY - segunda.frame.midY) > 0.01 {
                    return primeira.frame.midY > segunda.frame.midY
                }

                return primeira.frame.minX < segunda.frame.minX
            }

        guard let linhaRodape else {
            return linhas.map(\.texto).joined(separator: "\n")
        }

        let corpo = linhas.filter { $0.frame.maxY >= linhaRodape }
        let rodape = linhas.filter { $0.frame.maxY < linhaRodape }

        guard corpo.isEmpty == false, rodape.isEmpty == false else {
            return linhas.map(\.texto).joined(separator: "\n")
        }

        return (
            corpo.map(\.texto)
            + [marcadorRodapePorLayout]
            + rodape.map(\.texto)
        ).joined(separator: "\n")
    }

    private static func detectarLinhaRodape(cgImage: CGImage) -> CGFloat? {
        let largura = cgImage.width
        let altura = cgImage.height
        let bytesPorPixel = 4
        let bytesPorLinha = largura * bytesPorPixel
        var pixels = [UInt8](repeating: 255, count: altura * bytesPorLinha)

        guard let contexto = CGContext(
            data: &pixels,
            width: largura,
            height: altura,
            bitsPerComponent: 8,
            bytesPerRow: bytesPorLinha,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        contexto.draw(cgImage, in: CGRect(x: 0, y: 0, width: largura, height: altura))

        let inicio = Int(Double(altura) * 0.45)
        let fim = Int(Double(altura) * 0.94)
        let minimoSequenciaEscura = Int(Double(largura) * 0.42)
        var melhorLinha: Int?

        for y in inicio..<fim {
            var sequenciaAtual = 0
            var maiorSequencia = 0

            for x in 0..<largura {
                let indice = y * bytesPorLinha + x * bytesPorPixel
                let vermelho = Int(pixels[indice])
                let verde = Int(pixels[indice + 1])
                let azul = Int(pixels[indice + 2])
                let escuro = vermelho + verde + azul < 210

                if escuro {
                    sequenciaAtual += 1
                    maiorSequencia = max(maiorSequencia, sequenciaAtual)
                } else {
                    sequenciaAtual = 0
                }
            }

            if maiorSequencia >= minimoSequenciaEscura {
                melhorLinha = y
            }
        }

        guard let melhorLinha else {
            return nil
        }

        return 1 - (CGFloat(melhorLinha) / CGFloat(altura))
    }

    private static let marcadorRodapePorLayout = "<<<RODAPE_POR_LINHA_DO_PDF>>>"
}
