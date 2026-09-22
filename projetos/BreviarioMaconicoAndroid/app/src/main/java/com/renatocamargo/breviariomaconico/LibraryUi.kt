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
internal fun BreviarioScreen(colors: Palette, repo: BreviarioRepository, onRead: (BreviarioItem) -> Unit) {
    var date by remember { mutableStateOf("") }
    ItemSearchList(
        title = "Seleção de data",
        colors = colors,
        items = repo.buscarLeituras(date),
        search = date,
        label = "Digite dd/mm ou termo",
        onSearch = { date = it },
        onRead = onRead
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun AcervoScreen(colors: Palette, abrirObra: (String) -> Unit) {
    val context = LocalContext.current
    val catalogo = remember { BibliotecaCatalogRepository.get(context) }
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    var area by remember { mutableStateOf(BibliotecaArea.Breviarios) }
    var busca by remember { mutableStateOf("") }
    var atualizando by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<String?>(null) }
    var estados by remember(area, atualizando) { mutableStateOf(catalogo.estados(area)) }
    val filtrados = remember(estados, busca) { catalogo.buscar(estados, busca) }

    fun recarregar() {
        estados = catalogo.estados(area)
    }

    fun instalar(pacote: com.renatocamargo.breviariomaconico.data.BibliotecaPacoteCatalogo) {
        scope.launch {
            atualizando = true
            status = "Preparando download..."
            runCatching {
                withContext(Dispatchers.IO) {
                    catalogo.instalar(pacote)
                }
            }.onSuccess {
                status = "Obra baixada com sucesso."
            }.onFailure {
                status = it.message ?: "Não foi possível baixar a obra."
            }
            atualizando = false
            recarregar()
        }
    }

    fun baixarTodos() {
        scope.launch {
            atualizando = true
            val pendentes = catalogo.estados(area).filterNot { it.instalado }
            if (pendentes.isEmpty()) {
                status = "Todas as obras desta área já estão baixadas."
            } else {
                runCatching {
                    pendentes.forEachIndexed { index, estado ->
                        status = "Baixando ${index + 1}/${pendentes.size}: ${estado.pacote.tituloPrincipal}"
                        withContext(Dispatchers.IO) {
                            catalogo.instalar(estado.pacote)
                        }
                    }
                }.onSuccess {
                    status = "Download da área concluído."
                }.onFailure {
                    status = it.message ?: "Download interrompido."
                }
            }
            atualizando = false
            recarregar()
        }
    }

    LazyColumn(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            PremiumCard(colors) {
                Text("Acervo", color = colors.text, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                Text("Baixe obras individuais ou uma área completa para uso offline.", color = colors.secondary)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    BibliotecaArea.entries.forEach { item ->
                        AssistChip(
                            onClick = {
                                area = item
                                busca = ""
                            },
                            label = { Text(item.titulo, color = if (item == area) Color.Black else colors.text) },
                            leadingIcon = {
                                if (item == area) Icon(Icons.Default.CheckCircle, null, tint = Color(0xFF1F7A3A))
                            }
                        )
                    }
                }
                OutlinedTextField(
                    value = busca,
                    onValueChange = { busca = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Buscar livro pelo título") },
                    leadingIcon = { Icon(Icons.Default.Search, null) },
                    singleLine = true
                )
                Text("${filtrados.size} obra(s) encontrada(s) nesta área.", color = colors.secondary, fontSize = 13.sp)
                Button(enabled = !atualizando, onClick = { baixarTodos() }) {
                    Icon(Icons.Default.CloudDownload, null)
                    Spacer(Modifier.width(8.dp))
                    Text("Baixar todas da área")
                }
                status?.let { Text(it, color = colors.accent, fontWeight = FontWeight.SemiBold) }
            }
        }

        if (filtrados.isEmpty()) {
            item {
                PremiumCard(colors) {
                    Text("Nenhuma obra encontrada", color = colors.text, fontWeight = FontWeight.Bold)
                    Text("Tente buscar por outra parte do título.", color = colors.secondary)
                }
            }
        }

        items(filtrados) { estado ->
            AcervoPackageCard(
                colors = colors,
                estado = estado,
                busy = atualizando,
                onOpen = {
                    val obraId = estado.pacote.obras.firstOrNull()?.id
                    if (estado.instalado && obraId != null) abrirObra(obraId) else status = "Baixe a obra antes de abrir."
                },
                onInstall = { instalar(estado.pacote) },
                onRemove = {
                    catalogo.remover(estado.pacote)
                    status = "Obra removida do aparelho."
                    recarregar()
                }
            )
        }
    }
}

@Composable
internal fun AcervoPackageCard(
    colors: Palette,
    estado: BibliotecaPacoteEstado,
    busy: Boolean,
    onOpen: () -> Unit,
    onInstall: () -> Unit,
    onRemove: () -> Unit
) {
    PremiumCard(colors, Modifier.clickable { onOpen() }) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(estado.pacote.tituloPrincipal, color = colors.text, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                estado.pacote.obras.firstOrNull()?.autor?.let { autor ->
                    Text(autor, color = colors.secondary, fontSize = 13.sp)
                }
                Text(estado.pacote.area.titulo, color = colors.accent, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                Text(estado.pacote.detalhe, color = colors.secondary, fontSize = 13.sp)
                Text(if (estado.instalado) "Disponível offline" else "Não baixado", color = if (estado.instalado) colors.success else colors.secondary, fontSize = 13.sp)
            }
            IconButton(enabled = !busy, onClick = if (estado.instalado) onRemove else onInstall) {
                Icon(
                    if (estado.instalado) Icons.Default.Delete else Icons.Default.CloudDownload,
                    contentDescription = if (estado.instalado) "Remover" else "Baixar",
                    tint = colors.accent
                )
            }
        }
    }
}
