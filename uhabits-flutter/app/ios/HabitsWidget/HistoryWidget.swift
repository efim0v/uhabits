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

/// `HistoryWidget` — a `GraphWidgetView` wrapping the core `HistoryChart`
/// (`widgets.history#1`).
struct HistoryWidget: Widget {

    static let kind = "HistoryWidgetProvider"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: SelectHabitIntent.self,
            provider: HabitTimelineProvider()
        ) { entry in
            HistoryWidgetView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringKey("widget_name_history"))
        .description(LocalizedStringKey("widget_description_history"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HistoryWidgetView: View {

    let entry: HabitTimelineEntry

    var body: some View {
        switch entry.state {
        case .noHabits:
            WidgetMessageView(message: WidgetPlaceholder.noHabits).widgetCard()
        case .deleted:
            WidgetMessageView(message: WidgetPlaceholder.habitNotFound).widgetCard()
        case .habit(let habit):
            // `widgets.history#3`: the title is the habit name.
            GraphWidgetView(title: habit.name) {
                HistoryChartView(
                    habit: habit,
                    today: entry.today,
                    firstWeekday: entry.firstWeekday
                )
            }
            .widgetCard()
            // `widgets.history#5`: the card opens ShowHabitActivity for this
            // habit — `IntentFactory.startShowHabitActivity`, which
            // both platforms send as `uhabits://widget/show`.
            .widgetURL(WidgetLink.show(habit))
        }
    }
}

// MARK: - Chart

/// SwiftUI port of `org.isoron.uhabits.core.ui.views.HistoryChart` as the
/// History widget configures it (`widgets.history#2`, `#4`): `WidgetTheme`,
/// `defaultSquare = OFF`, `padding = 2.5`, and a static render — the scroll
/// and tap gestures `AndroidDataView` adds in the app do not exist inside a
/// widget (`widgets.history#6`), so `dataOffset` is fixed at 0 and
/// `onDateClicked` has no counterpart here.
struct HistoryChartView: View {

    let habit: WidgetHabit
    let today: Date

    /// `HistoryChart.firstWeekday`, as `daysSinceSunday` — the weekday the
    /// seven rows start on.
    ///
    /// Upstream `HistoryWidget` assigns it `prefs.firstWeekday` both at
    /// construction (HistoryWidget.kt:75) and on every refresh through
    /// `HistoryCardPresenter.buildState(habit, firstWeekday =
    /// prefs.firstWeekday, ...)`, so the widget's grid starts on the same
    /// weekday the habit-list header and the detail screen do. It arrives on
    /// the entry rather than being asked of `Calendar.current`, whose
    /// `firstWeekday` is the device REGION setting and has nothing to do with
    /// the preference (`audit4.history-and-frequency-home-screen-widgets#1`).
    let firstWeekday: Int

    /// `habit.historySeries` decoded once rather than once per square: the grid
    /// draws up to `7 * nColumns` of them and `String` has no random access, so
    /// indexing it per square would be quadratic in the widget's width
    /// (`audit10.history-home-screen-widget-draws-more#1`).
    private let publishedSeries: [HistorySquare]?

    /// `habit.historyNotes` as a set, for the same reason.
    private let publishedNotes: Set<Int>?

    init(habit: WidgetHabit, today: Date, firstWeekday: Int) {
        self.habit = habit
        self.today = today
        self.firstWeekday = firstWeekday
        self.publishedSeries = habit.historySeries.map { series in
            series.map { HistorySquare.of(ordinal: $0.wholeNumberValue ?? 1) }
        }
        self.publishedNotes = habit.historyNotes.map { Set($0) }
    }

    /// `HistoryChart.padding`, set to 2.5 by `HistoryWidget`.
    private let padding: CGFloat = 2.5

    /// `HistoryChart.squareSpacing`.
    private let squareSpacing: CGFloat = 1.0

    var body: some View {
        Canvas { context, size in
            draw(context: context, size: size)
        }
    }

    private func draw(context: GraphicsContext, size: CGSize) {
        let width = size.width
        let height = size.height
        guard width > 0, height > 0 else { return }

        let squareSize = ((height - 2 * padding) / 8.0).rounded()
        guard squareSize > 0 else { return }
        let font = Font.system(size: min(14.0, height * 0.06))

        // The weekday column is as wide as the widest short weekday name.
        let weekdayColumnWidth = (0..<7)
            .map { measure(context, DateNames.shortWeekday(daysSinceSunday: $0), font).width }
            .max().map { $0 + squareSize * 0.15 } ?? 0

        let nColumns = Int(floor((width - 2 * padding - weekdayColumnWidth) / squareSize))
        guard nColumns > 0 else { return }

        let firstWeekdayOffset =
            (DateNames.daysSinceSunday(today) - firstWeekday + 7) % 7
        let topLeftOffset = (nColumns - 1) * 7 + firstWeekdayOffset

        var headerOverflow: CGFloat = 0
        var lastPrintedMonth = ""
        var lastPrintedYear = ""

        for column in 0..<nColumns {
            let topOffset = topLeftOffset - 7 * column
            let topDate = DateNames.date(today, minusDays: topOffset)

            // `HistoryChart.drawHeader`: a column is labelled with its month
            // the first time that month appears, with its year the first time
            // that year appears and the month has not changed, and with
            // nothing otherwise. The overflow carries a label that is wider
            // than one column into the next columns' budget.
            let monthText = DateNames.shortMonth(topDate)
            let yearText = DateNames.year(topDate)
            var headerText = ""
            if monthText != lastPrintedMonth {
                headerText = monthText
                lastPrintedMonth = monthText
            } else if yearText != lastPrintedYear {
                headerText = yearText
                lastPrintedYear = yearText
            }
            drawText(
                context,
                headerText,
                font: font,
                color: WidgetTheme.mediumContrastText.color,
                at: CGPoint(
                    x: headerOverflow + padding + CGFloat(column) * squareSize,
                    y: padding + squareSize / 2
                ),
                anchor: .leading
            )
            headerOverflow += measure(context, headerText, font).width + 0.1 * squareSize
            headerOverflow = max(0, headerOverflow - squareSize)

            for row in 0..<7 {
                let offset = topOffset - row
                // Kotlin returns out of the whole column here, so the days
                // after today are left blank rather than skipped over.
                if offset < 0 { break }
                let date = DateNames.date(today, minusDays: offset)
                drawSquare(
                    context,
                    x: padding + CGFloat(column) * squareSize,
                    y: padding + CGFloat(row + 1) * squareSize,
                    side: squareSize - squareSpacing,
                    day: DateNames.day(date),
                    square: square(offset: offset),
                    hasNotes: hasNotes(offset: offset),
                    font: font
                )
            }
        }

        // The weekday names, left-aligned in the gutter to the right of the
        // last column, one per row of the leftmost week.
        for row in 0..<7 {
            let date = DateNames.date(today, minusDays: topLeftOffset - row)
            drawText(
                context,
                DateNames.shortWeekday(date),
                font: font,
                color: WidgetTheme.mediumContrastText.color,
                at: CGPoint(
                    x: padding + CGFloat(nColumns) * squareSize + squareSize * 0.15,
                    y: padding + squareSize * CGFloat(row + 1) + squareSize / 2
                ),
                anchor: .leading
            )
        }
    }

    private func drawSquare(
        _ context: GraphicsContext,
        x: CGFloat,
        y: CGFloat,
        side: CGFloat,
        day: Int,
        square: HistorySquare,
        hasNotes: Bool,
        font: Font
    ) {
        let rect = CGRect(x: x, y: y, width: side, height: side)
        let squareColor = HistorySquare.color(square, paletteIndex: habit.color)
        context.fill(
            Path(roundedRect: rect, cornerRadius: side * 0.15),
            with: .color(squareColor.color)
        )

        if square == .hatched {
            // Drawn in `theme.cardBackgroundColor`, which under `WidgetTheme`
            // is fully transparent — so this loop paints nothing at all on a
            // widget. Reproduced rather than skipped so the day a widget theme
            // gains an opaque card, the hatching appears by itself.
            var path = Path()
            var k = side / 10
            for _ in 0..<5 {
                path.move(to: CGPoint(x: x + k, y: y))
                path.addLine(to: CGPoint(x: x, y: y + k))
                path.move(to: CGPoint(x: x + side - k, y: y + side))
                path.addLine(to: CGPoint(x: x + side, y: y + side - k))
                k += side / 5
            }
            context.stroke(
                path,
                with: .color(WidgetTheme.cardBackground.color),
                lineWidth: 0.75
            )
        }

        // `HistoryChart.drawSquare`: when the card is transparent — which it
        // always is under `WidgetTheme` — every day number is drawn in
        // `highContrastTextColor` instead of whichever of the card and the
        // medium-contrast colour contrasts better with the square.
        drawText(
            context,
            "\(day)",
            font: font,
            color: WidgetTheme.highContrastText.color,
            at: CGPoint(x: x + side / 2, y: y + side / 2),
            anchor: .center
        )

        // `HistoryChart.drawSquare`'s last block: a day the user attached a
        // note to is marked with a filled circle of radius `width / 12` in the
        // square's top-right corner, `lowContrastTextColor` over a filled or
        // grey square and the habit's own colour over every other
        // (`audit6.history-home-screen-widget-never-draws#1`). `Canvas
        // .fillCircle` takes a centre and a radius; SwiftUI wants the bounding
        // box, which is that centre minus the radius on both axes.
        if hasNotes {
            let radius = side / 12
            let circleColor = square == .on || square == .grey
                ? WidgetTheme.lowContrastText
                : WidgetTheme.rawColor(paletteIndex: habit.color)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: x + side - side / 5 - radius,
                    y: y + side / 5 - radius,
                    width: 2 * radius,
                    height: 2 * radius
                )),
                with: .color(circleColor.color)
            )
        }
    }

    /// `HistoryCardPresenter.buildState(...).series`, as the document carries
    /// it (`audit10.history-home-screen-widget-draws-more#1`).
    ///
    /// `nColumns` above is geometric and nothing bounds it by the data behind
    /// it, so this card asks for 127-133 days at `.systemMedium`. Upstream the
    /// series runs from the habit's oldest known entry to today, which is why
    /// `defaultSquare = OFF` past its end means "before the habit existed" and
    /// nothing else; `historySeries` is that series. Falling back to `entries`
    /// — sixty days — is only for a document written before the field existed.
    private func square(offset: Int) -> HistorySquare {
        if let series = publishedSeries {
            guard offset < series.count else { return .off }
            return series[offset]
        }
        guard offset < habit.entries.count else { return .off }
        return HistorySquare.of(value: habit.entries[offset], habit: habit)
    }

    /// `HistoryChart.drawSquare`'s `hasNotes`: the published offsets when the
    /// document carries them, the sixty-day flag array otherwise, and false
    /// past the end of either — exactly as it is false past the end of the
    /// series.
    private func hasNotes(offset: Int) -> Bool {
        if let offsets = publishedNotes {
            return offsets.contains(offset)
        }
        guard let indicators = habit.notesIndicators,
              offset < indicators.count else { return false }
        return indicators[offset]
    }

    // MARK: - Canvas helpers

    private func measure(_ context: GraphicsContext, _ text: String, _ font: Font) -> CGSize {
        guard !text.isEmpty else { return .zero }
        return context.resolve(Text(text).font(font))
            .measure(in: CGSize(width: 1000, height: 1000))
    }

    private func drawText(
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

// MARK: - Squares

/// `HistoryChart.Square`.
enum HistorySquare {
    case on
    case off
    case grey
    case dimmed
    case hatched

    /// The published `historySeries` digit, which is the square's ordinal in
    /// the order all four ports declare it — ON, OFF, GREY, DIMMED, HATCHED.
    /// Anything else is OFF, the same answer an absent day gets.
    static func of(ordinal: Int) -> HistorySquare {
        switch ordinal {
        case 0: return .on
        case 1: return .off
        case 2: return .grey
        case 3: return .dimmed
        case 4: return .hatched
        default: return .off
        }
    }

    /// The inverse of [of(ordinal:)] — the digit `historySeries` spells this
    /// square with, which is what `WidgetStore.stageToggle` writes back into
    /// the series when a Checkmark tap moves today's value.
    var ordinal: Int {
        switch self {
        case .on: return 0
        case .off: return 1
        case .grey: return 2
        case .dimmed: return 3
        case .hatched: return 4
        }
    }

    /// `HistoryCardPresenter.buildState`, evaluated one entry at a time — the
    /// fallback for a document written before `historySeries` existed.
    static func of(value: Int, habit: WidgetHabit) -> HistorySquare {
        of(
            value: value,
            isNumerical: habit.isNumerical,
            isAtMost: habit.isAtMost,
            target: habit.target
        )
    }

    /// The same mapping over the three habit fields it actually needs, so that
    /// `WidgetStore.stageToggle` — which works on the raw JSON dictionary,
    /// never on a decoded [WidgetHabit] — can reach it instead of carrying a
    /// second copy of the table.
    ///
    /// The order of the numerical branches is the contract: UNKNOWN wins over
    /// everything, then SKIP, and only then is the target consulted — a SKIP is
    /// stored as 3, i.e. 0.003, which would otherwise satisfy every AT_MOST
    /// target.
    static func of(
        value: Int,
        isNumerical: Bool,
        isAtMost: Bool,
        target: Double
    ) -> HistorySquare {
        if isNumerical {
            if value == EntryValue.unknown { return .off }
            if value == EntryValue.skip { return .hatched }
            let amount = Double(value) / 1000.0
            if isAtMost && amount <= target { return .on }
            if !isAtMost && amount >= target { return .on }
            return .grey
        }
        switch value {
        case EntryValue.yesManual: return .on
        case EntryValue.yesAuto: return .dimmed
        case EntryValue.skip: return .hatched
        default: return .off
        }
    }

    /// `HistoryChart.drawSquare`'s colour table.
    static func color(_ square: HistorySquare, paletteIndex: Int) -> WidgetColor {
        let habitColor = WidgetTheme.rawColor(paletteIndex: paletteIndex)
        switch square {
        case .on:
            return habitColor
        case .off:
            return WidgetTheme.lowContrastText
        case .grey:
            return WidgetTheme.mediumContrastText
        case .dimmed, .hatched:
            return habitColor.blendWith(WidgetTheme.cardBackground, weight: 0.5)
        }
    }
}
