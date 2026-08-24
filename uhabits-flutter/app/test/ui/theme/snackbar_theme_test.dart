/// The toast is dark with white text, in every theme.
///
/// `View.showMessage` is `Snackbar.make(this, msg, LENGTH_SHORT)` followed by
/// `tv?.setTextColor(Color.WHITE)` — white, unconditionally, with no branch on
/// the theme (ViewExtensions.kt:105-115). White text is only legible on a dark
/// surface, and that is what the light theme shows.
///
/// Material 3 has a different idea: with no `snackBarTheme` a SnackBar paints
/// itself `ColorScheme.inverseSurface`, so it inverts with the app. In the dark
/// and pure-black themes that is a near-white slab with dark text — the exact
/// opposite of the one colour the Kotlin code states outright, and a bright
/// rectangle in an app whose whole point in pure black is that nothing is.
///
/// `feedback.toasts-must-be-dark-with-white-text#1`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/theme/app_theme.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

const String rule =
    'feedback.toasts-must-be-dark-with-white-text#1 — upstream sets the toast '
    "text to Color.WHITE in every theme, so the surface under it is dark in "
    'every theme.';

double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final themes = <String, core.Theme>{
    'light': core.LightTheme(),
    'dark': core.DarkTheme(),
    'pureBlack': core.PureBlackTheme(),
  };

  themes.forEach((name, theme) {
    testWidgets('$name: the toast is dark and its text is white',
        (tester) async {
      final ThemeData data = appThemeData(theme);
      await tester.pumpWidget(MaterialApp(
        theme: data,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Habit deleted'))),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pump();

      final Material slab = tester.widget<Material>(find
          .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
          .first);
      final Color background = slab.color!;
      final Color text = DefaultTextStyle.of(
              tester.element(find.text('Habit deleted')))
          .style
          .color!;

      expect(_luminance(background), lessThan(0.1),
          reason: '$rule In $name the toast came out $background. Material 3 '
              'paints an unthemed SnackBar with ColorScheme.inverseSurface, '
              'which inverts with the app.');
      expect(_luminance(text), greaterThan(0.7),
          reason: '$rule …and the text is the white the Kotlin sets by hand.');
      expect(_contrast(text, background), greaterThan(7),
          reason: rule);
    });
  });
}
