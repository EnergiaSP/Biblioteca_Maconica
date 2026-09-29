package com.renatocamargo.breviariomaconico

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.result.IntentSenderRequest
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.material3.RadioButton
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.semantics.Role
import com.renatocamargo.breviariomaconico.data.GoogleDriveNotebook
import com.renatocamargo.breviariomaconico.data.NotebookSync
import com.renatocamargo.breviariomaconico.data.OwnAccountNotebook
import kotlinx.coroutines.launch
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

    val scope = rememberCoroutineScope()
    var option by remember { mutableStateOf(NotebookSync.chosen(context)) }
    var syncing by remember { mutableStateOf(false) }
    var lastSync by remember { mutableStateOf(NotebookSync.lastSync(context)) }
    // Options offered on this device: Google Drive here, iCloud on iPhone and iPad; the own account when published.
    val options = listOf(NotebookSync.Option.NONE, NotebookSync.Option.GOOGLE) +
        (if (OwnAccountNotebook.provider(context) == null) emptyList() else listOf(NotebookSync.Option.OWN_ACCOUNT))
    fun optionName(value: NotebookSync.Option) = when (value) {
        NotebookSync.Option.NONE -> config.label("opcaoNenhuma")
        NotebookSync.Option.GOOGLE -> config.label("opcaoGoogle")
        NotebookSync.Option.OWN_ACCOUNT -> config.label("opcaoContaPropria")
    }
    lateinit var syncNow: () -> Unit
    val consent = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { result ->
        if (result.resultCode == android.app.Activity.RESULT_OK) syncNow() else message = config.label("semGoogle")
    }
    syncNow = {
        val provider = NotebookSync.provider(context, option)
        if (provider != null && !syncing) {
            syncing = true
            scope.launch {
                try {
                    val merged = NotebookSync.sync(context, provider, config)
                    lastSync = NotebookSync.lastSync(context)
                    refresh++
                    message = config.label("importado", counts(merged))
                } catch (consentNeeded: GoogleDriveNotebook.NeedsConsent) {
                    consent.launch(IntentSenderRequest.Builder(consentNeeded.intent.intentSender).build())
                } catch (error: Exception) {
                    message = error.localizedMessage.orEmpty()
                } finally {
                    syncing = false
                }
            }
        }
    }

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
        item(key = "notebook.sync") {
            PremiumCard(colors) {
                Text(config.label("sincronizacao"), color = colors.text, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Text(config.label("descricaoSincronizacao"), color = colors.secondary)
                Column(Modifier.selectableGroup().testTag("notebook.sync.option")) {
                    options.forEach { value ->
                        Row(verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).selectable(selected = option == value, role = Role.RadioButton) {
                                option = value
                                NotebookSync.choose(context, value)
                                if (value != NotebookSync.Option.NONE) syncNow()
                            }) {
                            RadioButton(selected = option == value, onClick = null)
                            Text(optionName(value), color = colors.text, modifier = Modifier.padding(start = 8.dp))
                        }
                    }
                }
                if (option != NotebookSync.Option.NONE) {
                    Button(colors = libraryActionColors(colors), enabled = !syncing, modifier = Modifier.testTag("notebook.sync.now"),
                        onClick = { syncNow() }) { Text(if (syncing) "Sincronizando..." else config.label("sincronizar")) }
                    lastSync?.let { millis ->
                        val text = java.text.DateFormat.getDateTimeInstance(java.text.DateFormat.SHORT, java.text.DateFormat.SHORT).format(java.util.Date(millis))
                        Text(config.label("sincronizado", mapOf("data" to text)), color = colors.secondary, fontSize = 13.sp)
                    }
                }
            }
        }
        if (message.isNotEmpty()) {
            item { Text(message, color = colors.text, modifier = Modifier.testTag("notebook.message")) }
        }
    }
}
