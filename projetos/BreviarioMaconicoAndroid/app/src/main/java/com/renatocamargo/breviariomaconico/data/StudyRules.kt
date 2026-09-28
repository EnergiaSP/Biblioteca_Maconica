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
    /** Counts, in a single pass over a normalized page, the occurrences of each keyword, including phrases. */
    class KeywordCounter(keywords: Set<String>) {
        private val single = keywords.filterNot { ' ' in it }.toSet()
        private val phrases = keywords.filter { ' ' in it }.map { it.split(' ') }
        private val phraseStarts = phrases.map { it.first() }.toSet()

        fun count(text: String): Map<String, Int> {
            val tokens = text.split(' ').filter { it.isNotEmpty() }
            val counts = HashMap<String, Int>()
            tokens.forEachIndexed { index, token ->
                if (token in single) counts.merge(token, 1, Int::plus)
                if (token in phraseStarts) {
                    for (phrase in phrases) {
                        if (phrase.first() == token && index + phrase.size <= tokens.size &&
                            tokens.subList(index, index + phrase.size) == phrase) {
                            counts.merge(phrase.joinToString(" "), 1, Int::plus)
                        }
                    }
                }
            }
            return counts
        }
    }

    companion object {
        /** A page belongs to a theme when a keyword appears as whole words: "lei" does not match "leitura". */
        fun matches(text: String, keywords: List<String>): Boolean =
            KeywordCounter(studyKeywords(keywords.map(::studyNormalized))).count(studyNormalized(text)).isNotEmpty()

        /** Folds case and accents and keeps only words, padded with spaces so keywords match whole words. */
        fun studyNormalized(text: String): String =
            " " + normalized(text).split(nonWord).filter { it.isNotEmpty() }.joinToString(" ") + " "

        fun select(items: List<BreviarioItem>, keywords: List<String>, texts: Map<String, String>, limit: Int): List<BreviarioItem> =
            incorporate(emptyList(), items, keywords, texts, limit)

        fun incorporate(selected: List<BreviarioItem>, batch: List<BreviarioItem>, keywords: List<String>, texts: Map<String, String>, limit: Int): List<BreviarioItem> {
            val normalizedKeywords = keywords.map(::studyNormalized)
            val normalizedTexts = texts.mapValues { studyNormalized(it.value) }
            val previous = incorporateNormalized(emptyList(), selected, normalizedKeywords, normalizedTexts, Int.MAX_VALUE)
            return incorporateNormalized(previous, batch, normalizedKeywords, normalizedTexts, limit).map { it.item }
        }

        fun incorporateNormalized(selected: List<ScoredItem>, batch: List<BreviarioItem>, keywords: List<String>, texts: Map<String, String>, limit: Int): List<ScoredItem> {
            val words = studyKeywords(keywords)
            val counter = KeywordCounter(words)
            return incorporateCounts(selected, batch, words, texts.mapValues { counter.count(it.value) }, limit)
        }

        /**
         * Keeps the `limit` most relevant pages. The result does not depend on batch size or order,
         * so the catalog can be streamed in batches without holding every page in memory.
         * [counts] comes from [KeywordCounter] over all rules' keywords, so each page is read once.
         */
        fun incorporateCounts(selected: List<ScoredItem>, batch: List<BreviarioItem>, keywords: Set<String>, counts: Map<String, Map<String, Int>>, limit: Int): List<ScoredItem> {
            if (limit <= 0) return emptyList()
            return (selected + batch.mapNotNull { score(it, keywords, counts[it.chavePersistencia].orEmpty()) })
                .sortedWith(order)
                .distinctBy { it.item.chavePersistencia }
                .take(limit)
        }

        /** Normalized keywords without padding, ignoring blanks and repetitions. */
        fun studyKeywords(keywords: List<String>): Set<String> = keywords.map { it.trim() }.filter { it.isNotEmpty() }.toSet()

        private val nonWord = Regex("[^\\p{L}\\p{N}]+")

        private fun score(item: BreviarioItem, keywords: Set<String>, counts: Map<String, Int>): ScoredItem? {
            var topics = 0
            var occurrences = 0
            for (keyword in keywords) {
                val count = counts[keyword] ?: 0
                if (count > 0) {
                    topics++
                    occurrences += count
                }
            }
            return if (topics == 0) null else ScoredItem(item, topics, occurrences)
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
