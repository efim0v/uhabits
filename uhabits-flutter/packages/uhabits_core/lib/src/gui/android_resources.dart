/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/utils/StyledResources.kt,
/// .../utils/InterfaceUtils.kt and the chart half of
/// uhabits-android/src/main/res/values/dimens.xml.
///
/// The legacy Android charts do not read a [Theme]; they read theme attributes
/// and dimension resources through these two helpers. [Theme] already carries
/// the attribute values (`contrast0`..`contrast100`, `cardBgColor`, …), so what
/// is left here is the *lookup* behaviour around them: the process-wide fixed
/// theme, the fixed resolution, and the one lookup that throws.
library;

import 'color.dart';
import 'theme.dart';

/// `res/values/dimens.xml`, the tokens the Android charts measure themselves
/// with (`charts-canvas-theming.android-contrast-attrs#6`).
///
/// Deliberately not folded into [Theme]: the names collide with the Themes.kt
/// size tokens and the values disagree. `Theme.smallTextSize` is 10.0, the
/// logical size the KMP charts draw labels at; `AndroidDimens.smallTextSize` is
/// the 14sp `R.dimen.smallTextSize` a `RingView` or a `NumberButtonView` asks
/// the resource table for. Both are real, and confusing them shifts every
/// golden.
class AndroidDimens {
  const AndroidDimens._();

  /// `<dimen name="baseSize">20dp</dimen>` — the row height of a streak or
  /// target chart, and the marker size of a score chart.
  static const double baseSize = 20.0;

  /// `<dimen name="checkmarkWidth">48dp</dimen>`.
  static const double checkmarkWidth = 48.0;

  /// `<dimen name="checkmarkHeight">48dp</dimen>`.
  static const double checkmarkHeight = 48.0;

  /// `<dimen name="regularTextSize">16sp</dimen>`.
  static const double regularTextSize = 16.0;

  /// `<dimen name="smallTextSize">14sp</dimen>` — a `RingView`'s default text
  /// size and a `NumberButtonView`'s number.
  static const double smallTextSize = 14.0;

  /// `<dimen name="smallerTextSize">12sp</dimen>` — the question mark and the
  /// unit label.
  static const double smallerTextSize = 12.0;

  /// `<dimen name="tinyTextSize">10sp</dimen>` — the header dates and every
  /// chart axis label.
  static const double tinyTextSize = 10.0;

  /// `<dimen name="habitNameWidth">160dp</dimen>`.
  static const double habitNameWidth = 160.0;

  /// `<dimen name="history_editor_max_height">350dp</dimen>`.
  static const double historyEditorMaxHeight = 350.0;
}

/// Port of `class StyledResources(private val context: Context)`.
///
/// Android resolves an attribute against `context.theme`; the port resolves it
/// against the [Theme] it is handed, which is the same indirection with the
/// resource table folded in.
class StyledResources {
  StyledResources(this._theme);

  final Theme _theme;

  /// `private var fixedTheme: Int?` on the companion object — a *process-wide*
  /// override, set by the instrumentation harness so that a screenshot is
  /// taken under a known theme whatever the device is set to
  /// (`charts-canvas-theming.android-contrast-attrs#7`).
  static Theme? _fixedTheme;

  /// `StyledResources.setFixedTheme(theme)`. Pass null to go back to the
  /// ambient theme.
  static void setFixedTheme(Theme? theme) {
    _fixedTheme = theme;
  }

  /// The theme every getter below reads from: the fixed one when one is set,
  /// otherwise the context's.
  Theme get theme => _fixedTheme ?? _theme;

  Color get contrast0 => theme.contrast0;

  Color get contrast20 => theme.contrast20;

  Color get contrast40 => theme.contrast40;

  Color get contrast60 => theme.contrast60;

  Color get contrast80 => theme.contrast80;

  Color get contrast100 => theme.contrast100;

  Color get cardBgColor => theme.cardBgColor;

  Color get headerBackgroundColor => theme.attrHeaderBackgroundColor;

  Color get windowBackgroundColor => theme.windowBackgroundColor;

  Color get highlightedBackgroundColor => theme.highlightedBackgroundColor;

  bool get useHabitColorAsPrimary => theme.useHabitColorAsPrimary;

  double get widgetShadowAlpha => theme.widgetShadowAlpha;

  /// `fun getPalette(): IntArray`.
  ///
  /// ```kotlin
  /// val resourceId = getResource(R.attr.palette)
  /// if (resourceId < 0) throw RuntimeException("palette resource not found")
  /// return context.resources.getIntArray(resourceId)
  /// ```
  ///
  /// `getResource` returns -1 when the theme does not declare the attribute,
  /// which is [Theme.palette] being null here
  /// (`charts-canvas-theming.android-contrast-attrs#8`).
  List<Color> getPalette() {
    final palette = theme.palette;
    if (palette == null) throw StateError('palette resource not found');
    return palette;
  }
}

/// Port of `object InterfaceUtils`, the density conversions
/// (`charts-canvas-theming.android-contrast-attrs#7`).
///
/// Flutter's logical pixel is already density-independent, so the port's charts
/// do not convert at all — which is exactly what a fixed resolution of 1.0
/// produces here. The class exists because the *fixed* resolution is the thing
/// the Android goldens were captured under, and a port that wants to reproduce
/// one has to reproduce the arithmetic too.
class InterfaceUtils {
  const InterfaceUtils._();

  static double? _fixedResolution;

  /// `InterfaceUtils.setFixedResolution(f)`. There is no way to unset it
  /// upstream; [reset] exists so a test can undo itself.
  static void setFixedResolution(double f) {
    _fixedResolution = f;
  }

  /// Not upstream: `fixedResolution` is a `var` with no clearing setter there,
  /// because the process it lives in is torn down after every test run.
  static void reset() {
    _fixedResolution = null;
  }

  static double? get fixedResolution => _fixedResolution;

  /// `dpToPixels(context, dp)`: a plain multiply once a fixed resolution is
  /// set, and `TypedValue.applyDimension(COMPLEX_UNIT_DIP, …)` — which is also
  /// a multiply by the display density — otherwise.
  static double dpToPixels(double dp, {required double density}) {
    final fixed = _fixedResolution;
    if (fixed != null) return dp * fixed;
    return dp * density;
  }

  /// `spToPixels(context, sp)`: the same, against the *scaled* density, which
  /// carries the user's font-size preference.
  static double spToPixels(
    double sp, {
    required double density,
    double? scaledDensity,
  }) {
    final fixed = _fixedResolution;
    if (fixed != null) return sp * fixed;
    return sp * (scaledDensity ?? density);
  }

  /// `getDimension(context, id)`: the resource table already holds the value in
  /// pixels, so a fixed resolution has to divide the device density back out
  /// before applying its own — `dim / actualDensity * fixedResolution`.
  static double getDimension(double dimensionPixels,
      {required double density}) {
    final fixed = _fixedResolution;
    if (fixed != null) return dimensionPixels / density * fixed;
    return dimensionPixels;
  }
}
