/// `charts-canvas-theming.android-contrast-attrs`.
///
/// The Android charts — ScoreChart, FrequencyChart, StreakChart, TargetChart,
/// RingView, HeaderView, CheckmarkButtonView, NumberButtonView — never look at
/// a `Theme`. They resolve `?attr/contrast60`, `?attr/cardBgColor` and friends
/// against the activity's theme through `StyledResources`, and those attributes
/// are declared in `uhabits-android/src/main/res/values/styles.xml`, a file
/// `Themes.kt` knows nothing about.
///
/// Ported from:
///   uhabits-android/src/main/res/values/attrs.xml,
///   .../values/styles.xml,
///   .../values/dimens.xml,
///   .../values/material_colors.xml,
///   .../values/colors.xml,
///   uhabits-android/src/main/java/org/isoron/uhabits/utils/StyledResources.kt,
///   .../utils/InterfaceUtils.kt.
///
/// The two colour systems disagree in small, load-bearing ways, and every case
/// below that pins one down says which side it is reading.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/gui/android_resources.dart';
import 'package:uhabits_core/src/gui/color.dart';
import 'package:uhabits_core/src/gui/theme.dart';

void main() {
  tearDown(() {
    StyledResources.setFixedTheme(null);
    InterfaceUtils.reset();
  });

  group('charts-canvas-theming.android-contrast-attrs', () {
    test('#1 the attribute set the legacy charts read', () {
      // attrs.xml declares exactly these; a theme has to answer all of them or
      // a chart drawing against it cannot be coloured at all.
      final theme = LightTheme();
      final attributes = <String, Object>{
        'contrast0': theme.contrast0,
        'contrast20': theme.contrast20,
        'contrast40': theme.contrast40,
        'contrast60': theme.contrast60,
        'contrast80': theme.contrast80,
        'contrast100': theme.contrast100,
        'cardBgColor': theme.cardBgColor,
        'headerBackgroundColor': theme.attrHeaderBackgroundColor,
        'windowBackgroundColor': theme.windowBackgroundColor,
        'highlightedBackgroundColor': theme.highlightedBackgroundColor,
        'palette': theme.palette!,
      };
      expect(attributes.length, 11,
          reason: 'charts-canvas-theming.android-contrast-attrs#1 — the '
              'attribute set is contrast0, contrast20, contrast40, contrast60, '
              'contrast80, contrast100, plus cardBgColor, headerBackgroundColor, '
              'windowBackgroundColor, highlightedBackgroundColor and palette');
      for (final entry in attributes.entries) {
        expect(entry.value, isNotNull,
            reason: 'charts-canvas-theming.android-contrast-attrs#1: '
                '?attr/${entry.key}');
      }
      expect((attributes['palette']! as List<Color>).length, 20,
          reason: 'charts-canvas-theming.android-contrast-attrs#1 — the '
              'palette attribute points at a 20-entry int-array');

      // The whole reason both systems are carried: they do not agree.
      expect(theme.contrast40, isNot(theme.lowContrastTextColor),
          reason: 'charts-canvas-theming.android-contrast-attrs#1 — the chart '
              'attributes are not the Themes.kt tokens: contrast40 is #D8D8D8 '
              'and lowContrastTextColor is 0xE0E0E0');
    });

    test('#2 the light theme (AppBaseTheme)', () {
      final theme = LightTheme();
      const rule = 'charts-canvas-theming.android-contrast-attrs#2';

      expect(theme.contrast0, const Color.fromRgb(0xFFFFFF), reason: rule);
      expect(theme.contrast20, const Color.fromRgb(0xE0E0E0), reason: rule);
      expect(theme.contrast40, const Color.fromRgb(0xD8D8D8), reason: rule);
      expect(theme.contrast60, const Color.fromRgb(0x9E9E9E), reason: rule);
      expect(theme.contrast80, const Color.fromRgb(0x616161), reason: rule);
      expect(theme.contrast100, const Color.fromRgb(0x424242), reason: rule);
      expect(theme.cardBgColor, const Color.fromRgb(0xFAFAFA), reason: rule);
      expect(theme.attrHeaderBackgroundColor, const Color.fromRgb(0xEEEEEE),
          reason: rule);
      expect(theme.windowBackgroundColor, const Color.fromRgb(0xEEEEEE),
          reason: rule);
      expect(theme.highlightedBackgroundColor, const Color.fromRgb(0xF5F5F5),
          reason: rule);
      expect(theme.useHabitColorAsPrimary, isTrue, reason: rule);
      expect(theme.palette!.first, const Color.fromRgb(0xD32F2F),
          reason: '$rule — palette=lightPalette');
    });

    test('#3 the dark theme (AppBaseThemeDark)', () {
      final theme = DarkTheme();
      const rule = 'charts-canvas-theming.android-contrast-attrs#3';

      expect(theme.contrast0, const Color.fromRgb(0x212121), reason: rule);
      expect(theme.contrast20, const Color.fromRgb(0x424242), reason: rule);
      expect(theme.contrast40, const Color.fromRgb(0x525252), reason: rule);
      expect(theme.contrast60, const Color.fromRgb(0x9E9E9E), reason: rule);
      expect(theme.contrast80, const Color.fromRgb(0xE0E0E0), reason: rule);
      expect(theme.contrast100, const Color.fromRgb(0xF5F5F5), reason: rule);
      expect(theme.cardBgColor, const Color.fromRgb(0x303030), reason: rule);
      expect(theme.attrHeaderBackgroundColor, const Color.fromRgb(0x212121),
          reason: rule);
      expect(theme.windowBackgroundColor, const Color.fromRgb(0x212121),
          reason: rule);
      expect(theme.highlightedBackgroundColor, const Color.fromRgb(0x424242),
          reason: rule);
      expect(theme.useHabitColorAsPrimary, isFalse, reason: rule);
      expect(theme.palette!.first, const Color.fromRgb(0xEF9A9A),
          reason: '$rule — palette=darkPalette');
    });

    test('#4 the pure-black theme (AppBaseThemeDark.PureBlack)', () {
      final theme = PureBlackTheme();
      const rule = 'charts-canvas-theming.android-contrast-attrs#4';

      expect(theme.contrast0, const Color.fromRgb(0x000000), reason: rule);
      expect(theme.contrast20, const Color.fromRgb(0x212121), reason: rule);
      expect(theme.contrast40, const Color.fromRgb(0x424242), reason: rule);
      expect(theme.contrast60, const Color.fromRgb(0x9E9E9E), reason: rule);
      expect(theme.contrast80, const Color.fromRgb(0xBDBDBD), reason: rule);
      expect(theme.contrast100, const Color.fromRgb(0xEEEEEE), reason: rule);
      expect(theme.cardBgColor, const Color.fromRgb(0x000000), reason: rule);
      expect(theme.attrHeaderBackgroundColor, const Color.fromRgb(0x000000),
          reason: rule);
      expect(theme.highlightedBackgroundColor, const Color.fromRgb(0x000000),
          reason: rule);
      expect(theme.windowBackgroundColor, const Color.fromRgb(0x000000),
          reason: rule);

      // The style restates no palette, so the dark one is inherited.
      expect(theme.palette, DarkTheme().palette,
          reason: '$rule — the PureBlack style overrides no palette');

      // And the divergence the two systems keep: the Themes.kt token is not
      // blackened, only the attribute is.
      expect(theme.headerBackgroundColor, const Color.fromRgb(0x212121),
          reason: '$rule — headerBackgroundColor the *attribute* is black, '
              'while the Themes.kt token of the same name stays grey_900');
    });

    test('#5 the widget theme (style WidgetTheme, parent AppBaseThemeDark)',
        () {
      final theme = WidgetTheme();
      const rule = 'charts-canvas-theming.android-contrast-attrs#5';

      expect(theme.cardBgColor, const Color.fromRgb(0x303030), reason: rule);
      expect(theme.contrast0, Color.WHITE, reason: rule);
      expect(theme.contrast20.red, 1.0, reason: rule);
      expect(theme.contrast20.alpha, closeTo(0x0F / 255.0, 1e-9),
          reason: '$rule — contrast20=#0FFFFFFF, white at ~6% alpha');
      expect(theme.contrast60.red, 1.0, reason: rule);
      expect(theme.contrast60.alpha, closeTo(0xAF / 255.0, 1e-9),
          reason: '$rule — contrast60=#AFFFFFFF, white at ~69% alpha');
      expect(theme.contrast80, const Color.fromRgb(0x424242), reason: rule);
      expect(theme.contrast100, Color.WHITE, reason: rule);
      expect(theme.widgetShadowAlpha, 0.0, reason: rule);

      // palette=@array/transparentWidgetPalette — a third palette, darker than
      // the light one and different again from `Themes.kt`'s WidgetTheme.
      final palette = theme.palette!;
      expect(palette[0], const Color.fromRgb(0xC62828),
          reason: '$rule — red_800, where lightPalette has red_700');
      expect(palette[12], const Color.fromRgb(0x283593),
          reason: '$rule — indigo_800');
      expect(palette[17], Color.BLACK.withAlpha(0xAF / 255.0),
          reason: '$rule — the last three entries are @color/black_aa');
      expect(palette[18], palette[17], reason: rule);
      expect(palette[19], palette[17], reason: rule);
      expect(palette, isNot(<Color>[
        for (var index = 0; index < 20; index++) theme.color(index)
      ]), reason: '$rule — transparentWidgetPalette is not the palette '
          'Themes.kt\'s WidgetTheme.color() returns');

      // parent="AppBaseThemeDark": the attributes the style does not restate
      // come from the dark theme, not from LightTheme, which is what this
      // class extends on the Themes.kt side.
      expect(theme.contrast40, DarkTheme().contrast40,
          reason: '$rule — contrast40 is not restated, so grey_750 is '
              'inherited from AppBaseThemeDark');
      expect(theme.windowBackgroundColor, DarkTheme().windowBackgroundColor,
          reason: '$rule — nor is windowBackgroundColor');
      expect(theme.useHabitColorAsPrimary, isFalse, reason: rule);
    });

    test('#6 the dimension tokens the charts measure themselves with', () {
      const rule = 'charts-canvas-theming.android-contrast-attrs#6';

      expect(AndroidDimens.baseSize, 20.0, reason: rule);
      expect(AndroidDimens.checkmarkWidth, 48.0, reason: rule);
      expect(AndroidDimens.checkmarkHeight, 48.0, reason: rule);
      expect(AndroidDimens.regularTextSize, 16.0, reason: rule);
      expect(AndroidDimens.smallTextSize, 14.0, reason: rule);
      expect(AndroidDimens.smallerTextSize, 12.0, reason: rule);
      expect(AndroidDimens.tinyTextSize, 10.0, reason: rule);
      expect(AndroidDimens.habitNameWidth, 160.0, reason: rule);
      expect(AndroidDimens.historyEditorMaxHeight, 350.0, reason: rule);

      // The collision worth stating out loud: the resource and the Themes.kt
      // token share a name and disagree by 4sp.
      expect(AndroidDimens.smallTextSize, isNot(LightTheme().smallTextSize),
          reason: '$rule — R.dimen.smallTextSize is 14sp; the Themes.kt '
              'smallTextSize token is 10.0');
      expect(AndroidDimens.tinyTextSize, LightTheme().smallTextSize,
          reason: '$rule — it is tinyTextSize that the KMP charts spell '
              'smallTextSize');
    });

    test('#7 the fixed-theme override replaces the ambient theme everywhere',
        () {
      final resources = StyledResources(LightTheme());
      expect(resources.contrast60, const Color.fromRgb(0x9E9E9E),
          reason: 'charts-canvas-theming.android-contrast-attrs#7 — with no '
              'override the context theme answers');
      expect(resources.cardBgColor, const Color.fromRgb(0xFAFAFA),
          reason: 'charts-canvas-theming.android-contrast-attrs#7');

      StyledResources.setFixedTheme(PureBlackTheme());
      expect(resources.cardBgColor, const Color.fromRgb(0x000000),
          reason: 'charts-canvas-theming.android-contrast-attrs#7 — the '
              'override is process-wide, so an instance built from the light '
              'theme answers with the fixed one');
      expect(StyledResources(DarkTheme()).contrast0,
          const Color.fromRgb(0x000000),
          reason: 'charts-canvas-theming.android-contrast-attrs#7 — and so '
              'does an instance built afterwards');

      StyledResources.setFixedTheme(null);
      expect(resources.cardBgColor, const Color.fromRgb(0xFAFAFA),
          reason: 'charts-canvas-theming.android-contrast-attrs#7 — clearing '
              'it goes back to the context theme');
    });

    test('#7 the fixed resolution replaces dp/sp conversion with a multiply',
        () {
      const rule = 'charts-canvas-theming.android-contrast-attrs#7';

      expect(InterfaceUtils.dpToPixels(10.0, density: 2.5), 25.0,
          reason: '$rule — without an override dp goes through the display '
              'density');
      expect(InterfaceUtils.spToPixels(10.0, density: 2.0, scaledDensity: 3.0),
          30.0,
          reason: '$rule — and sp through the scaled density');
      expect(InterfaceUtils.getDimension(35.0, density: 2.5), 35.0,
          reason: '$rule — a dimension resource is already in pixels');

      InterfaceUtils.setFixedResolution(2.0);
      expect(InterfaceUtils.fixedResolution, 2.0, reason: rule);
      expect(InterfaceUtils.dpToPixels(10.0, density: 2.5), 20.0,
          reason: '$rule — dpToPixels becomes a plain multiply by the fixed '
              'resolution, whatever the device density is');
      expect(InterfaceUtils.spToPixels(10.0, density: 2.5, scaledDensity: 4.0),
          20.0,
          reason: '$rule — spToPixels too, so the user font-size preference '
              'cannot shift a golden');
      expect(InterfaceUtils.getDimension(35.0, density: 2.5), 28.0,
          reason: '$rule — getDimension is rescaled by '
              '(dim / actualDensity * fixedResolution) = 35 / 2.5 * 2');
    });

    test('#8 getPalette throws when the attribute resolves to no resource',
        () {
      const rule = 'charts-canvas-theming.android-contrast-attrs#8';

      expect(StyledResources(LightTheme()).getPalette().length, 20,
          reason: '$rule — the attribute points at a 20-entry int-array');
      expect(StyledResources(WidgetTheme()).getPalette().first,
          const Color.fromRgb(0xC62828),
          reason: '$rule — and it is read off the *fixed or ambient* theme');

      expect(
        () => StyledResources(_PaletteLessTheme()).getPalette(),
        throwsA(isA<StateError>().having(
          (StateError e) => e.message,
          'message',
          'palette resource not found',
        )),
        reason: '$rule — a theme that declares no palette attribute resolves '
            'to a resource id < 0, and getPalette throws rather than '
            'returning an empty array',
      );

      StyledResources.setFixedTheme(_PaletteLessTheme());
      expect(() => StyledResources(LightTheme()).getPalette(),
          throwsA(isA<StateError>()),
          reason: '$rule — the lookup goes through the fixed theme like every '
              'other one');
    });
  });
}

/// A theme whose `palette` attribute is not declared, i.e. whose
/// `getResource(R.attr.palette)` returns -1.
class _PaletteLessTheme extends LightTheme {
  @override
  List<Color>? get palette => null;
}
