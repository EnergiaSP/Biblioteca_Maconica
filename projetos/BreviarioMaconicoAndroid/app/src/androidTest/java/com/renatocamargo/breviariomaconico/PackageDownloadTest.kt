package com.renatocamargo.breviariomaconico

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.renatocamargo.breviariomaconico.data.BibliotecaCatalogRepository
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Same check as iOS (`testDownloadingTheSamePackageTwiceKeepsOneCopy`); needs the network. */
@RunWith(AndroidJUnit4::class)
class PackageDownloadTest {
    @Test
    fun downloadingTheSamePackageTwiceKeepsOneCopy() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val repo = BibliotecaCatalogRepository.get(context)
        val pacote = repo.pacotes.first { it.arquivo == "bibliotecaMaconica/rag_bula_clemente_xii.sqlite" }
        val file = File(context.filesDir, "RAGPackages/${pacote.arquivo}")
        val marker = File(file.path + ".sha256")
        val folder = file.parentFile!!
        val savedFile = file.takeIf { it.exists() }?.readBytes()
        val savedMarker = marker.takeIf { it.exists() }?.readText()
        fun copies() = folder.listFiles()!!.count { it.name.startsWith("rag_bula_clemente_xii") }
        // Each download is tried twice; without the network the test is skipped, not failed.
        fun download() {
            val failure = runCatching { repo.instalar(pacote) }.exceptionOrNull()?.let { runCatching { repo.instalar(pacote) }.exceptionOrNull() }
            org.junit.Assume.assumeTrue("Sem rede para baixar o pacote: $failure", failure == null)
        }
        try {
            download()
            val pages = repo.paginasDaObra("bula_clemente_xii").size
            val hits = repo.buscarConteudo("bula", obraId = "bula_clemente_xii").size
            assertTrue(pages > 0 && hits > 0)
            download()
            // One package and its version marker, no leftover download, the same pages and search results.
            assertEquals(2, copies())
            assertTrue(folder.listFiles()!!.none { it.name.endsWith(".download") })
            assertEquals(pacote.sha256, marker.readText().trim())
            assertEquals(pages, repo.paginasDaObra("bula_clemente_xii").size)
            assertEquals(hits, repo.buscarConteudo("bula", obraId = "bula_clemente_xii").size)
        } finally {
            if (savedFile != null) file.writeBytes(savedFile) else file.delete()
            if (savedMarker != null) marker.writeText(savedMarker) else marker.delete()
        }
    }
}
