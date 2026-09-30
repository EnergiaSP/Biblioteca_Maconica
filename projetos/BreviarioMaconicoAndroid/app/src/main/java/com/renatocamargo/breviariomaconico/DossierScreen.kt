package com.renatocamargo.breviariomaconico

import com.renatocamargo.breviariomaconico.data.ReviewCardStore
import com.renatocamargo.breviariomaconico.data.ActiveReview
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.platform.LocalFocusManager
import com.renatocamargo.breviariomaconico.data.AssistedInterpretation
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.filled.BookmarkAdd
import com.renatocamargo.breviariomaconico.data.SavedDossier
import com.renatocamargo.breviariomaconico.data.SavedDossierStore
import com.renatocamargo.breviariomaconico.data.StudyNotebook
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
internal fun DossierScreen(
    colors: Palette,
    session: LibraryStudySession = remember { LibraryStudySession(MENSAGEM_INICIAL_DOSSIE) },
    abrirResultado: (BibliotecaBuscaResultado) -> Unit
) {
    val context = LocalContext.current
    val catalogo = remember { BibliotecaCatalogRepository.get(context) }
    val prefs = remember { PreferencesStore(context) }
    val scope = rememberCoroutineScope()
    val focusManager = LocalFocusManager.current
    var tema by session::termo
    var metadataFilter by session::metadataFilter
    var resultados by session::resultados
    var status by session::status
    var analiseIa by session::analiseIa
    var study by session::dossierStudy
    val dossierConfig = remember { DossierAnalysis.loadConfig(context) }
    var gerandoIa by remember { mutableStateOf(false) }
    var montando by remember { mutableStateOf(false) }
    var area by session::area
    var obraId by session::obraId
    var obras by remember { mutableStateOf(emptyList<com.renatocamargo.breviariomaconico.data.BibliotecaObraCatalogo>()) }
    var escolherObra by remember { mutableStateOf(false) }
    var consultaJob by remember { mutableStateOf<Job?>(null) }
    var analiseJob by remember { mutableStateOf<Job?>(null) }
    val studyPlan = remember(tema, resultados, study) { buildDossierStudyPlan(tema, resultados, study) }
    val savedStore = remember { SavedDossierStore(context) }
    val reviewConfig = remember { ActiveReview.loadConfig(context) }
    val cardStore = remember { ReviewCardStore(context) }
    var reviewRefresh by remember { mutableIntStateOf(0) }
    var savedList by remember { mutableStateOf(savedStore.all()) }
    val currentSaved = savedList.firstOrNull { it.id == session.savedDossierId }
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
        study = null
        session.savedDossierId = null
    }

    /** Builds the dossier for the current fields; a saved one keeps its review dates. */
    fun gerar(saved: SavedDossier? = null) {
        invalidar()
        session.savedDossierId = saved?.id
        val consulta = tema.trim()
        val areaSelecionada = area
        val obraSelecionada = obraId
        val filtroSelecionado = metadataFilter
        val base = saved?.createdDate ?: java.time.LocalDate.now()
        montando = true
        status = "Consultando as obras baixadas..."
        consultaJob = scope.launch {
            val requestContext = currentCoroutineContext()
            try {
                analiseIa = ""
                libraryQuery {
                    val todos = catalogo.buscarConteudo(dossierQuery(consulta), areaSelecionada, obraSelecionada,
                        limite = dossierConfig.limits.analyzedSources, cancelled = { !requestContext.isActive },
                        filtro = filtroSelecionado, variants = dossierConfig.variants)
                    todos to analyzeDossier(consulta, todos, dossierConfig, base, reviewConfig)
                }
                    .onSuccess { (todos, analise) ->
                        resultados = todos.take(dossierConfig.limits.shownSources)
                        study = analise
                        // A saved dossier shows the interpretation generated for it before.
                        analiseIa = saved?.let { savedStore.find(it.id)?.interpretacao?.text }.orEmpty()
                        // A reopened saved dossier gets the cards it does not have yet; stored ones keep their progress.
                        if (saved != null) {
                            cardStore.add(analise.cards, saved.id, saved.tema, java.time.LocalDate.now().toString())
                            reviewRefresh++
                        }
                        status = if (todos.isEmpty()) "Não encontrei base documental suficiente nas obras baixadas." else "Dossiê criado com ${todos.size} fonte(s) documentais."
                    }.onFailure {
                        resultados = emptyList()
                        study = null
                        status = "Não foi possível montar o dossiê. Verifique os downloads no Acervo e tente novamente."
                    }
            } finally {
                if (requestContext.isActive) montando = false
            }
        }
    }

    fun abrirSalvo(saved: SavedDossier) {
        tema = saved.tema
        area = BibliotecaArea.entries.firstOrNull { it.raw == saved.area }
        obraId = saved.obraId
        metadataFilter = LibraryMetadataFilter(saved.autor, saved.assunto)
        gerar(saved)
    }

    fun salvar() {
        val chave = SavedDossier.chave(tema, area?.raw, obraId, metadataFilter.autor, metadataFilter.assunto)
        val found = savedStore.findByKey(chave) ?: SavedDossier(java.util.UUID.randomUUID().toString(), tema.trim(), area?.raw,
            obraId, metadataFilter.autor.trim(), metadataFilter.assunto.trim(), java.time.LocalDate.now().toString())
        val saved = StudyNotebook.Interpretation.toKeep(analiseIa, found.interpretacao)?.let { found.copy(interpretacao = it) } ?: found
        savedStore.save(saved)
        DossierReminders.schedule(context, saved, dossierConfig)
        savedList = savedStore.all()
        session.savedDossierId = saved.id
        val created = cardStore.add(study?.cards.orEmpty(), saved.id, saved.tema, java.time.LocalDate.now().toString())
        reviewRefresh++
        status = "Dossiê salvo. Você será lembrado de cada revisão." +
            (if (created == 0) "" else " " + reviewConfig.label("criados", mapOf("n" to "$created")))
    }

    /** Keeps the interpretation just generated with the dossier, when it is saved. */
    fun guardarInterpretacao(texto: String): Boolean {
        val saved = session.savedDossierId?.let { savedStore.find(it) } ?: return false
        val interpretation = StudyNotebook.Interpretation.toKeep(texto, saved.interpretacao) ?: return false
        savedStore.save(saved.copy(interpretacao = interpretation))
        savedList = savedStore.all()
        return true
    }

    fun alternarRevisao(saved: SavedDossier, days: Int) {
        val updated = saved.toggled(days)
        savedStore.save(updated)
        DossierReminders.schedule(context, updated, dossierConfig)
        savedList = savedStore.all()
    }

    fun excluir(saved: SavedDossier) {
        DossierReminders.cancel(context, saved, dossierConfig)
        savedStore.remove(saved.id)
        cardStore.removeDossier(saved.id)
        reviewRefresh++
        if (session.savedDossierId == saved.id) session.savedDossierId = null
        savedList = savedStore.all()
        status = "Dossiê \"${saved.tema}\" excluído."
    }
    LaunchedEffect(session.pendingSavedDossierId) {
        val id = session.pendingSavedDossierId ?: return@LaunchedEffect
        session.pendingSavedDossierId = null
        savedList = savedStore.all()
        savedStore.find(id)?.let(::abrirSalvo) ?: run { status = "Este dossiê salvo foi excluído." }
    }
    LaunchedEffect(area) {
        obras = emptyList()
        libraryQuery { catalogo.obrasDisponiveis(area) }.onSuccess { obras = it }
    }
    DisposableEffect(Unit) {
        onDispose { if (montando) status = "Montagem interrompida. Toque em gerar dossiê novamente." }
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
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(onSearch = {
                        focusManager.clearFocus()
                        if (tema.isNotBlank() && !montando && !gerandoIa) gerar()
                    }),
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
                    gerar()
                }) {
                    Text(if (montando) "Montando..." else "Gerar dossiê")
                }
                FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(colors = libraryActionColors(colors), enabled = resultados.isNotEmpty() && !montando && currentSaved == null,
                        modifier = Modifier.testTag("dossier.save"), onClick = { salvar() }) {
                        Icon(Icons.Default.BookmarkAdd, null)
                        Spacer(Modifier.width(6.dp))
                        Text(if (currentSaved == null) "Salvar" else "Salvo")
                    }
                    Button(colors = libraryActionColors(colors), enabled = resultados.isNotEmpty(), onClick = {
                        shareText(context, textoDossie(tema, resultados, analiseIa, resumoEscopo, study))
                    }) {
                        Icon(Icons.Default.IosShare, null)
                        Spacer(Modifier.width(6.dp))
                        Text("Compartilhar")
                    }
                    Button(colors = libraryActionColors(colors), enabled = resultados.isNotEmpty(), onClick = {
                        shareDossierPdf(context, tema, resultados, analiseIa, resumoEscopo, prefs.settings.premiumPdfName, study)
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
                    val iaConfig = AssistedInterpretation.loadConfig(context)
                    analiseJob = scope.launch {
                        try {
                        val resultado = libraryQuery {
                                val sources = dossierSources(fontes)
                                val resposta = GeminiService.gerarTexto(promptAnaliseDossie(context, consulta, fontes, prefs.officialSources()), settings.geminiApiKey)
                                // Only sentences citing the dossier excerpts are kept; the rest is removed, not shown.
                                val filtered = AssistedInterpretation.filter(resposta, sources, iaConfig)
                                AssistedInterpretation.display(filtered, sources, iaConfig, dossierConfig)
                        }
                        resultado.onSuccess { texto ->
                            if (tema == consulta && resultados == fontes) {
                                analiseIa = texto
                                val guardada = guardarInterpretacao(texto)
                                Toast.makeText(context, if (texto.isEmpty()) iaConfig.labels.nothingKept
                                    else if (guardada) "Interpretação assistida gerada e guardada no dossiê salvo." else "Interpretação assistida gerada.",
                                    Toast.LENGTH_LONG).show()
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
                    Text(if (gerandoIa) "Gerando interpretação..." else "Gerar interpretação assistida")
                }
                if (resultados.isNotEmpty()) {
                    Text("A IA recebe somente os ${resultados.size} trechos exibidos neste dossiê. Ficam apenas as frases que citam um trecho; o resto é removido.",
                        color = colors.secondary, fontSize = 13.sp)
                }
                Text(status, modifier = Modifier.testTag("dossier.status"), color = colors.accent, fontWeight = FontWeight.SemiBold)
            }
        }
        // After the form, so building a dossier stays the first action (as on iOS).
        item(key = "review.summary") { ActiveReviewSummary(colors, cardStore, reviewConfig, reviewRefresh) { reviewRefresh++ } }
        if (savedList.isNotEmpty()) {
            item(key = "dossier.saved") {
                SavedDossiersCard(colors, savedList, dossierConfig.review, enabled = !montando, onOpen = ::abrirSalvo, onDelete = ::excluir)
            }
        }
        currentSaved?.takeIf { resultados.isNotEmpty() }?.let { saved ->
            item(key = "dossier.reviews") {
                SavedDossierReviewsCard(colors, saved, dossierConfig.review, dossierConfig.reviewReminder) { alternarRevisao(saved, it) }
            }
        }
        if (analiseIa.isNotBlank()) {
            item {
                PremiumCard(colors) {
                    // The text starts with its own title ("Interpretação assistida por IA") and notice.
                    SelectionContainer { Text(analiseIa, color = colors.secondary, lineHeight = 21.sp, modifier = Modifier.testTag("dossier.ai")) }
                    Text(if (currentSaved == null) "Salve o dossiê para guardar esta interpretação no caderno de estudo."
                        else "Guardada com o dossiê salvo; entra no caderno de estudo e na sincronização.",
                        color = colors.secondary, fontSize = 13.sp, modifier = Modifier.testTag("dossier.ai.saved"))
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
        study?.takeIf { resultados.isNotEmpty() }?.let { current ->
            item(key = "dossier.analysis") { DossierAnalysisSections(colors, current.display) }
            item(key = "dossier.map") { DossierConceptMap(colors, tema.trim(), current.related) }
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
