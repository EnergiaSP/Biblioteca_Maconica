package com.renatocamargo.breviariomaconico.wear

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.renatocamargo.breviariomaconico.progress.ReviewTransport
import org.json.JSONObject
import java.util.Calendar
import java.util.UUID

/**
 * Review cards on the watch (relogio_revisao_v1.json): today's session sent by the phone, kept here so it
 * opens without the phone; each grade goes back to the phone. Same as Apple Watch `WatchRevisaoStore`.
 */
internal object WearReviewStore {
    private fun prefs(context: Context) = context.applicationContext.getSharedPreferences("wear_revisao", Context.MODE_PRIVATE)

    fun deck(context: Context): ReviewTransport.Deck? =
        prefs(context).getString("baralho", null)?.let { runCatching { ReviewTransport.parseDeck(JSONObject(it)) }.getOrNull() }

    fun answered(context: Context): Set<String> = prefs(context).getStringSet("respondidos", emptySet()).orEmpty()

    fun pending(context: Context): List<ReviewTransport.Card> = deck(context)?.cards.orEmpty().filter { it.id !in answered(context) }

    fun receive(context: Context, deck: ReviewTransport.Deck) {
        prefs(context).edit().putString("baralho", deck.toJson().toString()).putStringSet("respondidos", emptySet()).apply()
        WearReviewReminder.schedule(context, deck)
    }

    fun answer(context: Context, card: ReviewTransport.Card, grade: String) {
        prefs(context).edit().putStringSet("respondidos", answered(context) + card.id).apply()
        ReviewTransport.sendAnswer(context, ReviewTransport.Answer(card.id, grade, UUID.randomUUID().toString()))
    }
}

/** Watch reminder of the cards due today, at 19:00, with the labels sent by the phone. */
internal object WearReviewReminder {
    private const val code = 830

    fun schedule(context: Context, deck: ReviewTransport.Deck) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = PendingIntent.getBroadcast(context, code, Intent(context, WearReviewReminderReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        manager.cancel(pending)
        if (deck.total == 0) return
        val at = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 19); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        if (at > System.currentTimeMillis()) manager.set(AlarmManager.RTC_WAKEUP, at, pending)
    }
}

class WearReviewReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val deck = WearReviewStore.deck(context) ?: return
        val pending = WearReviewStore.pending(context).size
        if (pending == 0) return
        val channelId = "wear_review"
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(channelId, deck.label("titulo"), NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(context, 831, Intent(context, WearMainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_launcher)
            .setContentTitle(deck.label("titulo"))
            .setContentText(deck.label("pendentes", mapOf("n" to "$pending")))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        if (android.os.Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) NotificationManagerCompat.from(context).notify(831, notification)
    }
}

/** Review section of the watch screen: how many cards are due, then one card at a time. */
@Composable
internal fun WearReviewSection() {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("wear_revisao", Context.MODE_PRIVATE) }
    var version by remember { mutableStateOf(0) }
    DisposableEffect(prefs) {
        val listener = android.content.SharedPreferences.OnSharedPreferenceChangeListener { _, _ -> version++ }
        prefs.registerOnSharedPreferenceChangeListener(listener)
        onDispose { prefs.unregisterOnSharedPreferenceChangeListener(listener) }
    }
    val deck = remember(version) { WearReviewStore.deck(context) } ?: return
    val pending = remember(version) { WearReviewStore.pending(context) }
    var open by remember { mutableStateOf(false) }
    var showing by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().testTag("wear.review"), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(deck.label("titulo"), color = Color.LightGray, fontSize = 11.sp)
        val card = pending.firstOrNull()
        if (!open || card == null) {
            Text(if (pending.isEmpty()) deck.label("vazio") else deck.label("pendentes", mapOf("n" to "${pending.size}")),
                color = Color.White, fontSize = 12.sp)
            if (pending.isNotEmpty()) Button(onClick = { open = true }, modifier = Modifier.fillMaxWidth()) { Text(deck.label("abrir"), fontSize = 11.sp) }
        } else {
            Text(card.front, color = Color.White, fontSize = 13.sp)
            if (showing) {
                Text(card.back, color = Color(0xFFD4AF37), fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Text(deck.label("fonte", mapOf("fonte" to card.source)), color = Color.LightGray, fontSize = 11.sp)
                for (grade in listOf("errei", "dificil", "acertei")) {
                    Button(onClick = { WearReviewStore.answer(context, card, grade); showing = false; version++ },
                        modifier = Modifier.fillMaxWidth().testTag("wear.review.$grade")) { Text(deck.label(grade), fontSize = 11.sp) }
                }
            } else {
                Button(onClick = { showing = true }, modifier = Modifier.fillMaxWidth().testTag("wear.review.show")) {
                    Text(deck.label("mostrar"), fontSize = 11.sp)
                }
            }
        }
    }
}
