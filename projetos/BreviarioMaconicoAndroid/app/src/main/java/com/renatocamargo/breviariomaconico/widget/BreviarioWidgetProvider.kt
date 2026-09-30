package com.renatocamargo.breviariomaconico.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.renatocamargo.breviariomaconico.MainActivity
import com.renatocamargo.breviariomaconico.R
import com.renatocamargo.breviariomaconico.data.BreviarioRepository
import com.renatocamargo.breviariomaconico.data.TextoFormatter

class BreviarioWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { widgetId ->
            updateWidget(context, manager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // After an app update the launcher shows the empty initial layout until the next periodic
        // update; redraw right away so the widget never stays blank.
        if (intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, BreviarioWidgetProvider::class.java))
            onUpdate(context, manager, ids)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    private fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
        val options = manager.getAppWidgetOptions(widgetId)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 180)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
        manager.updateAppWidget(widgetId, buildViews(context, widgetId, minWidth, minHeight))
    }

    companion object {
        /** Widget content for the given size; public so the instrumented test can render it. */
        fun buildViews(context: Context, widgetId: Int, minWidth: Int, minHeight: Int): RemoteViews {
            val item = BreviarioRepository.get(context).hoje()
            val compact = minWidth < 180 || minHeight < 120
            val large = minWidth >= 250 && minHeight >= 220
            val views = RemoteViews(context.packageName, R.layout.breviario_widget)
            views.setTextViewText(R.id.widgetDate, TextoFormatter.dataPorExtenso(item.data))
            views.setTextViewText(R.id.widgetTitle, item.titulo)
            views.setInt(R.id.widgetTitle, "setMaxLines", if (compact) 4 else 2)
            if (compact) {
                views.setViewVisibility(R.id.widgetExcerpt, View.GONE)
            } else {
                views.setViewVisibility(R.id.widgetExcerpt, View.VISIBLE)
                views.setInt(R.id.widgetExcerpt, "setMaxLines", if (large) 9 else 4)
                views.setTextViewText(R.id.widgetExcerpt, item.texto.take(if (large) 520 else 220))
            }
            val intent = Intent(context, MainActivity::class.java)
                .putExtra("data", item.data)
                .putExtra("obraId", item.obraId)
            val pendingIntent = PendingIntent.getActivity(
                context,
                widgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widgetRoot, pendingIntent)
            return views
        }
    }
}
