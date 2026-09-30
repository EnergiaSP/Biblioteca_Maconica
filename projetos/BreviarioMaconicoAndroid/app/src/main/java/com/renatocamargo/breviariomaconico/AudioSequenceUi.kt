package com.renatocamargo.breviariomaconico

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.renatocamargo.breviariomaconico.data.BreviarioItem
import com.renatocamargo.breviariomaconico.data.PreferencesStore
import org.json.JSONObject

/**
 * Audio of a whole collection or study path, one reading after another (audio_sequencia_v1.json).
 * Android speech cannot pause mid-sentence: "Pausar" keeps the position and "Continuar" reads the current
 * reading again. Same labels and order as iOS `LeituraVozService.ouvirSequencia`.
 */
internal class AudioSequence(private val tts: TextToSpeech, private val labels: Map<String, String>, val limit: Int) {
    var title by mutableStateOf<String?>(null)
        private set
    var items by mutableStateOf(emptyList<BreviarioItem>())
        private set
    var position by mutableStateOf(0)
        private set
    var paused by mutableStateOf(false)
        private set
    private val main = Handler(Looper.getMainLooper())

    init {
        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) = Unit
            @Deprecated("Deprecated in Java") override fun onError(utteranceId: String?) = Unit
            override fun onDone(utteranceId: String?) {
                // In a sequence, the next reading starts when this one ends.
                main.post { if (utteranceId == currentId() && !paused) advance() }
            }
        })
    }

    fun label(key: String, values: Map<String, String> = emptyMap()) =
        values.entries.fold(labels[key] ?: key) { text, (name, value) -> text.replace("{$name}", value) }

    private fun currentId() = "sequencia-$position-${items.getOrNull(position)?.chavePersistencia}"

    fun play(sequenceTitle: String, readings: List<BreviarioItem>) {
        val list = readings.take(limit)
        if (list.isEmpty()) return
        title = sequenceTitle
        items = list
        speak(0)
    }

    private fun speak(index: Int) {
        position = index
        paused = false
        val item = items[index]
        val announcement = label("anuncio", mapOf("n" to "${index + 1}", "total" to "${items.size}"))
        tts.speak("$announcement ${item.titulo}. ${item.texto}", TextToSpeech.QUEUE_FLUSH, null, currentId())
    }

    private fun advance() = if (position + 1 < items.size) speak(position + 1) else stop()

    fun next() = advance()

    fun togglePause() {
        if (title == null) return
        if (paused) speak(position) else { paused = true; tts.stop() }
    }

    fun stop() {
        title = null
        items = emptyList()
        paused = false
        tts.stop()
    }

    companion object {
        fun load(context: Context): JSONObject =
            context.assets.open("audio_sequencia_v1.json").bufferedReader().use { JSONObject(it.readText()) }
    }
}

@Composable
internal fun rememberAudioSequence(): AudioSequence {
    val context = LocalContext.current
    val settings = remember { PreferencesStore(context).settings }
    val tts = rememberTextToSpeech(settings.voiceGender, settings.voiceSpeed)
    return remember(tts) {
        val json = AudioSequence.load(context)
        require(json.getInt("schemaVersion") == 1)
        val labels = json.getJSONObject("rotulos").let { o -> o.keys().asSequence().associateWith { o.getString(it) } }
        AudioSequence(tts, labels, json.getInt("limiteLeituras"))
    }
}

/** Small speaker button on a collection or study path card. */
@Composable
internal fun AudioSequenceButton(colors: Palette, sequence: AudioSequence, onClick: () -> Unit) {
    IconButton(onClick = onClick, modifier = Modifier.testTag("audio.sequence.play")) {
        Icon(Icons.AutoMirrored.Filled.VolumeUp, contentDescription = sequence.label("ouvir"), tint = colors.accent)
    }
}

/** Progress and controls of the sequence being read. */
@Composable
internal fun AudioSequenceBar(colors: Palette, sequence: AudioSequence) {
    val title = sequence.title ?: return
    PremiumCard(colors) {
        Text(sequence.label("ouvindo", mapOf("titulo" to title, "n" to "${sequence.position + 1}", "total" to "${sequence.items.size}")),
            color = colors.text, fontWeight = FontWeight.SemiBold, modifier = Modifier.testTag("audio.sequence.status"))
        sequence.items.getOrNull(sequence.position)?.let { Text(it.titulo, color = colors.secondary, fontSize = 13.sp) }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = sequence::togglePause, modifier = Modifier.testTag("audio.sequence.pause")) {
                Text(sequence.label(if (sequence.paused) "continuar" else "pausar"), color = colors.text)
            }
            OutlinedButton(onClick = sequence::next, modifier = Modifier.testTag("audio.sequence.next")) {
                Text(sequence.label("proxima"), color = colors.text)
            }
            OutlinedButton(onClick = sequence::stop, modifier = Modifier.testTag("audio.sequence.stop")) {
                Text(sequence.label("parar"), color = colors.text)
            }
        }
    }
}
