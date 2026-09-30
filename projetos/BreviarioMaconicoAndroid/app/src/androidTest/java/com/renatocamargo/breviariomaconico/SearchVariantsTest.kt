package com.renatocamargo.breviariomaconico

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.renatocamargo.breviariomaconico.data.DossierAnalysis
import com.renatocamargo.breviariomaconico.data.SearchVariants
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

/** Same search variants as `Tools/variantes_referencia.py` and iOS (`casos_variantes_v1.json`). */
@RunWith(AndroidJUnit4::class)
class SearchVariantsTest {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()

    @Test
    fun searchVariantsMatchReferenceCases() {
        val config = SearchVariants.loadConfig(context)
        val cases = JSONObject(context.assets.open("casos_variantes_v1.json").bufferedReader().use { it.readText() }).getJSONArray("casos")
        for (index in 0 until cases.length()) {
            val case = cases.getJSONObject(index)
            val words = case.getJSONArray("palavras").let { a -> List(a.length()) { a.getString(it) } }
            val expected = case.getJSONObject("esperado").let { o ->
                o.keys().asSequence().associateWith { k -> o.getJSONArray(k).let { a -> List(a.length()) { a.getString(it) } } }
            }
            assertEquals("$words", expected, SearchVariants.expand(words, case.getBoolean("singularPlural"), config))
        }
        // The dossier variants are generated from the same groups.
        assertEquals(SearchVariants.spelling(config), DossierAnalysis.loadConfig(context).variants)
        assertEquals(listOf("jacob", "jacos"), SearchVariants.forSearch(context, "Irmãos \"Escada de Jacó\"", true)["jaco"])
    }

    /** In the installed collection, the option finds the other form: "malhete" also finds "malhetes". */
    @Test
    fun singularPluralWidensLibrarySearch() {
        val catalog = com.renatocamargo.breviariomaconico.data.BibliotecaCatalogRepository.get(context)
        for (query in listOf("malhete", "acácia")) {
            val alone = catalog.buscarConteudo(query, limite = 500, variants = SearchVariants.forSearch(context, query, false))
            val both = catalog.buscarConteudo(query, limite = 500, variants = SearchVariants.forSearch(context, query, true))
            android.util.Log.i("VariantesBusca", "$query: ${alone.size} sem, ${both.size} com singular e plural")
            org.junit.Assert.assertTrue(query, both.size > alone.size)
            org.junit.Assert.assertTrue(query, alone.map { it.id }.toSet().all { id -> both.any { it.id == id } } || alone.size == 500)
        }
    }
}
