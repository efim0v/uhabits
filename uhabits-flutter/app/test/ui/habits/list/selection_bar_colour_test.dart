/// The contextual bar has its own background, not the toolbar's.
///
/// `AppBaseTheme` sets the `actionModeBackground` attribute to
/// `@color/grey_700` (#616161) and `AppBaseThemeDark` sets it to
/// `@color/grey_800` (#424242); `AppBaseThemeDark.PureBlack` restates neither,
/// so it inherits grey_800. `ListHabitsSelectionMenu.startSelection()` calls
/// `startSupportActionMode`, and AppCompat's `Widget.AppCompat.ActionMode`
/// paints the bar with `?attr/actionModeBackground`. Long-pressing a habit
/// therefore recolours the top bar — the standard Android cue that a
/// contextual bar has taken over — and the colour returns when selection ends.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

const String rule =
    'audit14.selection-bar-keeps-the-toolbar-colour#1 — the contextual bar is '
    'painted from ?attr/actionModeBackground, which is a different grey from '
    'the toolbar in every theme.';

void main() {
  test('light uses grey_700', () {
    expect(core.LightTheme().actionModeBackgroundColor,
        const core.Color.fromRgb(0x616161),
        reason: '$rule AppBaseTheme: @color/grey_700.');
  });

  test('dark uses grey_800', () {
    expect(core.DarkTheme().actionModeBackgroundColor,
        const core.Color.fromRgb(0x424242),
        reason: '$rule AppBaseThemeDark: @color/grey_800.');
  });

  test('pure black inherits the dark grey', () {
    expect(core.PureBlackTheme().actionModeBackgroundColor,
        const core.Color.fromRgb(0x424242),
        reason: '$rule AppBaseThemeDark.PureBlack restates neither, so it '
            'inherits grey_800 — the one bar that is not black in that theme.');
  });

  test('it differs from the toolbar in every theme', () {
    for (final theme in <core.Theme>[
      core.LightTheme(),
      core.DarkTheme(),
      core.PureBlackTheme(),
    ]) {
      expect(theme.actionModeBackgroundColor,
          isNot(theme.statusBarBackgroundColor),
          reason: '$rule Otherwise entering selection mode changes nothing '
              'about the bar, which is the whole point of the cue.');
    }
  });
}
