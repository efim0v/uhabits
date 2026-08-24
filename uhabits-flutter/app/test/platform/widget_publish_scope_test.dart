/// `audit10.every-command-republishes-the-whole`: a checkmark tap rebuilds the
/// whole habit catalogue — score buckets, target windows, streaks and weekday
/// frequency, each over the habit's entire history — for every habit in the
/// list, not for the one the tap changed.
///
/// Upstream `WidgetUpdater.onCommandFinished` passes `command.habit.id` for a
/// `CreateRepetitionCommand` and null for everything else, and
/// `updateWidgets(modifiedHabitId, providerClass)` then does one cheap thing
/// per provider: ask `AppWidgetManager` for that provider's widget ids, keep
/// the ones whose `widgetPrefs.getHabitIdsFromWidgetId(w)` contains the id, and
/// broadcast `ACTION_APPWIDGET_UPDATE` with the survivors. No habit is read and
/// no presenter runs — `HistoryCardPresenter`, `ScoreCardPresenter`,
/// `TargetCardPresenter`, `streaks.getBest`, `computeWeekdayFrequency` all run
/// later, in the provider, and only for the widgets that were named. So the
/// per-tap cost upstream is bounded by the habit that changed.
///
/// The port cannot broadcast; it publishes documents. [HomeWidgetBridge.publish]
/// already filters the per-widget documents by `modifiedHabitId`, but
/// `buildIndexDocument` rebuilt every habit in the catalogue unconditionally,
/// so a tap on one habit paid for all of them — on the single Dart isolate,
/// before the platform write. Its own sibling listener does the opposite:
/// `HabitCardListCache.onCommandFinished` refreshes exactly one habit for a
/// `CreateRepetitionCommand`.
///
/// ## What this file asserts
///
/// Two halves, and the second is the more important one. That the filtered
/// publish rebuilds only the habit the command named — and that it nevertheless
/// writes byte-for-byte what the unfiltered publish would have written, because
/// a cheaper publish that drops an update is a worse defect than an expensive
/// one. Every input a habit document is *not* keyed by the modified habit —
/// the logical day, the first weekday, the score bucket the user chose — puts
/// the publish back on the unfiltered path.
library;

// The bridge reaches the core by its `src` path, exactly as
// lib/state/app_scope.dart does.
// ignore_for_file: implementation_imports

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';

const String rule1 =
    'audit10.every-command-republishes-the-whole#1 — In the Kotlin app: '
    '`WidgetUpdater.onCommandFinished` passes `command.habit.id` for a '
    '`CreateRepetitionCommand` and null for every other command, and '
    '`updateWidgets(modifiedHabitId, providerClass)` then asks '
    '`AppWidgetManager` for the provider\'s widget ids, keeps the ones bound '
    'to that habit, and broadcasts `ACTION_APPWIDGET_UPDATE` to them. It reads '
    'no habit and runs no presenter: `HistoryCardPresenter`, '
    '`ScoreCardPresenter`, `TargetCardPresenter`, `streaks.getBest` and '
    '`computeWeekdayFrequency` run afterwards, inside the provider, only for '
    'the widgets that were named. A checkmark tap therefore costs the app the '
    'work of the one habit it changed, and a command that could have touched '
    'anything costs the work of everything.';

void main() {
  const TimeZone gmt = FixedTimeZone(0);
  final TimeZone Function() realZone = getDefaultTimeZone;
  final LocalDate today = LocalDate.ymd(2015, 1, 26);

  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late WidgetRegistry registry;
  late FakeHomeWidgetPlatform platform;
  late Preferences preferences;
  late HomeWidgetBridge bridge;

  setUp(() {
    DateUtils.setFixedTimeZone(gmt);
    getDefaultTimeZone = () => gmt;
    setToday(today);
    habitList = MemoryHabitList();
    fixtures = HabitFixtures(CountingModelFactory(), habitList);
    registry = WidgetRegistry(MemoryStorage());
    platform = FakeHomeWidgetPlatform();
    preferences = Preferences(MemoryStorage());
    bridge = HomeWidgetBridge(
      habitList: habitList,
      registry: registry,
      platform: platform,
      preferences: preferences,
    );
  });

  tearDown(() {
    DateUtils.setFixedTimeZone(null);
    getDefaultTimeZone = realZone;
  });

  /// A daily habit checked on every one of the last 120 days.
  CountingHabit habitNamed(String name) {
    // Distinct positions, so the catalogue's order is the order they were
    // added rather than `byNameAsc`, which is the tie-break MemoryHabitList
    // falls back to.
    final CountingHabit habit = fixtures.createEmptyHabit(
      name: name,
      position: habitList.size(),
    ) as CountingHabit;
    for (int offset = 0; offset < 120; offset++) {
      habit.originalEntries.add(Entry(today.minus(offset), Entry.yesManual));
    }
    habit.recompute();
    habitList.add(habit);
    return habit;
  }

  /// The three habits, plus one widget bound to the first, published once so
  /// that every later publish is the interesting one.
  Future<List<CountingHabit>> threePublishedHabits() async {
    final List<CountingHabit> habits = <CountingHabit>[
      habitNamed('Meditate'),
      habitNamed('Run'),
      habitNamed('Read'),
    ];
    registry.addWidget(7, <int>[habits[0].id!]);
    await bridge.publish();
    for (final CountingHabit habit in habits) {
      habit.reads = 0;
    }
    return habits;
  }

  String index() => platform.data[HomeWidgetBridge.indexKey]!;

  group('audit10.every-command-republishes-the-whole', () {
    test('#1 a repetition rebuilds the habit it names and no other', () async {
      final List<CountingHabit> habits = await threePublishedHabits();

      await bridge.publish(habits[0].id);

      expect(habits[0].reads, greaterThan(0),
          reason: '$rule1 The habit the command named is the one whose '
              'document can have changed, so it is rebuilt.');
      expect(habits[1].reads, 0,
          reason: '$rule1 `CreateRepetitionCommand.run` writes one entry on '
              'one habit and recomputes that habit; no other habit\'s score '
              'buckets, target windows, streaks or weekday frequency can have '
              'moved, and upstream none of them is even read.');
      expect(habits[2].reads, 0, reason: '$rule1 Same, for every other habit.');
    });

    test('#1 the filtered publish writes what the unfiltered one would have',
        () async {
      final List<CountingHabit> habits = await threePublishedHabits();
      habits[0].originalEntries.add(Entry(today, Entry.skip));
      habits[0].recompute();

      await bridge.publish(habits[0].id);
      final String filtered = index();
      await bridge.publish();

      expect(filtered, index(),
          reason: '$rule1 The filter is upstream\'s and decides only what work '
              'is skipped, never what is published: a cheaper publish that '
              'drops an update is a worse defect than an expensive one.');
    });

    test('#1 a command that is not a repetition rebuilds everything', () async {
      final List<CountingHabit> habits = await threePublishedHabits();

      await bridge.publish();

      for (final CountingHabit habit in habits) {
        expect(habit.reads, greaterThan(0),
            reason: '$rule1 `onCommandFinished` passes null for every command '
                'that is not a `CreateRepetitionCommand` — rename, archive, '
                'delete, reorder, edit frequency — and a null id means every '
                'widget and therefore every habit.');
      }
    });

    test('#1 a habit created since the last publish is built even under the '
        'filter', () async {
      final List<CountingHabit> habits = await threePublishedHabits();
      final CountingHabit added = habitNamed('Stretch');
      added.reads = 0;

      await bridge.publish(habits[0].id);

      expect(added.reads, greaterThan(0),
          reason: '$rule1 The filter names the habits whose work may be '
              'skipped; a habit with no published document of its own has '
              'nothing to skip to.');
      expect(
        <Object?>[
          for (final Object? h
              in (jsonDecode(index()) as Map<String, Object?>)['habits']!
                  as List<Object?>)
            (h! as Map<String, Object?>)['name'],
        ],
        <String>['Meditate', 'Run', 'Read', 'Stretch'],
        reason: '$rule1 The catalogue is the whole habit list in list order '
            'whichever path the publish took — it is what `HabitEntityQuery` '
            'offers an iOS widget to be configured from '
            '(`audit4.ios-the-app-group-is-never#1`).',
      );
    });

    test('#1 a day rollover rebuilds every habit, filter or no filter',
        () async {
      final List<CountingHabit> habits = await threePublishedHabits();
      setToday(today.plus(1));

      await bridge.publish(habits[0].id);

      expect(habits[1].reads, greaterThan(0),
          reason: '$rule1 Every habit document is built against today — the '
              'entry window, the score, the target windows — so a publish that '
              'reused yesterday\'s work would leave the untouched habits a day '
              'behind. Only the habit the command named may be skipped, and '
              'only while nothing else it was built from has moved.');
      expect(
        (jsonDecode(index()) as Map<String, Object?>)['today'],
        '2015-01-27',
        reason: '$rule1 …and the catalogue says so.',
      );
    });

    test('#1 changing the score bucket rebuilds every habit', () async {
      final List<CountingHabit> habits = await threePublishedHabits();
      preferences.scoreCardSpinnerPosition = 2;

      await bridge.publish(habits[0].id);

      expect(habits[1].reads, greaterThan(0),
          reason: '$rule1 `widgets.score#3`: the Score widget follows the '
              'bucket the user last chose on the detail screen, and that '
              'bucket is an input of every habit\'s `scores` array — not just '
              'the one a command touched.');
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// A [Habit] that counts how often its computed entries were read.
///
/// Every path that builds a habit document goes through them — the entry
/// window, `HistoryCardPresenter`, `ScoreCardPresenter`, `TargetCardPresenter`
/// — and nothing else in a publish does, so the counter is "this habit's
/// document was built" without the bridge having to say so.
class CountingHabit extends Habit {
  CountingHabit({
    required super.computedEntries,
    required super.originalEntries,
    required super.scores,
    required super.streaks,
  });

  int reads = 0;

  @override
  EntryList get computedEntries {
    reads++;
    return super.computedEntries;
  }
}

/// [MemoryModelFactory] that builds [CountingHabit]s.
class CountingModelFactory extends MemoryModelFactory {
  @override
  Habit buildHabit() => CountingHabit(
        computedEntries: buildComputedEntries(),
        originalEntries: buildOriginalEntries(),
        scores: buildScoreList(),
        streaks: buildStreakList(),
      );
}

/// [HomeWidgetPlatform] over nothing: the `home_widget` method channel has no
/// implementation in a widget test, so this is where the port stops.
class FakeHomeWidgetPlatform implements HomeWidgetPlatform {
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
