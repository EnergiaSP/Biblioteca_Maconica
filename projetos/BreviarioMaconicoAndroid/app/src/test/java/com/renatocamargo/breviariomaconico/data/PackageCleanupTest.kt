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
}
