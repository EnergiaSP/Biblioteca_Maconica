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
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
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
import androidx.compose.ui.platform.testTag
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
internal fun ReaderScreen(
    colors: Palette,
    fullscreen: Boolean,
    onToggleFullscreen: () -> Unit,
    item: BreviarioItem,
    settings: ReaderSettings,
    officialSources: List<OfficialSource>,
    isFavorite: Boolean,
    isRead: Boolean,
    comment: String,
    reflection: String,
    textEdited: Boolean,
    highlights: List<TextHighlight>,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onHome: () -> Unit,
    onToggleFavorite: () -> Unit,
    onToggleRead: () -> Unit,
    onSaveComment: (String) -> Unit,
    onSaveReflection: (String) -> Unit,
    onSaveTextEdit: (String, String, String) -> Unit,
    onRestoreText: () -> Unit,
    onAddHighlight: (String) -> Unit,
    onRemoveHighlight: (String) -> Unit,
    onExportHighlights: () -> Unit,
    onOpenSettings: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var currentComment by remember(item.chavePersistencia, comment) { mutableStateOf(comment) }
    var currentReflection by remember(item.chavePersistencia, reflection) { mutableStateOf(reflection) }
    var shareOpen by remember { mutableStateOf(false) }
    var gerandoIa by remember { mutableStateOf(false) }
    var editOpen by remember { mutableStateOf(false) }
    var highlightText by remember(item.chavePersistencia) { mutableStateOf("") }
    val tts = rememberTextToSpeech(settings.voiceGender, settings.voiceSpeed)
    var speaking by remember { mutableStateOf(false) }

    LazyColumn(Modifier.fillMaxSize().padding(horizontal = if (fullscreen) 8.dp else 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onHome) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Voltar ao início", tint = colors.text) }
                Row(Modifier.weight(1f).testTag("reader.tools").horizontalScroll(rememberScrollState())) {
                    IconButton(onClick = onPrevious) { Icon(Icons.AutoMirrored.Filled.NavigateBefore, "Leitura anterior", tint = colors.text) }
                    IconButton(onClick = onNext) { Icon(Icons.AutoMirrored.Filled.NavigateNext, "Próxima leitura", tint = colors.text) }
                    IconButton(onClick = onToggleFavorite) {
                        Icon(if (isFavorite) Icons.Default.Favorite else Icons.Default.FavoriteBorder, if (isFavorite) "Remover dos favoritos" else "Adicionar aos favoritos", tint = colors.accent)
                    }
                    IconButton(onClick = onToggleRead) { Icon(Icons.Default.CheckCircle, if (isRead) "Marcar como não lida" else "Marcar como lida", tint = if (isRead) colors.accent else colors.text) }
                    Box {
                        IconButton(onClick = { shareOpen = true }) { Icon(Icons.Default.IosShare, "Compartilhar", tint = colors.text) }
                        DropdownMenu(expanded = shareOpen, onDismissRequest = { shareOpen = false }) {
                            DropdownMenuItem(text = { Text("WhatsApp / Texto") }, onClick = {
                                shareOpen = false
                                shareText(context, TextoFormatter.textoCompartilhavel(item))
                            }, leadingIcon = { Icon(Icons.Default.IosShare, null) })
                            DropdownMenuItem(text = { Text("PDF da leitura") }, onClick = {
                                shareOpen = false
                                sharePdf(context, listOf(item), emptyMap(), settings.premiumPdfName)
                            }, leadingIcon = { Icon(Icons.Default.PictureAsPdf, null) })
                            DropdownMenuItem(text = { Text("PDF com comentário") }, onClick = {
                                shareOpen = false
                                sharePdf(context, listOf(item), mapOf(item.chavePersistencia to currentComment), settings.premiumPdfName)
                            }, leadingIcon = { Icon(Icons.Default.PictureAsPdf, null) })
                            DropdownMenuItem(text = { Text("Copiar texto") }, onClick = {
                                shareOpen = false
                                copyText(context, TextoFormatter.textoCompartilhavel(item))
                            }, leadingIcon = { Icon(Icons.Default.ContentCopy, null) })
                            DropdownMenuItem(text = { Text("PDF dos marcadores") }, onClick = {
                                shareOpen = false
                                onExportHighlights()
                            }, leadingIcon = { Icon(Icons.Default.PictureAsPdf, null) })
                        }
                    }
                    IconButton(onClick = onToggleFullscreen) { Icon(Icons.Default.Book, if (fullscreen) "Sair da tela cheia" else "Tela cheia", tint = colors.text) }
                    IconButton(onClick = { editOpen = true }) { Icon(Icons.Default.TextFields, "Editar leitura", tint = colors.text) }
                    IconButton(onClick = onOpenSettings) { Icon(Icons.Default.Settings, "Configurações", tint = colors.text) }
                }
            }
            Text(TextoFormatter.dataPorExtenso(item.data), color = colors.accent, fontWeight = FontWeight.Bold)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(item.autor, color = colors.secondary, modifier = Modifier.weight(1f))
                AssistChip(
                    onClick = {
                        if (!settings.aiEnabled) {
                            Toast.makeText(context, "Ative a IA nas configurações.", Toast.LENGTH_LONG).show()
                            return@AssistChip
                        }
                        if (settings.geminiApiKey.isBlank()) {
                            Toast.makeText(context, "Informe a chave Gemini nas configurações.", Toast.LENGTH_LONG).show()
                            return@AssistChip
                        }
                        gerandoIa = true
                        scope.launch {
                            val resultado = withContext(Dispatchers.IO) {
                                runCatching {
                                    GeminiService.gerarTexto(promptAnaliseLeitura(item, officialSources), settings.geminiApiKey)
                                }
                            }
                            resultado.onSuccess { analise ->
                                val comentarioAtualizado = comentarioComAnaliseGemini(currentComment, analise)
                                currentComment = comentarioAtualizado
                                onSaveComment(comentarioAtualizado)
                                Toast.makeText(context, "Análise IA salva no comentário do dia.", Toast.LENGTH_LONG).show()
                            }.onFailure { erro ->
                                Toast.makeText(context, erro.message ?: "Não foi possível gerar a análise.", Toast.LENGTH_LONG).show()
                            }
                            gerandoIa = false
                        }
                    },
                    enabled = !gerandoIa,
                    label = { Text(if (gerandoIa) "Gerando..." else "IA") }
                )
            }
            Text(item.titulo, color = colors.text, fontSize = 28.sp, fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold)
        }
        item {
            ReadingSelectionText(item.texto, item.rodape, highlights, settings, colors, onAddHighlight)
        }
        if (item.rodape.isNotBlank()) {
            item {
                HorizontalDivider(color = colors.accent.copy(alpha = 0.8f), thickness = 1.dp)
                Spacer(Modifier.height(8.dp))
                Text("Notas de rodapé", color = colors.accent, fontWeight = FontWeight.Bold)
                Text(
                    item.rodape,
                    color = colors.secondary,
                    fontSize = (settings.fontSize - 2).sp,
                    lineHeight = (settings.fontSize + 3).sp,
                    fontFamily = FontFamily.Serif
                )
            }
        }
        item {
            PremiumCard(colors) {
                Text("Minha reflexão de hoje", color = colors.text, fontWeight = FontWeight.Bold)
                Text(
                    "Registre com suas palavras o principal aprendizado e uma aplicação prática.",
                    color = colors.secondary
                )
                OutlinedTextField(
                    value = currentReflection,
                    onValueChange = { currentReflection = it },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 180.dp),
                    label = { Text("Reflexão pessoal") }
                )
                Button(onClick = { onSaveReflection(currentReflection) }) {
                    Text("Salvar reflexão")
                }
            }
        }
        item {
            PremiumCard(colors) {
                Text("Marcadores", color = colors.text, fontWeight = FontWeight.Bold)
                Text("Salve trechos importantes para revisar e exportar depois.", color = colors.secondary)
                OutlinedTextField(
                    value = highlightText,
                    onValueChange = { highlightText = it },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 96.dp),
                    label = { Text("Trecho destacado") }
                )
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(onClick = {
                        onAddHighlight(highlightText)
                        highlightText = ""
                    }) {
                        Text("Salvar marcador")
                    }
                    Button(onClick = onExportHighlights, enabled = highlights.isNotEmpty()) {
                        Icon(Icons.Default.PictureAsPdf, null)
                        Spacer(Modifier.width(6.dp))
                        Text("Exportar")
                    }
                }
                if (highlights.isEmpty()) {
                    Text("Nenhum marcador salvo para esta leitura.", color = colors.secondary)
                } else {
                    highlights.forEach { highlight ->
                        HorizontalDivider(color = colors.secondary.copy(alpha = 0.18f))
                        Row(verticalAlignment = Alignment.Top) {
                            Text(highlight.text, color = colors.secondary, modifier = Modifier.weight(1f))
                            IconButton(onClick = { onRemoveHighlight(highlight.id) }) {
                                Icon(Icons.Default.Delete, contentDescription = "Remover marcador", tint = colors.accent)
                            }
                        }
                    }
                }
            }
        }
        item {
            PremiumCard(colors) {
                Text("Comentário pessoal", color = colors.text, fontWeight = FontWeight.Bold)
                OutlinedTextField(
                    value = currentComment,
                    onValueChange = { currentComment = it },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 280.dp),
                    label = { Text("Escreva sua reflexão") }
                )
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(onClick = { onSaveComment(currentComment) }) { Text("Salvar comentário") }
                    Button(onClick = {
                        if (speaking) {
                            tts.stop()
                            speaking = false
                        } else {
                            tts.speak(item.texto, TextToSpeech.QUEUE_FLUSH, null, "leitura-${item.data}")
                            speaking = true
                        }
                    }) {
                        Icon(if (speaking) Icons.Default.Stop else Icons.Default.PlayArrow, null)
                        Spacer(Modifier.width(6.dp))
                        Text(if (speaking) "Pausar" else "Ouvir texto")
                    }
                }
            }
        }
    }

    if (editOpen) {
        EditReadingDialog(
            colors = colors,
            item = item,
            textEdited = textEdited,
            onDismiss = { editOpen = false },
            onSave = { title, text, footnote ->
                onSaveTextEdit(title, text, footnote)
                editOpen = false
            },
            onRestore = {
                onRestoreText()
                editOpen = false
            }
        )
    }
}

@Composable
internal fun EditReadingDialog(
    colors: Palette,
    item: BreviarioItem,
    textEdited: Boolean,
    onDismiss: () -> Unit,
    onSave: (String, String, String) -> Unit,
    onRestore: () -> Unit
) {
    var title by remember(item.chavePersistencia) { mutableStateOf(item.titulo) }
    var text by remember(item.chavePersistencia) { mutableStateOf(item.texto) }
    var footnote by remember(item.chavePersistencia) { mutableStateOf(item.rodape) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Editar texto") },
        text = {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                item {
                    OutlinedTextField(
                        value = title,
                        onValueChange = { title = it },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Título") }
                    )
                }
                item {
                    OutlinedTextField(
                        value = text,
                        onValueChange = { text = it },
                        modifier = Modifier.fillMaxWidth().heightIn(min = 220.dp),
                        label = { Text("Texto principal") }
                    )
                }
                item {
                    OutlinedTextField(
                        value = footnote,
                        onValueChange = { footnote = it },
                        modifier = Modifier.fillMaxWidth().heightIn(min = 120.dp),
                        label = { Text("Notas de rodapé") }
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onSave(title, text, footnote) }) {
                Text("Salvar", color = colors.accent)
            }
        },
        dismissButton = {
            Row {
                if (textEdited) {
                    TextButton(onClick = onRestore) {
                        Text("Restaurar original", color = colors.accent)
                    }
                }
                TextButton(onClick = onDismiss) {
                    Text("Cancelar")
                }
            }
        }
    )
}
