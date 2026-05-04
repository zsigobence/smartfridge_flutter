package com.example.smartfridge

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class SmartFridgeWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return SmartFridgeWidgetFactory(applicationContext)
    }
}

class SmartFridgeWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private val items = mutableListOf<Pair<String, String>>()
    private var isDark = false
    private var nameColor  = Color.parseColor("#1C2B1F")
    private var titleColor = Color.parseColor("#1A7A45")

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val widgetPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        isDark     = flutterPrefs.getBoolean("flutter.dark_mode", false)
        nameColor  = if (isDark) Color.parseColor("#D8F0DC") else Color.parseColor("#1C2B1F")
        titleColor = if (isDark) Color.parseColor("#74DB77") else Color.parseColor("#1A7A45")

        items.clear()
        val count = widgetPrefs.getInt("item_count", 0)
        for (i in 0 until count) {
            val name = widgetPrefs.getString("item_${i}_name", "") ?: ""
            val date = widgetPrefs.getString("item_${i}_date", "") ?: ""
            if (name.isNotEmpty()) items.add(name to date)
        }
    }

    override fun onDestroy() = items.clear()

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.smartfridge_widget_item)
        if (position >= items.size) return views

        val (name, date) = items[position]
        val dateColor = when {
            date.contains("lejárt") -> Color.parseColor("#D32F2F")
            date == "ma!" || date == "holnap" ->
                if (isDark) Color.parseColor("#FFB74D") else Color.parseColor("#E65100")
            else -> titleColor
        }

        views.setTextViewText(R.id.item_name, name)
        views.setTextViewText(R.id.item_date, date)
        views.setTextColor(R.id.item_name, nameColor)
        views.setTextColor(R.id.item_date, dateColor)
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
