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

/** The app's own account (end-to-end encrypted notebook on the app's server); offered once published. */
internal object OwnAccountNotebook {
    fun provider(context: Context): NotebookProvider? = null
}
