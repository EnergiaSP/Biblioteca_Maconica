import Foundation
import PDFKit
import SQLite3

let raiz = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let origem = raiz.appendingPathComponent("ImportacaoLivrosPDF_OCR")
let destino = raiz
    .appendingPathComponent("ImportacaoLivrosPDF_OCR")
    .appendingPathComponent("_relatorios")
    .appendingPathComponent("amostra-rag.sqlite")

try? FileManager.default.removeItem(at: destino)

var db: OpaquePointer?
guard sqlite3_open_v2(destino.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
    fatalError("Nao foi possivel abrir banco de amostra.")
}
defer { sqlite3_close(db) }

func executar(_ sql: String) {
    guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
        fatalError(String(cString: sqlite3_errmsg(db)))
    }
}

func bindText(_ statement: OpaquePointer?, _ index: Int32, _ value: String) {
    sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
}

executar("PRAGMA journal_mode = WAL")
executar("CREATE TABLE obras (id TEXT PRIMARY KEY, titulo TEXT NOT NULL, paginas INTEGER NOT NULL)")
executar("CREATE TABLE paginas (id TEXT PRIMARY KEY, obra_id TEXT NOT NULL, pagina INTEGER NOT NULL, texto TEXT NOT NULL)")
executar("CREATE VIRTUAL TABLE fts USING fts5(bloco_id UNINDEXED, obra_id UNINDEXED, titulo, pagina UNINDEXED, texto, tokenize = 'unicode61 remove_diacritics 2')")

let nomesAmostra = [
    "A Bíblia Maçônica Versão Portugues.pdf",
    "Landmarks.pdf",
    "Sócrates em 90 Minutos - Paul Strathern.pdf"
]

var resumo: [[String: Any]] = []

for nome in nomesAmostra {
    let url = origem.appendingPathComponent(nome)
    guard let documento = PDFDocument(url: url) else {
        resumo.append(["arquivo": nome, "status": "nao_abriu"])
        continue
    }

    let obraID = nome
        .replacingOccurrences(of: ".pdf", with: "")
        .lowercased()
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { $0.isEmpty == false }
        .joined(separator: "_")

    var paginasComTexto = 0
    var blocos = 0

    var insertObra: OpaquePointer?
    sqlite3_prepare_v2(db, "INSERT INTO obras (id, titulo, paginas) VALUES (?, ?, ?)", -1, &insertObra, nil)
    bindText(insertObra, 1, obraID)
    bindText(insertObra, 2, nome.replacingOccurrences(of: ".pdf", with: ""))
    sqlite3_bind_int(insertObra, 3, Int32(documento.pageCount))
    sqlite3_step(insertObra)
    sqlite3_finalize(insertObra)

    for indice in 0..<documento.pageCount {
        guard let pagina = documento.page(at: indice) else {
            continue
        }

        let texto = (pagina.string ?? "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard texto.isEmpty == false else {
            continue
        }

        paginasComTexto += 1
        let paginaNumero = indice + 1
        let blocoID = "\(obraID)-p\(paginaNumero)"

        var insertPagina: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT INTO paginas (id, obra_id, pagina, texto) VALUES (?, ?, ?, ?)", -1, &insertPagina, nil)
        bindText(insertPagina, 1, blocoID)
        bindText(insertPagina, 2, obraID)
        sqlite3_bind_int(insertPagina, 3, Int32(paginaNumero))
        bindText(insertPagina, 4, texto)
        sqlite3_step(insertPagina)
        sqlite3_finalize(insertPagina)

        var insertFTS: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT INTO fts (bloco_id, obra_id, titulo, pagina, texto) VALUES (?, ?, ?, ?, ?)", -1, &insertFTS, nil)
        bindText(insertFTS, 1, blocoID)
        bindText(insertFTS, 2, obraID)
        bindText(insertFTS, 3, nome)
        sqlite3_bind_int(insertFTS, 4, Int32(paginaNumero))
        bindText(insertFTS, 5, texto)
        sqlite3_step(insertFTS)
        sqlite3_finalize(insertFTS)
        blocos += 1
    }

    resumo.append([
        "arquivo": nome,
        "status": "importado",
        "paginas": documento.pageCount,
        "paginasComTexto": paginasComTexto,
        "blocosFTS": blocos
    ])
}

let termosTeste = ["mestre", "templo", "filosofia"]
var buscas: [[String: Any]] = []

for termo in termosTeste {
    var statement: OpaquePointer?
    sqlite3_prepare_v2(
        db,
        """
        SELECT titulo, pagina, snippet(fts, 4, '[', ']', '...', 12)
        FROM fts
        WHERE fts MATCH ?
        LIMIT 5
        """,
        -1,
        &statement,
        nil
    )
    bindText(statement, 1, termo)

    var resultados: [[String: Any]] = []
    while sqlite3_step(statement) == SQLITE_ROW {
        let titulo = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
        let pagina = Int(sqlite3_column_int(statement, 1))
        let trecho = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
        resultados.append(["titulo": titulo, "pagina": pagina, "trecho": trecho])
    }
    sqlite3_finalize(statement)
    buscas.append(["termo": termo, "resultados": resultados])
}

let relatorio: [String: Any] = [
    "banco": destino.path,
    "obrasImportadas": resumo,
    "buscasTeste": buscas
]

let json = try JSONSerialization.data(withJSONObject: relatorio, options: [.prettyPrinted, .sortedKeys])
let saida = destino.deletingPathExtension().appendingPathExtension("json")
try json.write(to: saida)
print(String(data: json, encoding: .utf8) ?? "")
