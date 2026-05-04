package com.example.smartfridge

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews

class SmartFridgeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isDark = flutterPrefs.getBoolean("flutter.dark_mode", false)

        val bgColor      = if (isDark) Color.parseColor("#0F1F14") else Color.parseColor("#F2F9F5")
        val titleColor   = if (isDark) Color.parseColor("#74DB77") else Color.parseColor("#1A7A45")
        val dividerColor = if (isDark) Color.parseColor("#2A4A32") else Color.parseColor("#CCDDCC")

        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.smartfridge_widget)

            views.setInt(R.id.widget_root,    "setBackgroundColor", bgColor)
            views.setTextColor(R.id.widget_title,   titleColor)
            views.setInt(R.id.widget_divider, "setBackgroundColor", dividerColor)

            // ListView adapter beállítása – minden widget-példányhoz egyedi Uri
            val serviceIntent = Intent(context, SmartFridgeWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_list, serviceIntent)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
        }
    }
}
