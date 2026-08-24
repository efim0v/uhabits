/// The selected row of a settings list dialog must stay readable.
///
/// `ListPreferenceDialogFragmentCompat` builds its list with
/// `AlertDialog.Builder.setSingleChoiceItems`, i.e. `CheckedTextView` rows in
/// CHOICE_MODE_SINGLE. A CheckedTextView marks the current entry with its check
/// drawable and nothing else — the label keeps the same colour as every other
/// row. `audit11.the-two-settings-list-dialogs-never#1` made the port pass
/// `ListTile(selected: ...)` so a screen reader can hear which entry is in
/// force, and Material's ListTile answers `selected` by recolouring the label
/// with `ColorScheme.primary`. In this app that is deliberately the toolbar
/// grey #333333 (`app_theme.dart`: "It is NOT colorScheme.primary: that is the
/// toolbar (#333333)"), and the dialog sits on cardBackgroundColor — #303030 in
/// the dark theme, #000000 in pure black. The label the user is looking for
/// becomes the least readable thing on the screen.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/theme/app_theme.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

const String rule =
    'audit12.settings-dialog-selection-is-invisible-in-dark#1 — a '
    'CheckedTextView row keeps the ordinary label colour, so the port must not '
    'let the selection recolour it into the background.';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final themes = <String, core.Theme>{
    'light': core.LightTheme(),
    'dark': core.DarkTheme(),
    'pureBlack': core.PureBlackTheme(),
  };

  themes.forEach((name, theme) {
    testWidgets('$name: the selected label reads against the dialog',
        (tester) async {
      final data = appThemeData(theme);
      await tester.pumpWidget(MaterialApp(
        theme: data,
        home: const Scaffold(
          body: Column(children: <Widget>[
            ListTile(selected: true, title: Text('Monday')),
            ListTile(title: Text('Tuesday')),
          ]),
        ),
      ));

      final Color selected =
          DefaultTextStyle.of(tester.element(find.text('Monday'))).style.color!;
      final Color plain =
          DefaultTextStyle.of(tester.element(find.text('Tuesday'))).style.color!;
      final Color background = data.dialogTheme.backgroundColor ??
          data.colorScheme.surface;

      expect(_contrast(selected, background), greaterThan(4.5),
          reason: '$rule In $name the selected label is $selected on '
              '$background — the row the user is looking for has to be at '
              'least as readable as the others.');
      expect(selected, plain,
          reason: '$rule A CheckedTextView does not tint its label; the check '
              'mark and the accessibility flag carry the selection.');
    });
  });
}
