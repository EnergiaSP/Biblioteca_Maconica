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
import android.graphics.Bitmap
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
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.filled.Fullscreen
import androidx.compose.material.icons.filled.FullscreenExit
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

@Composable
internal fun LibraryReaderScreen(
    colors: Palette,
    prefs: PreferencesStore,
    fullscreen: Boolean,
    onToggleFullscreen: () -> Unit,
    onSaved: (String) -> Unit,
    paginas: List<BibliotecaPaginaLeitura>,
    paginaAtual: Int,
    settings: ReaderSettings,
    onPageChange: (Int) -> Unit,
    onHome: () -> Unit,
    onSearch: () -> Unit
) {
    val context = LocalContext.current
    val pagina = paginas.getOrNull(paginaAtual)
    if (pagina == null) {
        Box(Modifier.fillMaxSize().padding(18.dp), contentAlignment = Alignment.Center) {
            Text("Nenhuma obra carregada.", color = colors.text)
        }
        return
    }

    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onHome) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Voltar ao início", tint = colors.text) }
                Row {
                    IconButton(onClick = onToggleFullscreen) { Icon(if (fullscreen) Icons.Default.FullscreenExit else Icons.Default.Fullscreen, if (fullscreen) "Sair da tela cheia" else "Tela cheia", tint = colors.text) }
                    IconButton(enabled = paginaAtual > 0, onClick = { onPageChange((paginaAtual - 1).coerceAtLeast(0)) }) {
                        Icon(Icons.AutoMirrored.Filled.NavigateBefore, "Página anterior", tint = colors.text)
                    }
                    IconButton(enabled = paginaAtual < paginas.lastIndex, onClick = { onPageChange((paginaAtual + 1).coerceAtMost(paginas.lastIndex)) }) {
                        Icon(Icons.AutoMirrored.Filled.NavigateNext, "Próxima página", tint = colors.text)
                    }
                    IconButton(onClick = onSearch) { Icon(Icons.Default.Search, "Pesquisar no acervo", tint = colors.text) }
                    IconButton(onClick = { shareText(context, textoCompartilhavelPagina(pagina)) }) {
                        Icon(Icons.Default.IosShare, "Compartilhar página", tint = colors.text)
                    }
                    IconButton(onClick = { shareLibraryPdf(context, paginas) }) {
                        Icon(Icons.Default.PictureAsPdf, "Exportar obra em PDF", tint = colors.text)
                    }
                    IconButton(onClick = { copyText(context, textoCompartilhavelPagina(pagina)) }) {
                        Icon(Icons.Default.ContentCopy, "Copiar página", tint = colors.text)
                    }
                }
            }
            Text(pagina.tituloObra, color = colors.accent, fontWeight = FontWeight.Bold)
            pagina.autor?.let { Text(it, color = colors.secondary) }
            Text("Página ${pagina.pagina}", color = colors.secondary, fontSize = 13.sp)
            Text(pagina.titulo, color = colors.text, fontSize = 26.sp, fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold)
            Text(
                if (settings.libraryContinuousMode) "Modo contínuo" else "Modo página",
                color = colors.accent,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
        if (settings.libraryContinuousMode) {
            items(paginas.drop(paginaAtual)) { paginaLivro ->
                LibraryPageBlock(colors, paginaLivro, settings, prefs, onSaved)
            }
        } else {
            item {
                LibraryPageBlock(colors, pagina, settings, prefs, onSaved)
            }
        }
    }
}

@Composable
internal fun LibraryPageBlock(colors: Palette, pagina: BibliotecaPaginaLeitura, settings: ReaderSettings, prefs: PreferencesStore, onSaved: (String) -> Unit) {
    val context = LocalContext.current
    val item = remember(pagina) { BreviarioItem(pagina.pagina, "P${pagina.pagina}", pagina.titulo, pagina.autor.orEmpty(), pagina.texto, pagina.rodape, pagina.pagina, pagina.obraId) }
    var highlights by remember(item.chavePersistencia) { mutableStateOf(prefs.highlights(item)) }
    var showHighlights by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        if (pagina.titulo != "Página ${pagina.pagina}") {
            Text(pagina.titulo, color = colors.text, fontSize = 20.sp, fontFamily = FontFamily.Serif, fontWeight = FontWeight.Bold)
        }
        ReadingSelectionText(pagina.texto, pagina.rodape, highlights, settings, colors) { text ->
            prefs.addHighlight(item, text)
            highlights = prefs.highlights(item)
            onSaved("Marcador salvo.")
        }
        pagina.imagens.forEach { path ->
            AsyncPageImage(path = path, page = pagina.pagina)
        }
        if (pagina.rodape.isNotBlank()) {
            HorizontalDivider(color = colors.accent.copy(alpha = 0.8f), thickness = 1.dp)
            Text("Notas de rodapé", color = colors.accent, fontWeight = FontWeight.Bold)
            Text(
                pagina.rodape,
                color = colors.secondary,
                fontSize = (settings.fontSize - 2).sp,
                lineHeight = (settings.fontSize + 3).sp,
                fontFamily = FontFamily.Serif
            )
        }
        Text("Página ${pagina.pagina}", color = colors.secondary, fontSize = 12.sp, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.End)
        if (highlights.isNotEmpty()) {
            TextButton(onClick = { showHighlights = true }) { Text("Marcadores (${highlights.size})") }
        }
    }
    if (showHighlights) AlertDialog(onDismissRequest = { showHighlights = false }, title = { Text("Marcadores") }, text = {
        LazyColumn {
            items(highlights, key = { it.id }) { highlight ->
                Column {
                    Text(highlight.text)
                    IconButton(onClick = {
                        prefs.removeHighlight(item, highlight.id)
                        highlights = prefs.highlights(item)
                        onSaved("Marcador removido.")
                    }) { Icon(Icons.Default.Delete, "Remover marcador") }
                }
            }
        }
    }, confirmButton = {
        TextButton(enabled = highlights.isNotEmpty(), onClick = { shareHighlightsPdf(context, item, highlights) }) { Text("Exportar PDF") }
    }, dismissButton = {
        TextButton(onClick = { showHighlights = false }) { Text("Fechar") }
    })
}

@Composable
private fun AsyncPageImage(path: String, page: Int) {
    var bitmap by remember(path) { mutableStateOf<Bitmap?>(null) }
    LaunchedEffect(path) {
        bitmap = withContext(Dispatchers.IO) { decodePageImage(path) }
    }
    bitmap?.let {
        Image(
            bitmap = it.asImageBitmap(),
            contentDescription = "Imagem original da página $page",
            modifier = Modifier.fillMaxWidth(),
            contentScale = ContentScale.FillWidth
        )
    }
}

private fun decodePageImage(path: String, maxDimension: Int = 2048): Bitmap? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(path, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

    var sampleSize = 1
    while (bounds.outWidth / sampleSize > maxDimension || bounds.outHeight / sampleSize > maxDimension) {
        sampleSize *= 2
    }
    return BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sampleSize })
}
