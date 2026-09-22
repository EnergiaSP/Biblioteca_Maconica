import Foundation
import PDFKit
import SQLite3

let raiz = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let pastaOCR = raiz.appendingPathComponent("ImportacaoLivrosPDF_OCR")
let pastaRelatorios = pastaOCR.appendingPathComponent("_relatorios")
let bancoURL = pastaRelatorios.appendingPathComponent("biblioteca-rag-preimport.sqlite")
let relatorioURL = pastaRelatorios.appendingPathComponent("biblioteca-rag-preimport.json")
let limiteArgumento = CommandLine.arguments.firstIndex(of: "--limit")
    .flatMap { indice -> Int? in
        let proximo = CommandLine.arguments.index(after: indice)
        guard CommandLine.arguments.indices.contains(proximo) else { return nil }
        return Int(CommandLine.arguments[proximo])
    }

try FileManager.default.createDirectory(at: pastaRelatorios, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: bancoURL)
try? FileManager.default.removeItem(at: URL(fileURLWithPath: bancoURL.path + "-shm"))
try? FileManager.default.removeItem(at: URL(fileURLWithPath: bancoURL.path + "-wal"))
try? FileManager.default.removeItem(at: relatorioURL)

func pdfsParaImportar() -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: pastaOCR,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    return enumerator.compactMap { item -> URL? in
        guard let url = item as? URL,
              url.pathExtension.lowercased() == "pdf" else {
            return nil
        }

        let relativo = url.path.replacingOccurrences(of: pastaOCR.path + "/", with: "")
        guard relativo.split(separator: "/").contains(where: { $0.hasPrefix("_") }) == false else {
            return nil
        }

        return url
    }
    .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
}

var db: OpaquePointer?
guard sqlite3_open_v2(bancoURL.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
    fatalError("Nao foi possivel abrir o banco RAG.")
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

func bindDouble(_ statement: OpaquePointer?, _ index: Int32, _ value: Double) {
    sqlite3_bind_double(statement, index, value)
}

func bindInt(_ statement: OpaquePointer?, _ index: Int32, _ value: Int) {
    sqlite3_bind_int64(statement, index, sqlite3_int64(value))
}

func inserir(_ sql: String, _ valores: [(OpaquePointer?, Int32) -> Void]) {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
        fatalError(String(cString: sqlite3_errmsg(db)))
    }
    defer { sqlite3_finalize(statement) }
    for (indice, bind) in valores.enumerated() {
        bind(statement, Int32(indice + 1))
    }
    guard sqlite3_step(statement) == SQLITE_DONE else {
        fatalError(String(cString: sqlite3_errmsg(db)))
    }
}

executar("PRAGMA journal_mode = WAL")
executar("PRAGMA synchronous = NORMAL")
executar("PRAGMA temp_store = MEMORY")
executar("PRAGMA foreign_keys = ON")
executar("""
CREATE TABLE rag_obras (
    id TEXT PRIMARY KEY,
    area TEXT NOT NULL,
    tipo TEXT NOT NULL,
    titulo TEXT NOT NULL,
    autor TEXT,
    origem TEXT,
    edicao TEXT,
    assuntos_json TEXT NOT NULL,
    data_importacao REAL NOT NULL
)
""")
executar("""
CREATE TABLE rag_paginas (
    id TEXT PRIMARY KEY,
    obra_id TEXT NOT NULL REFERENCES rag_obras(id) ON DELETE CASCADE,
    numero_original INTEGER NOT NULL,
    titulo TEXT,
    texto_integral TEXT NOT NULL,
    largura REAL NOT NULL,
    altura REAL NOT NULL,
    UNIQUE(obra_id, numero_original)
)
""")
executar("""
CREATE TABLE rag_paragrafos (
    id TEXT PRIMARY KEY,
    obra_id TEXT NOT NULL REFERENCES rag_obras(id) ON DELETE CASCADE,
    pagina INTEGER NOT NULL,
    ordem INTEGER NOT NULL,
    texto TEXT NOT NULL,
    capitulo TEXT,
    secao TEXT,
    temas_json TEXT NOT NULL,
    palavras_chave_json TEXT NOT NULL
)
""")
executar("""
CREATE TABLE rag_notas (
    id TEXT PRIMARY KEY,
    obra_id TEXT NOT NULL REFERENCES rag_obras(id) ON DELETE CASCADE,
    pagina INTEGER NOT NULL,
    numero TEXT NOT NULL,
    texto TEXT NOT NULL
)
""")
executar("""
CREATE TABLE rag_imagens (
    id TEXT PRIMARY KEY,
    obra_id TEXT NOT NULL REFERENCES rag_obras(id) ON DELETE CASCADE,
    pagina INTEGER NOT NULL,
    caminho_relativo TEXT NOT NULL,
    largura REAL NOT NULL,
    altura REAL NOT NULL,
    descricao_ocr TEXT
)
""")
executar("""
CREATE VIRTUAL TABLE rag_fts USING fts5(
    bloco_id UNINDEXED,
    obra_id UNINDEXED,
    titulo_obra,
    area UNINDEXED,
    pagina UNINDEXED,
    texto,
    tokenize = 'unicode61 remove_diacritics 2'
)
""")

func slug(_ texto: String) -> String {
    let semExtensao = texto.replacingOccurrences(of: ".pdf", with: "")
    let latinizado = semExtensao.applyingTransform(.stripDiacritics, reverse: false) ?? semExtensao
    let tokens = latinizado.lowercased()
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { $0.isEmpty == false }
    return tokens.joined(separator: "_")
}

func idUnico(base: String, usados: inout Set<String>) -> String {
    let baseSeguro = base.isEmpty ? "obra" : base
    if usados.contains(baseSeguro) == false {
        usados.insert(baseSeguro)
        return baseSeguro
    }

    var indice = 2
    while true {
        let candidato = "\(baseSeguro)_\(indice)"
        if usados.contains(candidato) == false {
            usados.insert(candidato)
            return candidato
        }
        indice += 1
    }
}

func areaETipo(nome: String) -> (area: String, tipo: String, assuntos: [String]) {
    let n = (nome.applyingTransform(.stripDiacritics, reverse: false) ?? nome).lowercased()
    if n.contains("dicion") || n.contains("vocabulario") || n.contains("glossario") {
        return ("dicionariosMaconicos", "dicionario", ["Verbetes", "Terminologia", "Conceitos"])
    }
    if n.contains("judici") || n.contains("constituic") || n.contains("regulamento") || n.contains("landmark") {
        return ("judiciarioMaconico", "judiciario", ["Normas", "Organização", "Legislação"])
    }
    return ("bibliotecaMaconica", "livro", ["História", "Filosofia", "Simbologia", "Estudo"])
}

func normalizarTexto(_ texto: String) -> String {
    texto.replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { String($0).replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression) }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func separarTextoERodape(_ texto: String) -> (principal: String, rodape: String) {
    let linhas = texto.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard linhas.count > 4 else { return (texto, "") }

    if let separador = linhas.lastIndex(where: { linha in
        let limpa = linha.trimmingCharacters(in: .whitespaces)
        return limpa.count >= 8 && limpa.allSatisfy { "-_—―".contains($0) }
    }) {
        return (
            linhas[..<separador].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
            linhas[linhas.index(after: separador)...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    let ultimas = linhas.suffix(10)
    guard let inicioRodape = ultimas.firstIndex(where: {
        $0.trimmingCharacters(in: .whitespaces).range(of: #"^\d{1,4}\s+\S"#, options: .regularExpression) != nil
    }) else {
        return (texto, "")
    }

    return (
        linhas[..<inicioRodape].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
        linhas[inicioRodape...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    )
}

func paragrafos(_ texto: String) -> [String] {
    var saida: [String] = []
    var atual: [String] = []

    func fechar() {
        let texto = atual.joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if texto.isEmpty == false { saida.append(texto) }
        atual.removeAll(keepingCapacity: true)
    }

    for linha in texto.split(separator: "\n", omittingEmptySubsequences: false).map({ String($0).trimmingCharacters(in: .whitespaces) }) {
        if linha.isEmpty {
            fechar()
        } else {
            atual.append(linha)
        }
    }
    fechar()
    return saida
}

func notas(_ rodape: String) -> [(numero: String, texto: String)] {
    var saida: [(String, String)] = []
    var numeroAtual: String?
    var linhas: [String] = []

    func fechar() {
        guard let numeroAtual else { return }
        let texto = linhas.joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if texto.isEmpty == false { saida.append((numeroAtual, texto)) }
    }

    for linha in rodape.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
        let limpa = linha.trimmingCharacters(in: .whitespaces)
        if let range = limpa.range(of: #"^\d{1,4}\b"#, options: .regularExpression) {
            fechar()
            numeroAtual = String(limpa[range])
            linhas = [String(limpa[range.upperBound...]).trimmingCharacters(in: .whitespaces)]
        } else if limpa.isEmpty == false {
            linhas.append(limpa)
        }
    }
    fechar()
    return saida
}

let todosPDFs = pdfsParaImportar()
let pdfs = limiteArgumento.map { Array(todosPDFs.prefix($0)) } ?? todosPDFs
var relatorioObras: [[String: Any]] = []
var totais = ["obras": 0, "paginas": 0, "paginasComTexto": 0, "paragrafos": 0, "notas": 0, "imagens": 0, "falhas": 0]
var idsUsados = Set<String>()

executar("BEGIN IMMEDIATE TRANSACTION")
for (indiceArquivo, url) in pdfs.enumerated() {
    let nome = url.lastPathComponent
    guard let documento = PDFDocument(url: url) else {
        relatorioObras.append(["arquivo": nome, "status": "falha_abertura"])
        totais["falhas", default: 0] += 1
        print("Falha ao abrir \(nome) | concluídos \(indiceArquivo)/\(pdfs.count) | faltam \(pdfs.count - indiceArquivo)")
        continue
    }

    let slugBase = slug(nome)
    let obraID = idUnico(base: slugBase, usados: &idsUsados)
    let metadados = areaETipo(nome: nome)
    let titulo = nome.replacingOccurrences(of: ".pdf", with: "")
    let assuntosJSON = String(data: try JSONSerialization.data(withJSONObject: metadados.assuntos), encoding: .utf8) ?? "[]"
    inserir(
        "INSERT INTO rag_obras (id, area, tipo, titulo, autor, origem, edicao, assuntos_json, data_importacao) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
            { bindText($0, $1, obraID) },
            { bindText($0, $1, metadados.area) },
            { bindText($0, $1, metadados.tipo) },
            { bindText($0, $1, titulo) },
            { bindText($0, $1, nil) },
            { bindText($0, $1, nome) },
            { bindText($0, $1, nil) },
            { bindText($0, $1, assuntosJSON) },
            { bindDouble($0, $1, Date().timeIntervalSince1970) }
        ]
    )

    var paginasComTexto = 0
    var totalParagrafos = 0
    var totalNotas = 0
    var totalImagens = 0
    var paginasVazias: [Int] = []

    for indicePagina in 0..<documento.pageCount {
        guard let pagina = documento.page(at: indicePagina) else { continue }
        let numeroPagina = indicePagina + 1
        let bounds = pagina.bounds(for: .mediaBox)
        let texto = normalizarTexto(pagina.string ?? "")
        if texto.isEmpty { paginasVazias.append(numeroPagina) } else { paginasComTexto += 1 }

        let partes = separarTextoERodape(texto)
        let blocos = paragrafos(partes.principal)
        let notasPagina = notas(partes.rodape)
        let paginaID = "\(obraID)-pagina-\(numeroPagina)"

        inserir(
            "INSERT INTO rag_paginas (id, obra_id, numero_original, titulo, texto_integral, largura, altura) VALUES (?, ?, ?, ?, ?, ?, ?)",
            [
                { bindText($0, $1, paginaID) },
                { bindText($0, $1, obraID) },
                { bindInt($0, $1, numeroPagina) },
                { bindText($0, $1, nil) },
                { bindText($0, $1, texto) },
                { bindDouble($0, $1, Double(bounds.width)) },
                { bindDouble($0, $1, Double(bounds.height)) }
            ]
        )

        for (ordem, bloco) in blocos.enumerated() {
            let blocoID = "\(obraID)-p\(numeroPagina)-b\(ordem + 1)"
            inserir(
                "INSERT INTO rag_paragrafos (id, obra_id, pagina, ordem, texto, capitulo, secao, temas_json, palavras_chave_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    { bindText($0, $1, blocoID) },
                    { bindText($0, $1, obraID) },
                    { bindInt($0, $1, numeroPagina) },
                    { bindInt($0, $1, ordem + 1) },
                    { bindText($0, $1, bloco) },
                    { bindText($0, $1, nil) },
                    { bindText($0, $1, nil) },
                    { bindText($0, $1, assuntosJSON) },
                    { bindText($0, $1, assuntosJSON) }
                ]
            )
            inserir(
                "INSERT INTO rag_fts (bloco_id, obra_id, titulo_obra, area, pagina, texto) VALUES (?, ?, ?, ?, ?, ?)",
                [
                    { bindText($0, $1, blocoID) },
                    { bindText($0, $1, obraID) },
                    { bindText($0, $1, titulo) },
                    { bindText($0, $1, metadados.area) },
                    { bindInt($0, $1, numeroPagina) },
                    { bindText($0, $1, bloco) }
                ]
            )
        }
        totalParagrafos += blocos.count

        for (indiceNota, nota) in notasPagina.enumerated() {
            inserir(
                "INSERT INTO rag_notas (id, obra_id, pagina, numero, texto) VALUES (?, ?, ?, ?, ?)",
                [
                    { bindText($0, $1, "\(obraID)-p\(numeroPagina)-nota-\(nota.numero)-\(indiceNota + 1)") },
                    { bindText($0, $1, obraID) },
                    { bindInt($0, $1, numeroPagina) },
                    { bindText($0, $1, nota.numero) },
                    { bindText($0, $1, nota.texto) }
                ]
            )
        }
        totalNotas += notasPagina.count

        if bounds.width > 0, bounds.height > 0 {
            inserir(
                "INSERT INTO rag_imagens (id, obra_id, pagina, caminho_relativo, largura, altura, descricao_ocr) VALUES (?, ?, ?, ?, ?, ?, ?)",
                [
                    { bindText($0, $1, "\(obraID)-facsimile-\(numeroPagina)") },
                    { bindText($0, $1, obraID) },
                    { bindInt($0, $1, numeroPagina) },
                    { bindText($0, $1, "facsimiles/\(obraID)/pagina-\(String(format: "%04d", numeroPagina)).jpg") },
                    { bindDouble($0, $1, Double(bounds.width)) },
                    { bindDouble($0, $1, Double(bounds.height)) },
                    { bindText($0, $1, nil) }
                ]
            )
            totalImagens += 1
        }
    }

    totais["obras", default: 0] += 1
    totais["paginas", default: 0] += documento.pageCount
    totais["paginasComTexto", default: 0] += paginasComTexto
    totais["paragrafos", default: 0] += totalParagrafos
    totais["notas", default: 0] += totalNotas
    totais["imagens", default: 0] += totalImagens

    relatorioObras.append([
        "arquivo": nome,
        "obraID": obraID,
        "slugBase": slugBase,
        "area": metadados.area,
        "tipo": metadados.tipo,
        "status": "importado",
        "paginas": documento.pageCount,
        "paginasComTexto": paginasComTexto,
        "paginasVazias": paginasVazias,
        "paragrafos": totalParagrafos,
        "notas": totalNotas,
        "facsimilesPlanejados": totalImagens
    ])

    let concluidos = indiceArquivo + 1
    print("Importado \(concluidos)/\(pdfs.count): \(nome) | faltam \(pdfs.count - concluidos)")
    fflush(stdout)
}
executar("COMMIT")

let relatorio: [String: Any] = [
    "data": ISO8601DateFormatter().string(from: Date()),
    "pastaOrigem": pastaOCR.path,
    "banco": bancoURL.path,
    "totalPDFsDisponiveis": todosPDFs.count,
    "totalPDFsProcessados": pdfs.count,
    "totais": totais,
    "obras": relatorioObras
]
let json = try JSONSerialization.data(withJSONObject: relatorio, options: [.prettyPrinted, .sortedKeys])
try json.write(to: relatorioURL)
print("Relatorio final: \(relatorioURL.path)")
print("Banco final: \(bancoURL.path)")
