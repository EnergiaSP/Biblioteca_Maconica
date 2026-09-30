package com.renatocamargo.breviariomaconico.data

import android.content.Context
import org.json.JSONObject

/**
 * Notebook by theme: every note of the study notebook (saved dossiers with their interpretation,
 * highlights, reflections and comments) in one searchable list. Mirrors `entries`, `search`, `themes`
 * and `export` in `Tools/caderno_referencia.py`; the "porTema" cases of `casos_caderno_v1.json`.
 */
internal object StudyNotebookThemes {
    data class Rule(
        val typeOrder: List<String>, val types: Map<String, String>, val pageReference: String, val dossierOrigin: String,
        val exportHeader: String, val labels: Map<String, String>
    ) {
        fun label(key: String, values: Map<String, String> = emptyMap()) =
            values.entries.fold(labels[key] ?: key) { text, (name, value) -> text.replace("{$name}", value) }
    }
    data class Note(
        val type: String, val label: String, val origin: String, val text: String,
        val obraId: String?, val data: String?, val dossierId: String?
    ) {
        val key get() = listOf(type, obraId.orEmpty(), data.orEmpty(), dossierId.orEmpty(), text).joinToString("\u001f")
    }
    data class Theme(val theme: String, val count: Int)

    @Volatile private var cached: Rule? = null

    fun loadRule(context: Context): Rule = cached ?: parse(
        context.assets.open("caderno_v1.json").bufferedReader().use { JSONObject(it.readText()) }.getJSONObject("porTema")
    ).also { cached = it }

    fun parse(json: JSONObject): Rule {
        fun map(key: String) = json.getJSONObject(key).let { o -> o.keys().asSequence().associateWith { o.getString(it) } }
        val order = json.getJSONArray("ordemTipos")
        return Rule(List(order.length()) { order.getString(it) }, map("tipos"), json.getString("referenciaPagina"),
            json.getString("origemDossie"), json.getString("cabecalhoExportacao"), map("rotulos"))
    }

    private val PAGE = Regex("P(\\d+)")
    private val DAY = Regex("(\\d{2})/(\\d{2})")

    /** Pages by number ("P12"), dates dd/MM by month and day; anything else first. */
    fun dateOrder(data: String?): Int {
        if (data == null) return 0
        PAGE.matchEntire(data)?.let { return it.groupValues[1].toInt() }
        return DAY.matchEntire(data)?.let { it.groupValues[2].toInt() * 100 + it.groupValues[1].toInt() } ?: 0
    }

    fun origin(obraId: String, data: String, titles: Map<String, String>, rule: Rule): String {
        val reference = PAGE.matchEntire(data)?.let { rule.pageReference.replace("{pagina}", it.groupValues[1]) } ?: data
        return "${titles[obraId] ?: obraId}, $reference"
    }

    /** Every note of the notebook, in the order of the rule. */
    fun notes(notebook: StudyNotebook.Notebook, titles: Map<String, String>, rule: Rule): List<Note> {
        val items = mutableListOf<Pair<Note, Int>>()
        fun label(type: String) = rule.types[type] ?: type
        notebook.dossiers.forEach { d ->
            items += Note("dossie", label("dossie"), rule.dossierOrigin.replace("{tema}", d.tema), d.interpretation?.text.orEmpty(),
                d.obraId, null, d.id) to 0
        }
        notebook.readings.forEach { r ->
            val where = origin(r.obraId, r.data, titles, rule)
            fun note(type: String, text: String) = Note(type, label(type), where, text, r.obraId, r.data, null)
            r.highlights.forEachIndexed { index, h -> items += note("destaque", h.text) to index }
            if (r.reflection.isNotBlank()) items += note("reflexao", r.reflection) to 0
            if (r.comment.isNotBlank()) items += note("comentario", r.comment) to 0
        }
        fun rank(type: String) = rule.typeOrder.indexOf(type).let { if (it < 0) rule.typeOrder.size else it }
        return items.sortedWith(compareBy<Pair<Note, Int>>({ rank(it.first.type) }, { DossierAnalysis.fold(it.first.origin) },
            { dateOrder(it.first.data) }, { it.second })).map { it.first }
    }

    /** Each word searched must start a word of the note's text or origin (case and accents ignored). */
    fun search(notes: List<Note>, query: String): List<Note> {
        val wanted = DossierAnalysis.words(query).normalized
        return notes.filter { note ->
            val found = DossierAnalysis.words(note.text + " " + note.origin).normalized
            wanted.all { w -> found.any { it.startsWith(w) } }
        }
    }

    fun themes(notebook: StudyNotebook.Notebook, notes: List<Note>): List<Theme> {
        val names = LinkedHashMap<String, String>()
        notebook.dossiers.forEach { d -> d.tema.trim().let { names.getOrPut(DossierAnalysis.fold(it)) { it } } }
        return names.entries.sortedWith(compareBy({ it.key }, { it.value })).map { Theme(it.value, search(notes, it.value).size) }
    }

    fun export(found: List<Note>, query: String, rule: Rule): String {
        val title = query.trim().ifEmpty { rule.label("todas") }
        val blocks = listOf(rule.exportHeader.replace("{tema}", title)) + found.map { note ->
            "${note.label} — ${note.origin}" + note.text.trim().let { if (it.isEmpty()) "" else "\n$it" }
        }
        return blocks.joinToString("\n\n") + "\n"
    }
}
