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
import 'package:uhabits/l10n/app_localizations_en.dart';
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
      expect(
        result.completed,
        isTrue,
        reason: 'platform-glue.habit-content-uri#7 — SnoozeDelayPickerActivity '
            'finishes immediately if intent.data is null, and finishes if the '
            'habit id does not resolve. There is no Activity and no data URI '
            'here: the picker is handed the habit the notification named, and '
            '"the id did not resolve" arrives as a null habit — which it '
            'answers the same way, by closing with no result rather than '
            'showing an empty list.',
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

    test('platform-glue.localized-arrays#1 — the eight names stay '
        'index-aligned with the eight values', () {
      final names = SnoozePickerDialog.names(L10nEn());

      expect(
        names,
        <String>[
          '15 minutes',
          '30 minutes',
          '1 hour',
          '2 hours',
          '4 hours',
          '8 hours',
          '24 hours',
          'Custom...',
        ],
        reason: 'platform-glue.localized-arrays#1 — snooze_picker_names has 8 '
            'entries in this order and must stay index-aligned with the integer '
            'array snooze_picker_values [15, 30, 60, 120, 240, 480, 1440, -1]: '
            'interval_15_minutes, interval_30_minutes, interval_1_hour, '
            'interval_2_hour, interval_4_hour, interval_8_hour, '
            'interval_24_hour, interval_custom.',
      );
      expect(names.length, SnoozePickerDialog.values.length,
          reason: 'platform-glue.localized-arrays#1: index-aligned');

      // The alignment is the contract: entry i names value i, and the last
      // pair is the custom sentinel.
      final l10n = L10nEn();
      expect(
        <String>[
          l10n.interval15Minutes,
          l10n.interval30Minutes,
          l10n.interval1Hour,
          l10n.interval2Hour,
          l10n.interval4Hour,
          l10n.interval8Hour,
          l10n.interval24Hour,
          l10n.intervalCustom,
        ],
        names,
        reason: 'platform-glue.localized-arrays#1: in the order the array '
            'declares them',
      );
      expect(names.last, l10n.intervalCustom,
          reason: 'platform-glue.localized-arrays#1: interval_custom is the '
              'eighth name');
      expect(SnoozePickerDialog.values.last, SnoozePickerDialog.customValue,
          reason: 'platform-glue.localized-arrays#1: paired with -1');
    });

    test('platform-glue.localized-arrays#7 — "Always ask" exists but is not '
        'one of the eight', () {
      final l10n = L10nEn();

      expect(l10n.intervalAlwaysAsk, 'Always ask',
          reason: 'platform-glue.localized-arrays#7 — interval_always_ask '
              '("Always ask") is defined but is not referenced by the '
              'snooze_picker_names array.');
      expect(SnoozePickerDialog.names(l10n), isNot(contains('Always ask')),
          reason: 'platform-glue.localized-arrays#7: and the picker never '
              'offers it');
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

  // -------------------------------------------------------------------
  // reminders.snooze-by-delay — the menu of delays the picker offers
  // -------------------------------------------------------------------

  group('reminders.snooze-by-delay', () {
    test('#4 the available delays, plus the "Custom..." sentinel', () {
      expect(
        SnoozePickerDialog.values.take(7),
        <int>[15, 30, 60, 120, 240, 480, 1440],
        reason: 'reminders.snooze-by-delay#4: Available delays in minutes are '
            'exactly: 15, 30, 60, 120, 240, 480, 1440, plus the sentinel -1 '
            'meaning "Custom..."',
      );
      expect(
        SnoozePickerDialog.values.last,
        -1,
        reason: 'reminders.snooze-by-delay#4: plus the sentinel -1 meaning '
            '"Custom..."',
      );
      expect(
        SnoozePickerDialog.values.where((minutes) => minutes < 0).length,
        1,
        reason: 'reminders.snooze-by-delay#4: -1 is the only sentinel; every '
            'other entry is a real number of minutes',
      );
    });

    testWidgets('#5 the labels, in order', (tester) async {
      await _open(tester, habit: _habit());

      const List<String> labels = <String>[
        '15 minutes',
        '30 minutes',
        '1 hour',
        '2 hours',
        '4 hours',
        '8 hours',
        '24 hours',
        'Custom...',
      ];
      for (var i = 0; i < labels.length; i++) {
        expect(
          find.descendant(of: _item(i), matching: find.text(labels[i])),
          findsOneWidget,
          reason: 'reminders.snooze-by-delay#5: Delay labels in order are: '
              '"15 minutes", "30 minutes", "1 hour", "2 hours", "4 hours", '
              '"8 hours", "24 hours", "Custom..."',
        );
      }
      expect(
        SnoozePickerDialog.names(L10nEn()),
        labels,
        reason: 'reminders.snooze-by-delay#5: the label at position i is the '
            'one that carries the delay at position i',
      );
    });

    testWidgets('#5 each label answers with the delay next to it in #4', (
      tester,
    ) async {
      const List<int> minutes = <int>[15, 30, 60, 120, 240, 480, 1440];
      for (var i = 0; i < minutes.length; i++) {
        final result = await _open(tester, habit: _habit());
        await tester.tap(_item(i));
        await tester.pumpAndSettle();

        expect(
          result.value,
          isA<SnoozeDelay>()
              .having((choice) => choice.minutes, 'minutes', minutes[i]),
          reason: 'reminders.snooze-by-delay#5: the two arrays are parallel, '
              'so "${SnoozePickerDialog.names(L10nEn())[i]}" is exactly '
              '${minutes[i]} minutes',
        );
      }
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
