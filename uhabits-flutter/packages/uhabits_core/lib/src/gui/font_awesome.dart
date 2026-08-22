/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/FontAwesome.kt
/// and uhabits-android/src/main/res/values/fontawesome.xml.
///
/// Glyphs are addressed by raw code point, never by icon name: the strings
/// below are single characters in the private use area of the bundled
/// FontAwesome typeface, and they only render as icons when drawn with
/// `Font.FONT_AWESOME` (see [FontAssets]).
class FontAwesome {
  FontAwesome._();

  // The two constants declared by the shared core (FontAwesome.kt).

  /// `FontAwesome.CHECK` — U+F00C.
  static const String check = '\u{f00c}';

  /// `FontAwesome.TIMES` — U+F00D.
  static const String times = '\u{f00d}';

  // The rest of the vocabulary, declared by the Android string resources.
  // Kept here (rather than in a Flutter resource file) so that the charts and
  // the widgets can share one glyph table.

  /// `fa_skipped` — U+F068, the "minus" glyph.
  static const String skipped = '\u{f068}';

  /// `fa_question` — U+F128.
  static const String question = '\u{f128}';

  /// `fa_star_half_o` — U+F5C0.
  static const String starHalfO = '\u{f5c0}';

  /// `fa_arrow_circle_up` — U+F0AA.
  static const String arrowCircleUp = '\u{f0aa}';

  /// `fa_arrow_circle_down` — U+F0AB.
  static const String arrowCircleDown = '\u{f0ab}';

  /// `fa_bell_o` — U+F0F3.
  static const String bellO = '\u{f0f3}';

  /// `fa_calendar` — U+F073.
  static const String calendar = '\u{f073}';

  /// `fa_exclamation_circle` — U+F06A.
  static const String exclamationCircle = '\u{f06a}';

  /// `fa_umbrella_beach` — U+F5CA.
  static const String umbrellaBeach = '\u{f5ca}';

  /// The glyphs declared by the shared core, keyed by their Kotlin names.
  ///
  /// The core declares exactly these two.
  static const Map<String, String> coreGlyphs = <String, String>{
    'CHECK': check,
    'TIMES': times,
  };

  /// The glyphs declared by `res/values/fontawesome.xml`, keyed by their
  /// Android resource names. `fa_check` and `fa_times` repeat the two core
  /// code points; the remaining nine are only available on Android.
  static const Map<String, String> androidGlyphs = <String, String>{
    'fa_check': check,
    'fa_times': times,
    'fa_skipped': skipped,
    'fa_question': question,
    'fa_star_half_o': starHalfO,
    'fa_arrow_circle_up': arrowCircleUp,
    'fa_arrow_circle_down': arrowCircleDown,
    'fa_bell_o': bellO,
    'fa_calendar': calendar,
    'fa_exclamation_circle': exclamationCircle,
    'fa_umbrella_beach': umbrellaBeach,
  };
}

/// Where the three typefaces used by the drawing layer come from, and the
/// stable family names the Flutter renderer must register them under.
///
/// The Kotlin backends do not agree with each other: `JavaCanvas` loads all
/// three faces from the core's own assets, while `AndroidCanvas` only bundles
/// the icon font and falls back to `Typeface.DEFAULT` / `Typeface.DEFAULT_BOLD`
/// for text. That is why the two backends keep separate golden baselines. The
/// Flutter renderer follows the core/JVM side, so that the core goldens under
/// `uhabits-core/assets/test/views/` stay usable.
class FontAssets {
  FontAssets._();

  /// `Font.FONT_AWESOME` in the core/JVM renderer, relative to the core's
  /// resource root (`uhabits-core/assets/main/`).
  static const String coreFontAwesome = 'fonts/FontAwesome.ttf';

  /// `Font.REGULAR` in the core/JVM renderer.
  static const String coreRegular = 'fonts/NotoSans-Regular.ttf';

  /// `Font.BOLD` in the core/JVM renderer.
  static const String coreBold = 'fonts/NotoSans-Bold.ttf';

  /// The asset `InterfaceUtils.getFontAwesome` loads on Android, cached in a
  /// single process-wide `Typeface`. The instrumentation APK ships its own
  /// copy of the same file under `src/androidTest/assets/`.
  static const String androidFontAwesome = 'fontawesome-webfont.ttf';

  /// Family name the icon font is registered under.
  static const String fontAwesomeFamily = 'FontAwesome';

  /// Family name the regular and bold text faces are registered under.
  static const String regularFamily = 'NotoSans';
}
