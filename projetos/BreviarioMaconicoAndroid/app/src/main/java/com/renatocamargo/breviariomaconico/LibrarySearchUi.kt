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
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
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
import androidx.compose.ui.platform.testTag
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
import com.renatocamargo.breviariomaconico.data.LibraryMetadataFilter
import com.renatocamargo.breviariomaconico.data.DossierAnalysis
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
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.isActive
import java.io.File
import java.time.LocalDate
import java.util.Calendar
import java.util.Locale

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun StructuredSearchScreen(
    colors: Palette,
    termoInicial: String = "",
    session: LibraryStudySession = remember { LibraryStudySession(MENSAGEM_INICIAL_BUSCA, termoInicial) },
    abrirResultado: (BibliotecaBuscaResultado) -> Unit
) {
    val context = LocalContext.current
    val catalogo = remember { BibliotecaCatalogRepository.get(context) }
    val scope = rememberCoroutineScope()
    var termo by session::termo
    var metadataFilter by session::metadataFilter
    var area by session::area
    var obraId by session::obraId
    var obras by remember { mutableStateOf(emptyList<com.renatocamargo.breviariomaconico.data.BibliotecaObraCatalogo>()) }
    var escolherObra by remember { mutableStateOf(false) }
    var resultados by session::resultados
    var mensagem by session::status
    var buscando by remember { mutableStateOf(false) }
    var temMais by session::temMais
    var consultaJob by remember { mutableStateOf<Job?>(null) }
    DisposableEffect(Unit) {
        onDispose {
            if (buscando) {
                mensagem = "Busca interrompida. Toque em buscar novamente."
                session.ultimaConsulta = null
            }
        }
    }

    fun pesquisar(mais: Boolean = false) {
        if (mais && (buscando || !temMais)) return
        consultaJob?.cancel()
        val consulta = termo.trim()
        val areaSelecionada = area
        val obraSelecionada = obraId
        val filtroSelecionado = metadataFilter
        val inicio = if (mais) resultados.size else 0
        if (!mais) resultados = emptyList()
        if (consulta.isEmpty()) { temMais = false; buscando = false; return }
        buscando = true
        mensagem = "Buscando no acervo..."
        consultaJob = scope.launch {
            val requestContext = currentCoroutineContext()
            try {
                libraryQuery { catalogo.buscarConteudo(consulta, areaSelecionada, obraSelecionada,
                    limite = 51, offset = inicio, cancelled = { !requestContext.isActive }, filtro = filtroSelecionado) }
                    .onSuccess {
                        resultados = resultados + it.take(50)
                        temMais = it.size > 50
                        mensagem = if (resultados.isEmpty()) "Nenhum resultado encontrado nas obras disponíveis." else "${resultados.size} resultado(s) carregados."
                    }.onFailure {
                        mensagem = "Não foi possível consultar as obras. Tente novamente."
                    }
            } finally { if (requestContext.isActive) buscando = false }
        }
    }

    LaunchedEffect(termo, area, obraId, metadataFilter) {
        // Returning from an opened result must keep the results already loaded for the same query.
        val consulta = listOf(termo, area, obraId, metadataFilter)
        if (consulta == session.ultimaConsulta) return@LaunchedEffect
        session.ultimaConsulta = consulta
        consultaJob?.cancel()
        resultados = emptyList()
        temMais = false
        buscando = false
        delay(350)
        pesquisar()
    }
    DisposableEffect(Unit) { onDispose { consultaJob?.cancel() } }
    var areaDasObras by remember { mutableStateOf(area) }
    LaunchedEffect(area) {
        if (area != areaDasObras) {
            obraId = null
            areaDasObras = area
        }
        libraryQuery { catalogo.obrasDisponiveis(area) }.onSuccess { obras = it }
    }

    LazyColumn(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            PremiumCard(colors) {
                Text("Busca estruturada", color = colors.text, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                Text("Pesquisa por palavra ou frase nas obras baixadas do acervo.", color = colors.secondary)
                OutlinedTextField(
                    value = termo,
                    onValueChange = { termo = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Pesquisar no acervo") },
                    leadingIcon = { Icon(Icons.Default.Search, null) },
                    singleLine = true,
                    colors = librarySearchFieldColors(colors)
                )
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    val chipColors = FilterChipDefaults.filterChipColors(
                        labelColor = colors.text,
                        selectedContainerColor = colors.accentSurface,
                        selectedLabelColor = colors.onAccent
                    )
                    FilterChip(selected = area == null, onClick = { area = null },
                        label = { Text("Todo acervo") }, colors = chipColors)
                    BibliotecaArea.entries.forEach { item ->
                        FilterChip(selected = area == item, onClick = { area = item },
                            label = { Text(item.titulo) }, colors = chipColors)
                    }
                }
                Box {
                    TextButton(onClick = { escolherObra = true }) {
                        Text(obras.firstOrNull { it.id == obraId }?.titulo ?: "Todas as obras da seleção", color = colors.text)
                    }
                    DropdownMenu(expanded = escolherObra, onDismissRequest = { escolherObra = false }) {
                        DropdownMenuItem(text = { Text("Todas as obras da seleção") }, onClick = { obraId = null; escolherObra = false })
                        obras.forEach { obra ->
                            DropdownMenuItem(text = { Text(obra.titulo) }, onClick = { obraId = obra.id; escolherObra = false })
                        }
                    }
                }
                MetadataFilterFields(colors, metadataFilter) { metadataFilter = it }
                Button(colors = libraryActionColors(colors), enabled = termo.isNotBlank() && !buscando, onClick = { pesquisar() }) {
                    Icon(Icons.Default.Search, null)
                    Spacer(Modifier.width(8.dp))
                    Text(if (buscando) "Buscando..." else "Buscar")
                }
                Text(mensagem, color = colors.accent, fontWeight = FontWeight.SemiBold)
            }
        }
        items(resultados, key = { it.id }) { resultado ->
            SearchResultCard(colors, resultado, abrirResultado)
        }
        if (temMais) item {
            Button(colors = libraryActionColors(colors), enabled = !buscando, onClick = { pesquisar(mais = true) }, modifier = Modifier.fillMaxWidth()) {
                Text(if (buscando) "Buscando..." else "Carregar mais resultados")
            }
        }
    }
}

@Composable
internal fun MetadataFilterFields(colors: Palette, filter: LibraryMetadataFilter, onChange: (LibraryMetadataFilter) -> Unit) {
    OutlinedTextField(value = filter.autor, onValueChange = { onChange(filter.copy(autor = it)) },
        label = { Text("Filtrar por autor") }, modifier = Modifier.fillMaxWidth().testTag("search.author"),
        singleLine = true, colors = librarySearchFieldColors(colors))
    OutlinedTextField(value = filter.assunto, onValueChange = { onChange(filter.copy(assunto = it)) },
        label = { Text("Filtrar por assunto") }, modifier = Modifier.fillMaxWidth().testTag("search.subject"),
        singleLine = true, colors = librarySearchFieldColors(colors))
}

@Composable
internal fun librarySearchFieldColors(colors: Palette) = OutlinedTextFieldDefaults.colors(
    focusedTextColor = colors.text,
    unfocusedTextColor = colors.text,
    focusedLabelColor = colors.secondary,
    unfocusedLabelColor = colors.secondary,
    focusedLeadingIconColor = colors.secondary,
    unfocusedLeadingIconColor = colors.secondary,
    focusedBorderColor = colors.accent,
    unfocusedBorderColor = colors.secondary,
    cursorColor = colors.accent
)

@Composable
internal fun SearchResultCard(colors: Palette, resultado: BibliotecaBuscaResultado, abrirResultado: (BibliotecaBuscaResultado) -> Unit) {
    PremiumCard(colors, Modifier.clickable { abrirResultado(resultado) }) {
        Text(resultado.tituloObra, color = colors.text, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text("${resultado.area.titulo} • ${resultado.data?.let(TextoFormatter::dataPorExtenso) ?: "Página ${resultado.pagina}"}", color = colors.accent, fontSize = 13.sp)
        Text(resultado.trecho.take(320), color = colors.secondary, maxLines = 5, overflow = TextOverflow.Ellipsis)
    }
}

internal fun textoCompartilhavelPagina(pagina: BibliotecaPaginaLeitura): String =
    buildString {
        appendLine(pagina.tituloObra)
        pagina.autor?.let { appendLine(it) }
        appendLine("Página ${pagina.pagina}")
        appendLine()
        appendLine(TextoFormatter.sobrescrito(pagina.texto, pagina.rodape))
        if (pagina.rodape.isNotBlank()) {
            appendLine()
            appendLine("Notas de rodapé")
            appendLine(pagina.rodape)
        }
    }.trim()

@androidx.compose.runtime.Composable
internal fun libraryActionColors(colors: Palette) = androidx.compose.material3.ButtonDefaults.buttonColors(
    containerColor = colors.accentSurface,
    contentColor = colors.onAccent,
    disabledContainerColor = colors.surface,
    disabledContentColor = colors.secondary
)
