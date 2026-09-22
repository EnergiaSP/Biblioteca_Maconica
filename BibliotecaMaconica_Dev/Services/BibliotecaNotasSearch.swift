import CryptoKit
import Foundation
import SQLite3

enum BibliotecaNotasSearch {
    private static let lock = NSLock()

    static func buscar(source: URL, consulta: String, area: BibliotecaArea?, obraID: String?,
                       limite: Int, excluidas: Set<String>) throws -> [BibliotecaRAGResultadoBusca] {
        lock.lock()
        defer { lock.unlock() }
        try Task.checkCancellation()
        let files = FileManager.default
        let directory = (files.urls(for: .cachesDirectory, in: .userDomainMask).first ?? files.temporaryDirectory)
            .appendingPathComponent("RAGNotesSearchV1", isDirectory: true)
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        let key = SHA256.hash(data: Data(source.path.utf8)).map { String(format: "%02x", $0) }.joined()
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
