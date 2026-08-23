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
        .configurationDisplayName("History")
        .description("Shows a calendar of the habit's recent history.")
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
                HistoryChartView(habit: habit, today: entry.today)
            }
            .widgetCard()
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
            (DateNames.daysSinceSunday(today) - DateNames.firstWeekdayDaysSinceSunday() + 7) % 7
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

        // The notes indicator is deliberately absent: `Entry.notes` is not part
        // of the published contract, so `notesIndicators` is empty and every
        // square takes the `hasNotes == false` branch.
    }

    /// `HistoryCardPresenter.buildState`, evaluated one offset at a time
    /// against the published entries. Offsets past the end of the array fall
    /// back to `defaultSquare`, which the History widget sets to OFF
    /// (`widgets.history#2`).
    private func square(offset: Int) -> HistorySquare {
        guard offset < habit.entries.count else { return .off }
        return HistorySquare.of(value: habit.entries[offset], habit: habit)
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

    /// `HistoryCardPresenter.buildState`.
    static func of(value: Int, habit: WidgetHabit) -> HistorySquare {
        if habit.isNumerical {
            if value == EntryValue.unknown { return .off }
            if value == EntryValue.skip { return .hatched }
            let amount = Double(value) / 1000.0
            if habit.isAtMost && amount <= habit.target { return .on }
            if !habit.isAtMost && amount >= habit.target { return .on }
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
