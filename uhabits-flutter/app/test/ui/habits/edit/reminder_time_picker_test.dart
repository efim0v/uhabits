/// `reminders.edit-ui#4` — the radial time picker the reminder row opens.
///
/// Upstream:
///
/// ```kotlin
/// val dialog = TimePickerDialog.newInstance(
///     this, currentHour, currentMin, DateFormat.is24HourFormat(this))
/// dialog.accentColor = androidColor
/// ```
///
/// Two facts, both observable from the widget tree: the picker follows the
/// system 12/24-hour setting, and it is tinted with the habit's colour rather
/// than with the app's default accent. `DateFormat.is24HourFormat(context)` is
/// `MediaQuery.alwaysUse24HourFormat` in Flutter — the same system setting,
/// read through the same platform channel — so the test drives it by
/// overriding the `MediaQuery` above the navigator, which is where the pushed
/// editor route and its dialogs read from.
///
/// This file is deliberately separate from `edit_habit_screen_test.dart`: that
/// one belongs to the edit-habit domain and asserts the row; this one belongs
/// to the reminders domain and asserts the picker the row opens.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/theme/app_theme.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/uhabits_core.dart' hide Theme;

void main() {
  late Directory tempDir;
  final List<AppScope> scopes = <AppScope>[];
  int nextDatabase = 0;
  int nextTree = 0;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('uhabits_reminder_picker');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final path = '${tempDir.path}/habits${nextDatabase++}.db';
    final scope = AppScope.open(
      AppDatabase.openAndMigrate(path),
      databasePath: path,
      mainDispatcher: const AsyncDispatcher(),
      ioDispatcher: const AsyncDispatcher(),
    );
    scopes.add(scope);
    return scope;
  }

  Habit addHabit(AppScope scope, PaletteColor color) {
    final habit = scope.modelFactory.buildHabit()
      ..name = 'Meditate'
      ..color = color
      ..type = HabitType.yesNo
      ..frequency = Frequency.daily;
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  /// The editor on a pushed route, with the system 12/24-hour setting pinned.
  Future<void> pumpEditor(
    WidgetTester tester,
    AppScope scope, {
    int? habitId,
    required bool use24HourFormat,
  }) async {
    final Widget host = Provider<AppScope>.value(
      value: scope,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                EditHabitScreen.route(scope: scope, habitId: habitId),
              ),
              child: const Text('host'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        key: ValueKey<int>(nextTree++),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        // Above the navigator, so the pushed route and its dialogs inherit it.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(alwaysUse24HourFormat: use24HourFormat),
          child: child!,
        ),
        home: host,
      ),
    );
    await tester.tap(find.text('host'));
    await tester.pumpAndSettle();
  }

  Future<void> openTimePicker(WidgetTester tester) async {
    await tester.tap(find.byKey(EditHabitScreen.reminderTimePickerKey));
    await tester.pumpAndSettle();
  }

  group('reminders.edit-ui#4 — the reminder time picker', () {
    testWidgets('runs in 24-hour mode when the system setting says so',
        (tester) async {
      final scope = openScope();
      await pumpEditor(tester, scope, use24HourFormat: true);
      await openTimePicker(tester);

      expect(find.byType(TimePickerDialog), findsOneWidget,
          reason: 'reminders.edit-ui#4: the reminder row opens the radial time '
              'picker');
      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(TimePickerDialog)),
      );
      expect(find.text(localizations.anteMeridiemAbbreviation), findsNothing,
          reason: 'reminders.edit-ui#4: the picker uses 24-hour mode iff '
              'DateFormat.is24HourFormat(context) — with the system on 24 '
              'hours there is no AM control at all');
      expect(find.text(localizations.postMeridiemAbbreviation), findsNothing,
          reason: 'reminders.edit-ui#4: nor a PM one');
      expect(
        MediaQuery.alwaysUse24HourFormatOf(
          tester.element(find.byType(TimePickerDialog)),
        ),
        isTrue,
        reason: 'reminders.edit-ui#4: DateFormat.is24HourFormat is '
            'MediaQuery.alwaysUse24HourFormat in Flutter, and the picker reads '
            'it from the context it is shown in',
      );
    });

    testWidgets('runs in 12-hour mode when the system setting says so',
        (tester) async {
      final scope = openScope();
      await pumpEditor(tester, scope, use24HourFormat: false);
      await openTimePicker(tester);

      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(TimePickerDialog)),
      );
      expect(find.text(localizations.anteMeridiemAbbreviation), findsOneWidget,
          reason: 'reminders.edit-ui#4: with the system on 12 hours the AM/PM '
              'control is there — "iff" is a biconditional, so both halves are '
              'asserted');
      expect(find.text(localizations.postMeridiemAbbreviation), findsOneWidget,
          reason: 'reminders.edit-ui#4: and its PM half');
      expect(
        MediaQuery.alwaysUse24HourFormatOf(
          tester.element(find.byType(TimePickerDialog)),
        ),
        isFalse,
        reason: 'reminders.edit-ui#4: nothing in the app overrides the system '
            'setting on the way down to the picker',
      );
    });

    testWidgets("is tinted with the habit's colour", (tester) async {
      final scope = openScope();
      const PaletteColor habitColor = PaletteColor(11);
      final habit = addHabit(scope, habitColor);
      await pumpEditor(
        tester,
        scope,
        habitId: habit.id,
        use24HourFormat: true,
      );

      final host = tester.element(find.byType(EditHabitScreen));
      final expected = toFlutterColor(coreThemeOf(host).colorOf(habitColor));

      await openTimePicker(tester);
      final inPicker = tester.element(find.byType(TimePickerDialog));

      expect(Theme.of(inPicker).colorScheme.primary, expected,
          reason: "reminders.edit-ui#4: and is tinted with the habit's colour "
              '— upstream sets dialog.accentColor = androidColor, the habit '
              'colour resolved against the current theme');
      expect(expected, isNot(ThemeData.light().colorScheme.primary),
          reason: 'reminders.edit-ui#4: the tint really is the habit colour '
              'and not whatever the ambient theme would have used');
    });

    testWidgets('a habit with no reminder still opens a tinted picker at 08:00',
        (tester) async {
      final scope = openScope();
      const PaletteColor habitColor = PaletteColor(4);
      final habit = addHabit(scope, habitColor);
      await pumpEditor(
        tester,
        scope,
        habitId: habit.id,
        use24HourFormat: true,
      );

      final expected = toFlutterColor(
        coreThemeOf(tester.element(find.byType(EditHabitScreen)))
            .colorOf(habitColor),
      );

      await openTimePicker(tester);
      final inPicker = tester.element(find.byType(TimePickerDialog));

      expect(Theme.of(inPicker).colorScheme.primary, expected,
          reason: 'reminders.edit-ui#4: the tint does not depend on there '
              'being a reminder already — it is the habit colour either way');
      expect(find.text('08'), findsOneWidget,
          reason: 'reminders.edit-ui#4: shown on the 24-hour dial, which is '
              'what the mode flag selects');
    });
  });
}
