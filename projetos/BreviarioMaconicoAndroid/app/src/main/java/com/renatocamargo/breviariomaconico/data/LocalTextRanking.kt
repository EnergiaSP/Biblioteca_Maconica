package com.renatocamargo.breviariomaconico.data

import java.io.Closeable

/**
 * Matches texts outside the downloaded packages (integrated breviaries) with the same FTS5 tokenizer
 * and query used for the packages, and scores them by the shared occurrence count.
 * Returns the negative count of each matching key; lower is more relevant, as in the package search.
 */
internal fun rankLocalTexts(query: String, texts: Map<String, String>, variants: Map<String, List<String>> = emptyMap()): Map<String, Double> {
    if (query.isBlank() || texts.isEmpty()) return emptyMap()
    return LocalTextIndex(texts).use { it.rank(query, variants) }
}

/**
 * Full-text index of local texts, built once and queried many times: rebuilding it for the 730
 * breviary readings on every search took about 2.5 s on a mid-range phone (moto g84).
 */
internal class LocalTextIndex(private val texts: Map<String, String>) : Closeable {
    private val db = RagSQLite.open(":memory:")
    private val lock = Any()

    init {
        db.execSQL("CREATE VIRTUAL TABLE local_fts USING fts5(chave UNINDEXED, texto, tokenize = 'unicode61 remove_diacritics 2')")
        db.execSQL("BEGIN")
        db.execSQLForEach("INSERT INTO local_fts VALUES (?, ?)", texts.map { (key, text) -> arrayOf(key, text) })
        db.execSQL("COMMIT")
    }

    /** [keys] limits the result to some texts (works and scope of the search); null means all. */
    fun rank(query: String, variants: Map<String, List<String>> = emptyMap(), keys: Set<String>? = null): Map<String, Double> {
        if (query.isBlank() || texts.isEmpty()) return emptyMap()
        val found = synchronized(lock) {
            db.rawQuery("SELECT chave FROM local_fts WHERE local_fts MATCH ?",
                arrayOf("texto : (${TextoFormatter.consultaFTSSegura(query, variants)})")).use { rows ->
                buildList { while (rows.moveToNext()) add(rows.getString(0)) }
            }
        }.filter { keys == null || it in keys }
        // Per-index bm25 is not comparable across indexes, so relevance is the shared occurrence count.
        val terms = StudyIndex.searchTerms(query, variants)
        return found.associateWith { -StudyIndex.searchOccurrences(terms, texts[it].orEmpty()).toDouble() }
    }

    override fun close() = synchronized(lock) { db.close() }
}
