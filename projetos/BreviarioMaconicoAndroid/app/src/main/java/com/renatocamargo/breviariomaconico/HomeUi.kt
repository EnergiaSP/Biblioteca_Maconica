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
import com.renatocamargo.breviariomaconico.data.recentByWork
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.time.LocalDate
import java.util.Calendar
import java.util.Locale

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun HomeScreen(
    colors: Palette,
    repo: BreviarioRepository,
    prefs: PreferencesStore,
    favoritesSnapshot: Set<String>,
    readDatesSnapshot: Set<String>,
    libraryRecents: List<LibraryRecent>,
    onRead: (BreviarioItem) -> Unit,
    abrirObra: (String, Int?) -> Unit,
    onOpen: (Screen) -> Unit
) {
    val context = LocalContext.current
    val catalogo = remember { BibliotecaCatalogRepository.get(context) }
    favoritesSnapshot.size
    readDatesSnapshot.size
    val today = repo.hoje()
    val dailyReadings = remember(repo.itens) { repo.leiturasDeHoje().ifEmpty { listOf(today) } }
    val favoritos = prefs.favoriteItems(repo.itens)
    val naoLidas = prefs.unreadItems(repo.itens)
    val comentadas = prefs.commentedItems(repo.itens)
    val ultimasLeituras = prefs.recentDailyItems(repo.itens)
    var expandedArea by remember { mutableStateOf<BibliotecaArea?>(null) }
    LazyColumn(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("Biblioteca Maçônica", modifier = Modifier.weight(1f), color = colors.text, fontSize = 30.sp, fontWeight = FontWeight.Bold)
                IconButton(onClick = { onOpen(Screen.Settings) }) {
                    Icon(Icons.Default.Settings, contentDescription = "Configurações", tint = colors.text)
                }
            }
        }
        items(dailyReadings, key = { "daily-${it.chavePersistencia}" }) { daily ->
            val completed = prefs.isRead(daily)
            PremiumCard(colors) {
                Text(dailyWorkTitle(daily), color = colors.text, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Text(TextoFormatter.dataPorExtenso(daily.data), color = colors.accent, fontWeight = FontWeight.Bold)
                if (completed) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = colors.success, modifier = Modifier.size(24.dp))
                        Text("Leitura diária concluída", color = colors.success, fontSize = 21.sp, fontWeight = FontWeight.Bold)
                    }
                } else {
                    Text(daily.titulo, color = colors.text, fontSize = 21.sp, fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold)
                    Text(daily.texto.take(260), color = colors.secondary)
                }
                Button(onClick = { onRead(daily) }) {
                    Icon(Icons.Default.Book, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text("Leitura")
                }
            }
        }
        item {
            PremiumCard(colors, Modifier.clickable { onOpen(Screen.StructuredSearch) }) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Search, contentDescription = null, tint = colors.accent, modifier = Modifier.size(34.dp))
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text("Buscar na biblioteca", color = colors.text, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                        Text("Palavras, frases, obras e datas", color = colors.secondary)
                    }
                }
            }
        }
        item {
            PremiumCard(colors) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.CheckCircle, contentDescription = null, tint = colors.accent, modifier = Modifier.size(28.dp))
                    Spacer(Modifier.width(10.dp))
                    Text("Últimas leituras", color = colors.text, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                }
                if (ultimasLeituras.isEmpty()) {
                    Text("Nenhuma leitura diária aberta recentemente.", color = colors.secondary)
                } else {
                    ultimasLeituras.forEachIndexed { index, item ->
                        if (index > 0) HorizontalDivider(color = colors.secondary.copy(alpha = 0.18f))
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onRead(item) }
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text(item.titulo, color = colors.text, fontWeight = FontWeight.SemiBold)
                                Text("${dailyWorkTitle(item)} • ${TextoFormatter.dataPorExtenso(item.data)}", color = colors.secondary, fontSize = 13.sp)
                            }
                            Icon(Icons.AutoMirrored.Filled.NavigateNext, contentDescription = null, tint = colors.secondary)
                        }
                    }
                }
                recentByWork(
                    libraryRecents, 3, { it.obraId }, { it.page.toString() }
                ).forEach { recent ->
                    HorizontalDivider(color = colors.secondary.copy(alpha = 0.18f))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { abrirObra(recent.obraId, recent.page) }
                            .padding(vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(recent.title, color = colors.text, fontWeight = FontWeight.SemiBold)
                            Text("${recent.area} • Página ${recent.page}", color = colors.secondary, fontSize = 13.sp)
                        }
                        Icon(Icons.AutoMirrored.Filled.NavigateNext, contentDescription = null, tint = colors.secondary)
                    }
                }
            }
        }
        BibliotecaArea.entries.forEach { area ->
            item {
                val estados = catalogo.estados(area)
                HomeAreaCard(
                    colors = colors,
                    area = area,
                    total = estados.size,
                    instaladas = estados.count { it.instalado },
                    expanded = expandedArea == area,
                    onToggle = { expandedArea = if (expandedArea == area) null else area },
                    onAcervo = { onOpen(Screen.Acervo) }
                ) {
                    if (area == BibliotecaArea.Breviarios) {
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            HomeChip("Abrir breviário", Icons.Default.CalendarMonth, colors) { onOpen(Screen.Breviario) }
                            HomeChip("Favoritos (${favoritos.size})", Icons.Default.Favorite, colors) { onOpen(Screen.Favorites) }
                            HomeChip("Não lidos (${naoLidas.size})", Icons.Default.Book, colors) { onOpen(Screen.Unread) }
                            HomeChip("Comentários (${comentadas.size})", Icons.Default.TextFields, colors) { onOpen(Screen.Comments) }
                            HomeChip("Estatísticas", Icons.Default.CheckCircle, colors) { onOpen(Screen.Stats) }
                        }
                    } else {
                        Text("Use o Acervo para baixar e abrir obras desta área.", color = colors.secondary)
                    }
                }
            }
        }
    }
}

internal fun dailyWorkTitle(item: BreviarioItem): String =
    if (item.autor.isBlank()) "Breviário Maçônico" else "Breviário Maçônico - ${item.autor}"

@Composable
internal fun HomeAreaCard(
    colors: Palette,
    area: BibliotecaArea,
    total: Int,
    instaladas: Int,
    expanded: Boolean,
    onToggle: () -> Unit,
    onAcervo: () -> Unit,
    content: @Composable ColumnScope.() -> Unit
) {
    PremiumCard(colors, Modifier.clickable { onToggle() }) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.Book, contentDescription = null, tint = colors.accent, modifier = Modifier.size(32.dp))
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(area.titulo, color = colors.text, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Text("$instaladas de $total pacote(s) offline", color = colors.secondary, fontSize = 13.sp)
            }
            Icon(if (expanded) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown, contentDescription = null, tint = colors.secondary)
        }
        if (expanded) {
            content()
            Button(onClick = onAcervo) {
                Icon(Icons.Default.CloudDownload, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("Abrir acervo")
            }
        }
    }
}

@Composable
internal fun HomeChip(label: String, icon: androidx.compose.ui.graphics.vector.ImageVector, colors: Palette, onClick: () -> Unit) {
    AssistChip(
        onClick = onClick,
        leadingIcon = { Icon(icon, contentDescription = null, tint = colors.accent) },
        label = { Text(label, color = colors.text) }
    )
}
