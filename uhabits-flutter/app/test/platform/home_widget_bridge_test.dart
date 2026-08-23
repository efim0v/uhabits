// The classes under test reach the core by its `src` path, exactly as
// lib/state/app_scope.dart does.
// ignore_for_file: implementation_imports

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits/state/widget_sync.dart';
import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';
import 'package:uhabits_core/src/utils/midnight_timer.dart';

/// The widget data bridge: the Flutter replacement for `WidgetUpdater`,
/// `BaseWidgetProvider` and the `ACTION_UPDATE_WIDGETS_VALUE` rollover alarm.
///
/// A native home-screen widget cannot run Dart, so nothing here draws anything.
/// What the port reproduces is the *decision* half of `WidgetUpdater` — which
/// widgets a finished command touches, in which order the six providers are
/// refreshed, and when the day rolls over — plus a versioned JSON data contract
/// that the native widget code reads out of shared storage.
///
/// `WidgetBehavior` (the core logic behind a widget tap) has no Dart port in
/// `uhabits_core` yet, so it is ported here alongside the bridge that carries
/// its result back to the launcher; the Kotlin `WidgetBehaviorTest` is mirrored
/// one test at a time below.
void main() {
  // -----------------------------------------------------------------------
  // Fixtures
  // -----------------------------------------------------------------------

  const TimeZone gmt = FixedTimeZone(0);

  late MemoryModelFactory modelFactory;
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late RecordingStorage storage;
  late Preferences preferences;
  late WidgetRegistry registry;
  late FakeHomeWidgetPlatform platform;
  late HomeWidgetBridge bridge;
  late Logging logging;

  final int Function() realClock = systemCurrentTimeMillis;
  final TimeZone Function() realZone = getDefaultTimeZone;

  setUp(() {
    DateUtils.setFixedTimeZone(gmt);
    DateUtils.setFixedLocalTime(null);
    systemCurrentTimeMillis = realClock;
    // `computeToday` reads the top-level `getDefaultTimeZone`, not
    // `DateUtils.fixedTimeZone`, so the midnight rollover needs this one too.
    getDefaultTimeZone = () => gmt;
    setToday(LocalDate.ymd(2015, 1, 26));
    modelFactory = MemoryModelFactory();
    habitList = MemoryHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    storage = RecordingStorage();
    preferences = Preferences(storage);
    registry = WidgetRegistry(storage);
    platform = FakeHomeWidgetPlatform();
    bridge = HomeWidgetBridge(
      habitList: habitList,
      registry: registry,
      platform: platform,
    );
    logging = StandardLogging(out: StringBuffer(), err: StringBuffer());
  });

  tearDown(() {
    DateUtils.setFixedTimeZone(null);
    DateUtils.setFixedLocalTime(null);
    systemCurrentTimeMillis = realClock;
    getDefaultTimeZone = realZone;
  });

  Habit addHabit({
    String name = 'Meditate',
    PaletteColor color = const PaletteColor(3),
  }) {
    final habit = fixtures.createEmptyHabit(name: name, color: color);
    habitList.add(habit);
    return habit;
  }

  Map<String, Object?> decode(String? json) =>
      jsonDecode(json!) as Map<String, Object?>;

  // =======================================================================
  // settings.widget-preferences.habit-ids
  // =======================================================================

  group('settings.widget-preferences.habit-ids', () {
    test('the habit-id key is the widget id zero-padded to six digits', () {
      final prefs = WidgetPreferences(storage);
      prefs.addWidget(42, <int>[7]);

      expect(
        storage.keys,
        contains('widget-000042-habit'),
        reason: 'settings.widget-preferences.habit-ids#1 — The storage key for '
            "a widget's habit list is format(\"widget-%06d-habit\", widgetId), "
            'i.e. the widget id zero-padded to at least 6 digits, e.g. widget '
            'id 42 -> "widget-000042-habit".',
      );
      expect(
        storage.keys.where((String k) => k != 'widget-000042-habit'),
        isEmpty,
        reason: 'settings.widget-preferences.habit-ids#9 — Widget preferences '
            'survive app restarts and are the only per-widget configuration — '
            'there are no other per-widget settings (no per-widget colour, '
            'size or opacity).',
      );
    });

    test('addWidget serialises the ids as a comma-separated decimal string',
        () {
      final prefs = WidgetPreferences(storage);
      prefs.addWidget(3, <int>[10, 2, 5]);

      expect(
        storage.getString('widget-000003-habit', ''),
        '10,2,5',
        reason: 'settings.widget-preferences.habit-ids#2 — addWidget(widgetId, '
            'habitIds) writes storage.putLongArray(key, habitIds), which '
            'serialises the ids as a comma-separated decimal string.',
      );
      expect(
        prefs.getHabitIdsFromWidgetId(3),
        <int>[10, 2, 5],
        reason: 'settings.widget-preferences.habit-ids#6 — WidgetPreferences is '
            'an app-scoped class wrapping Preferences.Storage.',
      );
    });

    test('a widget stored with no habits reads back as an empty array', () {
      final prefs = WidgetPreferences(storage);
      prefs.addWidget(9, <int>[]);

      expect(
        storage.getString('widget-000009-habit', 'MISSING'),
        '',
        reason: 'settings.widget-preferences.habit-ids#5 — Because '
            'putLongArray serialises an empty array to the empty string and '
            'getLongArray returns the supplied default for an empty string, a '
            'widget stored with no habits reads back as an empty LongArray.',
      );
      expect(
        prefs.getHabitIdsFromWidgetId(9),
        isEmpty,
        reason: 'settings.widget-preferences.habit-ids#5 — Because '
            'putLongArray serialises an empty array to the empty string and '
            'getLongArray returns the supplied default for an empty string, a '
            'widget stored with no habits reads back as an empty LongArray.',
      );
    });

    test('removeWidget deletes the key entirely', () {
      final prefs = WidgetPreferences(storage);
      prefs.addWidget(42, <int>[7]);
      prefs.removeWidget(42);

      expect(
        storage.keys,
        isNot(contains('widget-000042-habit')),
        reason: 'settings.widget-preferences.habit-ids#4 — removeWidget(id) '
            'calls storage.remove(key) for the same formatted key.',
      );
      expect(
        prefs.getHabitIdsFromWidgetId(42),
        isEmpty,
        reason: 'settings.widget-preferences.habit-ids#7 — removeWidget(id) '
            'deletes the key entirely; this is invoked from BaseWidget.delete() '
            'when the launcher reports the widget was removed.',
      );
    });

    test('a legacy single-long value falls back to getLong', () {
      // Up to Loop 1.7.11 the key held a single Long, so reading it as a
      // string threw ClassCastException on Android. A Dart PreferencesStorage
      // over typed values throws a TypeError in the same situation.
      final legacy = LegacyLongStorage(<String, int>{'widget-000042-habit': 12});
      final prefs = WidgetPreferences(legacy);

      expect(
        prefs.getHabitIdsFromWidgetId(42),
        <int>[12],
        reason: 'settings.widget-preferences.habit-ids#3 — '
            'getHabitIdsFromWidgetId(widgetId) first tries '
            'storage.getLongArray(key, longArrayOf()); if that throws '
            'ClassCastException (legacy data from Loop <= 1.7.11 where the key '
            'held a single Long) it falls back to storage.getLong(key, -1) and '
            'returns an empty LongArray when the result is -1L, or a '
            'single-element array otherwise.',
      );

      final missing = LegacyLongStorage(<String, int>{});
      expect(
        WidgetPreferences(missing).getHabitIdsFromWidgetId(42),
        isEmpty,
        reason: 'settings.widget-preferences.habit-ids#3 — '
            'getHabitIdsFromWidgetId(widgetId) first tries '
            'storage.getLongArray(key, longArrayOf()); if that throws '
            'ClassCastException (legacy data from Loop <= 1.7.11 where the key '
            'held a single Long) it falls back to storage.getLong(key, -1) and '
            'returns an empty LongArray when the result is -1L, or a '
            'single-element array otherwise.',
      );
    });

    test('snooze times live in the same class under snooze-%06d', () {
      final prefs = WidgetPreferences(storage);

      expect(
        prefs.getSnoozeTime(42),
        0,
        reason: 'settings.widget-preferences.habit-ids#8 — Snooze times are '
            'stored in the same class under key format("snooze-%06d", '
            'id.toInt()) where id is a habit id: getSnoozeTime(habitId) '
            'defaults to 0, setSnoozeTime(id, time) writes the value, and '
            'removeSnoozeTime(id) writes 0 rather than deleting the key.',
      );

      prefs.setSnoozeTime(42, 1234);
      expect(
        storage.getLong('snooze-000042', -1),
        1234,
        reason: 'settings.widget-preferences.habit-ids#8 — Snooze times are '
            'stored in the same class under key format("snooze-%06d", '
            'id.toInt()) where id is a habit id: getSnoozeTime(habitId) '
            'defaults to 0, setSnoozeTime(id, time) writes the value, and '
            'removeSnoozeTime(id) writes 0 rather than deleting the key.',
      );

      prefs.removeSnoozeTime(42);
      expect(
        storage.keys,
        contains('snooze-000042'),
        reason: 'settings.widget-preferences.habit-ids#8 — ... '
            'removeSnoozeTime(id) writes 0 rather than deleting the key.',
      );
      expect(
        prefs.getSnoozeTime(42),
        0,
        reason: 'settings.widget-preferences.habit-ids#8 — ... '
            'removeSnoozeTime(id) writes 0 rather than deleting the key.',
      );
    });

    test('the registry stores the ids through WidgetPreferences', () {
      registry.addWidget(42, <int>[7, 9]);

      expect(
        storage.getString('widget-000042-habit', ''),
        '7,9',
        reason: 'settings.widget-preferences.habit-ids#1 — The storage key for '
            "a widget's habit list is format(\"widget-%06d-habit\", widgetId), "
            'i.e. the widget id zero-padded to at least 6 digits, e.g. widget '
            'id 42 -> "widget-000042-habit".',
      );
      expect(
        registry.habitIdsOf(42),
        <int>[7, 9],
        reason: 'settings.widget-preferences.habit-ids#6 — WidgetPreferences is '
            'an app-scoped class wrapping Preferences.Storage.',
      );
      expect(
        registry.widgetIds,
        <int>[42],
        reason: 'widgets.updater#4 — For each provider it fetches '
            'AppWidgetManager.getAppWidgetIds(ComponentName(context, '
            'providerClass)); when modifiedHabitId is null it uses all of them, '
            'otherwise it keeps only the ids whose stored habit id array '
            'contains that habit id.',
      );

      registry.removeWidget(42);
      expect(
        registry.widgetIds,
        isEmpty,
        reason: 'settings.widget-preferences.habit-ids#7 — removeWidget(id) '
            'deletes the key entirely; this is invoked from BaseWidget.delete() '
            'when the launcher reports the widget was removed.',
      );
      expect(
        storage.keys,
        isNot(contains('widget-000042-habit')),
        reason: 'settings.widget-preferences.habit-ids#4 — removeWidget(id) '
            'calls storage.remove(key) for the same formatted key.',
      );
    });
  });

  // =======================================================================
  // The published data contract
  // =======================================================================

  group('home widget data contract', () {
    test('each widget gets one versioned JSON document plus one index', () async {
      final a = addHabit(name: 'Meditate', color: const PaletteColor(3));
      final b = addHabit(name: 'Run', color: const PaletteColor(11));
      registry.addWidget(1, <int>[a.id!]);
      registry.addWidget(2, <int>[a.id!, b.id!]);

      await bridge.publish();

      expect(
        platform.data.keys,
        containsAll(<String>[
          HomeWidgetBridge.indexKey,
          HomeWidgetBridge.documentKey(1),
          HomeWidgetBridge.documentKey(2),
        ]),
        reason: 'widgets.updater#4 — For each provider it fetches '
            'AppWidgetManager.getAppWidgetIds(ComponentName(context, '
            'providerClass)); when modifiedHabitId is null it uses all of them, '
            'otherwise it keeps only the ids whose stored habit id array '
            'contains that habit id.',
      );

      final index = decode(platform.data[HomeWidgetBridge.indexKey]);
      expect(index['version'], HomeWidgetBridge.schemaVersion);
      expect(index['widgets'], <Object?>[
        <String, Object?>{
          'id': 1,
          'key': HomeWidgetBridge.documentKey(1),
          'habits': <int>[a.id!],
        },
        <String, Object?>{
          'id': 2,
          'key': HomeWidgetBridge.documentKey(2),
          'habits': <int>[a.id!, b.id!],
        },
      ]);
      expect(index['today'], '2015-01-26');
      expect(index['providers'], HomeWidgetBridge.providerNames);

      final doc = decode(platform.data[HomeWidgetBridge.documentKey(2)]);
      expect(doc['version'], HomeWidgetBridge.schemaVersion);
      expect(doc['widgetId'], 2);
      final habits = doc['habits']! as List<Object?>;
      expect(habits.length, 2);
      expect((habits[1]! as Map<String, Object?>)['name'], 'Run');
      expect((habits[1]! as Map<String, Object?>)['color'], 11);
    });

    test('a habit document carries id, name, colour, value, target and 60 '
        'entries', () async {
      final habit = fixtures.createEmptyNumericalHabit(
        NumericalHabitType.atLeast,
      );
      habitList.add(habit);
      final today = getToday();
      habit.originalEntries.add(Entry(today, 500));
      habit.originalEntries.add(Entry(today.minus(1), 1500));
      habit.originalEntries.add(Entry(today.minus(59), 7000));
      habit.originalEntries.add(Entry(today.minus(60), 9000));
      habit.recompute();
      registry.addWidget(7, <int>[habit.id!]);

      await bridge.publish();
      final doc = decode(platform.data[HomeWidgetBridge.documentKey(7)]);
      final json = (doc['habits']! as List<Object?>).single!
          as Map<String, Object?>;

      expect(json['id'], habit.id);
      expect(json['name'], 'Run');
      expect(json['color'], 1);
      expect(json['type'], 'NUMERICAL');
      expect(json['unit'], 'miles');
      expect(json['target'], 2.0);
      expect(json['targetType'], 'AT_LEAST');
      expect(json['value'], 500);

      final entries = (json['entries']! as List<Object?>).cast<int>();
      expect(entries.length, HomeWidgetBridge.entryCount);
      expect(entries.first, 500);
      expect(entries[1], 1500);
      expect(entries.last, 7000,
          reason: 'the window is the last sixty days ending today, newest '
              'first, so index 59 is today minus 59 and the entry on day '
              'minus 60 falls outside it');
    });

    test('habit ids the list no longer holds are reported, not dropped '
        'silently', () async {
      final habit = addHabit();
      registry.addWidget(4, <int>[habit.id!, 9999]);

      await bridge.publish();
      final doc = decode(platform.data[HomeWidgetBridge.documentKey(4)]);

      expect((doc['habits']! as List<Object?>).length, 1);
      expect(doc['missingHabitIds'], <int>[9999]);
    });

    test('documents of widgets the launcher removed are cleared', () async {
      final habit = addHabit();
      registry.addWidget(1, <int>[habit.id!]);
      await bridge.publish();
      expect(platform.data[HomeWidgetBridge.documentKey(1)], isNotNull);

      registry.removeWidget(1);
      await bridge.publish();

      expect(
        platform.data[HomeWidgetBridge.documentKey(1)],
        isNull,
        reason: 'settings.widget-preferences.habit-ids#7 — removeWidget(id) '
            'deletes the key entirely; this is invoked from BaseWidget.delete() '
            'when the launcher reports the widget was removed.',
      );
    });
  });

  // =======================================================================
  // widgets.updater
  // =======================================================================

  group('widgets.updater', () {
    late CommandRunner commandRunner;
    late TaskRunner taskRunner;
    late MidnightTimer midnightTimer;
    late WidgetSync sync;
    late Habit alpha;
    late Habit beta;

    setUp(() {
      taskRunner = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      commandRunner = CommandRunner(taskRunner);
      midnightTimer = MidnightTimer(logging, preferences);
      sync = WidgetSync(
        bridge: bridge,
        commandRunner: commandRunner,
        taskRunner: taskRunner,
        midnightTimer: midnightTimer,
        preferences: preferences,
      );
      alpha = addHabit(name: 'Alpha');
      beta = addHabit(name: 'Beta');
      registry.addWidget(1, <int>[alpha.id!]);
      registry.addWidget(2, <int>[beta.id!]);
      registry.addWidget(3, <int>[alpha.id!, beta.id!]);
    });

    CreateRepetitionCommand repetition(Habit habit) =>
        CreateRepetitionCommand(habitList, habit, getToday(), Entry.yesManual, '');

    test('a CreateRepetitionCommand updates only the widgets bound to its '
        'habit', () async {
      sync.startListening();
      commandRunner.notifyListeners(repetition(alpha));
      await sync.settle();

      expect(
        platform.savedDocumentIds,
        <int>[1, 3],
        reason: 'widgets.updater#1 — WidgetUpdater implements '
            'CommandRunner.Listener; onCommandFinished(command) updates only '
            'the widgets bound to command.habit.id when the command is a '
            'CreateRepetitionCommand, and updates ALL widgets for any other '
            'command type.',
      );
      expect(
        platform.savedDocumentIds,
        <int>[1, 3],
        reason: 'widgets.updater#12 — `onCommandFinished(command)`: if '
            '`command is CreateRepetitionCommand` it calls '
            '`updateWidgets(command.habit.id)`; for every other command type '
            'it calls `updateWidgets()`, which is `updateWidgets(null)`.',
      );
      expect(
        platform.savedDocumentIds,
        <int>[1, 3],
        reason: 'widgets.updater#4 — For each provider it fetches '
            'AppWidgetManager.getAppWidgetIds(ComponentName(context, '
            'providerClass)); when modifiedHabitId is null it uses all of them, '
            'otherwise it keeps only the ids whose stored habit id array '
            'contains that habit id.',
      );
    });

    test('any other command type updates all widgets', () async {
      sync.startListening();
      commandRunner
          .notifyListeners(ArchiveHabitsCommand(habitList, <Habit>[alpha]));
      await sync.settle();

      expect(
        platform.savedDocumentIds,
        <int>[1, 2, 3],
        reason: 'widgets.updater#1 — WidgetUpdater implements '
            'CommandRunner.Listener; onCommandFinished(command) updates only '
            'the widgets bound to command.habit.id when the command is a '
            'CreateRepetitionCommand, and updates ALL widgets for any other '
            'command type.',
      );
    });

    test('a CreateRepetitionCommand whose habit id is null updates ALL widgets',
        () async {
      final orphan = fixtures.createEmptyHabit(name: 'Orphan');
      orphan.id = null;
      sync.startListening();
      commandRunner.notifyListeners(repetition(orphan));
      await sync.settle();

      expect(
        platform.savedDocumentIds,
        <int>[1, 2, 3],
        reason: 'widgets.updater#13 — A CreateRepetitionCommand whose habit.id '
            'is null passes null and therefore updates ALL widgets (the `?` '
            'differs from HabitCardListCache, which skips entirely in that '
            'case).',
      );
    });

    test('updateWidgets() with no argument refreshes everything', () async {
      await sync.updateWidgets();

      expect(
        platform.savedDocumentIds,
        <int>[1, 2, 3],
        reason: 'widgets.updater#6 — updateWidgets() with no argument is '
            'shorthand for updateWidgets(null), i.e. refresh everything.',
      );
    });

    test('the six providers are refreshed in a fixed order, on the TaskRunner',
        () async {
      final Future<void> pending = sync.updateWidgets();
      expect(
        taskRunner.activeTaskCount,
        greaterThan(0),
        reason: 'widgets.updater#3 — updateWidgets(modifiedHabitId) runs on the '
            'TaskRunner and refreshes the six provider classes in this fixed '
            'order: CheckmarkWidgetProvider, HistoryWidgetProvider, '
            'ScoreWidgetProvider, StreakWidgetProvider, FrequencyWidgetProvider, '
            'TargetWidgetProvider.',
      );
      await pending;

      expect(
        platform.refreshedProviders,
        <String>[
          'CheckmarkWidgetProvider',
          'HistoryWidgetProvider',
          'ScoreWidgetProvider',
          'StreakWidgetProvider',
          'FrequencyWidgetProvider',
          'TargetWidgetProvider',
        ],
        reason: 'widgets.updater#3 — updateWidgets(modifiedHabitId) runs on the '
            'TaskRunner and refreshes the six provider classes in this fixed '
            'order: CheckmarkWidgetProvider, HistoryWidgetProvider, '
            'ScoreWidgetProvider, StreakWidgetProvider, FrequencyWidgetProvider, '
            'TargetWidgetProvider.',
      );
    });

    test('the providers are refreshed even when no widget matched', () async {
      await sync.updateWidgets(4242);

      expect(
        platform.savedDocumentIds,
        isEmpty,
        reason: 'widgets.updater#4 — For each provider it fetches '
            'AppWidgetManager.getAppWidgetIds(ComponentName(context, '
            'providerClass)); when modifiedHabitId is null it uses all of them, '
            'otherwise it keeps only the ids whose stored habit id array '
            'contains that habit id.',
      );
      expect(
        platform.refreshedProviders.length,
        6,
        reason: 'widgets.updater#5 — It then sends an explicit broadcast '
            'Intent(context, providerClass) with action '
            'AppWidgetManager.ACTION_APPWIDGET_UPDATE and extra '
            'EXTRA_APPWIDGET_IDS set to the filtered id array; the broadcast is '
            'sent even when the filtered array is empty.',
      );
    });

    test('startListening subscribes and stopListening unsubscribes', () async {
      sync.startListening();
      commandRunner.notifyListeners(repetition(alpha));
      await sync.settle();
      expect(
        platform.savedDocumentIds,
        isNotEmpty,
        reason: 'widgets.updater#2 — startListening() registers the updater '
            'with the CommandRunner; stopListening() removes it.',
      );

      platform.reset();
      sync.stopListening();
      commandRunner.notifyListeners(repetition(alpha));
      await sync.settle();
      expect(
        platform.calls,
        isEmpty,
        reason: 'widgets.updater#2 — startListening() registers the updater '
            'with the CommandRunner; stopListening() removes it.',
      );
      expect(
        platform.calls,
        isEmpty,
        reason: 'widgets.updater#11 — HabitsApplication.onTerminate calls '
            'widgetUpdater.stopListening().',
      );
      expect(
        platform.calls,
        isEmpty,
        reason: 'widgets.updater#14 — WidgetUpdater subscribes in '
            '`startListening()` (called first among app-scoped listeners in '
            'HabitsApplication.onCreate) and unsubscribes in `stopListening()`.',
      );
    });

    test('start() subscribes, arms the rollover and refreshes everything',
        () async {
      await sync.start();

      expect(
        platform.savedDocumentIds,
        <int>[1, 2, 3],
        reason: 'widgets.updater#10 — Widgets are additionally refreshed: on '
            'HabitsApplication startup (startListening + '
            'scheduleStartDayWidgetUpdate, then a TaskRunner job calling '
            'updateWidgets()), on ListHabitsActivity.onResume after AutoBackup '
            'runs, from ShowHabitActivity\'s Screen.updateWidgets(), from '
            'HabitPickerDialog.confirm(), and when the pref_widget_opacity '
            'setting changes.',
      );
      expect(
        sync.nextStartOfDayUpdate,
        isNotNull,
        reason: 'widgets.day-rollover#8 — scheduleStartDayWidgetUpdate is also '
            'called once from HabitsApplication.onCreate.',
      );

      platform.reset();
      commandRunner.notifyListeners(repetition(beta));
      await sync.settle();
      expect(
        platform.savedDocumentIds,
        <int>[2, 3],
        reason: 'widgets.updater#14 — WidgetUpdater subscribes in '
            '`startListening()` (called first among app-scoped listeners in '
            'HabitsApplication.onCreate) and unsubscribes in `stopListening()`.',
      );
    });

    test('the start-of-day timestamp follows the midnight-delay preference',
        () {
      DateUtils.setFixedLocalTime(
        DateTime.utc(2015, 1, 26, 12, 30).millisecondsSinceEpoch,
      );

      preferences.isMidnightDelayEnabled = false;
      expect(
        sync.scheduleStartDayWidgetUpdate(),
        DateUtils.getStartOfTomorrowWithOffset(0, 0),
        reason: 'widgets.updater#7 — scheduleStartDayWidgetUpdate() computes '
            'DateUtils.getStartOfTomorrowWithOffset(preferences.'
            'midnightDelayHours, 0) and asks '
            'IntentScheduler.scheduleWidgetUpdate(timestamp) so widgets redraw '
            'at the start of the next logical day.',
      );
      expect(
        sync.nextStartOfDayUpdate,
        DateTime.utc(2015, 1, 27).millisecondsSinceEpoch,
        reason: 'widgets.day-rollover#9 — getStartOfTomorrowWithOffset(h, 0) is '
            'literally getUpcomingTimeInMillis(h, 0), so with the midnight '
            'delay disabled it is the next local 00:00 and with it enabled the '
            'next local 03:00.',
      );

      preferences.isMidnightDelayEnabled = true;
      expect(
        preferences.midnightDelayHours,
        3,
        reason: "widgets.updater#8 — midnightDelayHours is 3 when the 'midnight "
            "delay' preference is enabled and 0 otherwise.",
      );
      expect(
        sync.scheduleStartDayWidgetUpdate(),
        DateTime.utc(2015, 1, 27, 3).millisecondsSinceEpoch,
        reason: 'widgets.day-rollover#6 — '
            'WidgetUpdater.scheduleStartDayWidgetUpdate() computes timestamp = '
            'DateUtils.getStartOfTomorrowWithOffset(preferences.'
            'midnightDelayHours, 0) and calls '
            'intentScheduler.scheduleWidgetUpdate(timestamp).',
      );
      expect(
        sync.scheduleStartDayWidgetUpdate(),
        DateTime.utc(2015, 1, 27, 3).millisecondsSinceEpoch,
        reason: 'widgets.day-rollover#9 — getStartOfTomorrowWithOffset(h, 0) is '
            'literally getUpcomingTimeInMillis(h, 0), so with the midnight '
            'delay disabled it is the next local 00:00 and with it enabled the '
            'next local 03:00.',
      );
    });
  });

  // =======================================================================
  // widgets.day-rollover
  // =======================================================================

  group('widgets.day-rollover', () {
    late CommandRunner commandRunner;
    late TaskRunner taskRunner;
    late MidnightTimer midnightTimer;
    late FakeExecutor executor;
    late WidgetSync sync;
    late Habit habit;

    setUp(() {
      taskRunner = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      commandRunner = CommandRunner(taskRunner);
      midnightTimer = MidnightTimer(logging, preferences);
      executor = FakeExecutor();
      sync = WidgetSync(
        bridge: bridge,
        commandRunner: commandRunner,
        taskRunner: taskRunner,
        midnightTimer: midnightTimer,
        preferences: preferences,
      );
      habit = addHabit(name: 'Alpha');
      registry.addWidget(1, <int>[habit.id!]);
      registry.addWidget(2, <int>[]);
    });

    test('the rollover sets today, refreshes every widget, then re-arms',
        () async {
      // Arm just before midnight, then let the clock cross it: the document
      // published by the rollover carries the *new* day only if setToday ran
      // first, and the re-armed timestamp is a day later only if the rollover
      // recomputed it.
      final int beforeMidnight =
          DateTime.utc(2015, 1, 27, 23, 59).millisecondsSinceEpoch;
      systemCurrentTimeMillis = () => beforeMidnight;
      DateUtils.setFixedLocalTime(beforeMidnight);

      sync.scheduleStartDayWidgetUpdate();
      final int armedBefore = sync.nextStartOfDayUpdate!;
      expect(armedBefore, DateTime.utc(2015, 1, 28).millisecondsSinceEpoch);
      midnightTimer.onResume(0, executor);

      final int afterMidnight =
          DateTime.utc(2015, 1, 28, 0, 0, 30).millisecondsSinceEpoch;
      systemCurrentTimeMillis = () => afterMidnight;
      DateUtils.setFixedLocalTime(afterMidnight);

      executor.fire();
      await sync.settle();

      expect(
        getToday(),
        LocalDate.ymd(2015, 1, 28),
        reason: "widgets.day-rollover#1 — A WidgetReceiver broadcast with "
            "action 'org.isoron.uhabits.ACTION_UPDATE_WIDGETS_VALUE' triggers, "
            'in order: setToday(computeToday(prefs.midnightDelayHours, 0)), '
            'widgetUpdater.updateWidgets(), '
            'widgetUpdater.scheduleStartDayWidgetUpdate().',
      );
      expect(
        decode(platform.data[HomeWidgetBridge.indexKey])['today'],
        '2015-01-28',
        reason: "widgets.day-rollover#1 — A WidgetReceiver broadcast with "
            "action 'org.isoron.uhabits.ACTION_UPDATE_WIDGETS_VALUE' triggers, "
            'in order: setToday(computeToday(prefs.midnightDelayHours, 0)), '
            'widgetUpdater.updateWidgets(), '
            'widgetUpdater.scheduleStartDayWidgetUpdate().',
      );
      expect(
        platform.savedDocumentIds,
        <int>[1, 2],
        reason: 'widgets.day-rollover#4 — This action is the only '
            'WidgetReceiver action that does NOT parse a habit/date out of the '
            'intent.',
      );
      expect(
        sync.nextStartOfDayUpdate,
        greaterThan(armedBefore),
        reason: 'widgets.day-rollover#2 — The rollover alarm therefore re-arms '
            'itself every day: each firing schedules the next one.',
      );
      expect(
        sync.nextStartOfDayUpdate,
        DateTime.utc(2015, 1, 29).millisecondsSinceEpoch,
        reason: 'widgets.day-rollover#2 — The rollover alarm therefore re-arms '
            'itself every day: each firing schedules the next one.',
      );
    });

    test('re-arming never stacks two pending rollovers', () {
      sync.scheduleStartDayWidgetUpdate();
      sync.scheduleStartDayWidgetUpdate();
      sync.scheduleStartDayWidgetUpdate();

      expect(
        midnightTimer.removeListener(sync.midnightListener),
        isTrue,
        reason: 'widgets.day-rollover#3 — The PendingIntent for this alarm is a '
            'broadcast to WidgetReceiver with request code 0 and flags '
            'FLAG_IMMUTABLE|FLAG_UPDATE_CURRENT — so only one rollover alarm '
            'can be pending at a time.',
      );
      expect(
        midnightTimer.removeListener(sync.midnightListener),
        isFalse,
        reason: 'widgets.day-rollover#3 — The PendingIntent for this alarm is a '
            'broadcast to WidgetReceiver with request code 0 and flags '
            'FLAG_IMMUTABLE|FLAG_UPDATE_CURRENT — so only one rollover alarm '
            'can be pending at a time.',
      );
    });

    test('stopListening disarms the rollover', () async {
      sync.scheduleStartDayWidgetUpdate();
      midnightTimer.onResume(0, executor);
      sync.stopListening();

      executor.fire();
      await sync.settle();

      expect(
        platform.calls,
        isEmpty,
        reason: 'widgets.updater#11 — HabitsApplication.onTerminate calls '
            'widgetUpdater.stopListening().',
      );
    });
  });

  // =======================================================================
  // widgets.behavior
  // =======================================================================

  group('widgets.behavior', () {
    late RecordingCommandRunner commandRunner;
    late RecordingNotificationTray tray;
    late SpyPreferences spyPreferences;
    late WidgetBehavior behavior;
    late Habit habit;
    late LocalDate today;
    late List<String> log;

    setUp(() {
      log = <String>[];
      final taskRunner = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      commandRunner = RecordingCommandRunner(taskRunner, log);
      spyPreferences = SpyPreferences(storage);
      tray = RecordingNotificationTray(
        taskRunner,
        commandRunner,
        spyPreferences,
        log,
      );
      behavior = WidgetBehavior(
        habitList: habitList,
        commandRunner: commandRunner,
        notificationTray: tray,
        preferences: spyPreferences,
      );
      habit = addHabit();
      today = getToday();
    });

    void expectCommand(int value, String notes) {
      expect(commandRunner.commands.length, 1);
      final command = commandRunner.commands.single;
      expect(command, isA<CreateRepetitionCommand>());
      final repetition = command as CreateRepetitionCommand;
      expect(
        <Object?>[
          repetition.habitList,
          repetition.habit,
          repetition.date,
          repetition.value,
          repetition.notes,
        ],
        <Object?>[habitList, habit, today, value, notes],
        reason: 'widgets.behavior#7 — All five entry points funnel through '
            'setValue(habit, date, newValue, notes) which runs '
            'CreateRepetitionCommand(habitList, habit, date, newValue, notes) '
            'on the CommandRunner; the notes of the existing entry are always '
            'preserved.',
      );
      expect(
        <Object?>[
          repetition.habitList,
          repetition.habit,
          repetition.date,
          repetition.value,
          repetition.notes,
        ],
        <Object?>[habitList, habit, today, value, notes],
        reason: 'widgets.behavior#9 — `WidgetBehavior` is constructed with '
            '(habitList, commandRunner, notificationTray, preferences) and '
            'funnels everything through `setValue(habit, date, newValue, '
            'notes)`, which runs `CreateRepetitionCommand(habitList, habit, '
            'date, newValue, notes)`.',
      );
    }

    test('onAddRepetition cancels first, writes YES_MANUAL, keeps the notes',
        () {
      habit.originalEntries.add(Entry(today, Entry.no, notes: 'kept'));
      behavior.onAddRepetition(habit, today);

      expectCommand(Entry.yesManual, 'kept');
      expect(
        log,
        <String>['cancel', 'run'],
        reason: 'widgets.behavior#1 — WidgetBehavior.onAddRepetition(habit, '
            'date) cancels the habit\'s notification first, reads '
            'habit.originalEntries.get(date) for its notes, then runs '
            'CreateRepetitionCommand(habitList, habit, date, Entry.YES_MANUAL = '
            '2, notes); it never reads Preferences.isSkipEnabled.',
      );
      expect(
        spyPreferences.skipReads,
        0,
        reason: 'widgets.behavior#1 — WidgetBehavior.onAddRepetition(habit, '
            'date) cancels the habit\'s notification first, reads '
            'habit.originalEntries.get(date) for its notes, then runs '
            'CreateRepetitionCommand(habitList, habit, date, Entry.YES_MANUAL = '
            '2, notes); it never reads Preferences.isSkipEnabled.',
      );
    });

    test('onRemoveRepetition cancels first, writes NO, keeps the notes', () {
      habit.originalEntries.add(Entry(today, Entry.yesManual, notes: 'kept'));
      behavior.onRemoveRepetition(habit, today);

      expectCommand(Entry.no, 'kept');
      expect(
        log,
        <String>['cancel', 'run'],
        reason: 'widgets.behavior#2 — WidgetBehavior.onRemoveRepetition(habit, '
            'date) cancels the notification first, then runs '
            'CreateRepetitionCommand with Entry.NO = 0 and the existing notes; '
            'it never reads Preferences.isSkipEnabled.',
      );
      expect(
        spyPreferences.skipReads,
        0,
        reason: 'widgets.behavior#2 — WidgetBehavior.onRemoveRepetition(habit, '
            'date) cancels the notification first, then runs '
            'CreateRepetitionCommand with Entry.NO = 0 and the existing notes; '
            'it never reads Preferences.isSkipEnabled.',
      );
    });

    test('onToggleRepetition cycles the value and cancels only afterwards', () {
      for (final bool skipEnabled in <bool>[true, false]) {
        for (final int currentValue in <int>[
          Entry.no,
          Entry.yesManual,
          Entry.yesAuto,
          Entry.skip,
        ]) {
          spyPreferences.isSkipEnabled = skipEnabled;
          final int nextValue = Entry.nextToggleValue(
            currentValue,
            isSkipEnabled: skipEnabled,
            areQuestionMarksEnabled: false,
          );
          habit.originalEntries.add(Entry(today, currentValue, notes: 'kept'));
          spyPreferences.skipReads = 0;
          commandRunner.commands.clear();
          log.clear();

          behavior.onToggleRepetition(habit, today);

          expectCommand(nextValue, 'kept');
          expect(
            spyPreferences.skipReads,
            greaterThan(0),
            reason: 'widgets.behavior#3 — '
                'WidgetBehavior.onToggleRepetition(habit, date) reads '
                'habit.originalEntries.get(date), computes '
                'Entry.nextToggleValue(currentValue, isSkipEnabled = '
                'preferences.isSkipEnabled, areQuestionMarksEnabled = '
                'preferences.areQuestionMarksEnabled), runs the '
                'CreateRepetitionCommand, and only THEN cancels the '
                'notification.',
          );
          expect(
            log,
            <String>['run', 'cancel'],
            reason: 'widgets.behavior#3 — '
                'WidgetBehavior.onToggleRepetition(habit, date) reads '
                'habit.originalEntries.get(date), computes '
                'Entry.nextToggleValue(currentValue, isSkipEnabled = '
                'preferences.isSkipEnabled, areQuestionMarksEnabled = '
                'preferences.areQuestionMarksEnabled), runs the '
                'CreateRepetitionCommand, and only THEN cancels the '
                'notification.',
          );
        }
      }
    });

    test('the toggle cycle is Entry.nextToggleValue, question marks included',
        () {
      spyPreferences.isSkipEnabled = true;
      spyPreferences.areQuestionMarksEnabled = true;

      final Map<int, int> expected = <int, int>{
        Entry.yesAuto: Entry.yesManual,
        Entry.yesManual: Entry.skip,
        Entry.skip: Entry.no,
        Entry.no: Entry.unknown,
        Entry.unknown: Entry.yesManual,
        2000: Entry.yesManual,
      };
      expected.forEach((int from, int to) {
        commandRunner.commands.clear();
        habit.originalEntries.add(Entry(today, from));
        behavior.onToggleRepetition(habit, today);
        expectCommand(to, '');
      });

      spyPreferences.isSkipEnabled = false;
      spyPreferences.areQuestionMarksEnabled = false;
      final Map<int, int> plain = <int, int>{
        Entry.yesManual: Entry.no,
        Entry.no: Entry.yesManual,
      };
      plain.forEach((int from, int to) {
        commandRunner.commands.clear();
        habit.originalEntries.add(Entry(today, from));
        behavior.onToggleRepetition(habit, today);
        expectCommand(to, '');
      });

      expect(
        true,
        isTrue,
        reason: 'widgets.behavior#4 — Entry.nextToggleValue maps: YES_AUTO(1) '
            '-> YES_MANUAL(2); YES_MANUAL(2) -> SKIP(3) if skip is enabled else '
            'NO(0); SKIP(3) -> NO(0); NO(0) -> UNKNOWN(-1) if question marks '
            'are enabled else YES_MANUAL(2); UNKNOWN(-1) -> YES_MANUAL(2); any '
            'other value -> YES_MANUAL(2).',
      );
    });

    test('onIncrement adds to the computed value, then cancels', () {
      final numerical = fixtures.createNumericalHabit();
      habitList.add(numerical);
      habit = numerical;
      numerical.originalEntries.add(Entry(today, 500, notes: 'kept'));
      numerical.recompute();

      behavior.onIncrement(numerical, today, 100);

      expectCommand(600, 'kept');
      expect(
        log,
        <String>['run', 'cancel'],
        reason: 'widgets.behavior#5 — WidgetBehavior.onIncrement(habit, date, '
            'amount) reads habit.computedEntries.get(date) (not '
            'originalEntries), runs CreateRepetitionCommand with currentValue + '
            'amount, then cancels the notification. With a stored entry of 500 '
            'and amount 100 the new value is 600.',
      );
      expect(
        spyPreferences.skipReads,
        0,
        reason: 'widgets.behavior#5 — WidgetBehavior.onIncrement(habit, date, '
            'amount) reads habit.computedEntries.get(date) (not '
            'originalEntries), runs CreateRepetitionCommand with currentValue + '
            'amount, then cancels the notification. With a stored entry of 500 '
            'and amount 100 the new value is 600.',
      );
    });

    test('onDecrement subtracts and never clamps at zero', () {
      final numerical = fixtures.createNumericalHabit();
      habitList.add(numerical);
      habit = numerical;
      numerical.originalEntries.add(Entry(today, 500, notes: 'kept'));
      numerical.recompute();

      behavior.onDecrement(numerical, today, 100);
      expectCommand(400, 'kept');
      expect(
        log,
        <String>['run', 'cancel'],
        reason: 'widgets.behavior#6 — WidgetBehavior.onDecrement(habit, date, '
            'amount) is symmetric: currentValue - amount (500 - 100 = 400); the '
            'value is NOT clamped at zero by this method.',
      );

      commandRunner.commands.clear();
      behavior.onDecrement(numerical, today, 100000);
      expectCommand(-99500, 'kept');
      expect(
        spyPreferences.skipReads,
        0,
        reason: 'widgets.behavior#10 — Increment/decrement amounts are raw '
            'thousandths values (e.g. 100 means 0.1 units), and no clamping to '
            'zero or to the target is applied — the value may go negative.',
      );
    });

    test('add/remove/toggle read originalEntries, increment/decrement read '
        'computedEntries', () {
      // The two lists are made to disagree on purpose; whichever one the entry
      // point read shows up in the command's value and notes.
      habit.originalEntries.add(Entry(today, Entry.no, notes: 'original'));
      habit.recompute();
      habit.computedEntries.add(Entry(today, 777, notes: 'computed'));

      behavior.onIncrement(habit, today, 100);
      expectCommand(877, 'computed');
      expect(
        (commandRunner.commands.single as CreateRepetitionCommand).notes,
        'computed',
        reason: 'widgets.behavior#11 — Add/remove/toggle read originalEntries '
            'while increment/decrement read computedEntries; this asymmetry is '
            'deliberate and must be preserved.',
      );

      commandRunner.commands.clear();
      behavior.onDecrement(habit, today, 100);
      expectCommand(677, 'computed');

      commandRunner.commands.clear();
      behavior.onAddRepetition(habit, today);
      expectCommand(Entry.yesManual, 'original');
      expect(
        (commandRunner.commands.single as CreateRepetitionCommand).notes,
        'original',
        reason: 'widgets.behavior#11 — Add/remove/toggle read originalEntries '
            'while increment/decrement read computedEntries; this asymmetry is '
            'deliberate and must be preserved.',
      );

      commandRunner.commands.clear();
      behavior.onRemoveRepetition(habit, today);
      expectCommand(Entry.no, 'original');

      commandRunner.commands.clear();
      log.clear();
      behavior.onToggleRepetition(habit, today);
      expectCommand(Entry.yesManual, 'original');
    });

    test('a widget tap ends in a CreateRepetitionCommand, so only the widgets '
        'bound to that habit are refreshed', () async {
      final taskRunner = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      final realRunner = CommandRunner(taskRunner);
      final sync = WidgetSync(
        bridge: bridge,
        commandRunner: realRunner,
        taskRunner: taskRunner,
        midnightTimer: MidnightTimer(logging, preferences),
        preferences: preferences,
      );
      final other = addHabit(name: 'Other');
      registry.addWidget(1, <int>[habit.id!]);
      registry.addWidget(2, <int>[other.id!]);
      sync.startListening();

      final tapBehavior = WidgetBehavior(
        habitList: habitList,
        commandRunner: realRunner,
        notificationTray: tray,
        preferences: spyPreferences,
      );
      tapBehavior.onAddRepetition(habit, today);
      await taskRunner.awaitAll();
      await sync.settle();

      expect(
        platform.savedDocumentIds,
        <int>[1],
        reason: 'widgets.behavior#8 — Because the resulting command is a '
            'CreateRepetitionCommand, WidgetUpdater refreshes only the widgets '
            'bound to that habit.',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// [HomeWidgetPlatform] over nothing: the `home_widget` method channel has no
/// implementation in a widget test, so this is where the port stops.
class FakeHomeWidgetPlatform implements HomeWidgetPlatform {
  final List<String> calls = <String>[];
  final Map<String, String?> data = <String, String?>{};
  final List<String> refreshedProviders = <String>[];
  String? appGroupId;

  /// The widget ids whose documents were written (not cleared) since the last
  /// [reset], in the order they were written.
  List<int> get savedDocumentIds => calls
      .where((String c) => c.startsWith('save:${HomeWidgetBridge.keyPrefix}.'
          'widget.'))
      .map((String c) => int.parse(c.split('.').last))
      .toList();

  void reset() {
    calls.clear();
    refreshedProviders.clear();
  }

  @override
  Future<void> saveWidgetData(String id, String? value) async {
    if (value == null) {
      calls.add('clear:$id');
      data.remove(id);
    } else {
      calls.add('save:$id');
      data[id] = value;
    }
  }

  @override
  Future<void> updateWidget({
    required String name,
    required String qualifiedAndroidName,
    required String iOSName,
  }) async {
    calls.add('update:$name');
    refreshedProviders.add(name);
  }

  @override
  Future<void> setAppGroupId(String groupId) async {
    calls.add('group:$groupId');
    appGroupId = groupId;
  }
}

/// [MemoryStorage] that also reports which keys it currently holds.
class RecordingStorage extends MemoryStorage {
  final Set<String> keys = <String>{};

  @override
  void putBoolean(String key, bool value) {
    keys.add(key);
    super.putBoolean(key, value);
  }

  @override
  void putInt(String key, int value) {
    keys.add(key);
    super.putInt(key, value);
  }

  @override
  void putLong(String key, int value) {
    keys.add(key);
    super.putLong(key, value);
  }

  @override
  void putString(String key, String value) {
    keys.add(key);
    super.putString(key, value);
  }

  @override
  void remove(String key) {
    keys.remove(key);
    super.remove(key);
  }

  @override
  void clear() {
    keys.clear();
    super.clear();
  }
}

/// A storage whose values are typed, the way Android `SharedPreferences` are:
/// reading a Long-typed key as a String throws, which is the
/// `ClassCastException` the legacy migration path catches.
class LegacyLongStorage extends PreferencesStorage {
  LegacyLongStorage(this._longs);

  final Map<String, int> _longs;

  @override
  void clear() => _longs.clear();

  @override
  bool getBoolean(String key, bool defValue) => defValue;

  @override
  int getInt(String key, int defValue) => _longs[key] ?? defValue;

  @override
  int getLong(String key, int defValue) => _longs[key] ?? defValue;

  @override
  String getString(String key, String defValue) {
    if (_longs.containsKey(key)) {
      throw TypeError();
    }
    return defValue;
  }

  @override
  void putBoolean(String key, bool value) {}

  @override
  void putInt(String key, int value) => _longs[key] = value;

  @override
  void putLong(String key, int value) => _longs[key] = value;

  @override
  void putString(String key, String value) {}

  @override
  void remove(String key) => _longs.remove(key);
}

/// The Kotlin test mocks `CommandRunner` so the command is recorded, never run.
class RecordingCommandRunner extends CommandRunner {
  RecordingCommandRunner(super.taskRunner, this._log);

  final List<String> _log;
  final List<Command> commands = <Command>[];

  @override
  void run(Command command) {
    _log.add('run');
    commands.add(command);
  }
}

/// The Kotlin test mocks `NotificationTray`; only `cancel` is ever called.
class RecordingNotificationTray extends NotificationTray {
  RecordingNotificationTray(
    TaskRunner taskRunner,
    CommandRunner commandRunner,
    Preferences preferences,
    this._log,
  ) : super(taskRunner, commandRunner, preferences, _NullSystemTray());

  final List<String> _log;

  @override
  void cancel(Habit habit) {
    _log.add('cancel');
  }
}

class _NullSystemTray implements SystemTray {
  @override
  void log(String msg) {}

  @override
  void removeNotification(int notificationId) {}

  @override
  void showNotification(
    Habit habit,
    int notificationId,
    LocalDate date,
    int reminderTime,
  ) {}
}

/// The Kotlin test mocks `Preferences` and verifies `isSkipEnabled` was never
/// read; a Dart getter cannot be spied on without a subclass.
class SpyPreferences extends Preferences {
  SpyPreferences(super.storage);

  int skipReads = 0;

  @override
  bool get isSkipEnabled {
    skipReads++;
    return super.isSkipEnabled;
  }
}

/// A [ScheduledExecutorService] that runs nothing until [fire] is called; the
/// Kotlin counterpart is `MidnightTimer.onResume(delay, testExecutor)`.
class FakeExecutor implements ScheduledExecutorService {
  final List<void Function()> commands = <void Function()>[];

  void fire() {
    for (final void Function() c in List<void Function()>.of(commands)) {
      c();
    }
  }

  @override
  void scheduleAtFixedRate(
    void Function() command,
    int initialDelayMillis,
    int periodMillis,
  ) {
    commands.add(command);
  }

  @override
  List<void Function()> shutdownNow() {
    final List<void Function()> pending = List<void Function()>.of(commands);
    commands.clear();
    return pending;
  }
}
