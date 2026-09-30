package com.renatocamargo.breviariomaconico.data

import android.content.Context
import org.json.JSONObject

/**
 * Search variants: spelling groups and the optional singular and plural. Mirrors
 * `Tools/variantes_referencia.py`; `casos_variantes_v1.json` holds the golden cases both apps reproduce.
 */
internal object SearchVariants {
    data class Inflection(val ending: String, val forms: List<String>)
    data class Config(
        val minimumLetters: Int, val maximumPerWord: Int, val noInflection: Set<String>, val groups: List<List<String>>,
        val inflections: List<Inflection>, val labels: Map<String, String>
    ) {
        fun label(key: String) = labels[key] ?: key
    }

    @Volatile private var cached: Config? = null

    fun loadConfig(context: Context): Config = cached ?: parse(
        context.assets.open("variantes_busca_v1.json").bufferedReader().use { JSONObject(it.readText()) }
    ).also { cached = it }

    fun parse(json: JSONObject): Config {
        require(json.getInt("schemaVersion") == 1)
        fun strings(array: org.json.JSONArray) = List(array.length()) { array.getString(it) }
        val groups = json.getJSONArray("grupos")
        val inflections = json.getJSONArray("singularPlural")
        val labels = json.getJSONObject("rotulos")
        return Config(json.getInt("minimoLetras"), json.getInt("maximoPorPalavra"), strings(json.getJSONArray("semFlexao")).toSet(),
            List(groups.length()) { strings(groups.getJSONArray(it)) },
            List(inflections.length()) { inflections.getJSONObject(it).let { i -> Inflection(i.getString("final"), strings(i.getJSONArray("formas"))) } },
            labels.keys().asSequence().associateWith { labels.getString(it) })
    }

    /** Each word of a group maps to the other words of the group, in the group's order. */
    fun spelling(config: Config): Map<String, List<String>> {
        val result = LinkedHashMap<String, MutableList<String>>()
        for (group in config.groups) for (word in group) {
            val current = result.getOrPut(word) { mutableListOf() }
            group.filter { it != word && it !in current }.forEach { current += it }
        }
        return result
    }

    fun inflections(word: String, config: Config): List<String> {
        if (word.length < config.minimumLetters || word in config.noInflection) return emptyList()
        val rule = config.inflections.firstOrNull { word.endsWith(it.ending) } ?: return emptyList()
        val stem = word.dropLast(rule.ending.length)
        return rule.forms.map { stem + it }
    }

    /** Alternatives of each searched word (already normalized), as passed to the index query. */
    fun expand(words: List<String>, singularPlural: Boolean, config: Config): Map<String, List<String>> {
        val groups = spelling(config)
        val result = LinkedHashMap<String, List<String>>()
        for (word in words) {
            val options = groups[word].orEmpty().toMutableList()
            if (singularPlural) (listOf(word) + options.toList()).forEach { options += inflections(it, config) }
            val unique = options.filter { it != word }.distinct()
            if (unique.isNotEmpty()) result[word] = unique.take(config.maximumPerWord)
        }
        return result
    }

    /** Variants of every word of a library search, words and quoted phrases alike. */
    fun forSearch(context: Context, query: String, singularPlural: Boolean): Map<String, List<String>> {
        val words = TextoFormatter.termosBusca(query).flatMap { StudyRules.studyNormalized(it).trim().split(' ').filter(String::isNotEmpty) }
        return expand(words, singularPlural, loadConfig(context))
    }

    private fun prefs(context: Context) = context.applicationContext.getSharedPreferences("busca", Context.MODE_PRIVATE)

    /** On unless the reader turned it off. */
    fun singularPluralOn(context: Context) = prefs(context).getBoolean("singularPlural", true)

    fun setSingularPlural(context: Context, on: Boolean) = prefs(context).edit().putBoolean("singularPlural", on).apply()
}
