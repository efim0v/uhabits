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

import Foundation

/// `JavaLocalDateFormatter(Locale.getDefault())` and the bits of
/// `LocalDate`/`DayOfWeek` the charts use.
///
/// `HistoryWidget` builds its chart with a formatter for the default locale
/// (`widgets.history#2`), so the weekday and month abbreviations here come from
/// the device locale too.
enum DateNames {

    private static let calendar = widgetCalendar

    private static let symbols: DateFormatter = {
        let formatter = DateFormatter()
        // The words follow the device locale, as
        // `JavaLocalDateFormatter(Locale.getDefault())` does upstream; the
        // calendar does not, because the month these names are indexed by is a
        // Gregorian month
        // (`audit17.ios-widgets-do-day-arithmetic-in-the-device-calendar#1`).
        formatter.locale = Locale.current
        formatter.calendar = widgetCalendar
        return formatter
    }()

    /// `dateFormatter.shortWeekdayName(date)` — "Sun", "Mon", ...
    static func shortWeekday(_ date: Date) -> String {
        shortWeekday(daysSinceSunday: daysSinceSunday(date))
    }

    /// `DayOfWeek.daysSinceSunday` indexes the same list, so the charts can ask
    /// for a name without having a date in hand.
    static func shortWeekday(daysSinceSunday: Int) -> String {
        let names = symbols.shortWeekdaySymbols ?? []
        guard names.count == 7 else { return "" }
        return names[((daysSinceSunday % 7) + 7) % 7]
    }

    /// `dateFormatter.shortMonthName(date)` — "Jan", "Feb", ...
    static func shortMonth(_ date: Date) -> String {
        let names = symbols.shortMonthSymbols ?? []
        let month = calendar.component(.month, from: date)
        guard names.count == 12, month >= 1, month <= 12 else { return "" }
        return names[month - 1]
    }

    static func year(_ date: Date) -> String {
        "\(calendar.component(.year, from: date))"
    }

    static func day(_ date: Date) -> Int {
        calendar.component(.day, from: date)
    }

    /// `DayOfWeek.daysSinceSunday`: Sunday is 0, Saturday is 6. `Calendar`
    /// numbers weekdays from 1 for Sunday, hence the shift.
    static func daysSinceSunday(_ date: Date) -> Int {
        calendar.component(.weekday, from: date) - 1
    }

    /// The device REGION setting's first weekday, as `daysSinceSunday`.
    ///
    /// **Not** `Preferences.firstWeekday`, which is what both grids lay
    /// themselves out from: that is a user preference, it is published on both
    /// documents, and it is read through `WidgetStore.firstWeekday()`. This is
    /// only that accessor's last resort, for a document written before the
    /// field existed — and it is the value both grids used unconditionally
    /// before, which put every square one row off from the same date in the app
    /// for anyone whose Loop setting differed from their iPhone's region
    /// (`audit4.history-and-frequency-home-screen-widgets#1`).
    static func firstWeekdayDaysSinceSunday() -> Int {
        calendar.firstWeekday - 1
    }

    /// `LocalDate.minus(days)`.
    static func date(_ date: Date, minusDays days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: date) ?? date
    }
}
