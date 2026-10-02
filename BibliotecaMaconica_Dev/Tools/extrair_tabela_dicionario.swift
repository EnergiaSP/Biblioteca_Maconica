import Foundation
import PDFKit

// Reads a dictionary laid out as a two-column table (Palavra | Significado) from the PDF text layer.
// PDFKit returns such a page column by column, so the terms end up apart from their meanings.
// Here each character is placed by its position: characters form lines by height, each line is split
// into the two columns at its widest gap, and a new entry starts when the left column has text after
// a row border (a gap larger than the line spacing). Each entry becomes "TERMO — significado", one
// paragraph per entry; the running header ("Palavras", "Palavra Significado") is dropped. The text
// itself is the PDF's own (no OCR). Output: the same JSON as refazer_ocr_obra.swift.
//
//   ./extrair_tabela_dicionario --pdf dicionario.pdf --saida paginas.json [--paginas 6,50]

struct Linha { var esquerda = ""; var direita = ""; var topo: CGFloat; var base: CGFloat }

func argumento(_ nome: String) -> String? {
    guard let i = CommandLine.arguments.firstIndex(of: nome), i + 1 < CommandLine.arguments.count else { return nil }
    return CommandLine.arguments[i + 1]
}

func linhas(_ pagina: PDFPage) -> [Linha] {
    // Heights of the text lines PDFKit finds; each height band is then read as two rectangles, the
    // left cell and the right cell, so a selection joining a term with a piece of meaning is split.
    let caixa = pagina.bounds(for: .mediaBox)
    let partes = (pagina.selection(for: caixa)?.selectionsByLine() ?? []).compactMap { sel -> CGRect? in
        let texto = (sel.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return texto.isEmpty ? nil : sel.bounds(for: pagina)
    }
    // The right column starts where most right-hand lines start.
    let inicios = partes.map { (($0.minX / 2).rounded() * 2) }.filter { $0 > caixa.width * 0.2 && $0 < caixa.width * 0.6 }
    let corte = (Dictionary(grouping: inicios, by: { $0 }).max { $0.value.count < $1.value.count }?.key ?? caixa.width * 0.31) - 2
    var faixas: [CGRect] = []
    for r in partes.sorted(by: { $0.midY > $1.midY }) {
        if let ultima = faixas.last, abs(ultima.midY - r.midY) < min(ultima.height, r.height) * 0.5 {
            faixas[faixas.count - 1] = ultima.union(r)
        } else {
            faixas.append(r)
        }
    }
    func ler(_ retangulo: CGRect) -> String {
        (pagina.selection(for: retangulo)?.string ?? "")
            .replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }
    return faixas.map { f in
        let meio = CGRect(x: 0, y: f.midY - f.height * 0.3, width: 0, height: f.height * 0.6)
        return Linha(esquerda: ler(CGRect(x: 0, y: meio.minY, width: corte, height: meio.height)),
                     direita: ler(CGRect(x: corte, y: meio.minY, width: caixa.width - corte, height: meio.height)),
                     topo: f.maxY, base: f.minY)
    }
}

func paginaComoTexto(_ pagina: PDFPage) -> String {
    var ls = linhas(pagina).filter { l in
        let tudo = (l.esquerda + " " + l.direita).trimmingCharacters(in: .whitespaces)
        return !["Palavras", "Palavra Significado", "Palavra", "Significado"].contains(tudo)
    }
    // Usual distance between lines of the same cell.
    let passos = zip(ls, ls.dropFirst()).map { $0.base - $1.topo }.filter { $0 > -2 }.sorted()
    let passo = passos.isEmpty ? 2 : passos[passos.count / 3]
    var entradas: [(termo: String, texto: String)] = []
    var anterior: Linha?
    for linha in ls {
        let novaLinhaDeTabela = anterior.map { $0.base - linha.topo > passo + 2.5 } ?? true
        if !linha.esquerda.isEmpty, novaLinhaDeTabela || entradas.isEmpty {
            entradas.append((linha.esquerda, linha.direita))
        } else if entradas.isEmpty {
            entradas.append(("", linha.direita))  // meaning continued from the previous page
        } else {
            var e = entradas.removeLast()
            if !linha.esquerda.isEmpty { e.termo += " " + linha.esquerda }
            if !linha.direita.isEmpty {
                e.texto = e.texto.hasSuffix("-") ? String(e.texto.dropLast()) + linha.direita
                                                  : (e.texto.isEmpty ? linha.direita : e.texto + " " + linha.direita)
            }
            entradas.append(e)
        }
        anterior = linha
    }
    ls.removeAll()
    return entradas.map { $0.termo.isEmpty ? $0.texto : "\($0.termo) — \($0.texto)" }.joined(separator: "\n\n")
}

guard let caminho = argumento("--pdf"), let saida = argumento("--saida"), let pdf = PDFDocument(url: URL(fileURLWithPath: caminho)) else {
    FileHandle.standardError.write("uso: --pdf arquivo.pdf --saida paginas.json\n".data(using: .utf8)!)
    exit(1)
}
let escolhidas = argumento("--paginas").map { Set($0.split(separator: ",").compactMap { Int($0) }) }
var paginas: [[String: Any]] = []
for i in 0..<pdf.pageCount where escolhidas?.contains(i + 1) ?? true {
    autoreleasepool {
        if let p = pdf.page(at: i) { paginas.append(["pagina": i + 1, "texto": paginaComoTexto(p)]) }
    }
}
let dados = try JSONSerialization.data(withJSONObject: ["pdf": caminho, "metodo": "tabela da camada de texto", "paginas": paginas],
                                       options: [.prettyPrinted])
try dados.write(to: URL(fileURLWithPath: saida))
print("\(paginas.count) página(s)")
