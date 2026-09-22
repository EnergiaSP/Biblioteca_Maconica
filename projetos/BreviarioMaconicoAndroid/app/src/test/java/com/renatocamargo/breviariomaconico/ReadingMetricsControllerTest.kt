package com.renatocamargo.breviariomaconico

import org.junit.Assert.assertEquals
import org.junit.Test

class ReadingMetricsControllerTest {
    @Test
    fun metricsAreBoundedAndHandleEmptyCollections() {
        assertEquals(0f, ReadingMetricsController.progress(0, 0))
        assertEquals(50, ReadingMetricsController.percentage(2, 4))
        assertEquals(1f, ReadingMetricsController.progress(8, 4))
    }
}
