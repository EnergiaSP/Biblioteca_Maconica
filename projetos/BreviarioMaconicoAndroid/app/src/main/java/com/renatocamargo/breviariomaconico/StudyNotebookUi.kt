package com.renatocamargo.breviariomaconico

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.renatocamargo.breviariomaconico.data.StudyNotebook
import org.json.JSONObject
import java.time.LocalDate

/**
 * Study notebook: what is kept on this device, export and import of the portable file, and the sync
 * options. Same sections and messages as iOS `CadernoEstudoView`.
 */
@Composable
internal fun StudyNotebookScreen(colors: Palette) {
    val context = LocalContext.current
    val config = remember { StudyNotebook.loadConfig(context) }
    var refresh by remember { mutableIntStateOf(0) }
    val summary = remember(refresh) { StudyNotebook.collect(context) }
    var message by remember { mutableStateOf("") }
    fun counts(notebook: StudyNotebook.Notebook) = mapOf(
        "leituras" to "${notebook.readings.size}", "dossies" to "${notebook.dossiers.size}", "cartoes" to "${notebook.cards.size}")

    val exporter = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        val notebook = StudyNotebook.collect(context)
        message = runCatching {
            context.contentResolver.openOutputStream(uri)?.use { it.write(StudyNotebook.toJson(notebook, config).toString(2).toByteArray()) }
            config.label("exportado", counts(notebook))
        }.getOrElse { "Não foi possível exportar. ${it.localizedMessage.orEmpty()}" }
    }
    val importer = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        val json = runCatching {
            context.contentResolver.openInputStream(uri)?.use { JSONObject(it.bufferedReader().readText()) }
        }.getOrNull()
        if (json == null || !StudyNotebook.valid(json, config)) {
            message = config.label("invalido")
            return@rememberLauncherForActivityResult
        }
        val merged = StudyNotebook.merge(StudyNotebook.collect(context), StudyNotebook.fromJson(json), LocalDate.now().toString(), config)
        StudyNotebook.apply(context, merged)
        refresh++
        message = config.label("importado", counts(merged))
    }

    LazyColumn(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Text(config.label("titulo"), color = colors.accent, fontSize = 28.sp, fontWeight = FontWeight.Bold)
            Text("Neste aparelho: ${summary.readings.size} leitura(s) com anotações, ${summary.dossiers.size} dossiê(s) salvo(s) " +
                "e ${summary.cards.size} cartão(ões) de revisão.", color = colors.secondary, modifier = Modifier.testTag("notebook.summary"))
        }
        item {
            PremiumCard(colors) {
                Text("Levar para outro aparelho", color = colors.text, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Text("O arquivo abre no Android, no iPhone e no iPad. Ao importar, nada do que já está no aparelho é apagado: " +
                    "anotações diferentes ficam as duas.", color = colors.secondary)
                Button(colors = libraryActionColors(colors), modifier = Modifier.testTag("notebook.export"),
                    onClick = { exporter.launch("caderno-biblioteca-maconica-${LocalDate.now()}.json") }) { Text(config.label("exportar")) }
                OutlinedButton(modifier = Modifier.testTag("notebook.import"),
                    onClick = { importer.launch(arrayOf("application/json", "text/plain", "application/octet-stream")) }) {
                    Text(config.label("importar"), color = colors.text)
                }
            }
        }
        if (message.isNotEmpty()) {
            item { Text(message, color = colors.text, modifier = Modifier.testTag("notebook.message")) }
        }
    }
}
