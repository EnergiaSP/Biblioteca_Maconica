package com.renatocamargo.breviariomaconico.data

import java.io.File
import java.security.MessageDigest
import kotlinx.coroutines.CancellationException

internal object NotesSearchIndex {
    /** Identity of a package file: the cache is rebuilt when it changes. */
    fun stamp(source: File): String = listOf(source, File(source.path + "-wal")).joinToString("|") {
        if (it.exists()) "${it.length()}:${it.lastModified()}:${android.system.Os.stat(it.path).st_ino}" else "absent"
    }

    @Synchronized
    fun search(source: File, cacheDir: File, query: String, area: BibliotecaArea?, workId: String?,
               limit: Int, excluded: Set<String> = emptySet(), cancelled: () -> Boolean = { false }): List<BibliotecaBuscaResultado> {
        fun checkCancellation() { if (cancelled()) throw CancellationException() }
        checkCancellation()
        val directory = File(cacheDir, "RAGNotesSearchV1").apply { mkdirs() }
        val key = MessageDigest.getInstance("SHA-256").digest(source.absolutePath.toByteArray()).joinToString("") { "%02x".format(it) }
        val stamp = stamp(source)
        return RagSQLite.open(File(directory, "$key.sqlite").path).use { db ->
            db.execSQL("PRAGMA busy_timeout = 5000")
            db.execSQL("CREATE TABLE IF NOT EXISTS cache_meta (stamp TEXT NOT NULL)")
            db.execSQL("""CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
                bloco_id UNINDEXED, obra_id UNINDEXED, titulo UNINDEXED, area UNINDEXED,
                pagina UNINDEXED, texto, tokenize='unicode61 remove_diacritics 2')""")
            val saved = db.rawQuery("SELECT stamp FROM cache_meta", emptyArray()).use { if (it.moveToNext()) it.getString(0) else null }
            if (saved != stamp) {
                // Stream from a read-only source; never modify a downloaded or imported original.
                db.execSQL("BEGIN IMMEDIATE")
                try {
                    db.execSQL("DELETE FROM notes_fts")
                    RagSQLite.open(source.path, readOnly = true).use { original ->
                        original.rawQuery("""SELECT n.rowid, n.obra_id, o.titulo, o.area, n.pagina, trim(n.numero || ' ' || n.texto)
                            FROM rag_notas n JOIN rag_obras o ON o.id = n.obra_id WHERE trim(n.texto) != ''""", emptyArray()).use { rows ->
                            while (rows.moveToNext()) {
                                checkCancellation()
                                db.execSQL("INSERT INTO notes_fts VALUES (?, ?, ?, ?, ?, ?)", arrayOf(
                                    "nota:${rows.getString(0)}", rows.getString(1), rows.getString(2), rows.getString(3), rows.getInt(4), rows.getString(5)))
                            }
                        }
                    }
                    checkCancellation()
                    db.execSQL("DELETE FROM cache_meta")
                    db.execSQL("INSERT INTO cache_meta(stamp) VALUES (?)", arrayOf(stamp))
                    db.execSQL("COMMIT")
                } catch (error: Throwable) {
                    db.execSQL("ROLLBACK")
                    throw error
                }
            }
            // An empty query only brings the cache up to date (see BibliotecaCatalogRepository.prepararBuscaNotas).
            if (query.isEmpty()) return@use emptyList()
            val filters = mutableListOf("notes_fts MATCH ?")
            val args = mutableListOf(query)
            if (area != null) { filters.add("area = ?"); args.add(area.raw) }
            if (workId != null) { filters.add("obra_id = ?"); args.add(workId) }
            // Excluded works are filtered below: many "!=" constraints next to MATCH make the bundled
            // SQLite refuse the query ("unable to use function MATCH in the requested context").
            args.add(limit.coerceAtLeast(0).toString())
            db.rawQuery("""SELECT bloco_id, obra_id, titulo, area, pagina, texto, bm25(notes_fts)
                FROM notes_fts WHERE ${filters.joinToString(" AND ")}
                ORDER BY bm25(notes_fts), obra_id, CAST(pagina AS INTEGER), bloco_id LIMIT ?""", args.toTypedArray()).use { rows ->
                buildList {
                    while (rows.moveToNext()) {
                        checkCancellation()
                        if (rows.getString(1) in excluded) continue
                        add(BibliotecaBuscaResultado(rows.getString(1), rows.getString(2), BibliotecaArea.from(rows.getString(3)),
                            rows.getInt(4), rows.getString(5), rows.getDouble(6), blocoId = rows.getString(0)))
                    }
                }
            }
        }
    }
}

/** Brings the footnote search caches up to date ahead of the first search (after an install or an update). */
internal fun BibliotecaCatalogRepository.prepararBuscaNotas(cancelled: () -> Boolean = { false }) {
    // Packages already prepared are skipped by their file identity alone, without opening any database.
    val prepared = appContext.getSharedPreferences("notas_preparadas", android.content.Context.MODE_PRIVATE)
    val cache = File(appContext.cacheDir, "RAGNotesSearchV1")
    for (file in pacotes.map { localFile(it) }.filter { it.exists() }.distinctBy { it.absolutePath }) {
        if (cancelled()) return
        val stamp = NotesSearchIndex.stamp(file)
        if (cache.isDirectory && prepared.getString(file.absolutePath, null) == stamp) continue
        runCatching { NotesSearchIndex.search(file, appContext.cacheDir, "", null, null, 0, cancelled = cancelled) }
            .onSuccess { prepared.edit().putString(file.absolutePath, stamp).apply() }
    }
}

/**
 * Footnote caches too, so the first library search after an install or update does not build them;
 * a little later, so opening the app and its first screens keep the disk to themselves.
 */
internal suspend fun BibliotecaCatalogRepository.prepararBuscaNotasDepoisDaAbertura() {
    kotlinx.coroutines.delay(8_000)
    // Packages left out of the catalog (works removed as copies of others) do not keep taking space.
    runCatching { removerPacotesForaDoCatalogo() }
    val job = kotlinx.coroutines.currentCoroutineContext()[kotlinx.coroutines.Job]
    prepararBuscaNotas { job?.isActive == false }
}
