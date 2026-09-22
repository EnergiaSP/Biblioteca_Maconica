package com.renatocamargo.breviariomaconico.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class StudyCollection(
    val id: String, val title: String, val keywords: List<String>,
    val subtitle: String, val detail: String, val topics: List<String>
)
data class StudyRules(val version: Int, val collectionLimit: Int, val pathLimit: Int,
    val collections: List<StudyCollection>, val paths: List<StudyPath>) {
    companion object {
        fun matches(text: String, keywords: List<String>): Boolean {
            val normalizedText = normalized(text)
            return keywords.any { it.isNotBlank() && normalizedText.contains(normalized(it)) }
        }

        fun select(items: List<BreviarioItem>, keywords: List<String>, texts: Map<String, String>, limit: Int): List<BreviarioItem> =
            incorporate(emptyList(), items, keywords, texts, limit)

        fun incorporate(selected: List<BreviarioItem>, batch: List<BreviarioItem>, keywords: List<String>, texts: Map<String, String>, limit: Int): List<BreviarioItem> =
            incorporateNormalized(selected, batch, keywords.map(::normalized), texts.mapValues { normalized(it.value) }, limit)

        fun incorporateNormalized(selected: List<BreviarioItem>, batch: List<BreviarioItem>, keywords: List<String>, texts: Map<String, String>, limit: Int): List<BreviarioItem> {
            if (limit <= 0) return emptyList()
            val accumulated = selected.sortedWith(order).take(limit)
            val boundary = accumulated.lastOrNull().takeIf { accumulated.size == limit }
            return (accumulated + batch.filter { item ->
                (boundary == null || order.compare(item, boundary) < 0) &&
                    keywords.any { it.isNotBlank() && texts[item.chavePersistencia].orEmpty().contains(it) }
            })
                .distinctBy { it.chavePersistencia }
                .sortedWith(order).take(limit)
        }

        private val order = compareBy<BreviarioItem> { it.obraId }.thenBy { it.pagina }.thenBy { it.data }

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
