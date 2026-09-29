package com.renatocamargo.breviariomaconico

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.renatocamargo.breviariomaconico.data.StudyNotebook
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Same merges and file checks as `Tools/caderno_referencia.py` and iOS (`casos_caderno_v1.json`). */
@RunWith(AndroidJUnit4::class)
class StudyNotebookTest {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()

    @Test
    fun studyNotebookMatchesReferenceCases() {
        val config = StudyNotebook.loadConfig(context)
        val root = JSONObject(context.assets.open("casos_caderno_v1.json").bufferedReader().use { it.readText() })
        val merges = root.getJSONArray("mesclagens")
        for (index in 0 until merges.length()) {
            val case = merges.getJSONObject(index)
            val merged = StudyNotebook.merge(StudyNotebook.fromJson(case.getJSONObject("local")),
                StudyNotebook.fromJson(case.getJSONObject("importado")), case.getString("hoje"), config)
            assertEquals(case.getString("nome"), StudyNotebook.fromJson(case.getJSONObject("esperado")), merged)
            // Written by this app and read back, the file keeps the same notebook.
            assertEquals(case.getString("nome"), merged, StudyNotebook.fromJson(StudyNotebook.toJson(merged, config)))
        }
        val checks = root.getJSONArray("validacao")
        for (index in 0 until checks.length()) {
            val case = checks.getJSONObject(index)
            assertEquals(case.getString("nome"), case.getBoolean("valido"), StudyNotebook.valid(case.getJSONObject("caderno"), config))
        }
    }

    /**
     * The file written by each app opens in the other: this app writes the reference notebook to
     * files/caderno-android.json and reads files/caderno-ios.json when it was copied there.
     */
    @Test
    fun studyNotebookFilesCrossPlatform() {
        val config = StudyNotebook.loadConfig(context)
        val root = JSONObject(context.assets.open("casos_caderno_v1.json").bufferedReader().use { it.readText() })
        val expected = StudyNotebook.fromJson(root.getJSONArray("mesclagens").getJSONObject(1).getJSONObject("esperado"))
        java.io.File(context.filesDir, "caderno-android.json").writeText(StudyNotebook.toJson(expected, config).toString(2))
        val fromIos = java.io.File(context.filesDir, "caderno-ios.json")
        org.junit.Assume.assumeTrue("Copy the file written by the iOS test to files/caderno-ios.json", fromIos.exists())
        val json = JSONObject(fromIos.readText())
        assertTrue(StudyNotebook.valid(json, config))
        assertEquals(expected, StudyNotebook.fromJson(json))
    }

    /** A notebook written to this device and collected again keeps the reading, its highlight and edit. */
    @Test
    fun studyNotebookRoundTripOnThisDevice() {
        val config = StudyNotebook.loadConfig(context)
        val obra = "teste_caderno_ida_e_volta"
        val prefs = context.getSharedPreferences("breviario_prefs", android.content.Context.MODE_PRIVATE)
        try {
            val reading = StudyNotebook.Reading(obra, "03/07", "Comentário importado.", "Reflexão importada.", true, true,
                listOf(StudyNotebook.Highlight("h1", "trecho marcado", 1_790_000_000_000)),
                StudyNotebook.Edit("Título", "", "Texto", "Nota", ""))
            val local = StudyNotebook.collect(context)
            StudyNotebook.apply(context, StudyNotebook.merge(local, StudyNotebook.Notebook(listOf(reading)), "2026-10-10", config))
            assertEquals(reading, StudyNotebook.collect(context).readings.first { it.obraId == obra })
            assertTrue(StudyNotebook.valid(StudyNotebook.toJson(StudyNotebook.collect(context), config), config))
        } finally {
            val editor = prefs.edit()
            prefs.all.keys.filter { obra in it }.forEach { editor.remove(it) }
            listOf("favorites", "readDates").forEach { key ->
                editor.putStringSet(key, prefs.getStringSet(key, emptySet()).orEmpty().filterNot { obra in it }.toSet())
            }
            editor.commit()
        }
    }
}
