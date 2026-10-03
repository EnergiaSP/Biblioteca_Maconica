import CryptoKit
import Foundation
import SQLite3

enum BibliotecaNotasSearch {
    // One lock per cache file: a single global lock serialized the parallel search of every package
    // and left a user-interactive caller waiting on lower-priority work (priority inversion).
    private static let locksLock = NSLock()
    nonisolated(unsafe) private static var locks: [String: NSLock] = [:]  // only read and written under locksLock

    private static func lock(for key: String) -> NSLock {
        locksLock.lock()
        defer { locksLock.unlock() }
        if let lock = locks[key] { return lock }
        let lock = NSLock()
        locks[key] = lock
        return lock
    }

    /// Brings the footnote search caches of every installed package up to date ahead of the first search
    /// (after opening the app and after a download), as Android's `prepararBuscaNotas`.
    static func prepararPacotesInstalados() {
        guard let catalogo = try? BibliotecaRAGCatalogService() else { return }
        var vistos = Set<String>()
        for url in catalogo.pacotes.compactMap({ catalogo.urlPacote($0) }) where vistos.insert(url.path).inserted {
            if Task.isCancelled { return }
            _ = try? buscar(source: url, consulta: "", area: nil, obraID: nil, limite: 0, excluidas: [])
        }
        removerCachesOrfaos(manter: Set(vistos.map(chave)))
    }

    /// Caches of packages no longer installed (removed from the catalog, test copies, or named after an old
    /// container path, before `chave` used relative paths: 1.2 GB on the test simulator), unchanged for a
    /// day, are removed; Android does the same.
    static func removerCachesOrfaos(manter: Set<String>, em pasta: URL = diretorio, agora: Date = Date()) {
        let files = FileManager.default
        guard let nomes = try? files.contentsOfDirectory(atPath: pasta.path) else { return }
        for nome in nomes where !manter.contains(String(nome.prefix { $0 != "." })) {
            let url = pasta.appendingPathComponent(nome)
            let alterado = (try? files.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? agora
            if agora.timeIntervalSince(alterado) > 86_400 { try? files.removeItem(at: url) }
        }
    }

    /// Named after the package path relative to the app's containers: their absolute paths change when the
    /// app is updated or reinstalled, which used to leave every cache behind and rebuild them all.
    private static func chave(_ path: String) -> String {
        var relativo = path
        for (raiz, marca) in [(NSHomeDirectory(), "home:"), (Bundle.main.bundlePath, "bundle:")] where path.hasPrefix(raiz + "/") {
            relativo = marca + path.dropFirst(raiz.count)
            break
        }
        return SHA256.hash(data: Data(relativo.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static var diretorio: URL {
        let files = FileManager.default
        return (files.urls(for: .cachesDirectory, in: .userDomainMask).first ?? files.temporaryDirectory)
            .appendingPathComponent("RAGNotesSearchV1", isDirectory: true)
    }

    static func buscar(source: URL, consulta: String, area: BibliotecaArea?, obraID: String?,
                       limite: Int, excluidas: Set<String>) throws -> [BibliotecaRAGResultadoBusca] {
        let key = chave(source.path)
        let lock = lock(for: key)
        lock.lock()
        defer { lock.unlock() }
        try Task.checkCancellation()
        let files = FileManager.default
        let directory = diretorio
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        let stamp = try [source.path, source.path + "-wal"].map { path -> String in
            guard files.fileExists(atPath: path) else { return "absent" }
            let attrs = try files.attributesOfItem(atPath: path)
            return "\(attrs[.size] ?? 0):\((attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0):\(attrs[.systemFileNumber] ?? 0)"
        }.joined(separator: "|")
        let database = try Database(directory.appendingPathComponent(key + ".sqlite"))
        try database.run("CREATE TABLE IF NOT EXISTS cache_meta (stamp TEXT NOT NULL)")
        try database.run("""
        CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
            bloco_id UNINDEXED, obra_id UNINDEXED, titulo UNINDEXED, area UNINDEXED,
            pagina UNINDEXED, texto, tokenize='unicode61 remove_diacritics 2')
        """)
        var saved: String?
        try database.run("SELECT stamp FROM cache_meta") { saved = Database.text($0, 0) }
        if saved != stamp {
            // Derived search cache only: the original package is always attached read-only.
            try database.run("ATTACH DATABASE ? AS original", [source.absoluteString + "?mode=ro"])
            defer { try? database.run("DETACH DATABASE original") }
            try database.run("BEGIN IMMEDIATE")
            do {
                try database.run("DELETE FROM notes_fts")
                try database.run("""
                INSERT INTO notes_fts(bloco_id, obra_id, titulo, area, pagina, texto)
                SELECT 'nota:' || n.rowid, n.obra_id, o.titulo, o.area, n.pagina,
                       trim(n.numero || ' ' || n.texto)
                FROM original.rag_notas n JOIN original.rag_obras o ON o.id = n.obra_id
                WHERE trim(n.texto) != ''
                """)
                try Task.checkCancellation()
                try database.run("DELETE FROM cache_meta")
                try database.run("INSERT INTO cache_meta(stamp) VALUES (?)", [stamp])
                try database.run("COMMIT")
            } catch {
                try? database.run("ROLLBACK")
                throw error
            }
        }
        // An empty query only brings the cache up to date (see prepararPacotesInstalados).
        if consulta.isEmpty { return [] }
        var filters = ["notes_fts MATCH ?"]
        var args = [consulta]
        if let area { filters.append("area = ?"); args.append(area.rawValue) }
        if let obraID { filters.append("obra_id = ?"); args.append(obraID) }
        for id in excluidas.sorted() { filters.append("obra_id != ?"); args.append(id) }
        args.append(String(max(0, limite)))
        var results: [BibliotecaRAGResultadoBusca] = []
        try database.run("""
        SELECT bloco_id, obra_id, titulo, area, pagina, texto, bm25(notes_fts)
        FROM notes_fts WHERE \(filters.joined(separator: " AND "))
        ORDER BY bm25(notes_fts), obra_id, CAST(pagina AS INTEGER), bloco_id LIMIT ?
        """, args) { row in
            let block = Database.text(row, 0), work = Database.text(row, 1)
            results.append(.init(id: "\(work)-\(block)", obraID: work,
                tituloObra: Database.text(row, 2), area: BibliotecaArea(rawValue: Database.text(row, 3)) ?? .bibliotecaMaconica,
                pagina: Int(sqlite3_column_int(row, 4)), blocoID: block,
                trecho: Database.text(row, 5), ranking: sqlite3_column_double(row, 6)))
        }
        return results
    }

    private final class Database {
        private var handle: OpaquePointer?
        init(_ url: URL) throws {
            let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI
            guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK else {
                let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Banco indisponível"
                sqlite3_close(handle)
                handle = nil
                throw BibliotecaSQLiteService.Erro.naoAbriuBanco(message)
            }
            sqlite3_busy_timeout(handle, 5_000)
        }
        deinit { sqlite3_close(handle) }
        func run(_ sql: String, _ args: [String] = [], row: ((OpaquePointer?) -> Void)? = nil) throws {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { throw failure() }
            defer { sqlite3_finalize(statement) }
            for (index, value) in args.enumerated() {
                guard sqlite3_bind_text(statement, Int32(index + 1), value, -1,
                    unsafeBitCast(-1, to: sqlite3_destructor_type.self)) == SQLITE_OK else { throw failure() }
            }
            while true {
                let status = sqlite3_step(statement)
                if status == SQLITE_DONE { return }
                guard status == SQLITE_ROW else { throw failure() }
                try Task.checkCancellation()
                row?(statement)
            }
        }
        private func failure() -> Error {
            BibliotecaSQLiteService.Erro.falhaSQL(String(cString: sqlite3_errmsg(handle)))
        }
        static func text(_ row: OpaquePointer?, _ column: Int32) -> String {
            sqlite3_column_text(row, column).map { String(cString: $0) } ?? ""
        }
    }
}
