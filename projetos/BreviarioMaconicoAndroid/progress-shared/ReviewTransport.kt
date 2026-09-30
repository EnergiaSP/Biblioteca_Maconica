package com.renatocamargo.breviariomaconico.progress

import android.content.Context
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import org.json.JSONArray
import org.json.JSONObject

/**
 * Review cards on the watch (relogio_revisao_v1.json): the phone keeps today's session as a data item,
 * the watch sends each grade as its own data item, delivered when they are connected. Same messages
 * as iOS `BaralhoRelogio` and `RespostaRelogio`.
 */
object ReviewTransport {
    const val DECK_PATH = "/revisao-cartoes"
    const val ANSWER_PATH = "/revisao-resposta"
    private val grades = setOf("errei", "dificil", "acertei")

    data class Card(val id: String, val front: String, val back: String, val source: String)
    data class Deck(val today: String, val total: Int, val cards: List<Card>, val labels: Map<String, String>) {
        fun label(key: String, values: Map<String, String> = emptyMap()) =
            values.entries.fold(labels[key] ?: key) { text, (name, value) -> text.replace("{$name}", value) }

        fun toJson(): JSONObject = JSONObject().put("hoje", today).put("total", total)
            .put("cartoes", JSONArray(cards.map { JSONObject().put("id", it.id).put("frente", it.front).put("verso", it.back).put("fonte", it.source) }))
            .put("rotulos", JSONObject(labels))
    }
    data class Answer(val id: String, val grade: String, val eventId: String) {
        fun toJson(): JSONObject = JSONObject().put("tipo", "respostaRevisao").put("id", id).put("nota", grade).put("eventoID", eventId)
    }

    fun parseDeck(json: JSONObject): Deck? = runCatching {
        val cards = json.getJSONArray("cartoes")
        val labels = json.getJSONObject("rotulos")
        Deck(json.getString("hoje"), json.getInt("total"),
            List(cards.length()) { cards.getJSONObject(it).let { c -> Card(c.getString("id"), c.getString("frente"), c.getString("verso"), c.getString("fonte")) } },
            labels.keys().asSequence().associateWith { labels.getString(it) })
    }.getOrNull()

    fun parseAnswer(json: JSONObject): Answer? {
        if (json.optString("tipo") != "respostaRevisao") return null
        val answer = Answer(json.optString("id"), json.optString("nota"), json.optString("eventoID"))
        return answer.takeIf { it.id.isNotEmpty() && it.grade in grades && it.eventId.isNotEmpty() }
    }

    fun sendDeck(context: Context, deck: Deck) {
        val request = PutDataMapRequest.create(DECK_PATH).apply { dataMap.putString("baralho", deck.toJson().toString()) }
            .asPutDataRequest().setUrgent()
        Wearable.getDataClient(context.applicationContext).putDataItem(request)
    }

    fun sendAnswer(context: Context, answer: Answer) {
        val request = PutDataMapRequest.create("$ANSWER_PATH/${answer.eventId}").apply { dataMap.putString("resposta", answer.toJson().toString()) }
            .asPutDataRequest().setUrgent()
        Wearable.getDataClient(context.applicationContext).putDataItem(request)
    }

    /** An applied grade is removed, so it is not delivered again. */
    fun removeAnswer(context: Context, uri: android.net.Uri) {
        Wearable.getDataClient(context.applicationContext).deleteDataItems(uri)
    }
}
