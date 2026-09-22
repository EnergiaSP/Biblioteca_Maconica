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
import androidx.compose.material3.FilterChip
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
internal fun GlobalIndexScreen(colors: Palette, abrirResultado: (BibliotecaBuscaResultado) -> Unit) {
    val context = LocalContext.current
    val catalogo = remember { BibliotecaCatalogRepository.get(context) }
    var area by remember { mutableStateOf<BibliotecaArea?>(null) }
    var obras by remember { mutableStateOf(emptyList<com.renatocamargo.breviariomaconico.data.BibliotecaObraCatalogo>()) }
    var obra by remember { mutableStateOf<com.renatocamargo.breviariomaconico.data.BibliotecaObraCatalogo?>(null) }
    var paginas by remember(obra) { mutableStateOf(emptyList<BibliotecaBuscaResultado>()) }
    var remissivo by remember(obra, area) { mutableStateOf(emptyList<com.renatocamargo.breviariomaconico.data.BibliotecaIndiceReferencia>()) }
    var filtro by remember(obra) { mutableStateOf("") }
    var quantidade by remember(obra) { mutableIntStateOf(50) }
    var mensagem by remember { mutableStateOf("") }
    var mostrarRemissivo by remember(obra) {
        mutableStateOf(obra?.id == com.renatocamargo.breviariomaconico.data.ObraId.BREVIARIO_SECULO_XXI)
    }
    LaunchedEffect(area) {
        obra = null
        libraryQuery { catalogo.obrasDisponiveis(area) }.onSuccess { obras = it }
            .onFailure { mensagem = "Não foi possível carregar as obras." }
    }
    LaunchedEffect(obra, area, quantidade, filtro) {
        val atual = obra
        mensagem = "Carregando índice..."
        libraryQuery {
            catalogo.indiceRemissivoGlobal(area, atual?.id) to
                (atual?.let { catalogo.indicePaginas(it.id, quantidade, filtro) } ?: emptyList())
        }.onSuccess { (termos, entradas) ->
            remissivo = termos
            paginas = entradas
            mensagem = if (atual != null && termos.isEmpty() && entradas.isEmpty()) "Nenhum índice disponível." else ""
        }.onFailure { mensagem = "Não foi possível abrir o índice desta obra." }
    }
    LazyColumn(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Text(obra?.titulo ?: "Índice do acervo", color = colors.text, fontSize = 24.sp, fontWeight = FontWeight.Bold)
            if (obra == null) {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = area == null, onClick = { area = null }, label = { Text("Todas as áreas") })
                    BibliotecaArea.entries.forEach { value ->
                        FilterChip(selected = area == value, onClick = { area = value }, label = { Text(value.titulo) },
                            leadingIcon = { if (area == value) Icon(Icons.Default.CheckCircle, null) })
                    }
                }
            } else {
                TextButton(onClick = { obra = null }) { Text("Voltar às obras") }
            }
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = mostrarRemissivo, onClick = { mostrarRemissivo = true }, label = { Text("Índice remissivo") },
                    modifier = Modifier.testTag("index.remissive"))
                FilterChip(selected = !mostrarRemissivo, onClick = { mostrarRemissivo = false },
                    label = { Text(if (obra == null) "Obras" else "Índice de leituras") })
            }
            OutlinedTextField(filtro, { filtro = it }, Modifier.fillMaxWidth(), label = { Text("Filtrar índice") })
            if (mensagem.isNotBlank()) Text(mensagem, color = colors.secondary)
        }
        if (mostrarRemissivo) {
            val filtrados = remissivo.filter { com.renatocamargo.breviariomaconico.data.normalized(it.entrada.termo)
                .contains(com.renatocamargo.breviariomaconico.data.normalized(filtro)) }
            if (filtrados.isEmpty() && mensagem.isBlank()) item { Text("Nenhuma referência disponível neste escopo.", color = colors.secondary) }
            items(filtrados, key = { it.id }) { referencia ->
                val entrada = referencia.entrada
                PremiumCard(colors) {
                    Text(entrada.termo, color = colors.text, fontWeight = FontWeight.Bold)
                    Text(referencia.tituloObra, color = colors.secondary)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        entrada.datas.forEach { data ->
                            AssistChip(onClick = {
                                BreviarioRepository.get(context).porData(data)?.takeIf { it.obraId == referencia.obraId }?.let {
                                    abrirResultado(BibliotecaBuscaResultado(it.obraId, referencia.tituloObra, BibliotecaArea.Breviarios,
                                        it.pagina, it.texto, data = it.data, rodape = it.rodape))
                                }
                            }, label = { Text(TextoFormatter.dataPorExtenso(data)) })
                        }
                    }
                }
            }
        } else if (obra == null) {
            items(obras.filter { com.renatocamargo.breviariomaconico.data.normalized(it.titulo).contains(com.renatocamargo.breviariomaconico.data.normalized(filtro)) }, key = { it.id }) { entrada ->
                PremiumCard(colors, Modifier.clickable { obra = entrada; filtro = "" }) {
                    Text(entrada.titulo, color = colors.text, fontWeight = FontWeight.Bold)
                    Text("${entrada.paginas} páginas", color = colors.secondary)
                }
            }
        } else {
            items(paginas, key = { it.id }) { entrada ->
                PremiumCard(colors, Modifier.clickable { abrirResultado(entrada) }) {
                    Text("${entrada.data?.let(TextoFormatter::dataPorExtenso) ?: "Página ${entrada.pagina}"} · ${entrada.trecho}", color = colors.text)
                }
            }
            if (paginas.size == quantidade) item {
                TextButton(onClick = { quantidade += 50 }) { Text("Carregar mais páginas") }
            }
        }
    }
}

@Composable
internal fun OfficialSourcesScreen(colors: Palette, prefs: PreferencesStore, onSaved: (String) -> Unit) {
    var title by remember { mutableStateOf("") }
    var origin by remember { mutableStateOf("") }
    var url by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }
    var sources by remember { mutableStateOf(prefs.officialSources()) }

    LazyColumn(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            PremiumCard(colors) {
                Text("Fontes oficiais", color = colors.text, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                Text("Cadastre referências institucionais confiáveis para orientar estudos e análises por IA.", color = colors.secondary)
                OutlinedTextField(title, { title = it }, modifier = Modifier.fillMaxWidth(), label = { Text("Título da fonte") }, singleLine = true)
                OutlinedTextField(origin, { origin = it }, modifier = Modifier.fillMaxWidth(), label = { Text("Origem institucional") }, singleLine = true)
                OutlinedTextField(url, { url = it }, modifier = Modifier.fillMaxWidth(), label = { Text("URL oficial") }, singleLine = true)
                OutlinedTextField(notes, { notes = it }, modifier = Modifier.fillMaxWidth().heightIn(min = 110.dp), label = { Text("Observações") })
                Button(onClick = {
                    if (title.isBlank() || origin.isBlank()) {
                        onSaved("Informe ao menos título e origem da fonte.")
                    } else {
                        prefs.saveOfficialSource(title, origin, url, notes)
                        title = ""
                        origin = ""
                        url = ""
                        notes = ""
                        sources = prefs.officialSources()
                        onSaved("Fonte oficial salva.")
                    }
                }) {
                    Icon(Icons.Default.CheckCircle, null)
                    Spacer(Modifier.width(8.dp))
                    Text("Salvar fonte oficial")
                }
            }
        }
        items(sources) { source ->
            PremiumCard(colors) {
                Text(source.title, color = colors.text, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Text(source.origin, color = colors.accent, fontSize = 13.sp)
                if (source.url.isNotBlank()) {
                    Text(source.url, color = colors.secondary, fontSize = 13.sp)
                }
                if (source.notes.isNotBlank()) {
                    Text(source.notes, color = colors.secondary)
                }
                Button(onClick = {
                    prefs.removeOfficialSource(source.id)
                    sources = prefs.officialSources()
                    onSaved("Fonte oficial removida.")
                }) {
                    Icon(Icons.Default.Delete, null)
                    Spacer(Modifier.width(6.dp))
                    Text("Remover")
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun RequestWorkScreen(colors: Palette, prefs: PreferencesStore, onSaved: (String) -> Unit) {
    val context = LocalContext.current
    var area by remember { mutableStateOf(BibliotecaArea.Biblioteca) }
    var title by remember { mutableStateOf("") }
    var author by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }
    var requests by remember { mutableStateOf(prefs.workRequests()) }

    LazyColumn(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            PremiumCard(colors) {
                Text("Solicitar obra", color = colors.text, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                Text("Registre uma sugestão de obra para inclusão futura na biblioteca.", color = colors.secondary)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    BibliotecaArea.entries.forEach { item ->
                        AssistChip(
                            onClick = { area = item },
                            label = { Text(item.titulo, color = if (item == area) Color.Black else colors.text) },
                            leadingIcon = { if (item == area) Icon(Icons.Default.CheckCircle, null, tint = Color(0xFF1F7A3A)) }
                        )
                    }
                }
                OutlinedTextField(title, { title = it }, modifier = Modifier.fillMaxWidth(), label = { Text("Título da obra") }, singleLine = true)
                OutlinedTextField(author, { author = it }, modifier = Modifier.fillMaxWidth(), label = { Text("Autor ou origem") }, singleLine = true)
                OutlinedTextField(notes, { notes = it }, modifier = Modifier.fillMaxWidth().heightIn(min = 140.dp), label = { Text("Observações") })
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(onClick = {
                        if (title.isBlank()) {
                            onSaved("Informe o título da obra.")
                        } else {
                            prefs.saveWorkRequest(area.titulo, title, author, notes)
                            requests = prefs.workRequests()
                            onSaved("Solicitação salva.")
                            title = ""
                            author = ""
                            notes = ""
                        }
                    }) {
                        Icon(Icons.Default.CheckCircle, null)
                        Spacer(Modifier.width(6.dp))
                        Text("Salvar")
                    }
                    Button(onClick = {
                        shareText(context, textoSolicitacaoObra(area.titulo, title, author, notes))
                    }) {
                        Icon(Icons.Default.IosShare, null)
                        Spacer(Modifier.width(6.dp))
                        Text("Compartilhar")
                    }
                }
            }
        }
        items(requests) { request ->
            PremiumCard(colors) {
                Text(request.title, color = colors.text, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Text(request.area, color = colors.accent, fontSize = 13.sp)
                if (request.author.isNotBlank()) Text(request.author, color = colors.secondary, fontSize = 13.sp)
                if (request.notes.isNotBlank()) Text(request.notes, color = colors.secondary)
            }
        }
    }
}
