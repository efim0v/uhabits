import 'dart:io';

import 'package:test/test.dart';
import 'package:uhabits_core/src/gui/color.dart';
import 'package:uhabits_core/src/gui/theme.dart';
import 'package:uhabits_core/src/models/palette_color.dart';

/// Rules from docs/parity/FEATURES.md:
///   charts-canvas-theming.theme-tokens,
///   charts-canvas-theming.theme-palette,
///   charts-canvas-theming.theme-variants.
///
/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/Themes.kt
/// (plus PaletteColor.kt and uhabits-android/.../utils/PaletteUtils.kt for the
/// CSV / fixed-Android palette rules). The Kotlin side has no unit test for
/// Themes.kt — BarChartTest/HistoryChartTest only render golden images with
/// LightTheme, DarkTheme and WidgetTheme — so every case below comes from the
/// rules and from the Kotlin sources read line by line.

/// The 20 habit colours of the light palette, in index order.
const lightPalette = <int>[
  0xD32F2F, //  0 red
  0xE64A19, //  1 deep orange
  0xF57C00, //  2 orange
  0xFF8F00, //  3 amber
  0xF9A825, //  4 yellow
  0xAFB42B, //  5 lime
  0x7CB342, //  6 light green
  0x388E3C, //  7 green
  0x00897B, //  8 teal
  0x00ACC1, //  9 cyan
  0x039BE5, // 10 light blue
  0x1976D2, // 11 blue
  0x303F9F, // 12 indigo
  0x5E35B1, // 13 deep purple
  0x8E24AA, // 14 purple
  0xD81B60, // 15 pink
  0x5D4037, // 16 brown
  0x424242, // 17 dark grey
  0x757575, // 18 grey
  0x9E9E9E, // 19 light grey
];

const darkPalette = <int>[
  0xEF9A9A,
  0xFFAB91,
  0xFFCC80,
  0xFFECB3,
  0xFFF59D,
  0xE6EE9C,
  0xC5E1A5,
  0x69F0AE,
  0x80CBC4,
  0x80DEEA,
  0x81D4FA,
  0x64B5F6,
  0x9FA8DA,
  0xB39DDB,
  0xCE93D8,
  0xF48FB1,
  0xBCAAA4,
  0xF5F5F5,
  0xE0E0E0,
  0x9E9E9E,
];

/// The light palette with two substitutions: indigo at 12 and grey at 17.
const widgetPalette = <int>[
  0xD32F2F,
  0xE64A19,
  0xF57C00,
  0xFF8F00,
  0xF9A825,
  0xAFB42B,
  0x7CB342,
  0x388E3C,
  0x00897B,
  0x00ACC1,
  0x039BE5,
  0x1976D2,
  0x6275F0, // 12 indigo — brighter than the light palette's 0x303F9F
  0x5E35B1,
  0x8E24AA,
  0xD81B60,
  0x5D4037,
  0x757575, // 17 dark grey — lighter than the light palette's 0x424242
  0x757575,
  0x9E9E9E,
];

/// The CSV / fixed-Android palette. Differs from [lightPalette] at 17 and 19.
const csvPalette = <String>[
  '#D32F2F',
  '#E64A19',
  '#F57C00',
  '#FF8F00',
  '#F9A825',
  '#AFB42B',
  '#7CB342',
  '#388E3C',
  '#00897B',
  '#00ACC1',
  '#039BE5',
  '#1976D2',
  '#303F9F',
  '#5E35B1',
  '#8E24AA',
  '#D81B60',
  '#5D4037',
  '#303030',
  '#757575',
  '#aaaaaa',
];

/// The 12 colour tokens of [Theme], read off an instance in declaration order.
Map<String, Color> tokensOf(Theme t) => <String, Color>{
      'appBackgroundColor': t.appBackgroundColor,
      'cardBackgroundColor': t.cardBackgroundColor,
      'headerBackgroundColor': t.headerBackgroundColor,
      'headerBorderColor': t.headerBorderColor,
      'headerTextColor': t.headerTextColor,
      'highContrastTextColor': t.highContrastTextColor,
      'itemBackgroundColor': t.itemBackgroundColor,
      'lowContrastTextColor': t.lowContrastTextColor,
      'mediumContrastTextColor': t.mediumContrastTextColor,
      'statusBarBackgroundColor': t.statusBarBackgroundColor,
      'toolbarBackgroundColor': t.toolbarBackgroundColor,
      'toolbarColor': t.toolbarColor,
    };

int rgbIntOf(Color c) =>
    (((c.red * 255).round() & 0xFF) << 16) |
    (((c.green * 255).round() & 0xFF) << 8) |
    ((c.blue * 255).round() & 0xFF);

/// '0xRRGGBB', so a mismatch reads like the Kotlin literal it came from.
String hexOf(Color c) =>
    '0x${rgbIntOf(c).toRadixString(16).toUpperCase().padLeft(6, '0')}';

String hexOfInt(int rgb) =>
    '0x${rgb.toRadixString(16).toUpperCase().padLeft(6, '0')}';

/// Asserts an opaque 0xRRGGBB token: exact channels plus alpha == 1.0.
void expectOpaque(Color actual, int expected, String rule) {
  expect(hexOf(actual), hexOfInt(expected), reason: rule);
  expect(actual.alpha, 1.0, reason: rule);
}

/// Proves `Theme` is extendable and that its tokens are the base values.
class ProbeBaseTheme extends Theme {}

/// Proves `color(paletteIndex)` is open: overriding it must reroute the
/// `colorOf(PaletteColor)` helper too.
class ProbeOverridingTheme extends Theme {
  @override
  Color color(int paletteIndex) => Color(0.5, 0.25, 0.125, 1.0);
}

/// Proves LightTheme / DarkTheme / WidgetTheme are `open` (extendable).
class ProbeLight extends LightTheme {}

class ProbeDark extends DarkTheme {}

class ProbeWidget extends WidgetTheme {}

void main() {
  group('charts-canvas-theming.theme-tokens', () {
    test('#1 the abstract Theme base class defines 12 opaque colour tokens',
        () {
      final theme = ProbeBaseTheme();
      const rule = 'charts-canvas-theming.theme-tokens#1';
      expectOpaque(theme.appBackgroundColor, 0xF4F4F4, rule);
      expectOpaque(theme.cardBackgroundColor, 0xFAFAFA, rule);
      expectOpaque(theme.headerBackgroundColor, 0xEEEEEE, rule);
      expectOpaque(theme.headerBorderColor, 0xCCCCCC, rule);
      expectOpaque(theme.headerTextColor, 0x9E9E9E, rule);
      expectOpaque(theme.highContrastTextColor, 0x202020, rule);
      expectOpaque(theme.itemBackgroundColor, 0xFFFFFF, rule);
      expectOpaque(theme.lowContrastTextColor, 0xE0E0E0, rule);
      expectOpaque(theme.mediumContrastTextColor, 0x9E9E9E, rule);
      expectOpaque(theme.statusBarBackgroundColor, 0x333333, rule);
      expectOpaque(theme.toolbarBackgroundColor, 0xF4F4F4, rule);
      expectOpaque(theme.toolbarColor, 0xFFFFFF, rule);
      expect(tokensOf(theme).length, 12,
          reason: '$rule — exactly these twelve tokens');
    });

    test('#1 the tokens are open: a subclass can replace one of them', () {
      // Kotlin marks every token `open val`; DarkTheme/PureBlackTheme/
      // WidgetTheme all rely on that.
      final base = ProbeBaseTheme();
      final dark = DarkTheme();
      expect(hexOf(base.appBackgroundColor) == hexOf(dark.appBackgroundColor),
          isFalse,
          reason: 'charts-canvas-theming.theme-tokens#1');
    });

    test('#2 the three size tokens are 48.0 / 10.0 / 17.0 in every variant',
        () {
      const rule = 'charts-canvas-theming.theme-tokens#2';
      final themes = <Theme>[
        ProbeBaseTheme(),
        LightTheme(),
        DarkTheme(),
        PureBlackTheme(),
        WidgetTheme(),
      ];
      for (final theme in themes) {
        expect(theme.checkmarkButtonSize, 48.0, reason: rule);
        expect(theme.smallTextSize, 10.0, reason: rule);
        expect(theme.regularTextSize, 17.0, reason: rule);
      }
    });

    test('#3 color(PaletteColor) delegates to the open color(int)', () {
      const rule = 'charts-canvas-theming.theme-tokens#3';
      final light = LightTheme();
      for (var i = 0; i < 20; i++) {
        expect(hexOf(light.colorOf(PaletteColor(i))), hexOf(light.color(i)),
            reason: rule);
      }
      // Overriding only color(int) must reroute the PaletteColor helper.
      final probe = ProbeOverridingTheme();
      final delegated = probe.colorOf(const PaletteColor(3));
      expect(delegated.red, 0.5, reason: rule);
      expect(delegated.green, 0.25, reason: rule);
      expect(delegated.blue, 0.125, reason: rule);
      expect(delegated.alpha, 1.0, reason: rule);
    });

    test('#4 LightTheme is an empty subclass and keeps every base value', () {
      const rule = 'charts-canvas-theming.theme-tokens#4';
      final base = tokensOf(ProbeBaseTheme());
      final light = tokensOf(LightTheme());
      expect(light.keys.toList(), base.keys.toList(), reason: rule);
      for (final name in base.keys) {
        expect(hexOf(light[name]!), hexOf(base[name]!),
            reason: '$rule ($name)');
        expect(light[name]!.alpha, base[name]!.alpha, reason: '$rule ($name)');
      }
      final lightTheme = LightTheme();
      final baseTheme = ProbeBaseTheme();
      for (var i = -3; i < 25; i++) {
        expect(hexOf(lightTheme.color(i)), hexOf(baseTheme.color(i)),
            reason: rule);
      }
      expect(lightTheme.checkmarkButtonSize, baseTheme.checkmarkButtonSize,
          reason: rule);
      expect(lightTheme.smallTextSize, baseTheme.smallTextSize, reason: rule);
      expect(lightTheme.regularTextSize, baseTheme.regularTextSize,
          reason: rule);
    });
  });

  group('charts-canvas-theming.theme-palette', () {
    test('#1 the light palette holds these exact 20 colours', () {
      const rule = 'charts-canvas-theming.theme-palette#1';
      final theme = LightTheme();
      expect(lightPalette.length, 20, reason: rule);
      for (var i = 0; i < 20; i++) {
        expectOpaque(theme.color(i), lightPalette[i], '$rule (index $i)');
      }
    });

    test('#1 out-of-range light indices fall back to 0x000000', () {
      const rule = 'charts-canvas-theming.theme-palette#1';
      final theme = LightTheme();
      for (final i in <int>[-100, -1, 20, 21, 1000]) {
        expectOpaque(theme.color(i), 0x000000, '$rule (index $i)');
      }
    });

    test('#2 the dark palette holds these exact 20 colours', () {
      const rule = 'charts-canvas-theming.theme-palette#2';
      final theme = DarkTheme();
      expect(darkPalette.length, 20, reason: rule);
      for (var i = 0; i < 20; i++) {
        expectOpaque(theme.color(i), darkPalette[i], '$rule (index $i)');
      }
    });

    test('#2 out-of-range dark indices fall back to 0xFFFFFF', () {
      const rule = 'charts-canvas-theming.theme-palette#2';
      final theme = DarkTheme();
      for (final i in <int>[-100, -1, 20, 21, 1000]) {
        expectOpaque(theme.color(i), 0xFFFFFF, '$rule (index $i)');
      }
    });

    test('#3 the widget palette is the light one with 12 and 17 replaced', () {
      const rule = 'charts-canvas-theming.theme-palette#3';
      final widget = WidgetTheme();
      final light = LightTheme();
      for (var i = 0; i < 20; i++) {
        expectOpaque(widget.color(i), widgetPalette[i], '$rule (index $i)');
      }
      expectOpaque(widget.color(12), 0x6275F0, rule);
      expectOpaque(light.color(12), 0x303F9F, rule);
      expectOpaque(widget.color(17), 0x757575, rule);
      expectOpaque(light.color(17), 0x424242, rule);
      for (var i = 0; i < 20; i++) {
        if (i == 12 || i == 17) continue;
        expect(hexOf(widget.color(i)), hexOf(light.color(i)),
            reason: '$rule (index $i is shared with the light palette)');
      }
      for (final i in <int>[-100, -1, 20, 21, 1000]) {
        expectOpaque(widget.color(i), 0x000000, '$rule (index $i)');
      }
    });

    test('#4 PaletteColor.toCsvColor returns the CSV hex strings', () {
      const rule = 'charts-canvas-theming.theme-palette#4';
      for (var i = 0; i < 20; i++) {
        expect(PaletteColor(i).toCsvColor(), csvPalette[i],
            reason: '$rule (index $i)');
      }
      // Indices 17 and 19 deliberately disagree with Theme's light palette.
      expect(PaletteColor(17).toCsvColor(), '#303030', reason: rule);
      expect(hexOf(LightTheme().color(17)), '0x424242', reason: rule);
      expect(PaletteColor(19).toCsvColor(), '#aaaaaa', reason: rule);
      expect(hexOf(LightTheme().color(19)), '0x9E9E9E', reason: rule);
      // Out-of-range indices throw (Kotlin: ArrayIndexOutOfBoundsException).
      expect(() => PaletteColor(20).toCsvColor(), throwsRangeError,
          reason: rule);
      expect(() => PaletteColor(-1).toCsvColor(), throwsRangeError,
          reason: rule);
    });

    test('#5 the fixed Android palette reuses the CSV colours', () {
      const rule = 'charts-canvas-theming.theme-palette#5';
      for (var i = 0; i < 20; i++) {
        final expected =
            0xFF000000 | int.parse(csvPalette[i].substring(1), radix: 16);
        expect(PaletteColor(i).toFixedAndroidColor(), expected,
            reason: '$rule (index $i)');
      }
      expect(PaletteColor(17).toFixedAndroidColor(), 0xFF303030, reason: rule);
      expect(PaletteColor(19).toFixedAndroidColor(), 0xFFAAAAAA, reason: rule);
      expect(() => PaletteColor(20).toFixedAndroidColor(), throwsRangeError,
          reason: rule);
    });

    test('#6 the default habit colour is palette index 8 (teal)', () {
      const rule = 'charts-canvas-theming.theme-palette#6';
      expect(defaultPaletteColor.paletteIndex, 8, reason: rule);
      expectOpaque(LightTheme().colorOf(defaultPaletteColor), 0x00897B, rule);
      expect(defaultPaletteColor.toCsvColor(), '#00897B', reason: rule);
    });

    test('#7 the light base token values', () {
      const rule = 'charts-canvas-theming.theme-palette#7';
      final theme = LightTheme();
      expectOpaque(theme.appBackgroundColor, 0xF4F4F4, rule);
      expectOpaque(theme.cardBackgroundColor, 0xFAFAFA, rule);
      expectOpaque(theme.headerBackgroundColor, 0xEEEEEE, rule);
      expectOpaque(theme.headerBorderColor, 0xCCCCCC, rule);
      expectOpaque(theme.headerTextColor, 0x9E9E9E, rule);
      expectOpaque(theme.highContrastTextColor, 0x202020, rule);
      expectOpaque(theme.itemBackgroundColor, 0xFFFFFF, rule);
      expectOpaque(theme.lowContrastTextColor, 0xE0E0E0, rule);
      expectOpaque(theme.mediumContrastTextColor, 0x9E9E9E, rule);
      expectOpaque(theme.statusBarBackgroundColor, 0x333333, rule);
      expectOpaque(theme.toolbarBackgroundColor, 0xF4F4F4, rule);
      expectOpaque(theme.toolbarColor, 0xFFFFFF, rule);
    });

    test('#8 the sizing constants', () {
      const rule = 'charts-canvas-theming.theme-palette#8';
      final theme = LightTheme();
      expect(theme.checkmarkButtonSize, 48.0, reason: rule);
      expect(theme.smallTextSize, 10.0, reason: rule);
      expect(theme.regularTextSize, 17.0, reason: rule);
    });

    test('#9 LightTheme is an unmodified subclass of Theme', () {
      const rule = 'charts-canvas-theming.theme-palette#9';
      final light = LightTheme();
      expect(light, isA<Theme>(), reason: rule);
      final base = tokensOf(ProbeBaseTheme());
      tokensOf(light).forEach((name, color) {
        expect(hexOf(color), hexOf(base[name]!), reason: '$rule ($name)');
        expect(color.alpha, base[name]!.alpha, reason: '$rule ($name)');
      });
      for (var i = 0; i < 20; i++) {
        expectOpaque(light.color(i), lightPalette[i], '$rule (index $i)');
      }
    });

    test('#10 DarkTheme overrides five tokens and re-declares seven', () {
      const rule = 'charts-canvas-theming.theme-palette#10';
      final dark = DarkTheme();
      final light = LightTheme();
      // Genuinely different from the light theme.
      expectOpaque(dark.appBackgroundColor, 0x212121, rule);
      expectOpaque(dark.cardBackgroundColor, 0x303030, rule);
      expectOpaque(dark.headerBackgroundColor, 0x212121, rule);
      expectOpaque(dark.highContrastTextColor, 0xF5F5F5, rule);
      expectOpaque(dark.lowContrastTextColor, 0x424242, rule);
      // Re-declared with the SAME values as the light theme.
      expectOpaque(dark.headerBorderColor, 0xCCCCCC, rule);
      expectOpaque(dark.headerTextColor, 0x9E9E9E, rule);
      expectOpaque(dark.itemBackgroundColor, 0xFFFFFF, rule);
      expectOpaque(dark.mediumContrastTextColor, 0x9E9E9E, rule);
      expectOpaque(dark.statusBarBackgroundColor, 0x333333, rule);
      expectOpaque(dark.toolbarBackgroundColor, 0xF4F4F4, rule);
      expectOpaque(dark.toolbarColor, 0xFFFFFF, rule);
      for (final name in <String>[
        'headerBorderColor',
        'headerTextColor',
        'itemBackgroundColor',
        'mediumContrastTextColor',
        'statusBarBackgroundColor',
        'toolbarBackgroundColor',
        'toolbarColor',
      ]) {
        expect(hexOf(tokensOf(dark)[name]!), hexOf(tokensOf(light)[name]!),
            reason: '$rule ($name matches the light theme)');
      }
    });

    test('#11 Theme.color(PaletteColor) delegates to color(paletteIndex)', () {
      const rule = 'charts-canvas-theming.theme-palette#11';
      for (final theme in <Theme>[
        LightTheme(),
        DarkTheme(),
        PureBlackTheme(),
        WidgetTheme(),
      ]) {
        for (var i = -1; i < 21; i++) {
          expect(hexOf(theme.colorOf(PaletteColor(i))), hexOf(theme.color(i)),
              reason: '$rule (index $i)');
        }
      }
    });

    test('#12 WidgetTheme extends LightTheme and overrides four tokens', () {
      const rule = 'charts-canvas-theming.theme-palette#12';
      final widget = WidgetTheme();
      expect(widget, isA<LightTheme>(), reason: rule);
      expect(widget.cardBackgroundColor, Color.TRANSPARENT,
          reason: '$rule (cardBackgroundColor is Color.TRANSPARENT)');
      expect(widget.cardBackgroundColor, Color(0.0, 0.0, 0.0, 0.0),
          reason: '$rule (cardBackgroundColor is Color.TRANSPARENT)');
      expect(widget.highContrastTextColor, Color.WHITE,
          reason: '$rule (highContrastTextColor is Color.WHITE)');
      expect(widget.highContrastTextColor, Color(1.0, 1.0, 1.0, 1.0),
          reason: '$rule (highContrastTextColor is Color.WHITE)');
      expect(widget.mediumContrastTextColor, Color.WHITE.withAlpha(0.50),
          reason: '$rule (mediumContrastTextColor is white at alpha 0.50)');
      expect(widget.mediumContrastTextColor, Color(1.0, 1.0, 1.0, 0.50),
          reason: '$rule (mediumContrastTextColor is white at alpha 0.50)');
      expect(widget.lowContrastTextColor, Color.WHITE.withAlpha(0.10),
          reason: '$rule (lowContrastTextColor is white at alpha 0.10)');
      expect(widget.lowContrastTextColor, Color(1.0, 1.0, 1.0, 0.10),
          reason: '$rule (lowContrastTextColor is white at alpha 0.10)');
      expect(widget.mediumContrastTextColor.alpha, 0.50, reason: rule);
      expect(widget.lowContrastTextColor.alpha, 0.10, reason: rule);
      // The other eight tokens still come from LightTheme.
      final light = tokensOf(LightTheme());
      for (final name in <String>[
        'appBackgroundColor',
        'headerBackgroundColor',
        'headerBorderColor',
        'headerTextColor',
        'itemBackgroundColor',
        'statusBarBackgroundColor',
        'toolbarBackgroundColor',
        'toolbarColor',
      ]) {
        expect(tokensOf(widget)[name], light[name], reason: '$rule ($name)');
      }
    });

    test('#13 Color(rgb) decomposes into red, green, blue and alpha 1.0', () {
      const rule = 'charts-canvas-theming.theme-palette#13';
      final c = Color.fromRgb(0x336699);
      expect(c.red, 0x33 / 255.0, reason: rule);
      expect(c.green, 0x66 / 255.0, reason: rule);
      expect(c.blue, 0x99 / 255.0, reason: rule);
      expect(c.alpha, 1.0, reason: rule);
      expect(Color.fromRgb(0xFF0000), Color(1.0, 0.0, 0.0, 1.0), reason: rule);
      expect(Color.fromRgb(0x00897B).red, 0x00 / 255.0, reason: rule);
      expect(Color.fromRgb(0x00897B).green, 0x89 / 255.0, reason: rule);
      expect(Color.fromRgb(0x00897B).blue, 0x7B / 255.0, reason: rule);
    });

    test('#14 luminosity = 0.21*red + 0.72*green + 0.07*blue', () {
      const rule = 'charts-canvas-theming.theme-palette#14';
      expect(Color(0.2, 0.4, 0.6, 1.0).luminosity,
          closeTo(0.21 * 0.2 + 0.72 * 0.4 + 0.07 * 0.6, 1e-12),
          reason: rule);
      expect(Color(1.0, 1.0, 1.0, 1.0).luminosity, closeTo(1.0, 1e-12),
          reason: rule);
      expect(Color(0.0, 0.0, 0.0, 1.0).luminosity, closeTo(0.0, 1e-12),
          reason: rule);
      // Alpha plays no part.
      expect(Color(0.2, 0.4, 0.6, 0.0).luminosity,
          closeTo(Color(0.2, 0.4, 0.6, 1.0).luminosity, 1e-12),
          reason: rule);
    });

    test('#15 contrast(other) = max(r, 1/r)', () {
      const rule = 'charts-canvas-theming.theme-palette#15';
      final white = Color(1.0, 1.0, 1.0, 1.0);
      final black = Color(0.0, 0.0, 0.0, 1.0);
      expect(white.contrast(black), closeTo(1.05 / 0.05, 1e-12), reason: rule);
      expect(black.contrast(white), closeTo(1.05 / 0.05, 1e-12), reason: rule);
      expect(white.contrast(white), closeTo(1.0, 1e-12), reason: rule);
      final teal = Color.fromRgb(0x00897B);
      expect(teal.contrast(white), greaterThanOrEqualTo(1.0), reason: rule);
      expect(teal.contrast(white), closeTo(white.contrast(teal), 1e-12),
          reason: rule);
    });

    test('#16 blendWith interpolates red, green, blue AND alpha', () {
      const rule = 'charts-canvas-theming.theme-palette#16';
      final blended =
          Color(0.0, 0.0, 0.0, 0.0).blendWith(Color(1.0, 1.0, 1.0, 1.0), 0.25);
      expect(blended.red, closeTo(0.25, 1e-12), reason: rule);
      expect(blended.green, closeTo(0.25, 1e-12), reason: rule);
      expect(blended.blue, closeTo(0.25, 1e-12), reason: rule);
      expect(blended.alpha, closeTo(0.25, 1e-12), reason: rule);
      final a = Color(0.2, 0.4, 0.6, 0.8);
      final b = Color(0.6, 0.2, 0.0, 0.4);
      final mid = a.blendWith(b, 0.5);
      expect(mid.red, closeTo(0.4, 1e-12), reason: rule);
      expect(mid.green, closeTo(0.3, 1e-12), reason: rule);
      expect(mid.blue, closeTo(0.3, 1e-12), reason: rule);
      expect(mid.alpha, closeTo(0.6, 1e-12), reason: rule);
      expect(a.blendWith(b, 0.0), a, reason: rule);
      expect(a.blendWith(b, 1.0), b, reason: rule);
    });
  });

  group('charts-canvas-theming.theme-variants', () {
    test('#1 DarkTheme token values and dark palette', () {
      const rule = 'charts-canvas-theming.theme-variants#1';
      final dark = DarkTheme();
      expectOpaque(dark.appBackgroundColor, 0x212121, rule);
      expectOpaque(dark.cardBackgroundColor, 0x303030, rule);
      expectOpaque(dark.headerBackgroundColor, 0x212121, rule);
      expectOpaque(dark.headerBorderColor, 0xCCCCCC, rule);
      expectOpaque(dark.headerTextColor, 0x9E9E9E, rule);
      expectOpaque(dark.highContrastTextColor, 0xF5F5F5, rule);
      expectOpaque(dark.itemBackgroundColor, 0xFFFFFF, rule);
      expectOpaque(dark.lowContrastTextColor, 0x424242, rule);
      expectOpaque(dark.mediumContrastTextColor, 0x9E9E9E, rule);
      expectOpaque(dark.statusBarBackgroundColor, 0x333333, rule);
      expectOpaque(dark.toolbarBackgroundColor, 0xF4F4F4, rule);
      expectOpaque(dark.toolbarColor, 0xFFFFFF, rule);
      for (var i = 0; i < 20; i++) {
        expectOpaque(dark.color(i), darkPalette[i], '$rule (index $i)');
      }
      expectOpaque(dark.color(20), 0xFFFFFF, rule);
    });

    test('#2 PureBlackTheme overrides only three tokens', () {
      const rule = 'charts-canvas-theming.theme-variants#2';
      final pure = PureBlackTheme();
      final dark = DarkTheme();
      expect(pure, isA<DarkTheme>(), reason: rule);
      expectOpaque(pure.appBackgroundColor, 0x000000, rule);
      expectOpaque(pure.cardBackgroundColor, 0x000000, rule);
      expectOpaque(pure.lowContrastTextColor, 0x212121, rule);
      final darkTokens = tokensOf(dark);
      for (final name in <String>[
        'headerBackgroundColor',
        'headerBorderColor',
        'headerTextColor',
        'highContrastTextColor',
        'itemBackgroundColor',
        'mediumContrastTextColor',
        'statusBarBackgroundColor',
        'toolbarBackgroundColor',
        'toolbarColor',
      ]) {
        expect(tokensOf(pure)[name], darkTokens[name],
            reason: '$rule ($name is inherited from DarkTheme)');
      }
      // The palette, too, is inherited untouched.
      for (var i = 0; i < 20; i++) {
        expectOpaque(pure.color(i), darkPalette[i], '$rule (index $i)');
      }
      expectOpaque(pure.color(-1), 0xFFFFFF, rule);
      expectOpaque(pure.color(20), 0xFFFFFF, rule);
      expect(pure.checkmarkButtonSize, 48.0, reason: rule);
    });

    test('#3 WidgetTheme overrides four tokens plus its own palette', () {
      const rule = 'charts-canvas-theming.theme-variants#3';
      final widget = WidgetTheme();
      expect(widget, isA<LightTheme>(), reason: rule);
      expect(widget.cardBackgroundColor, Color.TRANSPARENT,
          reason: '$rule (Color.TRANSPARENT)');
      expect(widget.highContrastTextColor, Color.WHITE,
          reason: '$rule (Color.WHITE)');
      expect(widget.mediumContrastTextColor, Color.WHITE.withAlpha(0.50),
          reason: '$rule (Color.WHITE.withAlpha(0.50))');
      expect(widget.lowContrastTextColor, Color.WHITE.withAlpha(0.10),
          reason: '$rule (Color.WHITE.withAlpha(0.10))');
      for (var i = 0; i < 20; i++) {
        expectOpaque(widget.color(i), widgetPalette[i], '$rule (index $i)');
      }
      expectOpaque(widget.color(20), 0x000000, rule);
    });

    test('#4 WidgetTheme.cardBackgroundColor is exactly Color.TRANSPARENT', () {
      const rule = 'charts-canvas-theming.theme-variants#4';
      // HistoryChart compares with ==, so componentwise equality is what the
      // branch actually tests.
      const transparent = Color.TRANSPARENT;
      expect(WidgetTheme().cardBackgroundColor == transparent, isTrue,
          reason: rule);
      // No other variant trips that branch.
      for (final theme in <Theme>[
        LightTheme(),
        DarkTheme(),
        PureBlackTheme(),
      ]) {
        expect(theme.cardBackgroundColor == transparent, isFalse,
            reason: '$rule (${theme.runtimeType} is opaque)');
      }
      expect(PureBlackTheme().cardBackgroundColor.alpha, 1.0,
          reason: '$rule (0x000000 is opaque black, not transparent)');
    });

    test('#5 LightTheme, DarkTheme and WidgetTheme are open; '
        'PureBlackTheme is final', () {
      const rule = 'charts-canvas-theming.theme-variants#5';
      // The three probe subclasses below only compile because their
      // superclasses are extendable.
      expect(ProbeLight(), isA<LightTheme>(), reason: rule);
      expect(ProbeDark(), isA<DarkTheme>(), reason: rule);
      expect(ProbeWidget(), isA<WidgetTheme>(), reason: rule);
      // Dart has no runtime reflection of class modifiers, so the `final`
      // half of the rule is checked against the source text. Comment lines
      // are dropped first, otherwise the doc comments quoting the Kotlin
      // declarations would be matched instead.
      final source = File('lib/src/gui/theme.dart')
          .readAsStringSync()
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .toList();
      String declarationOf(String name) => source.firstWhere(
            (line) => RegExp('^[a-z ]*class $name\\b').hasMatch(line),
            orElse: () => '<missing declaration of $name>',
          );
      expect(declarationOf('PureBlackTheme'), contains('class PureBlackTheme'),
          reason: '$rule (PureBlackTheme must be declared)');
      expect(declarationOf('PureBlackTheme').startsWith('final class'), isTrue,
          reason: '$rule (PureBlackTheme must be final)');
      for (final name in <String>['LightTheme', 'DarkTheme', 'WidgetTheme']) {
        final line = declarationOf(name);
        expect(line, contains('class $name'),
            reason: '$rule ($name must be declared)');
        expect(line.contains('final class'), isFalse,
            reason: '$rule ($name must stay open)');
        expect(line.contains('sealed class'), isFalse,
            reason: '$rule ($name must stay open)');
        expect(line.contains('interface class'), isFalse,
            reason: '$rule ($name must stay open)');
      }
    });
  });

  // -------------------------------------------------------------------------
  // The same themes read against the show-habit screen's own colour rules.
  // -------------------------------------------------------------------------
  group('show-habit.theme-colors', () {
    test('#2 the light palette indices 0..19, and black for anything else', () {
      const rule = 'show-habit.theme-colors#2';
      final theme = LightTheme();
      for (var i = 0; i < 20; i++) {
        expectOpaque(theme.color(i), lightPalette[i], '$rule (index $i)');
      }
      expectOpaque(theme.color(-1), 0x000000, rule);
      expectOpaque(theme.color(20), 0x000000, rule);
      expectOpaque(theme.color(999), 0x000000, rule);
    });

    test('#3 the dark palette indices 0..19, and white for anything else', () {
      const rule = 'show-habit.theme-colors#3';
      final theme = DarkTheme();
      for (var i = 0; i < 20; i++) {
        expectOpaque(theme.color(i), darkPalette[i], '$rule (index $i)');
      }
      expectOpaque(theme.color(-1), 0xFFFFFF, rule);
      expectOpaque(theme.color(20), 0xFFFFFF, rule);
    });

    test('#5 the dark neutrals, and what PureBlackTheme does to them', () {
      const rule = 'show-habit.theme-colors#5';
      final dark = DarkTheme();
      expectOpaque(dark.cardBackgroundColor, 0x303030, rule);
      expectOpaque(dark.lowContrastTextColor, 0x424242, rule);
      expectOpaque(dark.mediumContrastTextColor, 0x9E9E9E, rule);
      expectOpaque(dark.highContrastTextColor, 0xF5F5F5, rule);
      expectOpaque(dark.appBackgroundColor, 0x212121, rule);

      final pure = PureBlackTheme();
      expectOpaque(pure.appBackgroundColor, 0x000000, rule);
      expectOpaque(pure.cardBackgroundColor, 0x000000, rule);
      expectOpaque(pure.lowContrastTextColor, 0x212121, rule);
      // The other three neutrals are inherited from DarkTheme untouched.
      expectOpaque(pure.mediumContrastTextColor, 0x9E9E9E, rule);
      expectOpaque(pure.highContrastTextColor, 0xF5F5F5, rule);
    });

    test('#6 the two text sizes the charts read are 10.0 and 17.0', () {
      const rule = 'show-habit.theme-colors#6';
      for (final theme in <Theme>[
        LightTheme(),
        DarkTheme(),
        PureBlackTheme(),
        WidgetTheme(),
      ]) {
        expect(theme.smallTextSize, 10.0, reason: rule);
        expect(theme.regularTextSize, 17.0, reason: rule);
      }
    });
  });
}
