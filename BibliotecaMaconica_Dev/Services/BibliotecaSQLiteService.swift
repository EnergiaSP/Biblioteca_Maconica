import Foundation
import SQLite3

final class BibliotecaSQLiteService {
    enum Erro: LocalizedError {
        case naoAbriuBanco(String)
        case falhaSQL(String)
        case falhaPreparar(String)
        case falhaBind(String)

        var errorDescription: String? {
            switch self {
            case .naoAbriuBanco(let detalhe):
                "Nao foi possivel abrir o banco da biblioteca. \(detalhe)"
            case .falhaSQL(let detalhe):
                "Falha ao executar SQL. \(detalhe)"
            case .falhaPreparar(let detalhe):
                "Falha ao preparar consulta. \(detalhe)"
            case .falhaBind(let detalhe):
                "Falha ao gravar parametro no banco. \(detalhe)"
            }
        }
    }

    private let url: URL
    private let somenteLeitura: Bool
    private var db: OpaquePointer?

    init(url: URL = BibliotecaSQLiteService.urlBancoPadrao(), somenteLeitura: Bool = false) throws {
        self.url = url
        self.somenteLeitura = somenteLeitura

        if somenteLeitura == false {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        let flags = somenteLeitura
            ? SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
            : SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK else {
            let detalhe = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Erro desconhecido."
            sqlite3_close(db)
            db = nil
            throw Erro.naoAbriuBanco(detalhe)
        }

        do {
            try configurarBanco()
            if somenteLeitura == false {
                try criarSchema()
                try repararIndiceLegado()
            }
        } catch {
            sqlite3_close(db)
            db = nil
            throw error
        }
    }

    deinit {
        sqlite3_close(db)
    }

    static func urlBancoPadrao() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("BibliotecaMaconica", isDirectory: true)
            .appendingPathComponent("biblioteca-rag.sqlite")
    }

    func substituirObra(
        obra: BibliotecaRAGObra,
        paginas: [BibliotecaRAGPagina],
        paragrafos: [BibliotecaRAGParagrafo],
        notas: [BibliotecaRAGNotaRodape],
        imagens: [BibliotecaRAGImagem]
    ) throws {
        try transacao {
            try executar("DELETE FROM rag_fts WHERE obra_id = ?", [.text(obra.id)])
            try executar("DELETE FROM rag_imagens WHERE obra_id = ?", [.text(obra.id)])
            try executar("DELETE FROM rag_notas WHERE obra_id = ?", [.text(obra.id)])
            try executar("DELETE FROM rag_paragrafos WHERE obra_id = ?", [.text(obra.id)])
            try executar("DELETE FROM rag_paginas WHERE obra_id = ?", [.text(obra.id)])
            try executar("DELETE FROM rag_obras WHERE id = ?", [.text(obra.id)])
            try inserirObra(obra)

            for pagina in paginas {
                try inserirPagina(pagina)
            }

            for paragrafo in paragrafos {
                try inserirParagrafo(paragrafo)
            }

            for nota in notas {
                try inserirNota(nota)
            }

            for imagem in imagens {
                try inserirImagem(imagem)
            }
        }
    }

    func buscarTexto(
        termo: String,
        area: BibliotecaArea? = nil,
        obraID: String? = nil,
        limite: Int = 50,
        obrasExcluidas: Set<String> = []
    ) throws -> [BibliotecaRAGResultadoBusca] {
        let busca = termo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard busca.isEmpty == false else {
            return []
        }

        let consultaFTS = Self.consultaFTSSegura(busca)
        var filtros: [String] = []
        var parametros: [SQLValor] = [SQLValor.text(consultaFTS)]

        if let area {
            filtros.append("o.area = ?")
            parametros.append(.text(area.rawValue))
        }

        if let obraID {
            filtros.append("p.obra_id = ?")
            parametros.append(.text(obraID))
        }

        for id in obrasExcluidas.sorted() {
            filtros.append("p.obra_id != ?")
            parametros.append(.text(id))
        }

        parametros.append(.int(max(0, limite)))

        let whereExtra = filtros.isEmpty ? "" : " AND " + filtros.joined(separator: " AND ")
        let sql = """
        SELECT p.id, p.obra_id, o.titulo, o.area, p.pagina, p.texto, bm25(rag_fts) AS ranking
        FROM rag_fts
        JOIN rag_paragrafos p ON p.id = rag_fts.bloco_id AND p.obra_id = rag_fts.obra_id
        JOIN rag_obras o ON o.id = p.obra_id
        WHERE rag_fts MATCH ?\(whereExtra)
        ORDER BY ranking, p.obra_id, p.pagina, CAST(p.id AS TEXT)
        LIMIT ?
        """

        let paragrafos = try consultar(sql, parametros) { statement in
            let blocoID = colunaTexto(statement, 0)
            let obraID = colunaTexto(statement, 1)
            let titulo = colunaTexto(statement, 2)
            let areaRaw = colunaTexto(statement, 3)
            let area = BibliotecaArea(rawValue: areaRaw) ?? .bibliotecaMaconica
            let pagina = Int(sqlite3_column_int(statement, 4))
            let trecho = colunaTexto(statement, 5)
            let ranking = sqlite3_column_double(statement, 6)

            return BibliotecaRAGResultadoBusca(
                id: "\(obraID)-\(blocoID)",
                obraID: obraID,
                tituloObra: titulo,
                area: area,
                pagina: pagina,
                blocoID: blocoID,
                trecho: trecho,
                ranking: ranking
            )
        }
        let notas = try BibliotecaNotasSearch.buscar(source: url, consulta: consultaFTS, area: area,
            obraID: obraID, limite: limite, excluidas: obrasExcluidas)
        return Array((paragrafos + notas).sorted {
            if $0.ranking != $1.ranking { return $0.ranking < $1.ranking }
            if $0.obraID != $1.obraID { return $0.obraID < $1.obraID }
            if $0.pagina != $1.pagina { return $0.pagina < $1.pagina }
            return $0.blocoID < $1.blocoID
        }.prefix(max(0, limite)))
    }

    func buscarResultadosBiblioteca(
        termo: String,
        escopo: BibliotecaBuscaEscopo,
        area: BibliotecaArea?,
        obraID: String?,
        limite: Int = 80,
        obrasExcluidas: Set<String> = [],
        incluirNotas: Bool = true,
        filtro: BibliotecaFiltroMetadados = .init()
    ) throws -> [BibliotecaResultadoBusca] {
        let areaBusca: BibliotecaArea?
        switch escopo {
        case .appTodo:
            areaBusca = nil
        case .area:
            areaBusca = area
        case .obraAtual:
            areaBusca = nil
        }

        let obras = try carregarMetadadosObras()
        let metadados = Dictionary(uniqueKeysWithValues: obras.map { ($0.id, $0) })
        let excluidas = obrasExcluidas.union(obras.filter { !filtro.corresponde($0) }.map(\.id))
        let resultados = try buscarTexto(
            termo: termo,
            area: areaBusca,
            obraID: escopo == .obraAtual ? obraID : nil,
            limite: limite,
            obrasExcluidas: excluidas
        )

        var notasPorObra: [String: [Int: [String]]] = [:]
        for (id, trechos) in Dictionary(grouping: incluirNotas ? resultados : [], by: \.obraID) {
            notasPorObra[id] = try carregarNotasPorPagina(
                obraID: id, paginas: Array(Set(trechos.map(\.pagina)))
            )
        }
        return resultados.map { resultado in
            let obra = metadados[resultado.obraID] ?? BibliotecaObra(
                id: resultado.obraID,
                titulo: resultado.tituloObra,
                autor: nil,
                area: resultado.area,
                tipo: resultado.area == .dicionariosMaconicos ? .dicionario : .livro,
                recursoJSON: nil,
                descricao: "Obra importada para a biblioteca estruturada.",
                assuntos: [],
                ativa: true
            )
            let item = BreviarioItem(
                id: Self.idEstavel(texto: "\(resultado.obraID)-pagina-\(resultado.pagina)"),
                data: "P\(resultado.pagina)",
                titulo: "Página \(resultado.pagina)",
                frase: "",
                texto: resultado.trecho,
                rodape: notasPorObra[resultado.obraID]?[resultado.pagina]?.joined(separator: "\n"),
                pagina: resultado.pagina,
                obraID: resultado.obraID
            )

            return BibliotecaResultadoBusca(
                obra: obra,
                item: item,
                contexto: Self.contextoBusca(termo: termo, em: resultado.trecho),
                ranking: resultado.ranking,
                blocoID: resultado.blocoID
            )
        }
    }

    private func carregarMetadadosObras() throws -> [BibliotecaObra] {
        try consultar("SELECT id, titulo, autor, area, tipo, assuntos_json FROM rag_obras", []) { statement in
            let assuntos = try JSONDecoder().decode([String].self, from: Data(colunaTexto(statement, 5).utf8))
            return BibliotecaObra(id: colunaTexto(statement, 0), titulo: colunaTexto(statement, 1),
                autor: sqlite3_column_type(statement, 2) == SQLITE_NULL ? nil : colunaTexto(statement, 2),
                area: BibliotecaArea(rawValue: colunaTexto(statement, 3)) ?? .bibliotecaMaconica,
                tipo: BibliotecaObraTipo(rawValue: colunaTexto(statement, 4)) ?? .livro,
                recursoJSON: nil, descricao: "Obra importada para a biblioteca estruturada.", assuntos: assuntos, ativa: true)
        }
    }

    func carregarIndicePaginas(obraID: String) throws -> [BreviarioItem] {
        try consultar("SELECT numero_original, COALESCE(titulo, '') FROM rag_paginas WHERE obra_id = ? ORDER BY numero_original", [.text(obraID)]) { statement in
            let page = Int(sqlite3_column_int(statement, 0))
            return BreviarioItem(id: Self.idEstavel(texto: "\(obraID)-pagina-\(page)"), data: "P\(page)", titulo: colunaTexto(statement, 1), frase: "", texto: "", pagina: page, obraID: obraID)
        }
    }

    func carregarItensBiblioteca(obraID: String, limite: Int? = nil, paginas: [Int]? = nil) throws -> [BreviarioItem] {
        let paginas = paginas.map { Array(Set($0.filter { $0 > 0 })).sorted() }
        if paginas?.isEmpty == true { return [] }
        var sql = """
        SELECT
            p.numero_original,
            COALESCE(p.titulo, ''),
            p.texto_integral,
            o.titulo,
            COALESCE(o.autor, '')
        FROM rag_paginas p
        JOIN rag_obras o ON o.id = p.obra_id
        WHERE p.obra_id = ?
        """
        var parametros: [SQLValor] = [.text(obraID)]
        if let paginas {
            sql += " AND p.numero_original IN (\(Array(repeating: "?", count: paginas.count).joined(separator: ",")))"
            parametros.append(contentsOf: paginas.map(SQLValor.int))
        }
        sql += " ORDER BY p.numero_original"

        if let limite {
            sql += " LIMIT ?"
            parametros.append(.int(limite))
        }

        let notasPorPagina = try carregarNotasPorPagina(obraID: obraID, paginas: paginas)
        return try consultar(sql, parametros) { statement in
            let pagina = Int(sqlite3_column_int(statement, 0))
            let tituloPagina = colunaTexto(statement, 1)
            let texto = colunaTexto(statement, 2)
            let tituloObra = colunaTexto(statement, 3)
            let autor = Self.nilSeVazio(colunaTexto(statement, 4))
            let rodape = Self.nilSeVazio(notasPorPagina[pagina]?.joined(separator: "\n") ?? "")

            return BreviarioItem(
                id: Self.idEstavel(texto: "\(obraID)-pagina-\(pagina)"),
                data: "P\(pagina)",
                titulo: Self.nilSeVazio(tituloPagina) ?? "Página \(pagina)",
                frase: tituloObra,
                texto: texto,
                rodape: rodape,
                autor: autor,
                pagina: pagina,
                obraID: obraID
            )
        }
    }

    func percorrerItensBiblioteca(obraID: String, tamanhoLote: Int = 100, receber: ([BreviarioItem]) -> Bool) throws {
        var ultimaPagina = 0
        while !Task.isCancelled {
            let paginas = try consultar("SELECT numero_original FROM rag_paginas WHERE obra_id = ? AND numero_original > ? ORDER BY numero_original LIMIT ?",
                [.text(obraID), .int(ultimaPagina), .int(min(200, max(1, tamanhoLote)))]) {
                Int(sqlite3_column_int($0, 0))
            }
            guard let ultima = paginas.last else { return }
            let itens = try carregarItensBiblioteca(obraID: obraID, paginas: paginas)
            guard receber(itens) else { return }
            ultimaPagina = ultima
        }
    }

    func carregarNotasPorPagina(obraID: String, paginas: [Int]?) throws -> [Int: [String]] {
        var sql = """
            SELECT pagina, numero, texto
            FROM rag_notas
            WHERE obra_id = ?
            """
        var parametros: [SQLValor] = [.text(obraID)]
        if let paginas {
            sql += " AND pagina IN (\(Array(repeating: "?", count: paginas.count).joined(separator: ",")))"
            parametros.append(contentsOf: paginas.map(SQLValor.int))
        }
        sql += " ORDER BY pagina, numero"
        let notas = try consultar(sql, parametros) { statement in
            (
                pagina: Int(sqlite3_column_int(statement, 0)),
                numero: colunaTexto(statement, 1),
                texto: colunaTexto(statement, 2)
            )
        }

        return notas.reduce(into: [Int: [String]]()) { parcial, nota in
            let linha = nota.numero.isEmpty ? nota.texto : "\(nota.numero) \(nota.texto)"
            parcial[nota.pagina, default: []].append(linha)
        }
    }

    private static func nilSeVazio(_ texto: String) -> String? {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        return limpo.isEmpty ? nil : limpo
    }

    private func configurarBanco() throws {
        if somenteLeitura {
            try executar("PRAGMA query_only = ON")
            try executar("PRAGMA temp_store = MEMORY")
            return
        }

        try executar("PRAGMA journal_mode = WAL")
        try executar("PRAGMA synchronous = NORMAL")
        try executar("PRAGMA temp_store = MEMORY")
        try executar("PRAGMA foreign_keys = ON")
    }

    private func criarSchema() throws {
        try executar("""
        CREATE TABLE IF NOT EXISTS rag_obras (
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

        try executar("""
        CREATE TABLE IF NOT EXISTS rag_paginas (
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

        try executar("""
        CREATE TABLE IF NOT EXISTS rag_paragrafos (
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

        try executar("""
        CREATE TABLE IF NOT EXISTS rag_notas (
            id TEXT PRIMARY KEY,
            obra_id TEXT NOT NULL REFERENCES rag_obras(id) ON DELETE CASCADE,
            pagina INTEGER NOT NULL,
            numero TEXT NOT NULL,
            texto TEXT NOT NULL
        )
        """)

        try executar("""
        CREATE TABLE IF NOT EXISTS rag_imagens (
            id TEXT PRIMARY KEY,
            obra_id TEXT NOT NULL REFERENCES rag_obras(id) ON DELETE CASCADE,
            pagina INTEGER NOT NULL,
            caminho_relativo TEXT NOT NULL,
            largura REAL NOT NULL,
            altura REAL NOT NULL,
            descricao_ocr TEXT
        )
        """)

        try executar("""
        CREATE VIRTUAL TABLE IF NOT EXISTS rag_fts USING fts5(
            bloco_id UNINDEXED,
            obra_id UNINDEXED,
            titulo_obra,
            area UNINDEXED,
            pagina UNINDEXED,
            texto,
            tokenize = 'unicode61 remove_diacritics 2'
        )
        """)

        try executar("CREATE INDEX IF NOT EXISTS idx_rag_paginas_obra ON rag_paginas(obra_id, numero_original)")
        try executar("CREATE INDEX IF NOT EXISTS idx_rag_paragrafos_obra_pagina ON rag_paragrafos(obra_id, pagina)")
        try executar("CREATE INDEX IF NOT EXISTS idx_rag_notas_obra_pagina ON rag_notas(obra_id, pagina)")
    }

    private func repararIndiceLegado() throws {
        try executar("CREATE TABLE IF NOT EXISTS rag_migracoes (id TEXT PRIMARY KEY)")
        let migracao = "fts_reimportacao_v1"
        let aplicada = try consultar("SELECT id FROM rag_migracoes WHERE id = ?", [.text(migracao)]) {
            colunaTexto($0, 0)
        }
        guard aplicada.isEmpty else { return }
        // Rebuild derived data once; original content and read-only downloaded packages are untouched.
        try transacao {
            try executar("DELETE FROM rag_fts")
            try executar("""
            INSERT INTO rag_fts (bloco_id, obra_id, titulo_obra, area, pagina, texto)
            SELECT p.id, p.obra_id, o.titulo, o.area, p.pagina, p.texto
            FROM rag_paragrafos p JOIN rag_obras o ON o.id = p.obra_id
            """)
            try executar("INSERT INTO rag_migracoes(id) VALUES (?)", [.text(migracao)])
        }
    }

    private func inserirObra(_ obra: BibliotecaRAGObra) throws {
        try executar(
            """
            INSERT INTO rag_obras
            (id, area, tipo, titulo, autor, origem, edicao, assuntos_json, data_importacao)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(obra.id),
                .text(obra.area.rawValue),
                .text(obra.tipo.rawValue),
                .text(obra.titulo),
                .optionalText(obra.autor),
                .optionalText(obra.origem),
                .optionalText(obra.edicao),
                .text(jsonString(obra.assuntos)),
                .double(obra.dataImportacao.timeIntervalSince1970)
            ]
        )
    }

    private func inserirPagina(_ pagina: BibliotecaRAGPagina) throws {
        try executar(
            """
            INSERT INTO rag_paginas
            (id, obra_id, numero_original, titulo, texto_integral, largura, altura)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(pagina.id),
                .text(pagina.obraID),
                .int(pagina.numeroOriginal),
                .optionalText(pagina.titulo),
                .text(pagina.textoIntegral),
                .double(pagina.largura),
                .double(pagina.altura)
            ]
        )
    }

    private func inserirParagrafo(_ paragrafo: BibliotecaRAGParagrafo) throws {
        try executar(
            """
            INSERT INTO rag_paragrafos
            (id, obra_id, pagina, ordem, texto, capitulo, secao, temas_json, palavras_chave_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(paragrafo.id),
                .text(paragrafo.obraID),
                .int(paragrafo.pagina),
                .int(paragrafo.ordem),
                .text(paragrafo.texto),
                .optionalText(paragrafo.capitulo),
                .optionalText(paragrafo.secao),
                .text(jsonString(paragrafo.temas)),
                .text(jsonString(paragrafo.palavrasChave))
            ]
        )

        let tituloObra = try tituloObra(id: paragrafo.obraID) ?? ""
        let area = try areaObra(id: paragrafo.obraID)?.rawValue ?? ""

        try executar(
            """
            INSERT INTO rag_fts
            (bloco_id, obra_id, titulo_obra, area, pagina, texto)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [
                .text(paragrafo.id),
                .text(paragrafo.obraID),
                .text(tituloObra),
                .text(area),
                .int(paragrafo.pagina),
                .text(paragrafo.texto)
            ]
        )
    }

    private func inserirNota(_ nota: BibliotecaRAGNotaRodape) throws {
        try executar(
            """
            INSERT INTO rag_notas
            (id, obra_id, pagina, numero, texto)
            VALUES (?, ?, ?, ?, ?)
            """,
            [
                .text(nota.id),
                .text(nota.obraID),
                .int(nota.pagina),
                .text(nota.numero),
                .text(nota.texto)
            ]
        )
    }

    private func inserirImagem(_ imagem: BibliotecaRAGImagem) throws {
        try executar(
            """
            INSERT INTO rag_imagens
            (id, obra_id, pagina, caminho_relativo, largura, altura, descricao_ocr)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(imagem.id),
                .text(imagem.obraID),
                .int(imagem.pagina),
                .text(imagem.caminhoRelativo),
                .double(imagem.largura),
                .double(imagem.altura),
                .optionalText(imagem.descricaoOCR)
            ]
        )
    }

    private func tituloObra(id: String) throws -> String? {
        try consultar("SELECT titulo FROM rag_obras WHERE id = ? LIMIT 1", [.text(id)]) { statement in
            colunaTexto(statement, 0)
        }.first
    }

    private func areaObra(id: String) throws -> BibliotecaArea? {
        let areaRaw = try consultar("SELECT area FROM rag_obras WHERE id = ? LIMIT 1", [.text(id)]) { statement in
            colunaTexto(statement, 0)
        }.first
        return areaRaw.flatMap(BibliotecaArea.init(rawValue:))
    }

    private func transacao(_ operacao: () throws -> Void) throws {
        try executar("BEGIN IMMEDIATE TRANSACTION")
        do {
            try operacao()
            try executar("COMMIT")
        } catch {
            try? executar("ROLLBACK")
            throw error
        }
    }

    private func executar(_ sql: String, _ valores: [SQLValor] = []) throws {
        if valores.isEmpty {
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw Erro.falhaSQL(mensagemErro)
            }
            return
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw Erro.falhaPreparar(mensagemErro)
        }
        defer { sqlite3_finalize(statement) }

        try bind(valores, em: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw Erro.falhaSQL(mensagemErro)
        }
    }

    private func consultar<T>(
        _ sql: String,
        _ valores: [SQLValor] = [],
        mapear: (OpaquePointer?) throws -> T
    ) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw Erro.falhaPreparar(mensagemErro)
        }
        defer { sqlite3_finalize(statement) }

        try bind(valores, em: statement)

        var resultado: [T] = []
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            resultado.append(try mapear(statement))
            status = sqlite3_step(statement)
        }
        guard status == SQLITE_DONE else {
            throw Erro.falhaSQL(mensagemErro)
        }
        return resultado
    }

    private func bind(_ valores: [SQLValor], em statement: OpaquePointer?) throws {
        for (indice, valor) in valores.enumerated() {
            let posicao = Int32(indice + 1)
            let status: Int32
            switch valor {
            case .text(let texto):
                status = sqlite3_bind_text(statement, posicao, texto, -1, SQLITE_TRANSIENT)
            case .optionalText(let texto):
                if let texto {
                    status = sqlite3_bind_text(statement, posicao, texto, -1, SQLITE_TRANSIENT)
                } else {
                    status = sqlite3_bind_null(statement, posicao)
                }
            case .int(let inteiro):
                status = sqlite3_bind_int64(statement, posicao, sqlite3_int64(inteiro))
            case .double(let numero):
                status = sqlite3_bind_double(statement, posicao, numero)
            }

            guard status == SQLITE_OK else {
                throw Erro.falhaBind(mensagemErro)
            }
        }
    }

    private var mensagemErro: String {
        db.map { String(cString: sqlite3_errmsg($0)) } ?? "Erro desconhecido."
    }

    private func jsonString(_ valores: [String]) -> String {
        guard let data = try? JSONEncoder().encode(valores),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return string
    }

    private static func consultaFTSSegura(_ termo: String) -> String {
        let tokens = termosBusca(termo)

        guard tokens.isEmpty == false else {
            return "\"\(termo.replacingOccurrences(of: "\"", with: "\"\""))\""
        }

        return tokens.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            .joined(separator: " AND ")
    }

    static func termosBusca(_ termo: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #""([^"]+)"|([\p{L}\p{N}]+)"#) else { return [] }
        let texto = termo.lowercased() as NSString
        return regex.matches(in: texto as String, range: NSRange(location: 0, length: texto.length)).compactMap { match in
            if match.range(at: 1).location != NSNotFound {
                let palavras = texto.substring(with: match.range(at: 1)).components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !$0.isEmpty }.joined(separator: " ")
                return palavras.isEmpty ? nil : palavras
            }
            let palavra = texto.substring(with: match.range(at: 2))
            return palavra.count > 1 ? palavra : nil
        }
    }

    static func corresponde(termo: String, texto: String) -> Bool {
        let termos = termosBusca(termo)
        guard !termos.isEmpty else { return false }
        let normalizado = texto.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
        let palavras = " " + normalizado.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ") + " "
        return termos.allSatisfy {
            palavras.contains(" " + $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR")) + " ")
        }
    }

    private static func contextoBusca(termo: String, em texto: String) -> String {
        let textoLimpo = texto.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard let range = textoLimpo.range(of: termo, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return String(textoLimpo.prefix(260))
        }

        let inicio = textoLimpo.index(range.lowerBound, offsetBy: -120, limitedBy: textoLimpo.startIndex) ?? textoLimpo.startIndex
        let fim = textoLimpo.index(range.upperBound, offsetBy: 160, limitedBy: textoLimpo.endIndex) ?? textoLimpo.endIndex
        let prefixo = inicio == textoLimpo.startIndex ? "" : "..."
        let sufixo = fim == textoLimpo.endIndex ? "" : "..."
        return prefixo + String(textoLimpo[inicio..<fim]) + sufixo
    }

    private static func idEstavel(texto: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in texto.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % 900_000_000) + 1
    }
}

private enum SQLValor {
    case text(String)
    case optionalText(String?)
    case int(Int)
    case double(Double)
}

private func colunaTexto(_ statement: OpaquePointer?, _ coluna: Int32) -> String {
    guard let cString = sqlite3_column_text(statement, coluna) else {
        return ""
    }

    return String(cString: cString)
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
