package com.renatocamargo.breviariomaconico

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.core.content.FileProvider
import com.renatocamargo.breviariomaconico.data.BibliotecaBuscaResultado
import com.renatocamargo.breviariomaconico.data.BibliotecaPaginaLeitura
import com.renatocamargo.breviariomaconico.data.BreviarioItem
import com.renatocamargo.breviariomaconico.data.ReaderSettings
import com.renatocamargo.breviariomaconico.data.TextHighlight
import com.renatocamargo.breviariomaconico.data.TextoFormatter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.CancellationException
import java.util.concurrent.atomic.AtomicBoolean

internal fun copyText(context: Context, text: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    clipboard.setPrimaryClip(ClipData.newPlainText("Breviário Maçônico", text))
    Toast.makeText(context, "Texto copiado.", Toast.LENGTH_SHORT).show()
}

internal fun clipboardText(context: Context): String {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    val clip = clipboard.primaryClip ?: return ""
    if (clip.itemCount == 0) return ""
    return clip.getItemAt(0).coerceToText(context)?.toString().orEmpty()
}

internal fun shareText(context: Context, text: String) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, text)
    }
    context.startActivity(Intent.createChooser(intent, "Compartilhar leitura"))
}

internal fun sharePdf(context: Context, items: List<BreviarioItem>, comments: Map<String, String>, premiumName: String = "") {
    exportPdf(context, "breviario-maconico", "Compartilhar PDF") {
        createPdf(it, items, comments, premiumName)
    }
}

internal fun shareLibraryPdf(context: Context, paginas: List<BibliotecaPaginaLeitura>) {
    if (paginas.isEmpty()) return
    exportPdf(context, "biblioteca-maconica-obra", "Compartilhar PDF") {
        createLibraryPdf(it, paginas)
    }
}

internal fun shareDossierPdf(context: Context, tema: String, resultados: List<BibliotecaBuscaResultado>, analise: String = "", escopo: String = "Toda a biblioteca", nome: String = "") {
    exportPdf(context, "biblioteca-maconica-dossie", "Compartilhar PDF") {
        createDossierPdf(it, tema, resultados, analise, escopo, nome)
    }
}

internal fun shareHighlightsPdf(context: Context, item: BreviarioItem, highlights: List<TextHighlight>) {
    if (highlights.isEmpty()) {
        Toast.makeText(context, "Nenhum marcador salvo para exportar.", Toast.LENGTH_SHORT).show()
        return
    }
    exportPdf(context, "biblioteca-maconica-marcadores", "Compartilhar marcadores") {
        createHighlightsPdf(it, item, highlights)
    }
}

private val exportInProgress = AtomicBoolean(false)

private fun exportPdf(context: Context, name: String, title: String, render: (File) -> Unit) {
    val owner = context as? LifecycleOwner ?: return
    if (!exportInProgress.compareAndSet(false, true)) {
        Toast.makeText(context, "Aguarde a geração do PDF atual.", Toast.LENGTH_SHORT).show()
        return
    }
    Toast.makeText(context, "Preparando PDF...", Toast.LENGTH_SHORT).show()
    val job = owner.lifecycleScope.launch {
        var file: File? = null
        var shared = false
        try {
            withContext(Dispatchers.IO) {
                file = File.createTempFile("$name-", ".pdf", context.cacheDir)
                render(requireNotNull(file))
            }
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", requireNotNull(file))
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(Intent.createChooser(intent, title))
            shared = true
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: Exception) {
            Toast.makeText(context, "Não foi possível gerar ou compartilhar o PDF. Tente novamente.", Toast.LENGTH_LONG).show()
        } finally {
            if (!shared) file?.delete()
        }
    }
    job.invokeOnCompletion { exportInProgress.set(false) }
}

private fun exportComment(item: BreviarioItem, comments: Map<String, String>): String =
    comments[item.chavePersistencia].orEmpty().ifBlank {
        if (item.obraId == com.renatocamargo.breviariomaconico.data.ObraId.BREVIARIO_SECULO_XXI) comments[item.data].orEmpty() else ""
    }.trim()

internal fun createPdf(file: File, items: List<BreviarioItem>, comments: Map<String, String>, premiumName: String = "") {
    require(items.isNotEmpty()) { "Selecione ao menos uma leitura." }
    val document = PdfDocument()
    val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 20f; isFakeBoldText = true }
    val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = PdfPremiumStyle.bodySize }
    val footPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 10.5f; color = android.graphics.Color.DKGRAY }
    val goldPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = PdfPremiumStyle.gold; strokeWidth = 0.8f }
    val writer = PdfTextWriter(document, 595, 842)
    try {
        writer.premiumCover(items, items.any { exportComment(it, comments).isNotBlank() }, premiumName)
        if (items.size > 1) {
            writer.beginContent("Índice")
            writer.drawTextLine("Índice da exportação", 54f, titlePaint)
            writer.addSpace(18f)
            items.forEach { item ->
                writer.drawTextLine("${TextoFormatter.dataPorExtenso(item.data)}  ${item.titulo}", 54f, bodyPaint)
                writer.drawTextLine("Página original: ${item.pagina}", 54f, footPaint)
                writer.addSpace(4f)
            }
        }
        items.forEach { item ->
            val date = TextoFormatter.dataPorExtenso(item.data)
            writer.beginContent(date)
            writer.drawCentered(date, Paint(titlePaint).apply { textSize = 16f; color = PdfPremiumStyle.darkGold })
            writer.drawCentered(item.titulo, titlePaint)
            writer.decorativeSeparator()
            writer.drawTextLine("Página original: ${item.pagina}", 54f, Paint(footPaint).apply { textSize = 9f })
            writer.addSpace(20f)
            writer.drawWrappedJustified(TextoFormatter.sobrescrito(item.texto, item.rodape), 54f, 487f, PdfPremiumStyle.lineHeight, bodyPaint)
            if (item.rodape.isNotBlank()) {
                writer.reserveSpace(94f)
                writer.addSpace(26f)
                writer.drawDivider(54f, 541f, goldPaint)
                writer.drawTextLine("Notas de rodapé", 54f, Paint(footPaint).apply { isFakeBoldText = true })
                writer.drawNotes(item.rodape, 54f, 487f, 19.5f, footPaint)
            }
            val comment = exportComment(item, comments)
            if (comment.isNotBlank()) {
                writer.beginContent("$date - Comentário")
                writer.addSpace(14f)
                writer.drawTextLine("Comentário pessoal", 54f, Paint(titlePaint).apply { textSize = 13f })
                writer.addSpace(6f)
                writer.drawWrappedJustified(TextoFormatter.sobrescrito(comment, item.rodape), 54f, 487f, PdfPremiumStyle.lineHeight, bodyPaint)
            }
        }
        writer.finishCurrentPage()
        file.outputStream().use { document.writeTo(it) }
    } finally {
        try { writer.finishCurrentPage() } finally { document.close() }
    }
}

internal fun createLibraryPdf(file: File, paginas: List<BibliotecaPaginaLeitura>) {
    val document = PdfDocument()
    val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 20f; isFakeBoldText = true }
    val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 12f }
    val footPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 10f }
    val pageWidth = 595
    val pageHeight = 842
    val writer = PdfTextWriter(document, pageWidth, pageHeight)
    try {

    val primeira = paginas.first()
    writer.beginPage()
    writer.drawTextLine(primeira.tituloObra, 54f, titlePaint)
    primeira.autor?.let { writer.drawTextLine(it, 54f, bodyPaint) }
    writer.drawTextLine("${paginas.size} página(s) exportada(s)", 54f, bodyPaint)
    writer.finishCurrentPage()

    paginas.forEach { pagina ->
        writer.beginPage()
        writer.drawTextLine("Página ${pagina.pagina}", 46f, titlePaint)
        writer.drawTextLine(pagina.titulo, 46f, titlePaint)
        writer.addSpace(8f)
        writer.drawWrappedJustified(TextoFormatter.sobrescrito(pagina.texto, pagina.rodape), 46f, pageWidth - 92f, 18f, bodyPaint)
        if (pagina.rodape.isNotBlank()) {
            writer.addSpace(12f)
            writer.drawDivider(46f, pageWidth - 46f, footPaint)
            writer.drawTextLine("Notas de rodapé", 46f, footPaint)
            writer.drawNotes(pagina.rodape, 46f, pageWidth - 92f, 14f, footPaint)
        }
        writer.finishCurrentPage()
    }

    file.outputStream().use { document.writeTo(it) }
    } finally {
        try { writer.finishCurrentPage() } finally { document.close() }
    }
}

internal fun createTextPdf(file: File, title: String, text: String) {
    val document = PdfDocument()
    val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 20f; isFakeBoldText = true }
    val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 12f }
    val pageWidth = 595
    val pageHeight = 842
    val writer = PdfTextWriter(document, pageWidth, pageHeight)
    try {
    writer.beginPage()
    writer.drawTextLine(title, 46f, titlePaint)
    writer.addSpace(8f)
    writer.drawStructuredText(text, 46f, pageWidth - 92f, 18f, bodyPaint)
    writer.finishCurrentPage()
    file.outputStream().use { document.writeTo(it) }
    } finally {
        try { writer.finishCurrentPage() } finally { document.close() }
    }
}

internal fun createHighlightsPdf(file: File, item: BreviarioItem, highlights: List<TextHighlight>) {
    val document = PdfDocument()
    val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 20f; isFakeBoldText = true }
    val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 12f }
    val footPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 10f }
    val pageWidth = 595
    val pageHeight = 842
    val writer = PdfTextWriter(document, pageWidth, pageHeight)
    try {

    writer.beginPage()
    writer.drawTextLine("Marcadores", 46f, titlePaint)
    writer.drawTextLine(TextoFormatter.dataPorExtenso(item.data), 46f, bodyPaint)
    writer.drawTextLine(item.titulo, 46f, bodyPaint)
    writer.addSpace(12f)
    highlights.sortedBy { it.createdAt }.forEachIndexed { index, highlight ->
        writer.drawTextLine("Marcador ${index + 1}", 46f, footPaint)
        writer.drawWrapped(TextoFormatter.sobrescrito(highlight.text, item.rodape), 46f, pageWidth - 92f, 18f, bodyPaint)
        writer.addSpace(8f)
    }
    writer.finishCurrentPage()
    file.outputStream().use { document.writeTo(it) }
    } finally {
        try { writer.finishCurrentPage() } finally { document.close() }
    }
}

internal class PdfTextWriter(
    private val document: PdfDocument,
    private val pageWidth: Int,
    private val pageHeight: Int,
    private val heading: String = "Breviário Maçônico"
) {
    private var pageNumber = 1
    private var page: PdfDocument.Page? = null
    private var y = 58f
    private val bottom get() = pageHeight - if (reference == null) 54f else 74f
    private var background: Int? = null
    private var reference: String? = null
    private var contentPage = 0
    private val canvas get() = requireNotNull(page).canvas

    fun beginPage(backgroundColor: Int? = null) {
        finishCurrentPage()
        background = backgroundColor
        page = document.startPage(PdfDocument.PageInfo.Builder(pageWidth, pageHeight, pageNumber++).create())
        y = 58f
        background?.let { canvas.drawColor(it) }
        reference?.let {
            PdfPremiumStyle.content(canvas, it, ++contentPage, heading)
            y = 88f
        }
    }

    fun premiumCover(items: List<BreviarioItem>, comments: Boolean, name: String) {
        reference = null
        beginPage()
        PdfPremiumStyle.cover(canvas, items, comments, name)
        finishCurrentPage()
    }

    fun beginContent(title: String) {
        reference = title
        beginPage()
    }

    fun dossierCover(topic: String, sourceCount: Int, scope: String, name: String) {
        reference = null
        beginPage()
        PdfPremiumStyle.dossierCover(canvas, topic, sourceCount, scope, name)
        finishCurrentPage()
    }

    fun decorativeSeparator() {
        ensureSpace(20f)
        PdfPremiumStyle.separator(canvas, y + 6f, 253f)
        y += 20f
    }

    fun finishCurrentPage() {
        page?.let { document.finishPage(it) }
        page = null
    }

    fun addSpace(space: Float) { y += space }

    fun reserveSpace(space: Float) = ensureSpace(space)

    fun drawTextLine(text: String, x: Float, paint: Paint, lineHeight: Float = paint.textSize + 9f) {
        drawLayout(text, x, pageWidth - x * 2, lineHeight, paint)
    }

    fun drawDivider(x1: Float, x2: Float, paint: Paint) {
        ensureSpace(18f)
        canvas.drawLine(x1, y, x2, y, paint)
        y += 16f
    }

    fun drawCentered(text: String, paint: Paint) {
        drawLayout(text, 54f, pageWidth - 108f, paint.textSize + 12f, paint,
            alignment = android.text.Layout.Alignment.ALIGN_CENTER)
    }

    fun drawAcaciaOrnament(paint: Paint) {
        ensureSpace(150f)
        val center = pageWidth / 2f
        val stemPaint = Paint(paint).apply { style = Paint.Style.STROKE; strokeWidth = 3f }
        canvas.drawLine(center - 90f, y + 105f, center, y, stemPaint)
        canvas.drawLine(center + 90f, y + 105f, center, y, stemPaint)
        repeat(6) { index ->
            val offset = index * 17f
            canvas.save()
            canvas.rotate(-38f, center - 18f - offset, y + 24f + offset)
            canvas.drawOval(center - 34f - offset, y + 13f + offset, center - 4f - offset, y + 31f + offset, paint)
            canvas.restore()
            canvas.save()
            canvas.rotate(38f, center + 18f + offset, y + 24f + offset)
            canvas.drawOval(center + 4f + offset, y + 13f + offset, center + 34f + offset, y + 31f + offset, paint)
            canvas.restore()
        }
        y += 140f
    }


    fun drawWrapped(text: String, x: Float, width: Float, lineHeight: Float, paint: Paint) =
        drawParagraphs(text, x, width, lineHeight, paint, false)

    fun drawWrappedJustified(text: String, x: Float, width: Float, lineHeight: Float, paint: Paint) =
        drawParagraphs(text, x, width, lineHeight, paint, true)

    fun drawNotes(text: String, x: Float, width: Float, lineHeight: Float, paint: Paint) {
        text.lineSequence().filter { it.isNotBlank() }.forEach {
            drawLayout(it, x, width, lineHeight, paint)
        }
    }

    fun drawStructuredText(text: String, x: Float, width: Float, lineHeight: Float, paint: Paint) {
        // Generated headings and notes already have meaningful line breaks; do not join them as OCR wraps.
        text.lineSequence().forEach { line ->
            if (line.isBlank()) addSpace(lineHeight)
            else drawLayout(line, x, width, lineHeight, paint, justified = true)
        }
    }

    private fun drawParagraphs(text: String, x: Float, width: Float, lineHeight: Float, paint: Paint, justified: Boolean) {
        text.trim().split(Regex("\\n{2,}")).filter { it.isNotBlank() }.forEachIndexed { index, paragraph ->
            if (index > 0) y += lineHeight
            drawLayout(paragraph.replace("\n", " "), x, width, lineHeight, paint, justified)
        }
    }

    private fun drawLayout(text: String, x: Float, width: Float, lineHeight: Float, paint: Paint,
        justified: Boolean = false, alignment: android.text.Layout.Alignment = android.text.Layout.Alignment.ALIGN_NORMAL) {
        if (text.isBlank()) return
        val font = android.text.TextPaint(paint)
        val nativeLine = font.fontMetrics.descent - font.fontMetrics.ascent
        val layout = android.text.StaticLayout.Builder.obtain(text, 0, text.length, font, width.toInt())
            .setAlignment(alignment).setIncludePad(false)
            .setLineSpacing((lineHeight - nativeLine).coerceAtLeast(0f), 1f)
            .setJustificationMode(if (justified) android.graphics.text.LineBreaker.JUSTIFICATION_MODE_INTER_WORD else android.graphics.text.LineBreaker.JUSTIFICATION_MODE_NONE)
            .build()
        // Native line breaking preserves long words, Unicode and alignment at page boundaries.
        for (line in 0 until layout.lineCount) {
            val top = layout.getLineTop(line)
            val height = maxOf(lineHeight, (layout.getLineBottom(line) - top).toFloat())
            ensureSpace(height)
            canvas.save()
            canvas.translate(x, y)
            canvas.clipRect(0f, 0f, width, height)
            canvas.translate(0f, -top.toFloat())
            layout.draw(canvas)
            canvas.restore()
            y += height
        }
    }

    private fun ensureSpace(needed: Float) {
        if (page == null) beginPage(background)
        if (y + needed > bottom) beginPage(background)
    }
}

internal fun scheduleDailyNotification(context: Context, settings: ReaderSettings) {
    NotificationScheduler.schedule(context, settings)
}

internal fun sendTestNotification(context: Context): Boolean {
    val manager = androidx.core.app.NotificationManagerCompat.from(context)
    if (!manager.areNotificationsEnabled()) return false
    if (android.os.Build.VERSION.SDK_INT >= 33 &&
        androidx.core.content.ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED
    ) return false
    if (manager.getNotificationChannel("breviario_daily")?.importance == android.app.NotificationManager.IMPORTANCE_NONE) return false
    val intent = Intent(context, NotificationReceiver::class.java)
    val pendingIntent = PendingIntent.getBroadcast(context, 2027, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    alarmManager.set(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + 5000, pendingIntent)
    return true
}
