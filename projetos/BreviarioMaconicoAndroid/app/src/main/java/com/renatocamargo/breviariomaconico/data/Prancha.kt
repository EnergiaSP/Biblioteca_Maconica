package com.renatocamargo.breviariomaconico.data

import android.content.Context
import org.json.JSONObject

/**
 * Prancha built from a dossier with only the excerpts it already cites, ABNT citations and references,
 * and the side-by-side comparison of authors. Mirrors `Tools/prancha_referencia.py`;
 * `casos_prancha_v1.json` holds the golden cases both apps reproduce.
 */
internal object Prancha {
    data class Config(
        val noPlace: String, val noPublisher: String, val noPlaceNoPublisher: String, val noYear: String,
        val suffixes: List<String>, val articles: List<String>, val authorSeparators: List<String>, val conclusionTerms: Int,
        val sections: Map<String, String>, val texts: Map<String, String>, val labels: Map<String, String>
    ) {
        fun text(key: String, values: Map<String, String> = emptyMap()) = fill(texts[key] ?: key, values)
        fun label(key: String) = labels[key] ?: key
    }
    /** Bibliographic data of a work (`obras_referencias_v1.json`); empty fields are unknown. */
    data class Work(val titulo: String = "", val autor: String = "", val ano: String = "", val editora: String = "", val local: String = "")
    data class Section(val title: String, val paragraphs: List<String>)
    data class Author(val who: String, val works: List<String>, val excerpts: List<String>)
    data class Result(val title: String, val sections: List<Section>, val comparison: List<Author>, val references: List<String>, val text: String)

    @Volatile private var cachedConfig: Config? = null
    @Volatile private var cachedWorks: Map<String, Work>? = null

    fun loadConfig(context: Context): Config = cachedConfig ?: parse(
        context.assets.open("prancha_v1.json").bufferedReader().use { JSONObject(it.readText()) }
    ).also { cachedConfig = it }

    fun loadWorks(context: Context): Map<String, Work> = cachedWorks ?: parseWorks(
        context.assets.open("obras_referencias_v1.json").bufferedReader().use { JSONObject(it.readText()) }.getJSONObject("obras")
    ).also { cachedWorks = it }

    /** Cleaned reference title and author ("Aprendizado Maçônico — Rizzardo da Camino"), or [fallback] without a reference. */
    fun displayTitle(works: Map<String, Work>, workId: String, fallback: String): String =
        works[workId]?.takeIf { it.titulo.isNotBlank() }?.let { listOf(it.titulo, it.autor).filter(String::isNotBlank).joinToString(" — ") } ?: fallback

    fun parse(json: JSONObject): Config {
        require(json.getInt("schemaVersion") == 1)
        fun list(key: String) = json.getJSONArray(key).let { a -> List(a.length()) { a.getString(it) } }
        fun map(key: String) = json.getJSONObject(key).let { o -> o.keys().asSequence().associateWith { o.getString(it) } }
        return Config(json.getString("semLocal"), json.getString("semEditora"), json.getString("semLocalEditora"), json.getString("semAno"),
            list("sufixos"), list("artigos"), list("separadoresAutores"), json.getInt("limiteTermosConclusao"),
            map("secoes"), map("textos"), map("rotulos"))
    }

    fun parseWork(json: JSONObject) = Work(json.optString("titulo"), json.optString("autor"), json.optString("ano"),
        json.optString("editora"), json.optString("local"))

    fun parseWorks(json: JSONObject): Map<String, Work> = json.keys().asSequence().associateWith { parseWork(json.getJSONObject(it)) }

    fun fill(template: String, values: Map<String, String>) =
        values.entries.fold(template) { text, (name, value) -> text.replace("{$name}", value) }

    private fun words(text: String) = text.split(Regex("\\s+")).filter { it.isNotEmpty() }

    /** (surname, given names) of each author. */
    fun authors(name: String, c: Config): List<Pair<String, String>> {
        var parts = listOf(name.trim())
        for (separator in c.authorSeparators) parts = parts.flatMap { part -> part.split(separator).map { it.trim() } }
        return parts.filter { it.isNotEmpty() }.map { part ->
            val comma = part.indexOf(',')
            if (comma >= 0) return@map part.substring(0, comma).trim() to part.substring(comma + 1).trim()
            val list = words(part)
            val size = if (list.size >= 3 && list.last().lowercase() in c.suffixes) 2 else 1
            list.takeLast(size).joinToString(" ") to list.dropLast(size).joinToString(" ")
        }
    }

    fun join(items: List<String>, c: Config): String =
        if (items.size <= 1) items.joinToString("") else items.dropLast(1).joinToString(", ") + (c.texts["ultimoSeparador"] ?: " e ") + items.last()

    /** Authors in natural order ("Luc Ferry"), joined by commas and " e ". */
    fun spoken(name: String, c: Config) = join(authors(name, c).map { (surname, given) -> "$given $surname".trim() }, c)

    fun excerpt(text: String) = text.trimEnd(' ', ';', ',', ':')

    /** Title as the entry of a work without author: first word (and a leading article) in capitals. */
    fun titleEntry(title: String, c: Config): String {
        val list = words(title)
        val size = if (list.size >= 2 && list[0].lowercase() in c.articles) 2 else 1
        return (list.take(size).map { it.uppercase() } + list.drop(size)).joinToString(" ")
    }

    fun reference(work: Work, c: Config): String {
        val place = work.local.trim()
        val publisher = work.editora.trim()
        val imprint = if (place.isEmpty() && publisher.isEmpty()) c.noPlaceNoPublisher
            else "${place.ifEmpty { c.noPlace }}: ${publisher.ifEmpty { c.noPublisher }}"
        val year = work.ano.trim().ifEmpty { c.noYear }
        val title = work.titulo.trim()
        val names = authors(work.autor, c)
        if (names.isEmpty()) return "${titleEntry(title, c)}. $imprint, $year."
        val entry = names.joinToString("; ") { (surname, given) -> if (given.isEmpty()) surname.uppercase() else "${surname.uppercase()}, $given" }
        return "$entry${if (entry.endsWith(".")) "" else "."} $title. $imprint, $year."
    }

    fun citation(work: Work, page: Int, c: Config): String {
        val names = authors(work.autor, c)
        val who = if (names.isEmpty()) {
            val list = words(titleEntry(work.titulo.trim(), c))
            val size = if (list.size >= 2 && list[0].lowercase() in c.articles) 2 else 1
            list.take(size).joinToString(" ") + "..."
        } else names.joinToString("; ") { it.first.uppercase() }
        return "($who, ${work.ano.trim().ifEmpty { c.noYear }}, p. $page)"
    }

    fun build(
        term: String, sources: List<DossierAnalysis.Source>, definitions: List<DossierAnalysis.Excerpt>,
        summary: List<DossierAnalysis.Excerpt>, divergences: List<DossierAnalysis.Excerpt>,
        relatedTerms: List<DossierAnalysis.RelatedTerm>, works: Map<String, Work>, c: Config
    ): Result {
        val byId = sources.associateBy { it.id }
        val topic = words(DossierAnalysis.nfc(term)).joinToString(" ")
        fun work(sourceId: String): Work {
            val source = byId.getValue(sourceId)
            val data = works[source.obraId] ?: Work()
            return if (data.titulo.isBlank()) data.copy(titulo = source.tituloObra) else data
        }
        fun cite(item: DossierAnalysis.Excerpt) = citation(work(item.fonte), byId.getValue(item.fonte).pagina, c)
        fun quoted(item: DossierAnalysis.Excerpt) = c.text("trecho", mapOf("trecho" to excerpt(item.texto), "citacao" to cite(item)))

        val unique = (definitions + summary + divergences).filter { it.fonte in byId }.distinct()

        // Side by side: every cited excerpt grouped by author (or by work when the author is unknown).
        class Group(val who: String, val several: Boolean) {
            val works = mutableListOf<String>()
            val excerpts = mutableListOf<String>()
            val summary = mutableListOf<String>()
        }
        val groups = LinkedHashMap<String, Group>()
        for (item in unique) {
            val data = work(item.fonte)
            val known = data.autor.trim()
            val who = if (known.isEmpty()) c.text("semAutor", mapOf("obra" to data.titulo)) else spoken(known, c)
            val group = groups.getOrPut(DossierAnalysis.fold(who)) { Group(who, authors(known, c).size > 1) }
            if (data.titulo !in group.works) group.works += data.titulo
            group.excerpts += quoted(item)
            if (item in summary) group.summary += quoted(item)
        }
        val ordered = groups.entries.sortedWith(compareBy({ -it.value.excerpts.size }, { it.key })).map { it.value }
        val worksCited = unique.map { byId.getValue(it.fonte).obraId }.distinct()

        val introduction = listOf(
            if (unique.isEmpty()) c.text("semTrechos", mapOf("tema" to topic))
            else c.text("abertura", mapOf("n" to "${worksCited.size}", "tema" to topic))
        ) + definitions.filter { it.fonte in byId }.map {
            c.text("definicao", mapOf("obra" to work(it.fonte).titulo, "trecho" to excerpt(it.texto), "citacao" to cite(it)))
        }
        val development = ordered.filter { it.summary.isNotEmpty() }.map {
            c.text(if (it.several) "autoresAfirmam" else "autorAfirma", mapOf("quem" to it.who, "trechos" to it.summary.joinToString("; ")))
        }
        val divergent = divergences.filter { it.fonte in byId }.map {
            c.text("divergencia", mapOf("obra" to work(it.fonte).titulo, "trecho" to excerpt(it.texto), "citacao" to cite(it)))
        }
        val terms = relatedTerms.take(c.conclusionTerms).map { it.form }
        val conclusion = (if (terms.isEmpty()) emptyList() else listOf(c.text("conclusaoTermos", mapOf("tema" to topic, "termos" to join(terms, c))))) +
            c.text("conclusaoPendente")
        val references = worksCited.map { obra -> reference(work(unique.first { byId.getValue(it.fonte).obraId == obra }.fonte), c) }
            .toSet().sortedWith(compareBy({ DossierAnalysis.fold(it) }, { it }))

        val sections = buildList {
            add(Section(c.sections["introducao"].orEmpty(), introduction))
            add(Section(c.sections["desenvolvimento"].orEmpty(), development))
            if (divergent.isNotEmpty()) add(Section(c.sections["divergencias"].orEmpty(), divergent))
            add(Section(c.sections["conclusao"].orEmpty(), conclusion))
            add(Section(c.sections["referencias"].orEmpty(), references))
        }.filter { it.paragraphs.isNotEmpty() }
        val title = c.text("titulo", mapOf("tema" to topic))
        val text = (listOf(title) + sections.map { it.title + "\n\n" + it.paragraphs.joinToString("\n\n") }).joinToString("\n\n") + "\n"
        return Result(title, sections, ordered.map { Author(it.who, it.works.toList(), it.excerpts.toList()) }, references, text)
    }
}
