package com.renatocamargo.breviariomaconico

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.renatocamargo.breviariomaconico.data.ActiveReview
import com.renatocamargo.breviariomaconico.data.DossierAnalysis
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

/** Same cards, schedule and sessions as `Tools/revisao_referencia.py` and iOS (`casos_revisao_v1.json`). */
@RunWith(AndroidJUnit4::class)
class ActiveReviewTest {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()

    private fun JSONArray.strings() = List(length()) { getString(it) }

    @Test
    fun activeReviewMatchesReferenceCases() {
        val config = ActiveReview.loadConfig(context)
        val root = JSONObject(context.assets.open("casos_revisao_v1.json").bufferedReader().use { it.readText() })
        val generation = root.getJSONArray("geracao")
        for (index in 0 until generation.length()) {
            val case = generation.getJSONObject(index)
            val analysis = case.getJSONObject("analise")
            val sourcesJson = case.getJSONArray("fontes")
            val sources = List(sourcesJson.length()) { i ->
                val s = sourcesJson.getJSONObject(i)
                DossierAnalysis.Source(s.getString("id"), "", s.getString("tituloObra"), "", s.getInt("pagina"),
                    s.optString("data").takeIf { s.has("data") && it.isNotEmpty() })
            }
            val definitions = analysis.getJSONArray("definicoes").let { a ->
                List(a.length()) { DossierAnalysis.Excerpt(a.getJSONObject(it).getString("texto"), a.getJSONObject(it).getString("fonte")) }
            }
            val questions = analysis.getJSONArray("perguntas").let { a ->
                List(a.length()) { a.getJSONObject(it).let { q -> DossierAnalysis.Question(q.getString("pergunta"), q.getString("resposta"), q.getString("fonte")) } }
            }
            val forms = analysis.getJSONArray("termosAssociados").let { a -> List(a.length()) { a.getJSONObject(it).getString("forma") } }
            val expected = case.getJSONArray("esperado").let { a ->
                List(a.length()) { a.getJSONObject(it).let { c ->
                    ActiveReview.Card(c.getString("id"), c.getString("tipo"), c.getString("frente"), c.getString("verso"),
                        c.getString("fonte"), c.getJSONArray("alternativas").strings())
                } }
            }
            assertEquals(case.getString("id"), expected,
                ActiveReview.generate(case.getString("tema"), definitions, questions, forms, sources, config))
        }
        val schedule = root.getJSONArray("agenda")
        for (index in 0 until schedule.length()) {
            val case = schedule.getJSONObject(index)
            var state = ActiveReview.newState(case.getString("criadoEm"))
            val answers = case.getJSONArray("respostas")
            val states = List(answers.length()) { i ->
                val step = answers.getJSONArray(i)
                state = ActiveReview.answer(state, ActiveReview.Grade.entries.first { it.id == step.getString(0) }, step.getString(1), config)
                state
            }
            val expected = case.getJSONArray("esperado").let { a ->
                List(a.length()) { a.getJSONObject(it).let { e ->
                    ActiveReview.State(e.getInt("caixa"), e.getString("vencimento"), e.getInt("acertos"), e.getInt("erros"))
                } }
            }
            assertEquals(case.getString("nome"), expected, states)
        }
        val sessions = root.getJSONArray("sessoes")
        for (index in 0 until sessions.length()) {
            val case = sessions.getJSONObject(index)
            val cards = case.getJSONArray("cartoes").let { a ->
                List(a.length()) { a.getJSONObject(it).let { c -> ActiveReview.Due(c.getString("id"), c.getString("criadoEm"), c.getString("vencimento")) } }
            }
            assertEquals(case.getString("nome"), case.getJSONArray("esperado").strings(),
                ActiveReview.session(cards, case.getString("hoje"), config))
        }
    }
}
