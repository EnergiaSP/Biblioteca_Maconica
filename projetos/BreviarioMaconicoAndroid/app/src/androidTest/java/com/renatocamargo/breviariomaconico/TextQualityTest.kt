package com.renatocamargo.breviariomaconico

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.renatocamargo.breviariomaconico.data.TextQuality
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

/** Same results as `Tools/qualidade_referencia.py` and iOS for every case of `casos_qualidade_v1.json`. */
@RunWith(AndroidJUnit4::class)
class TextQualityTest {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()

    @Test
    fun textQualityMatchesReferenceCases() {
        val config = TextQuality.loadConfig(context)
        val cases = JSONObject(context.assets.open("casos_qualidade_v1.json").bufferedReader().use { it.readText() })
            .getJSONArray("casos")
        for (index in 0 until cases.length()) {
            val case = cases.getJSONObject(index)
            val name = case.getString("nome")
            val expected = case.getJSONObject("esperado")
            when (case.getString("tipo")) {
                "token" -> assertEquals(name, if (expected.isNull("classe")) null else expected.getString("classe"),
                    TextQuality.classify(case.getString("texto"), config))
                "obra" -> assertEquals(name, expected.getString("nivel"), TextQuality.workLevel(
                    case.getInt("avaliadas"), case.getInt("ruidosas"), case.getInt("ilegiveis"), config))
                else -> {
                    val rating = if (case.getString("tipo") == "pagina") TextQuality.ratePage(case.getString("texto"), config)
                    else TextQuality.rateSentence(case.getString("texto"), config)
                    val reasons = expected.getJSONObject("motivos")
                    assertEquals(name, expected.getInt("palavras"), rating.words)
                    assertEquals(name, expected.getInt("suspeitas"), rating.suspicious)
                    assertEquals(name, expected.getString("nivel"), rating.level.id)
                    assertEquals(name, reasons.keys().asSequence().associateWith { reasons.getInt(it) }, rating.reasons)
                }
            }
        }
    }
}
