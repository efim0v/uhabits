/// `audit3.toggling-a-check-mark-on-the#1`: every completed toggle of a
/// boolean check-mark buzzes.
///
/// Upstream `CheckmarkButtonView.performToggle()` advances the value, calls
/// `onToggle(value, notes)` and then
/// `performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)`. Flutter's
/// `HapticFeedback.vibrate()` is that exact constant: the Android embedder's
/// `PlatformPlugin` answers `HapticFeedbackType.STANDARD` — the argument-less
/// form of the `HapticFeedback.vibrate` platform message — with
/// `view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)`.
///
/// So the assertion is on the platform message, recorded off
/// `SystemChannels.platform`, and the gesture that produces it is made on the
/// habit list the app builds for itself — never on an [EntryPanel] this test
/// constructed, because a callback nothing supplies is precisely the defect.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/list/habit_card.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits_core/uhabits_core.dart';

const String rule = 'audit3.toggling-a-check-mark-on-the#1 — In the Kotlin '
    'app: Every completed toggle of a boolean check-mark buzzes with the '
    'LONG_PRESS haptic constant, which is the app\'s confirmation that a press '
    'landed on the right cell.';

const String longPressRule =
    'audit11.long-pressing-a-check-mark-or-number#1 — In the Kotlin app: '
    'CheckmarkButtonView.onLongClick and NumberButtonView.onLongClick both '
    'return true unconditionally, and View.performLongClickInternal answers a '
    'consumed long press with performHapticFeedback(HapticFeedbackConstants.'
    'LONG_PRESS) — onLongClickUseDefaultHapticFeedback defaults to true and '
    'neither view overrides it. So every long press inside the check-mark '
    'grid buzzes, whatever the listener did with it.';

const String tapRule =
    'audit11.long-pressing-a-check-mark-or-number#1 — In the Kotlin app: a '
    'short click is not haptic. View.performClick plays '
    'SoundEffectConstants.CLICK, a sound effect gated by the system '
    'touch-sounds setting, and NumberButtonView.onClick only calls onEdit(), '
    'so a numerical tap answers with no vibration at all.';

const String iosRule =
    'feedback.checkmark-haptics-are-the-ios-alert-buzz#1 — the toggle is the '
    'most frequent interaction in the app, so its confirmation has to be a '
    'tap on every platform, not a third of a second of alert vibration.';

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];
  final platformCalls = <MethodCall>[];

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_haptics');
    platformCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final database = AppDatabase.openAndMigrate('${tempDir.path}/habits.db');
    final scope = AppScope.open(database);
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  Habit addHabit(AppScope scope, String name, {HabitType type = HabitType.yesNo}) {
    final habit = scope.modelFactory.buildHabit()
      ..name = name
      ..type = type
      ..color = const PaletteColor(8);
    if (type == HabitType.numerical) {
      habit.unit = 'steps';
      habit.targetValue = 100.0;
    }
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  Future<void> pumpList(WidgetTester tester, AppScope scope) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: const HabitListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder cellOf(String habit, LocalDate date) => find.descendant(
        of: find.ancestor(
          of: find.text(habit),
          matching: find.byType(HabitCard),
        ),
        matching: find.byKey(EntryPanel.buttonKey(date)),
      );

  List<MethodCall> vibrations() => platformCalls
      .where((MethodCall c) => c.method == 'HapticFeedback.vibrate')
      .toList();

  group('audit3.toggling-a-check-mark-on-the', () {
    testWidgets('#1 a toggle on the list buzzes with LONG_PRESS',
        (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      await pumpList(tester, scope);
      final today = getToday();

      // pref_short_toggle is off by default, so the long press is the toggle.
      expect(scope.preferences.isShortToggleEnabled, isFalse);
      platformCalls.clear();
      await tester.longPress(cellOf('Meditate', today));
      await tester.pumpAndSettle();

      expect(vibrations(), hasLength(1), reason: rule);
      expect(vibrations().single.arguments, isNull,
          reason: '$rule The argument-less form of the message is '
              'HapticFeedbackType.STANDARD, which the Android embedder answers '
              'with HapticFeedbackConstants.LONG_PRESS; lightImpact, '
              'mediumImpact, heavyImpact and selectionClick all name '
              'themselves in the arguments and are other constants.');
    });

    testWidgets('on iOS the toggle taps rather than firing the alert buzz',
        (tester) async {
      // `HapticFeedback.vibrate()` is LONG_PRESS on Android and the right call
      // there, but the same message carries no feedback type, and iOS answers a
      // typeless one with AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
      // — the alert buzz that shakes the whole device, once per toggle. The
      // SDK says so itself: "On iOS devices that support haptic feedback, this
      // uses the default system vibration value (kSystemSoundID_Vibrate)".
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final scope = openScope();
      addHabit(scope, 'Meditate');
      await pumpList(tester, scope);
      final today = getToday();

      platformCalls.clear();
      await tester.longPress(cellOf('Meditate', today));
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;

      expect(vibrations(), hasLength(1), reason: iosRule);
      expect(vibrations().single.arguments, 'HapticFeedbackType.mediumImpact',
          reason: '$iosRule KEYBOARD_TAP on Android and '
              'UIImpactFeedbackStyleMedium on iOS: a tap, and still firmer '
              'than the lightImpact the port uses for VIRTUAL_KEY, so the two '
              'stay in the order Android puts them in.');
    });

    testWidgets(
        '#1 the toggle buzz follows the toggle — and the long press has its '
        'own', (tester) async {
      final scope = openScope();
      scope.preferences.isShortToggleEnabled = true;
      addHabit(scope, 'Meditate');
      await pumpList(tester, scope);
      final today = getToday();

      // With short toggle on, the *tap* toggles and the long press opens the
      // notes editor. The buzz is performToggle's, so it moves with it.
      platformCalls.clear();
      await tester.tap(cellOf('Meditate', today));
      await tester.pumpAndSettle();
      expect(vibrations(), hasLength(1), reason: rule);

      platformCalls.clear();
      await tester.longPress(cellOf('Meditate', today));
      await tester.pumpAndSettle();
      expect(vibrations(), hasLength(1),
          reason: '$longPressRule performToggle is not the only source: '
              'onLongClick returned true, so View buzzes for the long press '
              'that only opened the notes editor.');
    });

    testWidgets(
        '#1 a numerical cell has no performToggle, but its long press still '
        'buzzes', (tester) async {
      final scope = openScope();
      addHabit(scope, 'Steps', type: HabitType.numerical);
      await pumpList(tester, scope);
      final today = getToday();

      platformCalls.clear();
      await tester.longPress(cellOf('Steps', today));
      await tester.pumpAndSettle();
      expect(vibrations(), hasLength(1),
          reason: '$longPressRule NumberButtonView answers both gestures with '
              'onEdit and calls performHapticFeedback for neither — the buzz '
              'comes from the View superclass, which the listener arms by '
              'returning true.');
    });
  });

  group('audit11.long-pressing-a-check-mark-or-number', () {
    testWidgets('#1 a tap is a sound effect, not a haptic — nothing buzzes',
        (tester) async {
      final scope = openScope();
      addHabit(scope, 'Steps', type: HabitType.numerical);
      await pumpList(tester, scope);
      final today = getToday();

      platformCalls.clear();
      await tester.tap(cellOf('Steps', today));
      await tester.pumpAndSettle();

      expect(vibrations(), isEmpty, reason: tapRule);
    });

    testWidgets('#1 the long-press editor buzz is the LONG_PRESS constant',
        (tester) async {
      final scope = openScope();
      addHabit(scope, 'Steps', type: HabitType.numerical);
      await pumpList(tester, scope);
      final today = getToday();

      platformCalls.clear();
      await tester.longPress(cellOf('Steps', today));
      await tester.pumpAndSettle();

      expect(vibrations().single.arguments, isNull,
          reason: '$longPressRule The argument-less form of the message is '
              'HapticFeedbackType.STANDARD, which the Android embedder answers '
              'with HapticFeedbackConstants.LONG_PRESS — the same constant '
              'performLongClickInternal uses.');
    });

    testWidgets('#1 on iOS it taps rather than firing the alert buzz',
        (tester) async {
      // Same reasoning as the toggle: a typeless HapticFeedback.vibrate()
      // reaches iOS as kSystemSoundID_Vibrate, a third of a second of alert
      // vibration. The long press follows performToggleFeedback's shape.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final scope = openScope();
      addHabit(scope, 'Steps', type: HabitType.numerical);
      await pumpList(tester, scope);
      final today = getToday();

      platformCalls.clear();
      await tester.longPress(cellOf('Steps', today));
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;

      expect(vibrations().single.arguments, 'HapticFeedbackType.mediumImpact',
          reason: '$longPressRule $iosRule');
    });

    testWidgets('#1 the default boolean long press still buzzes exactly once',
        (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      await pumpList(tester, scope);
      final today = getToday();

      // pref_short_toggle off: the long press IS the toggle, and Android fires
      // LONG_PRESS twice there — once from performToggle and once from
      // performLongClickInternal. Two identical ticks back to back are one
      // buzz perceptually, so the port keeps the single one it already had.
      expect(scope.preferences.isShortToggleEnabled, isFalse);
      platformCalls.clear();
      await tester.longPress(cellOf('Meditate', today));
      await tester.pumpAndSettle();

      expect(vibrations(), hasLength(1),
          reason: '$longPressRule The toggle path already carries '
              "performToggle's own LONG_PRESS; arming the long press must not "
              'stack a second message on top of it.');
    });
  });
}
