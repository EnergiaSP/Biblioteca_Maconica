package com.renatocamargo.breviariomaconico

import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import com.renatocamargo.breviariomaconico.data.BibliotecaBuscaResultado
import java.io.File

internal fun createDossierPdf(file: File, topic: String, results: List<BibliotecaBuscaResultado>,
    analysis: String = "", scope: String = "Toda a biblioteca", name: String = "") {
    val document = PdfDocument()
    val writer = PdfTextWriter(document, 595, 842, heading = "Biblioteca Maçônica")
    val body = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = PdfPremiumStyle.bodySize }
    try {
        writer.dossierCover(topic, results.size, scope, name)
        writer.beginContent("Dossiê - $topic")
        writer.drawStructuredText(textoDossie(topic, results, analysis, scope), PdfPremiumStyle.margin, 487f,
            PdfPremiumStyle.lineHeight, body)
        writer.finishCurrentPage()
        file.outputStream().use { document.writeTo(it) }
    } finally {
        try { writer.finishCurrentPage() } finally { document.close() }
    }
}
