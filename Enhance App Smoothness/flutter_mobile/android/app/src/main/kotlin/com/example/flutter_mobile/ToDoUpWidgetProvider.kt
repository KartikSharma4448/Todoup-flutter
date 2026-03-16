package app.todoup

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class ToDoUpWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.todoup_widget).apply {
                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("todoup://widget/home"),
                )
                setOnClickPendingIntent(R.id.todoup_widget_root, launchIntent)

                setTextViewText(
                    R.id.widget_header,
                    widgetData.getString("todoup_header", "ToDoUp"),
                )
                setTextViewText(
                    R.id.widget_subtitle,
                    widgetData.getString("todoup_subtitle", "Today's focus"),
                )
                setTextViewText(
                    R.id.widget_score,
                    (widgetData.getInt("todoup_score", 0)).toString(),
                )
                setTextViewText(
                    R.id.widget_progress,
                    widgetData.getString("todoup_progress_label", "No tasks today"),
                )
                setTextViewText(
                    R.id.widget_completion,
                    widgetData.getString("todoup_completion_label", "0% complete"),
                )
                setTextViewText(
                    R.id.widget_footer,
                    widgetData.getString("todoup_footer_label", "Inbox clear"),
                )
                setTextViewText(
                    R.id.widget_updated_at,
                    widgetData.getString("todoup_updated_at", "Waiting for sync"),
                )

                val taskCount = widgetData.getInt("todoup_task_count", 0)
                setViewVisibility(
                    R.id.widget_empty_state,
                    if (taskCount == 0) View.VISIBLE else View.GONE,
                )

                bindTaskRow(widgetData, 0, R.id.task_1_row, R.id.task_1_icon, R.id.task_1_title, R.id.task_1_subtitle)
                bindTaskRow(widgetData, 1, R.id.task_2_row, R.id.task_2_icon, R.id.task_2_title, R.id.task_2_subtitle)
                bindTaskRow(widgetData, 2, R.id.task_3_row, R.id.task_3_icon, R.id.task_3_title, R.id.task_3_subtitle)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun RemoteViews.bindTaskRow(
        widgetData: SharedPreferences,
        index: Int,
        rowId: Int,
        iconId: Int,
        titleId: Int,
        subtitleId: Int,
    ) {
        val title = widgetData.getString("todoup_task_${index}_title", "").orEmpty()
        if (title.isBlank()) {
            setViewVisibility(rowId, View.GONE)
            return
        }

        val category = widgetData.getString("todoup_task_${index}_category", "").orEmpty()
        val subtitle = widgetData.getString("todoup_task_${index}_subtitle", "").orEmpty()
        val completed = widgetData.getBoolean("todoup_task_${index}_completed", false)

        setViewVisibility(rowId, View.VISIBLE)
        setTextViewText(iconId, categoryEmoji(category))
        setTextViewText(titleId, if (completed) "Done: $title" else title)
        setTextViewText(subtitleId, subtitle)
    }

    private fun categoryEmoji(category: String): String {
        return when (category) {
            "work" -> "\uD83D\uDCBC"
            "personal" -> "\u2764\uFE0F"
            "health" -> "\uD83C\uDFCB\uFE0F"
            "study" -> "\uD83D\uDCDA"
            "shopping" -> "\uD83D\uDED2"
            else -> "\u2705"
        }
    }
}
