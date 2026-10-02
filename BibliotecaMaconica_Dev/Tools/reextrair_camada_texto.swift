import Foundation
import PDFKit

// Reads the PDF text layer again, line by line with each line's position, keeping one copy of a line drawn
// twice at the same place (PDFs with two text layers, the original and an OCR one, or "shadow" text).
// The text is the PDF's own (no OCR); only the second copy of a line is dropped. Lines keep the page
// reading order (top to bottom; two columns are read one after the other) and a blank line marks a
// larger vertical gap (a new paragraph). Output: the same JSON as refazer_ocr_obra.swift.
//
//   ./reextrair_camada_texto --pdf obra.pdf --saida paginas.json [--paginas 9,14]

func argumento(_ nome: String) -> String? {
    guard let i = CommandLine.arguments.firstIndex(of: nome), i + 1 < CommandLine.arguments.count else { return nil }
    return CommandLine.arguments[i + 1]
}

func normalizada(_ s: String) -> String {
    s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
}

func sobreposicao(_ a: CGRect, _ b: CGRect) -> CGFloat {
    let i = a.intersection(b)
    guard !i.isNull, a.width > 0, b.width > 0 else { return 0 }
    return (i.width * i.height) / min(a.width * a.height, b.width * b.height)
}

func pagina(_ p: PDFPage) -> String {
    let caixa = p.bounds(for: .mediaBox)
    var linhas: [(texto: String, r: CGRect)] = []
    for sel in p.selection(for: caixa)?.selectionsByLine() ?? [] {
        let texto = (sel.string ?? "").replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !texto.isEmpty else { continue }
        let r = sel.bounds(for: p)
        // The same text drawn again over (almost) the same place is a second copy.
        let chave = normalizada(texto)
        if linhas.contains(where: { sobreposicao($0.r, r) > 0.6 && (normalizada($0.texto) == chave
            || normalizada($0.texto).contains(chave) || chave.contains(normalizada($0.texto))) }) {
            if let i = linhas.firstIndex(where: { sobreposicao($0.r, r) > 0.6 && chave.contains(normalizada($0.texto)) && chave.count > normalizada($0.texto).count }) {
                linhas[i] = (texto, r)  // keep the longer reading of the same line
            }
            continue
        }
        linhas.append((texto, r))
    }
    // Reading order: two columns when most lines sit clearly on one half.
    let meio = caixa.midX
    let esquerda = linhas.filter { $0.r.maxX <= meio + 4 }, direita = linhas.filter { $0.r.minX >= meio - 4 }
    let duasColunas = esquerda.count >= 6 && direita.count >= 6 && esquerda.count + direita.count >= linhas.count * 8 / 10
    let porAltura = { (l: [(texto: String, r: CGRect)]) in l.sorted { abs($0.r.midY - $1.r.midY) > 2 ? $0.r.midY > $1.r.midY : $0.r.minX < $1.r.minX } }
    let ordem = duasColunas
        ? porAltura(linhas.filter { !($0.r.maxX <= meio + 4) && !($0.r.minX >= meio - 4) }) + porAltura(esquerda) + porAltura(direita)
        : porAltura(linhas)
    // Pieces at the same height form one line ("“antologia”" and ","); joined without a space before punctuation.
    var unidas: [(texto: String, r: CGRect)] = []
    for (texto, r) in ordem {
        if let u = unidas.last, abs(u.r.midY - r.midY) < min(u.r.height, r.height) * 0.5, r.minX >= u.r.minX {
            let colado = texto.first.map { ",.;:!?)]”’»".contains($0) } ?? false
            unidas[unidas.count - 1] = (u.texto + (colado ? "" : " ") + texto, u.r.union(r))
        } else {
            unidas.append((texto, r))
        }
    }
    let alturas = unidas.map(\.r.height).sorted()
    let tipica = alturas.isEmpty ? 10 : alturas[alturas.count / 2]
    var saida = ""
    var anterior: CGRect?
    for (texto, r) in unidas {
        if let a = anterior {
            let lacuna = a.minY - r.maxY
            if lacuna > tipica * 0.9 || r.maxY > a.maxY + tipica {
                saida += "\n\n"
            } else if saida.hasSuffix("-"), let primeira = texto.first, primeira.isLowercase,
                      saida.dropLast().last?.isLetter == true {
                saida.removeLast()  // word split by a hyphen at the end of the line
                saida += texto
                anterior = r
                continue
            } else {
                saida += "\n"
            }
        }
        saida += texto
        anterior = r
    }
    return saida
}

guard let caminho = argumento("--pdf"), let saida = argumento("--saida"), let pdf = PDFDocument(url: URL(fileURLWithPath: caminho)) else {
    FileHandle.standardError.write("uso: --pdf arquivo.pdf --saida paginas.json\n".data(using: .utf8)!)
    exit(1)
}
let escolhidas = argumento("--paginas").map { Set($0.split(separator: ",").compactMap { Int($0) }) }
var paginas: [[String: Any]] = []
for i in 0..<pdf.pageCount where escolhidas?.contains(i + 1) ?? true {
    autoreleasepool { if let p = pdf.page(at: i) { paginas.append(["pagina": i + 1, "texto": pagina(p)]) } }
}
try JSONSerialization.data(withJSONObject: ["pdf": caminho, "metodo": "camada de texto sem cópias", "paginas": paginas],
                           options: [.prettyPrinted]).write(to: URL(fileURLWithPath: saida))
print("\(paginas.count) página(s)")
