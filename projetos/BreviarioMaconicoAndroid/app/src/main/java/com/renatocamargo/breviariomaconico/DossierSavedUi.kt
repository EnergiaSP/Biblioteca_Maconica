package com.renatocamargo.breviariomaconico

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.renatocamargo.breviariomaconico.data.BibliotecaArea
import com.renatocamargo.breviariomaconico.data.DossierAnalysis
import com.renatocamargo.breviariomaconico.data.SavedDossier
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

private val dateFormat = DateTimeFormatter.ofPattern("dd/MM/yyyy")

/** Same labels as iOS. */
internal fun reviewStatusLabel(status: SavedDossier.Status): String = when (status) {
    SavedDossier.Status.FEITA -> "Feita"
    SavedDossier.Status.ATRASADA -> "Atrasada"
    SavedDossier.Status.HOJE -> "Hoje"
    SavedDossier.Status.PROXIMA -> "Próxima"
}

/** One line describing where the saved dossier stands, identical to iOS. */
internal fun savedDossierProgress(saved: SavedDossier, steps: List<DossierAnalysis.ReviewStep>, today: LocalDate): String {
    val next = saved.nextReview(steps, today) ?: return "Todas as revisões concluídas."
    val date = next.date.format(dateFormat)
    return when (next.status) {
        SavedDossier.Status.ATRASADA -> "Revisão atrasada desde $date: ${next.task}"
        SavedDossier.Status.HOJE -> "Revisão de hoje: ${next.task}"
        else -> "Próxima revisão em $date: ${next.task}"
    }
}

/** Same wording as iOS. */
internal fun savedDossierReminderNote(saved: SavedDossier, reminder: DossierAnalysis.ReminderTime): String =
    "Salvo em ${saved.createdDate.format(dateFormat)}. Lembrete às ${"%02d:%02d".format(reminder.hour, reminder.minute)} no dia de cada revisão pendente."

internal fun savedDossierScope(saved: SavedDossier): String = listOfNotNull(
    BibliotecaArea.entries.firstOrNull { it.raw == saved.area }?.titulo ?: "Toda a biblioteca",
    saved.obraId?.let { "Obra selecionada" },
    listOf("Autor" to saved.autor, "Assunto" to saved.assunto)
        .mapNotNull { (label, value) -> value.trim().takeIf { it.isNotEmpty() }?.let { "$label: $it" } }
        .joinToString(" • ").takeIf { it.isNotEmpty() }
).joinToString(" • ")

@Composable
internal fun SavedDossierReviewsCard(
    colors: Palette,
    saved: SavedDossier,
    steps: List<DossierAnalysis.ReviewStep>,
    reminder: DossierAnalysis.ReminderTime,
    onToggle: (Int) -> Unit
) {
    PremiumCard(colors, Modifier.testTag("dossier.reviews")) {
        Text("Revisões deste dossiê", color = colors.text, fontWeight = FontWeight.Bold, fontSize = 20.sp)
        Text(savedDossierReminderNote(saved, reminder), color = colors.secondary, fontSize = 13.sp)
        saved.reviews(steps, LocalDate.now()).forEach { review ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(
                    checked = review.status == SavedDossier.Status.FEITA,
                    onCheckedChange = { onToggle(review.days) },
                    colors = CheckboxDefaults.colors(checkedColor = colors.accent, uncheckedColor = colors.secondary),
                    modifier = Modifier.testTag("dossier.review.${review.days}")
                )
                Column(Modifier.weight(1f)) {
                    Text("${review.date.format(dateFormat)} • ${reviewStatusLabel(review.status)}",
                        color = if (review.status == SavedDossier.Status.ATRASADA) colors.accent else colors.text,
                        fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                    Text(review.task, color = colors.secondary, fontSize = 14.sp)
                }
            }
        }
    }
}

@Composable
internal fun SavedDossiersCard(
    colors: Palette,
    saved: List<SavedDossier>,
    steps: List<DossierAnalysis.ReviewStep>,
    enabled: Boolean,
    onOpen: (SavedDossier) -> Unit,
    onDelete: (SavedDossier) -> Unit
) {
    PremiumCard(colors, Modifier.testTag("dossier.saved")) {
        Text("Dossiês salvos", color = colors.text, fontWeight = FontWeight.Bold, fontSize = 20.sp)
        Text("Ao abrir, o dossiê é refeito com o acervo instalado.", color = colors.secondary, fontSize = 13.sp)
        val today = LocalDate.now()
        saved.forEach { item ->
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(item.tema, color = colors.text, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                Text(savedDossierScope(item), color = colors.accent, fontSize = 13.sp)
                Text(savedDossierProgress(item, steps, today), color = colors.secondary, fontSize = 13.sp)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(enabled = enabled, colors = libraryActionColors(colors), onClick = { onOpen(item) },
                        modifier = Modifier.testTag("dossier.saved.open")) { Text("Abrir") }
                    TextButton(enabled = enabled, onClick = { onDelete(item) }, modifier = Modifier.testTag("dossier.saved.delete")) {
                        Text("Excluir", color = colors.text)
                    }
                }
            }
        }
    }
}

/**
 * The topic in the center and its associated terms around it, clockwise from the top, as on iOS.
 * Everything drawn comes from the analysis of the sources.
 */
@Composable
internal fun DossierConceptMap(colors: Palette, topic: String, terms: List<DossierAnalysis.RelatedTerm>) {
    val shown = terms.take(MAP_TERMS)
    if (shown.isEmpty()) return
    val measurer = rememberTextMeasurer()
    val description = "Mapa: $topic ligado a " + shown.joinToString(", ") { "${it.form} (${it.occurrences})" }
    PremiumCard(colors, Modifier.testTag("dossier.map")) {
        Text("Mapa do tema", color = colors.text, fontWeight = FontWeight.Bold, fontSize = 20.sp)
        Text("Termos que mais aparecem perto do tema nas fontes; o número é de ocorrências.", color = colors.secondary, fontSize = 13.sp)
        Canvas(Modifier.fillMaxWidth().height(320.dp).semantics { contentDescription = description }) {
            val center = Offset(size.width / 2, size.height / 2)
            val radius = min(size.width, size.height) * 0.36f
            val labelWidth = (size.width * 0.3f).toInt()
            val points = shown.indices.map { i ->
                val angle = Math.toRadians(-90.0 + 360.0 * i / shown.size)
                Offset(center.x + radius * cos(angle).toFloat(), center.y + radius * sin(angle).toFloat())
            }
            points.forEach { drawLine(colors.secondary.copy(alpha = 0.6f), center, it, strokeWidth = 2.dp.toPx()) }
            drawCircle(colors.accentSurface, radius = 34.dp.toPx(), center = center)
            drawCircle(colors.accent, radius = 34.dp.toPx(), center = center, style = Stroke(2.dp.toPx()))
            val topicLayout = measurer.measure(topic, TextStyle(color = colors.onAccent, fontSize = 12.sp, fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center), constraints = Constraints(maxWidth = 64.dp.roundToPx()), maxLines = 3)
            drawText(topicLayout, topLeft = Offset(center.x - topicLayout.size.width / 2, center.y - topicLayout.size.height / 2))
            shown.zip(points).forEach { (term, point) ->
                drawCircle(colors.accent, radius = 6.dp.toPx(), center = point)
                val layout = measurer.measure("${term.form} (${term.occurrences})", TextStyle(color = colors.text, fontSize = 12.sp,
                    textAlign = TextAlign.Center), constraints = Constraints(maxWidth = labelWidth), maxLines = 2)
                val below = point.y >= center.y
                val y = if (below) point.y + 8.dp.toPx() else point.y - 8.dp.toPx() - layout.size.height
                val x = (point.x - layout.size.width / 2).coerceIn(0f, size.width - layout.size.width)
                drawText(layout, topLeft = Offset(x, y.coerceIn(0f, size.height - layout.size.height)))
            }
        }
    }
}

/** Same number of terms drawn as iOS. */
internal const val MAP_TERMS = 8
