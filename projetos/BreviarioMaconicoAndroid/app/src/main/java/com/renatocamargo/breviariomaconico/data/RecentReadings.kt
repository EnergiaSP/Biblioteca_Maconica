package com.renatocamargo.breviariomaconico.data

internal data class DailyRecent(val workId: String, val date: String)

// Input is newest first. A visit in one work must not evict another work's history.
internal fun <T> recentByWork(
    entries: List<T>, limit: Int,
    work: (T) -> String, reference: (T) -> String
): List<T> {
    if (limit <= 0) return emptyList()
    val seen = mutableSetOf<Pair<String, String>>()
    val counts = mutableMapOf<String, Int>()
    return entries.filter { entry ->
        val id = work(entry)
        val position = reference(entry)
        if (id.isBlank() || position.isBlank() || !seen.add(id to position)) false
        else if ((counts[id] ?: 0) >= limit) false
        else { counts[id] = (counts[id] ?: 0) + 1; true }
    }
}
