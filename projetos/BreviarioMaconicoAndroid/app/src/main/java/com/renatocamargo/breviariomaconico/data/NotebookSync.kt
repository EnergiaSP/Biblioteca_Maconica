package com.renatocamargo.breviariomaconico.data

import android.app.PendingIntent
import android.content.Context
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.api.Scope
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.LocalDate
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject

/** A place where the notebook file is kept for sync (Google Drive, or the app's own account). */
internal interface NotebookProvider {
    val option: NotebookSync.Option
    /** null when there is no notebook there yet. */
    suspend fun read(): String?
    suspend fun write(text: String)
}

/**
 * Sync of the study notebook through the chosen service: read the remote notebook, merge it with the
 * local one without losing anything, apply the result here and write it back. A remote file that
 * cannot be read (a newer version of the app) is never overwritten. Same steps as iOS `CadernoSincronizacao`.
 */
internal object NotebookSync {
    enum class Option(val id: String) { NONE("nenhuma"), GOOGLE("google"), OWN_ACCOUNT("contaPropria") }
    class RemoteUnreadable(message: String) : Exception(message)

    private fun prefs(context: Context) = context.applicationContext.getSharedPreferences("caderno_sync", Context.MODE_PRIVATE)

    fun chosen(context: Context): Option = Option.entries.firstOrNull { it.id == prefs(context).getString("opcao", null) } ?: Option.NONE
    fun choose(context: Context, option: Option) = prefs(context).edit().putString("opcao", option.id).apply()
    fun lastSync(context: Context): Long? = prefs(context).getLong("em", 0L).takeIf { it > 0 }

    fun provider(context: Context, option: Option): NotebookProvider? = when (option) {
        Option.NONE -> null
        Option.GOOGLE -> GoogleDriveNotebook(context)
        Option.OWN_ACCOUNT -> OwnAccountNotebook.provider(context)
    }

    /** Merges the remote notebook here and writes the result back; returns the merged notebook. */
    suspend fun sync(context: Context, provider: NotebookProvider, config: StudyNotebook.Config): StudyNotebook.Notebook {
        val remote = provider.read()?.let { text ->
            val json = runCatching { JSONObject(text) }.getOrNull()
            if (json == null || !StudyNotebook.valid(json, config)) throw RemoteUnreadable(config.label("remotoIlegivel"))
            StudyNotebook.fromJson(json)
        }
        val local = StudyNotebook.collect(context)
        val merged = StudyNotebook.merge(local, remote ?: StudyNotebook.Notebook(), LocalDate.now().toString(), config)
        if (merged != local) StudyNotebook.apply(context, merged)
        if (merged != remote) provider.write(StudyNotebook.toJson(merged, config).toString(2))
        prefs(context).edit().putLong("em", System.currentTimeMillis()).apply()
        return merged
    }

    /** Automatic sync when the app comes back to the foreground; failures wait for the next time. */
    suspend fun syncIfChosen(context: Context) {
        val provider = provider(context, chosen(context)) ?: return
        runCatching { sync(context, provider, StudyNotebook.loadConfig(context)) }
    }
}

/**
 * The notebook in the app's private folder on Google Drive (scope drive.appdata: the app sees no other
 * file). Needs the app's OAuth client in the Google Cloud project; see the Phase 10 report.
 */
internal class GoogleDriveNotebook(private val context: Context) : NotebookProvider {
    override val option = NotebookSync.Option.GOOGLE

    /** The user still has to allow access; the screen launches [intent] and syncs again. */
    class NeedsConsent(val intent: PendingIntent) : Exception()

    private suspend fun token(): String {
        val request = AuthorizationRequest.builder().setRequestedScopes(listOf(Scope(SCOPE))).build()
        val result = try {
            Identity.getAuthorizationClient(context).authorize(request).await()
        } catch (error: Exception) {
            throw IOException(StudyNotebook.loadConfig(context).label("semGoogle"), error)
        }
        if (result.hasResolution()) throw NeedsConsent(result.pendingIntent ?: throw IOException("Autorização do Google indisponível."))
        return result.accessToken ?: throw IOException(StudyNotebook.loadConfig(context).label("semGoogle"))
    }

    private suspend fun request(method: String, url: String, token: String, body: ByteArray? = null, type: String? = null): String =
        withContext(Dispatchers.IO) {
            val connection = URL(url).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = if (method == "PATCH") "POST" else method
                if (method == "PATCH") connection.setRequestProperty("X-HTTP-Method-Override", "PATCH")
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.connectTimeout = 15_000
                connection.readTimeout = 30_000
                if (body != null) {
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", type ?: "application/json; charset=UTF-8")
                    connection.outputStream.use { it.write(body) }
                }
                val code = connection.responseCode
                val stream = if (code in 200..299) connection.inputStream else connection.errorStream
                val text = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
                if (code !in 200..299) throw IOException("Google Drive respondeu $code.")
                text
            } finally {
                connection.disconnect()
            }
        }

    private suspend fun fileId(token: String): String? {
        val query = URLEncoder.encode("name = '$FILE' and trashed = false", "UTF-8")
        val list = JSONObject(request("GET", "$API/files?spaces=appDataFolder&fields=files(id)&q=$query", token))
        return list.optJSONArray("files")?.optJSONObject(0)?.optString("id")?.takeIf { it.isNotEmpty() }
    }

    override suspend fun read(): String? {
        val token = token()
        val id = fileId(token) ?: return null
        return request("GET", "$API/files/$id?alt=media", token)
    }

    override suspend fun write(text: String) {
        val token = token()
        val id = fileId(token)
        if (id != null) {
            request("PATCH", "$UPLOAD/files/$id?uploadType=media", token, text.toByteArray(), "application/json; charset=UTF-8")
            return
        }
        val boundary = "caderno${System.currentTimeMillis()}"
        val metadata = JSONObject().put("name", FILE).put("parents", org.json.JSONArray(listOf("appDataFolder")))
        val body = "--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n" +
            "--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$text\r\n--$boundary--"
        request("POST", "$UPLOAD/files?uploadType=multipart", token, body.toByteArray(), "multipart/related; boundary=$boundary")
    }

    private companion object {
        const val SCOPE = "https://www.googleapis.com/auth/drive.appdata"
        const val FILE = "caderno-biblioteca-maconica.json"
        const val API = "https://www.googleapis.com/drive/v3"
        const val UPLOAD = "https://www.googleapis.com/upload/drive/v3"
    }
}

/**
 * The app's own account: a sync code without e-mail or password; the notebook is encrypted on the device
 * and the server keeps only the encrypted file. Mirrors `Tools/conta_propria_referencia.mjs`;
 * `casos_conta_propria_v1.json` holds the golden cases both apps reproduce.
 */
internal object OwnAccountNotebook {
    data class Config(
        val alphabet: String, val codeBytes: Int, val groupSize: Int, val accountPrefix: String, val credentialPrefix: String,
        val keyPrefix: String, val maxBytes: Int, val server: String, val labels: Map<String, String>
    ) {
        fun label(key: String) = labels[key] ?: key
    }
    data class Derivation(val account: String, val credential: String, val key: ByteArray)

    @Volatile private var cached: Config? = null

    fun loadConfig(context: Context): Config = cached ?: parse(
        context.assets.open("conta_propria_v1.json").bufferedReader().use { JSONObject(it.readText()) }
    ).also { cached = it }

    fun parse(json: JSONObject): Config {
        require(json.getInt("schemaVersion") == 1)
        val labels = json.getJSONObject("rotulos")
        return Config(json.getString("alfabeto"), json.getInt("bytesCodigo"), json.getInt("tamanhoGrupo"), json.getString("prefixoConta"),
            json.getString("prefixoCredencial"), json.getString("prefixoChave"), json.getInt("tamanhoMaximoBytes"), json.getString("servidor"),
            labels.keys().asSequence().associateWith { labels.getString(it) })
    }

    fun format(bytes: ByteArray, config: Config): String {
        val out = StringBuilder()
        var bits = 0
        var value = 0
        for (byte in bytes) {
            value = ((value shl 8) or (byte.toInt() and 0xFF)) and 0xFFFF
            bits += 8
            while (bits >= 5) {
                out.append(config.alphabet[(value shr (bits - 5)) and 31])
                bits -= 5
            }
        }
        if (bits > 0) out.append(config.alphabet[(value shl (5 - bits)) and 31])
        return group(out.toString(), config)
    }

    /** "ABCDEFGH..." as "ABCD-EFGH-...". */
    fun group(code: String, config: Config) = code.chunked(config.groupSize).joinToString("-")

    fun newCode(config: Config): String = format(ByteArray(config.codeBytes).also { java.security.SecureRandom().nextBytes(it) }, config)

    /** Upper case, without hyphens and spaces; null unless it has the exact length and only alphabet letters. */
    fun normalize(code: String, config: Config): String? {
        val clean = code.uppercase().filter { it != '-' && !it.isWhitespace() }
        val length = (config.codeBytes * 8 + 4) / 5
        return clean.takeIf { it.length == length && it.all { c -> c in config.alphabet } }
    }

    private fun sha(text: String) = java.security.MessageDigest.getInstance("SHA-256").digest(text.toByteArray(Charsets.UTF_8))
    private fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it) }

    fun derive(code: String, config: Config) = Derivation(hex(sha(config.accountPrefix + code)).take(32),
        hex(sha(config.credentialPrefix + code)), sha(config.keyPrefix + code))

    /** nonce (12 bytes) + ciphertext + tag (16 bytes), AES-256-GCM. */
    fun encrypt(data: ByteArray, key: ByteArray, nonce: ByteArray = ByteArray(12).also { java.security.SecureRandom().nextBytes(it) }): ByteArray {
        val cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, javax.crypto.spec.SecretKeySpec(key, "AES"), javax.crypto.spec.GCMParameterSpec(128, nonce))
        return nonce + cipher.doFinal(data)
    }

    fun decrypt(combined: ByteArray, key: ByteArray): ByteArray {
        val cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(javax.crypto.Cipher.DECRYPT_MODE, javax.crypto.spec.SecretKeySpec(key, "AES"),
            javax.crypto.spec.GCMParameterSpec(128, combined, 0, 12))
        return cipher.doFinal(combined, 12, combined.size - 12)
    }

    /** The published server, or a local one for tests (`servidorTeste` in caderno_sync). */
    fun server(context: Context): String =
        context.applicationContext.getSharedPreferences("caderno_sync", Context.MODE_PRIVATE).getString("servidorTeste", null)
            ?: loadConfig(context).server

    /** The option is offered once the server is published. */
    fun available(context: Context) = server(context).isNotEmpty()

    fun storedCode(context: Context): String? = SecureKeyStore(context).loadNotebookCode().ifBlank { null }
    fun storeCode(context: Context, code: String?) = SecureKeyStore(context).saveNotebookCode(code.orEmpty())

    fun provider(context: Context): NotebookProvider? {
        val config = loadConfig(context)
        val code = storedCode(context)?.let { normalize(it, config) } ?: return null
        return if (available(context)) OwnAccountProvider(server(context), derive(code, config), config) else null
    }
}

/** Reads and writes the encrypted notebook; the version read is sent back, so an upload never replaces one made in between. */
internal class OwnAccountProvider(
    server: String, private val derivation: OwnAccountNotebook.Derivation, private val config: OwnAccountNotebook.Config
) : NotebookProvider {
    override val option = NotebookSync.Option.OWN_ACCOUNT
    private val url = "${server.trim('/')}/v1/caderno/${derivation.account}"
    private var version: String? = null

    private suspend fun send(method: String, body: ByteArray? = null, headers: Map<String, String> = emptyMap()): Pair<Int, ByteArray> =
        withContext(Dispatchers.IO) {
            try {
                val connection = URL(url).openConnection() as HttpURLConnection
                try {
                    connection.requestMethod = method
                    connection.useCaches = false
                    connection.connectTimeout = 15_000
                    connection.readTimeout = 30_000
                    connection.setRequestProperty("Authorization", "Bearer ${derivation.credential}")
                    headers.forEach { (name, value) -> connection.setRequestProperty(name, value) }
                    if (body != null) {
                        connection.doOutput = true
                        connection.setRequestProperty("Content-Type", "application/octet-stream")
                        connection.outputStream.use { it.write(body) }
                    }
                    val code = connection.responseCode
                    if (code == 200 || code == 204) connection.getHeaderField("ETag")?.let { version = it }
                    val stream = if (code in 200..299) connection.inputStream else connection.errorStream
                    code to (stream?.use { it.readBytes() } ?: ByteArray(0))
                } finally {
                    connection.disconnect()
                }
            } catch (error: IOException) {
                throw IOException(config.label("semRede"), error)
            }
        }

    override suspend fun read(): String? {
        val (code, body) = send("GET")
        return when (code) {
            404 -> { version = null; null }
            200 -> String(OwnAccountNotebook.decrypt(body, derivation.key), Charsets.UTF_8)
            else -> throw IOException(config.label("semRede"))
        }
    }

    override suspend fun write(text: String) {
        val current = version
        val (code, _) = send("PUT", OwnAccountNotebook.encrypt(text.toByteArray(Charsets.UTF_8), derivation.key),
            if (current != null) mapOf("If-Match" to current) else mapOf("If-None-Match" to "*"))
        when (code) {
            204 -> Unit
            412 -> throw IOException(config.label("conflito"))
            else -> throw IOException(config.label("semRede"))
        }
    }
}
