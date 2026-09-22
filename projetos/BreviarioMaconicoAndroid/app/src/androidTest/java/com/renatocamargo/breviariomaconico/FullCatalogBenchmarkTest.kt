package com.renatocamargo.breviariomaconico

import android.content.Context
import android.os.SystemClock
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.renatocamargo.breviariomaconico.data.*
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class FullCatalogBenchmarkTest {
    @Test
    fun installedCorpusStudySelectionProducesComparableEvidence() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val catalog = BibliotecaCatalogRepository.get(context)
        val packages = catalog.pacotes.filter { it.url.isNotBlank() }
        assertEquals(314, packages.size)
        assertTrue(packages.all { catalog.localFile(it).isFile })
        val rules = StudyRules.load(context)
        val words = (rules.collections.map { it.keywords } + rules.paths.map { it.keywords }).map { it.map(::normalized) }
        val limits = List(rules.collections.size) { rules.collectionLimit } + List(rules.paths.size) { rules.pathLimit }
        val selected = MutableList(words.size) { emptyList<BreviarioItem>() }
        val works = packages.flatMap { it.obras }
        var pages = 0
        var maxBatch = 0
        val start = SystemClock.elapsedRealtime()
        for (work in works) {
            catalog.percorrerItensEstudo(work.id) { batch ->
                pages += batch.size
                maxBatch = maxOf(maxBatch, batch.size)
                val texts = batch.associate { it.chavePersistencia to normalized(listOf(it.titulo, it.texto, it.rodape).joinToString(" ")) }
                words.indices.forEach { i ->
                    selected[i] = StudyRules.incorporateNormalized(selected[i], batch, words[i], texts, limits[i])
                }
                true
            }
        }
        assertEquals(works.sumOf { it.paginas }, pages)
        assertTrue(maxBatch <= 100)
        selected.indices.forEach { i ->
            assertTrue(selected[i].isNotEmpty())
            assertTrue(selected[i].size <= limits[i])
        }
        File(context.filesDir, "medicao-estudos-android.json").writeText(JSONObject()
            .put("pages", pages).put("maxBatch", maxBatch)
            .put("milliseconds", SystemClock.elapsedRealtime() - start)
            .put("resultsPerRule", JSONArray(selected.map { it.size }))
            .put("ruleIDs", JSONArray(rules.collections.map { it.id } + rules.paths.map { it.id }))
            .put("selectedPages", JSONArray(selected.map { row -> JSONArray(row.map { "${it.obraId}:${it.pagina}" }) }))
            .put("environment", "emulator, not physical certification").toString(2))
    }

    @Test
    fun installedCorpusSupportsGlobalAreaWorkAndPageQueries() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val catalog = BibliotecaCatalogRepository.get(context)
        val packages = catalog.pacotes.filter { it.url.isNotBlank() }
        assertEquals("Catalog excludes the Rizzardo work by product policy", 314, packages.size)
        assertTrue(packages.none { p -> p.obras.any { it.id == "breviario_maconico_rizzardo_da_camino" } })
        assertTrue("Copy the audited corpus to the test emulator before running this suite", packages.all { catalog.localFile(it).isFile })
        val timings = JSONArray()
        for (query in listOf("maçonaria", "\"grande loja\"", "ética virtude")) {
            val start = SystemClock.elapsedRealtime()
            val hits = catalog.buscarConteudo(query, limite = 120)
            val elapsed = SystemClock.elapsedRealtime() - start
            assertTrue(hits.isNotEmpty())
            assertTrue(hits.size <= 120)
            assertEquals(hits.size, hits.distinctBy { Triple(it.obraId, it.pagina, it.trecho) }.size)
            assertTrue("Search took $elapsed ms", elapsed < 15_000)
            timings.put(JSONObject().put("query", query).put("milliseconds", elapsed).put("hits", hits.size))
        }
        for (area in BibliotecaArea.entries) {
            assertTrue(catalog.buscarConteudo("maçonaria", area = area).all { it.area == area })
        }
        val sample = catalog.buscarConteudo("maçonaria", area = BibliotecaArea.Biblioteca).first()
        assertTrue(catalog.buscarConteudo("maçonaria", obraId = sample.obraId).all { it.obraId == sample.obraId })
        val all = catalog.buscarConteudo("maçonaria", limite = 80)
        assertEquals(all.drop(40), catalog.buscarConteudo("maçonaria", limite = 40, offset = 40))
        val largest = packages.flatMap { it.obras }.maxBy { it.paginas }
        val start = SystemClock.elapsedRealtime()
        val pages = catalog.indicePaginas(largest.id, limite = largest.paginas + 1)
        assertEquals(largest.paginas, pages.size)
        val last = pages.last()
        assertTrue(catalog.indicePaginas(largest.id, filtro = last.pagina.toString()).any { it.pagina == last.pagina })
        File(context.filesDir, "medicao-acervo-android.json").writeText(JSONObject()
            .put("environment", "Android emulator API 36; not a physical-device certification")
            .put("packages", packages.size).put("queries", timings)
            .put("largestWorkPages", pages.size).put("pageIndexMilliseconds", SystemClock.elapsedRealtime() - start).toString(2))
    }
}
