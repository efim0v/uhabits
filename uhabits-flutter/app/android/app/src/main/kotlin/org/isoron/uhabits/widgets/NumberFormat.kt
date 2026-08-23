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

import java.text.DecimalFormat
import java.util.Locale

/**
 * Port of `Double.toShortString()` from
 * `uhabits-android/.../activities/habits/list/views/NumberButtonView.kt`.
 *
 * `widgets.checkmark-view#7` spells out the whole ladder. The two apparently
 * duplicated branches (>=1e7 and >=1e6 both '%.1fM'; >=1e4 and >=1e3 both
 * '%.1fk') are upstream's and are kept: collapsing them would be identical
 * today, and a wart preserved is a wart nobody has to rediscover.
 */
fun Double.toShortString(): String = when {
    this >= 1e9 -> String.format(Locale.getDefault(), "%.1fG", this / 1e9)
    this >= 1e8 -> String.format(Locale.getDefault(), "%.0fM", this / 1e6)
    this >= 1e7 -> String.format(Locale.getDefault(), "%.1fM", this / 1e6)
    this >= 1e6 -> String.format(Locale.getDefault(), "%.1fM", this / 1e6)
    this >= 1e5 -> String.format(Locale.getDefault(), "%.0fk", this / 1e3)
    this >= 1e4 -> String.format(Locale.getDefault(), "%.1fk", this / 1e3)
    this >= 1e3 -> String.format(Locale.getDefault(), "%.1fk", this / 1e3)
    this >= 1e2 -> DecimalFormat("#").format(this)
    this >= 1e1 -> DecimalFormat("#.#").format(this)
    else -> DecimalFormat("#.##").format(this)
}
