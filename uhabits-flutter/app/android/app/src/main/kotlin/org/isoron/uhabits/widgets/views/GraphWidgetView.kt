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
import android.view.ViewGroup
import android.widget.TextView
import org.isoron.uhabits.R

/**
 * Port of `uhabits-android/.../widgets/views/GraphWidgetView.kt`.
 *
 * `widgets.graph-view#2`: the chart is added to `innerFrame` below the title
 * with MATCH_PARENT x MATCH_PARENT, and the title is made visible.
 * `widgets.graph-view#3`: the title is the habit name, at most two lines.
 * `widgets.graph-view#4`: shared by Frequency, Score, Streak, Target and
 * History; only Checkmark uses a different layout.
 */
class GraphWidgetView(context: Context, val dataView: View) : HabitWidgetView(context) {

    private val title: TextView

    override val innerLayoutId: Int
        get() = R.layout.widget_graph

    init {
        inflateAndBuild()
        dataView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        (findViewById<View>(R.id.innerFrame) as ViewGroup).addView(dataView)
        title = findViewById<View>(R.id.title) as TextView
        title.visibility = VISIBLE
    }

    fun setTitle(text: String?) {
        title.text = text
    }
}
