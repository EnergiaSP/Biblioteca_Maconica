package com.renatocamargo.breviariomaconico.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Portable study notebook: the same file on Android and iOS (export, import and the sync options).
 * Importing merges it into the local notebook without losing anything. Mirrors
 * `Tools/caderno_referencia.py`; `casos_caderno_v1.json` holds the golden cases both apps reproduce.
 */
internal object StudyNotebook {
    data class Config(val format: String, val version: Int, val importMarker: String, val labels: Map<String, String>) {
        fun label(key: String, values: Map<String, String> = emptyMap()) =
            values.entries.fold(labels[key] ?: key) { text, (name, value) -> text.replace("{$name}", value) }
    }
    data class Highlight(val id: String, val text: String, val createdAt: Long)
    data class Edit(val title: String, val phrase: String, val text: String, val footnote: String, val author: String)
    data class Reading(
        val obraId: String, val data: String, val comment: String = "", val reflection: String = "",
        val favorite: Boolean = false, val read: Boolean = false, val highlights: List<Highlight> = emptyList(), val edit: Edit? = null
    ) {
        val hasContent get() = comment.isNotBlank() || reflection.isNotBlank() || favorite || read || highlights.isNotEmpty() || edit != null
    }
    data class Dossier(
        val id: String, val tema: String, val area: String?, val obraId: String?, val autor: String, val assunto: String,
        val criadoEm: String, val reviews: List<Int>
    ) {
        val key get() = listOf(tema, area.orEmpty(), obraId.orEmpty(), autor, assunto).joinToString("|") { it.trim().lowercase() }
    }
    data class Card(val card: ActiveReview.Card, val dossierId: String, val topic: String, val created: String, val state: ActiveReview.State)
    data class Notebook(val readings: List<Reading> = emptyList(), val dossiers: List<Dossier> = emptyList(), val cards: List<Card> = emptyList())

    @Volatile private var cached: Config? = null

    fun loadConfig(context: Context): Config = cached ?: parseConfig(
        context.assets.open("caderno_v1.json").bufferedReader().use { JSONObject(it.readText()) }
    ).also { cached = it }

    fun parseConfig(json: JSONObject): Config {
        require(json.getInt("schemaVersion") == 1)
        val labels = json.getJSONObject("rotulos")
        return Config(json.getString("formato"), json.getInt("versao"), json.getString("marcadorImportacao"),
            labels.keys().asSequence().associateWith { labels.getString(it) })
    }

    // Shared rule

    fun valid(json: JSONObject, config: Config): Boolean =
        json.optString("formato") == config.format && json.opt("versao") is Int && json.getInt("versao") <= config.version

    /** Stable order and no empty readings, so both apps write the same file. */
    fun canonical(notebook: Notebook): Notebook = Notebook(
        notebook.readings.map { reading -> reading.copy(highlights = reading.highlights.sortedWith(compareBy({ it.createdAt }, { it.text }))) }
            .filter { it.hasContent }.sortedWith(compareBy({ it.obraId }, { it.data })),
        notebook.dossiers.map { it.copy(reviews = it.reviews.toSortedSet().toList()) }
            .sortedWith(compareBy({ it.criadoEm }, { it.tema }, { it.id })),
        notebook.cards.sortedBy { it.card.id }
    )

    fun mergeText(local: String, imported: String, today: String, config: Config): String {
        val a = local.trim()
        val b = imported.trim()
        if (b.isEmpty() || a == b || a.contains(b)) return if (a.isNotEmpty()) local else if (b.isNotEmpty()) imported else ""
        if (a.isEmpty() || b.contains(a)) return imported
        val parts = today.split("-")
        val day = if (parts.size == 3) "${parts[2]}/${parts[1]}/${parts[0]}" else today
        return "$a\n\n${config.importMarker.replace("{data}", day)}\n$b"
    }

    fun merge(localNotebook: Notebook, importedNotebook: Notebook, today: String, config: Config): Notebook {
        val local = canonical(localNotebook)
        val imported = canonical(importedNotebook)
        val readings = LinkedHashMap(local.readings.associateBy { it.obraId to it.data })
        for (reading in imported.readings) {
            val key = reading.obraId to reading.data
            val mine = readings[key]
            if (mine == null) {
                readings[key] = reading
                continue
            }
            val texts = mine.highlights.map { it.text.trim() }.toMutableSet()
            val added = reading.highlights.filter { texts.add(it.text.trim()) }
            readings[key] = mine.copy(
                comment = mergeText(mine.comment, reading.comment, today, config),
                reflection = mergeText(mine.reflection, reading.reflection, today, config),
                favorite = mine.favorite || reading.favorite, read = mine.read || reading.read,
                highlights = mine.highlights + added, edit = mine.edit ?: reading.edit
            )
        }
        val dossiers = LinkedHashMap(local.dossiers.associateBy { it.key })
        val remap = HashMap<String, String>()
        for (dossier in imported.dossiers) {
            val mine = dossiers[dossier.key]
            if (mine == null) {
                dossiers[dossier.key] = dossier
            } else {
                remap[dossier.id] = mine.id
                dossiers[dossier.key] = mine.copy(criadoEm = minOf(mine.criadoEm, dossier.criadoEm),
                    reviews = (mine.reviews + dossier.reviews).toSortedSet().toList())
            }
        }
        val cards = LinkedHashMap(local.cards.associateBy { it.card.id })
        for (card in imported.cards) {
            val entry = card.copy(dossierId = remap[card.dossierId] ?: card.dossierId)
            val mine = cards[card.card.id]
            if (mine == null) {
                cards[card.card.id] = entry
                continue
            }
            fun answers(c: Card) = c.state.right + c.state.wrong
            val winner = if (answers(entry) > answers(mine)) entry else mine
            cards[card.card.id] = winner.copy(created = minOf(mine.created, entry.created))
        }
        return canonical(Notebook(readings.values.toList(), dossiers.values.toList(), cards.values.toList()))
    }

    // File

    fun toJson(notebook: Notebook, config: Config): JSONObject {
        val n = canonical(notebook)
        return JSONObject().put("formato", config.format).put("versao", config.version)
            .put("leituras", JSONArray(n.readings.map { r ->
                JSONObject().put("obraId", r.obraId).put("data", r.data).put("comentario", r.comment).put("reflexao", r.reflection)
                    .put("favorita", r.favorite).put("lida", r.read)
                    .put("destaques", JSONArray(r.highlights.map { JSONObject().put("id", it.id).put("texto", it.text).put("criadoEm", it.createdAt) }))
                    .put("edicao", r.edit?.let { JSONObject().put("titulo", it.title).put("frase", it.phrase).put("texto", it.text)
                        .put("rodape", it.footnote).put("autor", it.author) } ?: JSONObject.NULL)
            }))
            .put("dossies", JSONArray(n.dossiers.map { d ->
                JSONObject().put("id", d.id).put("tema", d.tema).put("area", d.area ?: JSONObject.NULL).put("obraId", d.obraId ?: JSONObject.NULL)
                    .put("autor", d.autor).put("assunto", d.assunto).put("criadoEm", d.criadoEm).put("revisoesConcluidas", JSONArray(d.reviews))
            }))
            .put("cartoes", JSONArray(n.cards.map { c ->
                JSONObject().put("cartao", JSONObject().put("id", c.card.id).put("tipo", c.card.kind).put("frente", c.card.front)
                    .put("verso", c.card.back).put("fonte", c.card.source).put("alternativas", JSONArray(c.card.options)))
                    .put("dossieId", c.dossierId).put("tema", c.topic).put("criadoEm", c.created)
                    .put("estado", JSONObject().put("caixa", c.state.box).put("vencimento", c.state.due)
                        .put("acertos", c.state.right).put("erros", c.state.wrong))
            }))
    }

    private fun JSONObject.nullableString(key: String) = if (isNull(key)) null else getString(key)

    fun fromJson(json: JSONObject): Notebook {
        fun <T> JSONArray?.items(read: (JSONObject) -> T) = if (this == null) emptyList() else List(length()) { read(getJSONObject(it)) }
        return Notebook(
            json.optJSONArray("leituras").items { r ->
                Reading(r.getString("obraId"), r.getString("data"), r.optString("comentario"), r.optString("reflexao"),
                    r.optBoolean("favorita"), r.optBoolean("lida"),
                    r.optJSONArray("destaques").items { Highlight(it.getString("id"), it.getString("texto"), it.getLong("criadoEm")) },
                    r.optJSONObject("edicao")?.let { Edit(it.optString("titulo"), it.optString("frase"), it.optString("texto"),
                        it.optString("rodape"), it.optString("autor")) })
            },
            json.optJSONArray("dossies").items { d ->
                Dossier(d.getString("id"), d.getString("tema"), d.nullableString("area"), d.nullableString("obraId"),
                    d.optString("autor"), d.optString("assunto"), d.getString("criadoEm"),
                    d.optJSONArray("revisoesConcluidas").let { a -> if (a == null) emptyList() else List(a.length()) { a.getInt(it) } })
            },
            json.optJSONArray("cartoes").items { c ->
                val card = c.getJSONObject("cartao")
                val options = card.getJSONArray("alternativas")
                val state = c.getJSONObject("estado")
                Card(ActiveReview.Card(card.getString("id"), card.getString("tipo"), card.getString("frente"), card.getString("verso"),
                    card.getString("fonte"), List(options.length()) { options.getString(it) }),
                    c.getString("dossieId"), c.getString("tema"), c.getString("criadoEm"),
                    ActiveReview.State(state.getInt("caixa"), state.getString("vencimento"), state.getInt("acertos"), state.getInt("erros")))
            }
        )
    }

    // This device

    /** "prefix_obra_data" or "prefix_data" (Breviário do Século XXI, legacy); a date never contains "_". */
    private fun readingKey(suffix: String): Pair<String, String>? {
        if (suffix.isEmpty()) return null
        val separator = suffix.lastIndexOf('_')
        return if (separator < 0) ObraId.BREVIARIO_SECULO_XXI to suffix else suffix.substring(0, separator) to suffix.substring(separator + 1)
    }

    /** The notebook of this device: readings, saved dossiers and review cards. */
    fun collect(context: Context): Notebook {
        val readings = LinkedHashMap<Pair<String, String>, Reading>()
        fun change(key: Pair<String, String>?, update: (Reading) -> Reading) {
            key ?: return
            readings[key] = update(readings[key] ?: Reading(key.first, key.second))
        }
        for ((name, value) in PreferencesStore(context).studyEntries()) {
            when {
                name.startsWith("comment_") && value is String -> change(readingKey(name.removePrefix("comment_"))) { it.copy(comment = value) }
                name.startsWith("reflection_") && value is String ->
                    change(readingKey(name.removePrefix("reflection_"))) { it.copy(reflection = value) }
                name.startsWith("highlights_") && value is String -> change(readingKey(name.removePrefix("highlights_"))) { reading ->
                    val array = runCatching { JSONArray(value) }.getOrDefault(JSONArray())
                    reading.copy(highlights = List(array.length()) { i -> array.getJSONObject(i) }
                        .filter { it.optString("text").isNotBlank() }
                        .map { Highlight(it.optString("id"), it.optString("text"), it.optLong("createdAt")) })
                }
                name.startsWith("textEdit_") && value is String -> change(readingKey(name.removePrefix("textEdit_"))) { reading ->
                    val obj = runCatching { JSONObject(value) }.getOrNull()
                    if (obj == null) reading else reading.copy(edit = Edit(obj.optString("title"), "", obj.optString("text"), obj.optString("footnote"), ""))
                }
                name == "favorites" && value is Set<*> -> value.filterIsInstance<String>().forEach { change(readingKey(it)) { r -> r.copy(favorite = true) } }
                name == "readDates" && value is Set<*> -> value.filterIsInstance<String>().forEach { change(readingKey(it)) { r -> r.copy(read = true) } }
            }
        }
        return canonical(Notebook(
            readings.values.toList(),
            SavedDossierStore(context).all().map { Dossier(it.id, it.tema, it.area, it.obraId, it.autor, it.assunto, it.criadoEm, it.revisoesConcluidas) },
            ReviewCardStore(context).all().map { Card(it.card, it.dossierId, it.topic, it.created, it.state) }
        ))
    }

    /** Writes a merged notebook to this device. Only adds or completes: the merge kept everything that was here. */
    fun apply(context: Context, notebook: Notebook) {
        val prefs = PreferencesStore(context)
        for (reading in notebook.readings) {
            prefs.importReading("${reading.obraId}_${reading.data}", reading.comment, reading.reflection, reading.favorite, reading.read,
                reading.highlights.sortedByDescending { it.createdAt }.map { TextHighlight(it.id, it.text, it.createdAt) },
                reading.edit?.let { BreviarioTextEdit(it.title, it.text, it.footnote) })
        }
        val dossiers = SavedDossierStore(context)
        notebook.dossiers.forEach { dossiers.save(SavedDossier(it.id, it.tema, it.area, it.obraId, it.autor, it.assunto, it.criadoEm, it.reviews)) }
        ReviewCardStore(context).replaceAll(notebook.cards.map { ReviewCardStore.Entry(it.card, it.dossierId, it.topic, it.created, it.state) })
    }
}
