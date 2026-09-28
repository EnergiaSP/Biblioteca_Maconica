package com.renatocamargo.breviariomaconico

import android.content.Intent
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.renatocamargo.breviariomaconico.data.BibliotecaArea
import com.renatocamargo.breviariomaconico.data.BibliotecaCatalogRepository
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Updates the installed collection to the current catalog through the Acervo screen, as a user
 * would. Opt-in because it downloads the whole collection:
 * `am instrument -e atualizarAcervo true -e class ...AcervoUpdateFlowTest`.
 */
@RunWith(AndroidJUnit4::class)
class AcervoUpdateFlowTest {
    @get:Rule
    val compose = createEmptyComposeRule()

    @Test
    fun outdatedPackagesAreUpdatedFromTheAcervoScreen() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("atualizarAcervo") == "true")
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val intent = Intent(context, MainActivity::class.java)
            .putExtra("ui_testing", true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        ActivityScenario.launch<MainActivity>(intent).use {
            compose.waitUntil(10_000) { compose.onAllNodesWithText("Biblioteca Maçônica").fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithTag("tab.acervo").performClick()
            BibliotecaArea.entries.forEach { area ->
                compose.onNodeWithTag("acervo.area.${area.raw}").performClick()
                compose.waitForIdle()
                compose.onNodeWithText("Baixar todas da área").performClick()
                // The previous area's final status stays on screen until this download starts.
                compose.waitUntil(60_000) {
                    compose.onAllNodes(
                        hasText("Baixando ", substring = true) or hasText("já estão baixadas e atualizadas", substring = true)
                    ).fetchSemanticsNodes().isNotEmpty()
                }
                compose.waitUntil(40 * 60_000L) {
                    compose.onAllNodes(
                        hasText("Download da área concluído.") or hasText("Todas as obras desta área já estão baixadas e atualizadas.")
                    ).fetchSemanticsNodes().isNotEmpty() ||
                        compose.onAllNodes(hasText("Download interrompido.", substring = true) or hasText("Falha", substring = true))
                            .fetchSemanticsNodes().isNotEmpty()
                }
                assertTrue(
                    "${area.titulo}: download falhou",
                    compose.onAllNodes(hasText("Falha", substring = true) or hasText("interrompido", substring = true))
                        .fetchSemanticsNodes().isEmpty()
                )
                compose.onAllNodes(hasText("com atualização disponível", substring = true)).fetchSemanticsNodes().let {
                    assertTrue("${area.titulo}: ainda há atualização pendente", it.isEmpty())
                }
            }
        }
        val catalog = BibliotecaCatalogRepository(context)
        val pendentes = BibliotecaArea.entries.flatMap { catalog.estados(it) }.filter { !it.instalado || it.desatualizado }
        assertTrue("Pendentes: ${pendentes.map { it.pacote.arquivo }}", pendentes.isEmpty())
    }
}
