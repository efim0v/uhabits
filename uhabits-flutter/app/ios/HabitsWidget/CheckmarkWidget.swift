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

/// `CheckmarkWidget` / `CheckmarkWidgetView`.
///
/// The one widget that does not use the graph shell (`widgets.graph-view#4`):
/// a ring showing the habit's score with today's checkmark glyph in the middle,
/// and the habit name underneath.
struct CheckmarkWidget: Widget {

    /// The `kind` must equal the string `HomeWidgetBridge.providerNames` passes
    /// to `HomeWidget.updateWidget(iOSName:)`, which is the Android provider
    /// class name spelled identically on purpose. Change one and the widget
    /// stops refreshing.
    static let kind = "CheckmarkWidgetProvider"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: SelectHabitIntent.self,
            provider: HabitTimelineProvider()
        ) { entry in
            CheckmarkWidgetView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringKey("widget_name_checkmark"))
        .description(LocalizedStringKey("widget_description_checkmark"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - View

struct CheckmarkWidgetView: View {

    let entry: HabitTimelineEntry

    var body: some View {
        switch entry.state {
        case .noHabits:
            WidgetMessageView(message: WidgetPlaceholder.noHabits)
                .widgetCard()
        case .deleted:
            WidgetMessageView(message: WidgetPlaceholder.habitNotFound)
                .widgetCard()
        case .habit(let habit):
            // `widgets.checkmark#6`, `#7`: which action a tap carries is
            // decided by the habit type — exactly the branch
            // `CheckmarkWidget.refreshData` takes when it chooses between
            // `toggleCheckmark` and `showNumberPicker`.
            if habit.isNumerical {
                // The value picker is an app screen and always was, so this
                // half is a link.
                CheckmarkContent(habit: habit)
                    .widgetCard(Self.cardColor(habit))
                    .widgetURL(WidgetLink.edit(habit, date: entry.todayText))
            } else {
                // The boolean half opens nothing: the button runs
                // `ToggleHabitIntent` inside this extension, which advances the
                // card and records the tap for the app to apply
                // (`audit4.tapping-a-boolean-checkmark-widget-now#1`).
                Button(intent: ToggleHabitIntent(habitId: habit.id)) {
                    CheckmarkContent(habit: habit)
                }
                .buttonStyle(.plain)
                .widgetCard(Self.cardColor(habit))
                // The margin the button does not cover, and any system that
                // will not run it: the same toggle, by way of the app.
                .widgetURL(WidgetLink.toggle(habit))
            }
        }
    }

    /// `widgets.checkmark-view#3`, `#4`: the card turns the habit colour when
    /// today is YES_MANUAL, YES_AUTO or SKIP, and stays `?attr/cardBgColor`
    /// for NO, UNKNOWN and anything else.
    static func cardColor(_ habit: WidgetHabit) -> Color {
        switch CheckmarkState.entryState(habit) {
        case EntryValue.yesManual, EntryValue.yesAuto, EntryValue.skip:
            return WidgetTheme.color(paletteIndex: habit.color)
        default:
            return WidgetTheme.cardBackgroundOpaque
        }
    }
}

private struct CheckmarkContent: View {

    let habit: WidgetHabit

    var body: some View {
        GeometryReader { geometry in
            let box = CheckmarkState.contentSize(geometry.size)
            let layout = CheckmarkState.layout(box)

            VStack(spacing: 0) {
                RingView(
                    percentage: habit.score ?? 0,
                    // `widgets.checkmark-view#10`: the ring thickness is 3% of
                    // the measured width.
                    thickness: 0.03 * box.width,
                    color: CheckmarkState.foregroundColor(habit),
                    glyph: CheckmarkState.glyph(habit),
                    // ...and the numerical ring text is set at 90% of the
                    // label size, the glyph at 100%.
                    glyphSize: habit.isNumerical
                        ? layout.textSize * 0.9
                        : layout.textSize,
                    isStroked: CheckmarkState.isStrokedTextEnabled(habit)
                )
                .frame(width: layout.diameter, height: layout.diameter)
                .padding(.top, 8)

                Text(habit.name)
                    .font(.system(size: layout.textSize))
                    .foregroundStyle(CheckmarkState.foregroundColor(habit))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
                    .frame(height: layout.labelHeight)
                    .padding(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
            }
            .frame(width: box.width, height: layout.totalHeight)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

/// `RingView` with `enableFontAwesome=true` and transparency enabled, which is
/// how `CheckmarkWidgetView` configures it.
///
/// Android builds the annulus by filling two pie slices and then punching the
/// inner disc out with `PorterDuff.CLEAR` (`widgets.checkmark-view#12`); the
/// visible result is a ring of `thickness` whose leading arc, starting at
/// -90 degrees, is the foreground colour and whose remainder is `contrast100`
/// at 15% alpha. Stroking two circles produces the same picture without the
/// blend mode.
private struct RingView: View {

    let percentage: Double
    let thickness: CGFloat
    let color: Color
    let glyph: CheckmarkGlyph
    let glyphSize: CGFloat
    let isStroked: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(WidgetTheme.ringInactive, lineWidth: thickness)
            Circle()
                .inset(by: thickness / 2)
                .trim(from: 0, to: CGFloat(clamped))
                .stroke(color, lineWidth: thickness)
                .rotationEffect(.degrees(-90))
            glyphView
        }
    }

    /// `RingView` quantises the sweep to `precision` (0.01) before drawing.
    private var clamped: Double {
        let precision = 0.01
        let quantised = (percentage / precision).rounded() * precision
        return min(max(quantised, 0), 1)
    }

    @ViewBuilder
    private var glyphView: some View {
        switch glyph {
        case .symbol(let name):
            Image(systemName: name)
                // `widgets.checkmark-view#8`: a YES_AUTO boolean draws its
                // glyph stroked rather than filled. FontAwesome's outline is
                // approximated here by the lightest symbol weight, since an
                // SF Symbol has no stroke-only rendering mode.
                .font(.system(size: glyphSize, weight: isStroked ? .ultraLight : .bold))
                .foregroundStyle(color)
        case .text(let value):
            Text(value)
                .font(.system(size: glyphSize))
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }
}

// MARK: - State

enum CheckmarkGlyph {
    /// An SF Symbol standing in for a FontAwesome codepoint.
    case symbol(String)
    /// A numerical habit's value, rendered as text.
    case text(String)
}

/// The pure half of `CheckmarkWidget.refreshData` and `CheckmarkWidgetView`.
enum CheckmarkState {

    /// `widgets.checkmark#3`, `#4`.
    ///
    /// A boolean habit's state is today's entry value verbatim. A numerical
    /// habit collapses to YES_MANUAL when it is complete and NO when it is
    /// not — which is why a numerical widget never shows SKIP or UNKNOWN.
    static func entryState(_ habit: WidgetHabit) -> Int {
        if habit.isNumerical {
            return habit.isCompletedToday ? EntryValue.yesManual : EntryValue.no
        }
        return habit.value
    }

    /// `widgets.checkmark-view#3`, `#4`: `?attr/contrast0` on an active card,
    /// `?attr/contrast60` otherwise.
    static func foregroundColor(_ habit: WidgetHabit) -> Color {
        switch entryState(habit) {
        case EntryValue.yesManual, EntryValue.yesAuto, EntryValue.skip:
            return WidgetTheme.contrast0
        default:
            return WidgetTheme.contrast60
        }
    }

    /// `widgets.checkmark-view#8`.
    static func isStrokedTextEnabled(_ habit: WidgetHabit) -> Bool {
        guard !habit.isNumerical else { return false }
        return entryState(habit) == EntryValue.yesAuto
    }

    /// `widgets.checkmark-view#6`, `#7`.
    ///
    /// The FontAwesome codepoints are replaced one for one by SF Symbols:
    /// `fa_check` (f00c) by `checkmark`, `fa_times` (f00d) by `xmark`,
    /// `fa_skipped` (f068, a minus sign) by `minus` and `fa_question` (f128)
    /// by `questionmark`. Shipping the FontAwesome face in the extension would
    /// reproduce the glyphs exactly, at the cost of carrying the font twice.
    static func glyph(_ habit: WidgetHabit) -> CheckmarkGlyph {
        if habit.isNumerical {
            return .text(shortString(Double(max(0, habit.value)) / 1000.0))
        }
        switch entryState(habit) {
        case EntryValue.yesManual, EntryValue.yesAuto:
            return .symbol("checkmark")
        case EntryValue.skip:
            return .symbol("minus")
        default:
            // NO, UNKNOWN and anything else. Upstream UNKNOWN draws
            // `fa_question` when `Preferences.areQuestionMarksEnabled`, but
            // that preference is not part of the published contract, so the
            // widget always takes the `fa_times` branch.
            return .symbol("xmark")
        }
    }

    /// What `R.layout.widget_checkmark`'s LinearLayout resolves to
    /// (`widgets.checkmark-view#1`).
    struct Layout {
        /// The label's text size, and the ring glyph's.
        let textSize: CGFloat
        /// The ring's diameter.
        let diameter: CGFloat
        /// The height the label row is stretched to.
        let labelHeight: CGFloat
        /// The whole stack, which the parent centres.
        let totalHeight: CGFloat
    }

    /// Resolves that layout the way `LinearLayout` does.
    ///
    /// The ring is `layout_height=0dp` with weight 0.9 and the label is
    /// `wrap_content` with weight 0.1, so the label is measured first and the
    /// *leftover* height is split 90/10 between them — the ring does not get
    /// 90% of the widget, it gets 90% of what is left after the label and the
    /// four margins (ring top 8, label top 4 and bottom 4). Getting this wrong
    /// is what makes a ring fill the whole card instead of leaving the margin
    /// the golden render shows.
    static func layout(_ box: CGSize) -> Layout {
        // `widgets.checkmark-view#10`: the label and the ring glyph are sized
        // from the *width*, capped at `R.dimen.smallTextSize` (14sp).
        let textSize = min(0.175 * box.width, 14)
        // A one-line `TextView` measures its font's ascent plus descent; for a
        // sans-serif face that is a little under 1.2 em.
        let labelHeight = 1.2 * textSize
        let leftover = box.height - 8 - labelHeight - 4 - 4
        let ringBox = 0.9 * leftover
        let labelBox = labelHeight + 0.1 * leftover
        // `widgets.checkmark-view#13`: RingView always measures square, so the
        // narrower of the two dimensions wins.
        let diameter = max(1, min(box.width - 8, ringBox))
        return Layout(
            textSize: textSize,
            diameter: diameter,
            labelHeight: max(0, labelBox),
            totalHeight: 8 + diameter + 4 + max(0, labelBox) + 4
        )
    }

    /// `widgets.checkmark-view#9`: at most 1.5x taller than wide, and never
    /// wider than it is tall.
    static func contentSize(_ available: CGSize) -> CGSize {
        var width = available.width
        var height = available.height
        if height >= width {
            height = min(height, (width * 1.5).rounded())
        } else {
            width = min(width, height)
        }
        return CGSize(width: width, height: height)
    }

    /// `Double.toShortString()` (`widgets.checkmark-view#7`).
    ///
    /// Reproduced including its redundant branches: `>= 1e7` and `>= 1e6` both
    /// format as `%.1fM`, and `>= 1e4` and `>= 1e3` both as `%.1fk`.
    static func shortString(_ value: Double) -> String {
        switch value {
        case let v where v >= 1e9: return String(format: "%.1fG", v / 1e9)
        case let v where v >= 1e8: return String(format: "%.0fM", v / 1e6)
        case let v where v >= 1e7: return String(format: "%.1fM", v / 1e6)
        case let v where v >= 1e6: return String(format: "%.1fM", v / 1e6)
        case let v where v >= 1e5: return String(format: "%.0fk", v / 1e3)
        case let v where v >= 1e4: return String(format: "%.1fk", v / 1e3)
        case let v where v >= 1e3: return String(format: "%.1fk", v / 1e3)
        case let v where v >= 1e2: return decimal(v, fractionDigits: 0)
        case let v where v >= 1e1: return decimal(v, fractionDigits: 1)
        default: return decimal(value, fractionDigits: 2)
        }
    }

    /// `DecimalFormat("#")`, `("#.#")` and `("#.##")`: at most that many
    /// fraction digits, and no trailing zeros.
    private static func decimal(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
