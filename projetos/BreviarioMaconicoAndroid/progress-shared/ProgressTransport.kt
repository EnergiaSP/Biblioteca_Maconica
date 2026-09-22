package com.renatocamargo.breviariomaconico.progress

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.tasks.await
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

object ProgressTransport {
    const val PATH = "/reading-progress"
    const val DATA_PATH = "/reading-progress-state"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val deliveryLock = Mutex()
    private val stateLock = Any()
    private val main = Handler(Looper.getMainLooper())

    fun parse(json: JSONObject): ProgressVersion? {
        if (json.opt("lido") !is Boolean) return null
        return ProgressVersion(json.optString("obraId"), json.optString("data"), json.getBoolean("lido"),
            json.optLong("atualizadoEm", 0), json.optString("eventoID", "legacy")).takeIf { it.valid() }
    }
    fun parse(data: DataMap): ProgressVersion? {
        if (!data.containsKey("lido")) return null
        return ProgressVersion(data.getString("obraId").orEmpty(), data.getString("data").orEmpty(),
            data.getBoolean("lido"), data.getLong("atualizadoEm", 0), data.getString("eventoID") ?: "legacy").takeIf { it.valid() }
    }
    private fun json(event: ProgressVersion) = JSONObject().put("obraId", event.work).put("data", event.date)
        .put("lido", event.read).put("atualizadoEm", event.timestamp).put("eventoID", event.eventId)

    private fun load(context: Context): ProgressLedger {
        val saved = context.getSharedPreferences("reading_progress_sync_v1", Context.MODE_PRIVATE)
        fun entries(key: String): MutableMap<String, ProgressVersion> {
            val array = runCatching { JSONArray(saved.getString(key, "[]")) }.getOrElse { JSONArray() }
            return (0 until array.length()).mapNotNull { array.optJSONObject(it)?.let(::parse) }.associateBy { it.key }.toMutableMap()
        }
        return ProgressLedger(entries("latest"), entries("pending"))
    }
    private fun save(context: Context, ledger: ProgressLedger) {
        context.getSharedPreferences("reading_progress_sync_v1", Context.MODE_PRIVATE).edit()
            .putString("latest", JSONArray(ledger.latest.values.map(::json)).toString())
            .putString("pending", JSONArray(ledger.pending.values.map(::json)).toString()).apply()
    }
    fun send(context: Context, work: String, date: String, read: Boolean) {
        val app = context.applicationContext
        synchronized(stateLock) {
            val ledger = load(app)
            if (ledger.edit(work, date, read, System.currentTimeMillis(), UUID.randomUUID().toString()) == null) return
            save(app, ledger)
        }
        flush(app)
    }
    fun receive(context: Context, event: ProgressVersion?, apply: (ProgressVersion) -> Unit) {
        if (event == null) return
        val app = context.applicationContext
        // Serialize incoming updates with UI edits before changing preferences.
        main.post {
            val accepted = synchronized(stateLock) {
                val ledger = load(app)
                if (ledger.receive(event)) {
                    save(app, ledger)
                    true
                } else false
            }
            // An observer can enqueue another edit. Persist first so that edit is not overwritten.
            if (accepted) apply(event)
        }
    }
    fun flush(context: Context) {
        val app = context.applicationContext
        scope.launch {
            deliveryLock.withLock {
                val events = synchronized(stateLock) { load(app).pending.values.toList() }
                for (event in events) {
                    val queued = runCatching {
                        val request = PutDataMapRequest.create("$DATA_PATH/${android.net.Uri.encode(event.work)}/${event.date.replace('/', '-')}").apply {
                            dataMap.putString("obraId", event.work)
                            dataMap.putString("data", event.date)
                            dataMap.putBoolean("lido", event.read)
                            dataMap.putLong("atualizadoEm", event.timestamp)
                            dataMap.putString("eventoID", event.eventId)
                        }.asPutDataRequest().setUrgent()
                        Wearable.getDataClient(app).putDataItem(request).await()
                    }.isSuccess
                    if (!queued) continue
                    synchronized(stateLock) {
                        val ledger = load(app)
                        ledger.delivered(event)
                        save(app, ledger)
                    }
                    runCatching {
                        val bytes = json(event).toString().toByteArray(Charsets.UTF_8)
                        Wearable.getNodeClient(app).connectedNodes.await().forEach {
                            Wearable.getMessageClient(app).sendMessage(it.id, PATH, bytes).await()
                        }
                    }
                }
            }
        }
    }
}
