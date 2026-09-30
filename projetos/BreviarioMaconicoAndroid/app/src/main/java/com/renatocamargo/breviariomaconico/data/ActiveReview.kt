package com.renatocamargo.breviariomaconico.data

import android.content.Context
import java.security.MessageDigest
import java.time.LocalDate
import org.json.JSONArray
import org.json.JSONObject

/**
 * Active review: flashcards and quiz made from a dossier, always with the source. Mirrors
 * `Tools/revisao_referencia.py`; `casos_revisao_v1.json` holds the golden cases both apps reproduce.
 */
internal object ActiveReview {
    private val D = DossierAnalysis
    private const val SEP = "\u001f"

    data class Config(
        val sessionCards: Int, val options: Int, val minOptions: Int, val intervals: List<Int>, val labels: Map<String, String>
    ) {
        /** Label with its "{name}" placeholders filled. */
        fun label(key: String, values: Map<String, String> = emptyMap()) =
            values.entries.fold(labels[key] ?: key) { text, (name, value) -> text.replace("{$name}", value) }
    }
    enum class Grade(val id: String) { WRONG("errei"), HARD("dificil"), RIGHT("acertei") }
    data class Card(
        val id: String, val kind: String, val front: String, val back: String, val source: String, val options: List<String>
    )
    data class State(val box: Int, val due: String, val right: Int, val wrong: Int)

    @Volatile private var cached: Config? = null

    fun loadConfig(context: Context): Config = cached ?: parse(
        context.assets.open("revisao_ativa_v1.json").bufferedReader().use { JSONObject(it.readText()) }
    ).also { cached = it }

    fun parse(json: JSONObject): Config {
        require(json.getInt("schemaVersion") == 1)
        val limits = json.getJSONObject("limites")
        val intervals = json.getJSONArray("intervalos")
        val labels = json.getJSONObject("rotulos")
        return Config(limits.getInt("cartoesPorSessao"), limits.getInt("alternativas"), limits.getInt("alternativasMinimas"),
            List(intervals.length()) { intervals.getInt(it) }, labels.keys().asSequence().associateWith { labels.getString(it) })
    }

    fun sha(text: String): String =
        MessageDigest.getInstance("SHA-256").digest(text.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }

    fun topic(term: String): String {
        val words = mutableListOf<String>()
        val current = StringBuilder()
        D.nfc(term).codePoints().forEach { cp ->
            if (Character.isWhitespace(cp) || Character.isSpaceChar(cp)) {
                if (current.isNotEmpty()) { words += current.toString(); current.clear() }
            } else current.appendCodePoint(cp)
        }
        if (current.isNotEmpty()) words += current.toString()
        return words.joinToString(" ")
    }

    private fun card(kind: String, front: String, back: String, source: String, options: List<String> = emptyList()) =
        Card(sha(listOf(kind, front, back, source).joinToString(SEP)).take(16), kind, front, back, source, options)

    /**
     * The answer and the first associated forms that differ from it ("degrau" and "degraus" count as
     * the same), in a fixed shuffled order; empty when there are too few.
     */
    fun options(id: String, answer: String, forms: List<String>, config: Config): List<String> {
        val chosen = mutableListOf(answer)
        val seen = mutableListOf(D.fold(answer))
        for (form in forms) {
            if (chosen.size == config.options) break
            val folded = D.fold(form)
            if (seen.none { folded.startsWith(it) || it.startsWith(folded) }) {
                seen += folded
                chosen += form
            }
        }
        if (chosen.size < config.minOptions) return emptyList()
        return chosen.sortedBy { sha(id + SEP + it) }
    }

    fun generate(
        term: String, definitions: List<DossierAnalysis.Excerpt>, questions: List<DossierAnalysis.Question>,
        forms: List<String>, sources: List<DossierAnalysis.Source>, config: Config
    ): List<Card> {
        val byId = sources.associateBy { it.id }
        fun cite(id: String) = byId[id]?.let { "${it.tituloObra}, ${D.reference(it)}" } ?: id
        val front = config.label("definicao", mapOf("tema" to topic(term)))
        val cards = definitions.map { card("definicao", front, it.texto, cite(it.fonte)) }.toMutableList()
        for (question in questions) {
            val base = card("lacuna", question.question, question.answer, cite(question.source))
            cards += base.copy(options = options(base.id, question.answer, forms, config))
        }
        return cards
    }

    // Schedule

    fun newState(today: String) = State(0, today, 0, 0)

    /** errei: back to box 0; dificil: same box; acertei: one box up. Due today + interval of the box. */
    fun answer(state: State, grade: Grade, today: String, config: Config): State {
        val box = when (grade) {
            Grade.WRONG -> 0
            Grade.HARD -> state.box
            Grade.RIGHT -> minOf(state.box + 1, config.intervals.size - 1)
        }
        return State(box, LocalDate.parse(today).plusDays(config.intervals[box].toLong()).toString(),
            state.right + (if (grade == Grade.RIGHT) 1 else 0), state.wrong + (if (grade == Grade.WRONG) 1 else 0))
    }

    data class Due(val id: String, val created: String, val due: String)

    /** Ids of the cards due until today: by due date, then creation date, then id; up to the limit. */
    fun session(cards: List<Due>, today: String, config: Config): List<String> =
        cards.filter { it.due <= today }
            .sortedWith(compareBy<Due>({ it.due }, { it.created }, { it.id }))
            .take(config.sessionCards).map { it.id }
}

/** Review cards on this device, with their progress. Same fields and rules as iOS `CartoesRevisaoStore`. */
internal class ReviewCardStore(context: Context) {
    data class Entry(val card: ActiveReview.Card, val dossierId: String, val topic: String, val created: String, val state: ActiveReview.State)

    private val prefs = context.applicationContext.getSharedPreferences("cartoes_revisao", Context.MODE_PRIVATE)

    fun all(): List<Entry> {
        val raw = prefs.getString(KEY, null) ?: return emptyList()
        val array = runCatching { JSONArray(raw) }.getOrNull() ?: return emptyList()
        return List(array.length()) { index ->
            val json = array.getJSONObject(index)
            val card = json.getJSONObject("cartao")
            val state = json.getJSONObject("estado")
            val options = card.getJSONArray("alternativas")
            Entry(
                ActiveReview.Card(card.getString("id"), card.getString("tipo"), card.getString("frente"), card.getString("verso"),
                    card.getString("fonte"), List(options.length()) { options.getString(it) }),
                json.getString("dossieId"), json.getString("tema"), json.getString("criadoEm"),
                ActiveReview.State(state.getInt("caixa"), state.getString("vencimento"), state.getInt("acertos"), state.getInt("erros"))
            )
        }
    }

    /** Adds the dossier's cards that are not stored yet; stored cards keep their progress. */
    fun add(cards: List<ActiveReview.Card>, dossierId: String, topic: String, today: String): Int {
        val current = all()
        val existing = current.map { it.card.id }.toSet()
        val added = cards.filter { it.id !in existing }.map { Entry(it, dossierId, topic, today, ActiveReview.newState(today)) }
        if (added.isNotEmpty()) write(current + added)
        return added.size
    }

    fun answer(id: String, grade: ActiveReview.Grade, today: String, config: ActiveReview.Config) =
        write(all().map { if (it.card.id == id) it.copy(state = ActiveReview.answer(it.state, grade, today, config)) else it })

    /** Cards due until today, in session order. */
    fun session(today: String, config: ActiveReview.Config): List<Entry> {
        val list = all()
        val byId = list.associateBy { it.card.id }
        return ActiveReview.session(list.map { ActiveReview.Due(it.card.id, it.created, it.state.due) }, today, config)
            .mapNotNull { byId[it] }
    }

    /** Replaces every card (a merged notebook already kept the ones that were here). */
    fun replaceAll(entries: List<Entry>) = write(entries)

    fun removeDossier(dossierId: String) = write(all().filterNot { it.dossierId == dossierId })

    private fun write(list: List<Entry>) {
        prefs.edit().putString(KEY, JSONArray(list.map { entry ->
            JSONObject()
                .put("cartao", JSONObject().put("id", entry.card.id).put("tipo", entry.card.kind).put("frente", entry.card.front)
                    .put("verso", entry.card.back).put("fonte", entry.card.source).put("alternativas", JSONArray(entry.card.options)))
                .put("dossieId", entry.dossierId).put("tema", entry.topic).put("criadoEm", entry.created)
                .put("estado", JSONObject().put("caixa", entry.state.box).put("vencimento", entry.state.due)
                    .put("acertos", entry.state.right).put("erros", entry.state.wrong))
        }).toString()).apply()
    }

    private companion object {
        const val KEY = "v1"
    }
}
