package com.renatocamargo.breviariomaconico

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import com.renatocamargo.breviariomaconico.data.PreferencesStore
import com.renatocamargo.breviariomaconico.progress.ProgressTransport
import com.renatocamargo.breviariomaconico.progress.ProgressVersion
import com.renatocamargo.breviariomaconico.progress.ReviewTransport
import org.json.JSONObject

class WearProgressListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != PATH) return
        apply(runCatching { ProgressTransport.parse(JSONObject(event.data.toString(Charsets.UTF_8))) }.getOrNull())
    }

    override fun onDataChanged(events: DataEventBuffer) {
        events.filter { it.type == DataEvent.TYPE_CHANGED && it.dataItem.uri.path?.startsWith("$DATA_PATH/") == true }
            .forEach { apply(runCatching { ProgressTransport.parse(DataMapItem.fromDataItem(it.dataItem).dataMap) }.getOrNull()) }
        // Grades given on the watch follow the same spaced review as here.
        events.filter { it.type == DataEvent.TYPE_CHANGED && it.dataItem.uri.path?.startsWith("${ReviewTransport.ANSWER_PATH}/") == true }
            .forEach { event ->
                val answer = runCatching {
                    ReviewTransport.parseAnswer(JSONObject(DataMapItem.fromDataItem(event.dataItem).dataMap.getString("resposta").orEmpty()))
                }.getOrNull()
                if (answer != null) ReviewWatchSync.apply(applicationContext, answer)
                ReviewTransport.removeAnswer(applicationContext, event.dataItem.uri)
            }
    }

    private fun apply(event: ProgressVersion?) = ProgressTransport.receive(applicationContext, event) {
        PreferencesStore(applicationContext).setRead(it.work, it.date, it.read)
        sendBroadcast(android.content.Intent(ACTION_PROGRESS_CHANGED).setPackage(packageName))
    }

    companion object {
        const val PATH = ProgressTransport.PATH
        const val DATA_PATH = ProgressTransport.DATA_PATH
        const val ACTION_PROGRESS_CHANGED = "com.renatocamargo.breviariomaconico.READING_PROGRESS_CHANGED"
    }
}

object PhoneWearProgressSync {
    fun send(context: android.content.Context, obraId: String, date: String, read: Boolean) =
        ProgressTransport.send(context, obraId, date, read)
}

/** Today's review session to the watch, and the grades that come back from it (relogio_revisao_v1.json). */
object ReviewWatchSync {
    fun sendDeck(context: android.content.Context) {
        val app = context.applicationContext
        runCatching {
            val rule = JSONObject(app.assets.open("relogio_revisao_v1.json").bufferedReader().use { it.readText() })
            val labels = rule.getJSONObject("rotulos").let { o -> o.keys().asSequence().associateWith { o.getString(it) } }
            val config = com.renatocamargo.breviariomaconico.data.ActiveReview.loadConfig(app)
            val today = java.time.LocalDate.now().toString()
            val session = com.renatocamargo.breviariomaconico.data.ReviewCardStore(app).session(today, config)
            val cards = session.take(rule.getInt("limiteCartoes")).map { ReviewTransport.Card(it.card.id, it.card.front, it.card.back, it.card.source) }
            ReviewTransport.sendDeck(app, ReviewTransport.Deck(today, session.size, cards, labels))
        }
    }

    fun apply(context: android.content.Context, answer: ReviewTransport.Answer) {
        val app = context.applicationContext
        val applied = app.getSharedPreferences("revisao_relogio", android.content.Context.MODE_PRIVATE)
        val seen = applied.getStringSet("eventos", emptySet()).orEmpty()
        if (answer.eventId in seen) return
        val grade = com.renatocamargo.breviariomaconico.data.ActiveReview.Grade.entries.first { it.id == answer.grade }
        com.renatocamargo.breviariomaconico.data.ReviewCardStore(app).answer(answer.id, grade, java.time.LocalDate.now().toString(),
            com.renatocamargo.breviariomaconico.data.ActiveReview.loadConfig(app))
        applied.edit().putStringSet("eventos", (seen + answer.eventId).toList().takeLast(200).toSet()).apply()
        sendDeck(app)
    }
}
