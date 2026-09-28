package com.renatocamargo.breviariomaconico.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.text.Normalizer
import java.time.LocalDate

/**
 * AI-free study dossier: every output is extracted from the given sources and cites one of them.
 * Mirrors `Tools/dossie_referencia.py`; `casos_dossie_v1.json` holds the golden cases both apps reproduce.
 */
internal object DossierAnalysis {
    data class Limits(
        val analyzedSources: Int, val shownSources: Int, val definitions: Int, val summary: Int, val relatedTerms: Int,
        val associationWindow: Int, val questions: Int, val divergences: Int, val centralWorks: Int, val dedicatedChapters: Int,
        val minSentence: Int, val maxSentence: Int, val chapterStart: Int, val minRelatedTerm: Int,
        val duplicateKeyTokens: Int, val duplicateMinTokens: Int
    )
    data class ReviewStep(val days: Int, val task: String)
    data class Config(
        val limits: Limits, val variants: Map<String, List<String>>, val definingVerbs: List<String>,
        val divergenceMarkers: List<String>, val stopWords: List<String>, val review: List<ReviewStep>,
        val areas: Map<String, String>,
        /** Local time of saved-dossier review notifications. */
        val reviewReminder: ReminderTime = ReminderTime(9, 0)
    )
    data class ReminderTime(val hour: Int, val minute: Int)

    data class Source(
        val id: String, val obraId: String, val tituloObra: String, val area: String, val pagina: Int,
        val data: String? = null, val texto: String = "", val rodape: String = ""
    )
    data class Excerpt(val texto: String, val fonte: String)
    data class Metrics(val sources: Int, val works: Int, val occurrences: Int, val duplicates: Int, val byArea: List<Pair<String, Int>>)
    data class CentralWork(val obraId: String, val titulo: String, val occurrences: Int, val sources: Int)
    /** [form] is the most frequent written form, shown to the reader ("maçom", not "macom"). */
    data class RelatedTerm(val term: String, val form: String, val occurrences: Int, val works: Int)
    data class Question(val question: String, val answer: String, val source: String)
    data class Step(val step: String, val text: String)
    data class Review(val date: String, val task: String)
    data class Result(
        val definitions: List<Excerpt>, val summary: List<Excerpt>, val divergences: List<Excerpt>, val metrics: Metrics,
        val centralWorks: List<CentralWork>, val dedicatedChapters: List<String>, val relatedTerms: List<RelatedTerm>,
        val questions: List<Question>, val roadmap: List<Step>, val review: List<Review>
    ) {
        /** Same shape as the golden cases, for comparison and export. */
        fun toJson(): JSONObject {
            fun excerpts(list: List<Excerpt>) = JSONArray(list.map { JSONObject().put("texto", it.texto).put("fonte", it.fonte) })
            return JSONObject()
                .put("definicoes", excerpts(definitions))
                .put("resumo", excerpts(summary))
                .put("divergencias", excerpts(divergences))
                .put("metricas", JSONObject().put("fontes", metrics.sources).put("obras", metrics.works)
                    .put("ocorrencias", metrics.occurrences).put("duplicadas", metrics.duplicates)
                    .put("porArea", JSONArray(metrics.byArea.map { JSONArray().put(it.first).put(it.second) })))
                .put("obrasCentrais", JSONArray(centralWorks.map {
                    JSONObject().put("obraId", it.obraId).put("titulo", it.titulo).put("ocorrencias", it.occurrences).put("fontes", it.sources)
                }))
                .put("capitulosDedicados", JSONArray(dedicatedChapters))
                .put("termosAssociados", JSONArray(relatedTerms.map {
                    JSONObject().put("termo", it.term).put("forma", it.form).put("ocorrencias", it.occurrences).put("obras", it.works)
                }))
                .put("perguntas", JSONArray(questions.map {
                    JSONObject().put("pergunta", it.question).put("resposta", it.answer).put("fonte", it.source)
                }))
                .put("roteiro", JSONArray(roadmap.map { JSONObject().put("etapa", it.step).put("texto", it.text) }))
                .put("revisao", JSONArray(review.map { JSONObject().put("data", it.date).put("tarefa", it.task) }))
        }
    }

    fun loadConfig(context: Context): Config {
        val json = context.assets.open("estudo_dossie_v1.json").bufferedReader().use { JSONObject(it.readText()) }
        require(json.getInt("schemaVersion") == 1)
        fun JSONArray.strings() = List(length()) { getString(it) }
        val limits = json.getJSONObject("limites")
        val variants = json.getJSONObject("variantes")
        return Config(
            Limits(limits.getInt("fontesAnalisadas"), limits.getInt("fontesExibidas"), limits.getInt("definicoes"),
                limits.getInt("resumo"), limits.getInt("termosAssociados"), limits.getInt("janelaAssociacao"),
                limits.getInt("perguntas"), limits.getInt("divergencias"), limits.getInt("obrasCentrais"),
                limits.getInt("capitulosDedicados"), limits.getInt("tamanhoMinimoFrase"), limits.getInt("tamanhoMaximoFrase"),
                limits.getInt("inicioCapitulo"), limits.getInt("tamanhoMinimoTermoAssociado"),
                limits.getInt("tokensChaveDuplicata"), limits.getInt("tokensMinimosDuplicata")),
            variants.keys().asSequence().associateWith { variants.getJSONArray(it).strings() },
            json.getJSONArray("verbosDefinicao").strings(),
            json.getJSONArray("marcadoresDivergencia").strings(),
            json.getJSONArray("palavrasVazias").strings(),
            json.getJSONArray("revisao").let { steps ->
                List(steps.length()) { ReviewStep(steps.getJSONObject(it).getInt("dias"), steps.getJSONObject(it).getString("tarefa")) }
            },
            json.getJSONObject("areas").let { areas -> areas.keys().asSequence().associateWith { areas.getString(it) } },
            json.getJSONObject("lembreteRevisao").let { ReminderTime(it.getInt("hora"), it.getInt("minuto")) }
        )
    }

    /** Lines shown on screen and in exports, identical on both platforms. */
    data class Display(
        val definitions: List<String>, val summary: List<String>, val divergences: List<String>, val metrics: List<String>,
        val centralWorks: List<String>, val dedicatedChapters: List<String>, val map: List<String>,
        val questions: List<String>, val roadmap: List<String>, val review: List<String>
    ) {
        fun toJson(): JSONObject = JSONObject()
            .put("definicoes", JSONArray(definitions)).put("resumo", JSONArray(summary)).put("divergencias", JSONArray(divergences))
            .put("metricas", JSONArray(metrics)).put("obrasCentrais", JSONArray(centralWorks))
            .put("capitulosDedicados", JSONArray(dedicatedChapters)).put("mapa", JSONArray(map))
            .put("perguntas", JSONArray(questions)).put("roteiro", JSONArray(roadmap)).put("revisao", JSONArray(review))
    }

    fun display(term: String, result: Result, sources: List<Source>, config: Config): Display {
        val byId = sources.associateBy { it.id }
        fun cite(id: String): String = byId[id]?.let { "${it.tituloObra}, ${reference(it)}" } ?: id
        fun excerpts(list: List<Excerpt>) = list.map { "${it.texto} — ${cite(it.fonte)}" }
        val metrics = result.metrics
        val areas = metrics.byArea.joinToString(", ") { "${config.areas[it.first] ?: it.first} (${it.second})" }
        val topic = clean(term).let { cleaned -> cleaned.split(' ').filter { it.isNotEmpty() }.joinToString(" ") }
        val written = java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy")
        return Display(
            excerpts(result.definitions), excerpts(result.summary), excerpts(result.divergences),
            listOf("${metrics.sources} fonte(s) em ${metrics.works} obra(s); ${metrics.occurrences} ocorrência(s) do tema.") +
                (if (areas.isEmpty()) emptyList() else listOf("Áreas: $areas.")) +
                (if (metrics.duplicates == 0) emptyList() else listOf("${metrics.duplicates} fonte(s) com texto repetido de outra obra desconsiderada(s).")),
            result.centralWorks.map { "${it.titulo}: ${it.occurrences} ocorrência(s) em ${it.sources} fonte(s)" },
            result.dedicatedChapters.map(::cite),
            result.relatedTerms.map { "$topic → ${it.form} (${it.occurrences} ocorrência(s), ${it.works} obra(s))" },
            result.questions.map { "${it.question} (Resposta: ${it.answer} — ${cite(it.source)})" },
            result.roadmap.map { "${it.step}: ${it.text}" },
            result.review.map { "${LocalDate.parse(it.date).format(written)}: ${it.task}" }
        )
    }

    // Text, by Unicode code point as in the reference.

    fun nfc(text: String): String = Normalizer.normalize(text, Normalizer.Form.NFC)

    private fun isWordChar(codePoint: Int): Boolean = when (Character.getType(codePoint).toByte()) {
        Character.UPPERCASE_LETTER, Character.LOWERCASE_LETTER, Character.TITLECASE_LETTER, Character.MODIFIER_LETTER,
        Character.OTHER_LETTER, Character.DECIMAL_DIGIT_NUMBER, Character.LETTER_NUMBER, Character.OTHER_NUMBER -> true
        else -> false
    }

    fun codePoints(text: String): IntArray = text.codePoints().toArray()

    fun string(points: IntArray, from: Int, to: Int): String = String(points, from, to - from)

    /** Runs of letters and digits with their code point positions. */
    fun spans(points: IntArray): List<IntRange> {
        val result = mutableListOf<IntRange>()
        var start = -1
        points.forEachIndexed { index, point ->
            if (isWordChar(point)) {
                if (start < 0) start = index
            } else if (start >= 0) {
                result.add(start until index)
                start = -1
            }
        }
        if (start >= 0) result.add(start until points.size)
        return result
    }

    fun fold(word: String): String {
        val decomposed = codePoints(Normalizer.normalize(word.lowercase(), Normalizer.Form.NFD))
        val kept = decomposed.filter { Character.getType(it) != Character.NON_SPACING_MARK.toInt() }.toIntArray()
        return String(kept, 0, kept.size)
    }

    private fun isNumber(word: String): Boolean =
        codePoints(word).all { Character.getType(it) == Character.DECIMAL_DIGIT_NUMBER.toInt() }

    class Words(val original: List<String>, val lower: List<String>, val normalized: List<String>)

    /** Original, lowercase (with accents) and normalized words, index-aligned. */
    fun words(text: String): Words {
        val points = codePoints(text)
        val original = spans(points).map { string(points, it.first, it.last + 1) }
        return Words(original, original.map { it.lowercase() }, original.map(::fold))
    }

    /** Collapses whitespace and removes OCR repetition: a run of 1 to 20 words repeated at once. */
    fun clean(raw: String): String {
        val items = mutableListOf<String>()
        val current = StringBuilder()
        for (point in codePoints(nfc(raw))) {
            if (Character.isWhitespace(point) || Character.isSpaceChar(point)) {
                if (current.isNotEmpty()) { items.add(current.toString()); current.setLength(0) }
            } else current.appendCodePoint(point)
        }
        if (current.isNotEmpty()) items.add(current.toString())
        val output = mutableListOf<String>()
        var index = 0
        while (index < items.size) {
            val size = (20 downTo 1).firstOrNull { size ->
                index + 2 * size <= items.size && items.subList(index, index + size) == items.subList(index + size, index + 2 * size)
            }
            if (size != null) {
                output.addAll(items.subList(index, index + size))
                index += 2 * size
            } else {
                output.add(items[index])
                index++
            }
        }
        return output.joinToString(" ")
    }

    private fun countType(word: String, test: (Int) -> Boolean): Int = codePoints(word).count { test(Character.getType(it)) }

    /**
     * Separates a heading glued by OCR to the start of a page: the leading words with no lowercase
     * letter ("49 10ª INSTRUÇÃO ESCADA DE JACÓ VM Degrau é..."). Page numbers at the very start are
     * dropped from the heading; a final single capital letter belongs to the body ("... JACÓ A escada").
     * Works on an already cleaned text; the heading is "" when there is none.
     */
    fun splitHeading(cleaned: String): Pair<String, String> {
        val letter: (Int) -> Boolean = { it in setOf(Character.UPPERCASE_LETTER, Character.LOWERCASE_LETTER, Character.TITLECASE_LETTER,
            Character.MODIFIER_LETTER, Character.OTHER_LETTER).map(Byte::toInt) }
        val number: (Int) -> Boolean = { it in setOf(Character.DECIMAL_DIGIT_NUMBER, Character.LETTER_NUMBER, Character.OTHER_NUMBER).map(Byte::toInt) }
        val items = if (cleaned.isEmpty()) emptyList() else cleaned.split(' ')
        // Only the Unicode lowercase category: "ª" and "º" (10ª, Nº) are not lowercase words.
        val prefix = items.takeWhile { word -> countType(word) { it == Character.LOWERCASE_LETTER.toInt() } == 0 }.toMutableList()
        if (prefix.isEmpty() || prefix.size == items.size || prefix.size > 20) return "" to cleaned
        val body = items.drop(prefix.size).toMutableList()
        while (prefix.isNotEmpty() && countType(prefix.last(), letter) == 1 && countType(prefix.last(), number) == 0) {
            body.add(0, prefix.removeAt(prefix.lastIndex))
        }
        while (prefix.isNotEmpty() && countType(prefix.first()) { it == Character.DECIMAL_DIGIT_NUMBER.toInt() } == codePoints(prefix.first()).size) {
            prefix.removeAt(0)
        }
        if (prefix.none { word -> countType(word) { it == Character.UPPERCASE_LETTER.toInt() } >= 2 }) return "" to cleaned
        return prefix.joinToString(" ") to body.joinToString(" ")
    }

    /** Cuts after '.', '!', '?' or ';' followed by a space; [cleaned] is already collapsed. */
    fun sentences(cleaned: String): List<String> {
        val points = codePoints(cleaned)
        val result = mutableListOf<String>()
        var start = 0
        for (index in points.indices) {
            if (points[index].toChar() in ".!?;" && points[index] < 128 && index + 1 < points.size && points[index + 1] == ' '.code) {
                result.add(string(points, start, index + 1).trim())
                start = index + 2
            }
        }
        if (start < points.size) result.add(string(points, start, points.size).trim())
        return result.map(::trimNoise).filter { it.isNotEmpty() }
    }

    fun isLetter(point: Int): Boolean = when (Character.getType(point).toByte()) {
        Character.UPPERCASE_LETTER, Character.LOWERCASE_LETTER, Character.TITLECASE_LETTER, Character.MODIFIER_LETTER,
        Character.OTHER_LETTER -> true
        else -> false
    }

    /**
     * Drops OCR noise before the first real word: a word starting with a letter that has two or more
     * letters, or a single letter followed by a space and another word ("A virtude", "A Fé").
     */
    fun trimNoise(sentence: String): String {
        val points = codePoints(sentence)
        val found = spans(points)
        found.forEachIndexed { index, span ->
            if (!isLetter(points[span.first])) return@forEachIndexed
            val letters = (span.first..span.last).count { isLetter(points[it]) }
            val end = span.last + 1
            val following = found.getOrNull(index + 1)?.first
            val singleOk = letters == 1 && end < points.size && points[end] == ' '.code && following == end + 1 && isLetter(points[following])
            if (letters >= 2 || singleOk) return string(points, span.first, points.size).trim()
        }
        return ""
    }

    fun occurrences(tokens: List<String>, term: List<Set<String>>): List<Int> {
        if (term.isEmpty() || tokens.size < term.size) return emptyList()
        return (0..tokens.size - term.size).filter { index -> term.indices.all { tokens[index + it] in term[it] } }
    }

    fun reference(source: Source): String =
        source.data?.takeIf { Regex("^\\d{2}/\\d{2}$").matches(it) } ?: "p. ${source.pagina}"

    private class Candidate(
        val score: Int, val source: Int, val order: Int, val text: String,
        val definition: Boolean, val divergent: Boolean, val key: String
    )

    fun analyze(term: String, sources: List<Source>, config: Config, today: LocalDate): Result {
        val limits = config.limits
        // Sources whose text repeats an earlier one (the same book imported twice) are ignored.
        val seenKeys = HashSet<String>()
        var duplicates = 0
        val sources = sources.filter { source ->
            val tokens = words(clean(source.texto)).normalized
            if (tokens.size < limits.duplicateMinTokens) return@filter true
            if (seenKeys.add(tokens.take(limits.duplicateKeyTokens).joinToString(" "))) true else { duplicates++; false }
        }
        val termAlts = words(nfc(term)).normalized.map { setOf(it) + config.variants[it].orEmpty() }
        val termWords = termAlts.flatten().toSet()
        // Defining verbs describe the term instead of being associated with it.
        val stop = config.stopWords.toSet() + config.definingVerbs.map(::fold)
        val defining = config.definingVerbs.toSet()
        val divergence = config.divergenceMarkers.toSet()

        val candidates = mutableListOf<Candidate>()
        val occurrencesBySource = mutableListOf<Int>()
        val startsWithTerm = mutableListOf<Boolean>()
        val associated = LinkedHashMap<String, Int>()
        val associatedWorks = HashMap<String, MutableSet<String>>()
        val associatedForms = HashMap<String, MutableMap<String, Int>>()
        sources.forEachIndexed { position, source ->
            val (heading, cleaned) = splitHeading(clean(source.texto))
            val sourceWords = words(cleaned)
            val tokens = sourceWords.normalized
            val found = occurrences(tokens, termAlts)
            val inHeading = occurrences(words(heading).normalized, termAlts).size
            occurrencesBySource.add(found.size + occurrences(words(clean(source.rodape)).normalized, termAlts).size + inHeading)
            startsWithTerm.add(inHeading > 0 || found.any { it < limits.chapterStart })
            for (index in found) {
                val afterStart = minOf(tokens.size, index + termAlts.size)
                val positions = (maxOf(0, index - limits.associationWindow) until index) +
                    (afterStart until minOf(tokens.size, afterStart + limits.associationWindow))
                for (at in positions) {
                    val word = tokens[at]
                    if (word.codePointCount(0, word.length) < limits.minRelatedTerm || word in stop || word in termWords || isNumber(word)) continue
                    associated[word] = (associated[word] ?: 0) + 1
                    associatedWorks.getOrPut(word) { mutableSetOf() }.add(source.obraId)
                    associatedForms.getOrPut(word) { HashMap() }.merge(sourceWords.lower[at], 1, Int::plus)
                }
            }
            sentences(cleaned).forEachIndexed { order, sentence ->
                val parts = words(sentence)
                if (occurrences(parts.normalized, termAlts).isEmpty()) return@forEachIndexed
                val length = sentence.codePointCount(0, sentence.length)
                if (length < limits.minSentence || length > limits.maxSentence) return@forEachIndexed
                val definition = parts.lower.any { it in defining }
                val score = (if (definition) 3 else 0) + (if (source.area == "dicionariosMaconicos") 2 else 0) +
                    (if (source.area != "bibliotecaMaconica") 1 else 0)
                val joined = parts.normalized.joinToString(" ")
                val keyPoints = codePoints(joined)
                candidates.add(Candidate(score, position, order, sentence, definition, parts.lower.any { it in divergence },
                    string(keyPoints, 0, minOf(120, keyPoints.size))))
            }
        }

        val seen = HashSet<String>()
        val unique = candidates.sortedWith(compareByDescending<Candidate> { it.score }.thenBy { it.source }.thenBy { it.order })
            .filter { seen.add(it.key) }

        fun pick(pool: List<Candidate>, limit: Int, excluded: Set<Pair<Int, Int>> = emptySet()): List<Candidate> {
            val chosen = mutableListOf<Candidate>()
            val works = HashSet<String>()
            for (candidate in pool) {
                if ((candidate.source to candidate.order) in excluded || !works.add(sources[candidate.source].obraId)) continue
                chosen.add(candidate)
                if (chosen.size == limit) break
            }
            return chosen
        }

        val definitions = pick(unique.filter { it.definition && sources[it.source].area == "dicionariosMaconicos" }, limits.definitions)
        val summary = pick(unique, limits.summary, definitions.map { it.source to it.order }.toSet())
        val divergences = pick(unique.filter { it.divergent }, limits.divergences)
        fun excerpt(candidate: Candidate) = Excerpt(candidate.text, sources[candidate.source].id)

        val byArea = sources.groupingBy { it.area }.eachCount()
        class Work(val titulo: String, var occurrences: Int, var count: Int, val first: Int)
        val works = LinkedHashMap<String, Work>()
        sources.forEachIndexed { position, source ->
            val work = works.getOrPut(source.obraId) { Work(source.tituloObra, 0, 0, position) }
            work.occurrences += occurrencesBySource[position]
            work.count++
        }
        val central = works.entries.sortedWith(compareByDescending<Map.Entry<String, Work>> { it.value.occurrences }
            .thenByDescending { it.value.count }.thenBy { it.key }).take(limits.centralWorks)
        val dedicated = mutableListOf<String>()
        val dedicatedWorks = HashSet<String>()
        sources.forEachIndexed { position, source ->
            if (startsWithTerm[position] && dedicated.size < limits.dedicatedChapters && dedicatedWorks.add(source.obraId)) dedicated.add(source.id)
        }
        val relatedTerms = associated.entries.sortedWith(compareByDescending<Map.Entry<String, Int>> { it.value }.thenBy { it.key })
            .take(limits.relatedTerms).map { entry ->
                // Shown in its most frequent written form; ties keep the smallest form.
                val form = associatedForms[entry.key].orEmpty().entries
                    .sortedWith(compareByDescending<Map.Entry<String, Int>> { it.value }.thenBy { it.key }).firstOrNull()?.key ?: entry.key
                RelatedTerm(entry.key, form, entry.value, associatedWorks[entry.key]?.size ?: 0)
            }

        val questions = mutableListOf<Question>()
        for (candidate in summary) {
            if (questions.size == limits.questions) break
            val points = codePoints(candidate.text)
            val normalized = words(candidate.text).normalized
            val related = relatedTerms.firstOrNull { it.term in normalized } ?: continue
            val span = spans(points)[normalized.indexOf(related.term)]
            questions.add(Question(string(points, 0, span.first) + "_____" + string(points, span.last + 1, points.size),
                string(points, span.first, span.last + 1), sources[candidate.source].id))
        }

        fun cite(position: Int) = "${sources[position].tituloObra}, ${reference(sources[position])}"
        val roadmap = mutableListOf<Step>()
        roadmap.add(if (definitions.isNotEmpty()) Step("Definição", "Comece pela definição em ${cite(definitions.first().source)}.")
            else Step("Definição", "Nenhum dicionário do acervo define o termo; comece pela fonte central."))
        central.firstOrNull()?.let { first ->
            val start = sources.indexOfFirst { it.id in dedicated && it.obraId == first.key }.takeIf { it >= 0 } ?: first.value.first
            roadmap.add(Step("Fonte central", "Leia ${first.value.titulo} (${first.value.occurrences} ocorrências), a partir de ${reference(sources[start])}."))
        }
        val breviaries = sources.indices.filter { sources[it].area == "breviarios" }.take(3)
        if (breviaries.isNotEmpty()) roadmap.add(Step("Breviários", "Leia nos breviários: " + breviaries.joinToString("; ") { cite(it) } + "."))
        if (central.size > 1) roadmap.add(Step("Aprofundamento", "Aprofunde em: " + central.drop(1).take(3).joinToString("; ") { it.value.titulo } + "."))
        if (divergences.size > 1) roadmap.add(Step("Comparação", "Compare ${cite(divergences[0].source)} com ${cite(divergences[1].source)}."))
        else if (central.size > 1) roadmap.add(Step("Comparação", "Compare como ${central[0].value.titulo} e ${central[1].value.titulo} tratam o tema."))
        roadmap.add(Step("Síntese", "Escreva uma síntese citando a obra e a página de cada trecho usado."))

        return Result(
            definitions.map(::excerpt), summary.map(::excerpt), divergences.map(::excerpt),
            Metrics(sources.size, works.size, occurrencesBySource.sum(), duplicates,
                byArea.entries.sortedWith(compareByDescending<Map.Entry<String, Int>> { it.value }.thenBy { it.key }).map { it.key to it.value }),
            central.map { CentralWork(it.key, it.value.titulo, it.value.occurrences, it.value.count) },
            dedicated, relatedTerms, questions, roadmap,
            config.review.map { Review(today.plusDays(it.days.toLong()).toString(), it.task) }
        )
    }
}
