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
package org.isoron.uhabits.widgets.views

import android.content.Context
import android.view.View
import android.widget.TextView
import org.isoron.uhabits.R

/**
 * Port of `uhabits-android/.../widgets/views/EmptyWidgetView.kt`.
 *
 * `widgets.empty#2`: the graph widgets' own shell, with the title shown and
 * nothing added below it — so what the user sees while a stack page loads is
 * the same rounded card the finished page will be, minus its contents.
 *
 * [setTitle] is upstream's and is deliberately never called: the title stays
 * empty, which is what makes the placeholder blank.
 */
class EmptyWidgetView(context: Context) : HabitWidgetView(context) {

    private val title: TextView

    override val innerLayoutId: Int
        get() = R.layout.widget_graph

    init {
        inflateAndBuild()
        title = findViewById<View>(R.id.title) as TextView
        title.visibility = VISIBLE
    }

    fun setTitle(text: String?) {
        title.text = text
    }
}
