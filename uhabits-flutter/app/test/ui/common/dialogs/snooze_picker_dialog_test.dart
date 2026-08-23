/// Widget tests for the snooze delay picker.
///
/// The Kotlin being reproduced is
/// uhabits-android/.../notifications/SnoozeDelayPickerActivity.kt together with
/// the two parallel arrays in res/values/constants.xml (`snooze_picker_names`,
/// `snooze_picker_values`) and the `interval_*` strings they point at.
///
/// Every expectation cites the parity rule it pins, from docs/parity/FEATURES.md.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/common/dialogs/snooze_picker_dialog.dart';
import 'package:uhabits/ui/theme/app_theme.dart';
// None of these four are re-exported from uhabits_core.dart yet.
// ignore_for_file: implementation_imports
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
// Flutter's material library exports a DateUtils of its own.
import 'package:uhabits_core/src/time/date_utils.dart' as core_time;
import 'package:uhabits_core/uhabits_core.dart' as core;

/// The wall clock every test runs against: 2015-01-26 14:35 local.
final int fixedLocalTime =
    DateTime.utc(2015, 1, 26, 14, 35).millisecondsSinceEpoch;

void main() {
  setUp(() {
    core_time.DateUtils.setFixedTimeZone(const core_time.FixedTimeZone(0));
    core_time.DateUtils.setFixedLocalTime(fixedLocalTime);
  });

  tearDown(() {
    core_time.DateUtils.setFixedLocalTime(null);
    core_time.DateUtils.setFixedTimeZone(null);
  });

  group('reminders.snooze-picker-ui', () {
    testWidgets('#2 a habit that cannot be resolved opens nothing', (
      tester,
    ) async {
      final result = await _open(tester, habit: null);

      expect(
        find.byType(SnoozePickerDialog),
        findsNothing,
        reason: 'reminders.snooze-picker-ui#2: it finishes immediately when '
            'intent is null, when intent.data is null, or when no habit '
            'matches ContentUris.parseId(data)',
      );
      expect(
        result.completed,
        isTrue,
        reason: 'reminders.snooze-picker-ui#2: it finishes immediately when '
            'intent is null, when intent.data is null, or when no habit '
            'matches ContentUris.parseId(data)',
      );
      expect(
        result.value,
        isNull,
        reason: 'reminders.snooze-picker-ui#2: it finishes immediately when '
            'intent is null, when intent.data is null, or when no habit '
            'matches ContentUris.parseId(data)',
      );
    });

    testWidgets('#4 the title and the eight names, in order', (tester) async {
      await _open(tester, habit: _habit());

      expect(
        find.text('Select snooze delay'),
        findsOneWidget,
        reason: 'reminders.snooze-picker-ui#4: The dialog title is "Select '
            'snooze delay" and the items are the eight snooze names in order',
      );
      const names = <String>[
        '15 minutes',
        '30 minutes',
        '1 hour',
        '2 hours',
        '4 hours',
        '8 hours',
        '24 hours',
        'Custom...',
      ];
      for (var i = 0; i < names.length; i++) {
        expect(
          find.descendant(of: _item(i), matching: find.text(names[i])),
          findsOneWidget,
          reason: 'reminders.snooze-picker-ui#4: The dialog title is "Select '
              'snooze delay" and the items are the eight snooze names in '
              'order',
        );
      }
      for (var i = 1; i < names.length; i++) {
        expect(
          tester.getCenter(_item(i)).dy,
          greaterThan(tester.getCenter(_item(i - 1)).dy),
          reason: 'reminders.snooze-picker-ui#4: the items are the eight '
              'snooze names in order',
        );
      }
    });

    testWidgets('#14 the names come from the localized strings', (
      tester,
    ) async {
      await _open(
        tester,
        habit: _habit(),
        locale: const Locale('es'),
      );

      expect(
        find.text('Seleccione el retardo de la interrupción'),
        findsOneWidget,
        reason: 'reminders.snooze-picker-ui#14: The snooze_picker_names array '
            'is localizable (it references @string/interval_* entries)',
      );
      expect(
        find.descendant(of: _item(0), matching: find.text('15 minutos')),
        findsOneWidget,
        reason: 'reminders.snooze-picker-ui#14: The snooze_picker_names array '
            'is localizable (it references @string/interval_* entries)',
      );
      expect(
        find.descendant(of: _item(7), matching: find.text('Personalizar...')),
        findsOneWidget,
        reason: 'reminders.snooze-picker-ui#14: The snooze_picker_names array '
            'is localizable (it references @string/interval_* entries)',
      );
    });

    test('#11 #14 the parallel values are fixed and untranslated', () {
      expect(
        SnoozePickerDialog.values,
        <int>[15, 30, 60, 120, 240, 480, 1440, -1],
        reason: 'reminders.snooze-picker-ui#11: The parallel '
            'R.array.snooze_picker_values are exactly '
            '[15, 30, 60, 120, 240, 480, 1440, -1] (minutes; -1 is the '
            'sentinel for "custom")',
      );
      expect(
        SnoozePickerDialog.customValue,
        -1,
        reason: 'reminders.snooze-picker-ui#11: -1 is the sentinel for '
            '"custom"',
      );
      expect(
        SnoozePickerDialog.values.length,
        8,
        reason: 'reminders.snooze-picker-ui#14: snooze_picker_values is marked '
            'translatable="false"',
      );
    });

    testWidgets('#5 tapping a delay reports its minutes and closes', (
      tester,
    ) async {
      for (var i = 0; i < 7; i++) {
        final result = await _open(tester, habit: _habit());
        await tester.tap(_item(i));
        await tester.pumpAndSettle();

        expect(
          result.value,
          isA<SnoozeDelay>().having(
            (choice) => choice.minutes,
            'minutes',
            SnoozePickerDialog.values[i],
          ),
          reason: 'reminders.snooze-picker-ui#5: Tapping an item whose value '
              'is >= 0 calls ReminderController.onSnoozeDelayPicked(habit, '
              'value) and finishes the activity',
        );
        expect(
          find.byType(SnoozePickerDialog),
          findsNothing,
          reason: 'reminders.snooze-picker-ui#5: Tapping an item whose value '
              'is >= 0 calls ReminderController.onSnoozeDelayPicked(habit, '
              'value) and finishes the activity',
        );
      }
    });

    testWidgets('#12 the reported delay is what snoozeReminder consumes', (
      tester,
    ) async {
      // The second half of the rule — notificationTray.cancel(habit) — lives in
      // ReminderController, which is not part of this slice; what the picker
      // owes it is the minutes value, and this checks that value drives
      // ReminderScheduler.snoozeReminder correctly.
      final storage = MemoryStorage();
      final widgetPreferences = WidgetPreferences(storage);
      final habitList = core.MemoryHabitList();
      final habit = _habit()
        ..id = 10
        ..reminder = core.Reminder(8, 30, core.WeekdayList.everyDay);
      habitList.add(habit);
      final scheduler = ReminderScheduler(
        CommandRunner(
          CoroutineTaskRunner(
            mainDispatcher: const UnconfinedTestDispatcher(),
            ioDispatcher: const UnconfinedTestDispatcher(),
          ),
        ),
        habitList,
        _SilentScheduler(),
        widgetPreferences,
      );

      final result = await _open(tester, habit: habit);
      // "2 hours".
      await tester.tap(_item(3));
      await tester.pumpAndSettle();

      final choice = result.value;
      expect(
        choice,
        isA<SnoozeDelay>().having((it) => it.minutes, 'minutes', 120),
        reason: 'reminders.snooze-picker-ui#12: Selecting an item whose value '
            '>= 0 calls reminderController.onSnoozeDelayPicked(habit, minutes) '
            'and finishes',
      );
      scheduler.snoozeReminder(habit, (choice! as SnoozeDelay).minutes);
      expect(
        widgetPreferences.getSnoozeTime(10),
        core_time.DateUtils.applyTimezone(fixedLocalTime) + 120 * 60 * 1000,
        reason: 'reminders.snooze-picker-ui#12: onSnoozeDelayPicked calls '
            'reminderScheduler.snoozeReminder(habit, minutes) and '
            'notificationTray.cancel(habit)',
      );
    });

    test('#6 the time picker opens on the current wall-clock time', () {
      expect(
        SnoozePickerDialog.initialTime(),
        const TimeOfDay(hour: 14, minute: 35),
        reason: 'reminders.snooze-picker-ui#6: opens a radial TimePickerDialog '
            'pre-set to the current Calendar HOUR_OF_DAY and MINUTE',
      );
      expect(
        SnoozePickerDialog.initialTime(
          DateTime.utc(2015, 1, 26, 0, 7).millisecondsSinceEpoch,
        ),
        const TimeOfDay(hour: 0, minute: 7),
        reason: 'reminders.snooze-picker-ui#6: opens a radial TimePickerDialog '
            'pre-set to the current Calendar HOUR_OF_DAY and MINUTE',
      );
    });

    testWidgets('#6 "Custom..." opens a radial picker over the list', (
      tester,
    ) async {
      await _open(tester, habit: _habit());
      await tester.tap(_item(7));
      await tester.pumpAndSettle();

      expect(
        find.byType(TimePickerDialog),
        findsOneWidget,
        reason: 'reminders.snooze-picker-ui#6: Tapping the item whose value is '
            '< 0 ("Custom...") opens a radial TimePickerDialog',
      );
      expect(
        find.byType(SnoozePickerDialog),
        findsOneWidget,
        reason: 'reminders.snooze-picker-ui#6: the item click listener neither '
            'dismisses the list nor finishes the activity — only picking a '
            'time does',
      );
    });

    testWidgets('#6 24-hour mode follows the platform setting', (tester) async {
      await _open(tester, habit: _habit(), use24HourFormat: false);
      await tester.tap(_item(7));
      await tester.pumpAndSettle();
      expect(
        find.text('AM'),
        findsOneWidget,
        reason: 'reminders.snooze-picker-ui#6: using 24-hour mode iff '
            'DateFormat.is24HourFormat(context)',
      );

      await _open(tester, habit: _habit(), use24HourFormat: true);
      await tester.tap(_item(7));
      await tester.pumpAndSettle();
      expect(
        find.text('AM'),
        findsNothing,
        reason: 'reminders.snooze-picker-ui#6: using 24-hour mode iff '
            'DateFormat.is24HourFormat(context)',
      );
    });

    testWidgets('#3 #6 the picker is tinted with the habit theme colour', (
      tester,
    ) async {
      await _open(tester, habit: _habit(const core.PaletteColor(5)));
      await tester.tap(_item(7));
      await tester.pumpAndSettle();
      expect(
        _tint(tester),
        toFlutterColor(core.LightTheme().color(5)),
        reason: 'reminders.snooze-picker-ui#6: tinted with the habit\'s theme '
            'colour',
      );

      await _open(
        tester,
        habit: _habit(const core.PaletteColor(5)),
        theme: appThemeData(core.DarkTheme()),
      );
      await tester.tap(_item(7));
      await tester.pumpAndSettle();
      expect(
        _tint(tester),
        toFlutterColor(core.DarkTheme().color(5)),
        reason: 'reminders.snooze-picker-ui#3: night mode uses '
            'R.style.BaseDialogDark with DarkTheme, otherwise R.style.BaseDialog '
            'with LightTheme',
      );
      expect(
        core.DarkTheme().color(5),
        isNot(core.LightTheme().color(5)),
        reason: 'reminders.snooze-picker-ui#3: night mode uses '
            'R.style.BaseDialogDark with DarkTheme, otherwise R.style.BaseDialog '
            'with LightTheme',
      );
    });

    testWidgets('#6 picking a time reports it and closes both dialogs', (
      tester,
    ) async {
      final result = await _open(tester, habit: _habit());
      await tester.tap(_item(7));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        result.value,
        isA<SnoozeUntilTime>()
            .having((it) => it.hour, 'hour', 14)
            .having((it) => it.minute, 'minute', 35),
        reason: 'reminders.snooze-picker-ui#6: Picking a time calls '
            'onSnoozeTimePicked(habit, hour, minute) and finishes',
      );
      expect(
        find.byType(TimePickerDialog),
        findsNothing,
        reason: 'reminders.snooze-picker-ui#6: Picking a time calls '
            'onSnoozeTimePicked(habit, hour, minute) and finishes',
      );
      expect(
        find.byType(SnoozePickerDialog),
        findsNothing,
        reason: 'reminders.snooze-picker-ui#6: Picking a time calls '
            'onSnoozeTimePicked(habit, hour, minute) and finishes',
      );
    });

    testWidgets('#6 cancelling the time picker leaves the list up', (
      tester,
    ) async {
      final result = await _open(tester, habit: _habit());
      await tester.tap(_item(7));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        find.byType(TimePickerDialog),
        findsNothing,
        reason: 'reminders.snooze-picker-ui#6: Picking a time calls '
            'onSnoozeTimePicked(habit, hour, minute) and finishes',
      );
      expect(
        find.byType(SnoozePickerDialog),
        findsOneWidget,
        reason: 'reminders.snooze-picker-ui#6: only picking a time finishes; '
            'the snooze list is still up',
      );
      expect(
        result.completed,
        isFalse,
        reason: 'reminders.snooze-picker-ui#7: Dismissing the dialog (back '
            'press / outside tap) finishes the activity',
      );
    });

    testWidgets('#7 dismissing the list reports nothing', (tester) async {
      final result = await _open(tester, habit: _habit());

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(
        find.byType(SnoozePickerDialog),
        findsNothing,
        reason: 'reminders.snooze-picker-ui#7: Dismissing the dialog (back '
            'press / outside tap) finishes the activity',
      );
      expect(
        result.completed,
        isTrue,
        reason: 'reminders.snooze-picker-ui#7: Dismissing the dialog (back '
            'press / outside tap) finishes the activity',
      );
      expect(
        result.value,
        isNull,
        reason: 'reminders.snooze-picker-ui#7: Dismissing the dialog (back '
            'press / outside tap) finishes the activity',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Where the awaited value of the dialog lands.
class _Result {
  SnoozeChoice? value;

  /// True once the future returned by the show function completed, which is
  /// the Flutter stand-in for the Android `onDismiss()` callback.
  bool completed = false;
}

core.Habit _habit([core.PaletteColor color = const core.PaletteColor(5)]) =>
    core.MemoryModelFactory().buildHabit()..color = color;

Finder _item(int index) => find.byKey(ValueKey<String>('snooze_item_$index'));

Color _tint(WidgetTester tester) => tester
    .widget<Theme>(find.byKey(SnoozePickerDialog.timePickerThemeKey))
    .data
    .colorScheme
    .primary;

/// Pumps a one-button app, taps the button and lets the picker open.
Future<_Result> _open(
  WidgetTester tester, {
  required core.Habit? habit,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  bool use24HourFormat = true,
}) async {
  final result = _Result();
  await tester.pumpWidget(
    MaterialApp(
      // A fresh key per call, so that re-opening inside one test starts from
      // an empty navigator instead of inheriting the previous routes.
      key: UniqueKey(),
      locale: locale,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(alwaysUse24HourFormat: use24HourFormat),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result.value = await showSnoozePickerDialog(
                  context,
                  habit: habit,
                );
                result.completed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

/// A [SystemScheduler] that records nothing: the alarm plumbing belongs to the
/// scheduling slices, and this test only needs the snooze bookkeeping.
class _SilentScheduler implements SystemScheduler {
  @override
  SchedulerResult scheduleShowReminder(
    int reminderTime,
    core.Habit habit,
    int timestamp,
  ) => SchedulerResult.ok;

  @override
  SchedulerResult? scheduleWidgetUpdate(int updateTime) => SchedulerResult.ok;

  @override
  void log(String componentName, String msg) {}
}
