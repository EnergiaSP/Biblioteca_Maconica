package com.renatocamargo.breviariomaconico.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
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

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    private fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
        val item = BreviarioRepository.get(context).hoje()
        val options = manager.getAppWidgetOptions(widgetId)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 180)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
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
        manager.updateAppWidget(widgetId, views)
    }
}
