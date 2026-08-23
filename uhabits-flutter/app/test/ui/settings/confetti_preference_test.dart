/// The `pref_disable_animation` half of `settings.preferences.disable-animations`.
///
/// Rules #1 and #2 — the key, its default, and the settings row that writes it
/// — are asserted in test/ui/settings/settings_screen_test.dart, and #5 (only
/// a YES_MANUAL toggle asks for confetti) belongs to the presenter and is
/// asserted in the core package. What is left is the two early returns the
/// preference actually buys, both of them inside
/// `ListHabitsScreen.showConfetti(color, x, y)` — which the port keeps as the
/// pure function `buildConfettiParty`, returning null where the Kotlin returns
/// from `Unit`.
library;

// The preferences layer is not re-exported from uhabits_core.dart.
// ignore_for_file: implementation_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/list/list_habits_root_view.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  final core.Theme theme = core.LightTheme();
  final core.Color color = theme.color(11);

  Preferences preferencesWith({required bool disabled}) =>
      Preferences(MemoryStorage())..isConfettiAnimationDisabled = disabled;

  ConfettiParty? party({
    required bool disabled,
    Offset position = const Offset(120, 340),
    double animatorDurationScale = 1.0,
  }) =>
      buildConfettiParty(
        baseColor: color,
        position: position,
        preferences: preferencesWith(disabled: disabled),
        animatorDurationScale: animatorDurationScale,
      );

  group('settings.preferences.disable-animations', () {
    test('#3 with the preference on, nothing is animated', () {
      const String rule =
          'settings.preferences.disable-animations#3 — '
          'ListHabitsScreen.showConfetti(color, x, y) returns immediately '
          'without animating when preferences.isConfettiAnimationDisabled is '
          'true. The port makes the same decision in buildConfettiParty, which '
          'answers null where the Kotlin returns early — so the KonfettiView is '
          'never asked to start.';

      expect(party(disabled: true), isNull, reason: rule);

      // And the guard is the only difference: the very same call with the
      // preference off produces a burst.
      expect(party(disabled: false), isNotNull,
          reason: '$rule The preference is what suppressed it, not the '
              'position or the duration scale.');

      // The default is off, so a fresh install does animate
      // (`#1`: the confetti animation is ON by default).
      expect(
        buildConfettiParty(
          baseColor: color,
          position: const Offset(120, 340),
          preferences: Preferences(MemoryStorage()),
          animatorDurationScale: 1.0,
        ),
        isNotNull,
        reason: '$rule An untouched preference animates.',
      );
    });

    test('#4 the (0, 0) origin suppresses the burst whatever the preference '
        'says', () {
      const String rule =
          'settings.preferences.disable-animations#4 — showConfetti also '
          'returns immediately when both x == 0f and y == 0f, regardless of the '
          'preference. That origin is what the ACTION_EDIT deep link passes '
          '(ListHabitsBehavior.onEdit(habit, date, 0f, 0f)), so it is the way a '
          'caller says "no animation" without touching the setting.';

      expect(party(disabled: false, position: Offset.zero), isNull,
          reason: '$rule With the preference OFF — the interesting half, '
              'because the preference would have allowed it.');
      expect(party(disabled: true, position: Offset.zero), isNull,
          reason: '$rule …and with it on, for the same reason twice over.');

      // "both x == 0f and y == 0f": either one alone is a legitimate position
      // on the edge of the screen and still animates.
      expect(party(disabled: false, position: const Offset(0, 340)), isNotNull,
          reason: '$rule x alone is not enough.');
      expect(party(disabled: false, position: const Offset(120, 0)), isNotNull,
          reason: '$rule …nor y alone.');

      // The origin check comes first, so it holds even when the system's
      // animator scale would have allowed the burst.
      expect(
        party(
          disabled: false,
          position: Offset.zero,
          animatorDurationScale: 1.0,
        ),
        isNull,
        reason: rule,
      );
    });
  });
}
