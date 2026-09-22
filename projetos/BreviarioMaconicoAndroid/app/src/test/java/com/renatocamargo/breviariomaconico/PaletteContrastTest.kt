package com.renatocamargo.breviariomaconico

import androidx.compose.ui.graphics.Color
import com.renatocamargo.breviariomaconico.data.AppThemeMode
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PaletteContrastTest {
    private fun luminance(color: Color): Double {
        fun linear(value: Float): Double = value.toDouble().let {
            if (it <= 0.04045) it / 12.92 else ((it + 0.055) / 1.055).pow(2.4)
        }
        return linear(color.red) * 0.2126 + linear(color.green) * 0.7152 + linear(color.blue) * 0.0722
    }

    private fun contrast(first: Color, second: Color): Double {
        val a = luminance(first)
        val b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    @Test
    fun textAndStatusMeetMinimumInEveryTheme() {
        assertEquals(21.0, contrast(Color.White, Color.Black), 0.0001)
        AppThemeMode.entries.forEach { theme ->
            val colors = palette(theme)
            (colors.background + colors.surface).forEach { background ->
                listOf(colors.text, colors.secondary, colors.accent, colors.success).forEach { foreground ->
                    assertTrue("$theme: ${contrast(foreground, background)}", contrast(foreground, background) >= 4.5)
                }
            }
            assertTrue("$theme badge", contrast(colors.onAccent, colors.accentSurface) >= 4.5)
        }
    }
}
