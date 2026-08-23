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

import WidgetKit

/// What one render of a habit widget needs.
struct HabitTimelineEntry: TimelineEntry {

    enum State {
        /// A habit to draw.
        case habit(WidgetHabit)
        /// The configured habit id is gone (`widgets.error-states#1`).
        case deleted
        /// Nothing has been published yet, so there is nothing to configure
        /// (the analogue of `widgets.error-states#6`).
        case noHabits
    }

    let date: Date
    let state: State

    /// The app's logical today, as published — already offset by the
    /// midnight-delay preference (`widgets.checkmark#5`). Falls back to the
    /// device's today when no document has been published.
    let today: Date

    /// The same day in the wire format, which is what a `uhabits://widget/edit`
    /// link carries: the value picker has to open on the day the *app* calls
    /// today, not on the day this process would compute.
    let todayText: String

    var habit: WidgetHabit? {
        if case .habit(let habit) = state { return habit }
        return nil
    }
}

/// The provider all six widgets share.
///
/// On Android `BaseWidgetProvider.onUpdate` reads the habit list out of the
/// application component in the launcher's process and redraws
/// (`widgets.provider-lifecycle#1`). Here there is no habit list and no
/// process to read it from: the provider reads the App Group document the
/// bridge published and turns it into an entry.
///
/// It is generic over the configuration because three of the six are
/// configured by a *filtered* picker upstream (`widgets.registration#6`), and
/// on iOS a filtered picker is a different intent type — see
/// `HabitSelectionIntent`. Nothing below depends on which of the three it is.
struct HabitTimelineProvider<Configuration: HabitSelectionIntent>:
    AppIntentTimelineProvider {

    typealias Entry = HabitTimelineEntry
    typealias Intent = Configuration

    /// The habits this widget's picker would have offered, which is also the
    /// set its unconfigured fallback may choose from: a Streak widget falls
    /// back onto a boolean habit and a Target widget onto a measurable one,
    /// because that is all `BooleanHabitPickerDialog` and
    /// `NumericalHabitPickerDialog` ever let the user pick.
    let eligible: (WidgetHabit) -> Bool

    init(eligible: @escaping (WidgetHabit) -> Bool = { _ in true }) {
        self.eligible = eligible
    }

    func placeholder(in context: Context) -> HabitTimelineEntry {
        entry(for: Configuration())
    }

    func snapshot(
        for configuration: Configuration,
        in context: Context
    ) async -> HabitTimelineEntry {
        entry(for: configuration)
    }

    /// One entry, valid until the start of the next day.
    ///
    /// Two things refresh a widget. The app pokes `WidgetCenter` after every
    /// command through `HomeWidgetBridge.publish`, which covers every edit the
    /// user makes; and the reload policy below covers the day rollover
    /// (`widgets.day-rollover`), which upstream is an AlarmManager alarm that
    /// fires whether or not the app is running. WidgetKit has no alarm, so the
    /// timeline expires at midnight instead.
    ///
    /// The rollover here is the device's midnight, not
    /// `getStartOfTomorrowWithOffset(midnightDelayHours, 0)`: the
    /// midnight-delay preference is not part of the published contract, so a
    /// user with the 3-hour delay enabled sees the widget roll over up to
    /// three hours early, until the app's next publish corrects it.
    func timeline(
        for configuration: Configuration,
        in context: Context
    ) async -> Timeline<HabitTimelineEntry> {
        let current = entry(for: configuration)
        return Timeline(entries: [current], policy: .after(Self.startOfTomorrow()))
    }

    private func entry(for configuration: Configuration) -> HabitTimelineEntry {
        let store = WidgetStore()
        let today = store.today() ?? Calendar.current.startOfDay(for: Date())
        let todayText = store.todayText() ?? WidgetStore.formatDate(today)
        if let habit = store.resolve(configuration, eligible: eligible) {
            return HabitTimelineEntry(
                date: Date(),
                state: .habit(habit),
                today: today,
                todayText: todayText
            )
        }
        // A habit that was picked and then deleted is a different failure from
        // never having had one, and upstream draws a different card for it.
        let state: HabitTimelineEntry.State =
            store.isDeleted(configuration) ? .deleted : .noHabits
        return HabitTimelineEntry(
            date: Date(),
            state: state,
            today: today,
            todayText: todayText
        )
    }

    static func startOfTomorrow(from now: Date = Date()) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.startOfDay(for: tomorrow)
    }
}
