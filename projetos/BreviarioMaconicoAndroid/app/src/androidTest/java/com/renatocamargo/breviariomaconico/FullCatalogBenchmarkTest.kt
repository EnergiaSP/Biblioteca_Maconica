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
        val words = (rules.collections.map { it.keywords } + rules.paths.map { it.keywords })
            .map { keywords -> StudyRules.studyKeywords(keywords.map(StudyRules::studyNormalized)) }
        val limits = List(rules.collections.size) { rules.collectionLimit } + List(rules.paths.size) { rules.pathLimit }
        val works = packages.flatMap { it.obras }
        val pages = works.sumOf { it.paginas }
        val maxBatch = 0
        val start = SystemClock.elapsedRealtime()
        val (selected, failures) = kotlinx.coroutines.runBlocking { catalog.scoreStudy(works.map { it.id }.toSet(), words, limits) }
        assertTrue("Packages failed: $failures", failures.isEmpty())
        selected.indices.forEach { i ->
            assertTrue(selected[i].isNotEmpty())
            assertTrue(selected[i].size <= limits[i])
        }
        File(context.filesDir, "medicao-estudos-android.json").writeText(JSONObject()
            .put("pages", pages).put("maxBatch", maxBatch)
            .put("milliseconds", SystemClock.elapsedRealtime() - start)
            .put("resultsPerRule", JSONArray(selected.map { it.size }))
            .put("ruleIDs", JSONArray(rules.collections.map { it.id } + rules.paths.map { it.id }))
            .put("selectedPages", JSONArray(selected.map { row -> JSONArray(row.map { "${it.ref.obraId}:${it.ref.pagina}" }) }))
            .put("engine", "fts5vocab")
            .put("environment", ambiente()).toString(2))
    }

    /** Real-corpus dossier for "Escada de Jacó" in the books area, compared with iOS item by item. */
    @Test
    fun installedCorpusDossierIsRecordedForParity() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val catalog = BibliotecaCatalogRepository.get(context)
        assertTrue(catalog.pacotes.filter { it.url.isNotBlank() }.all { catalog.localFile(it).isFile })
        val config = DossierAnalysis.loadConfig(context)
        val term = "Escada de Jacó"
        val results = catalog.buscarConteudo("\"$term\"", area = BibliotecaArea.Biblioteca, limite = config.limits.analyzedSources,
            variants = config.variants)
        assertTrue(results.isNotEmpty())
        val sources = dossierSources(results)
        val start = SystemClock.elapsedRealtime()
        val analysis = DossierAnalysis.analyze(term, sources, config, java.time.LocalDate.parse("2026-09-27"))
        val elapsed = SystemClock.elapsedRealtime() - start
        assertTrue(analysis.summary.isNotEmpty())
        File(context.filesDir, "dossie-acervo-android.json").writeText(analysis.toJson()
            .put("exibicao", DossierAnalysis.display(term, analysis, sources, config).toJson())
            .put("fontesIds", JSONArray(sources.map { it.id }))
            .put("milissegundosAnalise", elapsed)
            // The AI prompt for the excerpts shown in this dossier, compared byte by byte with iOS.
            .put("promptIA", AssistedInterpretation.prompt(term, sources.take(config.limits.shownSources), emptyList(),
                AssistedInterpretation.loadConfig(context), config))
            .toString(2))
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
        // Same books-only scope on both platforms; compared result by result across iOS and Android.
        val topResults = JSONObject()
        for (query in listOf("maçonaria", "\"grande loja\"", "ética virtude", "\"escada de jacó\"")) {
            topResults.put(query, JSONArray(catalog.buscarConteudo(query, area = BibliotecaArea.Biblioteca, limite = 120)
                .map { "${it.obraId}:${it.pagina}:${it.blocoId ?: it.data}" }))
        }
        val largest = packages.flatMap { it.obras }.maxBy { it.paginas }
        val start = SystemClock.elapsedRealtime()
        val pages = catalog.indicePaginas(largest.id, limite = largest.paginas + 1)
        assertEquals(largest.paginas, pages.size)
        val last = pages.last()
        assertTrue(catalog.indicePaginas(largest.id, filtro = last.pagina.toString()).any { it.pagina == last.pagina })
        File(context.filesDir, "medicao-acervo-android.json").writeText(JSONObject()
            .put("environment", ambiente())
            .put("packages", packages.size).put("queries", timings).put("topResults", topResults)
            .put("largestWorkPages", pages.size).put("pageIndexMilliseconds", SystemClock.elapsedRealtime() - start).toString(2))
    }

/** Where the measurement ran: a physical device is named, an emulator is marked as such. */
private fun ambiente(): String {
    val emulador = android.os.Build.FINGERPRINT.contains("generic") || android.os.Build.MODEL.contains("sdk_gphone")
    val aparelho = "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}, Android ${android.os.Build.VERSION.RELEASE}"
    return if (emulador) "emulator ($aparelho)" else "physical device ($aparelho)"
}

}
