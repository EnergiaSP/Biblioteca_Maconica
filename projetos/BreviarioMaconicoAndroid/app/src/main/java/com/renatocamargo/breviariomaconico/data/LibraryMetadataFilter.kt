package com.renatocamargo.breviariomaconico.data

data class LibraryMetadataFilter(val autor: String = "", val assunto: String = "") {
    val descricao: String get() = listOf("Autor" to autor, "Assunto" to assunto)
        .mapNotNull { (label, value) -> value.trim().takeIf { it.isNotEmpty() }?.let { "$label: $it" } }
        .joinToString(" • ")

    fun matches(work: BibliotecaObraCatalogo): Boolean =
        (autor.isBlank() || TextoFormatter.corresponde(autor, work.autor.orEmpty())) &&
        (assunto.isBlank() || TextoFormatter.corresponde(assunto, work.assuntos.joinToString(" ")))
}
