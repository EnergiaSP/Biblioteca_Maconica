package com.renatocamargo.breviariomaconico

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.renatocamargo.breviariomaconico.data.StudyNotebook
import com.renatocamargo.breviariomaconico.data.StudyNotebookThemes
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

    @Test
    fun studyNotebookByThemeMatchesReferenceCases() {
        val themes = StudyNotebookThemes
        val rule = themes.loadRule(context)
        val root = JSONObject(context.assets.open("casos_caderno_v1.json").bufferedReader().use { it.readText() }).getJSONObject("porTema")
        val notebook = StudyNotebook.fromJson(root.getJSONObject("caderno"))
        val titlesJson = root.getJSONObject("titulos")
        val titles = titlesJson.keys().asSequence().associateWith { titlesJson.getString(it) }
        fun optional(json: JSONObject, key: String) = if (json.isNull(key)) null else json.getString(key)
        fun note(json: JSONObject) = StudyNotebookThemes.Note(json.getString("tipo"), json.getString("rotulo"), json.getString("origem"),
            json.getString("texto"), optional(json, "obraId"), optional(json, "data"), optional(json, "dossieId"))
        val notes = themes.notes(notebook, titles, rule)
        val expectedThemes = root.getJSONArray("temas")
        assertEquals(List(expectedThemes.length()) { expectedThemes.getJSONObject(it).let { t -> StudyNotebookThemes.Theme(t.getString("tema"), t.getInt("quantidade")) } },
            themes.themes(notebook, notes))
        val searches = root.getJSONArray("buscas")
        for (index in 0 until searches.length()) {
            val case = searches.getJSONObject(index)
            val query = case.getString("consulta")
            val found = themes.search(notes, query)
            val expected = case.getJSONArray("encontradas")
            assertEquals(query, List(expected.length()) { note(expected.getJSONObject(it)) }, found)
            assertEquals(query, case.getString("exportacao"), themes.export(found, query, rule))
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

    /**
     * Sync through a service: the merged notebook is applied here and written back; a remote file from a
     * newer version of the app is never overwritten. Same as the iOS test.
     */
    @Test
    fun studyNotebookSyncMergesAndProtectsUnreadableRemote() = kotlinx.coroutines.runBlocking {
        class Memory(var text: String?) : com.renatocamargo.breviariomaconico.data.NotebookProvider {
            override val option = com.renatocamargo.breviariomaconico.data.NotebookSync.Option.OWN_ACCOUNT
            var writes = 0
            override suspend fun read() = text
            override suspend fun write(text: String) { this.text = text; writes++ }
        }
        val sync = com.renatocamargo.breviariomaconico.data.NotebookSync
        val config = StudyNotebook.loadConfig(context)
        val obra = "teste_caderno_sincronizacao"
        val prefs = context.getSharedPreferences("breviario_prefs", android.content.Context.MODE_PRIVATE)
        try {
            val other = StudyNotebook.Notebook(listOf(StudyNotebook.Reading(obra, "05/07", comment = "Anotação feita no outro aparelho.")))
            val cloud = Memory(StudyNotebook.toJson(other, config).toString())
            val merged = sync.sync(context, cloud, config)
            assertEquals("Anotação feita no outro aparelho.", prefs.getString("comment_${obra}_05/07", null))
            assertEquals(merged, StudyNotebook.fromJson(JSONObject(cloud.text!!)))
            val writes = cloud.writes
            sync.sync(context, cloud, config)
            assertEquals("Nothing changed, nothing is written", writes, cloud.writes)

            val future = """{"formato":"caderno-biblioteca-maconica","versao":99}"""
            val futureCloud = Memory(future)
            val failed = runCatching { sync.sync(context, futureCloud, config) }.isFailure
            assertTrue("A notebook from a newer version must not be merged", failed)
            assertEquals(future, futureCloud.text)
            assertEquals(0, futureCloud.writes)
        } finally {
            val editor = prefs.edit()
            prefs.all.keys.filter { obra in it }.forEach { editor.remove(it) }
            editor.commit()
            context.getSharedPreferences("caderno_sync", android.content.Context.MODE_PRIVATE).edit().clear().commit()
        }
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
