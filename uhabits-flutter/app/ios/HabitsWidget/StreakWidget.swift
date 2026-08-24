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

/// `StreakWidget` — a `GraphWidgetView` wrapping a `StreakChart`
/// (`widgets.streak#1`).
///
/// `widgets.streak#5`: its configure activity upstream is
/// `BooleanHabitPickerDialog`, so a measurable habit can never be chosen for
/// it. On iOS the picker is the entity query, which is why this widget is
/// configured by `SelectBooleanHabitIntent` rather than by the unfiltered
/// `SelectHabitIntent` the Checkmark, History, Score and Frequency widgets
/// use.
struct StreakWidget: Widget {

    static let kind = "StreakWidgetProvider"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: SelectBooleanHabitIntent.self,
            provider: HabitTimelineProvider<SelectBooleanHabitIntent>(
                eligible: { !$0.isNumerical }
            )
        ) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringKey("widget_name_streaks"))
        .description(LocalizedStringKey("widget_description_streaks"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StreakWidgetView: View {

    let entry: HabitTimelineEntry

    var body: some View {
        switch entry.state {
        case .noHabits:
            WidgetMessageView(message: WidgetPlaceholder.noHabits).widgetCard()
        case .deleted:
            WidgetMessageView(message: WidgetPlaceholder.habitNotFound).widgetCard()
        case .habit(let habit):
            // `widgets.streak#2`: the title is the habit name.
            GraphWidgetView(title: habit.name) {
                StreakChartView(habit: habit, today: entry.today)
            }
            .widgetCard()
            // `widgets.streak#6`: the card opens ShowHabitActivity for this
            // habit — `IntentFactory.startShowHabitActivity`, which
            // both platforms send as `uhabits://widget/show`.
            .widgetURL(WidgetLink.show(habit))
        }
    }
}

// MARK: - Chart

/// SwiftUI port of `org.isoron.uhabits.activities.common.views.StreakChart` as
/// `StreakWidget.refreshData` configures it (`widgets.streak#3`): the habit
/// colour and `habit.streaks.getBest(chart.maxStreakCount)`.
///
/// One horizontal bar per streak, top to bottom, each `R.dimen.baseSize` (20)
/// tall, with the streak length inside the bar and the start and end dates
/// flanking it when there is room.
///
/// **The streaks are the published ones.** `StreakList` is recomputed by
/// `Habit.recompute()` over the habit's entire record, so the bars upstream are
/// the genuinely longest runs with their real start dates; the document carries
/// `habit.streaks` for that reason. Rebuilding them from `habit.entries` —
/// `HomeWidgetBridge.entryCount`, sixty days — capped every bar at 60 and
/// dropped every run that ended before the window, which is the widget's whole
/// content. The rebuild survives only as the fallback for a document written
/// before the field existed, exactly as
/// `app/android/.../widgets/StreakWidget.kt` keeps `streaksFrom`.
struct StreakChartView: View {

    let habit: WidgetHabit

    /// The app's logical today, as published, so that a label reads the same
    /// day the list did (`widgets.checkmark#5`).
    let today: Date

    /// `R.dimen.baseSize` — the height of one row.
    private let baseSize: CGFloat = 20

    /// `dpToPixels(context, 2f)` — the bar's corner radius.
    private let cornerRadius: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            draw(context: context, size: size)
        }
    }

    private func draw(context: GraphicsContext, size: CGSize) {
        let width = size.width
        guard width > 0, size.height > 0 else { return }

        // `widgets.streak#4`: the number of bars is floor(measuredHeight /
        // baseSize), read after the view has been measured — which inside a
        // Canvas is the size handed to this closure.
        let streaks = StreakState.best(
            of: habit,
            limit: Int(size.height / baseSize),
            today: today
        )
        // `if (streaks!!.isEmpty()) return` — an empty card body.
        guard !streaks.isEmpty else { return }

        // onSizeChanged: max(min(baseSize * 0.5, regularTextSize),
        // tinyTextSize). `R.dimen.regularTextSize` is 17 and
        // `R.dimen.tinyTextSize` is 10, so on a 20-point row this is 10.
        let textSize = max(min(baseSize * 0.5, 17), 10)
        let font = Font.system(size: textSize)
        let em = lineHeight(context, font)
        let textMargin = 0.5 * em

        // updateMaxMinLengths.
        var maxLength = 0
        var maxLabelWidth: CGFloat = 0
        for streak in streaks {
            maxLength = max(maxLength, streak.length)
            maxLabelWidth = max(
                maxLabelWidth,
                max(
                    measure(context, label(streak.startOffset), font).width,
                    measure(context, label(streak.endOffset), font).width
                )
            )
        }
        var shouldShowLabels = true
        if width - 2 * maxLabelWidth < width * 0.25 {
            maxLabelWidth = 0
            shouldShowLabels = false
        }
        // `drawRow` divides by maxLength, and bails on every row when the
        // longest streak is empty.
        guard maxLength > 0 else { return }

        var top: CGFloat = 0
        for streak in streaks {
            drawRow(
                context,
                streak: streak,
                top: top,
                width: width,
                maxLength: maxLength,
                maxLabelWidth: maxLabelWidth,
                shouldShowLabels: shouldShowLabels,
                textMargin: textMargin,
                em: em,
                font: font,
                textSize: textSize
            )
            top += baseSize
        }
    }

    private func drawRow(
        _ context: GraphicsContext,
        streak: WidgetStreak,
        top: CGFloat,
        width: CGFloat,
        maxLength: Int,
        maxLabelWidth: CGFloat,
        shouldShowLabels: Bool,
        textMargin: CGFloat,
        em: CGFloat,
        font: Font,
        textSize: CGFloat
    ) {
        let percentage = Double(streak.length) / Double(maxLength)
        var availableWidth = width - 2 * maxLabelWidth
        if shouldShowLabels { availableWidth -= 2 * textMargin }

        let lengthText = "\(streak.length)"
        // A bar is never narrower than its own number plus one em.
        let barWidth = max(
            CGFloat(percentage) * availableWidth,
            measure(context, lengthText, font).width + em
        )
        let gap = (width - barWidth) / 2
        let paddingTopBottom = baseSize * 0.05

        context.fill(
            Path(
                roundedRect: CGRect(
                    x: gap,
                    y: top + paddingTopBottom,
                    width: barWidth,
                    height: baseSize - 2 * paddingTopBottom
                ),
                cornerRadius: cornerRadius
            ),
            with: .color(StreakState.barColor(percentage, habit: habit))
        )

        // `yOffset = rect.centerY() + 0.3f * em` is the baseline of text
        // centred in the row; the same 0.34-em correction the Dart charts make
        // turns it back into the centre SwiftUI anchors on.
        let centerY = top + baseSize / 2 + 0.3 * em - 0.34 * textSize

        draw(
            context,
            lengthText,
            font: font,
            color: StreakState.numberColor(percentage),
            at: CGPoint(x: width / 2, y: centerY),
            anchor: .center
        )

        if shouldShowLabels {
            draw(
                context,
                label(streak.startOffset),
                font: font,
                color: WidgetTheme.mediumContrastText.color,
                at: CGPoint(x: gap - textMargin, y: centerY),
                anchor: .trailing
            )
            draw(
                context,
                label(streak.endOffset),
                font: font,
                color: WidgetTheme.mediumContrastText.color,
                at: CGPoint(x: width - gap + textMargin, y: centerY),
                anchor: .leading
            )
        }
    }

    /// `df.longFormat(date)` — the locale's medium date pattern.
    private func label(_ offset: Int) -> String {
        DateNames.longFormat(DateNames.date(today, minusDays: offset))
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

    /// `Paint.fontSpacing` — the distance between two baselines.
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

/// One `org.isoron.uhabits.core.models.Streak`, expressed in offsets from the
/// published `today` because that is the only calendar the document carries.
///
/// `startOffset` is the older end of the run, so it is the *larger* offset —
/// `Streak.start` is never newer than `Streak.end`.
struct WidgetStreak: Equatable {

    let startOffset: Int
    let endOffset: Int

    /// `Streak.length` = `start.daysUntil(end) + 1`.
    var length: Int { startOffset - endOffset + 1 }
}

/// The pure half of `StreakWidget.refreshData`: `habit.streaks.getBest(n)`,
/// with `StreakList.recompute` kept as the pre-schema fallback.
enum StreakState {

    /// `habit.streaks` as this chart measures them — offsets back from the
    /// published `today` — or nil when the document predates the field.
    ///
    /// The bridge publishes `habit.streaks.getBest(HomeWidgetBridge
    /// .streakCount)` — the best thirty, a superset of any count a card this
    /// size can show — so [best] running `getBest` again over it gives the same
    /// answer for any limit. That is `StreakChartView.bestOf` on the Android
    /// side.
    ///
    /// Nothing here is clipped to the entry window: a run that ran for two
    /// hundred days simply has a `startOffset` of two hundred, and a run that
    /// ended a year ago is still in the list. A streak whose dates do not parse
    /// is dropped rather than guessed at — an extension that traps is killed
    /// and the user sees a blank card.
    static func published(_ habit: WidgetHabit, today: Date) -> [WidgetStreak]? {
        guard let streaks = habit.streaks else { return nil }
        return streaks.compactMap { streak in
            guard
                let start = WidgetStore.parseDate(streak.start),
                let end = WidgetStore.parseDate(streak.end),
                let startOffset = offset(of: start, from: today),
                let endOffset = offset(of: end, from: today)
            else { return nil }
            return WidgetStreak(startOffset: startOffset, endOffset: endOffset)
        }
    }

    /// Whole days from [date] to [today], which is how far back a bar's label
    /// has to count. Negative for a date in the future, which no streak has.
    private static func offset(of date: Date, from today: Date) -> Int? {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: today)
        ).day
    }

    /// `StreakList.recompute`'s predicate. A boolean day counts when its value
    /// is greater than zero — which includes SKIP, upstream behaviour — and a
    /// numerical day when it meets the target the habit's type asks for.
    ///
    /// The numerical branch is dead on this widget, whose picker offers only
    /// boolean habits (`widgets.streak#5`); it is here because
    /// `StreakList.recompute` has it and a widget that is one day pointed at a
    /// numerical habit should behave the way the model does.
    static func isPartOfStreak(value: Int, habit: WidgetHabit) -> Bool {
        guard habit.isNumerical else { return value > 0 }
        if habit.isAtMost {
            return value != EntryValue.unknown
                && Double(value) / 1000.0 <= habit.target
        }
        return Double(value) / 1000.0 >= habit.target
    }

    /// `StreakList.recompute`, over the published sixty-day window — the
    /// fallback for a document that predates [published].
    ///
    /// The entries arrive newest-first, which is the order `getByInterval`
    /// hands `recompute` upstream, so the loop below is the Kotlin one with
    /// dates replaced by their offsets: "one day older" is "offset + 1".
    static func recompute(_ habit: WidgetHabit) -> [WidgetStreak] {
        let offsets = habit.entries.indices.filter {
            isPartOfStreak(value: habit.entries[$0], habit: habit)
        }
        guard let first = offsets.first else { return [] }

        var streaks: [WidgetStreak] = []
        var begin = first
        var end = first
        for offset in offsets.dropFirst() {
            if offset == begin + 1 {
                begin = offset
            } else {
                streaks.append(WidgetStreak(startOffset: begin, endOffset: end))
                begin = offset
                end = offset
            }
        }
        streaks.append(WidgetStreak(startOffset: begin, endOffset: end))
        return streaks
    }

    /// `StreakList.getBest(limit)`: the [limit] longest streaks, handed back
    /// newest-first.
    ///
    /// `compareLonger` breaks a tie on length with `compareNewer`, so the
    /// ordering is total and the two sorts below are the Kotlin's two sorts.
    static func best(
        of habit: WidgetHabit,
        limit: Int,
        today: Date
    ) -> [WidgetStreak] {
        guard limit > 0 else { return [] }
        let all = published(habit, today: today) ?? recompute(habit)
        let longest = all.sorted { a, b in
            if a.length != b.length { return a.length > b.length }
            // A newer streak ends closer to today, i.e. at a smaller offset.
            return a.endOffset < b.endOffset
        }
        return Array(longest.prefix(limit)).sorted { $0.endOffset < $1.endOffset }
    }

    /// `percentageToColor`: the habit colour, then the same colour at alpha
    /// 192 and 96, then `?attr/contrast20`, which under the widget theme is
    /// the low-contrast white the History widget's empty squares use.
    static func barColor(_ percentage: Double, habit: WidgetHabit) -> Color {
        let primary = WidgetTheme.rawColor(paletteIndex: habit.color)
        if percentage >= 1.0 { return primary.color }
        if percentage >= 0.8 { return primary.withAlpha(192.0 / 255.0).color }
        if percentage >= 0.5 { return primary.withAlpha(96.0 / 255.0).color }
        return WidgetTheme.lowContrastText.color
    }

    /// `percentageToTextColor`: `?attr/contrast0` over a filled bar,
    /// `?attr/contrast60` otherwise.
    static func numberColor(_ percentage: Double) -> Color {
        percentage >= 0.5 ? WidgetTheme.contrast0 : WidgetTheme.contrast60
    }
}

extension DateNames {

    /// `JavaLocalDateFormatter.longFormat` —
    /// `DateFormat.getDateInstance(DateFormat.MEDIUM, Locale.getDefault())`,
    /// which `StreakChart` flanks every bar with
    /// (`audit3.streak-chart-date-labels-are-hard#1`).
    ///
    /// The formatter is built once: a chart asks for two labels per bar and
    /// `DateFormatter` is expensive enough to matter inside an extension with
    /// a 30 MB memory budget.
    private static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func longFormat(_ date: Date) -> String {
        mediumDate.string(from: date)
    }
}
