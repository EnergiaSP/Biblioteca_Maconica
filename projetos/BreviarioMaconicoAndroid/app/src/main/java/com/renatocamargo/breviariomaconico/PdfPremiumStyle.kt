package com.renatocamargo.breviariomaconico

import android.graphics.*
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import com.renatocamargo.breviariomaconico.data.BreviarioItem
import com.renatocamargo.breviariomaconico.data.TextoFormatter
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

internal object PdfPremiumStyle {
    const val margin = 54f
    const val bodySize = 12.8f
    const val lineHeight = 22.8f
    val gold = Color.rgb(184, 140, 51)
    val darkGold = Color.rgb(107, 77, 26)
    val paper = Color.rgb(247, 242, 230)

    private fun paint(color: Int, width: Float = 1f) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        this.color = color; strokeWidth = width; strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
    }

    private fun label(canvas: Canvas, value: String, top: Float, size: Float, bold: Boolean = false,
        align: Layout.Alignment = Layout.Alignment.ALIGN_CENTER, x: Float = margin, width: Float = 487f,
        color: Int = Color.BLACK) {
        val font = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = size; this.color = color; isFakeBoldText = bold }
        val layout = StaticLayout.Builder.obtain(value, 0, value.length, font, width.toInt()).setAlignment(align)
            .setIncludePad(false).setLineSpacing(4f, 1f).build()
        canvas.save(); canvas.translate(x, top); layout.draw(canvas); canvas.restore()
    }

    fun cover(canvas: Canvas, items: List<BreviarioItem>, comments: Boolean, name: String) {
        canvas.drawColor(paper)
        canvas.drawRect(0f, 0f, 595f, 16f, paint(Color.BLACK))
        canvas.drawRect(0f, 826f, 595f, 842f, paint(Color.BLACK))
        val border = paint(gold, 2f).apply { style = Paint.Style.STROKE }
        canvas.drawRect(34f, 38f, 561f, 804f, border)
        border.strokeWidth = 0.8f; border.alpha = 140
        canvas.drawRect(44f, 48f, 551f, 794f, border)
        acacia(canvas, 297.5f, 108f, 0.95f)
        symbol(canvas, 297.5f, 190f, 128f)
        label(canvas, "Breviário Maçônico", 282f, 29f, true)
        separator(canvas, 386f, 350f)
        label(canvas, "${items.size} ${if (items.size == 1) "dia selecionado" else "dias selecionados"}", 420f, 14f, color = Color.DKGRAY)
        val dates = items.map { TextoFormatter.dataPorExtenso(it.data) }
        label(canvas, if (dates.size == 1) dates.first() else "${dates.first()} a ${dates.last()}", 446f, 14f, color = Color.DKGRAY)
        val commentLabel = if (items.size == 1) "comentário salvo" else "comentários salvos"
        label(canvas, "${if (comments) "com" else "sem"} $commentLabel", 472f, 14f, color = Color.DKGRAY)
        acacia(canvas, 297.5f, 612f, 0.72f)
        if (name.isNotBlank()) label(canvas, name.trim(), 648f, 12f, color = Color.DKGRAY)
        items.firstOrNull()?.autor?.takeIf { it.isNotBlank() }?.let { label(canvas, "Autor: $it", 684f, 12f, color = Color.DKGRAY) }
        label(canvas, "Gerado em ${LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd 'de' MMM 'de' yyyy, HH:mm", Locale("pt", "BR")))}", 724f, 11f, color = Color.DKGRAY)
    }

    fun content(canvas: Canvas, reference: String, page: Int, heading: String = "Breviário Maçônico") {
        canvas.drawColor(Color.WHITE)
        canvas.saveLayerAlpha(0f, 0f, 595f, 842f, 16)
        symbol(canvas, 297.5f, 433f, 270f)
        canvas.restore()
        label(canvas, heading, 30f, 12f, true, Layout.Alignment.ALIGN_NORMAL, width = 439f)
        symbol(canvas, 523f, 43f, 30f)
        canvas.drawLine(54f, 62f, 541f, 62f, paint(gold, 0.8f))
        canvas.drawLine(54f, 786f, 541f, 786f, paint(Color.LTGRAY, 0.6f))
        label(canvas, reference, 796f, 8.5f, align = Layout.Alignment.ALIGN_NORMAL, width = 350f, color = Color.DKGRAY)
        label(canvas, "p. $page", 796f, 8.5f, align = Layout.Alignment.ALIGN_OPPOSITE, x = 414f, width = 127f, color = Color.DKGRAY)
    }

    fun dossierCover(canvas: Canvas, topic: String, sourceCount: Int, scope: String, name: String) {
        canvas.drawColor(paper)
        canvas.drawRect(34f, 38f, 561f, 804f, paint(gold, 2f).apply { style = Paint.Style.STROKE })
        canvas.drawRect(44f, 48f, 551f, 794f, paint(gold, 0.8f).apply { style = Paint.Style.STROKE; alpha = 140 })
        canvas.saveLayerAlpha(0f, 0f, 595f, 842f, 18)
        symbol(canvas, 297.5f, 401f, 285f)
        canvas.restore()
        acacia(canvas, 297.5f, 636f, 1.05f)
        label(canvas, "Biblioteca Maçônica", 118f, 17f, true, color = darkGold)
        label(canvas, "Dossiê de Estudo", 178f, 28f, true)
        val font = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 24f; color = darkGold }
        val heading = StaticLayout.Builder.obtain(topic, 0, topic.length, font, 487)
            .setAlignment(Layout.Alignment.ALIGN_CENTER).setIncludePad(false).setLineSpacing(4f, 1f)
            .setMaxLines(3).setEllipsize(android.text.TextUtils.TruncateAt.END).build()
        canvas.save(); canvas.translate(margin, 232f); heading.draw(canvas); canvas.restore()
        label(canvas, "$scope • $sourceCount referência(s) encontrada(s)", 340f, 13f, color = Color.DKGRAY)
        if (name.isNotBlank()) label(canvas, name.trim(), 682f, 13f, color = Color.DKGRAY)
        label(canvas, LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd 'de' MMMM 'de' yyyy, HH:mm", Locale("pt", "BR"))),
            724f, 11f, color = Color.DKGRAY)
    }

    fun separator(canvas: Canvas, y: Float, width: Float) {
        val p = paint(gold, 0.8f)
        canvas.drawLine(297.5f - width / 2, y, 297.5f + width / 2, y, p)
        for (x in listOf(297.5f - width / 2, 297.5f, 297.5f + width / 2)) canvas.drawCircle(x, y, 2.5f, p)
    }

    private fun symbol(canvas: Canvas, x: Float, y: Float, size: Float) {
        canvas.save(); canvas.translate(x, y); canvas.scale(size / 128f, size / 128f)
        val compass = Path().apply { moveTo(0f, -58f); lineTo(-48f, 52f); moveTo(0f, -58f); lineTo(48f, 52f) }
        canvas.drawPath(compass, paint(gold, 8f).apply { style = Paint.Style.STROKE })
        canvas.drawPath(compass, paint(Color.BLACK, 2f).apply { style = Paint.Style.STROKE })
        canvas.drawOval(-12f, -70f, 12f, -52f, paint(gold))
        canvas.drawOval(-12f, -70f, 12f, -52f, paint(Color.BLACK, 1.2f).apply { style = Paint.Style.STROKE })
        val square = Path().apply { moveTo(-56f, 24f); lineTo(0f, 58f); lineTo(56f, 24f) }
        canvas.drawPath(square, paint(gold, 12f).apply { style = Paint.Style.STROKE })
        canvas.drawPath(square, paint(Color.BLACK, 2f).apply { style = Paint.Style.STROKE })
        canvas.drawText("G", 0f, 25f, paint(Color.BLACK).apply { textSize = 38f; isFakeBoldText = true; textAlign = Paint.Align.CENTER })
        canvas.restore()
    }

    private fun acacia(canvas: Canvas, x: Float, y: Float, scale: Float) {
        canvas.save(); canvas.translate(x, y); canvas.scale(scale, scale)
        val stem = Path().apply { moveTo(-94f, 32f); cubicTo(-44f, -30f, 44f, -30f, 94f, 32f) }
        canvas.drawPath(stem, paint(Color.rgb(90, 130, 68), 1.3f).apply { style = Paint.Style.STROKE })
        for (index in 5 downTo 0) for (side in listOf(-1, 1)) {
            leaf(canvas, side * (12f + index * 14f), 22f - index * 7f, 13f + index % 2,
                27f + index % 3, side * (-34f + index * 5f), index / 6f)
        }
        leaf(canvas, 0f, -8f, 14f, 30f, 0f, 0.15f)
        canvas.restore()
    }

    private fun leaf(canvas: Canvas, x: Float, y: Float, width: Float, height: Float, angle: Float, variation: Float) {
        canvas.save(); canvas.translate(x, y); canvas.rotate(angle)
        val path = Path().apply {
            moveTo(0f, -height / 2); cubicTo(width * 0.78f, -height * 0.3f, width * 0.72f, height * 0.28f, 0f, height / 2)
            cubicTo(-width * 0.72f, height * 0.28f, -width * 0.78f, -height * 0.3f, 0f, -height / 2); close()
        }
        canvas.save(); canvas.translate(1.4f, 1.8f); canvas.drawPath(path, paint(Color.argb(28, 0, 0, 0))); canvas.restore()
        val fill = paint(Color.GREEN).apply { shader = LinearGradient(-width * 0.65f, -height * 0.45f, width * 0.55f, height * 0.48f,
            Color.rgb(122, (173 + variation * 25).toInt(), 71), Color.rgb(46, (110 + variation * 40).toInt(), 46), Shader.TileMode.CLAMP) }
        canvas.drawPath(path, fill)
        canvas.drawPath(path, paint(Color.argb(140, 28, 71, 31), 0.45f).apply { style = Paint.Style.STROKE })
        canvas.drawLine(0f, -height / 2 + 3, 0f, height / 2 - 3, paint(Color.argb(148, 224, 245, 148), 0.75f))
        canvas.restore()
    }
}
