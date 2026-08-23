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

/// `R.layout.widget_graph` — the shell the Frequency, History, Score, Streak
/// and Target widgets all share (`widgets.graph-view#1`, `#4`).
///
/// The paddings are the XML's, in points: 4 at the top, 8 on the other three
/// sides. The title is the habit name, centred, white, at `smallTextSize`
/// (14sp), clipped to two lines (`widgets.graph-view#3`), and the chart fills
/// what is left (`widgets.graph-view#2`).
struct GraphWidgetView<Chart: View>: View {

    let title: String
    @ViewBuilder let chart: () -> Chart

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(WidgetTheme.contrast0)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
            chart()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(EdgeInsets(top: 4, leading: 8, bottom: 8, trailing: 8))
    }
}

/// The states a widget shows instead of a habit.
///
/// `widgets.error-states#3` describes the Android layout: a centred white
/// label on a rounded #3f000000 plate. WidgetKit paints the card itself, so
/// the plate here is the container background and only the label is drawn.
/// Every one of them is a key into `Localizable.strings`, not a sentence.
///
/// Upstream these are string resources — `R.string.habit_not_found` and the
/// two the port added beside it — which the launcher resolves in the device
/// language before any app code runs, per-app language override included. A
/// Swift literal here would be English on every phone in the world, so the
/// same seven strings are mirrored from the ARB catalogue into
/// `ios/HabitsWidget/*.lproj/Localizable.strings` and named by key.
enum WidgetPlaceholder {

    /// `widgets.error-states#1` — the stored habit id no longer resolves.
    /// The wording is `R.string.habit_not_found`.
    static let habitNotFound = LocalizedStringKey("habit_not_found")

    /// `widgets.error-states#2` — the catch-all. Anything this extension
    /// cannot render falls back to the same text the `widget_error` layout
    /// carries by default.
    static let errorDrawing = LocalizedStringKey("widget_error_drawing")

    /// The analogue of `widgets.error-states#6`: upstream, a launcher drop with
    /// no eligible habits shows a message and never creates the widget. iOS
    /// creates the widget regardless, so the message lands here instead. The
    /// key is the one Android already carries for it,
    /// `R.string.widget_not_configured`.
    static let noHabits = LocalizedStringKey("widget_not_configured")
}

/// The centred label those states are drawn as.
struct WidgetMessageView: View {

    /// A key, so that `Text` resolves it against the extension's bundle.
    /// `Text(String)` would render whatever it was handed, verbatim, which is
    /// how the English literals survived translation.
    let message: LocalizedStringKey

    var body: some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundStyle(WidgetTheme.contrast0)
            .multilineTextAlignment(.center)
            .padding(EdgeInsets(top: 4, leading: 8, bottom: 0, trailing: 8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {

    /// The widget card.
    ///
    /// On Android `HabitWidgetView` paints a `RoundRectShape` with 18dp corners
    /// and an alpha taken from `Preferences.widgetOpacity`
    /// (`widgets.card-chrome#2`, `#5`). WidgetKit owns both the shape and the
    /// corner radius — a widget cannot draw outside its rounded container — so
    /// only the colour crosses over, through `containerBackground`.
    func widgetCard(_ color: Color = WidgetTheme.cardBackgroundOpaque) -> some View {
        containerBackground(color, for: .widget)
    }
}
