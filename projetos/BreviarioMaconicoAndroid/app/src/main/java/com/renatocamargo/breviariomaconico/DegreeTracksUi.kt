package com.renatocamargo.breviariomaconico

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.renatocamargo.breviariomaconico.data.DegreeTracks
import com.renatocamargo.breviariomaconico.data.SavedDossierStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Study tracks by degree with progress, milestones, the next step and the suggested works. Same as iOS `TrilhasGrauView`. */
@Composable
internal fun DegreeTracksScreen(
    colors: Palette,
    titles: () -> Map<String, String>,
    onStudy: (String) -> Unit,
    onOpenWork: (String) -> Unit
) {
    val context = LocalContext.current
    val config = remember { DegreeTracks.loadConfig(context) }
    var marked by remember { mutableStateOf(DegreeTracks.marked(context)) }
    var open by remember { mutableStateOf(emptySet<String>()) }
    val saved = remember { SavedDossierStore(context).all().map { it.tema } }
    val names by produceState(emptyMap<String, String>()) { value = withContext(Dispatchers.IO) { titles() } }
    val progress = DegreeTracks.progress(config, saved, marked)

    LazyColumn(Modifier.fillMaxSize().padding(18.dp).testTag("tracks.list"), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Text(config.label("titulo"), color = colors.accent, fontSize = 28.sp, fontWeight = FontWeight.Bold, modifier = Modifier.semantics { heading() })
            Text(config.label("descricao"), color = colors.secondary)
        }
        items(config.degrees.zip(progress), key = { it.first.id }) { (degree, state) ->
            val values = mapOf("feitas" to "${state.done.size}", "total" to "${state.total}", "percentual" to "${state.percent}")
            PremiumCard(colors) {
                Column(Modifier.testTag("trilha.${degree.id}"), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(degree.name, color = colors.text, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.semantics { heading() })
                    Text(degree.description, color = colors.secondary)
                    LinearProgressIndicator(progress = { if (state.total == 0) 0f else state.done.size.toFloat() / state.total },
                        color = colors.accent, modifier = Modifier.fillMaxWidth().semantics { stateDescription = config.label("progresso", values) })
                    Text(config.label("progresso", values), color = colors.text, modifier = Modifier.testTag("trilha.${degree.id}.progresso"))
                    if (state.milestone.isNotEmpty()) {
                        Text(state.milestone, color = colors.accent, fontWeight = FontWeight.SemiBold, modifier = Modifier.testTag("trilha.${degree.id}.marco"))
                    }
                    Text(degree.steps.firstOrNull { it.id == state.next }?.let { config.label("proxima", mapOf("tema" to it.topic)) }
                        ?: config.label("concluida"), color = colors.secondary)
                    // The next step is shown; the whole track opens on request.
                    val expanded = degree.id in open
                    degree.steps.filter { expanded || it.id == state.next }.forEach { step ->
                        val done = step.id in state.done
                        Column(Modifier.padding(vertical = 4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text((if (done) "✓ " else "○ ") + step.topic, color = if (done) colors.accent else colors.text, fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.semantics { stateDescription = if (done) config.label("estudada") else "" })
                            Text(step.description, color = colors.secondary, fontSize = 13.sp)
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedButton(onClick = { onStudy(step.topic) }, modifier = Modifier.testTag("trilha.etapa.${step.id}.estudar")
                                    .semantics { contentDescription = "${config.label("estudar")}: ${step.topic}" }) {
                                    Text(config.label("estudar"), color = colors.text)
                                }
                                TextButton(onClick = { DegreeTracks.toggle(context, step.id); marked = DegreeTracks.marked(context) },
                                    modifier = Modifier.testTag("trilha.etapa.${step.id}.marcar")
                                        .semantics { contentDescription = "${config.label(if (step.id in marked) "desmarcar" else "marcar")}: ${step.topic}" }) {
                                    Text(config.label(if (step.id in marked) "desmarcar" else "marcar"))
                                }
                            }
                        }
                    }
                    TextButton(onClick = { open = if (expanded) open - degree.id else open + degree.id },
                        modifier = Modifier.testTag("trilha.${degree.id}.etapas")) {
                        Text(if (expanded) config.label("ocultarEtapas") else config.label("verEtapas", mapOf("n" to "${degree.steps.size}")), color = colors.accent)
                    }
                    Text(config.label("obras"), color = colors.text, fontWeight = FontWeight.Bold)
                    if (degree.suggestedWorks.isEmpty()) Text(config.label("semObras"), color = colors.secondary, fontSize = 14.sp)
                    degree.suggestedWorks.forEach { work ->
                        TextButton(onClick = { onOpenWork(work) }) { Text(names[work] ?: work, color = colors.accent) }
                    }
                }
            }
        }
    }
}
