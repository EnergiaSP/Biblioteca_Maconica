package com.renatocamargo.breviariomaconico

import com.renatocamargo.breviariomaconico.progress.ProgressLedger
import com.renatocamargo.breviariomaconico.progress.ProgressVersion
import org.junit.Assert.*
import org.junit.Test

class ProgressLedgerTest {
    @Test fun sharedVersionedCases() {
        val rows = javaClass.classLoader!!.getResourceAsStream("progress_sync_v1.tsv")!!.bufferedReader().use { it.readLines() }.filter { it.isNotBlank() }.drop(1)
        assertEquals(9, rows.size)
        rows.forEach { row ->
            val parts = row.split('\t')
            assertEquals(8, parts.size)
            val ledger = ProgressLedger()
            ledger.receive(ProgressVersion("obra", "20/09", parts[3].toBoolean(), parts[1].toLong(), parts[2]))
            val event = ProgressVersion("obra", "20/09", parts[6].toBoolean(), parts[4].toLong(), parts[5])
            assertEquals(parts[0], parts[7].toBoolean(), ledger.receive(event))
        }
    }
    @Test fun offlineMultipleWorksRemainIndependent() {
        val state = ProgressLedger()
        state.edit("obra_a", "20/09", true, 100, "a")
        state.edit("obra_b", "20/09", true, 100, "b")
        state.edit("obra_a", "21/09", true, 100, "c")
        assertEquals(3, state.pending.size)
    }
    @Test fun rejectsDuplicatesStaleAndLegacyMessages() {
        val state = ProgressLedger()
        val first = state.edit("obra", "20/09", true, 100, "a")!!
        val last = state.edit("obra", "20/09", false, 90, "b")!!
        assertTrue(last.timestamp > first.timestamp)
        assertFalse(state.receive(first))
        assertFalse(state.receive(last))
        assertFalse(state.receive(ProgressVersion("obra", "20/09", true, 0, "legacy")))
        assertEquals(last, state.latest[last.key])
        state.delivered(first)
        assertEquals(last, state.pending[last.key])
        state.delivered(last)
        assertTrue(state.pending.isEmpty())
    }
    @Test fun tieBreakConverges() {
        val a = ProgressVersion("obra", "29/02", true, 100, "a")
        val b = ProgressVersion("obra", "29/02", false, 100, "b")
        val first = ProgressLedger()
        val second = ProgressLedger()
        assertTrue(first.receive(a)); assertTrue(first.receive(b))
        assertTrue(second.receive(b)); assertFalse(second.receive(a))
        assertEquals(first.latest, second.latest)
    }
    @Test fun rejectsInvalidDatesAndMissingIdentity() {
        val state = ProgressLedger()
        listOf("31/04", "32/01", "00/09", "20/13", "1/09", "ab/cd", "01/+1").forEach {
            assertNull(state.edit("obra", it, true, 100, "a"))
        }
        assertNull(state.edit("", "01/01", true, 100, "a"))
        assertNull(state.edit("obra", "01/01", true, Long.MAX_VALUE, "a"))
        assertNull(state.edit("obra", "01/01", true, 100, ""))
        assertFalse(state.receive(ProgressVersion("obra", "01/01", true, -1, "a")))
    }
}
