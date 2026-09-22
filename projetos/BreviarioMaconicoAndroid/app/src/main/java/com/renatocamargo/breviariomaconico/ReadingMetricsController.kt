package com.renatocamargo.breviariomaconico

import kotlin.math.roundToInt

internal object ReadingMetricsController {
    fun progress(completed: Int, total: Int): Float {
        if (total <= 0) return 0f
        return (completed.toFloat() / total.toFloat()).coerceIn(0f, 1f)
    }

    fun percentage(completed: Int, total: Int): Int =
        (progress(completed, total) * 100).roundToInt()
}
