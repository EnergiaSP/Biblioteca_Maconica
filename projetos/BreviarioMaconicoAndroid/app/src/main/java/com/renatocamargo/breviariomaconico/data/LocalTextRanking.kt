package com.renatocamargo.breviariomaconico.data

/**
 * Matches texts outside the downloaded packages (integrated breviaries) with the same FTS5 tokenizer
 * and query used for the packages, and scores them by the shared occurrence count.
 * Returns the negative count of each matching key; lower is more relevant, as in the package search.
 */
internal fun rankLocalTexts(query: String, texts: Map<String, String>): Map<String, Double> {
    if (query.isBlank() || texts.isEmpty()) return emptyMap()
    return RagSQLite.open(":memory:").use { db ->
        db.execSQL("CREATE VIRTUAL TABLE local_fts USING fts5(chave UNINDEXED, texto, tokenize = 'unicode61 remove_diacritics 2')")
        db.execSQL("BEGIN")
        texts.forEach { (key, text) -> db.execSQL("INSERT INTO local_fts VALUES (?, ?)", arrayOf(key, text)) }
        db.execSQL("COMMIT")
        val found = db.rawQuery("SELECT chave FROM local_fts WHERE local_fts MATCH ?",
            arrayOf("texto : (${TextoFormatter.consultaFTSSegura(query)})")).use { rows ->
            buildList { while (rows.moveToNext()) add(rows.getString(0)) }
        }
        // Per-index bm25 is not comparable across indexes, so relevance is the shared occurrence count.
        val terms = StudyIndex.searchTerms(query)
        found.associateWith { -StudyIndex.searchOccurrences(terms, texts[it].orEmpty()).toDouble() }
    }
}
