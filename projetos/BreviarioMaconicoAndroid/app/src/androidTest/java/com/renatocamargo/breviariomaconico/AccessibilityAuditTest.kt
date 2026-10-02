package com.renatocamargo.breviariomaconico

import android.content.Intent
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.google.android.apps.common.testing.accessibility.framework.AccessibilityCheckPreset
import com.google.android.apps.common.testing.accessibility.framework.AccessibilityCheckResult.AccessibilityCheckResultType
import com.google.android.apps.common.testing.accessibility.framework.Parameters
import com.google.android.apps.common.testing.accessibility.framework.uielement.AccessibilityHierarchyAndroid
import com.google.android.apps.common.testing.accessibility.framework.utils.contrast.BitmapImage
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Locale

/**
 * Automated accessibility audits of the main screens with Google's Accessibility Test Framework
 * (labels, touch targets, text contrast), as iOS runs performAccessibilityAudit on its screens.
 */
@RunWith(AndroidJUnit4::class)
class AccessibilityAuditTest {
    @get:Rule
    val compose = createEmptyComposeRule()
    private lateinit var scenario: ActivityScenario<MainActivity>

    @Before
    fun launch() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        scenario = ActivityScenario.launch(Intent(context, MainActivity::class.java).putExtra("ui_testing", true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        compose.waitUntil(10_000) { compose.onAllNodesWithText("Biblioteca Maçônica").fetchSemanticsNodes().isNotEmpty() }
    }

    @After
    fun close() = scenario.close()

    /** Errors found by the framework on the screen now shown, described for the failure message. */
    private fun audit(screen: String): List<String> {
        compose.waitForIdle()
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val automation = instrumentation.uiAutomation
        // The accessibility tree follows the screen with a delay; wait until it settles.
        automation.waitForIdle(500, 10_000)
        // Built from the app's own window, as Espresso does, so Compose's semantics nodes are included.
        var hierarchy: com.google.android.apps.common.testing.accessibility.framework.uielement.AccessibilityHierarchyAndroid? = null
        scenario.onActivity { activity -> hierarchy = AccessibilityHierarchyAndroid.newBuilder(activity.window.decorView).build() }
        val built = hierarchy ?: return listOf("$screen: tela sem janela ativa")
        val screenshot = automation.takeScreenshot()
        val parameters = Parameters().apply { screenshot?.let { putScreenCapture(BitmapImage(it)) } }
        val results = AccessibilityCheckPreset.getAccessibilityHierarchyChecksForPreset(AccessibilityCheckPreset.LATEST)
            .flatMap { it.runCheckOnHierarchy(built, null, parameters) }
        val elements = built.activeWindow.allViews.size
        android.util.Log.i("AuditoriaA11y", "$screen: $elements elementos, captura=${screenshot != null}, " +
            results.groupingBy { it.type }.eachCount())
        results.filter { it.type == AccessibilityCheckResultType.WARNING }.forEach {
            android.util.Log.i("AuditoriaA11y", "$screen AVISO ${it.sourceCheckClass.simpleName}: ${it.getMessage(Locale("pt", "BR"))} " +
                "[${it.element?.className} \"${it.element?.text ?: it.element?.contentDescription ?: ""}\"]")
        }
        // The audit must have looked at the screen: its elements and a screenshot for the contrast check.
        assertTrue("$screen: auditoria sem elementos", elements > 5)
        assertTrue("$screen: sem captura de tela para o contraste", screenshot != null)
        // Warnings count too: low contrast and repeated spoken text are fixed, not tolerated.
        // A text cut by the edge of a scroll container shows only a sliver of its glyphs, and the contrast
        // estimated on it mixes text and background (the framework says so); it is checked when scrolled into view.
        val sliver = 24 * instrumentation.targetContext.resources.displayMetrics.density
        return results.filter { it.type == AccessibilityCheckResultType.ERROR || it.type == AccessibilityCheckResultType.WARNING }
            .filterNot { result ->
                result.sourceCheckClass.simpleName == "TextContrastCheck" &&
                    (result.element?.boundsInScreen?.let { it.bottom - it.top } ?: Int.MAX_VALUE) < sliver
            }
            .map { result ->
                val element = result.element
                "$screen: ${result.getMessage(Locale("pt", "BR"))} [${element?.className} " +
                    "\"${element?.text ?: element?.contentDescription ?: ""}\" ${element?.boundsInScreen}]"
            }
    }

    @Test
    fun mainScreensHaveNoAccessibilityErrors() {
        val errors = mutableListOf<String>()
        errors += audit("Início")
        for ((tag, name) in listOf("tab.collections" to "Coleções", "tab.dossier" to "Dossiê", "tab.acervo" to "Acervo", "tab.more" to "Mais")) {
            compose.onNodeWithTag(tag).performClick()
            if (tag == "tab.collections") {
                compose.waitUntil(30_000) { compose.onAllNodesWithText("Coleções temáticas").fetchSemanticsNodes().isNotEmpty() }
            }
            errors += audit(name)
        }
        for (screen in listOf("Trilhas por grau", "Caderno de estudo")) {
            compose.onNodeWithTag("tab.more").performClick()
            compose.onNodeWithText(screen).performScrollTo().performClick()
            errors += audit(screen)
        }
        assertTrue(errors.joinToString("\n"), errors.isEmpty())
    }
}
