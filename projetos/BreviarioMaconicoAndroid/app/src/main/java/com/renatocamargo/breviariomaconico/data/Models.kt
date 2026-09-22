package com.renatocamargo.breviariomaconico.data

data class BreviarioItem(
    val id: Int,
    val data: String,
    val titulo: String,
    val autor: String,
    val texto: String,
    val rodape: String,
    val pagina: Int,
    val obraId: String = ObraId.BREVIARIO_SECULO_XXI
) {
    val chavePersistencia: String
        get() = "${obraId}_$data"
}

object ObraId {
    const val BREVIARIO_SECULO_XXI = "breviario_seculo_xxi"
}

data class IndiceRemissivoEntry(
    val id: Int,
    val termo: String,
    val datas: List<String>,
    val paginas: List<Int>
)

enum class AppThemeMode(val label: String) {
    Dark("Escuro"),
    Light("Claro"),
    Sepia("Sépia")
}

data class ReaderSettings(
    val theme: AppThemeMode = AppThemeMode.Dark,
    val fontSize: Float = 18f,
    val lineSpacing: Float = 8f,
    val voiceGender: String = "Feminina",
    val voiceSpeed: Float = 0.9f,
    val distractionFreeMode: Boolean = false,
    val premiumPdfName: String = "",
    val libraryContinuousMode: Boolean = true,
    val aiEnabled: Boolean = false,
    val geminiApiKey: String = "",
    val dailyNotificationEnabled: Boolean = false,
    val notificationHour: Int = 8,
    val notificationMinute: Int = 0,
    val notificationWorkIds: Set<String> = setOf(ObraId.BREVIARIO_SECULO_XXI)
)

data class OfficialSource(
    val id: String,
    val title: String,
    val origin: String,
    val url: String,
    val notes: String
)

data class WorkRequest(
    val id: String,
    val area: String,
    val title: String,
    val author: String,
    val notes: String
)

data class LibraryRecent(
    val obraId: String,
    val title: String,
    val area: String,
    val page: Int,
    val timestamp: Long
)

data class BreviarioTextEdit(
    val title: String,
    val text: String,
    val footnote: String
)

data class TextHighlight(
    val id: String,
    val text: String,
    val createdAt: Long
)

data class PersonalReflection(
    val persistenceKey: String,
    val workTitle: String,
    val date: String,
    val text: String,
    val updatedAt: Long
)

data class StudyPath(
    val id: String,
    val title: String,
    val objective: String,
    val suggestedDuration: String,
    val stages: List<String>,
    val keywords: List<String>,
    val subtitle: String,
    val instruction: String
)
