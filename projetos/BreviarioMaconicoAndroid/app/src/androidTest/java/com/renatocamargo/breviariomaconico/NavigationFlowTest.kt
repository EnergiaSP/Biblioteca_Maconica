package com.renatocamargo.breviariomaconico

import android.content.Intent
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.assertIsNotSelected
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextReplacement
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToKey
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.printToString
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.click
import androidx.compose.ui.test.swipeLeft
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.compose.ui.unit.dp
import com.renatocamargo.breviariomaconico.data.AppThemeMode
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NavigationFlowTest {
    @Test
    fun dossierInvalidatesSourcesWhenAuthorFilterChanges() {
        compose.onNodeWithTag("tab.dossier").performClick()
        compose.onNodeWithTag("dossier.topic").performTextReplacement("virtude")
        compose.onNodeWithText("Gerar dossiê").performScrollTo().performClick()
        assertDossierGenerated()
        compose.onNodeWithTag("search.author").performScrollTo().performTextReplacement("Autor inexistente de teste")
        compose.onNodeWithTag("dossier.results").assertDoesNotExist()
        compose.onNodeWithText("Gere o dossiê para consultar a seleção atual.").assertExists()
    }

    @Test
    fun globalRemissiveIndexFiltersAreaAndReportsEmptyScope() {
        compose.onNodeWithTag("tab.more").performClick()
        compose.onNodeWithText("Índices da Biblioteca").performScrollTo().performClick()
        compose.onNodeWithTag("index.remissive").performClick().assertIsSelected()
        compose.waitUntil(20_000) {
            compose.onAllNodesWithText("Breviário Maçônico - Kennyo Ismail").fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithText("Dicionários Maçônicos").performClick()
        compose.waitUntil(20_000) {
            compose.onAllNodesWithText("Nenhuma referência disponível neste escopo.").fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithText("Todas as áreas").performClick()
        compose.waitUntil(20_000) {
            compose.onAllNodesWithText("Breviário Maçônico - Kennyo Ismail").fetchSemanticsNodes().isNotEmpty()
        }
        saveScreen("index-global")
    }

    @Test
    fun dossierInvalidatesPreviousSourcesWhenTopicOrScopeChanges() {
        compose.onNodeWithTag("tab.dossier").performClick()
        compose.onNodeWithTag("dossier.topic").performTextReplacement("virtude")
        compose.onNodeWithText("Gerar dossiê").performScrollTo().performClick()
        assertDossierGenerated()
        compose.onNodeWithTag("dossier.topic").performScrollTo().performTextReplacement("simbolo")
        compose.onNodeWithTag("dossier.results").assertDoesNotExist()
        compose.onNodeWithText("Gere o dossiê para consultar a seleção atual.").assertExists()
        compose.onNodeWithText("Gerar dossiê").performScrollTo().performClick()
        assertDossierGenerated()
        compose.onNodeWithText("Dicionários Maçônicos").performScrollTo().performClick()
        compose.onNodeWithTag("dossier.results").assertDoesNotExist()
        compose.onNodeWithText("Gere o dossiê para consultar a seleção atual.").assertExists()
    }

    private fun assertDossierGenerated() {
        compose.waitUntil(20_000) {
            compose.onAllNodesWithText("Dossiê criado com", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithTag("dossier.list").performScrollToKey("dossier.plan")
        compose.onNodeWithTag("dossier.results").assertIsDisplayed()
    }

    @Test
    fun fullscreenRemovesNavigationAndCanExit() {
        compose.onAllNodesWithText("Leitura")[0].performClick()
        compose.onNodeWithTag("reader.tools").performTouchInput { swipeLeft() }
        compose.onAllNodesWithContentDescription("Tela cheia")[0].performClick()
        compose.onNodeWithTag("tab.home").assertDoesNotExist()
        compose.onAllNodesWithContentDescription("Sair da tela cheia")[0].performClick()
        compose.onNodeWithTag("tab.home").assertIsDisplayed()
    }

    @get:Rule
    val compose = createEmptyComposeRule()

    private lateinit var scenario: ActivityScenario<MainActivity>

    @Before
    fun launch() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val intent = Intent(context, MainActivity::class.java)
            .putExtra("ui_testing", true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        scenario = ActivityScenario.launch(intent)
        compose.waitUntil(10_000) { compose.onAllNodesWithText("Biblioteca Maçônica").fetchSemanticsNodes().isNotEmpty() }
        assertNativeForeground()
    }

    @After
    fun close() {
        if (::scenario.isInitialized) {
            try {
                if (scenario.state == androidx.lifecycle.Lifecycle.State.RESUMED) assertNativeForeground()
            } finally {
                scenario.close()
            }
        }
    }

    private fun assertNativeForeground() {
        val automation = InstrumentationRegistry.getInstrumentation().uiAutomation
        val packageName = ApplicationProvider.getApplicationContext<android.content.Context>().packageName
        // Compose actions alone can pass while a system dialog obscures the app.
        compose.waitUntil(5_000) {
            automation.rootInActiveWindow?.packageName?.toString() == packageName
        }
    }

    @Test
    fun mainTabsOpenTheirDestinations() {
        compose.onAllNodesWithText("Biblioteca Maçônica").assertCountEquals(1)
        compose.onAllNodesWithContentDescription("Configurações").assertCountEquals(1)
        compose.onNodeWithTag("tab.collections").performClick()
        compose.onNodeWithTag("tab.collections").assertIsSelected().assertHeightIsAtLeast(48.dp)
        compose.onAllNodesWithText("Coleções")[0].assertIsDisplayed()
        compose.onNodeWithTag("tab.dossier").performClick()
        compose.onNodeWithTag("tab.dossier").assertIsSelected().assertHeightIsAtLeast(48.dp)
        compose.onNodeWithTag("tab.collections").assertIsNotSelected()
        compose.onAllNodesWithText("Dossiê")[0].assertIsDisplayed()
        compose.onNodeWithTag("tab.acervo").performClick()
        compose.onNodeWithTag("tab.acervo").assertIsSelected().assertHeightIsAtLeast(48.dp)
        compose.onAllNodesWithText("Acervo")[0].assertIsDisplayed()
        compose.onNodeWithTag("tab.more").performClick()
        compose.onNodeWithTag("tab.more").assertIsSelected().assertHeightIsAtLeast(48.dp)
        compose.onAllNodesWithText("Recursos avançados")[0].assertIsDisplayed()
    }

    @Test
    fun settingsAndHomeButtonsCompleteRoundTrip() {
        compose.onAllNodesWithContentDescription("Configurações")[0].performClick()
        compose.onAllNodesWithText("Configurações")[0].assertIsDisplayed()
        compose.onAllNodesWithContentDescription("Home")[0].performClick()
        compose.onAllNodesWithText("Biblioteca Maçônica")[0].assertIsDisplayed()
    }

    @Test
    fun structuredSearchOpensFromHome() {
        compose.onNodeWithText("Buscar na biblioteca").performClick()
        compose.onAllNodesWithText("Busca estruturada")[0].assertIsDisplayed()
    }

    @Test
    fun collectionsShowDetailsAndExpandWithoutLosingReadings() {
        compose.onNodeWithTag("tab.collections").performClick()
        compose.waitUntil(20_000) { compose.onAllNodesWithTag("study.expand.virtudes").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("Aperfeiçoamento moral e conduta").assertIsDisplayed()
        compose.onNodeWithText("Prudência").assertExists()
        compose.onAllNodesWithTag("study.reading.virtudes").assertCountEquals(3)
        compose.onNodeWithTag("study.expand.virtudes").performScrollTo().performClick()
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val limit = com.renatocamargo.breviariomaconico.data.StudyRules.load(context).collectionLimit
        compose.onAllNodesWithTag("study.reading.virtudes").assertCountEquals(limit)
        compose.onNodeWithTag("study.expand.virtudes").performScrollTo().performClick()
        compose.onAllNodesWithTag("study.reading.virtudes").assertCountEquals(3)
    }

    @Test
    fun studyPathsPreserveCanonicalDetailsWhenScrolled() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val path = com.renatocamargo.breviariomaconico.data.StudyRules.load(context).paths.first()
        compose.onNodeWithTag("tab.collections").performClick()
        try {
            compose.waitUntil(20_000) { compose.onAllNodesWithTag("study.list").fetchSemanticsNodes().isNotEmpty() }
        } catch (error: androidx.compose.ui.test.ComposeTimeoutException) {
            println("STUDY_LOAD_TIMEOUT\n" + compose.onRoot(useUnmergedTree = true).printToString())
            saveScreen("study-load-timeout")
            throw error
        }
        compose.onNodeWithTag("study.list").performScrollToKey("path:${path.id}")
        for (text in listOf(path.subtitle, path.objective, path.instruction, path.suggestedDuration)) {
            compose.onAllNodesWithText(text)[0].performScrollTo().assertIsDisplayed()
        }
        path.stages.forEachIndexed { index, stage ->
            compose.onNodeWithText("${index + 1}. $stage").performScrollTo().assertIsDisplayed()
        }
        saveScreen("study-path")
    }

    @Test
    fun collectionOpensTheMatchingPageOfAnImportedBook() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val raw = context.getSharedPreferences("breviario_prefs", android.content.Context.MODE_PRIVATE)
        val history = raw.getString("libraryRecents", null)
        val source = java.io.File(context.cacheDir, "study-ui-${java.util.UUID.randomUUID()}.pdf")
        val importer = com.renatocamargo.breviariomaconico.data.LocalPdfOcrImporter(context)
        var imported: com.renatocamargo.breviariomaconico.data.ImportedPdfWork? = null
        try {
            val pdf = android.graphics.pdf.PdfDocument()
            try {
                for (number in 1..2) {
                    val page = pdf.startPage(android.graphics.pdf.PdfDocument.PageInfo.Builder(595, 842, number).create())
                    val paint = android.graphics.Paint().apply { textSize = 22f; color = android.graphics.Color.BLACK }
                    page.canvas.drawText(if (number == 1) "Apresentacao documental neutra" else "Estudo documental sobre virtude", 36f, 60f, paint)
                    page.canvas.drawText("Conteudo integral da pagina $number.", 36f, 105f, paint)
                    pdf.finishPage(page)
                }
                source.outputStream().use { pdf.writeTo(it) }
            } finally { pdf.close() }
            val work = kotlinx.coroutines.runBlocking {
                importer.import(android.net.Uri.fromFile(source), "000 Documento de teste", "Autor de teste",
                    com.renatocamargo.breviariomaconico.data.BibliotecaArea.Biblioteca) { }
            }
            imported = work
            // The global collection is bounded and ordered by work ID, not insertion date.
            val catalog = com.renatocamargo.breviariomaconico.data.BibliotecaCatalogRepository.get(context)
            org.junit.Assert.assertTrue("Fixture must precede the installed corpus to test the preview link",
                catalog.obrasInstaladas().filter { it.id != work.id }.all { it.id > work.id })
            val batchItems = mutableListOf<com.renatocamargo.breviariomaconico.data.BreviarioItem>()
            com.renatocamargo.breviariomaconico.data.BibliotecaCatalogRepository.get(context).percorrerItensEstudo(work.id) { batchItems.addAll(it); true }
            org.junit.Assert.assertEquals(listOf(1, 2), batchItems.map { it.pagina })
            org.junit.Assert.assertTrue(batchItems.last().texto.contains("virtude", ignoreCase = true))
            compose.onNodeWithTag("tab.collections").performClick()
            compose.waitUntil(20_000) { compose.onAllNodesWithText(work.title, substring = true).fetchSemanticsNodes().isNotEmpty() }
            val reading = compose.onAllNodesWithText(work.title, substring = true)[0]
            reading.performScrollTo().assertIsDisplayed()
            saveScreen("study-before-open")
            reading.performTouchInput { click() }
            compose.waitUntil(10_000) { compose.onAllNodesWithText("Página 2").fetchSemanticsNodes().isNotEmpty() }
            compose.onAllNodesWithText("Página 2")[0].assertIsDisplayed()
            compose.onAllNodesWithText("Página 1").assertCountEquals(0)
            saveScreen("study-after-open")
            assertNativeForeground()
        } finally {
            compose.onNodeWithTag("tab.home").performClick()
            imported?.let { work ->
                importer.remove(work.id)
                raw.edit().apply { raw.all.keys.filter { it.contains(work.id) }.forEach { remove(it) } }.commit()
            }
            raw.edit().apply { if (history == null) remove("libraryRecents") else putString("libraryRecents", history) }.commit()
            source.delete()
        }
    }

    private fun saveScreen(name: String) {
        compose.waitForIdle()
        assertNativeForeground()
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val screenshot = requireNotNull(InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot())
        try {
            context.cacheDir.resolve("$name.png").outputStream().use {
                check(screenshot.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it))
            }
        } finally { screenshot.recycle() }
    }

    @Test
    fun searchAndHomeRemainAvailableInEveryTheme() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val preferences = context.getSharedPreferences("breviario_prefs", android.content.Context.MODE_PRIVATE)
        val originalTheme = preferences.getString("theme", null)
        try {
            AppThemeMode.entries.forEach { theme ->
                scenario.close()
                preferences.edit().putString("theme", theme.name).commit()
                launch()
                compose.onNodeWithText("Buscar na biblioteca").performClick()
                compose.onAllNodesWithText("Busca estruturada")[0].assertIsDisplayed()
                compose.onNodeWithText("Todo acervo").assertIsSelected()
                compose.onNodeWithText("Breviários").performClick().assertIsSelected()
                compose.onNodeWithText("Todo acervo").assertIsNotSelected().performClick().assertIsSelected()
                compose.waitForIdle()
                assertNativeForeground()
                val screenshot = requireNotNull(InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot())
                try {
                    context.cacheDir.resolve("audit-search-${theme.name}.png").outputStream().use {
                        check(screenshot.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it))
                    }
                } finally {
                    screenshot.recycle()
                }
                compose.onNodeWithTag("tab.home").performClick()
                compose.onAllNodesWithText("Biblioteca Maçônica")[0].assertIsDisplayed()
            }
        } finally {
            scenario.close()
            preferences.edit().apply {
                if (originalTheme == null) remove("theme") else putString("theme", originalTheme)
            }.commit()
        }
    }

    @Test
    fun dailyReadingOpensAndReturnsHome() {
        compose.onAllNodesWithText("Leitura")[0].performClick()
        compose.onAllNodesWithContentDescription("Voltar ao início")[0].assertIsDisplayed()
        compose.onAllNodesWithContentDescription("Voltar ao início")[0].performClick()
        compose.onAllNodesWithText("Biblioteca Maçônica")[0].assertIsDisplayed()
    }

    @Test
    fun readingNavigationRecordsVisitsInsteadOfCalendarOrder() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val raw = context.getSharedPreferences("breviario_prefs", android.content.Context.MODE_PRIVATE)
        val originalHistory = raw.getString("dailyRecentsV1", null)
        val repo = com.renatocamargo.breviariomaconico.data.BreviarioRepository.get(context)
        val prefs = com.renatocamargo.breviariomaconico.data.PreferencesStore(context)
        val today = repo.hoje()
        val previous = repo.anterior(today)
        val earlier = repo.anterior(previous)
        try {
            compose.onAllNodesWithText("Leitura")[0].performClick()
            compose.onAllNodesWithContentDescription("Leitura anterior")[0].performClick()
            compose.waitForIdle()
            compose.onAllNodesWithContentDescription("Leitura anterior")[0].performClick()
            compose.waitForIdle()
            compose.onAllNodesWithContentDescription("Próxima leitura")[0].performClick()
            val expected = listOf(previous, earlier, today).map { it.chavePersistencia }
            compose.waitUntil(5_000) {
                prefs.recentDailyItems(repo.itens).filter { it.obraId == today.obraId }
                    .map { it.chavePersistencia } == expected
            }
            compose.onAllNodesWithContentDescription("Voltar ao início")[0].performClick()
            compose.onAllNodesWithText("Biblioteca Maçônica")[0].assertIsDisplayed()
        } finally {
            raw.edit().apply {
                if (originalHistory == null) remove("dailyRecentsV1") else putString("dailyRecentsV1", originalHistory)
            }.commit()
        }
    }

    @Test
    fun readingToolbarExposesLastActionOnNarrowScreens() {
        compose.onAllNodesWithText("Leitura")[0].performClick()
        compose.onNodeWithTag("reader.tools").performTouchInput { swipeLeft() }
        compose.onAllNodesWithContentDescription("Configurações").fetchSemanticsNodes()
        compose.onAllNodesWithContentDescription("Editar leitura")[0].assertIsDisplayed().performClick()
        compose.onAllNodesWithText("Cancelar")[0].performClick()
        compose.onAllNodesWithContentDescription("Voltar ao início")[0].performClick()
        compose.onAllNodesWithText("Biblioteca Maçônica")[0].assertIsDisplayed()
    }


    @Test
    fun rapidTabSwitchingRemainsStable() {
        repeat(3) {
            compose.onNodeWithTag("tab.collections").performClick()
            compose.onNodeWithTag("tab.dossier").performClick()
            compose.onNodeWithTag("tab.acervo").performClick()
            compose.onNodeWithTag("tab.more").performClick()
            compose.onNodeWithTag("tab.home").performClick()
        }
        compose.onAllNodesWithText("Biblioteca Maçônica")[0].assertIsDisplayed()
    }

    @Test
    fun activityRecreationKeepsNavigationAvailable() {
        scenario.recreate()
        compose.waitUntil(10_000) {
            compose.onAllNodesWithText("Biblioteca Maçônica").fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithTag("tab.acervo").assertIsDisplayed()
    }

    @Test
    fun repeatedSettingsRoundTripsRemainStable() {
        repeat(3) {
            compose.onAllNodesWithContentDescription("Configurações")[0].performClick()
            compose.onAllNodesWithText("Configurações")[0].assertIsDisplayed()
            compose.onAllNodesWithContentDescription("Home")[0].performClick()
            compose.onAllNodesWithText("Biblioteca Maçônica")[0].assertIsDisplayed()
        }
    }
}
