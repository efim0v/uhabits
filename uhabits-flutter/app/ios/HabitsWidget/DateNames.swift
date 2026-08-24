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

    /// `JavaLocalDateFormatter(locale)`.
    ///
    /// The words follow the locale, as `JavaLocalDateFormatter(Locale
    /// .getDefault())` does upstream; the calendar does not, because the month
    /// and weekday these names are indexed by are Gregorian
    /// (`audit17.ios-widgets-do-day-arithmetic-in-the-device-calendar#1`).
    private static func makeSymbols(_ locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = widgetCalendar
        return formatter
    }

    /// The device locale's, built once: `DateFormatter` is expensive enough to
    /// matter inside an extension with a 30 MB memory budget, and a chart asks
    /// for twelve month names per redraw.
    private static let currentSymbols: DateFormatter = makeSymbols(Locale.current)

    /// Upstream takes the locale as a constructor argument — the charts pass
    /// `Locale.getDefault()` — so the accessors below do too, and only their
    /// default argument reads the device.
    private static func symbols(for locale: Locale) -> DateFormatter {
        locale == Locale.current ? currentSymbols : makeSymbols(locale)
    }

    /// `dateFormatter.shortWeekdayName(date)` — "Sun", "Mon", ...
    static func shortWeekday(_ date: Date) -> String {
        shortWeekday(daysSinceSunday: daysSinceSunday(date))
    }

    /// `DayOfWeek.daysSinceSunday` indexes the same list, so the charts can ask
    /// for a name without having a date in hand.
    static func shortWeekday(daysSinceSunday: Int, locale: Locale = .current) -> String {
        let names = symbols(for: locale).shortWeekdaySymbols ?? []
        guard names.count == 7 else { return "" }
        return names[((daysSinceSunday % 7) + 7) % 7]
    }

    /// `dateFormatter.shortMonthName(date)` — "Jan", "Feb", ...
    static func shortMonth(_ date: Date, locale: Locale = .current) -> String {
        shortMonth(month: calendar.component(.month, from: date), locale: locale)
    }

    /// The same name for a 1-based month NUMBER, which is what `ScoreChart`
    /// and `FrequencyChart` measure all twelve of to size their columns, and
    /// what `FrequencyChart` labels its footer with — its grid is keyed by
    /// `MonthKey`, not by a date.
    ///
    /// The number is a GREGORIAN month, because `MonthKey` is built with
    /// `widgetCalendar` and upstream reads its names off
    /// `LocalDate.toGregorianCalendar()`. So the names have to be indexed the
    /// same way, which is what [symbols] guarantees and what a bare
    /// `DateFormatter` does not: with no explicit calendar a formatter takes
    /// its locale's, i.e. the device's Settings > General > Language & Region >
    /// Calendar choice. `fa_IR` and `ar_SA` resolve to persian and
    /// islamic-umalqura with no override at all, so a Gregorian November came
    /// out labelled with a Solar-Hijri or Hijri month the chart was not
    /// showing; a Hebrew calendar returns fourteen symbols, failing the count
    /// guard below, and the footer went blank
    /// (`audit21.ios-widget-month-names-come-from-the-gregorian-calendar#1`).
    ///
    /// It lives here rather than beside its caller because that is what hid
    /// it: `audit17` pinned "the DateFormatters in DateNames.swift and
    /// StreakWidget.swift" and a file-scoped sweep walked past the third one,
    /// an `extension DateNames` declared in ScoreWidget.swift.
    static func shortMonth(month: Int, locale: Locale = .current) -> String {
        let names = symbols(for: locale).shortMonthSymbols ?? []
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
