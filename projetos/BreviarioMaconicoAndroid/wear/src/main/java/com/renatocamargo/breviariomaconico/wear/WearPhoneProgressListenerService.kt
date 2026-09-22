package com.renatocamargo.breviariomaconico.wear

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import com.renatocamargo.breviariomaconico.progress.ProgressTransport
import com.renatocamargo.breviariomaconico.progress.ProgressVersion
import org.json.JSONObject

class WearPhoneProgressListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != ProgressTransport.PATH) return
        apply(runCatching { ProgressTransport.parse(JSONObject(event.data.toString(Charsets.UTF_8))) }.getOrNull())
    }

    override fun onDataChanged(events: DataEventBuffer) {
        events.filter { it.type == DataEvent.TYPE_CHANGED && it.dataItem.uri.path?.startsWith("${ProgressTransport.DATA_PATH}/") == true }
            .forEach { apply(runCatching { ProgressTransport.parse(DataMapItem.fromDataItem(it.dataItem).dataMap) }.getOrNull()) }
    }

    private fun apply(event: ProgressVersion?) = ProgressTransport.receive(applicationContext, event) {
        getSharedPreferences("wear_progress", MODE_PRIVATE).edit().putBoolean("${it.work}:${it.date}", it.read).apply()
    }
}
