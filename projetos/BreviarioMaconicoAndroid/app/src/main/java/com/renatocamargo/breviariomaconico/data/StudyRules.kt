package com.renatocamargo.breviariomaconico.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class StudyCollection(
    val id: String, val title: String, val keywords: List<String>,
    val subtitle: String, val detail: String, val topics: List<String>
)
/** Relevance of a page for a theme: distinct keywords found first, then total occurrences. */
data class ScoredItem(val item: BreviarioItem, val topics: Int, val occurrences: Int)

data class StudyRules(val version: Int, val collectionLimit: Int, val pathLimit: Int,
    val collections: List<StudyCollection>, val paths: List<StudyPath>) {
    companion object {
        /** A page belongs to a theme when a keyword appears as whole words: "lei" does not match "leitura". */
        fun matches(text: String, keywords: List<String>): Boolean {
            val normalizedText = studyNormalized(text)
            return validKeywords(keywords.map(::studyNormalized)).any { normalizedText.contains(it) }
        }

        /** Folds case and accents and keeps only words, padded with spaces so keywords match whole words. */
        fun studyNormalized(text: String): String =
            " " + normalized(text).split(nonWord).filter { it.isNotEmpty() }.joinToString(" ") + " "

        fun select(items: List<BreviarioItem>, keywords: List<String>, texts: Map<String, String>, limit: Int): List<BreviarioItem> =
            incorporate(emptyList(), items, keywords, texts, limit)

        fun incorporate(selected: List<BreviarioItem>, batch: List<BreviarioItem>, keywords: List<String>, texts: Map<String, String>, limit: Int): List<BreviarioItem> {
            val normalizedKeywords = keywords.map(::studyNormalized)
            val normalizedTexts = texts.mapValues { studyNormalized(it.value) }
            val previous = selected.mapNotNull { score(it, validKeywords(normalizedKeywords), normalizedTexts[it.chavePersistencia].orEmpty()) }
            return incorporateNormalized(previous, batch, normalizedKeywords, normalizedTexts, limit).map { it.item }
        }

        /**
         * Keeps the `limit` most relevant pages. The result does not depend on batch size or order,
         * so the catalog can be streamed in batches without holding every page in memory.
         */
        fun incorporateNormalized(selected: List<ScoredItem>, batch: List<BreviarioItem>, keywords: List<String>, texts: Map<String, String>, limit: Int): List<ScoredItem> {
            if (limit <= 0) return emptyList()
            val valid = validKeywords(keywords)
            return (selected + batch.mapNotNull { score(it, valid, texts[it.chavePersistencia].orEmpty()) })
                .sortedWith(order)
                .distinctBy { it.item.chavePersistencia }
                .take(limit)
        }

        private val nonWord = Regex("[^\\p{L}\\p{N}]+")

        private fun validKeywords(keywords: List<String>): List<String> = keywords.filter { it.isNotBlank() }.distinct()

        private fun score(item: BreviarioItem, keywords: List<String>, text: String): ScoredItem? {
            var topics = 0
            var occurrences = 0
            for (keyword in keywords) {
                val count = countOccurrences(keyword, text)
                if (count > 0) {
                    topics++
                    occurrences += count
                }
            }
            return if (topics == 0) null else ScoredItem(item, topics, occurrences)
        }

        /** Counts padded keyword matches; consecutive matches share the separating space. */
        private fun countOccurrences(keyword: String, text: String): Int {
            var total = 0
            var start = text.indexOf(keyword)
            while (start >= 0) {
                total++
                start = text.indexOf(keyword, start + keyword.length - 1)
            }
            return total
        }

        private val order = compareByDescending<ScoredItem> { it.topics }
            .thenByDescending { it.occurrences }
            .thenBy { it.item.obraId }
            .thenBy { it.item.pagina }
            .thenBy { it.item.data }

        fun load(context: Context): StudyRules {
            val json = context.assets.open("regras_estudo_v1.json").bufferedReader().use { JSONObject(it.readText()) }
            require(json.getInt("schemaVersion") == 1)
            fun JSONArray.strings() = List(length()) { getString(it) }
            val collections = json.getJSONArray("colecoes")
            val paths = json.getJSONArray("trilhas")
            return StudyRules(1, json.getInt("collectionLimit"), json.getInt("pathLimit"),
                List(collections.length()) { index -> collections.getJSONObject(index).let {
                    StudyCollection(it.getString("id"), it.getString("titulo"), it.getJSONArray("palavrasChave").strings(),
                        it.getString("subtitulo"), it.getString("detalhe"), it.getJSONArray("topicos").strings())
                } }, List(paths.length()) { index -> paths.getJSONObject(index).let {
                    StudyPath(it.getString("id"), it.getString("titulo"), it.getString("objetivo"),
                        it.getString("duracaoSugerida"), it.getJSONArray("etapas").strings(), it.getJSONArray("palavrasChave").strings(),
                        it.getString("subtitulo"), it.getString("instrucao"))
                } })
        }
    }
}
