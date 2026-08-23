/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/NotificationTray.kt
/// (the whole class, including its `SystemTray` interface and the inner
/// `ShowNotificationTask`), plus
/// uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReminderController.kt
/// and its Kotlin test
/// uhabits-android/src/test/java/org/isoron/uhabits/receivers/ReminderControllerTest.kt.
///
/// Covers the parity-ledger features `notifications.show-gating`,
/// `notifications.id-and-registry`, `notifications.content`,
/// `notifications.sticky-and-dismiss` and `reminders.on-show-reminder`.
///
/// Every `expect` carries the parity-ledger rule id it exercises.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// One `SystemTray.showNotification` call, recorded verbatim.
class _Shown {
  _Shown(this.habit, this.notificationId, this.date, this.reminderTime);

  final Habit habit;
  final int notificationId;
  final LocalDate date;
  final int reminderTime;
}

/// The `NotificationTray.SystemTray` the Android layer implements. Everything
/// it receives is recorded, which is the only window the core gives us into
/// what was actually posted.
class _FakeSystemTray implements SystemTray {
  _FakeSystemTray([List<String>? order]) : order = order ?? <String>[];

  /// Shared with the other doubles so cross-collaborator call order can be
  /// asserted.
  final List<String> order;

  final List<String> logs = <String>[];
  final List<_Shown> shown = <_Shown>[];
  final List<int> removed = <int>[];

  @override
  void log(String msg) {
    logs.add(msg);
  }

  @override
  void removeNotification(int notificationId) {
    removed.add(notificationId);
    order.add('removeNotification');
  }

  @override
  void showNotification(
    Habit habit,
    int notificationId,
    LocalDate date,
    int reminderTime,
  ) {
    shown.add(_Shown(habit, notificationId, date, reminderTime));
    order.add('showNotification');
  }
}

/// A [TaskRunner] that only collects tasks, so the two halves of
/// `ShowNotificationTask` can be driven one at a time.
class _ManualTaskRunner implements TaskRunner {
  final List<Task> pending = <Task>[];

  @override
  void execute(Task task) {
    task.onAttached(this);
    pending.add(task);
  }

  @override
  void addListener(TaskRunnerListener listener) {}

  @override
  void removeListener(TaskRunnerListener listener) {}

  @override
  void publishProgress(Task task, int progress) {}

  @override
  int get activeTaskCount => pending.length;

  @override
  Future<void> awaitAll() async {}

  /// Runs everything collected so far, background half first.
  Future<void> runAll() async {
    final tasks = List<Task>.of(pending);
    pending.clear();
    for (final task in tasks) {
      await task.doInBackground();
      task.onPostExecute();
    }
  }
}

/// Stands in for the single `ReminderScheduler` method `ReminderController`
/// uses.
class _FakeScheduler implements ReminderSchedulerApi {
  _FakeScheduler([List<String>? order]) : order = order ?? <String>[];

  final List<String> order;
  int scheduleAllCount = 0;

  @override
  void scheduleAll() {
    scheduleAllCount++;
    order.add('scheduleAll');
  }
}

/// The mokkery `mock<NotificationTray>()` of ReminderControllerTest: records
/// calls and runs none of the real logic.
class _RecordingTray extends NotificationTray {
  _RecordingTray(
    super.taskRunner,
    super.commandRunner,
    super.preferences,
    super.systemTray,
    this.order,
  );

  final List<String> order;
  final List<Habit> showCalls = <Habit>[];
  final List<LocalDate> showDates = <LocalDate>[];
  final List<int> showReminderTimes = <int>[];
  final List<Habit> cancelCalls = <Habit>[];
  final List<Habit> reshowCalls = <Habit>[];

  @override
  void show(Habit habit, LocalDate date, int reminderTime) {
    showCalls.add(habit);
    showDates.add(date);
    showReminderTimes.add(reminderTime);
    order.add('show');
  }

  @override
  void cancel(Habit habit) {
    cancelCalls.add(habit);
    order.add('cancel');
  }

  @override
  void reshow(Habit habit) {
    reshowCalls.add(habit);
    order.add('reshow');
  }
}

/// Records what a second `Preferences.Listener` sees.
class _CountingPreferencesListener extends PreferencesListener {
  int notificationsChanged = 0;

  @override
  void onNotificationsChanged() {
    notificationsChanged++;
  }
}

// ---------------------------------------------------------------------------
// Fixture
// ---------------------------------------------------------------------------

class _Fixture {
  _Fixture({TaskRunner? runner})
      : order = <String>[],
        factory = MemoryModelFactory() {
    systemTray = _FakeSystemTray(order);
    taskRunner = runner ??
        CoroutineTaskRunner(
          mainDispatcher: const UnconfinedTestDispatcher(),
          ioDispatcher: const UnconfinedTestDispatcher(),
        );
    commandRunner = CommandRunner(taskRunner);
    preferences = Preferences(MemoryStorage());
    tray = NotificationTray(
      taskRunner,
      commandRunner,
      preferences,
      systemTray,
    );
  }

  final List<String> order;
  final MemoryModelFactory factory;
  late final _FakeSystemTray systemTray;
  late final TaskRunner taskRunner;
  late final CommandRunner commandRunner;
  late final Preferences preferences;
  late final NotificationTray tray;

  /// A habit that passes every gate: not completed, not archived, with a
  /// reminder that fires every day.
  Habit habit({int? id = 5, String name = 'Meditate'}) {
    final habit = factory.buildHabit();
    habit.id = id;
    habit.name = name;
    habit.question = 'Did you meditate this morning?';
    habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
    habit.recompute();
    return habit;
  }
}

/// Writes today's entry and refreshes the derived lists.
void _enterToday(Habit habit, int value) {
  habit.originalEntries.add(Entry(getToday(), value));
  habit.recompute();
}

/// The default notification date used across the tests: 2015-01-25, a Sunday.
final LocalDate _sunday = LocalDate.ymd(2015, 1, 25);

void main() {
  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
  });

  tearDown(resetToday);

  // -------------------------------------------------------------------------
  // notifications.show-gating
  // -------------------------------------------------------------------------

  group('notifications.show-gating', () {
    test('show() stores the notification data and enqueues one task', () async {
      final runner = _ManualTaskRunner();
      final f = _Fixture(runner: runner);
      final habit = f.habit();

      f.tray.show(habit, _sunday, 456);

      expect(
        runner.pending.length,
        1,
        reason: 'notifications.show-gating#1 — show() enqueues exactly one '
            'ShowNotificationTask on the TaskRunner',
      );
      expect(
        f.systemTray.shown,
        isEmpty,
        reason: 'notifications.show-gating#1 — nothing is posted before the '
            'task runs',
      );

      await runner.runAll();

      expect(
        f.systemTray.shown.length,
        1,
        reason: 'notifications.show-gating#1 — running the enqueued task posts '
            'the notification',
      );
      expect(
        f.systemTray.shown.single.date,
        _sunday,
        reason: 'notifications.show-gating#1 — the stored NotificationData '
            'carries the date passed to show()',
      );
      expect(
        f.systemTray.shown.single.reminderTime,
        456,
        reason: 'notifications.show-gating#1 — the stored NotificationData '
            'carries the reminderTime passed to show()',
      );
    });

    test('isCompleted is captured in doInBackground, gates run in '
        'onPostExecute', () async {
      final runner = _ManualTaskRunner();
      final f = _Fixture(runner: runner);
      final habit = f.habit();

      f.tray.show(habit, _sunday, 456);
      final task = runner.pending.single;

      await task.doInBackground();

      expect(
        f.systemTray.shown,
        isEmpty,
        reason: 'notifications.show-gating#2 — doInBackground only computes '
            'isCompletedToday(); it posts nothing',
      );
      expect(
        f.systemTray.logs,
        isEmpty,
        reason: 'notifications.show-gating#2 — every log line and every gate '
            'belongs to onPostExecute',
      );

      // The habit becomes completed only AFTER the background half ran, so the
      // captured value is still false and the notification is posted.
      _enterToday(habit, Entry.yesManual);
      task.onPostExecute();

      expect(
        f.systemTray.shown.length,
        1,
        reason: 'notifications.show-gating#2 — gate 1 reads the isCompleted '
            'value computed in doInBackground, not the habit state at '
            'onPostExecute time',
      );
    });

    test('the whole pipeline also runs across asynchronous dispatchers',
        () async {
      final runner = CoroutineTaskRunner(
        mainDispatcher: const AsyncDispatcher(),
        ioDispatcher: const AsyncDispatcher(),
      );
      final f = _Fixture(runner: runner);
      final habit = f.habit();

      f.tray.show(habit, _sunday, 456);

      expect(
        f.systemTray.shown,
        isEmpty,
        reason: 'notifications.show-gating#2 — with real dispatchers nothing '
            'has run yet when show() returns',
      );

      await runner.awaitAll();

      expect(
        f.systemTray.shown.length,
        1,
        reason: 'notifications.show-gating#2 — the background half and the '
            'main-dispatcher half both complete',
      );
    });

    test('gate 1: an already checked habit is skipped', () {
      final f = _Fixture();
      final habit = f.habit();
      _enterToday(habit, Entry.yesManual);

      f.tray.show(habit, _sunday, 456);

      expect(
        f.systemTray.shown,
        isEmpty,
        reason: 'notifications.show-gating#3 — isCompleted && targetType != '
            'AT_MOST skips the notification',
      );
      expect(
        f.systemTray.logs,
        contains('Habit 5 already checked. Skipping.'),
        reason: 'notifications.show-gating#3 — the skip is logged as '
            '"Habit <id> already checked. Skipping."',
      );
    });

    test('gate 1 does not fire for an unchecked habit', () {
      final f = _Fixture();
      final habit = f.habit();
      _enterToday(habit, Entry.no);

      f.tray.show(habit, _sunday, 456);

      expect(
        f.systemTray.shown.length,
        1,
        reason: 'notifications.show-gating#3 — a habit whose entry is NO is '
            'not completed, so gate 1 lets it through',
      );
    });

    test('gate 2: a habit without a reminder is skipped', () {
      final f = _Fixture();
      final habit = f.habit();
      habit.reminder = null;

      f.tray.show(habit, _sunday, 456);

      expect(
        f.systemTray.shown,
        isEmpty,
        reason: 'notifications.show-gating#4 — hasReminder() == false skips '
            'the notification',
      );
      expect(
        f.systemTray.logs,
        contains('Habit 5 does not have a reminder. Skipping.'),
        reason: 'notifications.show-gating#4 — the skip is logged as '
            '"Habit <id> does not have a reminder. Skipping."',
      );
    });

    test('gate 3: an archived habit is skipped', () {
      final f = _Fixture();
      final habit = f.habit();
      habit.isArchived = true;

      f.tray.show(habit, _sunday, 456);

      expect(
        f.systemTray.shown,
        isEmpty,
        reason: 'notifications.show-gating#5 — isArchived skips the '
            'notification',
      );
      expect(
        f.systemTray.logs,
        contains('Habit 5 is archived. Skipping.'),
        reason: 'notifications.show-gating#5 — the skip is logged as '
            '"Habit <id> is archived. Skipping."',
      );
    });

    test('gate 4: a habit whose reminder excludes the date is skipped', () {
      final f = _Fixture();
      final habit = f.habit();
      // Every weekday except index 1 (Sunday).
      habit.reminder = Reminder(8, 30, WeekdayList(127 - 2));

      f.tray.show(habit, _sunday, 456);

      expect(
        f.systemTray.shown,
        isEmpty,
        reason: 'notifications.show-gating#6 — a date outside the reminder\'s '
            'weekday set skips the notification',
      );
      expect(
        f.systemTray.logs,
        contains('Habit 5 not supposed to run today. Skipping.'),
        reason: 'notifications.show-gating#6 — the skip is logged as '
            '"Habit <id> not supposed to run today. Skipping."',
      );
    });

    test('gates run in order: completed wins over archived', () {
      final f = _Fixture();
      final habit = f.habit();
      _enterToday(habit, Entry.yesManual);
      habit.isArchived = true;
      habit.reminder = null;

      f.tray.show(habit, _sunday, 456);

      expect(
        f.systemTray.logs.last,
        'Habit 5 already checked. Skipping.',
        reason: 'notifications.show-gating#3 — gate 1 runs before gates 2, 3 '
            'and 4, so its message is the only skip logged',
      );
    });

    test('the weekday index is (daysSinceSunday + 1) % 7', () {
      const expectedIndex = <DayOfWeek, int>{
        DayOfWeek.sunday: 1,
        DayOfWeek.monday: 2,
        DayOfWeek.tuesday: 3,
        DayOfWeek.wednesday: 4,
        DayOfWeek.thursday: 5,
        DayOfWeek.friday: 6,
        DayOfWeek.saturday: 0,
      };

      expect(
        _sunday.dayOfWeek,
        DayOfWeek.sunday,
        reason: 'notifications.show-gating#7 — anchor: 2015-01-25 is a Sunday',
      );

      for (var offset = 0; offset < 7; offset++) {
        final date = _sunday.plus(offset);
        final weekday = date.dayOfWeek;
        for (var index = 0; index < 7; index++) {
          final f = _Fixture();
          final habit = f.habit();
          habit.reminder = Reminder(8, 30, WeekdayList(1 << index));

          f.tray.show(habit, date, 456);

          expect(
            f.systemTray.shown.length,
            index == expectedIndex[weekday] ? 1 : 0,
            reason: 'notifications.show-gating#7 — reminder.days.toArray()'
                '[(date.dayOfWeek.daysSinceSunday + 1) % 7] decides; '
                '$weekday maps to index ${expectedIndex[weekday]}, so a '
                'reminder set only on index $index '
                '${index == expectedIndex[weekday] ? "shows" : "skips"}',
          );
        }
      }
    });

    test('the weekday test uses the notification date, not today', () {
      // Today is Sunday 2015-01-25; the alarm targets Saturday 2015-01-31.
      final saturday = LocalDate.ymd(2015, 1, 31);
      expect(
        saturday.dayOfWeek,
        DayOfWeek.saturday,
        reason: 'notifications.show-gating#8 — anchor: 2015-01-31 is a '
            'Saturday, a different weekday from today',
      );

      final onSaturday = _Fixture();
      final habitA = onSaturday.habit();
      habitA.reminder = Reminder(8, 30, WeekdayList(1 << 0));
      onSaturday.tray.show(habitA, saturday, 456);

      expect(
        onSaturday.systemTray.shown.length,
        1,
        reason: 'notifications.show-gating#8 — a Saturday-only reminder shows '
            'for a Saturday notification date even though today is Sunday',
      );

      final onSunday = _Fixture();
      final habitB = onSunday.habit();
      habitB.reminder = Reminder(8, 30, WeekdayList(1 << 1));
      onSunday.tray.show(habitB, saturday, 456);

      expect(
        onSunday.systemTray.shown,
        isEmpty,
        reason: 'notifications.show-gating#8 — a Sunday-only reminder is '
            'skipped for a Saturday notification date even though today is '
            'Sunday',
      );
    });

    test('showNotification receives habit, id, date and reminderTime', () {
      final f = _Fixture();
      final habit = f.habit();

      f.tray.show(habit, _sunday, 456);

      final shown = f.systemTray.shown.single;
      expect(
        identical(shown.habit, habit),
        isTrue,
        reason: 'notifications.show-gating#9 — the habit is handed to '
            'systemTray.showNotification unchanged',
      );
      expect(
        shown.notificationId,
        5,
        reason: 'notifications.show-gating#9 — the notification id computed by '
            'getNotificationId is passed along',
      );
      expect(
        shown.date,
        _sunday,
        reason: 'notifications.show-gating#9 — the notification date is passed '
            'along',
      );
      expect(
        shown.reminderTime,
        456,
        reason: 'notifications.show-gating#9 — the reminder instant is passed '
            'along',
      );
      expect(
        f.systemTray.logs.first,
        'Showing notification for habit=5',
        reason: 'notifications.show-gating#9 — "Showing notification for '
            'habit=<id>" is logged before the gates run',
      );
    });

    test('the "Showing notification" line is logged even when a gate skips',
        () {
      final f = _Fixture();
      final habit = f.habit();
      habit.isArchived = true;

      f.tray.show(habit, _sunday, 456);

      expect(
        f.systemTray.logs,
        <String>[
          'Showing notification for habit=5',
          'Habit 5 is archived. Skipping.',
        ],
        reason: 'notifications.show-gating#9 — the log line comes first, then '
            'the gate that skipped',
      );
    });

    test('isCompletedToday for a NUMERICAL AT_LEAST habit', () {
      final f = _Fixture();
      final habit = f.habit();
      habit.type = HabitType.numerical;
      habit.targetType = NumericalHabitType.atLeast;
      habit.targetValue = 2.0;
      _enterToday(habit, 1999);

      expect(
        habit.isCompletedToday(),
        isFalse,
        reason: 'notifications.show-gating#10 — AT_LEAST is completed only '
            'when value / 1000.0 >= targetValue; 1999/1000 < 2.0',
      );

      _enterToday(habit, 2000);

      expect(
        habit.isCompletedToday(),
        isTrue,
        reason: 'notifications.show-gating#10 — 2000/1000 >= 2.0 is completed',
      );

      f.tray.show(habit, _sunday, 456);

      expect(
        f.systemTray.shown,
        isEmpty,
        reason: 'notifications.show-gating#10 — a completed AT_LEAST habit is '
            'stopped by gate 1',
      );
    });

    test('isCompletedToday for a YES_NO habit', () {
      final f = _Fixture();
      final habit = f.habit();

      expect(
        habit.isCompletedToday(),
        isFalse,
        reason: 'notifications.show-gating#10 — YES_NO with UNKNOWN (-1) is '
            'not completed',
      );

      _enterToday(habit, Entry.no);
      expect(
        habit.isCompletedToday(),
        isFalse,
        reason: 'notifications.show-gating#10 — YES_NO with NO (0) is not '
            'completed',
      );

      _enterToday(habit, Entry.yesManual);
      expect(
        habit.isCompletedToday(),
        isTrue,
        reason: 'notifications.show-gating#10 — YES_NO with any value other '
            'than NO and UNKNOWN is completed',
      );

      _enterToday(habit, Entry.skip);
      expect(
        habit.isCompletedToday(),
        isTrue,
        reason: 'notifications.show-gating#10 — SKIP (3) also counts as '
            'completed for YES_NO habits',
      );
    });

    test('an AT_MOST habit always gets its reminder', () {
      final f = _Fixture();
      final habit = f.habit();
      habit.type = HabitType.numerical;
      habit.targetType = NumericalHabitType.atMost;
      habit.targetValue = 2.0;
      _enterToday(habit, 100000);

      expect(
        habit.isCompletedToday(),
        isFalse,
        reason: 'notifications.show-gating#10 — isCompletedToday() always '
            'returns false for AT_MOST habits',
      );

      f.tray.show(habit, _sunday, 456);

      expect(
        f.systemTray.shown.length,
        1,
        reason: 'notifications.show-gating#11 — gate 1 never fires for AT_MOST '
            'habits, so the reminder always shows',
      );
      expect(
        f.systemTray.logs,
        isNot(contains('Habit 5 already checked. Skipping.')),
        reason: 'notifications.show-gating#11 — the "already checked" branch '
            'is unreachable for AT_MOST habits',
      );
    });
  });

  // -------------------------------------------------------------------------
  // notifications.id-and-registry
  // -------------------------------------------------------------------------

  group('notifications.id-and-registry', () {
    test('the notification id is habit.id % Int.MAX_VALUE', () {
      for (final entry in <int, int>{
        5: 5,
        2147483646: 2147483646,
        2147483647: 0,
        2147483650: 3,
        4294967294: 0,
      }.entries) {
        final f = _Fixture();
        final habit = f.habit(id: entry.key);

        f.tray.show(habit, _sunday, 456);

        expect(
          f.systemTray.shown.single.notificationId,
          entry.value,
          reason: 'notifications.id-and-registry#1 — getNotificationId(habit) '
              'is (habit.id % Int.MAX_VALUE).toInt(); '
              '${entry.key} % 2147483647 == ${entry.value}',
        );
      }
    });

    test('the notification id is 0 when habit.id is null', () {
      final f = _Fixture();
      final habit = f.habit(id: null);

      f.tray.show(habit, _sunday, 456);

      expect(
        f.systemTray.shown.single.notificationId,
        0,
        reason: 'notifications.id-and-registry#1 — getNotificationId returns 0 '
            'when habit.id is null',
      );

      f.tray.cancel(habit);

      expect(
        f.systemTray.removed,
        <int>[0],
        reason: 'notifications.id-and-registry#1 — cancel uses the same id',
      );
    });

    test('active holds every notification currently shown', () {
      final f = _Fixture();
      final h1 = f.habit(id: 1, name: 'Meditate');
      final h2 = f.habit(id: 2, name: 'Wake up early');

      f.tray.show(h1, _sunday, 100);
      f.tray.show(h2, _sunday, 200);
      f.systemTray.shown.clear();

      f.tray.reshowAll();

      expect(
        f.systemTray.shown.map((s) => s.notificationId).toList(),
        <int>[1, 2],
        reason: 'notifications.id-and-registry#2 — the `active` map holds one '
            'entry per shown notification',
      );
    });

    test('cancel removes the notification and clears the registry entry', () {
      final f = _Fixture();
      final habit = f.habit();

      f.tray.show(habit, _sunday, 456);
      f.systemTray.shown.clear();

      f.tray.cancel(habit);

      expect(
        f.systemTray.removed,
        <int>[5],
        reason: 'notifications.id-and-registry#3 — cancel calls '
            'systemTray.removeNotification(getNotificationId(habit))',
      );

      f.tray.reshow(habit);
      f.tray.reshowAll();

      expect(
        f.systemTray.shown,
        isEmpty,
        reason: 'notifications.id-and-registry#3 — the habit is removed from '
            '`active`, so neither reshow nor reshowAll finds it again',
      );
    });

    test('reshow re-runs the task with the stored data', () {
      final f = _Fixture();
      final habit = f.habit();

      f.tray.show(habit, _sunday, 456);
      f.systemTray.shown.clear();

      f.tray.reshow(habit);

      final shown = f.systemTray.shown.single;
      expect(
        shown.date,
        _sunday,
        reason: 'notifications.id-and-registry#4 — reshow reuses the stored '
            'NotificationData date',
      );
      expect(
        shown.reminderTime,
        456,
        reason: 'notifications.id-and-registry#4 — reshow reuses the stored '
            'NotificationData reminderTime',
      );
    });

    test('reshow does nothing for a habit that was never shown', () {
      final f = _Fixture();
      final habit = f.habit();

      f.tray.reshow(habit);

      expect(
        f.systemTray.shown,
        isEmpty,
        reason: 'notifications.id-and-registry#4 — reshow is a no-op when the '
            'habit is absent from `active`',
      );
    });

    test('reshow re-applies the gates', () {
      final f = _Fixture();
      final habit = f.habit();

      f.tray.show(habit, _sunday, 456);
      f.systemTray.shown.clear();
      habit.isArchived = true;

      f.tray.reshow(habit);

      expect(
        f.systemTray.shown,
        isEmpty,
        reason: 'notifications.id-and-registry#4 — reshow runs a whole '
            'ShowNotificationTask, gates included',
      );
    });

    test('reshowAll re-runs the task for every active entry', () {
      final f = _Fixture();
      final h1 = f.habit(id: 1, name: 'Meditate');
      final h2 = f.habit(id: 2, name: 'Wake up early');

      f.tray.show(h1, _sunday, 100);
      f.tray.show(h2, LocalDate.ymd(2015, 1, 26), 200);
      f.systemTray.shown.clear();

      f.tray.reshowAll();

      expect(
        f.systemTray.shown.length,
        2,
        reason: 'notifications.id-and-registry#5 — reshowAll runs one task per '
            'entry of `active`',
      );
      expect(
        f.systemTray.shown.map((s) => s.reminderTime).toList(),
        <int>[100, 200],
        reason: 'notifications.id-and-registry#5 — each entry keeps its own '
            'NotificationData',
      );
    });

    test('the registry is keyed by habit id', () {
      final f = _Fixture();
      final habit = f.habit();

      f.tray.show(habit, _sunday, 456);
      f.systemTray.shown.clear();

      // Mutating a model field changes Habit's value equality and hash code.
      habit.name = 'Renamed';

      f.tray.reshow(habit);

      expect(
        f.systemTray.shown.length,
        1,
        reason: 'notifications.id-and-registry#7 — the Dart port keys `active` '
            'by habit id, so a mutated habit is still found',
      );

      final sameId = f.habit(id: 5, name: 'A different instance');
      f.systemTray.shown.clear();

      f.tray.reshow(sameId);

      expect(
        f.systemTray.shown.length,
        1,
        reason: 'notifications.id-and-registry#7 — any habit with the same id '
            'resolves to the same registry entry',
      );

      f.tray.cancel(sameId);
      f.systemTray.shown.clear();
      f.tray.reshowAll();

      expect(
        f.systemTray.shown,
        isEmpty,
        reason: 'notifications.id-and-registry#7 — cancelling by id clears the '
            'entry created by the original instance',
      );
    });
  });

  // -------------------------------------------------------------------------
  // notifications.content
  // -------------------------------------------------------------------------

  group('notifications.content', () {
    test('the reminders channel id is the constant "REMINDERS"', () {
      expect(
        NotificationTray.remindersChannelId,
        'REMINDERS',
        reason: 'notifications.content#1 — channel id is the constant '
            'NotificationTray.REMINDERS_CHANNEL_ID == "REMINDERS"',
      );
    });
  });

  // -------------------------------------------------------------------------
  // notifications.sticky-and-dismiss
  // -------------------------------------------------------------------------

  group('notifications.sticky-and-dismiss', () {
    test('shouldMakeNotificationsSticky reads pref_sticky_notifications', () {
      final storage = MemoryStorage();
      final preferences = Preferences(storage);

      expect(
        preferences.shouldMakeNotificationsSticky(),
        isFalse,
        reason: 'notifications.sticky-and-dismiss#1 — the default of '
            '"pref_sticky_notifications" is false',
      );

      storage.putBoolean('pref_sticky_notifications', true);

      expect(
        preferences.shouldMakeNotificationsSticky(),
        isTrue,
        reason: 'notifications.sticky-and-dismiss#1 — the value is read from '
            'the boolean key "pref_sticky_notifications"',
      );
    });

    test('setNotificationsSticky writes the key and notifies listeners', () {
      final storage = MemoryStorage();
      final preferences = Preferences(storage);
      final listener = _CountingPreferencesListener();
      preferences.addListener(listener);

      preferences.setNotificationsSticky(true);

      expect(
        storage.getBoolean('pref_sticky_notifications', false),
        isTrue,
        reason: 'notifications.sticky-and-dismiss#2 — setNotificationsSticky '
            'writes "pref_sticky_notifications"',
      );
      expect(
        listener.notificationsChanged,
        1,
        reason: 'notifications.sticky-and-dismiss#2 — it then fires '
            'onNotificationsChanged() on every registered listener',
      );

      preferences.setNotificationsSticky(false);

      expect(
        storage.getBoolean('pref_sticky_notifications', true),
        isFalse,
        reason: 'notifications.sticky-and-dismiss#2 — turning it off writes '
            'the same key',
      );
      expect(
        listener.notificationsChanged,
        2,
        reason: 'notifications.sticky-and-dismiss#2 — every write notifies',
      );
    });

    test('onNotificationsChanged reshows every active notification', () {
      final f = _Fixture();
      final h1 = f.habit(id: 1, name: 'Meditate');
      final h2 = f.habit(id: 2, name: 'Wake up early');

      f.tray.show(h1, _sunday, 100);
      f.tray.show(h2, _sunday, 200);
      f.systemTray.shown.clear();

      f.tray.onNotificationsChanged();

      expect(
        f.systemTray.shown.length,
        2,
        reason: 'notifications.sticky-and-dismiss#3 — NotificationTray.'
            'onNotificationsChanged() calls reshowAll()',
      );
    });

    test('toggling the preference reshows through the listener registration',
        () {
      final f = _Fixture();
      final habit = f.habit();
      f.tray.startListening();

      f.tray.show(habit, _sunday, 456);
      f.systemTray.shown.clear();

      f.preferences.setNotificationsSticky(true);

      expect(
        f.systemTray.shown.length,
        1,
        reason: 'notifications.sticky-and-dismiss#3 — the tray registers as a '
            'Preferences.Listener, so flipping the setting immediately '
            're-posts every active notification',
      );

      f.tray.stopListening();
      f.systemTray.shown.clear();
      f.preferences.setNotificationsSticky(false);

      expect(
        f.systemTray.shown,
        isEmpty,
        reason: 'notifications.sticky-and-dismiss#3 — stopListening '
            'unregisters the tray from Preferences',
      );
    });

    test('onDismiss reshows when sticky is on and cancels when it is off', () {
      final f = _Fixture();
      final tray = _RecordingTray(
        f.taskRunner,
        f.commandRunner,
        f.preferences,
        f.systemTray,
        f.order,
      );
      final controller = ReminderController(
        _FakeScheduler(f.order),
        tray,
        f.preferences,
      );
      final habit = f.habit();

      f.preferences.setNotificationsSticky(false);
      controller.onDismiss(habit);

      expect(
        tray.cancelCalls,
        <Habit>[habit],
        reason: 'notifications.sticky-and-dismiss#5 — with sticky off, '
            'onDismiss calls notificationTray.cancel(habit)',
      );
      expect(
        tray.reshowCalls,
        isEmpty,
        reason: 'notifications.sticky-and-dismiss#5 — with sticky off nothing '
            'is reshown',
      );

      f.preferences.setNotificationsSticky(true);
      controller.onDismiss(habit);

      expect(
        tray.reshowCalls,
        <Habit>[habit],
        reason: 'notifications.sticky-and-dismiss#5 — with sticky on, '
            'onDismiss calls notificationTray.reshow(habit), the Android 14+ '
            'workaround',
      );
      expect(
        tray.cancelCalls.length,
        1,
        reason: 'notifications.sticky-and-dismiss#5 — the sticky branch does '
            'not also cancel',
      );
    });
  });

  // -------------------------------------------------------------------------
  // reminders.on-show-reminder
  // -------------------------------------------------------------------------

  group('reminders.on-show-reminder', () {
    test('onShowReminder shows the notification first, then reschedules', () {
      final f = _Fixture();
      final scheduler = _FakeScheduler(f.order);
      final tray = _RecordingTray(
        f.taskRunner,
        f.commandRunner,
        f.preferences,
        f.systemTray,
        f.order,
      );
      final controller = ReminderController(scheduler, tray, f.preferences);
      final habit = f.habit();

      controller.onShowReminder(habit, _sunday, 456);

      expect(
        f.order,
        <String>['show', 'scheduleAll'],
        reason: 'reminders.on-show-reminder#1 — notificationTray.show is '
            'called FIRST and reminderScheduler.scheduleAll() second',
      );
      expect(
        tray.showCalls,
        <Habit>[habit],
        reason: 'reminders.on-show-reminder#1 — show receives the habit',
      );
    });

    test('every firing re-arms exactly once', () {
      final f = _Fixture();
      final scheduler = _FakeScheduler(f.order);
      final tray = _RecordingTray(
        f.taskRunner,
        f.commandRunner,
        f.preferences,
        f.systemTray,
        f.order,
      );
      final controller = ReminderController(scheduler, tray, f.preferences);
      final habit = f.habit();

      controller.onShowReminder(habit, _sunday, 456);
      controller.onShowReminder(habit, _sunday.plus(1), 457);
      controller.onShowReminder(habit, _sunday.plus(2), 458);

      expect(
        scheduler.scheduleAllCount,
        3,
        reason: 'reminders.on-show-reminder#2 — the app never uses repeating '
            'alarms: each firing re-arms the next one with one scheduleAll()',
      );
      expect(
        f.order,
        <String>['show', 'scheduleAll', 'show', 'scheduleAll', 'show',
            'scheduleAll'],
        reason: 'reminders.on-show-reminder#2 — the re-arm happens once per '
            'firing, immediately after the notification is shown',
      );
    });

    test('ReminderControllerTest.testOnShowReminder', () {
      final f = _Fixture();
      final scheduler = _FakeScheduler(f.order);
      final tray = _RecordingTray(
        f.taskRunner,
        f.commandRunner,
        f.preferences,
        f.systemTray,
        f.order,
      );
      final controller = ReminderController(scheduler, tray, f.preferences);
      final habit = f.habit();
      final date = LocalDate.ymd(2015, 1, 25);

      controller.onShowReminder(habit, date, 456);

      expect(
        tray.showCalls,
        <Habit>[habit],
        reason: 'reminders.on-show-reminder#4 — verify { notificationTray.show'
            '(habit, date, 456) }',
      );
      expect(
        tray.showDates,
        <LocalDate>[date],
        reason: 'reminders.on-show-reminder#4 — the date is LocalDate'
            '(2015, 1, 25)',
      );
      expect(
        tray.showReminderTimes,
        <int>[456],
        reason: 'reminders.on-show-reminder#4 — the reminderTime is 456',
      );
      expect(
        scheduler.scheduleAllCount,
        1,
        reason: 'reminders.on-show-reminder#4 — verify { reminderScheduler.'
            'scheduleAll() }',
      );
    });
  });
}
