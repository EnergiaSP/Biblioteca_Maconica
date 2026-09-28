package com.renatocamargo.breviariomaconico.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * AI-assisted interpretation of a dossier. The AI receives only the excerpts shown in the dossier,
 * numbered [F1], [F2]...; from its answer only sentences with a valid citation are kept, and a literal
 * quotation must exist in a cited excerpt. Mirrors `Tools/ia_referencia.py`; `casos_ia_v1.json`
 * holds the golden cases both apps reproduce.
 */
internal object AssistedInterpretation {
    private val D = DossierAnalysis

    data class Labels(
        val title: String, val notice: String, val removed: String, val citedSources: String,
        val nothingKept: String, val noOfficialSources: String
    )
    data class Config(
        val excerptChars: Int, val footnoteChars: Int, val minQuote: Int,
        val instructions: List<String>, val blocks: List<String>, val labels: Labels
    )
    data class OfficialSource(val title: String, val origin: String, val url: String, val notes: String)
    data class Result(val text: String, val kept: Int, val removed: Int, val citedSources: List<Int>)

    fun loadConfig(context: Context): Config {
        val json = context.assets.open("ia_assistida_v1.json").bufferedReader().use { JSONObject(it.readText()) }
        require(json.getInt("schemaVersion") == 1)
        fun JSONArray.strings() = List(length()) { getString(it) }
        val limits = json.getJSONObject("limites")
        val labels = json.getJSONObject("rotulos")
        return Config(
            limits.getInt("caracteresTrecho"), limits.getInt("caracteresRodape"), limits.getInt("citacaoLiteralMinima"),
            json.getJSONArray("instrucoes").strings(), json.getJSONArray("blocos").strings(),
            Labels(labels.getString("titulo"), labels.getString("aviso"), labels.getString("removidas"),
                labels.getString("fontesCitadas"), labels.getString("semFontes"), labels.getString("semFontesOficiais"))
        )
    }

    // Prompt

    fun prompt(
        term: String, sources: List<DossierAnalysis.Source>, official: List<OfficialSource>,
        config: Config, study: DossierAnalysis.Config
    ): String {
        val tokens = D.words(D.nfc(term)).normalized.map { setOf(it) + study.variants[it].orEmpty() }
        val lines = config.instructions.toMutableList()
        lines += listOf("", "Organize a resposta nestes blocos, nesta ordem, cada um com o título em uma linha própria:")
        lines += config.blocks.mapIndexed { index, title -> "${index + 1}. $title" }
        lines += listOf("", "TEMA: ${D.clean(term)}", "", "FONTES OFICIAIS CADASTRADAS (somente referência):")
        lines += official.map { "- ${it.title} | ${it.origin} | ${it.url} | ${it.notes}" }.ifEmpty { listOf(config.labels.noOfficialSources) }
        lines += listOf("", "TRECHOS DO DOSSIÊ:")
        sources.forEachIndexed { index, source ->
            lines += sourceLine(index + 1, source, study)
            lines += excerpt(source.texto, tokens, config.excerptChars)
            if (D.clean(source.rodape).isNotEmpty()) lines += "Notas de rodapé: " + shorten(source.rodape, config.footnoteChars)
            lines += ""
        }
        return lines.joinToString("\n").trimEnd('\n')
    }

    fun sourceLine(number: Int, source: DossierAnalysis.Source, study: DossierAnalysis.Config): String =
        "[F$number] ${source.tituloObra}, ${D.reference(source)} (${study.areas[source.area] ?: source.area})"

    /** Window of the cleaned text around the first occurrence of the topic, cut at word limits. */
    fun excerpt(text: String, term: List<Set<String>>, limit: Int): String {
        val cleaned = D.codePoints(D.clean(text))
        if (cleaned.size <= limit) return D.string(cleaned, 0, cleaned.size)
        val spans = D.spans(cleaned)
        val folded = spans.map { D.fold(D.string(cleaned, it.first, it.last + 1)) }
        val center = D.occurrences(folded, term).firstOrNull()?.let { spans[it].first } ?: 0
        var start = maxOf(0, center - limit / 3)
        if (start > 0) start = spans.firstOrNull { it.first >= start }?.first ?: start
        var end = start + limit
        end = if (end >= cleaned.size) cleaned.size
        else spans.map { it.last + 1 }.filter { it <= end && it > start }.maxOrNull() ?: end
        val body = D.string(cleaned, start, end).trim()
        return (if (start > 0) "… " else "") + body + (if (end < cleaned.size) " …" else "")
    }

    fun shorten(text: String, limit: Int): String {
        val cleaned = D.codePoints(D.clean(text))
        if (cleaned.size <= limit) return D.string(cleaned, 0, cleaned.size)
        val cut = (limit downTo 0).firstOrNull { cleaned[it] == ' '.code } ?: -1
        return D.string(cleaned, 0, if (cut > 0) cut else limit) + " …"
    }

    // Filter

    private val citation = Regex("\\[F([0-9]+)\\]")
    private val bullet = Regex("^([-*•]|[0-9]+[.)]) ")
    private val followingCitations = java.util.regex.Pattern.compile("(?: ?\\[F[0-9]+\\])+\\.?")
    private val quote = Regex("“([^”]*)”|\"([^\"]*)\"")

    /** A line is a heading only when it is one of the requested block titles (with number, # or **). */
    fun heading(line: String, config: Config): String? {
        var text = line.trimStart('#').trim().trim('*').trim()
        text = bullet.replaceFirst(text, "").trimEnd(':').trim().trim('*').trim()
        return config.blocks.firstOrNull { D.fold(D.clean(text)) == D.fold(it) }
    }

    /**
     * Sentence ends: '.', '!' or '?' followed by a space, not after a word of one or two letters
     * ("p.", "Sr."); citations right after the end belong to that sentence.
     */
    fun sentences(body: String): List<String> {
        val points = D.codePoints(body)
        val cuts = mutableListOf<Int>()
        var index = 0
        while (index < points.size) {
            val char = points[index]
            if ((char == '.'.code || char == '!'.code || char == '?'.code) && index + 1 < points.size && points[index + 1] == ' '.code) {
                var wordStart = index
                while (wordStart > 0 && D.isLetter(points[wordStart - 1])) wordStart--
                val letters = index - wordStart
                if (char != '.'.code || letters == 0 || letters >= 3) {
                    var end = index + 1
                    val rest = D.string(points, end, points.size)
                    val matcher = followingCitations.matcher(rest)
                    if (matcher.lookingAt()) {
                        val size = rest.codePointCount(0, matcher.end())
                        if (end + size == points.size || points[end + size] == ' '.code) end += size
                    }
                    cuts += end
                    index = end
                    continue
                }
            }
            index++
        }
        var start = 0
        return (cuts + points.size).map { end -> D.string(points, start, end).trim().also { start = end } }.filter { it.isNotEmpty() }
    }

    private fun normalized(text: String): String = D.words(D.clean(text)).normalized.joinToString(" ")

    /** A number too large for Int is an invalid source, as in the reference. */
    private fun citations(sentence: String): List<Int> =
        citation.findAll(sentence).map { it.groupValues[1].toIntOrNull() ?: Int.MAX_VALUE }.toList()

    private fun quotesMatch(sentence: String, ids: List<Int>, sources: List<DossierAnalysis.Source>, config: Config): Boolean {
        val cited = ids.map { " " + normalized(sources[it - 1].texto + " " + sources[it - 1].rodape) + " " }
        for (match in quote.findAll(sentence)) {
            val quoted = match.groups[1]?.value ?: match.groups[2]?.value ?: continue
            if (D.codePoints(D.clean(quoted)).size < config.minQuote) continue
            val needle = " " + normalized(quoted) + " "
            if (cited.none { needle in it }) return false
        }
        return true
    }

    fun filter(answer: String, sources: List<DossierAnalysis.Source>, config: Config): Result {
        val sections = mutableListOf<Pair<String?, MutableList<String>>>()
        var kept = 0
        var removed = 0
        val cited = sortedSetOf<Int>()
        for (raw in D.nfc(answer).replace("\r\n", "\n").replace("\r", "\n").split("\n")) {
            val line = D.clean(raw.replace("**", ""))
            if (line.isEmpty()) continue
            val title = heading(line, config)
            if (title != null) {
                sections += title to mutableListOf()
                continue
            }
            val marker = bullet.find(line)
            val prefix = marker?.let { it.groupValues[1] + " " } ?: ""
            val accepted = mutableListOf<String>()
            for (sentence in sentences(if (marker != null) line.substring(marker.range.last + 1) else line)) {
                val ids = citations(sentence)
                if (ids.isNotEmpty() && ids.all { it in 1..sources.size } && quotesMatch(sentence, ids, sources, config)) {
                    accepted += sentence
                    cited += ids
                } else {
                    removed++
                }
            }
            if (accepted.isNotEmpty()) {
                kept += accepted.size
                if (sections.isEmpty()) sections += null to mutableListOf()
                sections.last().second += prefix + accepted.joinToString(" ")
            }
        }
        val blocks = sections.filter { it.second.isNotEmpty() }.map { (title, lines) ->
            (title?.let { "$it\n" } ?: "") + lines.joinToString("\n")
        }
        return Result(blocks.joinToString("\n\n"), kept, removed, cited.toList())
    }

    /** Text shown on screen and in exports; empty when nothing could be kept. */
    fun display(result: Result, sources: List<DossierAnalysis.Source>, config: Config, study: DossierAnalysis.Config): String {
        if (result.kept == 0) return ""
        val lines = mutableListOf(config.labels.title, config.labels.notice)
        if (result.removed > 0) lines += config.labels.removed.replace("{n}", result.removed.toString())
        lines += listOf("", result.text, "", config.labels.citedSources + ":")
        lines += result.citedSources.map { sourceLine(it, sources[it - 1], study) }
        return lines.joinToString("\n")
    }
}
