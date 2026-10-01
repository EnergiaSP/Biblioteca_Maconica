package com.renatocamargo.breviariomaconico.data

import java.io.File

/**
 * Same rule as iOS (`BibliotecaOfflinePackageService.arquivosForaDoCatalogo`): a downloaded package
 * (`.sqlite`) or its version marker (`.sqlite.sha256`) whose path is no longer in the catalog (a work
 * removed as a copy of another, a package moved to another file) is deleted, so it does not take space.
 * Works the user imported (`imported_*`), their manifest and folders are never touched.
 */
internal fun arquivosForaDoCatalogo(relativos: List<String>, catalogo: Set<String>): List<String> =
    relativos.filter { caminho ->
        val nome = caminho.substringAfterLast('/')
        val pacote = caminho.removeSuffix(".sha256")
        !nome.startsWith("imported_") && pacote.endsWith(".sqlite") && pacote !in catalogo
    }

/** Deletes the packages left out of the catalog; returns how many files were removed. */
internal fun BibliotecaCatalogRepository.removerPacotesForaDoCatalogo(): Int {
    val raiz = File(appContext.filesDir, "RAGPackages")
    if (!raiz.isDirectory) return 0
    val relativos = raiz.walkTopDown().filter { it.isFile }.map { it.relativeTo(raiz).invariantSeparatorsPath }.toList()
    val remover = arquivosForaDoCatalogo(relativos, pacotes.map { it.arquivo }.toSet())
    return remover.count { File(raiz, it).delete() }
}
