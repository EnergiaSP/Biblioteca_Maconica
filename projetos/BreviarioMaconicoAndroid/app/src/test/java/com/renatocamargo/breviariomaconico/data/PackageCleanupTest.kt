package com.renatocamargo.breviariomaconico.data

import org.junit.Assert.assertEquals
import org.junit.Test

class PackageCleanupTest {
    /** Same cases as iOS (`testPackagesLeftOutOfTheCatalogAreRemovedButNotImports`). */
    @Test fun packagesLeftOutOfTheCatalogAreRemovedButNotImports() {
        val catalogo = setOf("rag_breviarios.sqlite", "bibliotecaMaconica/rag_a.sqlite")
        val arquivos = listOf(
            "rag_breviarios.sqlite", "rag_breviarios.sqlite.sha256",
            "bibliotecaMaconica/rag_a.sqlite", "bibliotecaMaconica/rag_a.sqlite.sha256",
            "bibliotecaMaconica/rag_copia.sqlite", "bibliotecaMaconica/rag_copia.sqlite.sha256",
            "imported_minha_obra_1.sqlite", "imported_minha_obra_1_images/page_1.jpg", "imported_works.json"
        )
        assertEquals(listOf("bibliotecaMaconica/rag_copia.sqlite", "bibliotecaMaconica/rag_copia.sqlite.sha256"),
            arquivosForaDoCatalogo(arquivos, catalogo))
    }

    /** Same cases as iOS (`testOrphanNoteCachesAreRemovedAfterADay`). */
    @Test fun orphanNoteCachesAreRemovedAfterADay() {
        val cacheDir = kotlin.io.path.createTempDirectory().toFile()
        try {
            val pasta = java.io.File(cacheDir, "RAGNotesSearchV1").apply { mkdirs() }
            val now = System.currentTimeMillis()
            listOf("atual.sqlite" to 3.0, "velho.sqlite" to 3.0, "velho.sqlite-journal" to 3.0, "recente.sqlite" to 0.5).forEach { (nome, dias) ->
                java.io.File(pasta, nome).apply { writeText("") }.setLastModified(now - (dias * 86_400_000).toLong())
            }
            NotesSearchIndex.removeOrphans(cacheDir, setOf("atual"), now)
            assertEquals(listOf("atual.sqlite", "recente.sqlite"), pasta.list().orEmpty().sorted())
        } finally {
            cacheDir.deleteRecursively()
        }
    }
}
