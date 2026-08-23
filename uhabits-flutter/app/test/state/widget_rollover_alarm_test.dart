/// `audit5.home-screen-widgets-never-roll-over`: the alarm that redraws every
/// home-screen widget when the logical day changes.
///
/// Upstream there are two independent clocks and it matters that there are two.
/// `MidnightTimer` belongs to the activity — `ListHabitsActivity.onResume`
/// starts it and `onPause` shuts it down — and it refreshes the *screen*.
/// `WidgetUpdater.scheduleStartDayWidgetUpdate()` belongs to the OS: it hands
/// `getStartOfTomorrowWithOffset(midnightDelayHours, 0)` to
/// `IntentScheduler.scheduleWidgetUpdate`, which sets an `AlarmManager` RTC
/// `setExactAndAllowWhileIdle` alarm on a broadcast `PendingIntent` addressed
/// to the manifest-declared `WidgetReceiver`. Pausing the activity does nothing
/// to it, and at the logical midnight it runs `setToday`, `updateWidgets()` and
/// `scheduleStartDayWidgetUpdate()` whether the app is in front, behind, or not
/// running at all.
///
/// The port collapsed the two into one: `WidgetSync` registered itself as a
/// `MidnightTimer` listener and nothing else, and `_ThemedApp._onPause` —
/// which is `ListHabitsActivity.onPause` — calls `midnightTimer.onPause()`,
/// whose `shutdownNow()` cancels the only clock there was. So the moment the
/// user pressed Home, the home-screen widgets stopped rolling over: they went
/// on showing yesterday's column, yesterday's ring and yesterday's "today"
/// until the app was opened again. That is the one place a widget is *supposed*
/// to be useful — the app is not open.
///
/// ## What this file pins
///
/// That the rollover has a clock of its own; that pausing the midnight timer
/// does not disarm it; that when it fires it performs `WidgetReceiver`'s three
/// steps in order; that it re-arms itself; and that only shutting the port down
/// stops it. A Dart timer still cannot outlive the isolate — no Flutter API
/// can wake a dead process — so "not running at all" remains out of reach, and
/// that is the one half of rule #1 this cannot buy.
library;

// The classes under test reach the core by its `src` path, exactly as
// lib/state/app_scope.dart does.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits/state/widget_sync.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/utils/midnight_timer.dart';

const String rule1 =
    'audit5.home-screen-widgets-never-roll-over#1 — In the Kotlin app: '
    '`scheduleStartDayWidgetUpdate()` computes '
    '`getStartOfTomorrowWithOffset(midnightDelayHours, 0)` and hands it to '
    '`IntentScheduler.scheduleWidgetUpdate`, which sets an AlarmManager RTC '
    '`setExactAndAllowWhileIdle` alarm on a broadcast PendingIntent addressed '
    'to the manifest-declared `WidgetReceiver`. At the logical midnight Android '
    'delivers that broadcast — starting the app process if it is dead — and the '
    'receiver runs `setToday(computeToday(...))`, `widgetUpdater.updateWidgets()` '
    'and `scheduleStartDayWidgetUpdate()` in that order. Every home-screen '
    'widget therefore redraws for the new day whether or not the user has '
    'opened the app.';

void main() {
  const TimeZone gmt = FixedTimeZone(0);

  late MemoryHabitList habitList;
  late MemoryStorage storage;
  late Preferences preferences;
  late WidgetRegistry registry;
  late FakeHomeWidgetPlatform platform;
  late HomeWidgetBridge bridge;
  late CommandRunner commandRunner;
  late TaskRunner taskRunner;
  late MidnightTimer midnightTimer;
  late FakeExecutor executor;
  late WidgetSync sync;

  final int Function() realClock = systemCurrentTimeMillis;
  final TimeZone Function() realZone = getDefaultTimeZone;

  /// The instant [millis] becomes both the wall clock (`computeToday`) and the
  /// local time the delay arithmetic reads (`DateUtils.getLocalTime`).
  void clockAt(int millis) {
    systemCurrentTimeMillis = () => millis;
    DateUtils.setFixedLocalTime(millis);
  }

  setUp(() {
    DateUtils.setFixedTimeZone(gmt);
    getDefaultTimeZone = () => gmt;
    habitList = MemoryHabitList();
    storage = MemoryStorage();
    preferences = Preferences(storage);
    registry = WidgetRegistry(storage);
    platform = FakeHomeWidgetPlatform();
    bridge = HomeWidgetBridge(
      habitList: habitList,
      registry: registry,
      platform: platform,
      preferences: preferences,
    );
    taskRunner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    commandRunner = CommandRunner(taskRunner);
    midnightTimer = MidnightTimer(
      StandardLogging(out: StringBuffer(), err: StringBuffer()),
      preferences,
    );
    executor = FakeExecutor();
    sync = WidgetSync(
      bridge: bridge,
      commandRunner: commandRunner,
      taskRunner: taskRunner,
      midnightTimer: midnightTimer,
      preferences: preferences,
    );

    final HabitFixtures fixtures =
        HabitFixtures(MemoryModelFactory(), habitList);
    final Habit alpha = fixtures.createEmptyHabit(name: 'Alpha');
    habitList.add(alpha);
    registry.addWidget(1, <int>[alpha.id!]);
    registry.addWidget(2, <int>[alpha.id!]);
    setToday(LocalDate.ymd(2015, 1, 27));
  });

  tearDown(() {
    // The port's `HabitsApplication.onTerminate`. Without it the alarm below
    // outlives the test that armed it.
    sync.stopListening();
    DateUtils.setFixedTimeZone(null);
    DateUtils.setFixedLocalTime(null);
    systemCurrentTimeMillis = realClock;
    getDefaultTimeZone = realZone;
    resetToday();
  });

  Map<String, Object?> decode(String? json) =>
      jsonDecode(json!) as Map<String, Object?>;

  /// Arms the rollover [millis] before the coming midnight and hands back the
  /// real-time slice a caller has to wait for it.
  ///
  /// The alarm is a real clock — that is the whole point of the fix — so the
  /// test moves the app's *logical* clock to just before midnight and then
  /// waits an actual fraction of a second.
  Duration armJustBeforeMidnight({int millis = 400}) {
    clockAt(DateTime.utc(2015, 1, 28).millisecondsSinceEpoch - millis);
    sync.scheduleStartDayWidgetUpdate();
    return Duration(milliseconds: millis * 4);
  }

  /// Midnight arrives.
  void crossMidnight() {
    clockAt(DateTime.utc(2015, 1, 28, 0, 0, 1).millisecondsSinceEpoch);
  }

  group('audit5.home-screen-widgets-never-roll-over', () {
    test('#1 the rollover fires with the app in the background', () async {
      final Duration wait = armJustBeforeMidnight();
      // The app is in the foreground: both clocks are running.
      midnightTimer.onResume(0, executor);
      // The user presses Home. `_ThemedApp._onPause` is
      // `ListHabitsActivity.onPause`, whose first statement is
      // `midnightTimer.onPause()` — and `shutdownNow()` takes every listener's
      // schedule with it.
      midnightTimer.onPause();
      expect(executor.commands, isEmpty,
          reason: 'the precondition: the screen clock really is dead, so '
              'anything that happens below is the widget alarm and only the '
              'widget alarm');

      crossMidnight();
      await Future<void>.delayed(wait);
      await sync.settle();

      expect(
        getToday(),
        LocalDate.ymd(2015, 1, 28),
        reason: '$rule1 Step one of the receiver: '
            'setToday(computeToday(prefs.midnightDelayHours, 0)). Upstream it '
            'is the alarm that performs it, not the activity\'s timer, which '
            'is exactly why it still happens with the activity paused.',
      );
      expect(
        decode(platform.data[HomeWidgetBridge.indexKey])['today'],
        '2015-01-28',
        reason: '$rule1 Step two: widgetUpdater.updateWidgets(). A widget '
            'reads `today` out of the document, so a document that still says '
            '2015-01-27 is a widget drawing yesterday.',
      );
      expect(
        platform.savedDocumentIds,
        <int>[1, 2],
        reason: '$rule1 "Every home-screen widget therefore redraws for the '
            'new day": the refresh is unfiltered, because this is the one '
            'widget action that carries no habit.',
      );
      expect(
        sync.nextStartOfDayUpdate,
        DateTime.utc(2015, 1, 29).millisecondsSinceEpoch,
        reason: '$rule1 Step three: scheduleStartDayWidgetUpdate(). Each '
            'firing arms the next one, so the second night in the background '
            'rolls over as well as the first.',
      );
    });

    test('#1 the rollover has a clock of its own', () async {
      final Duration wait = armJustBeforeMidnight();
      // The midnight timer was never resumed at all — the app was launched and
      // backgrounded before its first frame, or is a host that has no screen.
      crossMidnight();
      await Future<void>.delayed(wait);
      await sync.settle();

      expect(
        platform.savedDocumentIds,
        <int>[1, 2],
        reason: '$rule1 The AlarmManager alarm is armed by '
            'HabitsApplication.onCreate and is not the activity\'s timer; a '
            'port in which the only rollover is a MidnightTimer listener has '
            'no alarm at all.',
      );
    });

    test('#1 the alarm follows the midnight-delay preference', () async {
      preferences.isMidnightDelayEnabled = true;
      // 02:59:59.6 — before the *logical* midnight, which the delay moved to
      // 03:00.
      clockAt(DateTime.utc(2015, 1, 28, 3).millisecondsSinceEpoch - 400);
      sync.scheduleStartDayWidgetUpdate();
      expect(sync.nextStartOfDayUpdate,
          DateTime.utc(2015, 1, 28, 3).millisecondsSinceEpoch,
          reason: '$rule1 the timestamp is '
              'getStartOfTomorrowWithOffset(midnightDelayHours, 0)');

      clockAt(DateTime.utc(2015, 1, 28, 3, 0, 1).millisecondsSinceEpoch);
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      await sync.settle();

      expect(
        platform.savedDocumentIds,
        <int>[1, 2],
        reason: '$rule1 The alarm is set for the timestamp '
            'scheduleStartDayWidgetUpdate computed, so a user with the '
            'three-hour delay enabled has the widgets redraw at 03:00 and not '
            'at 00:00.',
      );
      expect(
        sync.nextStartOfDayUpdate,
        DateTime.utc(2015, 1, 29, 3).millisecondsSinceEpoch,
        reason: '$rule1 …and re-arms on the same offset.',
      );
    });

    test('#1 re-arming replaces the pending alarm rather than stacking one',
        () async {
      final Duration wait = armJustBeforeMidnight();
      sync.scheduleStartDayWidgetUpdate();
      sync.scheduleStartDayWidgetUpdate();

      crossMidnight();
      await Future<void>.delayed(wait);
      await sync.settle();

      expect(
        platform.savedDocumentIds,
        <int>[1, 2],
        reason: '$rule1 The PendingIntent is request code 0 with '
            'FLAG_UPDATE_CURRENT, so only one rollover can ever be pending; '
            'three arms must not produce three refreshes.',
      );
    });

    test('#1 stopListening is the only thing that disarms it', () async {
      final Duration wait = armJustBeforeMidnight();
      sync.stopListening();

      crossMidnight();
      await Future<void>.delayed(wait);
      await sync.settle();

      expect(
        platform.calls,
        isEmpty,
        reason: '$rule1 A Dart timer cannot outlive its isolate, so the port\'s '
            'equivalent of "the alarm survives" is "the alarm survives '
            'everything short of the port shutting down". '
            'HabitsApplication.onTerminate is that shutdown.',
      );
      expect(getToday(), LocalDate.ymd(2015, 1, 27),
          reason: '$rule1 …and nothing moved the day either');
    });

    test('#1 the rollover clock is not the screen clock', () {
      final String source = File('${_appDir()}/lib/state/widget_sync.dart')
          .readAsStringSync();
      final String main =
          File('${_appDir()}/lib/main.dart').readAsStringSync();

      expect(
        source,
        contains('abstract class WidgetUpdateAlarm'),
        reason: '$rule1 `IntentScheduler.scheduleWidgetUpdate` is a seam of its '
            'own upstream, and it has to be one here: a rollover that is only '
            'a `MidnightTimer` listener is a rollover the activity owns.',
      );
      expect(
        source.substring(source.indexOf('int scheduleStartDayWidgetUpdate()')),
        contains('_alarm.schedule('),
        reason: '$rule1 scheduleStartDayWidgetUpdate() computes the timestamp '
            'AND hands it to the scheduler; computing it and filing it away is '
            'what the port was doing.',
      );
      expect(
        main.substring(main.indexOf('void _onPause()')),
        isNot(contains('widgetSync')),
        reason: '$rule1 `ListHabitsActivity.onPause` calls '
            '`midnightTimer.onPause()` and nothing else; the widget alarm is '
            'not the activity\'s to cancel.',
      );
    });
  });
}

String _appDir() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String prefix in <String>['', '/app']) {
      final Directory candidate = Directory('${dir.path}$prefix');
      if (File('${candidate.path}/lib/state/widget_sync.dart').existsSync()) {
        return candidate.path;
      }
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('app/ not found from ${Directory.current.path}');
}

/// The `home_widget` plugin boundary, recording instead of calling.
class FakeHomeWidgetPlatform implements HomeWidgetPlatform {
  final List<String> calls = <String>[];
  final Map<String, String?> data = <String, String?>{};

  List<int> get savedDocumentIds => calls
      .where((String c) =>
          c.startsWith('save:${HomeWidgetBridge.keyPrefix}.widget.'))
      .map((String c) => int.parse(c.split('.').last))
      .toList();

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
  }

  @override
  Future<void> setAppGroupId(String groupId) async {
    calls.add('group:$groupId');
  }
}

/// `MidnightTimer.onResume(delay, testExecutor)`'s hand-driven schedule.
class FakeExecutor implements ScheduledExecutorService {
  final List<void Function()> commands = <void Function()>[];

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
