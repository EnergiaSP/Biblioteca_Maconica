package com.renatocamargo.breviariomaconico.data

import android.content.Context
import java.text.Normalizer
import org.json.JSONObject

/**
 * Quality of a page or sentence of the collection: the share of suspicious words left by OCR.
 * Mirrors `Tools/qualidade_referencia.py`; `casos_qualidade_v1.json` holds the golden cases both
 * apps reproduce. Works on code points after NFC, as iOS works on Unicode scalars.
 */
/** Rated, noisy and unreadable pages of a work, as recorded in the catalog (Tools/avaliar_qualidade_acervo.py). */
data class TextQualityCount(val rated: Int, val noisy: Int, val unreadable: Int)

internal object TextQuality {
    data class Limits(
        val minPageWords: Int, val minSentenceWords: Int, val noisyPercent: Int, val unreadablePercent: Int,
        val lettersWithoutVowel: Int, val goodWorkPercent: Int, val fairWorkPercent: Int
    )
    data class Labels(val noisyPage: String, val unreadablePage: String, val noisySource: String, val work: Map<String, String>)
    data class Config(
        val limits: Limits, val borders: Set<Int>, val abbreviationMarks: Set<Int>, val ordinalMarks: Set<Int>,
        val numericSigns: Set<Int>, val innerSigns: Set<Int>, val romanDigits: Set<Int>, val oneLetterWords: Set<Int>,
        val vowels: Set<Int>, val latinRanges: List<IntRange>, val labels: Labels
    )
    enum class Level(val id: String) { SHORT("curta"), READABLE("legivel"), NOISY("ruidosa"), UNREADABLE("ilegivel") }
    data class Rating(val words: Int, val suspicious: Int, val level: Level, val reasons: Map<String, Int>)
    fun workLevel(count: TextQualityCount, config: Config) = workLevel(count.rated, count.noisy, count.unreadable, config)

    /** Text quality of a package's works, as on iOS; null when no page was rated. */
    fun packageLabel(works: List<BibliotecaObraCatalogo>, config: Config): String? {
        val counts = works.mapNotNull { it.qualidade }
        val level = workLevel(TextQualityCount(counts.sumOf { it.rated }, counts.sumOf { it.noisy }, counts.sumOf { it.unreadable }), config)
        return if (level == "semAvaliacao") null else config.labels.work[level]
    }

    @Volatile private var cached: Config? = null

    /** Read once from the bundled asset, as iOS keeps `Configuracao.compartilhada`. */
    fun loadConfig(context: Context): Config = cached
        ?: parse(context.assets.open("qualidade_texto_v1.json").bufferedReader().use { JSONObject(it.readText()) })
            .also { cached = it }

    fun parse(json: JSONObject): Config {
        require(json.getInt("schemaVersion") == 1)
        fun set(key: String) = json.getString(key).codePoints().toArray().toSet()
        val limits = json.getJSONObject("limites")
        val labels = json.getJSONObject("rotulos")
        val work = labels.getJSONObject("obra")
        val ranges = json.getJSONArray("faixasLatinas")
        return Config(
            Limits(limits.getInt("palavrasMinimasPagina"), limits.getInt("palavrasMinimasFrase"),
                limits.getInt("ruidosaPercentual"), limits.getInt("ilegivelPercentual"), limits.getInt("letrasSemVogal"),
                limits.getInt("obraBoaPercentual"), limits.getInt("obraRegularPercentual")),
            set("bordas"), set("marcasAbreviacao"), set("marcasOrdinais"), set("sinaisNumericos"), set("sinaisInternos"),
            set("algarismosRomanos"), set("palavrasDeUmaLetra"), set("vogais"),
            List(ranges.length()) { ranges.getJSONArray(it).let { r -> r.getInt(0)..r.getInt(1) } },
            Labels(labels.getString("paginaRuidosa"), labels.getString("paginaIlegivel"), labels.getString("fonteRuidosa"),
                work.keys().asSequence().associateWith { work.getString(it) })
        )
    }

    // Unicode

    private fun type(cp: Int) = Character.getType(cp).toByte()
    private fun letter(cp: Int) = type(cp) in setOf(
        Character.UPPERCASE_LETTER, Character.LOWERCASE_LETTER, Character.TITLECASE_LETTER,
        Character.MODIFIER_LETTER, Character.OTHER_LETTER)
    private fun digit(cp: Int) = type(cp) == Character.DECIMAL_DIGIT_NUMBER
    private fun alnum(cp: Int) = letter(cp) || type(cp) in setOf(
        Character.DECIMAL_DIGIT_NUMBER, Character.LETTER_NUMBER, Character.OTHER_NUMBER)
    private fun upper(cp: Int) = type(cp) == Character.UPPERCASE_LETTER
    private fun lower(cp: Int) = type(cp) == Character.LOWERCASE_LETTER
    private fun separator(cp: Int) = cp in intArrayOf(9, 10, 11, 12, 13) || type(cp) in setOf(
        Character.SPACE_SEPARATOR, Character.LINE_SEPARATOR, Character.PARAGRAPH_SEPARATOR)

    fun words(text: String): List<IntArray> {
        val result = mutableListOf<IntArray>()
        val current = mutableListOf<Int>()
        Normalizer.normalize(text, Normalizer.Form.NFC).codePoints().forEach { cp ->
            if (separator(cp)) {
                if (current.isNotEmpty()) { result += current.toIntArray(); current.clear() }
            } else current += cp
        }
        if (current.isNotEmpty()) result += current.toIntArray()
        return result
    }

    // Classification

    private fun strip(word: IntArray, chars: Set<Int>): List<Int> {
        var start = 0
        var end = word.size
        while (start < end && word[start] in chars) start++
        while (end > start && word[end - 1] in chars) end--
        return word.slice(start until end)
    }

    private fun masonic(t: List<Int>, marks: Set<Int>): Boolean {
        var i = 0
        var groups = 0
        while (i < t.size) {
            val letters = i
            while (i < t.size && letter(t[i])) i++
            if (i == letters) return false
            val marksStart = i
            while (i < t.size && t[i] in marks) i++
            if (i == marksStart) return i == t.size && groups > 0
            groups++
        }
        return groups > 0
    }

    private fun ordinal(t: List<Int>, marks: Set<Int>): Boolean {
        val dot = '.'.code
        var body = if (t.lastOrNull() == dot) t.dropLast(1) else t
        if (body.isEmpty() || body.last() !in marks) return false
        body = body.dropLast(1)
        if (body.lastOrNull() == dot) body = body.dropLast(1)
        if (body.isEmpty() || !body.all { digit(it) || it == dot || it == ','.code }) return false
        return digit(body.first()) && digit(body.last())
    }

    fun classify(word: String, config: Config): String? =
        classify(Normalizer.normalize(word, Normalizer.Form.NFC).codePoints().toArray(), config)

    /** null: ignored (punctuation only); "normal"; or the reason the word is suspicious. */
    fun classify(word: IntArray, config: Config): String? {
        var t = strip(word, config.borders)
        if (t.none { alnum(it) }) return null
        if (masonic(t, config.abbreviationMarks) || ordinal(t, config.ordinalMarks)) return "normal"
        val dot = '.'.code
        val abbreviated = t.lastOrNull() == dot
        t = t.dropLastWhile { it == dot }
        if (t.isEmpty()) return null
        if (t.all { digit(it) || it in config.numericSigns }) return "normal"
        if (t.all { it in config.romanDigits } && (t.all { upper(it) } || t.size >= 2)) return "normal"
        val letters = t.filter { letter(it) }
        val hasDigit = t.any { digit(it) }
        val others = t.any { !alnum(it) && it !in config.innerSigns }
        if (letters.any { cp -> config.latinRanges.none { cp in it } }) return "escrita"
        if (letters.isNotEmpty() && hasDigit) return "misto"
        if (letters.isNotEmpty() && others) return "simbolo"
        if (letters.size == 1 && !abbreviated && !(t.size == 1 && t[0] in config.oneLetterWords)) return "solta"
        if (t.size >= 3 && t.zipWithNext().any { (a, b) -> lower(a) && upper(b) }) return "caixa"
        if (letters.size >= config.limits.lettersWithoutVowel && letters.none { it in config.vowels } &&
            !letters.all { upper(it) }) return "semVogal"
        return "normal"
    }

    // Rating

    fun rate(text: String, minimum: Int, config: Config): Rating {
        var counted = 0
        var suspicious = 0
        val reasons = sortedMapOf<String, Int>()
        for (word in words(text)) {
            val result = classify(word, config) ?: continue
            counted++
            if (result != "normal") {
                suspicious++
                reasons[result] = (reasons[result] ?: 0) + 1
            }
        }
        val limits = config.limits
        val level = when {
            counted < minimum -> Level.SHORT
            suspicious * 100 >= counted * limits.unreadablePercent -> Level.UNREADABLE
            suspicious * 100 >= counted * limits.noisyPercent -> Level.NOISY
            else -> Level.READABLE
        }
        return Rating(counted, suspicious, level, reasons)
    }

    fun ratePage(text: String, config: Config) = rate(text, config.limits.minPageWords, config)
    fun rateSentence(text: String, config: Config) = rate(text, config.limits.minSentenceWords, config)

    /** Quality of a whole work from its rated pages (short pages are not rated). */
    fun workLevel(rated: Int, noisy: Int, unreadable: Int, config: Config): String {
        if (rated == 0) return "semAvaliacao"
        val readable = rated - noisy - unreadable
        return when {
            readable * 100 >= rated * config.limits.goodWorkPercent -> "boa"
            readable * 100 >= rated * config.limits.fairWorkPercent -> "regular"
            else -> "baixa"
        }
    }
}
