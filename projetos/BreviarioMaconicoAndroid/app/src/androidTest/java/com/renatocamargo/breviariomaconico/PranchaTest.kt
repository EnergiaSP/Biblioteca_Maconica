package com.renatocamargo.breviariomaconico

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.renatocamargo.breviariomaconico.data.DossierAnalysis
import com.renatocamargo.breviariomaconico.data.Prancha
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

/** Same prancha, citations and ABNT references as `Tools/prancha_referencia.py` and iOS (`casos_prancha_v1.json`). */
@RunWith(AndroidJUnit4::class)
class PranchaTest {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()

    private fun strings(array: JSONArray) = List(array.length()) { array.getString(it) }

    @Test
    fun pranchaMatchesReferenceCases() {
        val config = Prancha.loadConfig(context)
        val root = JSONObject(context.assets.open("casos_prancha_v1.json").bufferedReader().use { it.readText() })
        val works = Prancha.parseWorks(root.getJSONObject("obras"))
        val cases = root.getJSONArray("casos")
        for (index in 0 until cases.length()) {
            val case = cases.getJSONObject(index)
            val rows = case.getJSONArray("fontes")
            val sources = List(rows.length()) { row -> rows.getJSONObject(row).let {
                DossierAnalysis.Source(it.getString("id"), it.getString("obraId"), it.getString("tituloObra"), it.getString("area"),
                    it.getInt("pagina"), it.optString("data").ifEmpty { null }, it.optString("texto"), it.optString("rodape"))
            } }
            val dossier = case.getJSONObject("dossie")
            fun excerpts(key: String) = dossier.getJSONArray(key).let { a ->
                List(a.length()) { a.getJSONObject(it).let { e -> DossierAnalysis.Excerpt(e.getString("texto"), e.getString("fonte")) } }
            }
            val terms = dossier.getJSONArray("termosAssociados").let { a ->
                List(a.length()) { a.getJSONObject(it).let { t ->
                    DossierAnalysis.RelatedTerm(t.getString("termo"), t.getString("forma"), t.getInt("ocorrencias"), t.getInt("obras"))
                } }
            }
            val result = Prancha.build(case.getString("termo"), sources, excerpts("definicoes"), excerpts("resumo"),
                excerpts("divergencias"), terms, works, config)
            val expected = case.getJSONObject("esperado")
            val id = case.getString("id")
            assertEquals(id, expected.getString("titulo"), result.title)
            val sections = expected.getJSONArray("secoes")
            assertEquals(id, List(sections.length()) { sections.getJSONObject(it).let { s ->
                Prancha.Section(s.getString("titulo"), strings(s.getJSONArray("paragrafos"))) } }, result.sections)
            val comparison = expected.getJSONArray("comparacao")
            assertEquals(id, List(comparison.length()) { comparison.getJSONObject(it).let { a ->
                Prancha.Author(a.getString("quem"), strings(a.getJSONArray("obras")), strings(a.getJSONArray("trechos"))) } }, result.comparison)
            assertEquals(id, strings(expected.getJSONArray("referencias")), result.references)
            assertEquals(id, expected.getString("texto"), result.text)
        }
        val references = root.getJSONArray("referencias")
        for (index in 0 until references.length()) {
            val case = references.getJSONObject(index)
            assertEquals(case.getString("referencia"), Prancha.reference(Prancha.parseWork(case.getJSONObject("obra")), config))
        }
        assertEquals("Kennyo Ismail", Prancha.loadWorks(context)["breviario_seculo_xxi"]?.autor)
    }
}
