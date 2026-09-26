package com.renatocamargo.breviariomaconico.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.isActive
import java.io.File

/**
 * Scores study themes straight from the FTS index of a downloaded package, so collections and
 * study paths consider every page without reading each page's text into memory.
 * Applies the shared rule of [StudyRules]: whole words, distinct keywords first, then occurrences.
 */
internal object StudyIndex {
    data class PageRef(val obraId: String, val pagina: Int)
    data class PageScore(val ref: PageRef, val topics: Int, val occurrences: Int)

    private data class Position(val doc: Long, val offset: Int)

    val order: Comparator<PageScore> = compareByDescending<PageScore> { it.topics }
        .thenByDescending { it.occurrences }
        .thenBy { it.ref.obraId }
        .thenBy { it.ref.pagina }

    /** Returns, for each rule, its `limits[i]` best pages among [works]; keywords come from [StudyRules.studyKeywords]. */
    fun score(db: RagSQLite, works: Set<String>, rules: List<Set<String>>, limits: List<Int>, cancelled: () -> Boolean = { false }): List<List<PageScore>> {
        // Instance rows (term, doc, column, offset) let SQLite count words and phrases per page.
        db.execSQL("CREATE VIRTUAL TABLE IF NOT EXISTS temp.vocab USING fts5vocab(main, rag_fts, 'instance')")
        val all = rules.flatten().toSet()

        // Counts are gathered per index block first; blocks are mapped to pages once at the end.
        val byBlock = HashMap<Long, MutableMap<String, Int>>()
        val single = all.filterNot { ' ' in it }.sorted()
        if (single.isNotEmpty()) {
            db.rawQuery("SELECT doc, term, count(*) FROM temp.vocab WHERE col = 'texto' AND term IN (${single.joinToString { "?" }}) GROUP BY doc, term",
                single.toTypedArray()).use { rows ->
                while (rows.moveToNext()) {
                    if (cancelled()) throw kotlinx.coroutines.CancellationException()
                    byBlock.getOrPut(rows.getLong(0)) { HashMap() }.merge(rows.getString(1), rows.getInt(2), Int::plus)
                }
            }
        }

        for (phrase in all.filter { ' ' in it }.sorted()) {
            // Consecutive token positions in the same block form the phrase, as in StudyRules.KeywordCounter.
            val words = phrase.split(' ')
            val positions = words.map { word ->
                db.rawQuery("SELECT doc, offset FROM temp.vocab WHERE col = 'texto' AND term = ?", arrayOf(word)).use { rows ->
                    buildSet { while (rows.moveToNext()) add(Position(rows.getLong(0), rows.getInt(1))) }
                }
            }
            for (start in positions[0]) {
                if ((1 until words.size).all { Position(start.doc, start.offset + it) in positions[it] }) {
                    byBlock.getOrPut(start.doc) { HashMap() }.merge(phrase, 1, Int::plus)
                }
            }
        }

        val counts = HashMap<PageRef, MutableMap<String, Int>>()
        if (byBlock.isNotEmpty()) {
            // Pages split into several index blocks are summed per page.
            db.rawQuery(blocksToPagesQuery(db), emptyArray()).use { rows ->
                while (rows.moveToNext()) {
                    val perWord = byBlock[rows.getLong(0)] ?: continue
                    val work = rows.getString(1)
                    if (work !in works) continue
                    val page = counts.getOrPut(PageRef(work, rows.getInt(2))) { HashMap() }
                    perWord.forEach { (word, count) -> page.merge(word, count, Int::plus) }
                }
            }
        }

        // Footnotes are not in the index; they are short, so they are counted in memory.
        val counter = StudyRules.KeywordCounter(all)
        db.rawQuery("SELECT obra_id, pagina, numero, texto FROM rag_notas", emptyArray()).use { rows ->
            while (rows.moveToNext()) {
                val work = rows.getString(0)
                if (work !in works) continue
                val found = counter.count(StudyRules.studyNormalized(rows.getString(2) + " " + rows.getString(3)))
                if (found.isEmpty()) continue
                val page = counts.getOrPut(PageRef(work, rows.getInt(1))) { HashMap() }
                found.forEach { (word, count) -> page.merge(word, count, Int::plus) }
            }
        }

        // Each page is visited once and scores every rule that shares one of its words.
        val rulesByWord = HashMap<String, MutableList<Int>>()
        rules.forEachIndexed { index, words -> words.forEach { rulesByWord.getOrPut(it) { mutableListOf() }.add(index) } }
        val best = List(rules.size) { mutableListOf<PageScore>() }
        val topics = IntArray(rules.size)
        val occurrences = IntArray(rules.size)
        for ((ref, perWord) in counts) {
            val touched = mutableListOf<Int>()
            for ((word, count) in perWord) {
                if (count <= 0) continue
                for (index in rulesByWord[word].orEmpty()) {
                    if (topics[index] == 0) touched.add(index)
                    topics[index]++
                    occurrences[index] += count
                }
            }
            for (index in touched) {
                insert(PageScore(ref, topics[index], occurrences[index]), best[index], limits[index])
                topics[index] = 0
                occurrences[index] = 0
            }
        }
        return best
    }

    /** Keeps the best pages of each rule across packages; same order as [StudyRules]. */
    fun combine(current: List<List<PageScore>>, next: List<List<PageScore>>, limits: List<Int>): List<List<PageScore>> =
        current.indices.map { index -> (current[index] + next[index]).sortedWith(order).take(limits[index].coerceAtLeast(0)) }

    /** Keeps [list] sorted with at most [limit] entries without sorting every candidate. */
    private fun insert(score: PageScore, list: MutableList<PageScore>, limit: Int) {
        if (limit <= 0) return
        if (list.size == limit && order.compare(score, list.last()) >= 0) return
        val position = list.indexOfFirst { order.compare(score, it) < 0 }.let { if (it < 0) list.size else it }
        list.add(position, score)
        if (list.size > limit) list.removeAt(list.lastIndex)
    }

    /**
     * Lists every index block with its work and page. Catalog packages keep both in the FTS content
     * table; indexes created by the PDF importer only keep the block id, used to reach the paragraph.
     */
    private fun blocksToPagesQuery(db: RagSQLite): String {
        val columns = db.rawQuery("PRAGMA table_info(rag_fts)", emptyArray()).use { rows ->
            buildList { while (rows.moveToNext()) add(rows.getString(1)) }
        }
        val work = columns.indexOf("obra_id")
        val page = columns.indexOf("pagina")
        // Reading these columns from the content table avoids loading each page's full text.
        if (work >= 0 && page >= 0) return "SELECT id, c$work, c$page FROM rag_fts_content"
        val block = columns.indexOf("bloco_id")
        require(block >= 0) { "Índice sem identificação de bloco." }
        val sameWork = if (work >= 0) " AND p.obra_id = f.c$work" else ""
        return "SELECT f.id, p.obra_id, p.pagina FROM rag_fts_content f JOIN rag_paragrafos p ON p.id = f.c$block$sameWork"
    }
}

/**
 * Scores every page of the downloaded packages that hold [workIds]. Packages are independent files,
 * so they are scored in parallel, each on its own read-only connection. Failed packages are returned
 * by title so the caller can warn instead of hiding them.
 */
internal suspend fun BibliotecaCatalogRepository.scoreStudy(workIds: Set<String>, rules: List<Set<String>>, limits: List<Int>):
    Pair<List<List<StudyIndex.PageScore>>, List<String>> = coroutineScope {
    val jobs = pacotes.mapNotNull { pacote ->
        val works = pacote.obras.map { it.id }.toSet().intersect(workIds)
        val file = localFile(pacote)
        if (works.isEmpty() || !file.exists()) null else Triple(pacote.titulo, file, works)
    }.distinctBy { it.second.absolutePath }
    val context = currentCoroutineContext()
    val results = jobs.map { (_, file, works) ->
        async(Dispatchers.IO) {
            runCatching { scorePackage(file, works, rules, limits) { !context.isActive } }
        }
    }.awaitAll()
    context.ensureActive()
    var merged: List<List<StudyIndex.PageScore>> = List(rules.size) { emptyList() }
    val failures = mutableListOf<String>()
    // Merged in package order so the outcome does not depend on thread timing.
    results.forEachIndexed { index, result ->
        result.onSuccess { merged = StudyIndex.combine(merged, it, limits) }.onFailure { failures.add(jobs[index].first) }
    }
    merged to failures
}

private fun scorePackage(file: File, works: Set<String>, rules: List<Set<String>>, limits: List<Int>, cancelled: () -> Boolean) =
    RagSQLite.open(file.absolutePath, readOnly = true).use { db -> StudyIndex.score(db, works, rules, limits, cancelled) }

/** Loads only the chosen pages of a work, with footnotes, in the same form as the study batches. */
internal fun BibliotecaCatalogRepository.studyItems(obraId: String, paginas: List<Int>): List<BreviarioItem> {
    val pacote = pacotes.firstOrNull { it.obras.any { obra -> obra.id == obraId } } ?: return emptyList()
    val file = localFile(pacote)
    if (!file.exists() || paginas.isEmpty()) return emptyList()
    return RagSQLite.open(file.absolutePath, readOnly = true).use { db ->
        paginas.distinct().sorted().chunked(200).flatMap { chunk ->
            val items = db.rawQuery("""
                SELECT p.numero_original, COALESCE(p.titulo, ''), p.texto_integral, COALESCE(o.autor, '')
                FROM rag_paginas p JOIN rag_obras o ON o.id = p.obra_id
                WHERE p.obra_id = ? AND p.numero_original IN (${chunk.joinToString { "?" }}) ORDER BY p.numero_original
            """.trimIndent(), (listOf<Any>(obraId) + chunk).toTypedArray()).use { rows ->
                buildList {
                    while (rows.moveToNext()) {
                        val page = rows.getInt(0)
                        add(BreviarioItem("$obraId-pagina-$page".hashCode(), "P$page",
                            rows.getString(1).ifBlank { "Página $page" }, rows.getString(3), rows.getString(2), "", page, obraId))
                    }
                }
            }
            val notes = db.rawQuery("SELECT pagina, numero, texto FROM rag_notas WHERE obra_id = ? AND pagina IN (${chunk.joinToString { "?" }}) ORDER BY pagina, numero",
                (listOf<Any>(obraId) + chunk).toTypedArray()).use { rows ->
                buildMap<Int, MutableList<String>> {
                    while (rows.moveToNext()) {
                        val number = rows.getString(1)
                        val text = rows.getString(2)
                        getOrPut(rows.getInt(0)) { mutableListOf() }.add(if (number.isEmpty()) text else "$number $text")
                    }
                }
            }
            items.map { it.copy(rodape = notes[it.pagina].orEmpty().joinToString("\n")) }
        }
    }
}
