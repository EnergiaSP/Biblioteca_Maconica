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
import com.renatocamargo.breviariomaconico.data.StudyRules
import com.renatocamargo.breviariomaconico.data.ScoredItem
import com.renatocamargo.breviariomaconico.data.StudyIndex
import com.renatocamargo.breviariomaconico.data.scoreStudy
import com.renatocamargo.breviariomaconico.data.studyItems
import com.renatocamargo.breviariomaconico.data.localStudySelection
import com.renatocamargo.breviariomaconico.data.BibliotecaObraCatalogo
import com.renatocamargo.breviariomaconico.data.PersonalReflection
import com.renatocamargo.breviariomaconico.data.ObraId
import kotlinx.coroutines.CancellationException
import com.renatocamargo.breviariomaconico.data.TextHighlight
import com.renatocamargo.breviariomaconico.data.TextoFormatter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.isActive
import kotlinx.coroutines.ensureActive
import java.io.File
import java.time.LocalDate
import java.util.Calendar
import java.util.Locale

@Composable
internal fun ItemListScreen(title: String, colors: Palette, items: List<BreviarioItem>, onRead: (BreviarioItem) -> Unit) {
    ItemSearchList(title, colors, items, null, "Selecionar data", {}, onRead)
}

@Composable
internal fun ItemSearchList(
    title: String,
    colors: Palette,
    items: List<BreviarioItem>,
    search: String?,
    label: String,
    onSearch: (String) -> Unit,
    onRead: (BreviarioItem) -> Unit
) {
    LazyColumn(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item {
            Text(title, color = colors.text, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            if (search != null) {
                OutlinedTextField(search, onSearch, modifier = Modifier.fillMaxWidth(), label = { Text(label) })
            }
        }
        items(items) { item -> ReadingCard(colors, item, onRead) }
    }
}

@Composable
internal fun ReadingCard(colors: Palette, item: BreviarioItem, onRead: (BreviarioItem) -> Unit) {
    PremiumCard(colors, Modifier.clickable { onRead(item) }) {
        Text(TextoFormatter.dataPorExtenso(item.data), color = colors.accent, fontWeight = FontWeight.Bold)
        Text(item.titulo, color = colors.text, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text(item.texto.take(180), color = colors.secondary, maxLines = 3, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
internal fun StatsScreen(colors: Palette, repo: BreviarioRepository, prefs: PreferencesStore) {
    val favorites = prefs.favoriteItems(repo.itens)
    val readItems = prefs.readItems(repo.itens)
    val comments = prefs.commentedItems(repo.itens)
    val percent = ReadingMetricsController.percentage(readItems.size, repo.itens.size)
    LazyColumn(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { StatCard(colors, "Progresso", "$percent%") }
        item { StatCard(colors, "Leituras concluídas", "${readItems.size}/${repo.itens.size}") }
        item { StatCard(colors, "Favoritos", favorites.size.toString()) }
        item { StatCard(colors, "Comentários", comments.size.toString()) }
    }
}

@Composable
internal fun StatCard(colors: Palette, title: String, value: String) {
    PremiumCard(colors) {
        Text(title, color = colors.secondary)
        Text(value, color = colors.text, fontSize = 30.sp, fontWeight = FontWeight.Bold)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun CollectionsScreen(
    colors: Palette,
    repo: BreviarioRepository,
    onRead: (BreviarioItem) -> Unit,
    abrirObra: (String, Int?) -> Unit,
    cache: StudyContentCache = remember { StudyContentCache() }
) {
    val context = LocalContext.current
    var snapshot by remember(repo) { mutableStateOf<StudyScreenContent?>(null) }
    var loadingError by remember(repo) { mutableStateOf<String?>(null) }
    LaunchedEffect(repo) {
        try {
            snapshot = withContext(Dispatchers.IO) {
                val rules = StudyRules.load(context)
                val prefs = PreferencesStore(context)
                val readings = repo.itens.map { prefs.applyTextEdit(it) }
                val catalog = BibliotecaCatalogRepository.get(context)
                val works = catalog.obrasInstaladas()
                val reflectionsNow = prefs.reflectionHistory(readings, works.associate { it.id to it.titulo })
                // Reopening the tab reuses the collections while works, downloads and readings are unchanged.
                val key = listOf(works.joinToString(",") { it.id },
                    catalog.pacotes.map { catalog.localFile(it) }.filter { it.exists() }.distinct().sortedBy { it.path }.joinToString(",") { "${it.name}:${it.length()}" },
                    readings.sumOf { it.texto.length + it.titulo.length }.toString()).joinToString("|")
                cache.reusable(key)?.let { cached -> return@withContext cached.copy(reflections = reflectionsNow) }
                val collectionWords = rules.collections.associate { it.id to it.keywords.map(StudyRules::studyNormalized) }
                val pathWords = rules.paths.associate { it.id to it.keywords.map(StudyRules::studyNormalized) }
                val local = localStudySelection(readings, repo.indice, rules)
                val collections = rules.collections.associate { it.id to local.getValue(it.id) }.toMutableMap()
                val paths = rules.paths.associate { it.id to local.getValue(it.id) }.toMutableMap()
                val dailyWorkIds = readings.map { it.obraId }.toSet()
                val jobContext = currentCoroutineContext()
                val failedWorks = mutableListOf<String>()
                val pendingWorks = works.filterNot { it.id in dailyWorkIds }
                val reflections = reflectionsNow
                suspend fun publish(completed: Int) {
                    val partial = StudyScreenContent(rules, works, collections.mapValues { entry -> entry.value.map { it.item } },
                        paths.mapValues { entry -> entry.value.map { it.item } },
                        reflections, failedWorks.toList(), completed, pendingWorks.size)
                    withContext(Dispatchers.Main) { snapshot = partial }
                }
                publish(0)
                // Downloaded works are scored on their FTS index: every page counts, and only the best are loaded.
                val ruleWords = (rules.collections.map { collectionWords.getValue(it.id) } + rules.paths.map { pathWords.getValue(it.id) })
                    .map(StudyRules::studyKeywords)
                val limits = List(rules.collections.size) { rules.collectionLimit } + List(rules.paths.size) { rules.pathLimit }
                val (scores, failures) = catalog.scoreStudy(pendingWorks.map { it.id }.toSet(), ruleWords, limits)
                failedWorks.addAll(failures)
                val loaded = scores.flatten().groupBy({ it.ref.obraId }, { it.ref.pagina }).flatMap { (workId, pages) ->
                    jobContext.ensureActive()
                    catalog.studyItems(workId, pages)
                }.associateBy { StudyIndex.PageRef(it.obraId, it.pagina) }
                val ruleIds = rules.collections.map { it.id } + rules.paths.map { it.id }
                ruleIds.forEachIndexed { index, id ->
                    // Index scores are kept as they are, so both platforms rank catalog pages identically.
                    val fromCatalog = scores[index].mapNotNull { score -> loaded[score.ref]?.let { ScoredItem(it, score.topics, score.occurrences) } }
                    val target = if (index < rules.collections.size) collections else paths
                    target[id] = StudyRules.incorporateCounts(target[id].orEmpty() + fromCatalog, emptyList(), ruleWords[index], emptyMap(), limits[index])
                }
                StudyScreenContent(rules, works, collections.mapValues { entry -> entry.value.map { it.item } },
                    paths.mapValues { entry -> entry.value.map { it.item } },
                    reflections, failedWorks, pendingWorks.size, pendingWorks.size)
                    .also { if (failedWorks.isEmpty()) cache.store(key, it) }
            }
        } catch (error: CancellationException) { throw error }
        catch (_: Exception) { loadingError = "Não foi possível carregar as coleções." }
    }
    val content = snapshot
    if (content == null) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            if (loadingError != null) Text(loadingError!!, color = colors.text)
            else androidx.compose.material3.CircularProgressIndicator()
        }
        return
    }
    val rules = content.rules
    val reflectionHistory = content.reflections
    val studyPaths = rules.paths
    val audio = rememberAudioSequence()
    fun openReading(item: BreviarioItem) {
        if (item.data.startsWith("P")) abrirObra(item.obraId, item.pagina) else onRead(item)
    }
    LazyColumn(Modifier.fillMaxSize().padding(18.dp).testTag("study.list"), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Text("Coleções temáticas", color = colors.text, fontSize = 26.sp, fontWeight = FontWeight.Bold)
            if (content.completedWorks < content.totalWorks) {
                Text("Atualizando referências: ${content.completedWorks} de ${content.totalWorks} obras", color = colors.secondary,
                    modifier = Modifier.testTag("study.progress"))
                androidx.compose.material3.LinearProgressIndicator(
                    progress = { content.completedWorks.toFloat() / content.totalWorks }, modifier = Modifier.fillMaxWidth())
            }
            if (content.failedWorks.isNotEmpty()) Text("Não foi possível consultar algumas obras: ${content.failedWorks.joinToString(", ")}", color = colors.text)
        }
        if (audio.title != null) item(key = "audio.sequence") { AudioSequenceBar(colors, audio) }
        rules.collections.forEach { collection ->
            item(key = "collection:${collection.id}") {
                val matches = content.collections[collection.id].orEmpty()
                StudyCollectionCard(collection, matches, colors, content::readingLabel, ::openReading) {
                    AudioSequenceButton(colors, audio, collection.title) { audio.play(collection.title, matches) }
                }
            }
        }
        item {
            Text("Trilhas de estudo", color = colors.text, fontSize = 24.sp, fontWeight = FontWeight.Bold)
        }
        studyPaths.forEach { path ->
            item(key = "path:${path.id}") {
                val relatedReadings = content.paths[path.id].orEmpty()
                PremiumCard(colors) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(path.title, color = colors.text, fontSize = 21.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                        AudioSequenceButton(colors, audio, path.title) { audio.play(path.title, relatedReadings) }
                    }
                    Text(path.subtitle, color = colors.secondary)
                    Text(path.objective, color = colors.secondary)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(path.instruction, color = colors.accent, fontWeight = FontWeight.SemiBold)
                        Text(path.suggestedDuration, color = colors.accent, fontWeight = FontWeight.SemiBold)
                    }
                    path.stages.forEachIndexed { index, stage ->
                        Text("${index + 1}. $stage", color = colors.text)
                    }
                    relatedReadings.forEach { reading ->
                        Text(
                            content.readingLabel(reading),
                            color = colors.accent,
                            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
                                .clickable(role = androidx.compose.ui.semantics.Role.Button) { openReading(reading) }.padding(vertical = 4.dp)
                        )
                    }
                }
            }
        }
        item {
            Text("Histórico de reflexões", color = colors.text, fontSize = 24.sp, fontWeight = FontWeight.Bold)
        }
        if (reflectionHistory.isEmpty()) {
            item {
                PremiumCard(colors) {
                    Text("As reflexões salvas nas leituras aparecerão aqui.", color = colors.secondary)
                }
            }
        } else {
            items(reflectionHistory.take(30)) { reflection ->
                PremiumCard(colors) {
                    Text("${reflection.workTitle} • ${TextoFormatter.dataPorExtenso(reflection.date)}", color = colors.accent, fontWeight = FontWeight.Bold)
                    Text(reflection.text, color = colors.text, maxLines = 8, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

/** Keeps the last computed collections for the app session, keyed by what they depend on. */
internal class StudyContentCache {
    private var key: String? = null
    private var content: StudyScreenContent? = null

    @Synchronized
    fun reusable(currentKey: String): StudyScreenContent? = content.takeIf { key == currentKey }

    @Synchronized
    fun store(currentKey: String, value: StudyScreenContent) {
        key = currentKey
        content = value
    }
}

internal data class StudyScreenContent(
    val rules: StudyRules,
    val works: List<BibliotecaObraCatalogo>,
    val collections: Map<String, List<BreviarioItem>>,
    val paths: Map<String, List<BreviarioItem>>,
    val reflections: List<PersonalReflection>,
    val failedWorks: List<String> = emptyList(),
    val completedWorks: Int = 0,
    val totalWorks: Int = 0
) {
    fun readingLabel(item: BreviarioItem): String {
        val title = works.firstOrNull { it.id == item.obraId }?.titulo ?: dailyWorkTitle(item)
        val reference = if (item.data.startsWith("P")) "Página ${item.pagina}" else TextoFormatter.dataPorExtenso(item.data)
        return "$title • $reference - ${item.titulo}"
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun ExportScreen(colors: Palette, repo: BreviarioRepository, prefs: PreferencesStore, initialWorkId: String) {
    val context = LocalContext.current
    var workId by remember { mutableStateOf(initialWorkId) }
    var workMenu by remember { mutableStateOf(false) }
    val works = remember(repo) { repo.itens.distinctBy { it.obraId } }
    val entries = remember(repo, workId) { repo.itens.filter { it.obraId == workId } }
    var selected by remember(workId) { mutableStateOf(emptySet<String>()) }
    var includeComments by remember { mutableStateOf(false) }
    var start by remember { mutableStateOf(LocalDate.now()) }
    var end by remember { mutableStateOf(LocalDate.now()) }
    val dates = entries.map { it.data }.toSet()
    val week = dates.intersect(TextoFormatter.datasSemana(LocalDate.now()))
    val month = dates.filter { it.substringAfter("/").toIntOrNull() == LocalDate.now().monthValue }.toSet()
    val interval = dates.intersect(TextoFormatter.datasIntervalo(start, end))
    fun chooseDate(value: LocalDate, update: (LocalDate) -> Unit) {
        android.app.DatePickerDialog(context, { _, year, monthIndex, day -> update(LocalDate.of(year, monthIndex + 1, day)) }, value.year, value.monthValue - 1, value.dayOfMonth).show()
    }
    LazyColumn(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            PremiumCard(colors) {
                Text("Exportação", color = colors.text, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Box {
                    TextButton(onClick = { workMenu = true }) { Text(entries.firstOrNull()?.let(::dailyWorkTitle) ?: "Escolher obra") }
                    DropdownMenu(expanded = workMenu, onDismissRequest = { workMenu = false }) {
                        works.forEach { work -> DropdownMenuItem(text = { Text(dailyWorkTitle(work)) }, onClick = { workId = work.obraId; workMenu = false }) }
                    }
                }
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    androidx.compose.material3.FilterChip(selected = week.isNotEmpty() && selected.containsAll(week), onClick = { selected = selected + week }, label = { Text("Semanal") })
                    androidx.compose.material3.FilterChip(selected = month.isNotEmpty() && selected.containsAll(month), onClick = { selected = selected + month }, label = { Text("Mensal") })
                    androidx.compose.material3.FilterChip(selected = dates.isNotEmpty() && selected.containsAll(dates), onClick = { selected = dates }, label = { Text("Total") })
                    TextButton(onClick = { selected = emptySet() }) { Text("Limpar") }
                }
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(onClick = { chooseDate(start) { start = it } }) { Icon(Icons.Default.CalendarMonth, null); Text("De ${start.format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy"))}") }
                    TextButton(onClick = { chooseDate(end) { end = it } }) { Icon(Icons.Default.CalendarMonth, null); Text("Até ${end.format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy"))}") }
                    androidx.compose.material3.FilterChip(selected = interval.isNotEmpty() && selected.containsAll(interval), onClick = { selected = selected + interval }, label = { Text("Selecionar intervalo") })
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    androidx.compose.material3.Checkbox(checked = includeComments, onCheckedChange = { includeComments = it })
                    Text("Incluir comentários", color = colors.text)
                }
                Text("${selected.size} ${if (selected.size == 1) "dia selecionado" else "dias selecionados"}", color = colors.accent)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(enabled = selected.isNotEmpty(), onClick = {
                        val chosen = entries.filter { it.data in selected }.map { prefs.applyTextEdit(it) }
                        sharePdf(context, chosen, if (includeComments) chosen.associate { it.chavePersistencia to prefs.comment(it) } else emptyMap(), prefs.settings.premiumPdfName)
                    }) {
                        Icon(Icons.Default.PictureAsPdf, null)
                        Spacer(Modifier.width(6.dp))
                        Text("PDF")
                    }
                    Button(enabled = selected.isNotEmpty(), onClick = {
                        val text = entries.filter { selected.contains(it.data) }.map { prefs.applyTextEdit(it) }.joinToString("\n\n") { TextoFormatter.textoCompartilhavel(it, if (includeComments) prefs.comment(it) else "") }
                        shareText(context, text)
                    }) {
                        Icon(Icons.Default.IosShare, null)
                        Spacer(Modifier.width(6.dp))
                        Text("Texto")
                    }
                }
            }
        }
        items(entries, key = { it.chavePersistencia }) { item ->
            val checked = selected.contains(item.data)
            PremiumCard(colors, Modifier.clickable {
                selected = if (checked) selected - item.data else selected + item.data
            }) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(if (checked) "✓" else "○", color = colors.accent, fontSize = 24.sp)
                    Spacer(Modifier.width(10.dp))
                    Column {
                        Text(TextoFormatter.dataPorExtenso(item.data), color = colors.accent)
                        Text(item.titulo, color = colors.text, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}
