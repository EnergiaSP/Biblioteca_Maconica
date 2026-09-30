package com.renatocamargo.breviariomaconico.data

import android.content.Context
import org.json.JSONObject

/**
 * Study tracks by degree (Aprendiz, Companheiro, Mestre): each step is a topic studied in the
 * Dossiê. Mirrors `Tools/trilhas_referencia.py`; `casos_trilhas_v1.json` holds the golden cases.
 */
internal object DegreeTracks {
    data class Step(val id: String, val topic: String, val description: String)
    data class Degree(val id: String, val name: String, val description: String, val steps: List<Step>, val suggestedWorks: List<String>)
    data class Milestone(val percent: Int, val label: String)
    data class Config(val milestones: List<Milestone>, val labels: Map<String, String>, val degrees: List<Degree>) {
        fun label(key: String, values: Map<String, String> = emptyMap()) =
            values.entries.fold(labels[key] ?: key) { text, (name, value) -> text.replace("{$name}", value) }
    }
    data class Progress(val degree: String, val done: List<String>, val total: Int, val percent: Int, val milestone: String, val next: String?)

    @Volatile private var cached: Config? = null

    fun loadConfig(context: Context): Config = cached ?: parse(
        context.assets.open("trilhas_grau_v1.json").bufferedReader().use { JSONObject(it.readText()) }
    ).also { cached = it }

    fun parse(json: JSONObject): Config {
        require(json.getInt("schemaVersion") == 1)
        val milestones = json.getJSONArray("marcos")
        val labels = json.getJSONObject("rotulos")
        val degrees = json.getJSONArray("graus")
        return Config(
            List(milestones.length()) { milestones.getJSONObject(it).let { m -> Milestone(m.getInt("percentual"), m.getString("rotulo")) } },
            labels.keys().asSequence().associateWith { labels.getString(it) },
            List(degrees.length()) { index ->
                val d = degrees.getJSONObject(index)
                val steps = d.getJSONArray("etapas")
                val works = d.getJSONArray("obrasSugeridas")
                Degree(d.getString("id"), d.getString("nome"), d.getString("descricao"),
                    List(steps.length()) { steps.getJSONObject(it).let { s -> Step(s.getString("id"), s.getString("tema"), s.getString("descricao")) } },
                    List(works.length()) { works.getString(it) })
            })
    }

    /** Case, accents and spaces ignored, as the saved dossier topic is compared with the step topic. */
    fun studyKey(topic: String) = DossierAnalysis.fold(topic).split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")

    fun progress(config: Config, savedTopics: List<String>, marked: Set<String>): List<Progress> {
        val saved = savedTopics.map(::studyKey).toSet()
        return config.degrees.map { degree ->
            val done = degree.steps.filter { it.id in marked || studyKey(it.topic) in saved }.map { it.id }
            val total = degree.steps.size
            val milestone = config.milestones.lastOrNull { done.size >= maxOf(1, (total * it.percent + 99) / 100) }?.label.orEmpty()
            Progress(degree.id, done, total, if (total == 0) 0 else done.size * 100 / total, milestone,
                degree.steps.firstOrNull { it.id !in done }?.id)
        }
    }

    // Steps marked on this device

    private fun prefs(context: Context) = context.applicationContext.getSharedPreferences("trilhas_grau", Context.MODE_PRIVATE)

    fun marked(context: Context): Set<String> = prefs(context).getStringSet("marcadas", emptySet()).orEmpty().toSet()

    fun toggle(context: Context, step: String) {
        val current = marked(context).toMutableSet()
        if (!current.remove(step)) current.add(step)
        prefs(context).edit().putStringSet("marcadas", current).apply()
    }
}
