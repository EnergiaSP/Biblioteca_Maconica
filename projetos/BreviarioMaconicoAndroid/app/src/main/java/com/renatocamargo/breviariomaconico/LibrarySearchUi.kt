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
internal fun StructuredSearchScreen(colors: Palette, termoInicial: String = "", abrirResultado: (BibliotecaBuscaResultado) -> Unit) {
    val context = LocalContext.current
    val catalogo = remember { BibliotecaCatalogRepository.get(context) }
    val scope = rememberCoroutineScope()
    var termo by remember { mutableStateOf(termoInicial) }
    var metadataFilter by remember { mutableStateOf(LibraryMetadataFilter()) }
    var area by remember { mutableStateOf<BibliotecaArea?>(null) }
    var obraId by remember { mutableStateOf<String?>(null) }
    var obras by remember { mutableStateOf(emptyList<com.renatocamargo.breviariomaconico.data.BibliotecaObraCatalogo>()) }
    var escolherObra by remember { mutableStateOf(false) }
    var resultados by remember { mutableStateOf(emptyList<BibliotecaBuscaResultado>()) }
    var mensagem by remember { mutableStateOf("Digite um termo para buscar nas obras baixadas.") }
    var buscando by remember { mutableStateOf(false) }
    var temMais by remember { mutableStateOf(false) }
    var consultaJob by remember { mutableStateOf<Job?>(null) }

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
        consultaJob?.cancel()
        resultados = emptyList()
        temMais = false
        buscando = false
        delay(350)
        pesquisar()
    }
    DisposableEffect(Unit) { onDispose { consultaJob?.cancel() } }
    LaunchedEffect(area) {
        obraId = null
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
private fun MetadataFilterFields(colors: Palette, filter: LibraryMetadataFilter, onChange: (LibraryMetadataFilter) -> Unit) {
    OutlinedTextField(value = filter.autor, onValueChange = { onChange(filter.copy(autor = it)) },
        label = { Text("Filtrar por autor") }, modifier = Modifier.fillMaxWidth().testTag("search.author"),
        singleLine = true, colors = librarySearchFieldColors(colors))
    OutlinedTextField(value = filter.assunto, onValueChange = { onChange(filter.copy(assunto = it)) },
        label = { Text("Filtrar por assunto") }, modifier = Modifier.fillMaxWidth().testTag("search.subject"),
        singleLine = true, colors = librarySearchFieldColors(colors))
}

@Composable
private fun librarySearchFieldColors(colors: Palette) = OutlinedTextFieldDefaults.colors(
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

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun DossierScreen(colors: Palette, abrirResultado: (BibliotecaBuscaResultado) -> Unit) {
    val context = LocalContext.current
    val catalogo = remember { BibliotecaCatalogRepository.get(context) }
    val prefs = remember { PreferencesStore(context) }
    val scope = rememberCoroutineScope()
    var tema by remember { mutableStateOf("") }
    var metadataFilter by remember { mutableStateOf(LibraryMetadataFilter()) }
    var resultados by remember { mutableStateOf(emptyList<BibliotecaBuscaResultado>()) }
    var status by remember { mutableStateOf("Informe um tema para montar um dossiê com fontes do acervo baixado.") }
    var analiseIa by remember { mutableStateOf("") }
    var gerandoIa by remember { mutableStateOf(false) }
    var montando by remember { mutableStateOf(false) }
    var area by remember { mutableStateOf<BibliotecaArea?>(null) }
    var obraId by remember { mutableStateOf<String?>(null) }
    var obras by remember { mutableStateOf(emptyList<com.renatocamargo.breviariomaconico.data.BibliotecaObraCatalogo>()) }
    var escolherObra by remember { mutableStateOf(false) }
    var consultaJob by remember { mutableStateOf<Job?>(null) }
    var analiseJob by remember { mutableStateOf<Job?>(null) }
    val studyPlan = remember(tema, resultados) { buildDossierStudyPlan(tema, resultados) }
    val resumoEscopo = listOf(obras.firstOrNull { it.id == obraId }?.titulo ?: area?.titulo ?: "Toda a biblioteca",
        metadataFilter.descricao).filter { it.isNotEmpty() }.joinToString(" • ")

    fun invalidar() {
        consultaJob?.cancel()
        analiseJob?.cancel()
        resultados = emptyList()
        analiseIa = ""
        montando = false
        gerandoIa = false
        status = "Gere o dossiê para consultar a seleção atual."
    }
    LaunchedEffect(area) {
        obras = emptyList()
        libraryQuery { catalogo.obrasDisponiveis(area) }.onSuccess { obras = it }
    }

    LazyColumn(Modifier.fillMaxSize().padding(18.dp).testTag("dossier.list"), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            PremiumCard(colors) {
                Text("Dossiê de estudos", color = colors.text, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                Text("Gera um roteiro documental com base apenas nos trechos encontrados nas obras baixadas.", color = colors.secondary)
                OutlinedTextField(
                    value = tema,
                    onValueChange = { invalidar(); tema = it },
                    modifier = Modifier.fillMaxWidth().testTag("dossier.topic"),
                    label = { Text("Tema, símbolo, frase ou assunto") },
                    leadingIcon = { Icon(Icons.Default.Search, null) },
                    singleLine = true,
                    colors = librarySearchFieldColors(colors)
                )
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    val chipColors = FilterChipDefaults.filterChipColors(labelColor = colors.text,
                        selectedContainerColor = colors.accentSurface, selectedLabelColor = colors.onAccent)
                    FilterChip(selected = area == null, onClick = { invalidar(); area = null; obraId = null },
                        label = { Text("Todo acervo") }, colors = chipColors)
                    BibliotecaArea.entries.forEach { item ->
                        FilterChip(selected = area == item, onClick = { invalidar(); area = item; obraId = null },
                            label = { Text(item.titulo) }, colors = chipColors)
                    }
                }
                Box {
                    TextButton(onClick = { escolherObra = true }) {
                        Text(obras.firstOrNull { it.id == obraId }?.titulo ?: "Todas as obras da seleção", color = colors.text)
                    }
                    DropdownMenu(expanded = escolherObra, onDismissRequest = { escolherObra = false }) {
                        DropdownMenuItem(text = { Text("Todas as obras da seleção") }, onClick = {
                            invalidar(); obraId = null; escolherObra = false
                        })
                        obras.forEach { obra ->
                            DropdownMenuItem(text = { Text(obra.titulo) }, onClick = {
                                invalidar(); obraId = obra.id; escolherObra = false
                            })
                        }
                    }
                }
                MetadataFilterFields(colors, metadataFilter) { invalidar(); metadataFilter = it }
                Button(colors = libraryActionColors(colors), enabled = tema.isNotBlank() && !montando && !gerandoIa, onClick = {
                    invalidar()
                    val consulta = tema.trim()
                    val areaSelecionada = area
                    val obraSelecionada = obraId
                    val filtroSelecionado = metadataFilter
                    montando = true
                    status = "Consultando as obras baixadas..."
                    consultaJob = scope.launch {
                        val requestContext = currentCoroutineContext()
                        try {
                            analiseIa = ""
                            libraryQuery { catalogo.buscarConteudo(consulta, areaSelecionada, obraSelecionada,
                                limite = 30, cancelled = { !requestContext.isActive }, filtro = filtroSelecionado) }
                                .onSuccess {
                                    resultados = it
                                    status = if (it.isEmpty()) "Não encontrei base documental suficiente nas obras baixadas." else "Dossiê criado com ${it.size} fonte(s) documentais."
                                }.onFailure {
                                    resultados = emptyList()
                                    status = "Não foi possível montar o dossiê. Verifique os downloads no Acervo e tente novamente."
                                }
                        } finally {
                            if (requestContext.isActive) montando = false
                        }
                    }
                }) {
                    Text(if (montando) "Montando..." else "Gerar dossiê")
                }
                FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(colors = libraryActionColors(colors), enabled = resultados.isNotEmpty(), onClick = {
                        shareText(context, textoDossie(tema, resultados, analiseIa, resumoEscopo))
                    }) {
                        Icon(Icons.Default.IosShare, null)
                        Spacer(Modifier.width(6.dp))
                        Text("Compartilhar")
                    }
                    Button(colors = libraryActionColors(colors), enabled = resultados.isNotEmpty(), onClick = {
                        shareDossierPdf(context, tema, resultados, analiseIa, resumoEscopo, prefs.settings.premiumPdfName)
                    }) {
                        Icon(Icons.Default.PictureAsPdf, null)
                        Spacer(Modifier.width(6.dp))
                        Text("PDF")
                    }
                }
                Button(colors = libraryActionColors(colors), enabled = resultados.isNotEmpty() && !gerandoIa, onClick = {
                    val settings = prefs.settings
                    if (!settings.aiEnabled) {
                        Toast.makeText(context, "Ative a IA nas configurações.", Toast.LENGTH_LONG).show()
                        return@Button
                    }
                    if (settings.geminiApiKey.isBlank()) {
                        Toast.makeText(context, "Informe a chave Gemini nas configurações.", Toast.LENGTH_LONG).show()
                        return@Button
                    }
                    gerandoIa = true
                    val fontes = resultados.toList()
                    val consulta = tema
                    analiseJob = scope.launch {
                        try {
                        val resultado = libraryQuery {
                                GeminiService.gerarTexto(promptAnaliseDossie(consulta, fontes, prefs.officialSources()), settings.geminiApiKey)
                                    .also { GeminiService.validarCitacoes(it, fontes.size) }
                        }
                        resultado.onSuccess { texto ->
                            if (tema == consulta && resultados == fontes) {
                                analiseIa = texto
                                Toast.makeText(context, "Análise do dossiê gerada.", Toast.LENGTH_LONG).show()
                            }
                        }.onFailure { erro ->
                            Toast.makeText(context, erro.message ?: "Não foi possível gerar a análise.", Toast.LENGTH_LONG).show()
                        }
                        } finally {
                            if (currentCoroutineContext().isActive) gerandoIa = false
                        }
                    }
                }) {
                    Icon(Icons.Default.TextFields, null)
                    Spacer(Modifier.width(6.dp))
                    Text(if (gerandoIa) "Gerando análise..." else "Gerar análise IA")
                }
                Text(status, modifier = Modifier.testTag("dossier.status"), color = colors.accent, fontWeight = FontWeight.SemiBold)
            }
        }
        if (analiseIa.isNotBlank()) {
            item {
                PremiumCard(colors) {
                    Text("Análise IA", color = colors.text, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                    Text(analiseIa, color = colors.secondary, lineHeight = 21.sp)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(colors = libraryActionColors(colors), onClick = { copyText(context, analiseIa) }) {
                            Icon(Icons.Default.ContentCopy, null)
                            Spacer(Modifier.width(6.dp))
                            Text("Copiar")
                        }
                        Button(colors = libraryActionColors(colors), onClick = { shareText(context, analiseIa) }) {
                            Icon(Icons.Default.IosShare, null)
                            Spacer(Modifier.width(6.dp))
                            Text("Compartilhar")
                        }
                    }
                }
            }
        }
        if (resultados.isNotEmpty()) {
            item(key = "dossier.plan") {
                PremiumCard(colors) {
                    Text("Roteiro de estudo", modifier = Modifier.testTag("dossier.results"), color = colors.text, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                    studyPlan.roadmap.forEachIndexed { index, stage ->
                        Text("${index + 1}. $stage", color = colors.secondary)
                    }
                }
            }
            item {
                PremiumCard(colors) {
                    Text("Perguntas de fixação", color = colors.text, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                    studyPlan.questions.forEach { question -> Text("• $question", color = colors.secondary) }
                }
            }
            item {
                PremiumCard(colors) {
                    Text("Mapa conceitual", color = colors.text, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                    studyPlan.conceptMap.forEach { relation -> Text("• $relation", color = colors.secondary) }
                }
            }
            item {
                PremiumCard(colors) {
                    Text("Revisão espaçada", color = colors.text, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                    studyPlan.spacedReview.forEach { stage -> Text("• $stage", color = colors.secondary) }
                }
            }
            item {
                PremiumCard(colors) {
                    Text("Cruzamento documental", color = colors.text, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                    studyPlan.crossReferences.forEach { crossing -> Text("• $crossing", color = colors.secondary) }
                }
            }
            item {
                PremiumCard(colors) {
                    Text("Termos relacionados", color = colors.text, fontWeight = FontWeight.Bold)
                    Text(studyPlan.relatedTerms.joinToString(", "), color = colors.secondary)
                    Text("Limites da base", color = colors.text, fontWeight = FontWeight.Bold)
                    studyPlan.limits.forEach { Text("• $it", color = colors.secondary) }
                }
            }
        }
        items(resultados, key = { it.id }) { resultado ->
            SearchResultCard(colors, resultado, abrirResultado)
        }
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
private fun libraryActionColors(colors: Palette) = androidx.compose.material3.ButtonDefaults.buttonColors(
    containerColor = colors.accentSurface,
    contentColor = colors.onAccent,
    disabledContainerColor = colors.surface,
    disabledContentColor = colors.secondary
)
