/// `audit8.entry-popups-paint-themselves-cardbgcolor-over`.
///
/// The two entry popups — `CheckmarkDialog` and `NumberDialog` — share
/// `res/layout/checkmark_popup.xml`, whose root LinearLayoutCompat carries
/// `android:background="@drawable/checkmark_dialog_bg"` and
/// `app:divider="@drawable/checkmark_dialog_divider"`. Those two drawables name
/// themed attributes, not Themes.kt tokens:
///
/// ```xml
/// <!-- checkmark_dialog_bg.xml -->
/// <solid android:color="?attr/contrast0" />
/// <stroke android:width="2dp" android:color="?contrast40" />
/// <corners android:radius="5dp" />
///
/// <!-- checkmark_dialog_divider.xml -->
/// <solid android:color="?contrast40"/>
/// ```
///
/// `?attr/contrast0` and `?attr/contrast40` are NOT `cardBackgroundColor` and
/// `lowContrastTextColor`: in the light theme the fill is #FFFFFF where
/// cardBgColor is #FAFAFA, and the border is #D8D8D8 where lowContrastTextColor
/// is #E0E0E0. Both dark variants disagree as well.
library;

// Preferences are not re-exported from uhabits_core.dart yet.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/common/dialogs/checkmark_dialog.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/theme/app_theme.dart' show appThemeData, toFlutterColor;
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  /// Pumps a popup under [theme] and returns nothing: every assertion below
  /// reads the widget tree back through [_fill], [_border] and [_dividers].
  Future<void> openCheckmark(WidgetTester tester, core.Theme theme) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: appThemeData(theme),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showCheckmarkDialog(
                  context,
                  value: core.Entry.yesManual,
                  notes: '',
                  color: const core.Color.fromRgb(0xD32F2F),
                  preferences: Preferences(MemoryStorage()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> openNumber(WidgetTester tester, core.Theme theme) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: appThemeData(theme),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showNumberDialog(
                  context,
                  value: 1.0,
                  notes: '',
                  color: const core.Color.fromRgb(0xD32F2F),
                  preferences: Preferences(MemoryStorage()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final variants = <String, core.Theme>{
    'light': core.LightTheme(),
    'dark': core.DarkTheme(),
    'pure black': core.PureBlackTheme(),
  };

  group('audit8.entry-popups-paint-themselves-cardbgcolor-over', () {
    for (final entry in variants.entries) {
      final name = entry.key;
      final theme = entry.value;

      testWidgets('#1 the checkmark popup fills with ?attr/contrast0 and '
          'strokes with ?contrast40 ($name)', (tester) async {
        await openCheckmark(tester, theme);

        expect(
          _fill(tester),
          toFlutterColor(theme.contrast0),
          reason: 'audit8.entry-popups-paint-themselves-cardbgcolor-over#1 — '
              'checkmark_dialog_bg.xml declares <solid ?attr/contrast0>, not '
              'the Themes.kt cardBackgroundColor token',
        );
        expect(
          _border(tester).top.color,
          toFlutterColor(theme.contrast40),
          reason: 'audit8.entry-popups-paint-themselves-cardbgcolor-over#1 — '
              'the 2dp stroke is ?contrast40, not lowContrastTextColor',
        );
        expect(
          _border(tester).top.width,
          2.0,
          reason: 'audit8.entry-popups-paint-themselves-cardbgcolor-over#1 — '
              'a 2dp stroke',
        );
        for (final divider in _dividers(tester)) {
          expect(
            divider.color,
            toFlutterColor(theme.contrast40),
            reason: 'audit8.entry-popups-paint-themselves-cardbgcolor-over#1 — '
                'checkmark_dialog_divider.xml is <solid ?contrast40>',
          );
        }
      });

      testWidgets('#1 the numeric popup shares the same drawable ($name)',
          (tester) async {
        await openNumber(tester, theme);

        expect(
          _fill(tester),
          toFlutterColor(theme.contrast0),
          reason: 'audit8.entry-popups-paint-themselves-cardbgcolor-over#1 — '
              'number_dialog and checkmark_dialog are one layout upstream, so '
              'the numeric popup takes ?attr/contrast0 too',
        );
        expect(
          _border(tester).top.color,
          toFlutterColor(theme.contrast40),
          reason: 'audit8.entry-popups-paint-themselves-cardbgcolor-over#1 — '
              'and the same ?contrast40 stroke',
        );
        for (final divider in _dividers(tester)) {
          expect(
            divider.color,
            toFlutterColor(theme.contrast40),
            reason: 'audit8.entry-popups-paint-themselves-cardbgcolor-over#1 — '
                'and the same ?contrast40 divider',
          );
        }
      });
    }

    test('#1 the two attributes are not the tokens the port was reading', () {
      // The regression this finding is about is only visible because the four
      // values differ; if they ever coincided the assertions above would pass
      // over a defect.
      expect(
        core.LightTheme().contrast0,
        isNot(core.LightTheme().cardBackgroundColor),
        reason: 'audit8.entry-popups-paint-themselves-cardbgcolor-over#1 — '
            '#FFFFFF fill vs the #FAFAFA cardBgColor token',
      );
      expect(
        core.LightTheme().contrast40,
        isNot(core.LightTheme().lowContrastTextColor),
        reason: 'audit8.entry-popups-paint-themselves-cardbgcolor-over#1 — '
            '#D8D8D8 border vs the #E0E0E0 lowContrast token',
      );
      expect(
        <core.Color>[
          core.LightTheme().contrast0,
          core.DarkTheme().contrast0,
          core.PureBlackTheme().contrast0,
        ],
        <core.Color>[
          const core.Color.fromRgb(0xFFFFFF),
          const core.Color.fromRgb(0x212121),
          const core.Color.fromRgb(0x000000),
        ],
        reason: 'audit8.entry-popups-paint-themselves-cardbgcolor-over#1 — '
            'light #FFFFFF, dark #212121, pure black #000000',
      );
      expect(
        <core.Color>[
          core.LightTheme().contrast40,
          core.DarkTheme().contrast40,
          core.PureBlackTheme().contrast40,
        ],
        <core.Color>[
          const core.Color.fromRgb(0xD8D8D8),
          const core.Color.fromRgb(0x525252),
          const core.Color.fromRgb(0x424242),
        ],
        reason: 'audit8.entry-popups-paint-themselves-cardbgcolor-over#1 — '
            'light #D8D8D8, dark #525252, pure black #424242',
      );
    });
  });
}

/// The popup's own `Container`, the one carrying `@drawable/checkmark_dialog_bg`.
///
/// It is the outermost decorated box under the `Dialog`; the only other one is
/// the `Container` a `Divider` builds for itself, which [_dividers] reads
/// through the `Divider` widget instead.
BoxDecoration _decoration(WidgetTester tester) => tester
    .widgetList<Container>(
      find.descendant(of: find.byType(Dialog), matching: find.byType(Container)),
    )
    .map((container) => container.decoration)
    .whereType<BoxDecoration>()
    .first;

Color? _fill(WidgetTester tester) => _decoration(tester).color;

BoxBorder _border(WidgetTester tester) => _decoration(tester).border!;

Iterable<Divider> _dividers(WidgetTester tester) => tester.widgetList<Divider>(
      find.descendant(of: find.byType(Dialog), matching: find.byType(Divider)),
    );
