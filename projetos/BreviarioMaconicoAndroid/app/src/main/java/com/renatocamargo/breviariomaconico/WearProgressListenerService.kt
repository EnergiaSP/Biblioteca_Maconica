package com.renatocamargo.breviariomaconico

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import com.renatocamargo.breviariomaconico.data.PreferencesStore
import com.renatocamargo.breviariomaconico.progress.ProgressTransport
import com.renatocamargo.breviariomaconico.progress.ProgressVersion
import org.json.JSONObject

class WearProgressListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != PATH) return
        apply(runCatching { ProgressTransport.parse(JSONObject(event.data.toString(Charsets.UTF_8))) }.getOrNull())
    }

    override fun onDataChanged(events: DataEventBuffer) {
        events.filter { it.type == DataEvent.TYPE_CHANGED && it.dataItem.uri.path?.startsWith("$DATA_PATH/") == true }
            .forEach { apply(runCatching { ProgressTransport.parse(DataMapItem.fromDataItem(it.dataItem).dataMap) }.getOrNull()) }
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
