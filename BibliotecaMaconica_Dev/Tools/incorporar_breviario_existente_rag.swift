import Foundation
import SQLite3

struct BreviarioDataArquivo: Decodable {
    let itens: [Item]
    let indiceRemissivo: [Indice]

    struct Item: Decodable {
        let id: Int
        let data: String
        let titulo: String
        let frase: String?
        let texto: String
        let rodape: String?
        let autor: String?
        let pagina: Int?
    }

    struct Indice: Decodable {
        let termo: String
        let paginas: [Int]
        let datas: [String]
    }
}

let raiz = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let breviarioURL = raiz.appendingPathComponent("Resources/breviario.json")
let bancoURL = raiz.appendingPathComponent("ImportacaoLivrosPDF_OCR/_relatorios/biblioteca-rag-preimport.sqlite")
let relatorioURL = raiz.appendingPathComponent("ImportacaoLivrosPDF_OCR/_relatorios/relatorio_breviario_rag.json")

let dados = try JSONDecoder().decode(BreviarioDataArquivo.self, from: Data(contentsOf: breviarioURL))

var db: OpaquePointer?
guard sqlite3_open_v2(bancoURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
    fatalError("Nao foi possivel abrir o banco RAG: \(bancoURL.path)")
}
defer { sqlite3_close(db) }

func executar(_ sql: String) {
    guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
        fatalError(String(cString: sqlite3_errmsg(db)))
    }
}

func bindText(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
    guard let value else {
        sqlite3_bind_null(statement, index)
        return
    }
    sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
}

func bindInt(_ statement: OpaquePointer?, _ index: Int32, _ value: Int) {
    sqlite3_bind_int64(statement, index, sqlite3_int64(value))
}

func bindDouble(_ statement: OpaquePointer?, _ index: Int32, _ value: Double) {
    sqlite3_bind_double(statement, index, value)
}

func inserir(_ sql: String, _ binds: [(OpaquePointer?, Int32) -> Void]) {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
        fatalError(String(cString: sqlite3_errmsg(db)))
    }
    defer { sqlite3_finalize(statement) }
    for (index, bind) in binds.enumerated() {
        bind(statement, Int32(index + 1))
    }
    guard sqlite3_step(statement) == SQLITE_DONE else {
        fatalError(String(cString: sqlite3_errmsg(db)))
    }
}

func limpar(_ texto: String) -> String {
    texto
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func separarParagrafos(_ texto: String) -> [String] {
    texto
        .components(separatedBy: "\n\n")
        .map {
            $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { $0.isEmpty == false }
}

func separarNotas(_ rodape: String?) -> [(numero: String, texto: String)] {
    guard let rodape = rodape?.trimmingCharacters(in: .whitespacesAndNewlines),
          rodape.isEmpty == false else {
        return []
    }

    var notas: [(String, String)] = []
    var numeroAtual: String?
    var linhas: [String] = []

    func finalizar() {
        guard let numeroAtual else { return }
        let texto = linhas.joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if texto.isEmpty == false {
            notas.append((numeroAtual, texto))
        }
    }

    for linha in rodape.components(separatedBy: .newlines) {
        let limpa = linha.trimmingCharacters(in: .whitespaces)
        if let match = limpa.range(of: #"^\d{1,4}\b"#, options: .regularExpression) {
            finalizar()
            numeroAtual = String(limpa[match])
            linhas = [String(limpa[match.upperBound...]).trimmingCharacters(in: .whitespaces)]
        } else if limpa.isEmpty == false {
            linhas.append(limpa)
        }
    }
    finalizar()
    return notas
}

let obraID = "breviario_seculo_xxi"
let tituloObra = "Breviário Maçônico"
let autor = "Kennyo Ismail"
let assuntos = ["Leitura diária", "Reflexão", "Ética", "Filosofia", "Ritualística"]
let assuntosJSON = String(data: try JSONSerialization.data(withJSONObject: assuntos), encoding: .utf8) ?? "[]"
let termosPorData = Dictionary(grouping: dados.indiceRemissivo.flatMap { entrada in
    entrada.datas.map { data in (data: data, termo: entrada.termo) }
}, by: \.data).mapValues { pares in
    pares.map(\.termo).joined(separator: " ")
}

executar("BEGIN IMMEDIATE TRANSACTION")
executar("DELETE FROM rag_fts WHERE obra_id = '\(obraID)'")
executar("DELETE FROM rag_imagens WHERE obra_id = '\(obraID)'")
executar("DELETE FROM rag_notas WHERE obra_id = '\(obraID)'")
executar("DELETE FROM rag_paragrafos WHERE obra_id = '\(obraID)'")
executar("DELETE FROM rag_paginas WHERE obra_id = '\(obraID)'")
executar("DELETE FROM rag_obras WHERE id = '\(obraID)'")

inserir(
    "INSERT INTO rag_obras (id, area, tipo, titulo, autor, origem, edicao, assuntos_json, data_importacao) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
    [
        { bindText($0, $1, obraID) },
        { bindText($0, $1, "breviarios") },
        { bindText($0, $1, "breviarioDiario") },
        { bindText($0, $1, tituloObra) },
        { bindText($0, $1, autor) },
        { bindText($0, $1, "Resources/breviario.json") },
        { bindText($0, $1, nil) },
        { bindText($0, $1, assuntosJSON) },
        { bindDouble($0, $1, Date().timeIntervalSince1970) }
    ]
)

var totalParagrafos = 0
var totalNotas = 0
var totalFTS = 0

for item in dados.itens {
    let pagina = item.pagina ?? item.id
    let texto = limpar(item.texto)
    let rodape = limpar(item.rodape ?? "")
    let textoIntegral = [item.data, item.titulo, item.frase ?? "", texto, rodape]
        .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        .joined(separator: "\n\n")
    let paginaID = "\(obraID)-dia-\(item.data.replacingOccurrences(of: "/", with: "-"))"

    inserir(
        "INSERT INTO rag_paginas (id, obra_id, numero_original, titulo, texto_integral, largura, altura) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [
            { bindText($0, $1, paginaID) },
            { bindText($0, $1, obraID) },
            { bindInt($0, $1, pagina) },
            { bindText($0, $1, item.titulo) },
            { bindText($0, $1, textoIntegral) },
            { bindDouble($0, $1, 0) },
            { bindDouble($0, $1, 0) }
        ]
    )

    let blocosBase = separarParagrafos(texto)
    let blocos = blocosBase.isEmpty ? [texto] : blocosBase
    for (ordem, bloco) in blocos.enumerated() where bloco.isEmpty == false {
        let blocoID = "\(obraID)-\(item.data.replacingOccurrences(of: "/", with: "-"))-b\(ordem + 1)"
        let termosIndice = termosPorData[item.data] ?? ""
        let textoBusca = [item.data, item.titulo, item.frase ?? "", bloco, termosIndice]
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .joined(separator: "\n")

        inserir(
            "INSERT INTO rag_paragrafos (id, obra_id, pagina, ordem, texto, capitulo, secao, temas_json, palavras_chave_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                { bindText($0, $1, blocoID) },
                { bindText($0, $1, obraID) },
                { bindInt($0, $1, pagina) },
                { bindInt($0, $1, ordem + 1) },
                { bindText($0, $1, bloco) },
                { bindText($0, $1, item.data) },
                { bindText($0, $1, item.titulo) },
                { bindText($0, $1, assuntosJSON) },
                { bindText($0, $1, assuntosJSON) }
            ]
        )

        inserir(
            "INSERT INTO rag_fts (bloco_id, obra_id, titulo_obra, area, pagina, texto) VALUES (?, ?, ?, ?, ?, ?)",
            [
                { bindText($0, $1, blocoID) },
                { bindText($0, $1, obraID) },
                { bindText($0, $1, tituloObra) },
                { bindText($0, $1, "breviarios") },
                { bindInt($0, $1, pagina) },
                { bindText($0, $1, textoBusca) }
            ]
        )
        totalParagrafos += 1
        totalFTS += 1
    }

    for (indiceNota, nota) in separarNotas(item.rodape).enumerated() {
        inserir(
            "INSERT INTO rag_notas (id, obra_id, pagina, numero, texto) VALUES (?, ?, ?, ?, ?)",
            [
                { bindText($0, $1, "\(obraID)-\(item.data.replacingOccurrences(of: "/", with: "-"))-nota-\(nota.numero)-\(indiceNota + 1)") },
                { bindText($0, $1, obraID) },
                { bindInt($0, $1, pagina) },
                { bindText($0, $1, nota.numero) },
                { bindText($0, $1, nota.texto) }
            ]
        )
        totalNotas += 1
    }
}

executar("COMMIT")

let relatorio: [String: Any] = [
    "data": ISO8601DateFormatter().string(from: Date()),
    "obraID": obraID,
    "titulo": tituloObra,
    "itensDiarios": dados.itens.count,
    "indiceRemissivo": dados.indiceRemissivo.count,
    "paginasRAG": dados.itens.count,
    "paragrafosRAG": totalParagrafos,
    "notasRAG": totalNotas,
    "blocosFTS": totalFTS,
    "banco": bancoURL.path
]
let saida = try JSONSerialization.data(withJSONObject: relatorio, options: [.prettyPrinted, .sortedKeys])
try saida.write(to: relatorioURL)
print(String(data: saida, encoding: .utf8) ?? "")
