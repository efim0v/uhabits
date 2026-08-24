/// `audit4.tapping-a-boolean-checkmark-widget-now`: a tap on a boolean
/// Checkmark widget must flip the card where it stands.
///
/// Upstream the tap is a broadcast. `WidgetReceiver` runs
/// `WidgetBehavior.onToggleRepetition` inside the app's process, the provider
/// redraws, and nothing at all appears on screen — which is the entire point of
/// the widget. The port turned it into an activity launch: `WidgetIntents.
/// toggleCheckmark` builds `HomeWidgetLaunchIntent.getActivity(...)`, so every
/// tick of a checkbox threw the user into the app.
///
/// ## What replaces the broadcast, and why it is not a background isolate
///
/// The obvious substitute — `HomeWidgetBackgroundIntent` plus
/// `HomeWidget.registerInteractivityCallback`, which runs Dart in a background
/// isolate — cannot work here. `HomeWidgetBackgroundService` builds a bare
/// `FlutterEngine` and never runs `GeneratedPluginRegistrant`, so that isolate
/// has no `path_provider` to resolve the database directory with and no
/// `sqflite`/`sqlite3` channel behind `AppDatabase`. The callback would be
/// handed a URI and have nothing to open.
///
/// So the write is staged instead, and iOS is where it is staged from because
/// iOS is where the platform offers an in-place tap: a widget `Button(intent:)`
/// runs an `AppIntent` inside the extension without foregrounding anything.
/// The intent does two things — it records the tap in the App Group, and it
/// advances the value the card draws so the checkmark flips immediately — and
/// the app applies the recorded taps through `CommandRunner` at its next
/// publish, which happens at startup, on every resume, after every command and
/// at the day rollover.
///
/// One writer is preserved: the entry is still created by
/// `WidgetBehavior.onToggleRepetition` on the `CommandRunner`, so the list
/// cache, the notification tray, the reminder scheduler and the widget updater
/// all learn about it and the change is undoable. What the extension writes is
/// a *request*, never an entry.
///
/// ## What is asserted
///
/// The Dart half runs: a staged tap is applied, exactly once, through the
/// command runner. The Swift half is read from the file — an `AppIntent` in a
/// widget extension cannot be executed by `flutter test` — and what is read is
/// that the tap is a `Button(intent:)` that does not open the app, and that the
/// value it paints follows `Entry.nextToggleValue` with the two preferences the
/// index now publishes.
library;

// The core is reached by its `src` path, exactly as lib/state does.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits/state/widget_sync.dart';
import 'package:uhabits/state/widget_toggle_queue.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';
import 'package:uhabits_core/src/utils/midnight_timer.dart';

// ---------------------------------------------------------------------------
// Locating the iOS source set
// ---------------------------------------------------------------------------

final Directory appDir = _findApp();
final Directory widgetDir = Directory('${appDir.path}/ios/HabitsWidget');

Directory _findApp() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String prefix in <String>['', '/app']) {
      final Directory candidate = Directory('${dir.path}$prefix');
      if (File('${candidate.path}/ios/HabitsWidget/WidgetData.swift')
          .existsSync()) {
        return candidate;
      }
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('app/ not found from ${Directory.current.path}');
}

String swift(String name) => File('${widgetDir.path}/$name').readAsStringSync();

const String rule =
    'audit4.tapping-a-boolean-checkmark-widget-now#1 — In the Kotlin app: The '
    'tap is a broadcast: `WidgetReceiver` runs '
    '`WidgetBehavior.onToggleRepetition` and the widget flips in place. Nothing '
    'opens, the user stays on the home screen — which is the entire point of '
    'the Checkmark widget.';

const String collapseRule =
    'audit10.ios-widget-taps-collapse#1 — In the Kotlin app: Each widget tap '
    'is its own `ACTION_TOGGLE_REPETITION` broadcast, and '
    '`WidgetBehavior.onToggleRepetition` re-reads '
    '`habit.originalEntries.get(date)` before computing `nextToggleValue`. '
    'Successive taps on the same habit and day therefore each start from the '
    'value the previous one wrote and walk the cycle one step at a time: '
    'UNKNOWN -> YES_MANUAL -> NO by default, UNKNOWN -> YES_MANUAL -> SKIP -> '
    'NO with skip enabled.';

void main() {
  // -----------------------------------------------------------------------
  // Fixtures
  // -----------------------------------------------------------------------

  late MemoryModelFactory modelFactory;
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late MemoryStorage storage;
  late Preferences preferences;
  late CommandRunner commandRunner;
  late TaskRunner taskRunner;
  final Logging logging = StandardLogging(out: StringBuffer(), err: StringBuffer());
  late NotificationTray tray;
  late WidgetBehavior behavior;
  late FakeWidgetDataStore store;
  late WidgetToggleQueue queue;
  late FakePlatform platform;
  late WidgetSync sync;

  /// The whole harness, over one [Dispatcher] pair.
  ///
  /// Parameterised because the dispatcher is not an implementation detail of
  /// this feature: `UnconfinedTestDispatcher` runs every command inline, so a
  /// drain that reads the model between taps sees the previous tap's write
  /// whether or not the code was written to. Production wires
  /// [AsyncDispatcher] (`AppScope.open`), where a command runs two event-loop
  /// turns after `CommandRunner.run` returns — which is the arrangement
  /// `audit10.ios-widget-taps-collapse#1` is about.
  void buildHarness(Dispatcher dispatcher) {
    modelFactory = MemoryModelFactory();
    habitList = MemoryHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    storage = MemoryStorage();
    preferences = Preferences(storage);
    taskRunner = CoroutineTaskRunner(
      mainDispatcher: dispatcher,
      ioDispatcher: dispatcher,
    );
    commandRunner = CommandRunner(taskRunner);
    tray = NotificationTray(
      taskRunner,
      commandRunner,
      preferences,
      _NullSystemTray(),
    );
    behavior = WidgetBehavior(
      habitList: habitList,
      commandRunner: commandRunner,
      notificationTray: tray,
      preferences: preferences,
    );
    store = FakeWidgetDataStore();
    queue = WidgetToggleQueue(
      store: store,
      habitList: habitList,
      behavior: behavior,
    );
    platform = FakePlatform();
    sync = WidgetSync(
      bridge: HomeWidgetBridge(
        habitList: habitList,
        registry: WidgetRegistry(storage),
        platform: platform,
        preferences: preferences,
      ),
      commandRunner: commandRunner,
      taskRunner: taskRunner,
      midnightTimer: MidnightTimer(logging, preferences),
      preferences: preferences,
      pendingToggles: queue,
    );
  }

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 26));
    buildHarness(const UnconfinedTestDispatcher());
  });

  Habit addHabit() {
    final Habit habit = fixtures.createEmptyHabit(name: 'Meditate');
    habitList.add(habit);
    return habit;
  }

  /// One tap, as `ToggleHabitIntent.perform()` records it.
  void stageTap(int habitId, {int seq = 1, String date = '2015-01-26'}) {
    store.data[WidgetToggleQueue.key] = jsonEncode(<String, Object?>{
      'version': WidgetToggleQueue.schemaVersion,
      'toggles': <Object?>[
        <String, Object?>{'seq': seq, 'habit': habitId, 'date': date},
      ],
    });
  }

  // =======================================================================
  // The app side: a staged tap becomes a command
  // =======================================================================

  group('audit4.tapping-a-boolean-checkmark-widget-now', () {
    test('#1 a staged tap runs onToggleRepetition at the next publish',
        () async {
      final Habit habit = addHabit();
      final LocalDate today = getToday();
      stageTap(habit.id!);

      await sync.updateWidgets();
      await sync.settle();

      expect(habit.originalEntries.get(today).value, Entry.yesManual,
          reason: '$rule The tap that the extension recorded has to end in '
              '`WidgetBehavior.onToggleRepetition` on the CommandRunner — the '
              'one writer — or the home screen and the database disagree for '
              'as long as the app stays closed.');
      expect(store.data[WidgetToggleQueue.key], isNot(contains('"seq":1')),
          reason: '$rule An applied tap leaves the queue, or the next publish '
              'toggles the habit a second time.');
    });

    test('#1 the same tap is never applied twice', () async {
      final Habit habit = addHabit();
      final LocalDate today = getToday();
      stageTap(habit.id!);

      await sync.updateWidgets();
      await sync.settle();
      await sync.updateWidgets();
      await sync.settle();

      expect(habit.originalEntries.get(today).value, Entry.yesManual,
          reason: '$rule Draining is idempotent: the queue is the record of '
              'taps not yet applied, and a publish that runs twice must not '
              'walk the value cycle twice.');
    });

    test('#1 two taps walk the cycle twice, in order', () async {
      final Habit habit = addHabit();
      final LocalDate today = getToday();
      preferences.isSkipEnabled = true;
      store.data[WidgetToggleQueue.key] = jsonEncode(<String, Object?>{
        'version': WidgetToggleQueue.schemaVersion,
        'toggles': <Object?>[
          <String, Object?>{'seq': 1, 'habit': habit.id, 'date': '2015-01-26'},
          <String, Object?>{'seq': 2, 'habit': habit.id, 'date': '2015-01-26'},
        ],
      });

      await sync.updateWidgets();
      await sync.settle();

      expect(habit.originalEntries.get(today).value, Entry.skip,
          reason: '$rule `widgets.checkmark#9` — repeated taps walk UNKNOWN -> '
              'YES_MANUAL -> SKIP with skip enabled. Two taps while the app '
              'was closed are two toggles, not one.');
    });

    test('#1 a tap for a habit that no longer exists is dropped', () async {
      addHabit();
      stageTap(4242);

      await sync.updateWidgets();
      await sync.settle();

      expect(store.data[WidgetToggleQueue.key], isNot(contains('4242')),
          reason: '$rule A tap on a widget whose habit was deleted between the '
              'tap and the next launch has nowhere to land; leaving it queued '
              'would retry it on every publish forever.');
    });

    test('#1 the index publishes the two preferences the flip depends on',
        () async {
      addHabit();
      preferences
        ..isSkipEnabled = true
        ..areQuestionMarksEnabled = true;

      await sync.updateWidgets();
      await sync.settle();

      final Map<String, Object?> index = jsonDecode(
          platform.data[HomeWidgetBridge.indexKey]!) as Map<String, Object?>;
      expect(index['isSkipEnabled'], isTrue,
          reason: '$rule `widgets.behavior#3` computes the next value from '
              '`isSkipEnabled` and `areQuestionMarksEnabled`. The extension '
              'paints that value the instant the finger lifts, so it has to '
              'read the same two preferences — otherwise a user with skip '
              'disabled watches the card show SKIP and then correct itself to '
              'NO when the app next runs.');
      expect(index['areQuestionMarksEnabled'], isTrue, reason: rule);
    });
  });

  // =======================================================================
  // The extension side: the tap opens nothing
  // =======================================================================

  group('audit4.tapping-a-boolean-checkmark-widget-now (extension)', () {
    test('#1 the boolean card is a Button, not a link into the app', () {
      final String source = swift('CheckmarkWidget.swift');

      expect(source, contains('Button(intent: ToggleHabitIntent('),
          reason: '$rule A `widgetURL` foregrounds the app; a '
              '`Button(intent:)` runs inside the widget extension and shows '
              'nothing. That is the difference this rule is about.');
      expect(source, contains('habit.isNumerical'),
          reason: '$rule …and only the boolean half toggles: '
              '`widgets.checkmark#7` opens the value picker for a measurable '
              'habit, which is an app screen and always was.');
    });

    test('#1 the intent stages the tap and redraws, and opens nothing', () {
      final String source = swift('WidgetData.swift');

      expect(source, contains('struct ToggleHabitIntent'),
          reason: '$rule The intent is what runs in place of the broadcast.');
      expect(source, contains('openAppWhenRun'),
          reason: '$rule An AppIntent that does not say otherwise may bring '
              'the app forward; saying `openAppWhenRun = false` is what keeps '
              'the user on the home screen.');
      expect(RegExp(r'openAppWhenRun\s*:?\s*Bool?\s*=?\s*false|'
              r'openAppWhenRun = false')
          .hasMatch(source), isTrue, reason: rule);
      expect(source, contains('WidgetCenter.shared.reloadAllTimelines'),
          reason: '$rule The provider redraws after the broadcast upstream, '
              'and `WidgetUpdater.updateWidgets(habitId)` refreshes all six '
              'providers; here the intent asks WidgetKit for the same redraw.');

      // Both sides spell the key from the shared prefix, so the values are
      // compared rather than a literal grepped for.
      expect(source, contains(r'static let pendingKey = "\(keyPrefix).pending"'),
          reason: '$rule The tap is recorded under the key the app drains.');
      expect('${HomeWidgetBridge.keyPrefix}.pending', WidgetToggleQueue.key,
          reason: '$rule …and that is the key WidgetToggleQueue reads: one '
              'store, one prefix, one contract.');
    });

    test('#1 the card the extension paints is the value the app will write',
        () {
      final String source = swift('WidgetData.swift');
      final int start = source.indexOf('static func nextToggleValue');
      expect(start, isNonNegative,
          reason: '$rule The flip has to follow `Entry.nextToggleValue`, or '
              'the card shows one thing and the database records another.');
      final String body = source.substring(start, start + 900);

      // The four branches of Entry.nextToggleValue, in the core's own terms.
      expect(body, contains('isSkipEnabled'), reason: rule);
      expect(body, contains('areQuestionMarksEnabled'), reason: rule);
      expect(body, contains('EntryValue.yesAuto'), reason: rule);
      expect(body, contains('EntryValue.skip'), reason: rule);
      expect(body, contains('EntryValue.unknown'), reason: rule);
    });
  });

  // =======================================================================
  // The ordering contract, under the dispatchers production actually wires
  // =======================================================================

  group('audit10.ios-widget-taps-collapse', () {
    /// Every test here rebuilds the harness on [AsyncDispatcher], which is
    /// what `AppScope.open` passes to `CoroutineTaskRunner` for both roles.
    /// Under it `CommandRunner.run` returns before the command has run, so a
    /// drain that re-reads `habit.originalEntries` between taps reads the
    /// value the *previous* publish left, not the one the previous tap wrote.
    setUp(() => buildHarness(const AsyncDispatcher()));

    /// Runs the event loop until nothing is left in flight.
    ///
    /// `WidgetSync.settle()` awaits the publishes only. Under
    /// [AsyncDispatcher] the `CreateRepetitionCommand` a drain issues is a
    /// task-runner job of its own that outlives the publish that issued it,
    /// and finishing it schedules another publish — so quiescence is reached
    /// by alternating the two until both are empty, which is what the running
    /// app does between one tap and the next.
    Future<void> quiesce() async {
      for (int i = 0; i < 10; i++) {
        await sync.settle();
        await taskRunner.awaitAll();
        await Future<void>.delayed(Duration.zero);
      }
    }

    void stageTaps(int habitId, int count, {String date = '2015-01-26'}) {
      store.data[WidgetToggleQueue.key] = jsonEncode(<String, Object?>{
        'version': WidgetToggleQueue.schemaVersion,
        'toggles': <Object?>[
          for (int seq = 1; seq <= count; seq++)
            <String, Object?>{'seq': seq, 'habit': habitId, 'date': date},
        ],
      });
    }

    test('#1 two taps on the same day walk the cycle twice, not once',
        () async {
      final Habit habit = addHabit();
      final LocalDate today = getToday();
      stageTaps(habit.id!, 2);

      await sync.updateWidgets();
      await quiesce();

      expect(habit.originalEntries.get(today).value, Entry.no,
          reason: '$collapseRule Upstream each tap is its own '
              '`ACTION_TOGGLE_REPETITION` broadcast, and '
              '`WidgetBehavior.onToggleRepetition` re-reads '
              '`habit.originalEntries.get(date)` as its first statement — so '
              'tap 2 starts from what tap 1 wrote and the pair walks UNKNOWN '
              '-> YES_MANUAL -> NO. Landing on YES_MANUAL means the user who '
              'mis-tapped and tapped again to undo it watched the card '
              'un-tick and had the correction thrown away.');
    });

    test('#1 two taps with skip enabled reach SKIP', () async {
      final Habit habit = addHabit();
      final LocalDate today = getToday();
      preferences.isSkipEnabled = true;
      stageTaps(habit.id!, 2);

      await sync.updateWidgets();
      await quiesce();

      expect(habit.originalEntries.get(today).value, Entry.skip,
          reason: '$collapseRule `widgets.checkmark#9` — with skip enabled the '
              'cycle is UNKNOWN -> YES_MANUAL -> SKIP -> NO, and two taps is '
              'two steps along it whatever dispatcher the task runner was '
              'built from.');
    });

    test('#1 three taps walk three steps', () async {
      final Habit habit = addHabit();
      final LocalDate today = getToday();
      preferences.isSkipEnabled = true;
      stageTaps(habit.id!, 3);

      await sync.updateWidgets();
      await quiesce();

      expect(habit.originalEntries.get(today).value, Entry.no,
          reason: '$collapseRule A run of taps is a run of broadcasts '
              'upstream; the queue is only the delivery mechanism, so N '
              'staged taps have to be N advances.');
    });

    test('#1 each staged tap is its own command, in sequence order', () async {
      final Habit habit = addHabit();
      final _RecordingListener recorder = _RecordingListener();
      commandRunner.addListener(recorder);
      preferences.isSkipEnabled = true;
      stageTaps(habit.id!, 2);

      await sync.updateWidgets();
      await quiesce();

      expect(recorder.values, <int>[Entry.yesManual, Entry.skip],
          reason: '$collapseRule Each broadcast upstream runs one '
              '`CreateRepetitionCommand` through `CommandRunner`, so each is '
              'separately undoable and each notifies the list cache, the tray '
              'and the widget updater. Collapsing the run into one command — '
              'or into two commands carrying the same value — loses both.');
    });

    test('#1 taps on different habits are independent', () async {
      final Habit first = addHabit();
      final Habit second = fixtures.createEmptyHabit(name: 'Run');
      habitList.add(second);
      final LocalDate today = getToday();
      store.data[WidgetToggleQueue.key] = jsonEncode(<String, Object?>{
        'version': WidgetToggleQueue.schemaVersion,
        'toggles': <Object?>[
          <String, Object?>{'seq': 1, 'habit': first.id, 'date': '2015-01-26'},
          <String, Object?>{'seq': 2, 'habit': second.id, 'date': '2015-01-26'},
          <String, Object?>{'seq': 3, 'habit': first.id, 'date': '2015-01-26'},
        ],
      });

      await sync.updateWidgets();
      await quiesce();

      expect(first.originalEntries.get(today).value, Entry.no,
          reason: '$collapseRule Two taps on one habit walk two steps…');
      expect(second.originalEntries.get(today).value, Entry.yesManual,
          reason: '$collapseRule …and the single tap on the other habit walks '
              'exactly one, unaffected by its neighbours in the queue.');
    });

    test('#1 taps on different days are independent', () async {
      final Habit habit = addHabit();
      store.data[WidgetToggleQueue.key] = jsonEncode(<String, Object?>{
        'version': WidgetToggleQueue.schemaVersion,
        'toggles': <Object?>[
          <String, Object?>{'seq': 1, 'habit': habit.id, 'date': '2015-01-26'},
          <String, Object?>{'seq': 2, 'habit': habit.id, 'date': '2015-01-25'},
        ],
      });

      await sync.updateWidgets();
      await quiesce();

      expect(habit.originalEntries.get(LocalDate.ymd(2015, 1, 26)).value,
          Entry.yesManual,
          reason: '$collapseRule A tap carries its own date; two taps on '
              'different days are one advance each.');
      expect(habit.originalEntries.get(LocalDate.ymd(2015, 1, 25)).value,
          Entry.yesManual, reason: collapseRule);
    });

    test('#1 the queue is still drained exactly once', () async {
      final Habit habit = addHabit();
      final LocalDate today = getToday();
      stageTaps(habit.id!, 2);

      await sync.updateWidgets();
      await quiesce();
      await sync.updateWidgets();
      await quiesce();

      expect(store.data[WidgetToggleQueue.key], isNull,
          reason: '$collapseRule Applied taps leave the queue…');
      expect(habit.originalEntries.get(today).value, Entry.no,
          reason: '$collapseRule …and a second publish must not replay them.');
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// The App Group, reduced to a map: the same shape `HomeWidget.getWidgetData`
/// and `saveWidgetData` present, with none of the plugin.
class FakeWidgetDataStore implements WidgetDataStore {
  final Map<String, String?> data = <String, String?>{};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }
}

class FakePlatform implements HomeWidgetPlatform {
  final Map<String, String?> data = <String, String?>{};

  @override
  Future<void> saveWidgetData(String id, String? value) async {
    if (value == null) {
      data.remove(id);
    } else {
      data[id] = value;
    }
  }

  @override
  Future<void> updateWidget({
    required String name,
    required String qualifiedAndroidName,
    required String iOSName,
  }) async {}

  @override
  Future<void> setAppGroupId(String groupId) async {}
}

/// Every `CreateRepetitionCommand` the runner finished, in order, reduced to
/// the value it stored — which is what "one command per tap, walking the
/// cycle" means from outside.
class _RecordingListener implements CommandRunnerListener {
  final List<int> values = <int>[];

  @override
  void onCommandFinished(Command command) {
    if (command is CreateRepetitionCommand) values.add(command.value);
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
