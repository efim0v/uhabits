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

/**
 * Port of the two functions of
 * `uhabits-core/src/commonMain/kotlin/org/isoron/platform/utils/StringUtils.kt`
 * that the stack widget uses.
 *
 * They live here rather than in the core because a widget provider runs in the
 * launcher's process, where there is no core library — and because this is the
 * only thing in the core that the widget encoding depends on.
 *
 * `widgets.stack#12`: the round trip is deliberately lossy in one direction.
 * `joinLongs(LongArray(0))` is the empty string, and `splitLongs("")` splits it
 * into a single empty token, which does not parse, which empties the whole
 * array. A stack widget bound to no habits therefore reports a count of 0 and
 * shows its empty view — which is the behaviour, not an accident to fix.
 */
object StringUtils {

    fun joinLongs(values: LongArray): String = values.joinToString(separator = ",")

    fun splitLongs(str: String): LongArray {
        return try {
            str.split(",").map { it.toLong() }.toLongArray()
        } catch (e: NumberFormatException) {
            LongArray(0)
        }
    }
}
