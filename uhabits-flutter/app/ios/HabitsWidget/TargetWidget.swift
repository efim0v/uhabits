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

/// `TargetWidget` — a `GraphWidgetView` wrapping a `TargetChart`
/// (`widgets.target#1`).
///
/// `widgets.target#8`: its configure activity upstream is
/// `NumericalHabitPickerDialog`, so a boolean habit can never be chosen for
/// it — which on iOS makes the parameter a `NumericalHabitEntity` and the
/// configuration a `SelectNumericalHabitIntent`.
struct TargetWidget: Widget {

    static let kind = "TargetWidgetProvider"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: SelectNumericalHabitIntent.self,
            provider: HabitTimelineProvider<SelectNumericalHabitIntent>(
                eligible: { $0.isNumerical }
            )
        ) { entry in
            TargetWidgetView(entry: entry)
        }
        .configurationDisplayName("Target")
        .description("Shows how much of the target is done this day, week, month, quarter and year.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TargetWidgetView: View {

    let entry: HabitTimelineEntry

    var body: some View {
        switch entry.state {
        case .noHabits:
            WidgetMessageView(message: WidgetPlaceholder.noHabits).widgetCard()
        case .deleted:
            WidgetMessageView(message: WidgetPlaceholder.habitNotFound).widgetCard()
        case .habit(let habit):
            // `widgets.target#2`: the title is the habit name.
            GraphWidgetView(title: habit.name) {
                TargetChartView(
                    state: TargetState.buildState(habit, today: entry.today),
                    habit: habit
                )
            }
            .widgetCard()
        }
    }
}

// MARK: - Chart

/// SwiftUI port of `org.isoron.uhabits.activities.common.views.TargetChart`.
///
/// One labelled progress bar per interval: a right-aligned label in a gutter as
/// wide as the widest of them, then a rounded background bar with the completed
/// part painted over it in the habit colour, and the completed and remaining
/// amounts written inside whichever half has room for them.
///
/// Note that the remaining amount is not clamped: an over-target row shows a
/// negative number whenever it fits.
struct TargetChartView: View {

    let state: TargetCardState

    let habit: WidgetHabit

    /// `R.dimen.baseSize`, the height of one row.
    private let baseSize: CGFloat = 20

    /// `dpToPixels(context, 4f)`.
    private let padding: CGFloat = 4

    /// `dpToPixels(context, 2f)`.
    private let cornerRadius: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            draw(context: context, size: size)
        }
    }

    private func draw(context: GraphicsContext, size: CGSize) {
        guard !state.labels.isEmpty, size.width > 0 else { return }

        // `paint.textSize` is `R.dimen.tinyTextSize`, 10.
        let font = Font.system(size: 10)
        var maxLabelSize: CGFloat = 0
        for label in state.labels {
            maxLabelSize = max(maxLabelSize, measure(context, label, font).width)
        }

        // The block of rows is vertically centred. `onMeasure` sizes the view
        // at exactly labels.size * baseSize, so on the habit screen this is
        // zero; inside a widget the card is taller than the rows, and the
        // block sits in the middle of it.
        let marginTop = (size.height - baseSize * CGFloat(state.labels.count)) / 2
        for row in 0..<state.labels.count {
            drawRow(
                context,
                row: row,
                top: marginTop + CGFloat(row) * baseSize,
                width: size.width,
                maxLabelSize: maxLabelSize,
                font: font
            )
        }
    }

    private func drawRow(
        _ context: GraphicsContext,
        row: Int,
        top: CGFloat,
        width: CGFloat,
        maxLabelSize: CGFloat,
        font: Font
    ) {
        let stop = maxLabelSize + padding * 2
        let centerY = top + baseSize / 2

        // Label.
        draw(
            context,
            state.labels[row],
            font: font,
            color: WidgetTheme.contrast60,
            at: CGPoint(x: stop - padding, y: centerY),
            anchor: .trailing
        )

        // Background box.
        let barLeft = stop + padding
        let barRight = width - padding
        let barTop = top + baseSize * 0.05
        let barHeight = baseSize - 2 * (baseSize * 0.05)
        let barWidth = barRight - barLeft
        guard barWidth > 0 else { return }
        context.fill(
            Path(
                roundedRect: CGRect(
                    x: barLeft, y: barTop, width: barWidth, height: barHeight
                ),
                cornerRadius: cornerRadius
            ),
            with: .color(WidgetTheme.lowContrastText.color)
        )

        let target = state.targets[row]
        var percentage = target > 0 ? state.values[row] / target : 1.0
        // Clamped above but never below, so a negative value stays negative.
        percentage = min(1.0, percentage)

        // Completed box.
        var completedWidth = CGFloat(percentage) * barWidth
        if completedWidth > 0 && completedWidth < 2 * cornerRadius {
            completedWidth = 2 * cornerRadius
        }
        let remainingWidth = barWidth - completedWidth
        context.fill(
            Path(
                roundedRect: CGRect(
                    x: barLeft, y: barTop, width: completedWidth, height: barHeight
                ),
                cornerRadius: cornerRadius
            ),
            with: .color(WidgetTheme.color(paletteIndex: habit.color))
        )

        // Values. `TargetChart` imports the Android `toShortString`, which is
        // the same table `CheckmarkState.shortString` already carries.
        let remaining = target - state.values[row]
        let completedText = CheckmarkState.shortString(state.values[row])
        let remainingText = CheckmarkState.shortString(remaining)
        if completedWidth > measure(context, completedText, font).width + 2 * padding {
            draw(
                context,
                completedText,
                font: font,
                color: WidgetTheme.contrast0,
                at: CGPoint(x: barLeft + completedWidth / 2, y: centerY),
                anchor: .center
            )
        }
        if remainingWidth > measure(context, remainingText, font).width + 2 * padding {
            draw(
                context,
                remainingText,
                font: font,
                color: WidgetTheme.contrast60,
                at: CGPoint(
                    x: (barLeft + completedWidth + barRight) / 2,
                    y: centerY
                ),
                anchor: .center
            )
        }
    }

    // MARK: - Canvas helpers

    private func measure(
        _ context: GraphicsContext,
        _ text: String,
        _ font: Font
    ) -> CGSize {
        guard !text.isEmpty else { return .zero }
        return context.resolve(Text(text).font(font))
            .measure(in: CGSize(width: 1000, height: 1000))
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

/// `TargetCardState`: three parallel lists, one entry per interval.
struct TargetCardState {

    let values: [Double]
    let targets: [Double]
    let intervals: [Int]

    /// `TargetCardView.intervalToLabel` (`widgets.target#4`). Every interval
    /// that is not one of the first four — 365 included — is "Year".
    ///
    /// The five strings are English literals here, as every other string in
    /// this extension is: the widget bundle ships no `.lproj` of its own, and
    /// giving it one is a slice of its own.
    var labels: [String] {
        intervals.map { interval in
            switch interval {
            case 1: return "Today"
            case 7: return "Week"
            case 30: return "Month"
            case 91: return "Quarter"
            default: return "Year"
            }
        }
    }
}

/// The pure half of `TargetWidget.refreshData`, i.e.
/// `TargetCardPresenter.buildState` run over the published entries
/// (`widgets.target#3`).
enum TargetState {

    /// The windows `buildState` aggregates over, in the order it lists them.
    enum Window: CaseIterable {
        case day, week, month, quarter, year

        var interval: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            case .quarter: return 91
            case .year: return 365
            }
        }
    }

    /// `TargetCardPresenter.buildState`.
    ///
    /// Two deliberate departures, both forced by the published contract and
    /// neither fixable on this side:
    ///
    ///  - **the window.** `buildState` aggregates the habit's whole history;
    ///    the document carries `HomeWidgetBridge.entryCount` (60) days, so the
    ///    quarter and year rows only ever count the days inside that window.
    ///    They read low on a habit older than two months.
    ///  - **the frequency denominator.** `widgets.target#5` includes the
    ///    "Today" row only when `frequency.denominator <= 1` and the "Week" row
    ///    only when it is `<= 7`, and `#7` divides the target by the same
    ///    number. The denominator is not published, so this assumes the daily
    ///    frequency every numerical habit is created with: five bars, and a
    ///    daily target equal to the habit's target. A weekly numerical habit
    ///    shows five bars here and four upstream.
    static func buildState(_ habit: WidgetHabit, today: Date) -> TargetCardState {
        // `dailyTarget = habit.targetValue / habit.frequency.denominator`,
        // with the denominator assumed to be 1 — see above.
        let dailyTarget = habit.target

        var values: [Double] = []
        var targets: [Double] = []
        var intervals: [Int] = []
        for window in Window.allCases {
            let days = daysOf(window, today: today, entryCount: habit.entries.count)
            values.append(groupedSum(habit, days: days) / 1000.0)
            let skipped = countSkippedDays(habit, days: days)
            let target = nominalTarget(window, today: today, dailyTarget: dailyTarget)
            // `widgets.target#7`: reduced by dailyTarget per skipped day, and
            // floored at 0.
            targets.append(max(0.0, target - dailyTarget * Double(skipped)))
            intervals.append(window.interval)
        }
        return TargetCardState(values: values, targets: targets, intervals: intervals)
    }

    /// The offsets from today that fall inside the bucket containing today —
    /// which is what `groupedSum(...).firstOrNull` picks out upstream.
    static func daysOf(_ window: Window, today: Date, entryCount: Int) -> Range<Int> {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.year, .month], from: today)
        let year = parts.year ?? 2000
        let month = parts.month ?? 1

        /// `LocalDate.startOfMonth` / `startOfQuarter` / `startOfYear`, built
        /// from components rather than from `Calendar.dateInterval`, which
        /// answers nil for `.quarter` on the Gregorian calendar.
        func firstOf(month: Int) -> Date {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            return calendar.date(from: components) ?? today
        }

        let start: Date
        switch window {
        case .day:
            start = calendar.startOfDay(for: today)
        case .week:
            // `Preferences.firstWeekday` is not published; the calendar's own
            // first weekday decides where the week starts, exactly as the
            // History widget's rows do.
            start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        case .month:
            start = firstOf(month: month)
        case .quarter:
            start = firstOf(month: ((month - 1) / 3) * 3 + 1)
        case .year:
            start = firstOf(month: 1)
        }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: today)
        ).day ?? 0
        return 0..<min(max(0, days) + 1, entryCount)
    }

    /// `EntryList.groupedSum`'s mapping, summed over one bucket: a numerical
    /// day contributes `max(0, value)` and a SKIP day zero; a boolean day
    /// contributes 1000 when it is YES_MANUAL and zero otherwise.
    static func groupedSum(_ habit: WidgetHabit, days: Range<Int>) -> Double {
        var sum = 0
        for offset in days {
            let value = habit.entries[offset]
            if habit.isNumerical {
                sum += value == EntryValue.skip ? 0 : max(0, value)
            } else {
                sum += value == EntryValue.yesManual ? 1000 : 0
            }
        }
        return Double(sum)
    }

    /// `EntryList.countSkippedDays`. There is no `isNumerical` parameter:
    /// SKIP is detected identically for boolean and numerical habits.
    static func countSkippedDays(_ habit: WidgetHabit, days: Range<Int>) -> Int {
        days.filter { habit.entries[$0] == EntryValue.skip }.count
    }

    /// The target of one window before the skipped days are taken off it, for
    /// a habit whose frequency denominator is 1.
    static func nominalTarget(
        _ window: Window,
        today: Date,
        dailyTarget: Double
    ) -> Double {
        let calendar = Calendar.current
        switch window {
        case .day:
            return dailyTarget
        case .week:
            return dailyTarget * 7
        case .month:
            let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
            return dailyTarget * Double(daysInMonth)
        case .quarter:
            return dailyTarget * 91
        case .year:
            let daysInYear = calendar.range(of: .day, in: .year, for: today)?.count ?? 365
            return dailyTarget * Double(daysInYear)
        }
    }
}
