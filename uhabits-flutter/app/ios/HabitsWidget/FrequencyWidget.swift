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

// MARK: - Widget

/// `FrequencyWidget` — a `GraphWidgetView` wrapping a `FrequencyChart`
/// (`widgets.frequency#1`).
///
/// Its configure activity upstream is the unfiltered `HabitPickerDialog`
/// (`widgets.registration#6`), so it takes the same `SelectHabitIntent` the
/// Checkmark, History and Score widgets take.
struct FrequencyWidget: Widget {

    static let kind = "FrequencyWidgetProvider"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: SelectHabitIntent.self,
            provider: HabitTimelineProvider<SelectHabitIntent>()
        ) { entry in
            FrequencyWidgetView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringKey("widget_name_frequency"))
        .description(LocalizedStringKey("widget_description_frequency"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FrequencyWidgetView: View {

    let entry: HabitTimelineEntry

    var body: some View {
        switch entry.state {
        case .noHabits:
            WidgetMessageView(message: WidgetPlaceholder.noHabits).widgetCard()
        case .deleted:
            WidgetMessageView(message: WidgetPlaceholder.habitNotFound).widgetCard()
        case .habit(let habit):
            // `widgets.frequency#2`: the title is the habit name.
            GraphWidgetView(title: habit.name) {
                FrequencyChartView(
                    habit: habit,
                    today: entry.today,
                    firstWeekday: entry.firstWeekday
                )
            }
            .widgetCard()
            // `widgets.frequency#6`: the card opens ShowHabitActivity for this
            // habit — `IntentFactory.startShowHabitActivity`, which
            // both platforms send as `uhabits://widget/show`.
            .widgetURL(WidgetLink.show(habit))
        }
    }
}

// MARK: - Chart

/// SwiftUI port of
/// `org.isoron.uhabits.activities.common.views.FrequencyChart` as
/// `FrequencyWidget.refreshData` configures it (`widgets.frequency#3`).
///
/// One column per calendar month, seven weekday rows plus a footer row, and a
/// bubble in each cell whose radius grows with how often the habit was
/// performed on that weekday that month.
///
/// Two upstream details that look like bugs and are not, both kept:
///
///  - only `nColumns - 1` months are drawn; the rightmost column's width is
///    spent on the weekday names;
///  - the month name under a column is centred on the first `baseSize` of that
///    column rather than on the column, because `drawColumn` hands `drawFooter`
///    the same `baseSize`-wide cell rectangle its loop left behind.
///
/// Both of the chart's inputs are published rather than rebuilt here, exactly
/// as `FrequencyWidget.refreshData` takes both from outside upstream:
///
///  - **the buckets.** `setFrequency(habit.originalEntries
///    .computeWeekdayFrequency(habit.isNumerical))` runs over the habit's whole
///    history and over the user's own marks. The document carries
///    `habit.weekdayFrequency` for exactly that reason: rebuilding from the
///    sixty published `entries` populated at most three columns and drew every
///    older month empty, so the calendar read as if the habit had started two
///    months ago — and it counted `computedEntries`, where a non-daily
///    frequency has already filled YES_AUTO days in.
///  - **the first weekday.** `widgets.frequency#3` is
///    `setFirstWeekday(firstWeekday)`, handed `preferences.firstWeekday` by
///    `FrequencyWidgetProvider`. It arrives on the entry
///    (`audit4.history-and-frequency-home-screen-widgets#1`); asking
///    `Calendar.current` instead read the device REGION setting, so a US-region
///    iPhone drew a Sunday-first grid for a user who chose Monday in Loop.
///
/// `widgets.frequency#5` is what the published buckets guarantee: the widget
/// must not count auto-satisfied days, and `computeWeekdayFrequency` is fed the
/// ORIGINAL entries, so a YES_AUTO day was never counted in the first place.
struct FrequencyChartView: View {

    let habit: WidgetHabit

    let today: Date

    /// `FrequencyChart.setFirstWeekday`, as `daysSinceSunday`.
    let firstWeekday: Int

    var body: some View {
        Canvas { context, size in
            draw(context: context, size: size)
        }
    }

    private func draw(context: GraphicsContext, size: CGSize) {
        let width = size.width
        var height = size.height
        // onSizeChanged: `if (height < 9) height = 200`.
        if height < 9 { height = 200 }
        let baseSize = CGFloat(Int(height / 8))
        guard baseSize > 0, width > 0 else { return }

        let textSize = baseSize * 0.4
        let font = Font.system(size: textSize)
        let em = lineHeight(context, font)
        let columnWidth = max(baseSize, maxMonthWidth(context, font) * 1.2)
        let columnHeight = 8 * baseSize
        let nColumns = Int(width / columnWidth)
        guard nColumns > 0 else { return }

        // `habit.weekdayFrequency`: every month the habit has existed, counted
        // from the user's own marks. The rebuild below it is the fallback for a
        // document written before the field existed, exactly as
        // `app/android/.../widgets/FrequencyWidget.kt` keeps
        // `FrequencyChartView.computeWeekdayFrequency` for the same case.
        let frequency = FrequencyState.published(habit)
            ?? FrequencyState.weekdayFrequency(habit, today: today)
        let maxFreq = FrequencyState.maxFreq(frequency)
        let ramp = FrequencyState.colorRamp(paletteIndex: habit.color)
        let weekdays = FrequencyState.weekdaySequence(firstWeekday: firstWeekday)

        drawGrid(
            context,
            right: CGFloat(nColumns) * columnWidth,
            chartHeight: columnHeight,
            columnWidth: columnWidth,
            weekdays: weekdays,
            font: font,
            em: em,
            textSize: textSize
        )

        var month = MonthKey(of: today)
        month = month.stepped(by: -nColumns + 2)
        for i in 0..<(nColumns - 1) {
            drawColumn(
                context,
                left: CGFloat(i) * columnWidth,
                baseSize: baseSize,
                month: month,
                weekdays: weekdays,
                values: frequency[month],
                maxFreq: maxFreq,
                ramp: ramp,
                font: font,
                em: em,
                textSize: textSize
            )
            month = month.stepped(by: 1)
        }
    }

    /// `drawGrid`: seven weekday labels down the rightmost column, a hairline
    /// above each row and one more under the last.
    private func drawGrid(
        _ context: GraphicsContext,
        right: CGFloat,
        chartHeight: CGFloat,
        columnWidth: CGFloat,
        weekdays: [Int],
        font: Font,
        em: CGFloat,
        textSize: CGFloat
    ) {
        let nRows = 7
        let rowHeight = chartHeight / CGFloat(nRows + 1)
        var top: CGFloat = 0
        for weekday in weekdays {
            draw(
                context,
                DateNames.shortWeekday(daysSinceSunday: weekday),
                font: font,
                color: WidgetTheme.mediumContrastText.color,
                at: CGPoint(
                    x: right - columnWidth,
                    y: top + rowHeight / 2 + 0.25 * em - 0.34 * textSize
                ),
                anchor: .leading
            )
            stroke(context, from: CGPoint(x: 0, y: top), to: CGPoint(x: right, y: top))
            top += rowHeight
        }
        stroke(context, from: CGPoint(x: 0, y: top), to: CGPoint(x: right, y: top))
    }

    private func drawColumn(
        _ context: GraphicsContext,
        left: CGFloat,
        baseSize: CGFloat,
        month: MonthKey,
        weekdays: [Int],
        values: [Int]?,
        maxFreq: Int,
        ramp: [WidgetColor],
        font: Font,
        em: CGFloat,
        textSize: CGFloat
    ) {
        let weekDaysInMonth = month.weekdayOccurrences()
        let cx = left + baseSize / 2

        for (row, weekday) in weekdays.enumerated() {
            let index = (weekday + 1) % 7
            guard let values else { continue }
            drawMarker(
                context,
                center: CGPoint(
                    x: cx,
                    y: baseSize * CGFloat(row) + baseSize / 2
                ),
                cellHeight: baseSize,
                rawValue: values[index],
                weekdayFrequency: weekDaysInMonth[index],
                maxFreq: maxFreq,
                ramp: ramp
            )
        }

        // drawFooter, against the cell the loop left behind: one row further
        // down and still only baseSize wide.
        let footerCy = baseSize * 7 + baseSize / 2
        draw(
            context,
            DateNames.shortMonth(month: month.month),
            font: font,
            color: WidgetTheme.mediumContrastText.color,
            at: CGPoint(x: cx, y: footerCy - 0.1 * em - 0.34 * textSize),
            anchor: .center
        )
        if month.month == 2 {
            draw(
                context,
                "\(month.year)",
                font: font,
                color: WidgetTheme.mediumContrastText.color,
                at: CGPoint(x: cx, y: footerCy + 0.9 * em - 0.34 * textSize),
                anchor: .center
            )
        }
    }

    private func drawMarker(
        _ context: GraphicsContext,
        center: CGPoint,
        cellHeight: CGFloat,
        rawValue: Int,
        weekdayFrequency: Int,
        maxFreq: Int,
        ramp: [WidgetColor]
    ) {
        // A skipped entry stores a negative value; it counts as zero.
        let value = max(0, rawValue)
        let padding = cellHeight * 0.2
        let maxRadius = (cellHeight - 2 * padding) / 2
        let scalingFactor = habit.isNumerical ? maxFreq : weekdayFrequency
        guard scalingFactor > 0 else { return }
        let scale = Double(value) / Double(scalingFactor)
        let radius = maxRadius * CGFloat(scale)
        let index = min(ramp.count - 1, Int((Double(ramp.count - 1) * scale).rounded()))
        context.fill(
            Path(
                ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            ),
            with: .color(ramp[index].color)
        )
    }

    // MARK: - Canvas helpers

    private func stroke(_ context: GraphicsContext, from: CGPoint, to: CGPoint) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        // `pGrid.strokeWidth = 1f`, overriding what onSizeChanged computed.
        context.stroke(path, with: .color(WidgetTheme.lowContrastText.color), lineWidth: 1)
    }

    private func maxMonthWidth(_ context: GraphicsContext, _ font: Font) -> CGFloat {
        (1...12)
            .map { measure(context, DateNames.shortMonth(month: $0), font).width }
            .max() ?? 0
    }

    private func measure(
        _ context: GraphicsContext,
        _ text: String,
        _ font: Font
    ) -> CGSize {
        guard !text.isEmpty else { return .zero }
        return context.resolve(Text(text).font(font))
            .measure(in: CGSize(width: 1000, height: 1000))
    }

    private func lineHeight(_ context: GraphicsContext, _ font: Font) -> CGFloat {
        measure(context, "100", font).height
    }

    private func draw(
        _ context: GraphicsContext,
        _ text: String,
        font: Font,
        color: Color,
        at point: CGPoint,
        anchor: UnitPoint
    ) {
        guard !text.isEmpty else { return }
        context.draw(
            context.resolve(Text(text).font(font).foregroundStyle(color)),
            at: point,
            anchor: anchor
        )
    }
}

// MARK: - State

/// One calendar month, which is the key `computeWeekdayFrequency` buckets by
/// (`LocalDate.startOfMonth`).
struct MonthKey: Hashable {

    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(of date: Date) {
        let components = widgetCalendar.dateComponents([.year, .month], from: date)
        self.init(year: components.year ?? 2000, month: components.month ?? 1)
    }

    /// `stepMonth`: month arithmetic that wraps the year.
    func stepped(by months: Int) -> MonthKey {
        var year = self.year
        var month = self.month + months
        while month < 1 {
            month += 12
            year -= 1
        }
        while month > 12 {
            month -= 12
            year += 1
        }
        return MonthKey(year: year, month: month)
    }

    var startOfMonth: Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return widgetCalendar.date(from: components) ?? Date()
    }

    /// `countWeekdayOccurrencesInMonth`: how many Sundays, Mondays … the month
    /// has, indexed the way the histogram is — `(daysSinceSunday + 1) % 7`.
    func weekdayOccurrences() -> [Int] {
        let start = startOfMonth
        let weekday = (DateNames.daysSinceSunday(start) + 1) % 7
        let length = widgetCalendar
            .range(of: .day, in: .month, for: start)?.count ?? 30
        var frequency = [Int](repeating: 0, count: 7)
        for day in weekday..<(weekday + length) {
            frequency[day % 7] += 1
        }
        return frequency
    }
}

/// The pure half of `FrequencyWidget.refreshData`.
enum FrequencyState {

    /// `habit.weekdayFrequency` as the chart indexes it — one 7-slot array per
    /// [MonthKey] — or nil when the document predates the field.
    ///
    /// The wire keys are `HomeWidgetBridge.formatDate` strings for each month's
    /// first day (`LocalDate.startOfMonth`), which is the key
    /// `computeWeekdayFrequency` buckets by; only the year and the month are
    /// read back, because that is all [MonthKey] is. A malformed key is
    /// dropped rather than guessed at: an extension that traps is killed and
    /// the user sees a blank card.
    static func published(_ habit: WidgetHabit) -> [MonthKey: [Int]]? {
        guard let buckets = habit.weekdayFrequency else { return nil }
        var frequency: [MonthKey: [Int]] = [:]
        for (key, values) in buckets {
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3, values.count == 7 else { continue }
            frequency[MonthKey(year: parts[0], month: parts[1])] = values
        }
        return frequency
    }

    /// `EntryList.computeWeekdayFrequency(isNumerical)`, over the published
    /// sixty-day window — the fallback for a document that predates
    /// [published].
    ///
    /// `widgets.frequency#4`: every KNOWN entry is bucketed by its month
    /// start; within a month it accumulates into a 7-slot array indexed
    /// `(daysSinceSunday + 1) % 7`; a numerical habit adds the raw entry value
    /// and a boolean one adds 1 only when the value is YES_MANUAL.
    static func weekdayFrequency(
        _ habit: WidgetHabit,
        today: Date
    ) -> [MonthKey: [Int]] {
        var frequency: [MonthKey: [Int]] = [:]
        for (offset, value) in habit.entries.enumerated() {
            // getKnown(): an UNKNOWN day is not an entry at all.
            guard value != EntryValue.unknown else { continue }
            let date = DateNames.date(today, minusDays: offset)
            let weekday = (DateNames.daysSinceSunday(date) + 1) % 7
            let month = MonthKey(of: date)
            var values = frequency[month] ?? [Int](repeating: 0, count: 7)
            if habit.isNumerical {
                values[weekday] += value
            } else if value == EntryValue.yesManual {
                values[weekday] += 1
            }
            frequency[month] = values
        }
        return frequency
    }

    /// `getMaxFreq`: the largest count anywhere in the map, floored at 1.
    static func maxFreq(_ frequency: [MonthKey: [Int]]) -> Int {
        var maxValue = 1
        for values in frequency.values {
            for value in values { maxValue = max(value, maxValue) }
        }
        return maxValue
    }

    /// The seven rows, top to bottom, starting on the weekday the user chose
    /// — `chart.setFirstWeekday(firstWeekday)` (`widgets.frequency#3`).
    static func weekdaySequence(firstWeekday: Int) -> [Int] {
        (0..<7).map { (firstWeekday + $0) % 7 }
    }

    /// `initColors`: `[contrast20, mix(contrast20, habit, 0.66),
    /// mix(contrast20, habit, 0.33), habit]`.
    ///
    /// `ColorUtils.mixColors(a, b, amount)` weights `a`, so index 1 is mostly
    /// grid colour and index 2 mostly habit colour. It blends packed ARGB and
    /// truncates, alpha included, which is what [mix] reproduces.
    static func colorRamp(paletteIndex: Int) -> [WidgetColor] {
        let grid = WidgetTheme.lowContrastText
        let habit = WidgetTheme.rawColor(paletteIndex: paletteIndex)
        return [
            grid,
            mix(grid, habit, amount: 0.66),
            mix(grid, habit, amount: 0.33),
            habit,
        ]
    }

    /// `ColorUtils.mixColors`, channel by channel over 8-bit values.
    static func mix(
        _ color1: WidgetColor,
        _ color2: WidgetColor,
        amount: Double
    ) -> WidgetColor {
        func channel(_ a: Double, _ b: Double) -> Double {
            let mixed = a * 255.0 * amount + b * 255.0 * (1 - amount)
            return Double(Int(mixed)) / 255.0
        }
        return WidgetColor(
            red: channel(color1.red, color2.red),
            green: channel(color1.green, color2.green),
            blue: channel(color1.blue, color2.blue),
            alpha: channel(color1.alpha, color2.alpha)
        )
    }
}
