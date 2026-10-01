package com.renatocamargo.breviariomaconico

import android.content.Intent
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performImeAction
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.performScrollToKey
import androidx.compose.ui.test.performTextReplacement
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Store screenshots (Paridade/PUBLICACAO_LOJAS.md), only when asked: `-e capturas 1`.
 * Saved in files/capturas/ of the app and copied by Tools/gerar_capturas_android.sh. Same screens as iOS.
 */
@RunWith(AndroidJUnit4::class)
class StoreScreenshotsTest {
    @get:Rule
    val compose = createEmptyComposeRule()
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()
    private var scenario: ActivityScenario<MainActivity>? = null

    private fun open() {
        scenario?.close()
        scenario = ActivityScenario.launch(Intent(context, MainActivity::class.java).putExtra("ui_testing", true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        compose.waitUntil(10_000) { compose.onAllNodesWithText("Biblioteca Maçônica").fetchSemanticsNodes().isNotEmpty() }
    }

    private fun capture(name: String) {
        compose.waitForIdle()
        Thread.sleep(1500)
        val bitmap = requireNotNull(InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot())
        val folder = context.filesDir.resolve("capturas").apply { mkdirs() }
        folder.resolve("$name.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }

    private fun openFromMore(title: String) {
        open()
        compose.onNodeWithTag("tab.more").performClick()
        compose.onNodeWithText(title).performScrollTo().performClick()
        Thread.sleep(1500)
    }

    @Test
    fun storeScreenshots() {
        assumeTrue("Only for the store screenshots", InstrumentationRegistry.getArguments().getString("capturas") == "1")
        val saved = com.renatocamargo.breviariomaconico.data.SavedDossierStore(context)
        saved.all().forEach { saved.remove(it.id) }
        open()
        capture("01-inicio")

        compose.onAllNodesWithText("Leitura")[0].performClick()
        Thread.sleep(1500)
        capture("02-leitura")

        open()
        compose.onNodeWithTag("tab.collections").performClick()
        compose.waitUntil(30_000) { compose.onAllNodesWithText("Ver todas as leituras").fetchSemanticsNodes().isNotEmpty() }
        // The collections are shown when every work is scored, not while they load.
        compose.waitUntil(120_000) { compose.onAllNodesWithTag("study.progress").fetchSemanticsNodes().isEmpty() }
        capture("03-colecoes")

        open()
        compose.onNodeWithTag("tab.dossier").performClick()
        val topic = InstrumentationRegistry.getArguments().getString("tema") ?: "Acácia"
        compose.onNodeWithTag("dossier.topic").performTextReplacement(topic)
        compose.onNodeWithTag("dossier.topic").performImeAction()
        compose.waitUntil(60_000) { compose.onAllNodesWithText("Dossiê criado com", substring = true).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("dossier.list").performScrollToIndex(0)
        compose.onNodeWithTag("dossier.save").performScrollTo().performClick()
        compose.onNodeWithTag("dossier.list").performScrollToKey("dossier.analysis")
        capture("04-dossie")
        compose.onNodeWithTag("dossier.list").performScrollToIndex(0)
        compose.onNodeWithTag("dossier.prancha").performScrollTo().performClick()
        compose.waitUntil(10_000) { compose.onAllNodesWithTag("prancha").fetchSemanticsNodes().isNotEmpty() }
        capture("05-prancha")

        openFromMore("Trilhas por grau")
        capture("06-trilhas")

        openFromMore("Caderno de estudo")
        compose.waitUntil(30_000) { compose.onAllNodesWithTag("notebook.theme.count").fetchSemanticsNodes().isNotEmpty() }
        capture("07-caderno")

        open()
        compose.onNodeWithTag("tab.acervo").performClick()
        Thread.sleep(3000)
        capture("08-acervo")
        scenario?.close()
    }
}
