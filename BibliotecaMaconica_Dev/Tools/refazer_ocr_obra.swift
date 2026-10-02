import AppKit
import Foundation
import PDFKit
import Vision

// Redoes the OCR of one work from its original PDF, ignoring any text layer the PDF already has.
// Each page is rendered at high resolution and read by Vision (accurate, language correction);
// lines become paragraphs by their spacing, and words split by a hyphen at the end of a line
// are joined. The text of each page goes to a JSON file, applied to the work package by
// Tools/aplicar_ocr_refeito.py (which keeps the old text of a page whenever it is not worse).
//
//   swiftc -O refazer_ocr_obra.swift -o refazer_ocr_obra
//   ./refazer_ocr_obra --pdf original.pdf --saida paginas.json [--lado 3000] [--idiomas pt-BR,en-US] [--paginas 5,9]

struct Opcoes {
    var pdf = ""
    var saida = ""
    var lado: CGFloat = 3000
    var idiomas = ["pt-BR", "en-US", "es-ES", "fr-FR"]
    var paginas: Set<Int>? = nil
}

func lerOpcoes() -> Opcoes {
    var opcoes = Opcoes()
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let nome = args.removeFirst()
        guard let valor = args.first else { break }
        args.removeFirst()
        switch nome {
        case "--pdf": opcoes.pdf = valor
        case "--saida": opcoes.saida = valor
        case "--lado": opcoes.lado = CGFloat(Double(valor) ?? 3000)
        case "--idiomas": opcoes.idiomas = valor.split(separator: ",").map(String.init)
        case "--paginas": opcoes.paginas = Set(valor.split(separator: ",").compactMap { Int($0) })
        default: break
        }
    }
    return opcoes
}

func renderizar(_ pagina: PDFPage, lado: CGFloat) -> CGImage? {
    let caixa = pagina.bounds(for: .mediaBox)
    guard caixa.width > 0, caixa.height > 0 else { return nil }
    let escala = lado / max(caixa.width, caixa.height)
    let largura = Int(caixa.width * escala), altura = Int(caixa.height * escala)
    guard let contexto = CGContext(data: nil, width: largura, height: altura, bitsPerComponent: 8, bytesPerRow: 0,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
    contexto.setFillColor(.white)
    contexto.fill(CGRect(x: 0, y: 0, width: largura, height: altura))
    contexto.scaleBy(x: escala, y: escala)
    // Rotation of the page is respected; only the drawing is used (the old text layer is not read).
    pagina.draw(with: .mediaBox, to: contexto)
    return contexto.makeImage()
}

struct Linha {
    let texto: String
    let topo: CGFloat      // 0 = top of the page
    let altura: CGFloat
    let esquerda: CGFloat
    let direita: CGFloat
}

func reconhecer(_ imagem: CGImage, idiomas: [String]) throws -> [Linha] {
    let pedido = VNRecognizeTextRequest()
    pedido.recognitionLevel = .accurate
    pedido.usesLanguageCorrection = true
    let suportados = (try? pedido.supportedRecognitionLanguages()) ?? idiomas
    pedido.recognitionLanguages = idiomas.filter { suportados.contains($0) }
    pedido.customWords = ["Maçonaria", "Maçônico", "Maçônica", "maçom", "maçons", "Loja", "Oriente", "Aprendiz",
                          "Companheiro", "Mestre", "Rito", "Escocês", "Simbologia", "Ritualística", "Acácia",
                          "Esquadro", "Compasso", "Venerável", "Vigilante", "Grão-Mestre", "Templários"]
    try VNImageRequestHandler(cgImage: imagem, options: [:]).perform([pedido])
    return (pedido.results ?? []).compactMap { observacao in
        guard let texto = observacao.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces), !texto.isEmpty else { return nil }
        let caixa = observacao.boundingBox
        return Linha(texto: texto, topo: 1 - caixa.maxY, altura: caixa.height, esquerda: caixa.minX, direita: caixa.maxX)
    }
}

/// Lines in reading order. Two columns are read one after the other when the page clearly has them.
func ordenar(_ linhas: [Linha]) -> [Linha] {
    let porTopo = linhas.sorted { $0.topo < $1.topo }
    let esquerda = porTopo.filter { $0.direita <= 0.52 }
    let direita = porTopo.filter { $0.esquerda >= 0.48 }
    if esquerda.count >= 8, direita.count >= 8, Double(esquerda.count + direita.count) >= 0.8 * Double(linhas.count) {
        let largas = porTopo.filter { $0.direita > 0.52 && $0.esquerda < 0.48 }
        return largas.filter { $0.topo < (esquerda.first?.topo ?? 0) } + esquerda + direita
            + largas.filter { $0.topo >= (esquerda.first?.topo ?? 0) }
    }
    return porTopo
}

/// Paragraphs separated by a blank line: a larger gap, or a short line ending a sentence.
func montarTexto(_ linhas: [Linha]) -> String {
    guard !linhas.isEmpty else { return "" }
    let alturas = linhas.map(\.altura).sorted()
    let alturaTipica = alturas[alturas.count / 2]
    let margemDireita = linhas.map(\.direita).sorted()[Int(Double(linhas.count) * 0.8)]
    var saida = ""
    for (indice, linha) in linhas.enumerated() {
        if indice > 0 {
            let anterior = linhas[indice - 1]
            let intervalo = linha.topo - (anterior.topo + anterior.altura)
            let fimDeFrase = anterior.texto.last.map { ".:!?»\"”".contains($0) } ?? false
            let curta = anterior.direita < margemDireita - 0.08
            let novaColuna = linha.topo < anterior.topo
            if intervalo > alturaTipica * 0.9 || (fimDeFrase && curta) || novaColuna {
                saida += "\n\n"
            } else if saida.hasSuffix("-"), let primeira = linha.texto.first, primeira.isLowercase,
                      let antes = saida.dropLast().last, antes.isLetter {
                saida.removeLast()  // word split at the end of the line
                saida += linha.texto
                continue
            } else {
                saida += "\n"
            }
        }
        saida += linha.texto
    }
    return saida
}

let opcoes = lerOpcoes()
guard let documento = PDFDocument(url: URL(fileURLWithPath: opcoes.pdf)) else {
    FileHandle.standardError.write("Não foi possível abrir \(opcoes.pdf)\n".data(using: .utf8)!)
    exit(1)
}
var paginas: [[String: Any]] = []
let inicio = Date()
for indice in 0..<documento.pageCount where opcoes.paginas?.contains(indice + 1) ?? true {
    autoreleasepool {
        guard let pagina = documento.page(at: indice) else { return }
        var texto = ""
        if let imagem = renderizar(pagina, lado: opcoes.lado), let linhas = try? reconhecer(imagem, idiomas: opcoes.idiomas) {
            texto = montarTexto(ordenar(linhas))
        }
        paginas.append(["pagina": indice + 1, "texto": texto])
        if (indice + 1) % 25 == 0 || indice + 1 == documento.pageCount {
            print("\(indice + 1)/\(documento.pageCount) páginas (\(Int(Date().timeIntervalSince(inicio))) s)")
            fflush(stdout)
        }
    }
}
let dados = try JSONSerialization.data(withJSONObject: ["pdf": opcoes.pdf, "lado": opcoes.lado, "idiomas": opcoes.idiomas,
                                                        "paginas": paginas], options: [.prettyPrinted])
try dados.write(to: URL(fileURLWithPath: opcoes.saida))
