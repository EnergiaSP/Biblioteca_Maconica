package com.renatocamargo.breviariomaconico.data

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.net.URL
import java.security.MessageDigest

enum class BibliotecaArea(val raw: String, val titulo: String) {
    Breviarios("breviarios", "Breviários"),
    Dicionarios("dicionariosMaconicos", "Dicionários Maçônicos"),
    Judiciario("judiciarioMaconico", "Judiciário Maçônico"),
    Biblioteca("bibliotecaMaconica", "Biblioteca Maçônica");

    companion object {
        fun from(raw: String): BibliotecaArea =
            entries.firstOrNull { it.raw == raw } ?: Biblioteca
    }
}

data class BibliotecaObraCatalogo(
    val id: String,
    val titulo: String,
    val autor: String?,
    val paginas: Int,
    val assuntos: List<String> = emptyList()
)

data class LibraryMetadataFilter(val autor: String = "", val assunto: String = "") {
    val descricao: String get() = listOf("Autor" to autor, "Assunto" to assunto)
        .mapNotNull { (label, value) -> value.trim().takeIf { it.isNotEmpty() }?.let { "$label: $it" } }
        .joinToString(" • ")

    fun matches(work: BibliotecaObraCatalogo): Boolean =
        (autor.isBlank() || TextoFormatter.corresponde(autor, work.autor.orEmpty())) &&
        (assunto.isBlank() || TextoFormatter.corresponde(assunto, work.assuntos.joinToString(" ")))
}

data class BibliotecaPacoteCatalogo(
    val id: String,
    val area: BibliotecaArea,
    val titulo: String,
    val arquivo: String,
    val url: String,
    val tamanhoBytes: Long,
    val sha256: String?,
    val paginas: Int,
    val obras: List<BibliotecaObraCatalogo>
) {
    val tituloPrincipal: String
        get() = obras.firstOrNull()?.titulo ?: titulo

    val detalhe: String
        get() {
            val tamanhoMb = tamanhoBytes / 1024.0 / 1024.0
            return "$paginas páginas • ${"%.1f".format(tamanhoMb)} MB"
        }
}

data class BibliotecaPacoteEstado(
    val pacote: BibliotecaPacoteCatalogo,
    val instalado: Boolean,
    val tamanhoLocalBytes: Long
)

data class BibliotecaPaginaLeitura(
    val obraId: String,
    val tituloObra: String,
    val autor: String?,
    val area: BibliotecaArea,
    val pagina: Int,
    val titulo: String,
    val texto: String,
    val rodape: String,
    val imagens: List<String> = emptyList()
)

data class BibliotecaBuscaResultado(
    val obraId: String,
    val tituloObra: String,
    val area: BibliotecaArea,
    val pagina: Int,
    val trecho: String,
    val ranking: Double = 0.0,
    val data: String? = null,
    val blocoId: String? = null,
    val rodape: String = ""
) {
    val id: String get() = "$obraId|${blocoId ?: data ?: pagina}"
}

data class BibliotecaIndiceTermo(
    val termo: String,
    val ocorrencias: Int,
    val obras: List<String>
)

data class BibliotecaIndiceReferencia(val obraId: String, val tituloObra: String, val entrada: IndiceRemissivoEntry) {
    val id: String get() = "$obraId|${entrada.id}"
}

class BibliotecaCatalogRepository internal constructor(context: Context) {
    private val appFilesDir = context.applicationContext.filesDir
    private val appContext = context.applicationContext
    private val remotePackages: List<BibliotecaPacoteCatalogo>
    val pacotes: List<BibliotecaPacoteCatalogo>
        get() = (remotePackages + importedPackages()).sortedWith(
            compareBy<BibliotecaPacoteCatalogo> { it.area.ordinal }.thenBy { normalized(it.tituloPrincipal) }
        )

    init {
        val json = context.assets.open("rag_catalogo.json")
            .bufferedReader(Charsets.UTF_8)
            .use { it.readText() }
        val root = JSONObject(json)
        val baseURL = root.optString("baseURL").trimEnd('/')
        val array = root.getJSONArray("pacotes")
        remotePackages = List(array.length()) { index ->
            val obj = array.getJSONObject(index)
            val area = BibliotecaArea.from(obj.optString("area"))
            val estatisticas = obj.optJSONObject("estatisticas")
            val obras = obj.optJSONArray("obras")?.let { obrasArray ->
                List(obrasArray.length()) { obraIndex ->
                    val obra = obrasArray.getJSONObject(obraIndex)
                    BibliotecaObraCatalogo(
                        id = obra.optString("id"),
                        titulo = obra.optString("titulo"),
                        autor = obra.optString("autor").takeIf { it.isNotBlank() && it != "null" },
                        paginas = obra.optInt("paginas"),
                        assuntos = obra.optJSONArray("assuntos")?.let { topics ->
                            List(topics.length()) { topics.optString(it) }.filter { it.isNotBlank() }
                        }.orEmpty()
                    )
                }
            }.orEmpty()
            val arquivo = obj.optString("arquivo")
            BibliotecaPacoteCatalogo(
                id = "${area.raw}-$arquivo",
                area = area,
                titulo = obj.optString("titulo"),
                arquivo = arquivo,
                url = obj.optString("url").ifBlank { "$baseURL/$arquivo" },
                tamanhoBytes = obj.optLong("tamanhoBytes"),
                sha256 = obj.optString("sha256").takeIf { it.isNotBlank() && it != "null" },
                paginas = estatisticas?.optInt("paginas") ?: obras.sumOf { it.paginas },
                obras = obras
            )
        }
            .filterNot { pacote -> pacote.obras.any { it.id == "breviario_maconico_rizzardo_da_camino" } }
            .sortedWith(compareBy<BibliotecaPacoteCatalogo> { it.area.ordinal }.thenBy { normalized(it.tituloPrincipal) })
    }

    private fun importedPackages(): List<BibliotecaPacoteCatalogo> =
        LocalPdfOcrImporter.loadImported(appContext).map { work ->
            BibliotecaPacoteCatalogo(
                id = "local-${work.id}",
                area = work.area,
                titulo = work.title,
                arquivo = work.databaseFile,
                url = "",
                tamanhoBytes = File(appFilesDir, "RAGPackages/${work.databaseFile}").length(),
                sha256 = null,
                paginas = work.pages,
                obras = listOf(BibliotecaObraCatalogo(work.id, work.title, work.author, work.pages, work.assuntos))
            )
        }

    fun estados(area: BibliotecaArea): List<BibliotecaPacoteEstado> =
        pacotes.filter { it.area == area }.map { pacote ->
            val local = localFile(pacote)
            BibliotecaPacoteEstado(
                pacote = pacote,
                instalado = local.exists(),
                tamanhoLocalBytes = if (local.exists()) local.length() else 0L
            )
        }

    fun buscar(estados: List<BibliotecaPacoteEstado>, termo: String): List<BibliotecaPacoteEstado> {
        val query = normalized(termo.trim())
        if (query.isBlank()) return estados
        return estados.filter { estado ->
            normalized(estado.pacote.tituloPrincipal).contains(query) ||
                normalized(estado.pacote.titulo).contains(query) ||
                estado.pacote.obras.any { normalized(it.titulo).contains(query) || normalized(it.autor.orEmpty()).contains(query) }
        }
    }

    fun localFile(pacote: BibliotecaPacoteCatalogo): File =
        File(appFilesDir, "RAGPackages/${pacote.arquivo}")

    fun instalar(pacote: BibliotecaPacoteCatalogo, onProgress: (String) -> Unit = {}) {
        require(pacote.url.isNotBlank()) { "Esta obra foi importada localmente e já está instalada." }
        val destino = localFile(pacote)
        destino.parentFile?.mkdirs()
        val temporario = File.createTempFile("pacote-", ".download", destino.parentFile)
        try {
            onProgress("Baixando ${pacote.tituloPrincipal}")
            val connection = URL(pacote.url).openConnection().apply {
                connectTimeout = 30_000
                readTimeout = 60_000
            }
            connection.getInputStream().use { input ->
                temporario.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    var total = 0L
                    var count = input.read(buffer)
                    while (count >= 0) {
                        total += count
                        check(total <= pacote.tamanhoBytes) { "Tamanho inesperado de ${pacote.tituloPrincipal}." }
                        output.write(buffer, 0, count)
                        count = input.read(buffer)
                    }
                    output.fd.sync()
                }
            }

            check(temporario.length() == pacote.tamanhoBytes) { "Download incompleto de ${pacote.tituloPrincipal}." }
            pacote.sha256?.let { esperado ->
                check(sha256(temporario).equals(esperado, ignoreCase = true)) {
                    "Falha de integridade em ${pacote.tituloPrincipal}."
                }
            }
            // Same-directory rename is atomic and keeps the previous package on failure.
            android.system.Os.rename(temporario.absolutePath, destino.absolutePath)
        } finally {
            temporario.delete()
        }
    }

    fun remover(pacote: BibliotecaPacoteCatalogo) {
        val localWork = pacote.id.removePrefix("local-")
        if (pacote.id.startsWith("local-")) {
            LocalPdfOcrImporter(appContext).remove(localWork)
        } else {
            localFile(pacote).takeIf { it.exists() }?.delete()
        }
    }

    fun paginasDaObra(obraId: String, limite: Int? = null): List<BibliotecaPaginaLeitura> {
        val pacote = pacotes.firstOrNull { pacote -> pacote.obras.any { it.id == obraId } } ?: return emptyList()
        val banco = localFile(pacote)
        if (!banco.exists()) return emptyList()

        val notas = notasPorPagina(banco, obraId)
        val imagens = imagensPorPagina(banco, obraId)
        val sql = buildString {
            append(
                """
                SELECT
                    p.numero_original,
                    COALESCE(p.titulo, ''),
                    p.texto_integral,
                    o.titulo,
                    COALESCE(o.autor, ''),
                    o.area
                FROM rag_paginas p
                JOIN rag_obras o ON o.id = p.obra_id
                WHERE p.obra_id = ?
                ORDER BY p.numero_original
                """.trimIndent()
            )
            if (limite != null) append(" LIMIT $limite")
        }

        return abrirSomenteLeitura(banco).use { db ->
            db.rawQuery(sql, arrayOf(obraId)).use { cursor ->
                buildList {
                    while (cursor.moveToNext()) {
                        val pagina = cursor.getInt(0)
                        val tituloPagina = cursor.getString(1).ifBlank { "Página $pagina" }
                        val texto = cursor.getString(2).orEmpty()
                        val tituloObra = cursor.getString(3).orEmpty()
                        val autor = cursor.getString(4).ifBlank { null }
                        val area = BibliotecaArea.from(cursor.getString(5).orEmpty())
                        add(
                            BibliotecaPaginaLeitura(
                                obraId = obraId,
                                tituloObra = tituloObra,
                                autor = autor,
                                area = area,
                                pagina = pagina,
                                titulo = tituloPagina,
                                texto = TextoFormatter.textoComParagrafos(texto),
                                rodape = notas[pagina].orEmpty().joinToString("\n"),
                                imagens = imagens[pagina].orEmpty()
                            )
                        )
                    }
                }
            }
        }
    }

    fun percorrerItensEstudo(obraId: String, cancelled: () -> Boolean = { false }, receber: (List<BreviarioItem>) -> Boolean) {
        val pacote = pacotes.firstOrNull { it.obras.any { obra -> obra.id == obraId } } ?: return
        val banco = localFile(pacote)
        if (!banco.exists()) return
        abrirSomenteLeitura(banco).use { db -> percorrerItensEstudo(db, obraId, cancelled = cancelled, receber = receber) }
    }

    fun primeiraPaginaDaObra(obraId: String): BibliotecaPaginaLeitura? =
        paginasDaObra(obraId, limite = 1).firstOrNull()

    fun buscarConteudo(termo: String, area: BibliotecaArea? = null, obraId: String? = null, limite: Int = 80, offset: Int = 0,
        cancelled: () -> Boolean = { false }, filtro: LibraryMetadataFilter = LibraryMetadataFilter()): List<BibliotecaBuscaResultado> {
        val query = termo.trim()
        if (query.isBlank()) return emptyList()

        val consultaFTS = TextoFormatter.consultaFTSSegura(query)

        val candidatos = pacotes
            .filter { pacote -> area == null || pacote.area == area }
            .filter { pacote -> obraId == null || pacote.obras.any { it.id == obraId } }
            .filter { localFile(it).exists() }
            .filter { pacote -> pacote.obras.any { filtro.matches(it) } }

        val quantidade = limite.coerceIn(1, 500) + offset.coerceAtLeast(0)
        val resultados = mutableListOf<BibliotecaBuscaResultado>()
        for (pacote in candidatos.distinctBy { localFile(it).absolutePath }) {
            if (cancelled()) throw kotlinx.coroutines.CancellationException()
            val permitidas = candidatos.filter { localFile(it) == localFile(pacote) }
                .flatMap { it.obras }.filter(filtro::matches).map { it.id }.toSet()
            val excluidas = mutableSetOf(ObraId.BREVIARIO_SECULO_XXI)
            abrirSomenteLeitura(localFile(pacote)).use { db ->
                // A file may contain works absent from this catalog entry.
                db.rawQuery("SELECT id FROM rag_obras", emptyArray()).use { cursor ->
                    while (cursor.moveToNext()) if (cursor.getString(0) !in permitidas) excluidas.add(cursor.getString(0))
                }
                val scopedIndex = db.rawQuery("PRAGMA table_info(rag_fts)", emptyArray()).use { cursor ->
                    var found = false
                    while (cursor.moveToNext()) if (cursor.getString(1) == "obra_id") found = true
                    found
                }
                val workJoin = if (scopedIndex) " AND p.obra_id = rag_fts.obra_id" else ""
                val argumentos = mutableListOf(consultaFTS)
                val filtros = mutableListOf<String>()
                excluidas.sorted().forEach { id ->
                    filtros.add("p.obra_id != ?")
                    argumentos.add(id)
                }
                if (area != null) {
                    filtros.add("o.area = ?")
                    argumentos.add(area.raw)
                }
                if (obraId != null) {
                    filtros.add("p.obra_id = ?")
                    argumentos.add(obraId)
                }
                val whereExtra = if (filtros.isEmpty()) "" else " AND ${filtros.joinToString(" AND ")}"
                argumentos.add(quantidade.toString())
                val sql = """
                    SELECT p.obra_id, o.titulo, o.area, p.pagina, p.texto, bm25(rag_fts) AS ranking, p.id
                    FROM rag_fts
                    JOIN rag_paragrafos p ON p.id = rag_fts.bloco_id$workJoin
                    JOIN rag_obras o ON o.id = p.obra_id
                    WHERE rag_fts MATCH ?$whereExtra
                    ORDER BY ranking, p.obra_id, p.pagina, CAST(p.id AS TEXT)
                    LIMIT ?
                """.trimIndent()
                db.rawQuery(sql, argumentos.toTypedArray()).use { cursor ->
                    while (cursor.moveToNext()) {
                        resultados.add(
                            BibliotecaBuscaResultado(
                                obraId = cursor.getString(0),
                                tituloObra = cursor.getString(1),
                                area = BibliotecaArea.from(cursor.getString(2)),
                                pagina = cursor.getInt(3),
                                trecho = TextoFormatter.textoComParagrafos(cursor.getString(4).orEmpty()),
                                ranking = cursor.getDouble(5),
                                blocoId = cursor.getString(6)
                            )
                        )
                    }
                }
            }
            resultados.addAll(NotesSearchIndex.search(localFile(pacote), appContext.cacheDir, consultaFTS,
                area, obraId, quantidade, excluidas, cancelled))
        }

        if ((area == null || area == BibliotecaArea.Breviarios) && filtro.matches(obraBreviarioIntegrado)) {
            val embedded = BreviarioRepository.get(appContext)
            embedded.buscarLeituras(query).filter { obraId == null || it.obraId == obraId }.forEach {
                resultados.add(BibliotecaBuscaResultado(it.obraId, "Breviário Maçônico - Kennyo Ismail", BibliotecaArea.Breviarios,
                    it.pagina, it.texto, data = it.data, rodape = it.rodape))
            }
        }
        val selecionados = resultados.distinctBy { it.id }
            .sortedWith(compareBy<BibliotecaBuscaResultado> { it.ranking }.thenBy { it.obraId }.thenBy { it.pagina }.thenBy { it.blocoId ?: it.data.orEmpty() })
            .drop(offset.coerceAtLeast(0)).take(limite.coerceIn(1, 500))
        val notas = mutableMapOf<Pair<String, Int>, String>()
        for ((id, trechos) in selecionados.filter { it.data == null }.groupBy { it.obraId }) {
            if (cancelled()) throw kotlinx.coroutines.CancellationException()
            val pacote = candidatos.firstOrNull { p -> p.obras.any { it.id == id } } ?: continue
            notasPorPagina(localFile(pacote), id, trechos.map { it.pagina }.distinct()).forEach { (pagina, linhas) ->
                notas[id to pagina] = linhas.joinToString("\n")
            }
        }
        return selecionados.map { it.copy(rodape = notas[it.obraId to it.pagina] ?: it.rodape) }
    }

    fun obrasInstaladas(area: BibliotecaArea? = null): List<BibliotecaObraCatalogo> =
        pacotes
            .filter { pacote -> area == null || pacote.area == area }
            .filter { localFile(it).exists() }
            .flatMap { it.obras }
            .sortedBy { normalized(it.titulo) }

    fun obrasDisponiveis(area: BibliotecaArea? = null): List<BibliotecaObraCatalogo> =
        (obrasInstaladas(area) + if (area == null || area == BibliotecaArea.Breviarios)
            listOf(obraBreviarioIntegrado)
        else emptyList()).distinctBy { it.id }.sortedBy { normalized(it.titulo) }

    private val obraBreviarioIntegrado get() = BibliotecaObraCatalogo(
        ObraId.BREVIARIO_SECULO_XXI, "Breviário Maçônico - Kennyo Ismail", "Kennyo Ismail", 365,
        listOf("Leitura diária", "Reflexão", "Ética", "Filosofia", "Ritualística")
    )

    fun indiceRemissivoGlobal(area: BibliotecaArea? = null, obraId: String? = null): List<BibliotecaIndiceReferencia> {
        if (area != null && area != BibliotecaArea.Breviarios) return emptyList()
        if (obraId != null && obraId != ObraId.BREVIARIO_SECULO_XXI) return emptyList()
        return BreviarioRepository.get(appContext).indice.map {
            BibliotecaIndiceReferencia(ObraId.BREVIARIO_SECULO_XXI, "Breviário Maçônico - Kennyo Ismail", it)
        }.sortedWith(compareBy<BibliotecaIndiceReferencia> { normalized(it.entrada.termo) }.thenBy { it.id })
    }

    fun indicePaginas(obraId: String, limite: Int = 50, filtro: String = ""): List<BibliotecaBuscaResultado> {
        if (obraId == ObraId.BREVIARIO_SECULO_XXI) {
            val consulta = normalized(filtro)
            return BreviarioRepository.get(appContext).itens.asSequence()
                .filter { it.obraId == obraId && normalized("${it.data} ${TextoFormatter.dataPorExtenso(it.data)} ${it.titulo}").contains(consulta) }
                .sortedBy { it.pagina }.take(limite.coerceAtLeast(1)).map {
                    BibliotecaBuscaResultado(it.obraId, "Breviário Maçônico - Kennyo Ismail", BibliotecaArea.Breviarios,
                        it.pagina, it.titulo, data = it.data, rodape = it.rodape)
                }.toList()
        }
        val pacote = pacotes.firstOrNull { p -> p.obras.any { it.id == obraId } } ?: return emptyList()
        val file = localFile(pacote)
        if (!file.exists()) return emptyList()
        return abrirSomenteLeitura(file).use { db ->
            db.rawQuery("SELECT o.titulo, o.area, p.numero_original, COALESCE(p.titulo, '') FROM rag_paginas p JOIN rag_obras o ON o.id = p.obra_id WHERE p.obra_id = ? ORDER BY p.numero_original",
                arrayOf(obraId)).use { row ->
                buildList {
                    while (size < limite.coerceAtLeast(1) && row.moveToNext()) {
                        if (normalized("${row.getInt(2)} ${row.getString(3)}").contains(normalized(filtro)))
                            add(BibliotecaBuscaResultado(obraId, row.getString(0), BibliotecaArea.from(row.getString(1)), row.getInt(2), row.getString(3)))
                    }
                }
            }
        }
    }

    private fun notasPorPagina(banco: File, obraId: String, paginas: List<Int>? = null): Map<Int, List<String>> =
        abrirSomenteLeitura(banco).use { db ->
            db.rawQuery(
                """
                SELECT pagina, numero, texto
                FROM rag_notas
                WHERE obra_id = ?
                ${paginas?.let { "AND pagina IN (${it.joinToString(",") { "?" }})" }.orEmpty()}
                ORDER BY pagina, numero
                """.trimIndent(),
                (listOf(obraId) + paginas.orEmpty().map { it.toString() }).toTypedArray()
            ).use { cursor ->
                buildMap<Int, MutableList<String>> {
                    while (cursor.moveToNext()) {
                        val pagina = cursor.getInt(0)
                        val numero = cursor.getString(1).orEmpty()
                        val texto = cursor.getString(2).orEmpty()
                        val linha = if (numero.isBlank()) texto else "$numero $texto"
                        getOrPut(pagina) { mutableListOf() }.add(TextoFormatter.rodapeEmLinhas(linha))
                    }
                }
            }
        }

    private fun imagensPorPagina(banco: File, obraId: String): Map<Int, List<String>> =
        runCatching {
            abrirSomenteLeitura(banco).use { db ->
            db.rawQuery(
                """
                SELECT pagina, caminho_relativo
                FROM rag_imagens
                WHERE obra_id = ?
                ORDER BY pagina, id
                """.trimIndent(),
                arrayOf(obraId)
            ).use { cursor ->
                buildMap<Int, MutableList<String>> {
                    while (cursor.moveToNext()) {
                        val pagina = cursor.getInt(0)
                        val relative = cursor.getString(1).orEmpty()
                        val candidates = listOf(
                            File(banco.parentFile, relative),
                            File(appFilesDir, relative)
                        )
                        candidates.firstOrNull { it.exists() }?.let { file ->
                            getOrPut(pagina) { mutableListOf() }.add(file.absolutePath)
                        }
                    }
                }
            }
            }
        }.getOrDefault(emptyMap())

    private fun abrirSomenteLeitura(file: File): RagSQLite =
        RagSQLite.open(file.absolutePath, readOnly = true)

    companion object {
        @Volatile private var instance: BibliotecaCatalogRepository? = null

        fun get(context: Context): BibliotecaCatalogRepository =
            instance ?: synchronized(this) {
                instance ?: BibliotecaCatalogRepository(context.applicationContext).also { instance = it }
            }
    }
}

internal fun percorrerItensEstudo(db: RagSQLite, obraId: String, tamanhoLote: Int = 100,
    cancelled: () -> Boolean = { false }, receber: (List<BreviarioItem>) -> Boolean) {
    var lastPage = 0
    while (!cancelled()) {
        val batch = db.rawQuery("""
            SELECT p.numero_original, COALESCE(p.titulo, ''), p.texto_integral, COALESCE(o.autor, '')
            FROM rag_paginas p JOIN rag_obras o ON o.id = p.obra_id
            WHERE p.obra_id = ? AND p.numero_original > ? ORDER BY p.numero_original LIMIT ?
        """.trimIndent(), arrayOf(obraId, lastPage, tamanhoLote.coerceIn(1, 200))).use { cursor ->
            buildList {
                while (cursor.moveToNext()) {
                    val page = cursor.getInt(0)
                    add(BreviarioItem("$obraId-pagina-$page".hashCode(), "P$page",
                        cursor.getString(1).ifBlank { "Página $page" }, cursor.getString(3),
                        cursor.getString(2), "", page, obraId))
                }
            }
        }
        if (batch.isEmpty() || cancelled()) return
        val notes = db.rawQuery("SELECT pagina, numero, texto FROM rag_notas WHERE obra_id = ? AND pagina IN (${batch.joinToString { "?" }}) ORDER BY pagina, numero",
            (listOf<Any>(obraId) + batch.map { it.pagina }).toTypedArray()).use { cursor ->
            buildMap<Int, MutableList<String>> {
                while (cursor.moveToNext()) {
                    val number = cursor.getString(1)
                    val text = cursor.getString(2)
                    getOrPut(cursor.getInt(0)) { mutableListOf() }.add(if (number.isEmpty()) text else "$number $text")
                }
            }
        }
        if (!receber(batch.map { it.copy(rodape = notes[it.pagina].orEmpty().joinToString("\n")) })) return
        lastPage = batch.last().pagina
    }
}

private fun sha256(file: File): String {
    val digest = MessageDigest.getInstance("SHA-256")
    file.inputStream().use { input ->
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        while (true) {
            val read = input.read(buffer)
            if (read <= 0) break
            digest.update(buffer, 0, read)
        }
    }
    return digest.digest().joinToString("") { "%02x".format(it) }
}
