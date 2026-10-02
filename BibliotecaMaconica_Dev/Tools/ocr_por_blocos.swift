import AppKit
import Foundation
import PDFKit
import Vision

// OCR for pages laid out in many narrow columns and captions (illustrated books): Vision reads the lines,
// which are then grouped into text blocks (lines that overlap horizontally, follow each other closely and
// have the same letter size) and each block is written whole, one after the other, in reading order
// (blocks ordered by column, then top to bottom). Plain line-by-line ordering interleaves the columns.
// Output: the same JSON as refazer_ocr_obra.swift.
//
//   ./ocr_por_blocos --pdf livro.pdf --saida paginas.json [--paginas 14,15] [--lado 3000]

func argumento(_ nome: String) -> String? {
    guard let i = CommandLine.arguments.firstIndex(of: nome), i + 1 < CommandLine.arguments.count else { return nil }
    return CommandLine.arguments[i + 1]
}

struct Linha { let texto: String; let r: CGRect }  // r: 0..1, origin top-left

func ler(_ pagina: PDFPage, lado: CGFloat) -> [Linha] {
    let caixa = pagina.bounds(for: .mediaBox)
    let e = lado / max(caixa.width, caixa.height)
    guard let ctx = CGContext(data: nil, width: Int(caixa.width * e), height: Int(caixa.height * e), bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return [] }
    ctx.setFillColor(.white)
    ctx.fill(CGRect(x: 0, y: 0, width: caixa.width * e, height: caixa.height * e))
    ctx.scaleBy(x: e, y: e)
    pagina.draw(with: .mediaBox, to: ctx)
    let pedido = VNRecognizeTextRequest()
    pedido.recognitionLevel = .accurate
    pedido.usesLanguageCorrection = true
    pedido.recognitionLanguages = ["pt-BR", "en-US"]
    try? VNImageRequestHandler(cgImage: ctx.makeImage()!, options: [:]).perform([pedido])
    return (pedido.results ?? []).compactMap { o in
        guard let t = o.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
        let b = o.boundingBox
        return Linha(texto: t, r: CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height))
    }
}

func blocos(_ linhas: [Linha]) -> [[Linha]] {
    var pai = Array(0..<linhas.count)
    func raiz(_ i: Int) -> Int { var i = i; while pai[i] != i { pai[i] = pai[pai[i]]; i = pai[i] }; return i }
    for i in linhas.indices {
        for j in linhas.indices where j > i {
            let a = linhas[i].r, b = linhas[j].r
            let (cima, baixo) = a.minY <= b.minY ? (a, b) : (b, a)
            let altura = min(a.height, b.height)
            let lacuna = baixo.minY - cima.maxY
            let sobreposicao = min(a.maxX, b.maxX) - max(a.minX, b.minX)
            let mesmaLetra = max(a.height, b.height) < altura * 1.45
            // Same block: the next line just below, sharing most of the narrower width, same letter size.
            if mesmaLetra, lacuna > -altura * 0.4, lacuna < altura * 1.1,
               sobreposicao > 0.5 * min(a.width, b.width), abs(a.minX - b.minX) < 0.06 || abs(a.midX - b.midX) < 0.04 {
                pai[raiz(i)] = raiz(j)
            }
        }
    }
    var grupos: [Int: [Linha]] = [:]
    for i in linhas.indices { grupos[raiz(i), default: []].append(linhas[i]) }
    let lista = grupos.values.map { $0.sorted { $0.r.minY < $1.r.minY } }
    // Reading order: blocks whose tops are close go left to right; otherwise top to bottom, by column.
    return lista.sorted { a, b in
        let ra = a.map(\.r).reduce(a[0].r) { $0.union($1) }, rb = b.map(\.r).reduce(b[0].r) { $0.union($1) }
        let mesmaFaixa = ra.minY < rb.maxY && rb.minY < ra.maxY
        if mesmaFaixa && abs(ra.minX - rb.minX) > 0.05 { return ra.minX < rb.minX }
        return ra.minY < rb.minY
    }
}

func texto(_ bloco: [Linha]) -> String {
    var s = ""
    for l in bloco {
        if s.hasSuffix("-"), let p = l.texto.first, p.isLowercase, s.dropLast().last?.isLetter == true {
            s.removeLast(); s += l.texto  // word split at the end of the line
        } else {
            s += (s.isEmpty ? "" : "\n") + l.texto
        }
    }
    return s
}

guard let caminho = argumento("--pdf"), let saida = argumento("--saida"), let pdf = PDFDocument(url: URL(fileURLWithPath: caminho)) else {
    FileHandle.standardError.write("uso: --pdf livro.pdf --saida paginas.json\n".data(using: .utf8)!)
    exit(1)
}
let lado = CGFloat(Double(argumento("--lado") ?? "3000") ?? 3000)
let escolhidas = argumento("--paginas").map { Set($0.split(separator: ",").compactMap { Int($0) }) }
var paginas: [[String: Any]] = []
for i in 0..<pdf.pageCount where escolhidas?.contains(i + 1) ?? true {
    autoreleasepool {
        guard let p = pdf.page(at: i) else { return }
        paginas.append(["pagina": i + 1, "texto": blocos(ler(p, lado: lado)).map(texto).joined(separator: "\n\n")])
    }
}
try JSONSerialization.data(withJSONObject: ["pdf": caminho, "metodo": "OCR por blocos", "paginas": paginas], options: [.prettyPrinted])
    .write(to: URL(fileURLWithPath: saida))
print("\(paginas.count) página(s)")
