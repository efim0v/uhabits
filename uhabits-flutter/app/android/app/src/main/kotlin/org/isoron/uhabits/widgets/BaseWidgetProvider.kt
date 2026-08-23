/*
 * Copyright (C) 2016-2025 Álinson Santos Xavier <git@axavier.org>
 *
 * This file is part of Loop Habit Tracker.
 *
 * Loop Habit Tracker is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * Loop Habit Tracker is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */
package org.isoron.uhabits.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle
import android.os.Looper
import android.widget.RemoteViews
import org.isoron.uhabits.R

/**
 * Port of `uhabits-android/.../widgets/BaseWidgetProvider.kt`.
 *
 * `widgets.provider-lifecycle#1`: upstream resolves `habitList`, `preferences`
 * and `widgetPreferences` from the application component and calls
 * `context.setTheme(R.style.WidgetTheme)` before drawing. There is no component
 * to resolve — the data is read per widget from [WidgetData] — and no
 * `WidgetTheme` style, because `widgets.theme#5` says widgets never follow the
 * app theme, so the palette is the compile-time constant [WidgetTheme] and the
 * `setTheme` call has nothing left to do.
 */
abstract class BaseWidgetProvider : AppWidgetProvider() {

    /**
     * `widgets.stack#1`: the StackWidgetType this provider's widgets become
     * when their document holds anything other than exactly one habit.
     */
    protected abstract val stackWidgetType: StackWidgetType

    /** The provider's own widget, for the ordinary one-habit case. */
    protected abstract fun buildSingleWidget(
        context: Context,
        widgetId: Int,
        document: WidgetDocument
    ): BaseWidget

    /**
     * `widgets.stack#1`: a single-habit widget only when exactly one habit is
     * bound; 0 or 2+ habits are a StackWidget of the matching type.
     *
     * Two or more is what a home screen carried over from the Kotlin build
     * looks like — `settings.widget-preferences.habit-ids` still reads its
     * comma-separated `widget-%06d-habit` values. Zero is a widget bound to
     * nothing, which draws the type's empty label (`widgets.error-states#4`).
     */
    private fun buildWidget(
        context: Context,
        widgetId: Int,
        document: WidgetDocument
    ): BaseWidget {
        val widget = if (document.isStack()) {
            StackWidget(context, widgetId, stackWidgetType, document.habits)
        } else {
            buildSingleWidget(context, widgetId, document)
        }
        // `settings.preferences.widget-opacity#5`: upstream read
        // `prefs.widgetOpacity` out of the application component, because the
        // provider and the app were the same program. The preference now
        // arrives in the document instead, and every widget gets it before it
        // is measured or drawn. A StackWidget is `stacked` and discards it,
        // which is `settings.preferences.widget-opacity#7`.
        widget.setWidgetOpacity(document.widgetOpacity)
        return widget
    }

    /**
     * `widgets.provider-lifecycle#1`: update every id in the array on a
     * background thread that first calls `Looper.prepare()`.
     *
     * The `Looper.prepare()` is not ceremony: inflating a `View` off the main
     * thread needs a Looper on that thread, and the whole render path here is
     * view inflation.
     */
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        widgetIds: IntArray
    ) {
        val pending = goAsync()
        Thread {
            try {
                if (Looper.myLooper() == null) Looper.prepare()
                for (id in widgetIds) update(context, manager, id)
            } finally {
                pending.finish()
            }
        }.start()
    }

    /**
     * `widgets.provider-lifecycle#4`: the resize callback does the same work on
     * the calling thread, using the supplied options bundle rather than asking
     * the manager for one.
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        options: Bundle
    ) {
        try {
            val widget = getWidgetFromId(context, widgetId)
            widget.setDimensions(getDimensionsFromOptions(context, options))
            updateAppWidget(manager, widget)
        } catch (e: RuntimeException) {
            drawErrorWidget(context, manager, widgetId, e)
            e.printStackTrace()
        }
    }

    /**
     * `widgets.provider-lifecycle#7`, `#8`: reject a null context or id array,
     * then delete each widget's stored habit mapping, skipping the ones that no
     * longer resolve.
     *
     * `BaseWidget.delete()` called `WidgetPreferences.removeWidget(id)` in the
     * app's own SharedPreferences. The mapping now lives on the Dart side, in
     * `WidgetRegistry`, which is the only thing that may write it — a native
     * writer would race the Flutter one and there is no lock between the two
     * processes. So this does the two things that are unambiguously ours: it
     * drops the published document (the launcher's copy of the data), and it
     * *records the ids* under [WidgetData.DELETED_KEY].
     *
     * That record is the whole point. Without it the Dart registry never learns
     * the widget is gone: it keeps the `widget-%06d-habit` binding, keeps
     * listing the widget in the published index, and republishes a document for
     * it after every command, forever
     * (`audit4.deleting-a-widget-from-the-launcher#1`). Dropping the document
     * alone does not help — `HomeWidgetBridge.publish` only clears documents for
     * ids the *registry* no longer has, and nothing was ever going to remove one
     * from the registry. `HomeWidgetBridge.reapDeletedWidgets` consumes this
     * record at the start of the next publish and calls
     * `WidgetRegistry.removeWidget` for each id, which is
     * `WidgetPreferences.removeWidget` again, one process over.
     */
    override fun onDeleted(context: Context?, ids: IntArray?) {
        if (context == null) throw RuntimeException("context is null")
        if (ids == null) throw RuntimeException("ids is null")
        val storage = WidgetData.storage(context)
        val editor = storage.edit()
        for (id in ids) editor.remove(WidgetData.documentKey(id))
        editor.putString(WidgetData.DELETED_KEY, WidgetData.recordDeleted(storage, ids))
        editor.apply()
    }

    /**
     * `widgets.dimensions#2`: the four option ints are in dp; portrait is
     * (minWidth x maxHeight) and landscape is (maxWidth x minHeight)
     * (`widgets.dimensions#3`).
     */
    fun getDimensionsFromOptions(ctx: Context, options: Bundle): WidgetDimensions {
        val maxWidth = dpToPixels(
            ctx,
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH).toFloat()
        ).toInt()
        val maxHeight = dpToPixels(
            ctx,
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT).toFloat()
        ).toInt()
        val minWidth = dpToPixels(
            ctx,
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH).toFloat()
        ).toInt()
        val minHeight = dpToPixels(
            ctx,
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT).toFloat()
        ).toInt()
        return WidgetDimensions(minWidth, maxHeight, maxWidth, minHeight)
    }

    /**
     * `widgets.provider-lifecycle#9`, restated for a published document: a
     * widget whose habit no longer resolves raises [HabitNotFoundException] for
     * the whole widget.
     */
    private fun getWidgetFromId(context: Context, widgetId: Int): BaseWidget {
        val document = WidgetData.readWidget(context, widgetId)
        return buildWidget(context, widgetId, document)
    }

    /** `widgets.provider-lifecycle#2`. */
    private fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
        try {
            val widget = getWidgetFromId(context, widgetId)
            val options = manager.getAppWidgetOptions(widgetId)
            widget.setDimensions(getDimensionsFromOptions(context, options))
            updateAppWidget(manager, widget)
        } catch (e: RuntimeException) {
            drawErrorWidget(context, manager, widgetId, e)
            e.printStackTrace()
        }
    }

    /**
     * `widgets.provider-lifecycle#5`, `#6` and `widgets.error-states#1`, `#2`:
     * any RuntimeException becomes the error widget, and a
     * [HabitNotFoundException] relabels it 'Habit deleted / not found'.
     *
     * Two labels upstream does not have, because upstream cannot reach these
     * states: a widget the Flutter side has never published for
     * ([WidgetNotConfiguredException]) and a document from a schema this build
     * does not know ([UnknownSchemaException]).
     *
     * `audit.android-widget-chrome-text-is-hard#1`: all three are string
     * resources rather than Kotlin literals, and are resolved against the
     * widget's own [Context], so the launcher's locale — and the Android 13
     * per-app language — decides the wording. They cannot travel in the
     * published document instead: two of the three are drawn precisely because
     * there is no readable document (`WidgetNotConfiguredException` *is* "no
     * document", `UnknownSchemaException` is "a document this build cannot
     * parse"). the `res/values-<locale>/strings.xml` files are generated from
     * `app/lib/l10n/app_*.arb`; see app/test/platform/widget_strings_test.dart.
     */
    private fun drawErrorWidget(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        e: RuntimeException
    ) {
        val errorView = RemoteViews(context.packageName, R.layout.widget_error)
        val label = when (e) {
            is HabitNotFoundException -> R.string.habit_not_found
            is WidgetNotConfiguredException -> R.string.widget_not_configured
            is UnknownSchemaException -> R.string.widget_update_required
            else -> null
        }
        if (label != null) {
            errorView.setCharSequence(R.id.label, "setText", context.getString(label))
        }
        manager.updateAppWidget(widgetId, errorView)
    }

    companion object {
        /**
         * `widgets.provider-lifecycle#3`: build landscape first, then portrait,
         * combine them, and push the pair.
         */
        fun updateAppWidget(manager: AppWidgetManager, widget: BaseWidget) {
            val landscape = widget.landscapeRemoteViews
            val portrait = widget.portraitRemoteViews
            manager.updateAppWidget(widget.id, RemoteViews(landscape, portrait))
        }
    }
}
