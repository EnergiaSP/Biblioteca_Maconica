package com.renatocamargo.breviariomaconico

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.renatocamargo.breviariomaconico.data.DossierAnalysis
import com.renatocamargo.breviariomaconico.data.SavedDossier
import com.renatocamargo.breviariomaconico.data.SavedDossierStore
import java.time.LocalDate
import java.time.ZoneId

/**
 * One notification per pending review of a saved dossier, at the shared reminder time
 * (`lembreteRevisao`). Tapping it opens the saved dossier, as on iOS.
 */
internal object DossierReminders {
    private const val CHANNEL = "dossie_revisao"

    fun uri(id: String): Uri = Uri.Builder().scheme("breviario").authority("dossie").appendQueryParameter("id", id).build()

    fun schedule(context: Context, saved: SavedDossier, config: DossierAnalysis.Config) {
        cancel(context, saved, config)
        val alarms = context.getSystemService(AlarmManager::class.java)
        val now = System.currentTimeMillis()
        saved.reviews(config.review, LocalDate.now())
            .filter { it.status != SavedDossier.Status.FEITA }
            .forEach { review ->
                val at = review.date.atTime(config.reviewReminder.hour, config.reviewReminder.minute)
                    .atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
                if (at > now) alarms.set(AlarmManager.RTC_WAKEUP, at, pending(context, saved, review.days, review.task))
            }
    }

    fun cancel(context: Context, saved: SavedDossier, config: DossierAnalysis.Config) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        config.review.forEach { step -> pending(context, saved, step.days, step.task).let { alarms.cancel(it); it.cancel() } }
    }

    fun isScheduled(context: Context, saved: SavedDossier, days: Int): Boolean =
        PendingIntent.getBroadcast(context, "${saved.id}:$days".hashCode(),
            Intent(context, DossierReviewReceiver::class.java).setData(uri(saved.id).buildUpon().appendQueryParameter("dias", days.toString()).build()),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE) != null

    fun rescheduleAll(context: Context) {
        val config = DossierAnalysis.loadConfig(context)
        SavedDossierStore(context).all().forEach { schedule(context, it, config) }
    }

    private fun pending(context: Context, saved: SavedDossier, days: Int, task: String): PendingIntent {
        val intent = Intent(context, DossierReviewReceiver::class.java)
            .setData(uri(saved.id).buildUpon().appendQueryParameter("dias", days.toString()).build())
            .putExtra("tema", saved.tema)
            .putExtra("tarefa", task)
        return PendingIntent.getBroadcast(context, "${saved.id}:$days".hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    fun post(context: Context, id: String, tema: String, tarefa: String, days: Int) {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(NotificationChannel(CHANNEL, "Revisão de dossiês", NotificationManager.IMPORTANCE_DEFAULT))
        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            data = uri(id)
        }
        val tap = PendingIntent.getActivity(context, "$id:$days:open".hashCode(), open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_menu_agenda)
            .setContentTitle("Revisão do dossiê: $tema")
            .setContentText(tarefa)
            .setStyle(NotificationCompat.BigTextStyle().bigText(tarefa))
            .setContentIntent(tap)
            .addAction(android.R.drawable.ic_menu_view, "Abrir dossiê", tap)
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(context).notify("$id:$days".hashCode(), notification)
    }
}

class DossierReviewReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val data = intent?.data ?: return
        val id = data.getQueryParameter("id") ?: return
        val days = data.getQueryParameter("dias")?.toIntOrNull() ?: return
        // Skip reviews completed or dossiers removed after the alarm was set.
        val saved = SavedDossierStore(context).find(id) ?: return
        if (days in saved.revisoesConcluidas) return
        DossierReminders.post(context, id, saved.tema, intent.getStringExtra("tarefa").orEmpty(), days)
    }
}
