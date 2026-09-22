package com.renatocamargo.breviariomaconico.data

import org.junit.Assert.assertEquals
import org.junit.Test

class RecentReadingsTest {
    private fun select(entries: List<DailyRecent>, limit: Int = 3) =
        recentByWork(entries, limit, { it.workId }, { it.date })

    @Test fun limitsEachWorkWithoutMixingIdenticalDates() {
        val entries = (1..5).flatMap { listOf(DailyRecent("a", "$it/01"), DailyRecent("b", "$it/01")) }
        assertEquals(entries.take(6), select(entries))
    }

    @Test fun newestVisitReplacesOnlyTheSameWorkAndReference() {
        val latest = DailyRecent("a", "01/01")
        val entries = listOf(latest, DailyRecent("b", "01/01"), latest, DailyRecent("a", "02/01"))
        assertEquals(listOf(latest, entries[1], entries[3]), select(entries))
    }

    @Test fun openingAnOlderDateStillMakesItTheMostRecent() {
        val entries = listOf(DailyRecent("a", "01/01"), DailyRecent("a", "31/12"))
        assertEquals(entries, select(entries))
    }

    @Test fun invalidEntriesAndEmptyLimitDoNotCreateHistory() {
        assertEquals(emptyList<DailyRecent>(), select(listOf(DailyRecent("", "01/01"), DailyRecent("a", ""))))
        assertEquals(emptyList<DailyRecent>(), select(listOf(DailyRecent("a", "01/01")), 0))
    }
}
