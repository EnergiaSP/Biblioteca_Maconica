package com.renatocamargo.breviariomaconico

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.renatocamargo.breviariomaconico.data.BibliotecaArea
import com.renatocamargo.breviariomaconico.data.BibliotecaBuscaResultado
import com.renatocamargo.breviariomaconico.data.LibraryMetadataFilter

internal const val MENSAGEM_INICIAL_BUSCA = "Digite um termo para buscar nas obras baixadas."
internal const val MENSAGEM_INICIAL_DOSSIE = "Informe um tema para montar um dossiê com fontes do acervo baixado."

/** Keeps search and dossier inputs and results while the user opens a result and comes back. */
internal class LibraryStudySession(statusInicial: String, termoInicial: String = "") {
    var termo by mutableStateOf(termoInicial)
    var metadataFilter by mutableStateOf(LibraryMetadataFilter())
    var area by mutableStateOf<BibliotecaArea?>(null)
    var obraId by mutableStateOf<String?>(null)
    var resultados by mutableStateOf(emptyList<BibliotecaBuscaResultado>())
    var status by mutableStateOf(statusInicial)
    var temMais by mutableStateOf(false)
    var analiseIa by mutableStateOf("")
    var dossierStudy by mutableStateOf<DossierStudy?>(null)
    /** Saved dossier shown now, and one waiting to be opened (from a review notification). */
    var savedDossierId by mutableStateOf<String?>(null)
    var pendingSavedDossierId by mutableStateOf<String?>(null)
    var ultimaConsulta: List<Any?>? = null
}
