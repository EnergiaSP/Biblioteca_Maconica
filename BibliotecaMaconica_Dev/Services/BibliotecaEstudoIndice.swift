import Foundation
import SQLite3

/// Scores study themes straight from the FTS index of a downloaded package, so collections and
/// study paths consider every page without reading each page's text into memory.
/// Applies the shared rule of `RegrasEstudo`: whole words, distinct keywords first, then occurrences.
enum BibliotecaEstudoIndice {
    struct Referencia: Hashable {
        let obraID: String
        let pagina: Int
    }

    struct Pontuacao {
        let referencia: Referencia
        let temas: Int
        let ocorrencias: Int
    }

    enum Erro: LocalizedError {
        case falhaSQL(String)

        var errorDescription: String? {
            switch self {
            case .falhaSQL(let detalhe):
                "Falha ao consultar o índice de estudos. \(detalhe)"
            }
        }
    }

    /// Returns, for each rule, its `limites[i]` best pages among `obras` in the package at `url`.
    /// `regras` holds keywords already normalized by `RegrasEstudo.palavrasChave`.
    static func pontuar(url: URL, obras: Set<String>, regras: [Set<String>], limites: [Int]) throws -> [[Pontuacao]] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let detalhe = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Erro desconhecido."
            sqlite3_close(db)
            throw Erro.falhaSQL(detalhe)
        }
        defer { sqlite3_close(db) }

        // Instance rows (term, doc, column, offset) let SQLite count words and phrases per page.
        try executar(db, "CREATE VIRTUAL TABLE temp.vocab USING fts5vocab(main, rag_fts, 'instance')")

        let todas = regras.reduce(into: Set<String>()) { $0.formUnion($1) }

        // Counts are gathered per index block first; blocks are mapped to pages once at the end.
        var porBloco: [Int64: [String: Int]] = [:]
        let simples = todas.filter { !$0.contains(" ") }.sorted()
        if !simples.isEmpty {
            let sql = """
            SELECT doc, term, count(*) FROM temp.vocab
            WHERE col = 'texto' AND term IN (\(marcadores(simples.count)))
            GROUP BY doc, term
            """
            try consultar(db, sql, simples) { statement in
                porBloco[sqlite3_column_int64(statement, 0), default: [:]][texto(statement, 1), default: 0] += Int(sqlite3_column_int(statement, 2))
            }
        }

        for expressao in todas.filter({ $0.contains(" ") }).sorted() {
            // Consecutive token positions in the same block form the phrase, as in `RegrasEstudo.contarPalavras`.
            let palavras = expressao.split(separator: " ").map(String.init)
            var posicoes: [Set<Posicao>] = []
            for palavra in palavras {
                var conjunto = Set<Posicao>()
                try consultar(db, "SELECT doc, offset FROM temp.vocab WHERE col = 'texto' AND term = ?", [palavra]) { statement in
                    conjunto.insert(Posicao(doc: sqlite3_column_int64(statement, 0), deslocamento: Int(sqlite3_column_int(statement, 1))))
                }
                posicoes.append(conjunto)
            }
            for inicio in posicoes[0] where (1..<palavras.count).allSatisfy({
                posicoes[$0].contains(Posicao(doc: inicio.doc, deslocamento: inicio.deslocamento + $0))
            }) {
                porBloco[inicio.doc, default: [:]][expressao, default: 0] += 1
            }
        }

        var contagens: [Referencia: [String: Int]] = [:]
        if !porBloco.isEmpty {
            // Pages split into several index blocks are summed per page.
            try consultar(db, try consultaPaginasDosBlocos(db), []) { statement in
                guard let porPalavra = porBloco[sqlite3_column_int64(statement, 0)] else { return }
                let obra = texto(statement, 1)
                guard obras.contains(obra) else { return }
                let referencia = Referencia(obraID: obra, pagina: Int(sqlite3_column_int(statement, 2)))
                contagens[referencia, default: [:]].merge(porPalavra, uniquingKeysWith: +)
            }
        }

        // Footnotes are not in the index; they are short, so they are counted in memory.
        let contador = RegrasEstudo.ContadorPalavras(palavras: todas)
        try consultar(db, "SELECT obra_id, pagina, numero, texto FROM rag_notas", []) { statement in
            let obra = texto(statement, 0)
            guard obras.contains(obra) else { return }
            let encontradas = contador.contar(RegrasEstudo.normalizar(texto(statement, 2) + " " + texto(statement, 3)))
            guard !encontradas.isEmpty else { return }
            let referencia = Referencia(obraID: obra, pagina: Int(sqlite3_column_int(statement, 1)))
            contagens[referencia, default: [:]].merge(encontradas, uniquingKeysWith: +)
        }

        // Each page is visited once and scores every rule that shares one of its words.
        var regrasPorPalavra: [String: [Int]] = [:]
        for (indice, palavras) in regras.enumerated() {
            for palavra in palavras { regrasPorPalavra[palavra, default: []].append(indice) }
        }
        var melhores = Array(repeating: [Pontuacao](), count: regras.count)
        var temas = Array(repeating: 0, count: regras.count)
        var ocorrencias = Array(repeating: 0, count: regras.count)
        for (referencia, porPalavra) in contagens {
            var tocadas: [Int] = []
            for (palavra, quantidade) in porPalavra where quantidade > 0 {
                for indice in regrasPorPalavra[palavra] ?? [] {
                    if temas[indice] == 0 { tocadas.append(indice) }
                    temas[indice] += 1
                    ocorrencias[indice] += quantidade
                }
            }
            for indice in tocadas {
                inserir(Pontuacao(referencia: referencia, temas: temas[indice], ocorrencias: ocorrencias[indice]),
                        em: &melhores[indice], limite: limites[indice])
                temas[indice] = 0
                ocorrencias[indice] = 0
            }
        }
        return melhores
    }

    /// Keeps `lista` sorted with at most `limite` entries without sorting every candidate.
    private static func inserir(_ pontuacao: Pontuacao, em lista: inout [Pontuacao], limite: Int) {
        guard limite > 0 else { return }
        if lista.count == limite, let ultima = lista.last, !precede(pontuacao, ultima) { return }
        let posicao = lista.firstIndex { precede(pontuacao, $0) } ?? lista.endIndex
        lista.insert(pontuacao, at: posicao)
        if lista.count > limite { lista.removeLast() }
    }

    /// Keeps the best pages of each rule across packages; same order as `RegrasEstudo`.
    static func combinar(_ atual: [[Pontuacao]], com novas: [[Pontuacao]], limites: [Int]) -> [[Pontuacao]] {
        atual.indices.map { indice in
            Array((atual[indice] + novas[indice]).sorted(by: precede).prefix(max(0, limites[indice])))
        }
    }

    static func precede(_ lhs: Pontuacao, _ rhs: Pontuacao) -> Bool {
        if lhs.temas != rhs.temas { return lhs.temas > rhs.temas }
        if lhs.ocorrencias != rhs.ocorrencias { return lhs.ocorrencias > rhs.ocorrencias }
        if lhs.referencia.obraID != rhs.referencia.obraID { return lhs.referencia.obraID < rhs.referencia.obraID }
        return lhs.referencia.pagina < rhs.referencia.pagina
    }

    private struct Posicao: Hashable {
        let doc: Int64
        let deslocamento: Int
    }

    /// Lists every index block with its work and page. Catalog packages keep both in the FTS content
    /// table; indexes created by the Android PDF importer only keep the block id, used to reach the paragraph.
    private static func consultaPaginasDosBlocos(_ db: OpaquePointer?) throws -> String {
        var colunas: [String] = []
        try consultar(db, "PRAGMA table_info(rag_fts)", []) { colunas.append(texto($0, 1)) }
        if let obra = colunas.firstIndex(of: "obra_id"), let pagina = colunas.firstIndex(of: "pagina") {
            // Reading these columns from the content table avoids loading each page's full text.
            return "SELECT id, c\(obra), c\(pagina) FROM rag_fts_content"
        }
        guard let bloco = colunas.firstIndex(of: "bloco_id") else {
            throw Erro.falhaSQL("Índice sem identificação de bloco.")
        }
        let mesmaObra = colunas.firstIndex(of: "obra_id").map { " AND p.obra_id = f.c\($0)" } ?? ""
        return "SELECT f.id, p.obra_id, p.pagina FROM rag_fts_content f JOIN rag_paragrafos p ON p.id = f.c\(bloco)\(mesmaObra)"
    }

    private static func marcadores(_ quantidade: Int) -> String {
        Array(repeating: "?", count: quantidade).joined(separator: ",")
    }

    private static func executar(_ db: OpaquePointer?, _ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw Erro.falhaSQL(String(cString: sqlite3_errmsg(db)))
        }
    }

    private static func consultar(_ db: OpaquePointer?, _ sql: String, _ valores: [String], linha: (OpaquePointer?) -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw Erro.falhaSQL(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        let transitorio = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (indice, valor) in valores.enumerated() {
            sqlite3_bind_text(statement, Int32(indice + 1), valor, -1, transitorio)
        }
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            try Task.checkCancellation()
            linha(statement)
            status = sqlite3_step(statement)
        }
        guard status == SQLITE_DONE else {
            throw Erro.falhaSQL(String(cString: sqlite3_errmsg(db)))
        }
    }

    private static func texto(_ statement: OpaquePointer?, _ coluna: Int32) -> String {
        sqlite3_column_text(statement, coluna).map { String(cString: $0) } ?? ""
    }
}

extension BibliotecaRAGCatalogService {
    /// Scores every page of the downloaded packages that hold `obraIDs`. Packages are independent
    /// files, so they are scored in parallel, each on its own read-only connection.
    /// Packages that fail are reported in `falhas` so the caller can warn instead of hiding them.
    func pontuarEstudo(obraIDs: Set<String>, regras: [Set<String>], limites: [Int])
        throws -> (pontuacoes: [[BibliotecaEstudoIndice.Pontuacao]], falhas: [String]) {
        let trabalhos = pacotes.compactMap { pacote -> (titulo: String, url: URL, obras: Set<String>)? in
            let obras = Set(pacote.obraIDs).intersection(obraIDs)
            guard !obras.isEmpty, let url = urlPacote(pacote) else { return nil }
            return (pacote.titulo, url, obras)
        }
        let resultados = ResultadosParalelos(quantidade: trabalhos.count)
        DispatchQueue.concurrentPerform(iterations: trabalhos.count) { indice in
            guard !Task.isCancelled else { return }
            let trabalho = trabalhos[indice]
            resultados.guardar(indice, Result {
                try BibliotecaEstudoIndice.pontuar(url: trabalho.url, obras: trabalho.obras, regras: regras, limites: limites)
            })
        }
        try Task.checkCancellation()

        var resultado = Array(repeating: [BibliotecaEstudoIndice.Pontuacao](), count: regras.count)
        var falhas: [String] = []
        // Merged in package order so the outcome does not depend on thread timing.
        for (indice, saida) in resultados.todos().enumerated() {
            switch saida {
            case .success(let pontuacoes):
                resultado = BibliotecaEstudoIndice.combinar(resultado, com: pontuacoes, limites: limites)
            case .failure, .none:
                falhas.append(trabalhos[indice].titulo)
            }
        }
        return (resultado, falhas)
    }
}

private final class ResultadosParalelos: @unchecked Sendable {
    private let trava = NSLock()
    private var itens: [Result<[[BibliotecaEstudoIndice.Pontuacao]], Error>?]

    init(quantidade: Int) {
        itens = Array(repeating: nil, count: quantidade)
    }

    func guardar(_ indice: Int, _ resultado: Result<[[BibliotecaEstudoIndice.Pontuacao]], Error>) {
        trava.lock()
        itens[indice] = resultado
        trava.unlock()
    }

    func todos() -> [Result<[[BibliotecaEstudoIndice.Pontuacao]], Error>?] {
        trava.lock()
        defer { trava.unlock() }
        return itens
    }
}
