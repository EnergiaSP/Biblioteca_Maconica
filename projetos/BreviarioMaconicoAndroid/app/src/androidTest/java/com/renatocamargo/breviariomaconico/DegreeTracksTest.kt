package com.renatocamargo.breviariomaconico

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.renatocamargo.breviariomaconico.data.DegreeTracks
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

/** Same progress by degree as `Tools/trilhas_referencia.py` and iOS (`casos_trilhas_v1.json`). */
@RunWith(AndroidJUnit4::class)
class DegreeTracksTest {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()

    private fun strings(array: JSONArray) = List(array.length()) { array.getString(it) }

    @Test
    fun degreeTracksMatchReferenceCases() {
        val config = DegreeTracks.loadConfig(context)
        assertEquals(listOf("aprendiz", "companheiro", "mestre"), config.degrees.map { it.id })
        val cases = JSONObject(context.assets.open("casos_trilhas_v1.json").bufferedReader().use { it.readText() }).getJSONArray("casos")
        for (index in 0 until cases.length()) {
            val case = cases.getJSONObject(index)
            val expected = case.getJSONArray("esperado").let { a ->
                List(a.length()) { a.getJSONObject(it).let { p ->
                    DegreeTracks.Progress(p.getString("grau"), strings(p.getJSONArray("concluidas")), p.getInt("total"), p.getInt("percentual"),
                        p.getString("marco"), if (p.isNull("proxima")) null else p.getString("proxima"))
                } }
            }
            assertEquals(case.getString("nome"), expected,
                DegreeTracks.progress(config, strings(case.getJSONArray("temasSalvos")), strings(case.getJSONArray("marcadas")).toSet()))
        }
    }

    /** The suggested works are shown by title, so every one of them is in the catalog titles. */
    @Test
    fun suggestedWorksHaveCatalogTitles() {
        val titles = com.renatocamargo.breviariomaconico.data.BibliotecaCatalogRepository.get(context).titulosDoCatalogo()
        val missing = DegreeTracks.loadConfig(context).degrees.flatMap { it.suggestedWorks }.filter { it !in titles }
        assertEquals("Sem título: $missing (${titles.size} títulos)", emptyList<String>(), missing)
    }
}
