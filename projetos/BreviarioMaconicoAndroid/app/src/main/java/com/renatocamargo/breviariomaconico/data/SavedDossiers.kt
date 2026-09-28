package com.renatocamargo.breviariomaconico.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate

/**
 * A saved dossier keeps the question, not the answer: reopening rebuilds it from the installed
 * collection, so it never shows outdated text. Reviews are dated from the day it was saved.
 * Same fields and rules as iOS `DossieSalvo`.
 */
internal data class SavedDossier(
    val id: String,
    val tema: String,
    val area: String?,
    val obraId: String?,
    val autor: String,
    val assunto: String,
    /** yyyy-MM-dd */
    val criadoEm: String,
    val revisoesConcluidas: List<Int> = emptyList()
) {
    enum class Status { FEITA, ATRASADA, HOJE, PROXIMA }
    data class Review(val days: Int, val task: String, val date: LocalDate, val status: Status)

    val createdDate: LocalDate get() = LocalDate.parse(criadoEm)

    /** Identifies the same study (topic and scope), ignoring case and surrounding spaces. */
    val chave: String get() = chave(tema, area, obraId, autor, assunto)

    fun reviews(steps: List<DossierAnalysis.ReviewStep>, today: LocalDate): List<Review> = steps.map { step ->
        val date = createdDate.plusDays(step.days.toLong())
        val status = when {
            step.days in revisoesConcluidas -> Status.FEITA
            date < today -> Status.ATRASADA
            date == today -> Status.HOJE
            else -> Status.PROXIMA
        }
        Review(step.days, step.task, date, status)
    }

    fun nextReview(steps: List<DossierAnalysis.ReviewStep>, today: LocalDate): Review? =
        reviews(steps, today).firstOrNull { it.status != Status.FEITA }

    fun toggled(days: Int): SavedDossier = copy(
        revisoesConcluidas = if (days in revisoesConcluidas) revisoesConcluidas - days else (revisoesConcluidas + days).sorted()
    )

    fun toJson(): JSONObject = JSONObject()
        .put("id", id).put("tema", tema).put("area", area ?: JSONObject.NULL).put("obraId", obraId ?: JSONObject.NULL)
        .put("autor", autor).put("assunto", assunto).put("criadoEm", criadoEm)
        .put("revisoesConcluidas", JSONArray(revisoesConcluidas))

    companion object {
        fun chave(tema: String, area: String?, obraId: String?, autor: String, assunto: String): String =
            listOf(tema, area.orEmpty(), obraId.orEmpty(), autor, assunto).joinToString("|") { it.trim().lowercase() }

        fun fromJson(json: JSONObject) = SavedDossier(
            id = json.getString("id"),
            tema = json.getString("tema"),
            area = json.optString("area").takeUnless { json.isNull("area") || it.isBlank() },
            obraId = json.optString("obraId").takeUnless { json.isNull("obraId") || it.isBlank() },
            autor = json.optString("autor"),
            assunto = json.optString("assunto"),
            criadoEm = json.getString("criadoEm"),
            revisoesConcluidas = json.optJSONArray("revisoesConcluidas")?.let { a -> List(a.length()) { a.getInt(it) } }.orEmpty()
        )
    }
}

/** Saved dossiers on this device, most recent first. */
internal class SavedDossierStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("dossies_salvos", Context.MODE_PRIVATE)

    fun all(): List<SavedDossier> {
        val raw = prefs.getString(KEY, null) ?: return emptyList()
        val array = runCatching { JSONArray(raw) }.getOrNull() ?: return emptyList()
        return List(array.length()) { SavedDossier.fromJson(array.getJSONObject(it)) }
            .sortedWith(compareByDescending<SavedDossier> { it.criadoEm }.thenBy { it.tema.lowercase() })
    }

    fun find(id: String): SavedDossier? = all().firstOrNull { it.id == id }

    fun findByKey(chave: String): SavedDossier? = all().firstOrNull { it.chave == chave }

    /** Replaces the dossier with the same id, or the same study saved before. */
    fun save(dossier: SavedDossier) =
        write(all().filterNot { it.id == dossier.id || it.chave == dossier.chave } + dossier)

    fun remove(id: String) = write(all().filterNot { it.id == id })

    private fun write(list: List<SavedDossier>) {
        prefs.edit().putString(KEY, JSONArray(list.map { it.toJson() }).toString()).apply()
    }

    private companion object {
        const val KEY = "v1"
    }
}
