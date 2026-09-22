package com.renatocamargo.breviariomaconico.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.text.Normalizer
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

class BreviarioRepository private constructor(context: Context) {
    val itens: List<BreviarioItem>
    val indice: List<IndiceRemissivoEntry>

    private val itensPorData: Map<String, BreviarioItem>
    private val itensPorObraEData: Map<String, BreviarioItem>
    private val pesquisaNormalizada: Map<String, String>

    init {
        val json = context.assets.open("breviario.json")
            .bufferedReader(Charsets.UTF_8)
            .use { it.readText() }
        val root = JSONObject(json)

        itens = root.getJSONArray("itens").toList { obj ->
            BreviarioItem(
                id = obj.optInt("id"),
                data = obj.optString("data"),
                titulo = obj.optString("titulo"),
                autor = obj.optString("autor"),
                texto = TextoFormatter.textoComParagrafos(obj.optString("texto")),
                rodape = TextoFormatter.rodapeEmLinhas(obj.optString("rodape")),
                pagina = obj.optInt("pagina"),
                obraId = obj.optString("obraID").ifBlank { ObraId.BREVIARIO_SECULO_XXI }
            )
        }.sortedWith(compareBy({ it.data.substringAfter("/").toIntOrNull() ?: 0 }, { it.data.substringBefore("/").toIntOrNull() ?: 0 }))

        indice = root.getJSONArray("indiceRemissivo").toList { obj ->
            IndiceRemissivoEntry(
                id = obj.optInt("id"),
                termo = obj.optString("termo"),
                datas = obj.optJSONArray("datas").strings(),
                paginas = obj.optJSONArray("paginas").ints()
            )
        }.sortedBy { normalized(it.termo) }

        itensPorData = itens.associateBy { it.data }
        itensPorObraEData = itens.associateBy { "${it.obraId}|${it.data}" }
        val indicePorData = indice.flatMap { entry -> entry.datas.map { it to entry.termo } }.groupBy({ it.first }, { it.second })
        pesquisaNormalizada = itens.associate { item -> item.chavePersistencia to normalized(
            listOf(item.titulo, item.texto, item.rodape, item.data, item.autor, indicePorData[item.data].orEmpty().joinToString(" ")).joinToString(" ")) }
    }

    fun hoje(): BreviarioItem = porData(LocalDate.now().format(DateTimeFormatter.ofPattern("dd/MM")))
        ?: itens.first()

    fun porData(data: String): BreviarioItem? = itensPorData[data]

    fun porObraEData(obraId: String, data: String): BreviarioItem? =
        itensPorObraEData["$obraId|$data"]

    fun leiturasDeHoje(obraIds: Set<String>? = null): List<BreviarioItem> {
        val hoje = LocalDate.now().format(DateTimeFormatter.ofPattern("dd/MM"))
        return itens.filter { it.data == hoje && (obraIds == null || it.obraId in obraIds) }
    }

    fun proximo(item: BreviarioItem): BreviarioItem {
        return adjacentReading(itens, item, 1)
    }

    fun anterior(item: BreviarioItem): BreviarioItem {
        return adjacentReading(itens, item, -1)
    }

    fun buscarLeituras(query: String): List<BreviarioItem> {
        val q = normalized(query)
        if (q.isBlank()) return itens
        return itens.filter { TextoFormatter.corresponde(query, pesquisaNormalizada[it.chavePersistencia].orEmpty()) }
    }

    fun buscarIndice(query: String): List<IndiceRemissivoEntry> {
        val q = normalized(query)
        if (q.isBlank()) return indice
        return indice.filter { normalized(it.termo).contains(q) || it.datas.any { data -> data.contains(q) } }
    }

    companion object {
        @Volatile private var instance: BreviarioRepository? = null

        fun get(context: Context): BreviarioRepository =
            instance ?: synchronized(this) {
                instance ?: BreviarioRepository(context.applicationContext).also { instance = it }
            }
    }
}

object TextoFormatter {
    fun datasSemana(data: LocalDate): Set<String> {
        val primeiro = data.minusDays((data.dayOfWeek.value % 7).toLong())
        return (0L..6L).map { primeiro.plusDays(it).format(DateTimeFormatter.ofPattern("dd/MM")) }.toSet()
    }

    fun datasIntervalo(start: LocalDate, end: LocalDate): Set<String> {
        val first = minOf(start, end)
        val last = maxOf(start, end)
        val count = minOf(java.time.temporal.ChronoUnit.DAYS.between(first, last) + 1, 366L)
        return (0 until count).map { first.plusDays(it).format(DateTimeFormatter.ofPattern("dd/MM")) }.toSet()
    }

    fun chamadasRodape(rodape: String): Set<String> =
        Regex("(?m)^\\s*(\\d{1,4})(?=[.)\\s-])").findAll(rodape).map { it.groupValues[1] }.toSet()

    fun referencias(texto: String, rodape: String): List<IntRange> {
        val notas = chamadasRodape(rodape)
        return Regex("(?<![\\d/])\\d{1,4}(?![\\d/])").findAll(texto).filter { match ->
            val anterior = texto.substring(0, match.range.first).lastOrNull { !it.isWhitespace() }
            match.value in notas && anterior != null && !anterior.isDigit() && anterior != '/'
        }.map { it.range }.toList()
    }

    fun sobrescrito(texto: String, rodape: String): String {
        val resultado = StringBuilder(texto)
        val digitos = "⁰¹²³⁴⁵⁶⁷⁸⁹"
        referencias(texto, rodape).asReversed().forEach { range ->
            resultado.replace(range.first, range.last + 1, texto.substring(range).map { digitos[it - '0'] }.joinToString(""))
        }
        return resultado.toString()
    }

    fun consultaFTSSegura(termo: String): String {
        val tokens = termosBusca(termo)
        fun literal(text: String) = "\"${text.replace("\"", "\"\"")}\""
        return if (tokens.isEmpty()) literal(termo) else tokens.joinToString(" AND ", transform = ::literal)
    }

    fun termosBusca(termo: String): List<String> = Regex("\"([^\"]+)\"|([\\p{L}\\p{N}]+)").findAll(termo.lowercase(Locale.ROOT)).mapNotNull {
        if (it.groupValues[1].isNotEmpty()) it.groupValues[1].split(Regex("[^\\p{L}\\p{N}]+"))
            .filter(String::isNotBlank).joinToString(" ").takeIf(String::isNotBlank)
        else it.groupValues[2].takeIf { word -> word.length > 1 }
    }.toList()

    fun corresponde(termo: String, texto: String): Boolean {
        val termos = termosBusca(termo)
        if (termos.isEmpty()) return false
        val palavras = " " + normalized(texto).split(Regex("[^\\p{L}\\p{N}]+"))
            .filter(String::isNotBlank).joinToString(" ") + " "
        return termos.all { palavras.contains(" " + normalized(it) + " ") }
    }

    fun textoComParagrafos(texto: String): String =
        texto.replace("\r\n", "\n")
            .replace("\r", "\n")
            .split(Regex("\\n{2,}"))
            .map { limparLinha(it) }
            .filter { it.isNotBlank() }
            .joinToString("\n\n")

    fun rodapeEmLinhas(texto: String): String {
        val limpo = textoComParagrafos(texto).replace("\n\n", "\n")
        return limpo.replace(Regex("\\s+(?=\\d{1,4}\\s+[A-ZÁÉÍÓÚÂÊÔÃÕÇ])"), "\n")
            .lineSequence()
            .map { limparLinha(it) }
            .filter { it.isNotBlank() }
            .joinToString("\n")
    }

    fun textoCompartilhavel(item: BreviarioItem, comentario: String? = null): String {
        val base = buildString {
            appendLine("Breviário Maçônico")
            appendLine(dataPorExtenso(item.data))
            appendLine(item.titulo)
            if (item.autor.isNotBlank()) appendLine(item.autor)
            appendLine()
            appendLine(sobrescrito(item.texto, item.rodape))
            if (item.rodape.isNotBlank()) {
                appendLine()
                appendLine("Notas de rodapé")
                appendLine(item.rodape)
            }
        }.trim()

        val comentarioLimpo = comentario?.trim().orEmpty()
        return if (comentarioLimpo.isBlank()) base else "$base\n\nComentário pessoal\n${sobrescrito(comentarioLimpo, item.rodape)}"
    }

    fun dataPorExtenso(data: String): String {
        if (data.count { it == '/' } != 1) return data
        val dia = data.substringBefore("/").toIntOrNull() ?: return data
        val mes = data.substringAfter("/").toIntOrNull() ?: return data
        if (dia !in 1..31 || mes !in 1..12) return data
        val meses = listOf("", "janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro")
        return "%02d de %s".format(dia, meses.getOrElse(mes) { "" })
    }

    private fun limparLinha(texto: String): String =
        texto.split(Regex("\\s+")).filter { it.isNotBlank() }.joinToString(" ").trim()
}

fun normalized(value: String): String {
    val portugueseBrazil = Locale.Builder().setLanguage("pt").setRegion("BR").build()
    val clean = Normalizer.normalize(value.lowercase(portugueseBrazil), Normalizer.Form.NFD)
    return clean.replace(Regex("\\p{Mn}+"), "")
}

private fun JSONArray?.strings(): List<String> {
    if (this == null) return emptyList()
    return List(length()) { index -> optString(index) }
}

private fun JSONArray?.ints(): List<Int> {
    if (this == null) return emptyList()
    return List(length()) { index -> optInt(index) }
}

private inline fun <T> JSONArray.toList(transform: (JSONObject) -> T): List<T> =
    List(length()) { index -> transform(getJSONObject(index)) }

private fun Int.floorMod(size: Int): Int = ((this % size) + size) % size

internal fun adjacentReading(items: List<BreviarioItem>, current: BreviarioItem, step: Int): BreviarioItem {
    val work = items.filter { it.obraId == current.obraId }
    if (work.isEmpty()) return current
    val index = work.indexOfFirst { it.chavePersistencia == current.chavePersistencia }
    if (index < 0) return current
    return work[(index + step).floorMod(work.size)]
}
