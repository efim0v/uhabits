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

import SwiftUI
import WidgetKit

/// The iOS half of the home-screen widgets.
///
/// Android registers six providers in the manifest (`widgets.registration#1`)
/// and this bundle offers the same six — Checkmark, History, Score, Streaks,
/// Frequency and Target — in the small and medium families. The order below is
/// `HomeWidgetBridge.providerNames`, which is also the order the manifest
/// declares them in; each entry's `kind` is that provider's name spelled
/// identically, because `HomeWidgetBridge.publish` calls
/// `WidgetCenter.reloadTimelines(ofKind:)` for all six and a reload for a kind
/// no bundle declares is a silent no-op — which is exactly how three of them
/// went missing unnoticed (`audit3.ios-ships-only-three-of-the#1`).
///
/// Three of the six are configured by a filtered picker upstream
/// (`widgets.registration#6`). iOS has no configuration activity, so the
/// filter lives in the entity query the widget's intent parameter is typed
/// with; see `HabitSelection.swift`.
///
/// Two things about the widget sizes are worth stating, because they read like
/// omissions against `widgets.registration#2`..`#5`:
///
/// - There is no size declaration to port. `minWidth`, `minResizeWidth`,
///   `resizeMode` and `widgetCategory` describe a launcher that lets the user
///   resize a widget to arbitrary dimensions. iOS offers fixed families
///   instead, so a widget declares which families it supports and the system
///   picks the size.
/// - `updatePeriodMillis=3600000` has no equivalent either: WidgetKit reloads
///   on a timeline policy, not a fixed period. See
///   `HabitTimelineProvider.timeline` for what replaces it.
@main
struct HabitsWidgetBundle: WidgetBundle {

    var body: some Widget {
        CheckmarkWidget()
        HistoryWidget()
        ScoreWidget()
        StreakWidget()
        FrequencyWidget()
        TargetWidget()
    }
}
