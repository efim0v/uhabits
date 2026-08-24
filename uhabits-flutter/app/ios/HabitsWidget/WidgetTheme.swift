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

/// `org.isoron.platform.gui.Color`, as far as the widgets need it.
///
/// Kept as four doubles rather than a `SwiftUI.Color` because `HistoryChart`
/// blends colours componentwise, alpha included, and a `Color` cannot be taken
/// apart again.
struct WidgetColor: Equatable {

    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// From a 0xRRGGBB literal, which is how `Themes.kt` writes them.
    init(_ rgb: Int) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }

    /// `Color.blendWith(other, weight)` — a straight componentwise mix that
    /// includes the alpha channel. Blending with [transparent] therefore both
    /// darkens *and* fades, which is what makes a DIMMED history square look
    /// the way it does on a widget.
    func blendWith(_ other: WidgetColor, weight: Double) -> WidgetColor {
        WidgetColor(
            red: red * (1 - weight) + other.red * weight,
            green: green * (1 - weight) + other.green * weight,
            blue: blue * (1 - weight) + other.blue * weight,
            alpha: alpha * (1 - weight) + other.alpha * weight
        )
    }

    /// `Color.withAlpha(newAlpha)`.
    func withAlpha(_ newAlpha: Double) -> WidgetColor {
        WidgetColor(red: red, green: green, blue: blue, alpha: newAlpha)
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    static let transparent = WidgetColor(red: 0, green: 0, blue: 0, alpha: 0)
    static let white = WidgetColor(red: 1, green: 1, blue: 1, alpha: 1)
}

/// Swift copy of `org.isoron.uhabits.core.ui.views.WidgetTheme` plus the
/// Android `R.style.WidgetTheme` attributes that the widget views read through
/// `StyledResources`.
///
/// The two halves live in one place here because on iOS there is no resource
/// system to split them across: [color(paletteIndex:)] is the core
/// `WidgetTheme` (`widgets.theme#2`), `cardBackground`/`highContrastText`/...
/// are the core theme colours (`widgets.theme#3`), and `cardBgColor`/
/// `contrast0`/`contrast20`/`contrast60`/`contrast100` are the XML attributes
/// of the same name (`widgets.theme#1`).
///
/// `widgets.theme#5`: none of this consults the user's light/dark preference.
/// A widget is always drawn with these colours, so every view below is written
/// against a dark card and never reads the environment's colour scheme.
enum WidgetTheme {

    // MARK: - Habit palette (`widgets.theme#2`)

    /// `WidgetTheme.color(paletteIndex)` for 0..19, black for anything else.
    ///
    /// Note the deliberate differences from the app's `LightTheme` palette:
    /// index 12 is `0x6275f0` rather than `0x303F9F`, and index 17 is
    /// `0x757575` rather than `0x424242` — the widget palette lightens the
    /// colours that would otherwise vanish into the dark card.
    static func rawColor(paletteIndex: Int) -> WidgetColor {
        switch paletteIndex {
        case 0: return WidgetColor(0xD32F2F)
        case 1: return WidgetColor(0xE64A19)
        case 2: return WidgetColor(0xF57C00)
        case 3: return WidgetColor(0xFF8F00)
        case 4: return WidgetColor(0xF9A825)
        case 5: return WidgetColor(0xAFB42B)
        case 6: return WidgetColor(0x7CB342)
        case 7: return WidgetColor(0x388E3C)
        case 8: return WidgetColor(0x00897B)
        case 9: return WidgetColor(0x00ACC1)
        case 10: return WidgetColor(0x039BE5)
        case 11: return WidgetColor(0x1976D2)
        case 12: return WidgetColor(0x6275F0)
        case 13: return WidgetColor(0x5E35B1)
        case 14: return WidgetColor(0x8E24AA)
        case 15: return WidgetColor(0xD81B60)
        case 16: return WidgetColor(0x5D4037)
        case 17: return WidgetColor(0x757575)
        case 18: return WidgetColor(0x757575)
        case 19: return WidgetColor(0x9E9E9E)
        default: return WidgetColor(0x000000)
        }
    }

    static func color(paletteIndex: Int) -> Color {
        rawColor(paletteIndex: paletteIndex).color
    }

    // MARK: - Core theme colours (`widgets.theme#3`)

    /// `WidgetTheme.cardBackgroundColor` = TRANSPARENT.
    ///
    /// Two `HistoryChart` branches hinge on this: every square's day number
    /// takes the `highContrastTextColor` shortcut instead of a per-square
    /// contrast calculation, and the hatching drawn over a SKIP square is
    /// painted in a fully transparent colour — so on a widget, and only on a
    /// widget, HATCHED and DIMMED squares are indistinguishable.
    static let cardBackground = WidgetColor.transparent

    /// `WidgetTheme.highContrastTextColor` = WHITE.
    static let highContrastText = WidgetColor.white

    /// `WidgetTheme.mediumContrastTextColor` = WHITE at 50%.
    static let mediumContrastText = WidgetColor.white.withAlpha(0.50)

    /// `WidgetTheme.lowContrastTextColor` = WHITE at 10%.
    static let lowContrastText = WidgetColor.white.withAlpha(0.10)

    // MARK: - Android style attributes (`widgets.theme#1`)

    /// `?attr/cardBgColor` = `@color/grey_850` = #303030.
    ///
    /// This is the widget card itself. On Android it is painted by
    /// `HabitWidgetView` into a `RoundRectShape` with 18dp corners
    /// (`widgets.card-chrome#2`); WidgetKit owns both the shape and the corner
    /// radius, so only the colour crosses over, through `containerBackground`.
    static let cardBackgroundOpaque = WidgetColor(0x303030).color

    /// `?attr/contrast0` = `@color/white`.
    static let contrast0 = Color.white

    /// `?attr/contrast20` = `@color/white_a0` = #0fffffff, i.e. white at
    /// alpha 0x0f/0xff.
    ///
    /// Kept in [WidgetColor] form as well, unlike its siblings, because
    /// `FrequencyChart.initColors` blends it into the marker ramp
    /// componentwise — alpha included — and a `SwiftUI.Color` cannot be taken
    /// apart again.
    static let rawContrast20 = WidgetColor.white.withAlpha(Double(0x0f) / 255.0)

    /// `?attr/contrast20`, as a `SwiftUI.Color`.
    static let contrast20 = rawContrast20.color

    /// `?attr/contrast60` = `@color/white_aa` = #afffffff, i.e. white at
    /// alpha 0xaf/0xff.
    static let contrast60 = Color.white.opacity(Double(0xaf) / 255.0)

    /// `?attr/contrast100` = `@color/white`. `RingView` fills the unearned
    /// part of the ring with this at 15% alpha (`widgets.checkmark-view#12`).
    static let ringInactive = Color.white.opacity(0.15)
}
