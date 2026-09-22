import CoreGraphics
import Foundation
import PDFKit
import Vision

@main
struct OCRPageSample {

    static func main() throws {
        let caminhoPDF = CommandLine.arguments.dropFirst().first ?? "Breviario maconico OCR.pdf"
        let paginaIndice = Int(CommandLine.arguments.dropFirst(2).first ?? "1") ?? 1
        let url = URL(fileURLWithPath: caminhoPDF)

        guard let pdf = PDFDocument(url: url),
              let pagina = pdf.page(at: max(0, paginaIndice - 1)),
              let cgPDF = CGPDFDocument(url as CFURL),
              let cgPage = cgPDF.page(at: paginaIndice) else {
            print("ERRO: nao foi possivel abrir pagina")
            exit(1)
        }

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
            print("ERRO: imagem invalida")
            exit(1)
        }

        contexto.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        contexto.fill(CGRect(x: 0, y: 0, width: largura, height: altura))
        contexto.saveGState()
        contexto.scaleBy(x: escala, y: escala)
        contexto.drawPDFPage(cgPage)
        contexto.restoreGState()

        guard let cgImage = contexto.makeImage() else {
            print("ERRO: cgImage invalida")
            exit(1)
        }

        var linhas: [String] = []
        var candidatosPrimeiraLinha: [String] = []
        let request = VNRecognizeTextRequest { request, _ in
            let resultados = request.results as? [VNRecognizedTextObservation] ?? []
            linhas = resultados.compactMap { $0.topCandidates(1).first?.string }
            candidatosPrimeiraLinha = resultados.first?.topCandidates(10).map {
                "\($0.string) [\($0.confidence)]"
            } ?? []
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.01

        do {
            try VNImageRequestHandler(cgImage: cgImage).perform([request])
        } catch {
            print("ERRO Vision: \(error)")
            exit(1)
        }

        print("PDFKit:")
        print(pagina.string?.prefix(800) ?? "")
        print("\nVision:")
        print(linhas.prefix(30).joined(separator: "\n"))
        print("\nCandidatos primeira linha:")
        print(candidatosPrimeiraLinha.joined(separator: "\n"))
    }
}
