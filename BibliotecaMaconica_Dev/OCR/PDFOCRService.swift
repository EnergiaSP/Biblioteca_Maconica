import PDFKit
import UIKit
import Vision

class PDFOCRService {
    enum ModoExtracao {
        case breviarioDiario
        case obraGenerica
    }

    static func extrairTexto(
        url: URL,
        modo: ModoExtracao = .breviarioDiario
    ) throws -> String {

        guard let pdf = PDFDocument(url: url), !pdf.isLocked, pdf.pageCount > 0
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var textoCompleto = ""

        for i in 0..<pdf.pageCount {
            try Task.checkCancellation()

            guard let pagina = pdf.page(at: i)
            else {
                throw CocoaError(.fileReadCorruptFile)
            }

            let textoDaPagina = pagina.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            textoCompleto += "\n--- PAGINA \(i + 1) ---\n"

            let deveUsarOCR: Bool = {
                switch modo {
                case .breviarioDiario:
                    return i < 367
                case .obraGenerica:
                    return textoDaPagina.isEmpty
                }
            }()

            if deveUsarOCR == false {
                textoCompleto += textoDaPagina
            } else {
                let textoOCR = try reconhecerTextoOCR(pagina: pagina)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                textoCompleto += textoOCR.isEmpty ? textoDaPagina : textoOCR
            }

            textoCompleto += "\n"
        }

        return textoCompleto
    }

    static func renderizarPaginas(
        url: URL,
        obraID: String,
        larguraMaxima: CGFloat = 1800,
        qualidade: CGFloat = 0.88
    ) throws -> [Int: PaginaMidia] {
        guard let pdf = PDFDocument(url: url), !pdf.isLocked, pdf.pageCount > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let destino = try diretorioMidia(obraID: obraID)
        var concluido = false
        defer { if !concluido { try? FileManager.default.removeItem(at: destino.diretorio) } }
        try FileManager.default.copyItem(at: url, to: destino.diretorio.appendingPathComponent("original.pdf"))
        var paginas: [Int: PaginaMidia] = [:]

        for indice in 0..<pdf.pageCount {
            try Task.checkCancellation()
            try autoreleasepool {
                guard let pagina = pdf.page(at: indice) else {
                    throw CocoaError(.fileReadCorruptFile)
                }

                let numeroPagina = indice + 1
                let imagem = try renderizarPagina(pagina, larguraMaxima: larguraMaxima)
                let tamanho = imagem.size

                let dados: Data?
                if qualidade >= 1.0 {
                    dados = imagem.pngData()
                } else {
                    dados = imagem.jpegData(compressionQuality: qualidade)
                }

                guard let dados else {
                    throw CocoaError(.fileWriteUnknown)
                }

                let extensao = qualidade >= 1.0 ? "png" : "jpg"
                let nomeArquivo = String(format: "pagina-%04d.%@", numeroPagina, extensao)
                let arquivo = destino.diretorio.appendingPathComponent(nomeArquivo)

                try dados.write(to: arquivo, options: .atomic)
                paginas[numeroPagina] = PaginaMidia(
                        pagina: numeroPagina,
                        caminhoRelativo: "\(destino.caminhoRelativo)/\(nomeArquivo)",
                        largura: Double(tamanho.width),
                        altura: Double(tamanho.height),
                        tipo: qualidade >= 1.0 ? "facsimile-png" : "facsimile-jpeg-otimizado"
                )
            }
        }

        guard paginas.count == pdf.pageCount else { throw CocoaError(.fileWriteUnknown) }
        concluido = true
        return paginas
    }

    private static func renderizarPagina(_ pagina: PDFPage, larguraMaxima: CGFloat = .greatestFiniteMagnitude) throws -> UIImage {
        guard let paginaCG = pagina.pageRef else { throw CocoaError(.fileReadCorruptFile) }
        let bounds = paginaCG.getBoxRect(.mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let rotacionada = abs(paginaCG.rotationAngle) % 180 == 90
        let largura = rotacionada ? bounds.height : bounds.width
        let altura = rotacionada ? bounds.width : bounds.height
        let escala = min(max(1, larguraMaxima) / largura, CGFloat(2), sqrt(6_000_000 / (largura * altura)))
        let tamanho = CGSize(width: largura * escala, height: altura * escala)

        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        let renderer = UIGraphicsImageRenderer(size: tamanho, format: formato)
        return renderer.image { contexto in
            UIColor.white.set()
            contexto.fill(CGRect(origin: .zero, size: tamanho))
            contexto.cgContext.saveGState()
            // PDF coordinates point upward; the page transform also includes its rotation and origin.
            contexto.cgContext.translateBy(x: 0, y: tamanho.height)
            contexto.cgContext.scaleBy(x: escala, y: -escala)
            contexto.cgContext.concatenate(paginaCG.getDrawingTransform(.mediaBox, rect: CGRect(x: 0, y: 0, width: largura, height: altura), rotate: 0, preserveAspectRatio: true))
            contexto.cgContext.drawPDFPage(paginaCG)
            contexto.cgContext.restoreGState()
        }

    }

    private static func reconhecerTextoOCR(pagina: PDFPage) throws -> String {
        let imagem = try renderizarPagina(pagina)
        guard let cgImage = imagem.cgImage else { throw CocoaError(.fileReadCorruptFile) }

        var observacoesReconhecidas: [VNRecognizedTextObservation] = []
        let request = VNRecognizeTextRequest { request, _ in
            guard let observacoes = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            observacoesReconhecidas = observacoes
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.01

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

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

    static let marcadorRodapePorLayout = "<<<RODAPE_POR_LINHA_DO_PDF>>>"

    private static func diretorioMidia(obraID: String) throws -> (
        diretorio: URL,
        caminhoRelativo: String
    ) {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let caminhoRelativo = "BreviarioMaconicoXXI/Midia/\(nomeSeguroArquivo(obraID))/\(UUID().uuidString)"
        let diretorio = base.appendingPathComponent(caminhoRelativo, isDirectory: true)

        try FileManager.default.createDirectory(
            at: diretorio,
            withIntermediateDirectories: true
        )

        return (diretorio, caminhoRelativo)
    }

    private static func nomeSeguroArquivo(_ texto: String) -> String {
        let permitidos = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(
            texto.unicodeScalars.map { permitidos.contains($0) ? Character($0) : "-" }
        )
    }
}
