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
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import java.util.Calendar

object WearNotificationScheduler {
    private const val requestCode = 816

    fun scheduleDaily(context: Context) {
        context.getSharedPreferences("wear_progress", Context.MODE_PRIVATE).edit().putBoolean("daily_notification", true).apply()
        schedule(context, nextEightAm(), repeating = true)
    }

    fun scheduleTest(context: Context) {
        schedule(context, System.currentTimeMillis() + 5_000, repeating = false, code = requestCode + 1)
    }

    fun cancel(context: Context) {
        context.getSharedPreferences("wear_progress", Context.MODE_PRIVATE).edit().putBoolean("daily_notification", false).apply()
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(pendingIntent(context, requestCode))
    }

    fun restore(context: Context) {
        if (context.getSharedPreferences("wear_progress", Context.MODE_PRIVATE).getBoolean("daily_notification", false)) {
            schedule(context, nextEightAm(), repeating = true)
        }
    }

    private fun schedule(context: Context, at: Long, repeating: Boolean, code: Int = requestCode) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = pendingIntent(context, code)
        if (repeating) manager.setInexactRepeating(AlarmManager.RTC_WAKEUP, at, AlarmManager.INTERVAL_DAY, pending)
        else manager.set(AlarmManager.RTC_WAKEUP, at, pending)
    }

    private fun pendingIntent(context: Context, code: Int): PendingIntent = PendingIntent.getBroadcast(
        context,
        code,
        Intent(context, WearNotificationReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    private fun nextEightAm(): Long = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 8); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
    }.timeInMillis
}

class WearNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val reading = runCatching { loadWearReading(context) }.getOrNull() ?: return
        val channelId = "wear_daily_reading"
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(channelId, "Leitura diária", NotificationManager.IMPORTANCE_DEFAULT)
        )
        val open = PendingIntent.getActivity(
            context,
            817,
            Intent(context, WearMainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                data = android.net.Uri.Builder().scheme("breviario").authority("leitura").appendQueryParameter("obra", reading.obraId).appendQueryParameter("data", reading.data).build()
                putExtra("obraId", reading.obraId)
                putExtra("data", reading.data)
                putExtra("abrirLeitura", true)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(com.renatocamargo.breviariomaconico.wear.R.drawable.ic_launcher)
            .setContentTitle("Biblioteca Maçônica")
            .setContentText("${reading.data} • ${reading.titulo}")
            .setContentIntent(open)
            .addAction(com.renatocamargo.breviariomaconico.wear.R.drawable.ic_launcher, "Abrir leitura", open)
            .setAutoCancel(true)
            .build()
        if (android.os.Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            NotificationManagerCompat.from(context).notify(817, notification)
        }
    }
}

class WearBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED || intent?.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            WearNotificationScheduler.restore(context)
        }
    }
}
