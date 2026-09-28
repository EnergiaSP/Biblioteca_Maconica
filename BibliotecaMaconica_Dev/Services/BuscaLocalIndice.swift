import Foundation
import SQLite3

private let SQLITE_TRANSIENT_LOCAL = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension BibliotecaSQLiteService {
    /// Full-text index of a local work's readings, built once and queried many times. The relevance
    /// is the shared occurrence count, as for downloaded packages.
    final class IndiceLocal: @unchecked Sendable {
        private var db: OpaquePointer?
        private let textos: [String: String]
        private let trava = NSLock()

        init(textos lista: [(chave: String, texto: String)]) throws {
            textos = Dictionary(lista.map { ($0.chave, $0.texto) }, uniquingKeysWith: { primeiro, _ in primeiro })
            guard sqlite3_open(":memory:", &db) == SQLITE_OK else {
                sqlite3_close(db)
                throw Erro.naoAbriuBanco("Índice temporário indisponível.")
            }
            let criar = "CREATE VIRTUAL TABLE local_fts USING fts5(chave UNINDEXED, texto, tokenize = 'unicode61 remove_diacritics 2')"
            guard sqlite3_exec(db, criar, nil, nil, nil) == SQLITE_OK,
                  sqlite3_exec(db, "BEGIN", nil, nil, nil) == SQLITE_OK else {
                throw Erro.falhaSQL(String(cString: sqlite3_errmsg(db)))
            }
            var inserir: OpaquePointer?
            guard sqlite3_prepare_v2(db, "INSERT INTO local_fts VALUES (?, ?)", -1, &inserir, nil) == SQLITE_OK else {
                throw Erro.falhaPreparar(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(inserir) }
            for documento in lista {
                sqlite3_bind_text(inserir, 1, documento.chave, -1, SQLITE_TRANSIENT_LOCAL)
                sqlite3_bind_text(inserir, 2, documento.texto, -1, SQLITE_TRANSIENT_LOCAL)
                guard sqlite3_step(inserir) == SQLITE_DONE else {
                    throw Erro.falhaSQL(String(cString: sqlite3_errmsg(db)))
                }
                sqlite3_reset(inserir)
            }
            sqlite3_exec(db, "COMMIT", nil, nil, nil)
        }

        deinit { sqlite3_close(db) }

        func pontuar(termo: String, variantes: [String: [String]] = [:]) throws -> [String: Double] {
            let busca = termo.trimmingCharacters(in: .whitespacesAndNewlines)
            guard busca.isEmpty == false, textos.isEmpty == false else { return [:] }
            trava.lock()
            defer { trava.unlock() }
            var consulta: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT chave FROM local_fts WHERE local_fts MATCH ?", -1, &consulta, nil) == SQLITE_OK else {
                throw Erro.falhaPreparar(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(consulta) }
            sqlite3_bind_text(consulta, 1, "texto : (\(BibliotecaSQLiteService.consultaFTSSegura(busca, variantes: variantes)))",
                              -1, SQLITE_TRANSIENT_LOCAL)
            var encontrados = Set<String>()
            while sqlite3_step(consulta) == SQLITE_ROW {
                encontrados.insert(colunaTexto(consulta, 0))
            }
            // Per-index bm25 is not comparable across indexes, so relevance is the shared occurrence count.
            let termos = BibliotecaSQLiteService.termosContagem(busca, variantes: variantes)
            return Dictionary(uniqueKeysWithValues: encontrados.map { chave in
                (chave, -Double(BibliotecaSQLiteService.ocorrenciasBusca(termos: termos, texto: textos[chave] ?? "")))
            })
        }
    }
}

/// Local works searched as they are now, indexed once per file version (path, date and size):
/// typing pauses and "load more" neither decode the work's file nor rebuild its index.
final class BuscaLocalCache: @unchecked Sendable {
    struct Corpus {
        let dados: BreviarioData
        let conteudos: [String: String]
        let indice: BibliotecaSQLiteService.IndiceLocal
    }

    static let compartilhado = BuscaLocalCache()
    private var itens: [String: (versao: String, corpus: Corpus)] = [:]
    private let trava = NSLock()

    func corpus(obraID: String, url: URL, montar: () throws -> (BreviarioData, [(chave: String, texto: String)])) throws -> Corpus {
        let atributos = try? FileManager.default.attributesOfItem(atPath: url.path)
        let versao = [url.path, "\((atributos?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)",
                      "\((atributos?[.size] as? NSNumber)?.intValue ?? 0)"].joined(separator: "|")
        trava.lock()
        if let item = itens[obraID], item.versao == versao {
            trava.unlock()
            return item.corpus
        }
        trava.unlock()
        let (dados, textos) = try montar()
        let corpus = Corpus(dados: dados,
                            conteudos: Dictionary(textos.map { ($0.chave, $0.texto) }, uniquingKeysWith: { primeiro, _ in primeiro }),
                            indice: try BibliotecaSQLiteService.IndiceLocal(textos: textos))
        trava.lock()
        itens[obraID] = (versao, corpus)
        trava.unlock()
        return corpus
    }
}
