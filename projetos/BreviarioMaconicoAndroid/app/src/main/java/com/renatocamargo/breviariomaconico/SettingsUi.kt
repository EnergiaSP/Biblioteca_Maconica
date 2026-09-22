package com.renatocamargo.breviariomaconico

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ClipData
import android.content.ClipboardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Paint
import android.graphics.BitmapFactory
import android.graphics.pdf.PdfDocument
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.NavigateBefore
import androidx.compose.material.icons.automirrored.filled.NavigateNext
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CloudDownload
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.NavigateBefore
import androidx.compose.material.icons.filled.NavigateNext
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.TextFields
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.renatocamargo.breviariomaconico.data.AppThemeMode
import com.renatocamargo.breviariomaconico.data.BibliotecaArea
import com.renatocamargo.breviariomaconico.data.BibliotecaBuscaResultado
import com.renatocamargo.breviariomaconico.data.BibliotecaCatalogRepository
import com.renatocamargo.breviariomaconico.data.BibliotecaIndiceTermo
import com.renatocamargo.breviariomaconico.data.BibliotecaPaginaLeitura
import com.renatocamargo.breviariomaconico.data.BibliotecaPacoteEstado
import com.renatocamargo.breviariomaconico.data.BreviarioItem
import com.renatocamargo.breviariomaconico.data.BreviarioRepository
import com.renatocamargo.breviariomaconico.data.GeminiService
import com.renatocamargo.breviariomaconico.data.IndiceRemissivoEntry
import com.renatocamargo.breviariomaconico.data.LibraryRecent
import com.renatocamargo.breviariomaconico.data.LocalPdfOcrImporter
import com.renatocamargo.breviariomaconico.data.OfficialSource
import com.renatocamargo.breviariomaconico.data.PreferencesStore
import com.renatocamargo.breviariomaconico.data.ReaderSettings
import com.renatocamargo.breviariomaconico.data.StudyPath
import com.renatocamargo.breviariomaconico.data.TextHighlight
import com.renatocamargo.breviariomaconico.data.TextoFormatter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.time.LocalDate
import java.util.Calendar
import java.util.Locale

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun SettingsScreen(
    colors: Palette,
    settings: ReaderSettings,
    dailyWorks: List<BreviarioItem>,
    onSave: (ReaderSettings) -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var current by remember(settings) { mutableStateOf(settings) }
    var importTitle by remember { mutableStateOf("") }
    var importAuthor by remember { mutableStateOf("") }
    var importTopics by remember { mutableStateOf("") }
    var importArea by remember { mutableStateOf(BibliotecaArea.Biblioteca) }
    var importStatus by remember { mutableStateOf<String?>(null) }
    var importing by remember { mutableStateOf(false) }
    var testNotificationPending by remember { mutableStateOf(false) }
    fun scheduleTest() {
        val scheduled = sendTestNotification(context)
        Toast.makeText(context, if (scheduled) "Teste agendado." else "Notificações bloqueadas. Verifique a permissão e o canal nas configurações do Android.", Toast.LENGTH_LONG).show()
    }
    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            if (testNotificationPending) scheduleTest() else onSave(current)
        } else {
            Toast.makeText(context, "Permissão negada. Nenhuma notificação foi agendada.", Toast.LENGTH_LONG).show()
        }
        testNotificationPending = false
    }
    val pdfLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null && importTitle.isNotBlank()) {
            importing = true
            scope.launch {
                runCatching {
                    LocalPdfOcrImporter(context).import(uri, importTitle, importAuthor.ifBlank { null }, importArea,
                        assuntos = importTopics.split(',').map(String::trim).filter(String::isNotEmpty)) { progress ->
                        importStatus = "${progress.message} (${progress.currentPage}/${progress.totalPages})"
                    }
                }.onSuccess { work ->
                    importStatus = "${work.title} importado com ${work.pages} páginas e já disponível no acervo."
                    importTitle = ""
                    importAuthor = ""
                    importTopics = ""
                    Toast.makeText(context, "Obra importada com sucesso.", Toast.LENGTH_LONG).show()
                }.onFailure { error ->
                    importStatus = error.localizedMessage ?: "Falha ao importar o PDF."
                    Toast.makeText(context, importStatus, Toast.LENGTH_LONG).show()
                }
                importing = false
            }
        }
    }
    LazyColumn(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            PremiumCard(colors) {
                Text("Aparência e leitura", color = colors.text, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AppThemeMode.entries.forEach { mode ->
                        AssistChip(onClick = { current = current.copy(theme = mode) }, label = { Text(mode.label) })
                    }
                }
                Text("Tamanho da fonte: ${current.fontSize.toInt()}", color = colors.text)
                Slider(current.fontSize, { current = current.copy(fontSize = it) }, valueRange = 14f..26f)
                Text("Espaçamento: ${current.lineSpacing.toInt()}", color = colors.text)
                Slider(current.lineSpacing, { current = current.copy(lineSpacing = it) }, valueRange = 4f..16f)
                Text("Voz", color = colors.text, fontWeight = FontWeight.Bold)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("Feminina", "Masculina").forEach { voice ->
                        AssistChip(onClick = { current = current.copy(voiceGender = voice) }, label = { Text(voice) })
                    }
                }
                Text("Velocidade da voz: ${(current.voiceSpeed * 100).toInt()}%", color = colors.text)
                Slider(
                    value = current.voiceSpeed,
                    onValueChange = { current = current.copy(voiceSpeed = it) },
                    valueRange = 0.75f..1.2f
                )
                AssistChip(
                    onClick = { current = current.copy(distractionFreeMode = !current.distractionFreeMode) },
                    label = { Text(if (current.distractionFreeMode) "Modo sem distrações ativo" else "Modo sem distrações inativo") },
                    leadingIcon = {
                        if (current.distractionFreeMode) Icon(Icons.Default.CheckCircle, null, tint = Color(0xFF1F7A3A))
                    }
                )
                OutlinedTextField(
                    value = current.premiumPdfName,
                    onValueChange = { current = current.copy(premiumPdfName = it) },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Nome para a capa PDF premium") },
                    singleLine = true
                )
                Text("Leitura de livros", color = colors.text, fontWeight = FontWeight.Bold)
                AssistChip(
                    onClick = { current = current.copy(libraryContinuousMode = !current.libraryContinuousMode) },
                    label = { Text(if (current.libraryContinuousMode) "Modo contínuo ativo" else "Modo página ativo") }
                )
            }
        }
        item {
            PremiumCard(colors) {
                Text("Importar PDF com OCR", color = colors.text, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Text(
                    "A importação é feita no aparelho, preserva páginas e imagens e inclui o conteúdo na busca e nos índices.",
                    color = colors.secondary
                )
                OutlinedTextField(
                    value = importTitle,
                    onValueChange = { importTitle = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Título da obra") },
                    singleLine = true
                )
                OutlinedTextField(
                    value = importAuthor,
                    onValueChange = { importAuthor = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Autor (opcional)") },
                    singleLine = true
                )
                OutlinedTextField(
                    value = importTopics,
                    onValueChange = { importTopics = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Assuntos (separados por vírgula)") },
                    enabled = !importing
                )
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    BibliotecaArea.entries.forEach { area ->
                        AssistChip(
                            onClick = { importArea = area },
                            label = { Text(area.titulo) },
                            leadingIcon = {
                                if (importArea == area) Icon(Icons.Default.CheckCircle, null, tint = Color(0xFF1F7A3A))
                            }
                        )
                    }
                }
                Button(
                    onClick = { pdfLauncher.launch("application/pdf") },
                    enabled = importTitle.isNotBlank() && !importing
                ) {
                    Icon(Icons.Default.PictureAsPdf, null)
                    Spacer(Modifier.width(7.dp))
                    Text(if (importing) "Importando…" else "Selecionar PDF")
                }
                importStatus?.let { Text(it, color = colors.secondary) }
            }
        }
        item {
            PremiumCard(colors) {
                Text("IA de estudo", color = colors.text, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Text(
                    "Opcional. Quando ativada, a análise deve usar apenas o texto do app e fontes documentais recuperadas.",
                    color = colors.secondary
                )
                AssistChip(
                    onClick = { current = current.copy(aiEnabled = !current.aiEnabled) },
                    label = { Text(if (current.aiEnabled) "IA ativada" else "IA desativada") }
                )
                OutlinedTextField(
                    value = current.geminiApiKey,
                    onValueChange = { current = current.copy(geminiApiKey = it.trim()) },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Chave Gemini") },
                    singleLine = true
                )
            }
        }
        item {
            PremiumCard(colors) {
                Text("Notificação diária", color = colors.text, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Text("Obras que enviarão a leitura do dia", color = colors.secondary)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    dailyWorks.forEach { work ->
                        val selected = work.obraId in current.notificationWorkIds
                        AssistChip(
                            onClick = {
                                val updated = current.notificationWorkIds.toMutableSet().apply {
                                    if (selected) remove(work.obraId) else add(work.obraId)
                                }
                                current = current.copy(notificationWorkIds = updated)
                            },
                            label = {
                                Text(
                                    if (work.autor.isBlank()) "Breviário" else "Breviário - ${work.autor}",
                                    color = if (selected) Color.Black else colors.text
                                )
                            },
                            leadingIcon = {
                                if (selected) Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF1F7A3A))
                            }
                        )
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    AssistChip(onClick = { current = current.copy(dailyNotificationEnabled = !current.dailyNotificationEnabled) }, label = { Text(if (current.dailyNotificationEnabled) "Ativa" else "Inativa") })
                    Spacer(Modifier.width(10.dp))
                    OutlinedTextField(current.notificationHour.toString(), { current = current.copy(notificationHour = it.toIntOrNull()?.coerceIn(0, 23) ?: 8) }, label = { Text("Hora") }, modifier = Modifier.width(100.dp))
                    Spacer(Modifier.width(8.dp))
                    OutlinedTextField(current.notificationMinute.toString(), { current = current.copy(notificationMinute = it.toIntOrNull()?.coerceIn(0, 59) ?: 0) }, label = { Text("Min") }, modifier = Modifier.width(100.dp))
                }
                FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = {
                        testNotificationPending = false
                        if (current.dailyNotificationEnabled && Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        } else onSave(current)
                    }) {
                        Icon(Icons.Default.Notifications, null)
                        Spacer(Modifier.width(6.dp))
                        Text("Salvar notificação")
                    }
                    Button(onClick = {
                        testNotificationPending = true
                        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        } else {
                            scheduleTest()
                            testNotificationPending = false
                        }
                    }) {
                        Text("Teste em 5 segundos")
                    }
                }
            }
        }
    }
}

@Composable
internal fun MoreScreen(colors: Palette, onOpen: (Screen) -> Unit) {
    LazyColumn(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { ReadingCardLike(colors, "Índices da Biblioteca", "Obras, áreas e índice remissivo geral.") { onOpen(Screen.GlobalIndex) } }
        item { ReadingCardLike(colors, "Acervo offline", "Baixar uma obra ou todas as obras.") { onOpen(Screen.Acervo) } }
        item { ReadingCardLike(colors, "Fontes oficiais", "Referências confiáveis para IA e estudos.") { onOpen(Screen.OfficialSources) } }
        item { ReadingCardLike(colors, "Solicitar obra", "Sugerir novos PDFs e títulos.") { onOpen(Screen.RequestWork) } }
        item { ReadingCardLike(colors, "IA da leitura", "Resumo e explicação da leitura atual.") { onOpen(Screen.ReadingAI) } }
        item { ReadingCardLike(colors, "Exportar Dias", "PDF e texto para dias sequenciais ou alternados.") { onOpen(Screen.Export) } }
    }
}

@Composable
internal fun ReadingCardLike(colors: Palette, title: String, subtitle: String, onClick: () -> Unit) {
    PremiumCard(colors, Modifier.clickable(onClick = onClick)) {
        Text(title, color = colors.text, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Text(subtitle, color = colors.secondary)
    }
}

@Composable
internal fun PremiumCard(colors: Palette, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = colors.surface.copy(alpha = 0.92f)),
        shape = RoundedCornerShape(10.dp)
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp), content = content)
    }
}

@Composable
internal fun ToastNotice(message: String, colors: Palette, onGone: () -> Unit) {
    LaunchedEffect(message) {
        kotlinx.coroutines.delay(1800)
        onGone()
    }
    Box(Modifier.fillMaxSize().padding(bottom = 28.dp), contentAlignment = Alignment.BottomCenter) {
        Surface(color = colors.accentSurface, shape = RoundedCornerShape(12.dp), shadowElevation = 8.dp) {
            Text(message, color = colors.onAccent, modifier = Modifier.padding(horizontal = 18.dp, vertical = 12.dp), fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
internal fun rememberTextToSpeech(voiceGender: String, voiceSpeed: Float): TextToSpeech {
    val context = LocalContext.current
    val tts = remember {
        TextToSpeech(context) { }
    }
    LaunchedEffect(voiceGender, voiceSpeed) {
        tts.language = Locale.Builder().setLanguage("pt").setRegion("BR").build()
        val candidates = tts.voices?.filter { it.locale.language == "pt" }.orEmpty()
        val selected = if (voiceGender == "Masculina") candidates.lastOrNull() else candidates.firstOrNull()
        if (selected != null) tts.voice = selected
        tts.setSpeechRate(voiceSpeed.coerceIn(0.5f, 2f))
    }
    DisposableEffect(Unit) {
        onDispose {
            tts.stop()
            tts.shutdown()
        }
    }
    return tts
}
