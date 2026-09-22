package com.renatocamargo.breviariomaconico.wear

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class WearReading(
    val obraId: String,
    val data: String,
    val titulo: String,
    val autor: String,
    val texto: String,
    val rodape: String = ""
) {
    val resumo: String
        get() = texto.replace(Regex("\\s+"), " ").take(360).trimEnd() + if (texto.length > 360) "…" else ""
}

class WearMainActivity : ComponentActivity() {
    private var reading by mutableStateOf<WearReading?>(null)
    private var openFull by mutableStateOf(false)
    private var loading by mutableStateOf(true)
    private var loadJob: Job? = null
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        com.renatocamargo.breviariomaconico.progress.ProgressTransport.flush(applicationContext)
        openReading(intent)
        setContent {
            val selected = reading
            if (selected != null) WearReadingApp(selected, openFull)
            else Text(if (loading) "Carregando leitura…" else "Leitura indisponível neste relógio.", color = Color.White, modifier = Modifier.fillMaxSize().background(Color.Black).padding(20.dp))
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        openReading(intent)
    }

    override fun onResume() {
        super.onResume()
        val today = SimpleDateFormat("dd/MM", Locale.forLanguageTag("pt-BR")).format(Date())
        if (intent.getStringExtra("data") == null && reading?.data?.let { it != today } == true) openReading(intent)
    }

    private fun openReading(intent: android.content.Intent) {
        loadJob?.cancel()
        loading = true
        reading = null
        loadJob = lifecycleScope.launch {
            reading = withContext(Dispatchers.IO) {
                runCatching { loadWearReading(this@WearMainActivity, intent.getStringExtra("data"), intent.getStringExtra("obraId")) }.getOrNull()
            }
            openFull = intent.getBooleanExtra("abrirLeitura", false)
            loading = false
        }
    }
}

internal fun loadWearReading(context: android.content.Context, date: String? = null, workId: String? = null): WearReading? {
        val portuguese = Locale.Builder().setLanguage("pt").setRegion("BR").build()
        val today = date ?: SimpleDateFormat("dd/MM", portuguese).format(Date())
        val json = context.assets.open("breviario.json").bufferedReader().use { it.readText() }
        val items = JSONObject(json).getJSONArray("itens")
        val selected = (0 until items.length())
            .map { items.getJSONObject(it) }
            .firstOrNull { it.optString("data") == today && (workId == null || it.optString("obraID", it.optString("obraId", "breviario_seculo_xxi")) == workId) }
            ?: return null
        return WearReading(
            obraId = selected.optString("obraID", selected.optString("obraId", "breviario_seculo_xxi")),
            data = selected.optString("data"),
            titulo = selected.optString("titulo", "Leitura diária"),
            autor = selected.optString("autor"),
            texto = selected.optString("texto"),
            rodape = selected.optString("rodape").takeUnless { it == "null" }.orEmpty()
        )
}

@androidx.compose.runtime.Composable
private fun WearReadingApp(reading: WearReading, initiallyFull: Boolean = false) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val key = "${reading.obraId}:${reading.data}"
    val prefs = remember { context.getSharedPreferences("wear_progress", android.content.Context.MODE_PRIVATE) }
    var testNotificationPending by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    fun scheduleNotification(test: Boolean) {
        if (!androidx.core.app.NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            message = "Notificações bloqueadas nas configurações."
            return
        }
        val channel = context.getSystemService(android.app.NotificationManager::class.java).getNotificationChannel("wear_daily_reading")
        if (channel?.importance == android.app.NotificationManager.IMPORTANCE_NONE) {
            message = "Canal de notificações bloqueado."
            return
        }
        if (test) WearNotificationScheduler.scheduleTest(context) else WearNotificationScheduler.scheduleDaily(context)
        message = if (test) "Teste agendado." else "Notificação diária ativada."
    }
    val notificationPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) scheduleNotification(testNotificationPending)
        else message = "Permissão negada. Nenhuma notificação foi agendada."
        testNotificationPending = false
    }
    var full by remember(key, initiallyFull) { mutableStateOf(initiallyFull) }
    var read by remember(key) { mutableStateOf(prefs.getBoolean(key, false)) }
    androidx.compose.runtime.DisposableEffect(prefs, key) {
        val listener = android.content.SharedPreferences.OnSharedPreferenceChangeListener { saved, changed ->
            if (changed == key) read = saved.getBoolean(key, false)
        }
        prefs.registerOnSharedPreferenceChangeListener(listener)
        onDispose { prefs.unregisterOnSharedPreferenceChangeListener(listener) }
    }

    MaterialTheme {
        Column(
            Modifier.fillMaxSize().background(Color(0xFF111111)).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(9.dp)
        ) {
            Text(reading.data, color = Color.LightGray, fontSize = 12.sp)
            Text(reading.titulo, color = Color(0xFFD4AF37), fontSize = 17.sp, fontWeight = FontWeight.Bold)
            if (reading.autor.isNotBlank()) Text(reading.autor, color = Color.LightGray, fontSize = 11.sp)
            Text(if (full) reading.texto else reading.resumo, color = Color.White, fontSize = 13.sp, lineHeight = 18.sp)
            if (full && reading.rodape.isNotBlank()) {
                androidx.compose.material3.HorizontalDivider(color = Color.LightGray)
                Text("Notas de rodapé", color = Color.LightGray, fontSize = 12.sp)
                Text(reading.rodape, color = Color.White, fontSize = 13.sp, lineHeight = 18.sp)
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Button(onClick = { full = !full }, modifier = Modifier.weight(1f)) {
                    Text(if (full) "Resumo" else "Ler", fontSize = 11.sp)
                }
                Button(onClick = {
                    read = !read
                    prefs.edit().putBoolean(key, read).apply()
                    WearProgressSync.send(context, reading.obraId, reading.data, read)
                }, modifier = Modifier.weight(1f)) {
                    Text(if (read) "Lido ✓" else "Marcar", fontSize = 11.sp, textAlign = TextAlign.Center)
                }
            }
            Text("Notificações", color = Color.LightGray, fontSize = 11.sp)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Button(onClick = {
                    testNotificationPending = false
                    if (android.os.Build.VERSION.SDK_INT >= 33 &&
                        ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    ) {
                        notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
                    } else {
                        scheduleNotification(false)
                    }
                }, modifier = Modifier.weight(1f)) {
                    Text("Ativar 08h", fontSize = 10.sp)
                }
                Button(onClick = {
                    testNotificationPending = true
                    if (android.os.Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
                    } else scheduleNotification(true)
                }, modifier = Modifier.weight(1f)) {
                    Text("Teste 5s", fontSize = 10.sp)
                }
            }
            Button(onClick = { WearNotificationScheduler.cancel(context); message = "Notificação cancelada." }, modifier = Modifier.fillMaxWidth()) {
                Text("Cancelar notificação", fontSize = 10.sp)
            }
            message?.let { Text(it, color = Color.White, fontSize = 12.sp) }
            Spacer(Modifier.height(8.dp))
        }
    }
}

private object WearProgressSync {
    fun send(context: android.content.Context, obraId: String, data: String, read: Boolean) {
        com.renatocamargo.breviariomaconico.progress.ProgressTransport.send(context, obraId, data, read)
    }
}
