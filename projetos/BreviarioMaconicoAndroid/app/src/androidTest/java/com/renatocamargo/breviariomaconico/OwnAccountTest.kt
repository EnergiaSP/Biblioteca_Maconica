package com.renatocamargo.breviariomaconico

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.renatocamargo.breviariomaconico.data.NotebookSync
import com.renatocamargo.breviariomaconico.data.OwnAccountNotebook
import com.renatocamargo.breviariomaconico.data.OwnAccountProvider
import com.renatocamargo.breviariomaconico.data.StudyNotebook
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Same codes, derivations and encrypted bytes as `Tools/conta_propria_referencia.mjs` and iOS. */
@RunWith(AndroidJUnit4::class)
class OwnAccountTest {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()

    private fun bytes(hex: String) = ByteArray(hex.length / 2) { hex.substring(it * 2, it * 2 + 2).toInt(16).toByte() }
    private fun hex(data: ByteArray) = data.joinToString("") { "%02x".format(it) }

    @Test
    fun ownAccountMatchesReferenceCases() {
        val config = OwnAccountNotebook.loadConfig(context)
        val root = JSONObject(context.assets.open("casos_conta_propria_v1.json").bufferedReader().use { it.readText() })
        root.getJSONArray("formatacao").let { cases ->
            for (i in 0 until cases.length()) cases.getJSONObject(i).let {
                assertEquals(it.getString("codigo"), OwnAccountNotebook.format(bytes(it.getString("bytes")), config))
            }
        }
        root.getJSONArray("normalizacao").let { cases ->
            for (i in 0 until cases.length()) cases.getJSONObject(i).let {
                val expected = if (it.isNull("esperado")) null else it.getString("esperado")
                assertEquals(it.getString("entrada"), expected, OwnAccountNotebook.normalize(it.getString("entrada"), config))
            }
        }
        root.getJSONArray("derivacao").let { cases ->
            for (i in 0 until cases.length()) cases.getJSONObject(i).let {
                val derivation = OwnAccountNotebook.derive(it.getString("codigo"), config)
                assertEquals(it.getString("conta"), derivation.account)
                assertEquals(it.getString("credencial"), derivation.credential)
                assertEquals(it.getString("chave"), hex(derivation.key))
            }
        }
        root.getJSONArray("cifragem").let { cases ->
            for (i in 0 until cases.length()) cases.getJSONObject(i).let {
                val key = bytes(it.getString("chave"))
                val encrypted = OwnAccountNotebook.encrypt(it.getString("texto").toByteArray(Charsets.UTF_8), key, bytes(it.getString("nonce")))
                assertEquals(it.getString("nome"), it.getString("cifrado"), hex(encrypted))
                assertArrayEquals(it.getString("texto").toByteArray(Charsets.UTF_8), OwnAccountNotebook.decrypt(bytes(it.getString("cifrado")), key))
            }
        }
    }

    /**
     * Real sync through the own-account server (local `wrangler dev`, seen by the emulator as 10.0.2.2), as
     * on iOS. Opt-in: am instrument -e servidor http://10.0.2.2:8787 ...
     */
    @Test
    fun ownAccountSyncThroughServer() = runBlocking {
        val server = InstrumentationRegistry.getArguments().getString("servidor")
        assumeTrue("Pass -e servidor http://10.0.2.2:8787", server != null)
        val config = OwnAccountNotebook.loadConfig(context)
        val notebookConfig = StudyNotebook.loadConfig(context)
        val derivation = OwnAccountNotebook.derive(OwnAccountNotebook.normalize(OwnAccountNotebook.newCode(config), config)!!, config)
        try {
            val device = OwnAccountProvider(server!!, derivation, config)
            val merged = NotebookSync.sync(context, device, notebookConfig)
            val other = OwnAccountProvider(server, derivation, config)
            val read = other.read()!!
            assertEquals(merged, StudyNotebook.fromJson(JSONObject(read)))

            // Both devices read the same version; the first upload wins and the second one is refused.
            val third = OwnAccountProvider(server, derivation, config)
            third.read()
            other.write(read)
            val refused = runCatching { third.write(read) }.exceptionOrNull()
            assertTrue("An upload over a replaced version must be refused", refused?.message == config.label("conflito"))
        } finally {
            context.getSharedPreferences("caderno_sync", android.content.Context.MODE_PRIVATE).edit().clear().commit()
        }
    }

    /**
     * Android and iPhone with the same sync code exchange notes through the own-account server; runs after
     * the iOS test wrote its note. Opt-in: -e servidor http://10.0.2.2:8787 -e codigo XXXX-...
     */
    @Test
    fun ownAccountCrossPlatformExchange() = runBlocking {
        val arguments = InstrumentationRegistry.getArguments()
        val server = arguments.getString("servidor")
        val code = arguments.getString("codigo")
        assumeTrue("Pass -e servidor and -e codigo", server != null && code != null)
        val config = OwnAccountNotebook.loadConfig(context)
        val provider = OwnAccountProvider(server!!, OwnAccountNotebook.derive(OwnAccountNotebook.normalize(code!!, config)!!, config), config)
        val prefs = context.getSharedPreferences("breviario_prefs", android.content.Context.MODE_PRIVATE)
        try {
            prefs.edit().putString("comment_teste_cruzado_android_01/01", "Anotação feita no Android.").commit()
            val merged = NotebookSync.sync(context, provider, StudyNotebook.loadConfig(context))
            assertEquals("Anotação feita no iPhone.", merged.readings.firstOrNull { it.obraId == "teste_cruzado_ios" }?.comment)
            assertEquals("Anotação feita no iPhone.", prefs.getString("comment_teste_cruzado_ios_01/01", null))
        } finally {
            val editor = prefs.edit()
            prefs.all.keys.filter { "teste_cruzado" in it }.forEach { editor.remove(it) }
            editor.commit()
            context.getSharedPreferences("caderno_sync", android.content.Context.MODE_PRIVATE).edit().clear().commit()
        }
    }
}
