package com.renatocamargo.breviariomaconico

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.renatocamargo.breviariomaconico.data.BreviarioRepository
import com.renatocamargo.breviariomaconico.data.PreferencesStore

class NotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val repo = BreviarioRepository.get(context)
        val settings = PreferencesStore(context).settings
        val items = repo.leiturasDeHoje(settings.notificationWorkIds).ifEmpty { listOf(repo.hoje()) }
        val channelId = "breviario_daily"
        val channel = NotificationChannel(channelId, "Leitura diária", NotificationManager.IMPORTANCE_DEFAULT)
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)

        items.forEachIndexed { index, item ->
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                data = android.net.Uri.Builder().scheme("breviario").authority("leitura").appendQueryParameter("obra", item.obraId).appendQueryParameter("data", item.data).build()
                putExtra("data", item.data)
                putExtra("obraId", item.obraId)
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                10 + index,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(android.R.drawable.ic_menu_today)
                .setContentTitle("Biblioteca Maçônica")
                .setContentText("${item.titulo} • toque para abrir a leitura")
                .setStyle(NotificationCompat.BigTextStyle().bigText(item.texto.take(420)))
                .setContentIntent(pendingIntent)
                .addAction(android.R.drawable.ic_menu_view, "Abrir leitura", pendingIntent)
                .setAutoCancel(true)
                .build()

            if (Build.VERSION.SDK_INT < 33 ||
                ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
            ) {
                NotificationManagerCompat.from(context).notify(2026 + index, notification)
            }
        }
    }
}
