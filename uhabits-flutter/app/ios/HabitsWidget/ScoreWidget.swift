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

/// `ScoreWidget` — a `GraphWidgetView` wrapping a `ScoreChart`
/// (`widgets.score#1`).
struct ScoreWidget: Widget {

    static let kind = "ScoreWidgetProvider"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: SelectHabitIntent.self,
            provider: HabitTimelineProvider()
        ) { entry in
            ScoreWidgetView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringKey("widget_name_score"))
        .description(LocalizedStringKey("widget_description_score"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ScoreWidgetView: View {

    let entry: HabitTimelineEntry

    var body: some View {
        switch entry.state {
        case .noHabits:
            WidgetMessageView(message: WidgetPlaceholder.noHabits).widgetCard()
        case .deleted:
            WidgetMessageView(message: WidgetPlaceholder.habitNotFound).widgetCard()
        case .habit(let habit):
            // `widgets.score#2`: the title is the habit name.
            GraphWidgetView(title: habit.name) {
                ScoreChartView(habit: habit, today: entry.today)
            }
            .widgetCard()
            // `widgets.score#7`: the card opens ShowHabitActivity for this
            // habit — `IntentFactory.startShowHabitActivity`, which
            // both platforms send as `uhabits://widget/show`.
            .widgetURL(WidgetLink.show(habit))
        }
    }
}

// MARK: - Chart

/// SwiftUI port of `ScoreChart` with `isTransparencyEnabled = true`, which is
/// how `ScoreWidget.refreshData` configures it (`widgets.score#5`).
struct ScoreChartView: View {

    let habit: WidgetHabit
    let today: Date

    /// `BUCKET_SIZES[scoreCardSpinnerPosition]` (`widgets.score#4`).
    ///
    /// `widgets.score#3`: the widget plots the bucket the user last chose on
    /// the habit detail screen, which is what `habit.scores` was built at, so
    /// it has to be read from the document rather than assumed. It is what
    /// turns a column index back into a date — `today - offset * bucketSize` —
    /// and it decides the footer: the year is printed for `bucketSize >= 365`
    /// and the month/day for anything smaller. Hardcoding the weekly default
    /// plotted a correct yearly line against dates one week apart.
    ///
    /// 7 only for a document written before the field existed, which is the
    /// preference's own default.
    private var bucketSize: Int { habit.bucketSize ?? 7 }

    var body: some View {
        Canvas { context, size in
            draw(context: context, size: size)
        }
    }

    private func draw(context: GraphicsContext, size: CGSize) {
        let width = size.width
        var height = size.height
        guard width > 0 else { return }
        // `ScoreChart.onSizeChanged` treats a degenerate height as 200.
        if height < 9 { height = 200 }

        // `R.dimen.tinyTextSize` is 10sp; the chart shrinks below it on small
        // widgets but never grows past it.
        let fontSize = min(height * 0.06, 10)
        let font = Font.system(size: fontSize)
        let em = lineHeight(context, font)

        let footerHeight = (3 * em).rounded(.down)
        let paddingTop = em.rounded(.down)
        let baseSize = ((height - footerHeight - paddingTop) / 8).rounded(.down)
        guard baseSize > 0 else { return }

        // `maxDayWidth` and `maxMonthWidth` are the same computation upstream:
        // both loops measure the twelve short month names. Reproduced, wart
        // included, because the wider of the two factors (1.5x vs 1.2x) is what
        // actually sets the column width.
        let widestMonth = (1...12)
            .map { measure(context, DateNames.shortMonth(month: $0), font).width }
            .max() ?? 0
        var columnWidth = max(baseSize, widestMonth * 1.5)
        columnWidth = max(columnWidth, widestMonth * 1.2)
        let nColumns = max(1, Int(width / columnWidth))
        columnWidth = width / CGFloat(nColumns)
        let columnHeight = 8 * baseSize

        let gridRect = CGRect(
            x: 0,
            y: paddingTop,
            width: CGFloat(nColumns) * columnWidth,
            height: columnHeight
        )
        drawGrid(context, rect: gridRect, font: font, em: em)

        // `ScoreChart.onDraw` bails out before anything is plotted when it has
        // no scores. The grid and the axis labels above are drawn first, so an
        // empty chart still looks like a chart, which is what a document
        // written before `scores` existed leaves this side with.
        guard let scores = habit.scores, !scores.isEmpty else { return }

        let primary = WidgetTheme.color(paletteIndex: habit.color)
        var previousCenter: CGPoint?
        var previousMonthText = ""
        var previousYearText = ""
        var skipYear = 0
        var markers: [CGPoint] = []
        var line = Path()

        for k in 0..<nColumns {
            let offset = nColumns - k - 1
            if offset >= scores.count { continue }
            let score = min(max(scores[offset], 0), 1)
            let date = DateNames.date(today, minusDays: offset * bucketSize)
            let markerHeight = (CGFloat(columnHeight) * CGFloat(score)).rounded(.down)
            let center = CGPoint(
                x: CGFloat(k) * columnWidth + columnWidth / 2,
                y: paddingTop + columnHeight - markerHeight
            )
            if let previous = previousCenter {
                line.move(to: previous)
                line.addLine(to: center)
                markers.append(previous)
            }
            if k == nColumns - 1 { markers.append(center) }
            previousCenter = center

            drawFooter(
                context,
                center: CGPoint(x: CGFloat(k) * columnWidth + columnWidth / 2, y: 0),
                bottom: paddingTop + columnHeight,
                date: date,
                font: font,
                em: em,
                previousMonthText: &previousMonthText,
                previousYearText: &previousYearText,
                skipYear: &skipYear
            )
        }

        context.stroke(line, with: .color(primary), lineWidth: baseSize * 0.1)

        // `drawMarker`: a disc the size of the card punched out of the line
        // (`XFERMODE_CLEAR` under transparency) with the habit colour inside
        // it. Filling with the card colour is the same picture without the
        // blend mode, because the card is what the hole would reveal.
        for marker in markers {
            context.fill(
                Path(ellipseIn: circle(at: marker, radius: baseSize * 0.275)),
                with: .color(WidgetTheme.cardBackgroundOpaque)
            )
            context.fill(
                Path(ellipseIn: circle(at: marker, radius: baseSize * 0.175)),
                with: .color(primary)
            )
        }
    }

    /// `ScoreChart.drawGrid`: five rows labelled 100%, 80%, 60%, 40%, 20%,
    /// each with a rule along its top, plus a closing rule at the bottom.
    private func drawGrid(
        _ context: GraphicsContext,
        rect: CGRect,
        font: Font,
        em: CGFloat
    ) {
        let nRows = 5
        let rowHeight = rect.height / CGFloat(nRows)
        for i in 0...nRows {
            let top = rect.minY + CGFloat(i) * rowHeight
            var rule = Path()
            rule.move(to: CGPoint(x: rect.minX, y: top))
            rule.addLine(to: CGPoint(x: rect.maxX, y: top))
            context.stroke(
                rule,
                with: .color(WidgetTheme.contrast20),
                lineWidth: 1
            )
            guard i < nRows else { break }
            drawBaselineText(
                context,
                "\(100 - i * 100 / nRows)%",
                font: font,
                color: WidgetTheme.contrast60,
                x: rect.minX + 0.5 * em,
                baseline: top + em,
                anchor: .topLeading
            )
        }
    }

    /// `ScoreChart.drawFooter`.
    private func drawFooter(
        _ context: GraphicsContext,
        center: CGPoint,
        bottom: CGFloat,
        date: Date,
        font: Font,
        em: CGFloat,
        previousMonthText: inout String,
        previousYearText: inout String,
        skipYear: inout Int
    ) {
        let yearText = DateNames.year(date)
        let monthText = DateNames.shortMonth(date)
        let dayText = "\(DateNames.day(date))"

        var shouldPrintYear = true
        if yearText == previousYearText { shouldPrintYear = false }
        // A year is printed only every other year once the buckets are annual.
        if bucketSize >= 365 && DateNames.yearNumber(date) % 2 != 0 { shouldPrintYear = false }
        if skipYear > 0 {
            skipYear -= 1
            shouldPrintYear = false
        }
        if shouldPrintYear {
            previousYearText = yearText
            previousMonthText = ""
            drawBaselineText(
                context,
                yearText,
                font: font,
                color: WidgetTheme.contrast60,
                x: center.x,
                baseline: bottom + em * 2.2,
                anchor: .top
            )
            skipYear = 1
        }
        if bucketSize < 365 {
            let text: String
            if monthText != previousMonthText {
                previousMonthText = monthText
                text = monthText
            } else {
                text = dayText
            }
            drawBaselineText(
                context,
                text,
                font: font,
                color: WidgetTheme.contrast60,
                x: center.x,
                baseline: bottom + em * 1.2,
                anchor: .top
            )
        }
    }

    // MARK: - Canvas helpers

    private func circle(at center: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
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

    /// `Paint.fontSpacing` — the distance between two baselines.
    private func lineHeight(_ context: GraphicsContext, _ font: Font) -> CGFloat {
        measure(context, "100%", font).height
    }

    /// `Canvas.drawText` on Android positions the *baseline* at y, unlike the
    /// core `Canvas` abstraction which centres the line. SwiftUI can only
    /// anchor the line box, so the ascent is subtracted to land the baseline
    /// where Android would have put it. The ratio is SF Pro's ascender.
    private func drawBaselineText(
        _ context: GraphicsContext,
        _ text: String,
        font: Font,
        color: Color,
        x: CGFloat,
        baseline: CGFloat,
        anchor: UnitPoint
    ) {
        guard !text.isEmpty else { return }
        let resolved = context.resolve(Text(text).font(font).foregroundStyle(color))
        let ascent = resolved.measure(in: CGSize(width: 1000, height: 1000)).height * 0.818
        context.draw(resolved, at: CGPoint(x: x, y: baseline - ascent), anchor: anchor)
    }
}

extension DateNames {

    static func yearNumber(_ date: Date) -> Int {
        widgetCalendar.component(.year, from: date)
    }
}
