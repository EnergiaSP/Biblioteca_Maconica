package com.renatocamargo.breviariomaconico

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.renatocamargo.breviariomaconico.data.BreviarioRepository
import com.renatocamargo.breviariomaconico.data.ObraId
import com.renatocamargo.breviariomaconico.data.TextoFormatter
import com.renatocamargo.breviariomaconico.widget.BreviarioWidgetProvider
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** Renders the home screen widget as the launcher would, at the sizes the provider distinguishes. */
@RunWith(AndroidJUnit4::class)
class WidgetRenderTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()

    private fun render(width: Int, height: Int): View {
        var root: View? = null
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val views = BreviarioWidgetProvider.buildViews(context, 1, width, height)
            root = views.apply(context, FrameLayout(context))
        }
        return root!!
    }

    private fun View.text(id: Int) = findViewById<TextView>(id)

    @Test fun providerIsOfferedToLaunchers() {
        val providers = AppWidgetManager.getInstance(context).getInstalledProvidersForPackage(context.packageName, null)
        val provider = providers.single { it.provider == ComponentName(context, BreviarioWidgetProvider::class.java) }
        assertTrue(provider.resizeMode != 0)
    }

    /** Same order as iOS `BreviarioSnapshotProvider.recursosEmbutidos`: Século XXI first, then Rizzardo. */
    @Test fun dailyReadingFollowsTheBreviaryOrderOfIos() {
        val repo = BreviarioRepository.get(context)
        assertEquals(ObraId.BREVIARIO_SECULO_XXI, repo.hoje().obraId)
        assertEquals(listOf(ObraId.BREVIARIO_SECULO_XXI, ObraId.BREVIARIO_RIZZARDO), repo.leiturasDeHoje().map { it.obraId })
        assertEquals(ObraId.BREVIARIO_SECULO_XXI, repo.porData("28/09")!!.obraId)
    }

    @Test fun showsTodaysReadingAtEverySize() {
        val item = BreviarioRepository.get(context).hoje()
        assertTrue(item.titulo.isNotBlank() && item.texto.isNotBlank())
        val compact = render(250, 110)
        val medium = render(250, 180)
        val large = render(320, 260)
        listOf(compact, medium, large).forEach { root ->
            assertEquals(TextoFormatter.dataPorExtenso(item.data), root.text(R.id.widgetDate).text.toString())
            assertEquals(item.titulo, root.text(R.id.widgetTitle).text.toString())
            assertTrue(root.findViewById<View>(R.id.widgetRoot).hasOnClickListeners())
        }
        assertEquals(View.GONE, compact.text(R.id.widgetExcerpt).visibility)
        assertEquals(4, compact.text(R.id.widgetTitle).maxLines)
        assertEquals(View.VISIBLE, medium.text(R.id.widgetExcerpt).visibility)
        assertEquals(item.texto.take(220), medium.text(R.id.widgetExcerpt).text.toString())
        assertEquals(4, medium.text(R.id.widgetExcerpt).maxLines)
        assertEquals(item.texto.take(520), large.text(R.id.widgetExcerpt).text.toString())
        assertEquals(9, large.text(R.id.widgetExcerpt).maxLines)
    }
}
