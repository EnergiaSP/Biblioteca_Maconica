package com.renatocamargo.breviariomaconico.progress

data class ProgressVersion(val work: String, val date: String, val read: Boolean, val timestamp: Long, val eventId: String) {
    val key get() = "$work|$date"
    fun newerThan(other: ProgressVersion) =
        if (timestamp != other.timestamp) timestamp > other.timestamp else eventId > other.eventId
    fun valid() = validReading(work, date) && timestamp >= 0 && timestamp < Long.MAX_VALUE && eventId.isNotEmpty() && eventId.length <= 128

    companion object {
        fun validReading(work: String, date: String): Boolean {
            if (work.isEmpty() || work.length > 200 || '|' in work || !date.matches(Regex("[0-9]{2}/[0-9]{2}"))) return false
            val day = date.take(2).toInt()
            val month = date.takeLast(2).toInt()
            return month in 1..12 && day in 1..intArrayOf(31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[month - 1]
        }
    }
}

class ProgressLedger(
    val latest: MutableMap<String, ProgressVersion> = mutableMapOf(),
    val pending: MutableMap<String, ProgressVersion> = mutableMapOf()
) {
    fun edit(work: String, date: String, read: Boolean, now: Long, id: String): ProgressVersion? {
        if (!ProgressVersion.validReading(work, date)) return null
        val previous = latest.values.maxOfOrNull { it.timestamp } ?: 0L
        if (previous >= Long.MAX_VALUE - 1) return null
        val event = ProgressVersion(work, date, read, maxOf(now, previous + 1), id)
        if (!event.valid()) return null
        return event.also {
            latest[it.key] = it
            pending[it.key] = it
        }
    }
    fun receive(event: ProgressVersion): Boolean {
        if (!event.valid() || latest[event.key]?.let { !event.newerThan(it) } == true) return false
        latest[event.key] = event
        pending.remove(event.key)
        return true
    }
    fun delivered(event: ProgressVersion) {
        if (pending[event.key] == event) pending.remove(event.key)
    }
}
