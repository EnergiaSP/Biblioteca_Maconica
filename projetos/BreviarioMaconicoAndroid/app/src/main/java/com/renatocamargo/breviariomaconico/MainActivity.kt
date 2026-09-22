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
import androidx.compose.ui.platform.testTag
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

class MainActivity : ComponentActivity() {
    private var openData by mutableStateOf<String?>(null)
    private var openWorkId by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        com.renatocamargo.breviariomaconico.progress.ProgressTransport.flush(applicationContext)
        consumeNavigationIntent(intent)
        setContent {
            BreviarioAndroidApp(
                openData,
                openWorkId,
                uiTesting = (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
                    && intent.getBooleanExtra("ui_testing", false)
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeNavigationIntent(intent)
    }

    private fun consumeNavigationIntent(intent: Intent) {
        openData = intent.getStringExtra("data")
        openWorkId = intent.getStringExtra("obraId")
    }
}

internal enum class Screen(val title: String) {
    Home("Biblioteca Maçônica"),
    Reader("Leitura"),
    LibraryReader("Livro"),
    Breviario("Breviário"),
    Acervo("Acervo"),
    StructuredSearch("Busca estruturada"),
    GlobalIndex("Índice geral"),
    Index("Índice Remissivo"),
    Favorites("Favorito"),
    Unread("Não Lido"),
    Comments("Comentário"),
    Stats("Estatística"),
    Collections("Coleções"),
    Dossier("Dossiê"),
    OfficialSources("Fontes oficiais"),
    RequestWork("Solicitar obra"),
    ReadingAI("IA da leitura"),
    Export("Exportar"),
    Settings("Configurações"),
    More("Recursos avançados")
}

internal data class Palette(
    val background: List<Color>,
    val surface: Color,
    val text: Color,
    val secondary: Color,
    val accent: Color,
    val buttonText: Color,
    val onAccent: Color,
    val accentSurface: Color,
    val success: Color
)

internal fun palette(mode: AppThemeMode): Palette = when (mode) {
    AppThemeMode.Dark -> Palette(
        background = listOf(Color(0xFF050505), Color(0xFF071824)),
        surface = Color(0xFF141414),
        text = Color.White,
        secondary = Color(0xFFD6D0C2),
        accent = Color(0xFFC8A34B),
        buttonText = Color.White,
        onAccent = Color.Black,
        accentSurface = Color(0xFFC8A34B),
        success = Color(0xFF21A365)
    )
    AppThemeMode.Light -> Palette(
        background = listOf(Color(0xFFFAFAF6), Color(0xFFE8EEF0)),
        surface = Color.White,
        text = Color.Black,
        secondary = Color(0xFF4C4C4C),
        accent = Color(0xFF8C610A),
        buttonText = Color.Black,
        onAccent = Color.Black,
        accentSurface = Color(0xFFE6CC94),
        success = Color(0xFF176C35)
    )
    AppThemeMode.Sepia -> Palette(
        background = listOf(Color(0xFFF3E3C3), Color(0xFFE7D0A3)),
        surface = Color(0xFFFFF3D5),
        text = Color.Black,
        secondary = Color(0xFF3D2D17),
        accent = Color(0xFF76520A),
        buttonText = Color.Black,
        onAccent = Color.Black,
        accentSurface = Color(0xFFD1B37A),
        success = Color(0xFF0F4D27)
    )
}

@Composable
internal fun BreviarioAndroidApp(openData: String?, openWorkId: String?, uiTesting: Boolean = false) {
    val context = LocalContext.current
    val prefs = remember { PreferencesStore(context) }
    val repo = remember { BreviarioRepository.get(context) }
    var activated by remember { mutableStateOf(prefs.activated || uiTesting) }
    var showSplash by remember { mutableStateOf(!uiTesting) }
    var settings by remember { mutableStateOf(prefs.settings) }
    val navigation = remember {
        val initialItem = openData?.let { data -> openWorkId?.let { repo.porObraEData(it, data) } ?: repo.porData(data) }
            ?: repo.hoje()
        AppNavigationController(if (openData != null) Screen.Reader else Screen.Home, initialItem)
    }
    val screen = navigation.screen
    val selected = navigation.selectedItem
    var livroPaginas by remember { mutableStateOf(emptyList<BibliotecaPaginaLeitura>()) }
    var livroPaginaAtual by remember { mutableIntStateOf(0) }
    var favorites by remember { mutableStateOf(prefs.favorites()) }
    var readDates by remember { mutableStateOf(prefs.readDates()) }
    var libraryRecents by remember { mutableStateOf(prefs.libraryRecents()) }
    var savedNotice by remember { mutableStateOf<String?>(null) }
    var dataRevision by remember { mutableIntStateOf(0) }
    var leituraTelaCheia by remember { mutableStateOf(settings.distractionFreeMode) }
    LaunchedEffect(settings.distractionFreeMode) { leituraTelaCheia = settings.distractionFreeMode }
    val appScope = rememberCoroutineScope()
    val colors = palette(settings.theme)
    val view = androidx.compose.ui.platform.LocalView.current
    androidx.compose.runtime.SideEffect {
        var owner: android.content.Context = context
        while (owner is android.content.ContextWrapper && owner !is android.app.Activity) owner = owner.baseContext
        (owner as? android.app.Activity)?.window?.let { window ->
            androidx.core.view.WindowCompat.getInsetsController(window, view).apply {
                isAppearanceLightStatusBars = settings.theme != AppThemeMode.Dark
                isAppearanceLightNavigationBars = settings.theme != AppThemeMode.Dark
            }
        }
    }

    DisposableEffect(context) {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(receiverContext: Context?, intent: Intent?) {
                readDates = prefs.readDates()
                dataRevision++
            }
        }
        ContextCompat.registerReceiver(
            context,
            receiver,
            IntentFilter(WearProgressListenerService.ACTION_PROGRESS_CHANGED),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
        onDispose { context.unregisterReceiver(receiver) }
    }

    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(2500)
        showSplash = false
    }

    LaunchedEffect(openData, openWorkId) {
        val data = openData ?: return@LaunchedEffect
        val target = openWorkId?.let { repo.porObraEData(it, data) } ?: repo.porData(data)
        if (target != null) {
            navigation.showReader(target)
            showSplash = false
        }
    }

    fun goReader(item: BreviarioItem) {
        navigation.showReader(item)
    }

    LaunchedEffect(navigation.screen, navigation.selectedItem.chavePersistencia) {
        if (navigation.screen == Screen.Reader) prefs.markDailyRecent(navigation.selectedItem)
    }

    val currentBookPage = livroPaginas.getOrNull(livroPaginaAtual)
    LaunchedEffect(navigation.screen, currentBookPage?.obraId, currentBookPage?.pagina) {
        if (navigation.screen == Screen.LibraryReader && currentBookPage != null) {
            prefs.markLibraryRecent(currentBookPage.obraId, currentBookPage.tituloObra,
                currentBookPage.area.titulo, currentBookPage.pagina)
            libraryRecents = prefs.libraryRecents()
        }
    }

    fun notifySaved(message: String) {
        savedNotice = message
    }

    fun abrirObraBiblioteca(obraId: String, pagina: Int? = null) {
        appScope.launch {
            val paginas = libraryQuery {
                BibliotecaCatalogRepository.get(context).paginasDaObra(obraId)
            }.getOrElse {
                notifySaved("Não foi possível abrir esta obra. Verifique o download no Acervo.")
                return@launch
            }
            if (paginas.isEmpty()) {
                notifySaved("Baixe a obra no Acervo antes de abrir.")
                return@launch
            }
            livroPaginas = paginas
            livroPaginaAtual = pagina?.let { paginaDesejada ->
                paginas.indexOfFirst { it.pagina == paginaDesejada }.takeIf { it >= 0 }
            } ?: 0
            navigation.show(Screen.LibraryReader)
        }
    }

    fun abrirResultado(resultado: BibliotecaBuscaResultado) {
        val integrado = resultado.data?.let { repo.porObraEData(resultado.obraId, it) }
        if (integrado != null) goReader(integrado)
        else abrirObraBiblioteca(resultado.obraId, resultado.pagina)
    }

    if (!activated) {
        ActivationScreen(colors) {
            prefs.activated = true
            activated = true
        }
        return
    }

    val scheme = if (settings.theme == AppThemeMode.Dark) androidx.compose.material3.darkColorScheme()
        else androidx.compose.material3.lightColorScheme()
    MaterialTheme(colorScheme = scheme.copy(
        primary = colors.accentSurface,
        onPrimary = colors.onAccent,
        background = colors.background.first(),
        onBackground = colors.text,
        surface = colors.surface,
        onSurface = colors.text,
        onSurfaceVariant = colors.secondary
    )) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.background.first())
    ) {
        if (showSplash) {
            SplashScreen(colors)
        } else {
            MainScaffold(
                screen = screen,
                colors = colors,
                hideChrome = (screen == Screen.Reader || screen == Screen.LibraryReader) && leituraTelaCheia,
                onHome = navigation::showHome,
                onNavigate = navigation::show,
                onSettings = { navigation.show(Screen.Settings) }
            ) { padding ->
                Box(Modifier.padding(padding)) {
                    when (screen) {
                        Screen.Home -> HomeScreen(colors, repo, prefs, favorites, readDates, libraryRecents, ::goReader, abrirObra = ::abrirObraBiblioteca, onOpen = navigation::show)
                        Screen.Reader -> ReaderScreen(
                            colors = colors,
                            fullscreen = leituraTelaCheia,
                            onToggleFullscreen = { leituraTelaCheia = !leituraTelaCheia },
                            item = remember(selected, dataRevision) { prefs.applyTextEdit(selected) },
                            settings = settings,
                            officialSources = prefs.officialSources(),
                            isFavorite = prefs.isFavorite(selected),
                            isRead = prefs.isRead(selected),
                            comment = prefs.comment(selected),
                            reflection = prefs.reflection(selected),
                            textEdited = prefs.textEdit(selected) != null,
                            highlights = prefs.highlights(selected),
                            onPrevious = { navigation.updateSelected(repo.anterior(selected)) },
                            onNext = { navigation.updateSelected(repo.proximo(selected)) },
                            onHome = navigation::showHome,
                            onToggleFavorite = {
                                prefs.toggleFavorite(selected)
                                favorites = prefs.favorites()
                                notifySaved("Favorito atualizado.")
                            },
                            onToggleRead = {
                                prefs.toggleRead(selected)
                                readDates = prefs.readDates()
                                PhoneWearProgressSync.send(context, selected.obraId, selected.data, prefs.isRead(selected))
                                notifySaved("Leitura atualizada.")
                            },
                            onSaveComment = {
                                prefs.saveComment(selected, it)
                                notifySaved("Comentário salvo.")
                            },
                            onSaveReflection = {
                                prefs.saveReflection(selected, it)
                                notifySaved("Reflexão salva.")
                            },
                            onSaveTextEdit = { title, text, footnote ->
                                prefs.saveTextEdit(selected, title, text, footnote)
                                navigation.updateSelected(prefs.applyTextEdit(selected))
                                dataRevision++
                                notifySaved("Texto editado salvo.")
                            },
                            onRestoreText = {
                                prefs.removeTextEdit(selected)
                                navigation.updateSelected(repo.porObraEData(selected.obraId, selected.data) ?: selected)
                                dataRevision++
                                notifySaved("Texto original restaurado.")
                            },
                            onAddHighlight = {
                                prefs.addHighlight(selected, it)
                                dataRevision++
                                notifySaved("Marcador salvo.")
                            },
                            onRemoveHighlight = {
                                prefs.removeHighlight(selected, it)
                                dataRevision++
                                notifySaved("Marcador removido.")
                            },
                            onExportHighlights = {
                                shareHighlightsPdf(context, prefs.applyTextEdit(selected), prefs.highlights(selected))
                            },
                            onOpenSettings = { navigation.show(Screen.Settings) }
                        )
                        Screen.LibraryReader -> LibraryReaderScreen(
                            colors = colors,
                            prefs = prefs,
                            fullscreen = leituraTelaCheia,
                            onToggleFullscreen = { leituraTelaCheia = !leituraTelaCheia },
                            onSaved = ::notifySaved,
                            paginas = livroPaginas,
                            paginaAtual = livroPaginaAtual,
                            settings = settings,
                            onPageChange = { livroPaginaAtual = it },
                            onHome = navigation::showHome,
                            onSearch = { navigation.show(Screen.StructuredSearch) }
                        )
                        Screen.Breviario -> BreviarioScreen(colors, repo, ::goReader)
                        Screen.Acervo -> AcervoScreen(colors, abrirObra = ::abrirObraBiblioteca)
                        Screen.StructuredSearch -> StructuredSearchScreen(colors, abrirResultado = ::abrirResultado)
                        Screen.GlobalIndex -> GlobalIndexScreen(colors, abrirResultado = ::abrirResultado)
                        Screen.Index -> IndexScreen(colors, repo, ::goReader)
                        Screen.Favorites -> ItemListScreen("Favorito", colors, prefs.favoriteItems(repo.itens), ::goReader)
                        Screen.Unread -> ItemListScreen("Não Lido", colors, prefs.unreadItems(repo.itens), ::goReader)
                        Screen.Comments -> ItemListScreen("Comentário", colors, prefs.commentedItems(repo.itens), ::goReader)
                        Screen.Stats -> StatsScreen(colors, repo, prefs)
                        Screen.Collections -> CollectionsScreen(colors, repo, ::goReader, abrirObra = ::abrirObraBiblioteca)
                        Screen.Dossier -> DossierScreen(colors, abrirResultado = ::abrirResultado)
                        Screen.OfficialSources -> OfficialSourcesScreen(colors, prefs, onSaved = {
                            notifySaved(it)
                        })
                        Screen.RequestWork -> RequestWorkScreen(colors, prefs, onSaved = {
                            notifySaved(it)
                        })
                        Screen.ReadingAI -> ReadingAIScreen(
                            colors = colors,
                            item = selected,
                            settings = settings,
                            officialSources = prefs.officialSources(),
                            comment = prefs.comment(selected),
                            onSaveComment = {
                                prefs.saveComment(selected, it)
                                notifySaved("Análise IA salva no comentário do dia.")
                            },
                            onOpenReading = { navigation.show(Screen.Reader) }
                        )
                        Screen.Export -> ExportScreen(colors, repo, prefs, selected.obraId)
                        Screen.Settings -> SettingsScreen(
                            colors = colors,
                            settings = settings,
                            dailyWorks = repo.itens.distinctBy { it.obraId },
                            onSave = { updatedSettings ->
                                settings = updatedSettings
                                prefs.settings = updatedSettings
                                scheduleDailyNotification(context, updatedSettings)
                                notifySaved("Configurações salvas.")
                            }
                        )
                        Screen.More -> MoreScreen(colors, navigation::show)
                    }
                }
            }
        }

        savedNotice?.let { message ->
            ToastNotice(message = message, colors = colors, onGone = { savedNotice = null })
        }
    }
    }
}
