package com.renatocamargo.breviariomaconico

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.renatocamargo.breviariomaconico.data.ActiveReview
import com.renatocamargo.breviariomaconico.data.ReviewCardStore
import java.time.LocalDate

/** Entry of the Dossier screen: cards due today, as on iOS. [refresh] changes when cards change. */
@Composable
internal fun ActiveReviewSummary(
    colors: Palette, store: ReviewCardStore, config: ActiveReview.Config, refresh: Int, onChanged: () -> Unit
) {
    val today = LocalDate.now().toString()
    val total = remember(refresh) { store.all().size }
    val due = remember(refresh) { store.session(today, config).size }
    var reviewing by remember { mutableStateOf(false) }
    PremiumCard(colors) {
        Text(config.label("titulo"), color = colors.text, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Text(if (total == 0) config.label("semCartoes") else config.label("paraHoje", mapOf("n" to "$due")),
            color = colors.secondary, modifier = Modifier.testTag("review.summary"))
        if (due > 0) {
            Button(colors = libraryActionColors(colors), onClick = { reviewing = true }, modifier = Modifier.testTag("review.start")) {
                Text("Revisar agora")
            }
        }
    }
    if (reviewing) ActiveReviewSession(colors, store, config) { reviewing = false; onChanged() }
}

/**
 * Review session: front, then the answer with its source and the grade; cloze cards can be answered as
 * multiple choice. Same steps and labels as iOS `RevisaoAtivaSessaoView`.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun ActiveReviewSession(colors: Palette, store: ReviewCardStore, config: ActiveReview.Config, onClose: () -> Unit) {
    val today = remember { LocalDate.now().toString() }
    val queue = remember { store.session(today, config) }
    var index by remember { mutableIntStateOf(0) }
    var showingAnswer by remember { mutableStateOf(false) }
    var quiz by remember { mutableStateOf(false) }
    var chosen by remember { mutableStateOf<String?>(null) }
    fun grade(grade: ActiveReview.Grade) {
        store.answer(queue[index].card.id, grade, today, config)
        index++
        showingAnswer = false
        chosen = null
        quiz = false
    }
    AlertDialog(
        onDismissRequest = onClose,
        title = { Text(config.label("titulo")) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (index >= queue.size) {
                    Text(config.label("concluida"), modifier = Modifier.testTag("review.done"))
                    return@Column
                }
                val entry = queue[index]
                val card = entry.card
                Text("${index + 1} de ${queue.size} • ${entry.topic}", color = colors.secondary, fontSize = 13.sp)
                if (card.kind == "lacuna") Text(config.label("lacuna"), color = colors.secondary)
                Text(card.front, fontSize = 18.sp, modifier = Modifier.testTag("review.front"))
                if (card.options.isNotEmpty() && !showingAnswer) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Switch(checked = quiz, onCheckedChange = { quiz = it }, modifier = Modifier.testTag("review.quiz"))
                        Text(config.label("quiz"))
                    }
                }
                if (quiz && card.options.isNotEmpty()) {
                    card.options.forEach { option ->
                        OutlinedButton(
                            enabled = chosen == null || chosen == option,
                            onClick = { if (chosen == null) { chosen = option; showingAnswer = true } },
                            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
                        ) { Text(option, modifier = Modifier.fillMaxWidth()) }
                    }
                } else if (!showingAnswer) {
                    Button(colors = libraryActionColors(colors), onClick = { showingAnswer = true }, modifier = Modifier.testTag("review.show")) {
                        Text(config.label("mostrarResposta"))
                    }
                }
                if (showingAnswer) {
                    val picked = chosen
                    PremiumCard(colors) {
                        if (picked != null) {
                            Text(if (picked == card.back) config.label("certa") else config.label("errada", mapOf("resposta" to card.back)),
                                fontWeight = FontWeight.Bold)
                        } else {
                            Text(card.back, modifier = Modifier.testTag("review.back"))
                        }
                        Text(card.source, color = colors.secondary, fontSize = 13.sp)
                    }
                    if (picked != null) {
                        Button(colors = libraryActionColors(colors), modifier = Modifier.testTag("review.next"),
                            onClick = { grade(if (picked == card.back) ActiveReview.Grade.RIGHT else ActiveReview.Grade.WRONG) }) {
                            Text("Próximo")
                        }
                    } else {
                        // Side by side when they fit; they wrap at large text sizes.
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            ActiveReview.Grade.entries.forEach { option ->
                                Button(colors = libraryActionColors(colors), onClick = { grade(option) },
                                    modifier = Modifier.heightIn(min = 48.dp).testTag("review.grade.${option.id}")) {
                                    Text(config.label(option.id))
                                }
                            }
                        }
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onClose) { Text("Fechar") } }
    )
}
