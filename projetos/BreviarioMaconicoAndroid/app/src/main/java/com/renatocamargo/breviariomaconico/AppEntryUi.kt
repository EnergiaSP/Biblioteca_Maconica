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
import androidx.compose.foundation.selection.selectable
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
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
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
internal fun SplashScreen(colors: Palette) {
    Column(
        Modifier
            .fillMaxSize()
            .padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Image(
            painter = painterResource(R.drawable.launch_icon),
            contentDescription = null,
            modifier = Modifier.size(132.dp),
            contentScale = ContentScale.Fit
        )
        Spacer(Modifier.height(18.dp))
        Text("Biblioteca Maçônica", color = colors.text, fontSize = 30.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        Text("Estudo, leitura e acervo maçônico", color = colors.accent, fontSize = 18.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
    }
}

@Composable
internal fun ActivationScreen(colors: Palette, onActivated: () -> Unit) {
    var code by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var showAdmin by remember { mutableStateOf(false) }
    var adminTapCount by remember { mutableIntStateOf(0) }
    var lastAdminTap by remember { mutableLongStateOf(0L) }

    fun registerAdminTap() {
        val now = System.currentTimeMillis()
        adminTapCount = if (now - lastAdminTap > 2200) 1 else adminTapCount + 1
        lastAdminTap = now
        if (adminTapCount >= 8) {
            adminTapCount = 0
            showAdmin = true
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF100D09), Color(0xFF2D1D08), Color.Black)))
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Image(
                painter = painterResource(R.drawable.launch_icon),
                contentDescription = null,
                modifier = Modifier
                    .size(116.dp)
                    .clickable { registerAdminTap() }
            )
            Spacer(Modifier.height(14.dp))
            Text("Biblioteca Maçônica", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            Text("Estudo, leitura e acervo maçônico", color = Color(0xFFE7C15A), fontSize = 17.sp, textAlign = TextAlign.Center)
            Spacer(Modifier.height(26.dp))
            Card(colors = CardDefaults.cardColors(containerColor = Color.White.copy(alpha = 0.14f))) {
                Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text("Código de ativação", color = Color.White, fontWeight = FontWeight.Bold)
                    OutlinedTextField(
                        value = code,
                        onValueChange = { code = it.uppercase() },
                        modifier = Modifier.fillMaxWidth(),
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters),
                        singleLine = true,
                        label = { Text("Digite o código") }
                    )
                    Button(
                        modifier = Modifier.fillMaxWidth(),
                        onClick = {
                            if (ActivationCodeGenerator.isValid(code)) onActivated() else message = "Código inválido para hoje."
                        }
                    ) {
                        Text("Ativar")
                    }
                    if (message.isNotBlank()) Text(message, color = Color(0xFFFFC1B8))
                }
            }
        }
    }

    if (showAdmin) AdminDialog(onDismiss = { showAdmin = false })
}

@Composable
internal fun AdminDialog(onDismiss: () -> Unit) {
    var password by remember { mutableStateOf("") }
    var authorized by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (authorized) "Gerador de ativação" else "Senha administrativa") },
        text = {
            if (authorized) {
                Column {
                    Text("Código de hoje")
                    Text(ActivationCodeGenerator.todayCode(), fontSize = 22.sp, fontWeight = FontWeight.Bold)
                }
            } else {
                OutlinedTextField(password, { password = it }, label = { Text("Senha") }, singleLine = true)
            }
        },
        confirmButton = {
            TextButton(onClick = {
                if (authorized) onDismiss() else authorized = ActivationCodeGenerator.adminPasswordValid(password)
            }) {
                Text(if (authorized) "Fechar" else "Abrir")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancelar") } }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun MainScaffold(
    screen: Screen,
    colors: Palette,
    onHome: () -> Unit,
    onNavigate: (Screen) -> Unit,
    onSettings: () -> Unit,
    hideChrome: Boolean = false,
    content: @Composable (androidx.compose.foundation.layout.PaddingValues) -> Unit
) {
    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            if (!hideChrome && screen != Screen.Home) {
            TopAppBar(
                title = { Text(screen.title, color = colors.text, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = {
                    IconButton(onClick = onHome) {
                        Icon(Icons.Default.Home, contentDescription = "Home", tint = colors.text)
                    }
                },
                actions = {
                    IconButton(onClick = onSettings) {
                        Icon(Icons.Default.Settings, contentDescription = "Configurações", tint = colors.text)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)
            )
            }
        },
        bottomBar = {
            if (!hideChrome) {
            Surface(color = colors.surface.copy(alpha = 0.96f), shadowElevation = 10.dp) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp, vertical = 6.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    BottomItem(Screen.Home, screen, colors, Icons.Default.Home, "Início", onHome)
                    BottomItem(Screen.Collections, screen, colors, Icons.Default.Book, "Coleções") { onNavigate(Screen.Collections) }
                    BottomItem(Screen.Dossier, screen, colors, Icons.Default.TextFields, "Dossiê") { onNavigate(Screen.Dossier) }
                    BottomItem(Screen.Acervo, screen, colors, Icons.Default.CalendarMonth, "Acervo") { onNavigate(Screen.Acervo) }
                    BottomItem(Screen.More, screen, colors, Icons.Default.MoreHoriz, "Mais") { onNavigate(Screen.More) }
                }
            }
            }
        },
        content = content
    )
}

@Composable
internal fun RowScope.BottomItem(
    target: Screen,
    current: Screen,
    colors: Palette,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit
) {
    val selected = current == target
    val showLabel = LocalDensity.current.fontScale <= 1.3f
    Column(
        modifier = Modifier
            .weight(1f)
            .heightIn(min = 48.dp)
            .testTag("tab.${target.name.lowercase()}")
            .selectable(selected = selected, role = Role.Tab, onClick = onClick)
            .semantics { contentDescription = label }
            .padding(vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically)
    ) {
        Icon(icon, contentDescription = null, tint = if (selected) colors.accent else colors.secondary, modifier = Modifier.size(24.dp))
        if (showLabel) Text(label, color = if (selected) colors.accent else colors.secondary,
            maxLines = 1, fontSize = 11.sp, modifier = Modifier.clearAndSetSemantics { })
    }
}
