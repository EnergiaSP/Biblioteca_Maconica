package com.renatocamargo.breviariomaconico

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.renatocamargo.breviariomaconico.data.ActiveReview
import com.renatocamargo.breviariomaconico.data.ReviewCardStore
import com.renatocamargo.breviariomaconico.progress.ReviewTransport
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

/** Messages of the review cards on the watch, the same WatchConnectivity carries on iOS (relogio_revisao_v1.json). */
@RunWith(AndroidJUnit4::class)
class ReviewWatchTest {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()

    @Test
    fun watchReviewMessagesMatchSharedExamples() {
        val rule = JSONObject(context.assets.open("relogio_revisao_v1.json").bufferedReader().use { it.readText() })
        val examples = rule.getJSONObject("exemplos")
        val deck = ReviewTransport.parseDeck(examples.getJSONObject("baralho"))!!
        assertEquals(listOf("degrau", "Símbolo da imortalidade."), deck.cards.map { it.back })
        assertEquals("Sent and read back unchanged", deck, ReviewTransport.parseDeck(JSONObject(deck.toJson().toString())))
        assertEquals("2 cartão(ões) para hoje", deck.label("pendentes", mapOf("n" to "2")))
        val answers = examples.getJSONArray("respostas")
        for (index in 0 until answers.length()) {
            val case = answers.getJSONObject(index)
            assertEquals("${case.getJSONObject("mensagem")}", case.getBoolean("valida"), ReviewTransport.parseAnswer(case.getJSONObject("mensagem")) != null)
        }
    }

    /** A grade from the watch follows the same spaced review as here, and a repeated delivery counts once. */
    @Test
    fun gradeFromWatchIsAppliedOnce() {
        val store = ReviewCardStore(context)
        val before = store.all()
        val today = java.time.LocalDate.now().toString()
        val card = ActiveReview.Card("relogio-teste", "lacuna", "A Fé é o primeiro _____.", "degrau", "Breviário, 03/07", emptyList())
        try {
            store.replaceAll(emptyList())
            store.add(listOf(card), "dossie-teste", "fé", today)
            val answer = ReviewTransport.Answer(card.id, "acertei", "evento-${System.nanoTime()}")
            ReviewWatchSync.apply(context, answer)
            ReviewWatchSync.apply(context, answer)
            val state = store.all().single().state
            assertEquals(1, state.box)
            assertEquals(1, state.right)
        } finally {
            store.replaceAll(before)
        }
    }
}
