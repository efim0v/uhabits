/// The iOS widget extension against the document the app publishes: the
/// derived fields it must read rather than rebuild, and the weekday origin it
/// must be told rather than guess.
///
/// Four rules, one root. `HomeWidgetBridge._habitDocument` runs the same
/// presenters the habit screen runs and publishes what they produce — the best
/// streaks over the whole record, the weekday histogram over every month the
/// habit has existed, the target rows the habit's frequency admits, the score
/// bucket the user chose — and `buildIndexDocument` publishes the first
/// weekday. `app/android/.../widgets/` consumes all five. The WidgetKit
/// extension consumed none of them: `struct WidgetHabit` declared neither
/// `streaks` nor `weekdayFrequency` nor `targetRows` nor `bucketSize`, and
/// neither `WidgetIndex` nor `WidgetDocument` declared `firstWeekday`, so four
/// charts recomputed from the sixty daily values `entries` carries and two laid
/// their calendars out from the device region.
///
/// ## Why a test reads files instead of running code
///
/// The extension is a separate process with no Flutter engine: its
/// `TimelineProvider` runs inside `chronod` and its `Canvas` is rasterised by
/// WidgetKit. `ios/Runner.xcodeproj` has exactly one unit-test bundle
/// (`RunnerTests`, the empty Flutter stub) and the `HabitsWidget` target has
/// none, so there is no Swift test target to put an assertion in either. What
/// this file can do — and what test/platform/widget_history_window_test.dart
/// and test/platform/ios_widget_toggle_test.dart already do — is assert the
/// two halves of the boundary against each other: the *values* the bridge
/// publishes, which is real Dart, and the *fields the Swift declares and
/// reads*, extracted from the source that ships.
///
/// The cross-check in the first group is the one that was missing:
/// test/platform/home_widget_bridge_test.dart asserts what is written into the
/// App Group and test/platform/ios_widgets_test.dart asserts the bundle's
/// shape, but nothing asserted that every key `_habitDocument` emits has a
/// counterpart in `WidgetHabit` — which is exactly how four fields stayed
/// unread for two audits.
library;

// The bridge reaches the core by its `src` path, exactly as
// lib/state/app_scope.dart does.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';

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

/// [source] with its comments stripped.
///
/// Every field below is *named* by a doc comment somewhere in the extension —
/// several of them by a comment explaining that the field does not exist — so
/// an assertion about what the code reads has to be made against code alone.
String withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// [source] with every run of whitespace collapsed to one space, so an
/// assertion is about the code and not about where the formatter wrapped it.
String squashed(String source) => source
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll('( ', '(')
    .replaceAll(' )', ')');

/// The body of one top-level Swift declaration: from its header line to the
/// start of the next top-level declaration, so an assertion about one struct
/// cannot be satisfied by the contents of the next one.
String declaration(String source, String header) {
  final int start = source.indexOf(header);
  if (start < 0) fail('$header is not declared');
  final int next = source.indexOf(
    RegExp(r'^(struct|extension|enum|protocol|final class|class) ',
        multiLine: true),
    start + header.length,
  );
  return source.substring(start, next < 0 ? source.length : next);
}

/// The body of one Swift function, from its `func` line to the next
/// declaration at the same indentation.
String function(String source, String header) {
  final int start = source.indexOf(header);
  if (start < 0) fail('$header is not declared');
  final int next = source.indexOf(
    RegExp(r'^    (private )?(static )?(func|var|let) ', multiLine: true),
    start + header.length,
  );
  return source.substring(start, next < 0 ? source.length : next);
}

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

const String rule1 =
    'audit11.ios-streak-and-frequency-widgets-still#1 — In the Kotlin app: '
    '`StreakWidget.refreshData` sets `setStreaks(habit.streaks.getBest('
    'maxStreakCount))`, and `StreakList` is recomputed by `Habit.recompute()` '
    'over the habit\'s entire record, so the bars are the genuinely longest '
    'runs with their real start dates. `FrequencyWidget.refreshData` sets '
    '`setFrequency(habit.originalEntries.computeWeekdayFrequency('
    'habit.isNumerical))` — one 7-slot bucket per month for every month the '
    'habit has existed, counted from the user\'s own marks. Neither chart '
    'rebuilds anything from a fixed window.';

const String rule2 =
    'audit11.ios-target-widget-ignores-the-published#1 — In the Kotlin app: '
    '`TargetWidget.refreshData` draws `TargetCardPresenter.buildState(habit, '
    'firstWeekday = prefs.firstWeekdayInt, theme = WidgetTheme())`. That '
    'presenter emits the "Today" row only when `frequency.denominator <= 1` '
    'and the "Week" row only when it is `<= 7`, scales every target from '
    '`dailyTarget = habit.targetValue / frequency.denominator` (with '
    '`targetThisWeek = habit.targetValue` when the denominator is 7), and sums '
    'calendar-truncated groups over the habit\'s whole record. '
    '`ScoreWidget.refreshData` likewise plots `ScoreCardPresenter.buildState`\'s '
    'series at the bucket the user chose on the detail screen, not at a fixed '
    'weekly one.';

const String rule3 =
    'audit11.ios-history-and-frequency-widgets-lay#1 — In the Kotlin app: '
    '`HistoryWidget` builds its chart with `firstWeekday = prefs.firstWeekday` '
    'both at construction and on every refresh through '
    '`HistoryCardPresenter.buildState(habit, firstWeekday = '
    'prefs.firstWeekday, ...)`, and `FrequencyWidgetProvider` hands '
    '`preferences.firstWeekday` to `FrequencyWidget.refreshData`, which calls '
    '`setFirstWeekday(firstWeekday)`. Both grids start on the weekday the user '
    'chose in Settings — the same origin the habit-list header and the detail '
    'screen use — never on the device locale\'s.';

void main() {
  // =======================================================================
  // Fixtures
  // =======================================================================

  const TimeZone gmt = FixedTimeZone(0);
  final TimeZone Function() realZone = getDefaultTimeZone;
  final LocalDate today = LocalDate.ymd(2015, 1, 26);

  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late MemoryStorage storage;
  late Preferences preferences;
  late WidgetRegistry registry;
  late FakeHomeWidgetPlatform platform;
  late HomeWidgetBridge bridge;

  setUp(() {
    DateUtils.setFixedTimeZone(gmt);
    getDefaultTimeZone = () => gmt;
    setToday(today);
    habitList = MemoryHabitList();
    fixtures = HabitFixtures(MemoryModelFactory(), habitList);
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
  });

  tearDown(() {
    DateUtils.setFixedTimeZone(null);
    getDefaultTimeZone = realZone;
  });

  Map<String, Object?> index() =>
      jsonDecode(platform.data[HomeWidgetBridge.indexKey]!)
          as Map<String, Object?>;

  Map<String, Object?> document(int widgetId) =>
      jsonDecode(platform.data[HomeWidgetBridge.documentKey(widgetId)]!)
          as Map<String, Object?>;

  Map<String, Object?> habitOf(Map<String, Object?> doc) =>
      (doc['habits']! as List<Object?>).first as Map<String, Object?>;

  // =======================================================================
  // Streaks and the weekday histogram
  // =======================================================================

  group('audit11.ios-streak-and-frequency-widgets-still', () {
    test('#1 every field the bridge publishes per habit is declared by '
        'WidgetHabit', () async {
      final Habit habit = fixtures.createLongHabit();
      habitList.add(habit);
      registry.addWidget(7, <int>[habit.id!]);
      await bridge.publish();

      final String source = withoutComments(swift('WidgetData.swift'));
      final String struct = declaration(source, 'struct WidgetHabit');
      final List<String> undeclared = <String>[
        for (final String key in habitOf(document(7)).keys)
          if (!RegExp('let $key\\b').hasMatch(struct)) key,
      ];

      expect(undeclared, isEmpty,
          reason: '$rule1 A field the extension does not decode is a field the '
              'chart rebuilds from `entries` — sixty days — or does without. '
              'Nothing cross-checked the two halves of the contract, which is '
              'how `streaks`, `weekdayFrequency`, `targetRows` and '
              '`bucketSize` stayed unread through two audits that had already '
              'published them.');
    });

    test('#1 a field a newer bridge stops publishing cannot blank the widget',
        () {
      final String struct =
          declaration(withoutComments(swift('WidgetData.swift')),
              'struct WidgetHabit');

      for (final String field in <String>[
        'bucketSize',
        'streaks',
        'weekdayFrequency',
        'targetRows',
      ]) {
        expect(RegExp('let $field: [^\\n]*\\?\\n').hasMatch(struct), isTrue,
            reason: '$rule1 A widget outlives an app update for as long as it '
                'sits on the home screen, so it decodes documents older than '
                'itself. `JSONDecoder` fails the WHOLE `WidgetHabit` on one '
                'missing non-optional key and `WidgetStore.decode` answers nil '
                'for it, so a required `$field` would turn every card on the '
                'home screen into the "no habit" placeholder — a worse defect '
                'than the one this rule is about. Optional, with the local '
                'rebuild as the fallback, is what `WidgetHabit.score` and '
                '`scores` already do and what '
                '`app/android/.../widgets/WidgetData.kt` does for the same '
                'four fields.');
      }
    });

    test("#1 the streaks' and the buckets' own fields line up too", () async {
      final Habit habit = fixtures.createLongHabit();
      habitList.add(habit);
      registry.addWidget(7, <int>[habit.id!]);
      await bridge.publish();

      final String source = withoutComments(swift('WidgetData.swift'));
      final String streak = declaration(source, 'struct WidgetStreakData');
      final Map<String, Object?> published =
          (habitOf(document(7))['streaks']! as List<Object?>).first!
              as Map<String, Object?>;
      expect(
        <String>[
          for (final String key in published.keys)
            if (!RegExp('let $key\\b').hasMatch(streak)) key,
        ],
        isEmpty,
        reason: '$rule1 The cross-check has to reach inside the array as well: '
            'every member of `WidgetStreakData` is non-optional, so one '
            'renamed key fails the whole habit and blanks the card rather than '
            'quietly losing the field.',
      );
      expect(streak, contains('let start: String'),
          reason: '$rule1 `Streak.start` is a calendar date, and a run '
              '`habit.streaks.getBest` found may begin years before the '
              'published `today` — which is the entire reason the field '
              'exists, so it cannot travel as an offset into the sixty-day '
              'window.');

      final Map<String, Object?> frequency =
          habitOf(document(7))['weekdayFrequency']! as Map<String, Object?>;
      expect(frequency.values.first, isA<List<Object?>>().having(
          (List<Object?> slots) => slots.length, 'length', 7),
          reason: '$rule1 `computeWeekdayFrequency` accumulates one 7-slot '
              'array per month, indexed `(daysSinceSunday + 1) % 7` — the '
              'shape `FrequencyChartView.drawColumn` indexes.');
      expect(
        frequency.keys,
        everyElement(matches(RegExp(r'^\d{4}-\d{2}-01$'))),
        reason: '$rule1 …keyed by that month\'s first day in '
            '`HomeWidgetBridge.formatDate`\'s format — three dash-separated '
            'numbers, which is what `FrequencyState.published` splits back '
            'into a `MonthKey`.',
      );
    });

    test('#1 the Streak chart draws the published streaks', () async {
      // A single run of 200 days: more than three times the published entry
      // window, so only the whole-history list can describe it.
      final Habit habit = fixtures.createEmptyHabit(name: 'Meditate');
      for (int offset = 0; offset < 200; offset++) {
        habit.originalEntries.add(Entry(today.minus(offset), Entry.yesManual));
      }
      habit.recompute();
      habitList.add(habit);
      registry.addWidget(7, <int>[habit.id!]);
      await bridge.publish();

      final List<Object?> streaks =
          habitOf(document(7))['streaks']! as List<Object?>;
      expect((streaks.first! as Map<String, Object?>)['length'], 200,
          reason: '$rule1 `habit.streaks.getBest(n)` reports the run at its '
              'real length; a widget that rebuilt it from the sixty published '
              'entries could never report more than 60.');

      final String source = squashed(withoutComments(swift('StreakWidget.swift')));
      expect(source, contains('habit.streaks'),
          reason: '$rule1 `StreakState.recompute` scanned `habit.entries`, so '
              'the longest bar a user could ever see was 60 and every streak '
              'that ended before the window was absent from the "best '
              'streaks" list — which is the widget\'s whole content.');
    });

    test('#1 the Frequency chart draws the published weekday buckets',
        () async {
      final Habit habit = fixtures.createLongHabit();
      habitList.add(habit);
      registry.addWidget(7, <int>[habit.id!]);
      await bridge.publish();

      final Map<String, Object?> frequency =
          habitOf(document(7))['weekdayFrequency']! as Map<String, Object?>;
      final String windowStart = HomeWidgetBridge.formatDate(
          today.minus(HomeWidgetBridge.entryCount));
      expect(
        frequency.keys.any((String key) => key.compareTo(windowStart) < 0),
        isTrue,
        reason: '$rule1 `computeWeekdayFrequency` buckets every month the '
            'habit has existed, so a habit with 120 days of marks has columns '
            'older than the published entry window.',
      );

      final String source =
          squashed(withoutComments(swift('FrequencyWidget.swift')));
      expect(source, contains('habit.weekdayFrequency'),
          reason: '$rule1 `FrequencyState.weekdayFrequency` bucketed the sixty '
              'published entries, so every column older than two months was '
              'drawn empty and the calendar read as if the user had started '
              'the habit two months ago.');
    });
  });

  // =======================================================================
  // Target rows and the score bucket
  // =======================================================================

  group('audit11.ios-target-widget-ignores-the-published', () {
    /// "Run 20 km, 1 time per week" — the habit whose Target card the iOS
    /// widget disagreed with.
    Habit weeklyRunner() {
      final Habit habit =
          fixtures.createEmptyNumericalHabit(NumericalHabitType.atLeast);
      habit.targetValue = 20.0;
      habit.frequency = Frequency(1, 7);
      habit.originalEntries.add(Entry(today, 20000));
      habit.recompute();
      habitList.add(habit);
      return habit;
    }

    test('#1 the Target chart draws the published rows', () async {
      final Habit habit = weeklyRunner();
      registry.addWidget(7, <int>[habit.id!]);
      await bridge.publish();

      final List<Object?> rows =
          habitOf(document(7))['targetRows']! as List<Object?>;
      expect(
        rows
            .map((Object? row) => (row! as Map<String, Object?>)['interval'])
            .toList(),
        <int>[7, 30, 91, 365],
        reason: '$rule2 The "Today" row exists only when '
            '`frequency.denominator <= 1`, and this habit is 1 time every 7 '
            'days, so the card has four bars.',
      );
      expect((rows.first! as Map<String, Object?>)['target'], 20.0,
          reason: '$rule2 `targetThisWeek = habit.targetValue` when the '
              'denominator is 7. A widget assuming a daily frequency scales it '
              'by seven and shows a finished week at 14%.');

      final String row = declaration(
          withoutComments(swift('WidgetData.swift')), 'struct WidgetTargetRow');
      expect(
        <String>[
          for (final String key
              in (rows.first! as Map<String, Object?>).keys)
            if (!RegExp('let $key\\b').hasMatch(row)) key,
        ],
        isEmpty,
        reason: '$rule2 A row is three numbers and the chart draws all three; '
            'they are non-optional, so a renamed key blanks the card instead '
            'of drawing a bar of the wrong length.',
      );

      final String source = squashed(withoutComments(swift('TargetWidget.swift')));
      expect(source, contains('habit.targetRows'),
          reason: '$rule2 `TargetState.buildState` recomputed all five windows '
              'with `dailyTarget = habit.target`, so iOS showed five bars '
              'where the habit\'s own detail card and the Android widget show '
              'four, with every target wrong by the denominator.');
    });

    test('#1 the Score chart plots at the published bucket size', () async {
      storage.putInt('pref_score_view_interval', 4);
      final Habit habit = fixtures.createLongHabit();
      habitList.add(habit);
      registry.addWidget(7, <int>[habit.id!]);
      await bridge.publish();

      expect(habitOf(document(7))['bucketSize'], 365,
          reason: '$rule2 `widgets.score#3`: the widget follows '
              '`Preferences.scoreCardSpinnerPosition`, and position 4 is the '
              'yearly bucket.');

      final String source = squashed(withoutComments(swift('ScoreWidget.swift')));
      expect(source, contains('habit.bucketSize'),
          reason: '$rule2 `bucketSize` is what turns a column index into a '
              'date, so a chart hardcoding 7 plots the right line against '
              'dates spaced one week apart — the footer of a yearly chart '
              'labelled in weeks.');
    });
  });

  // =======================================================================
  // The weekday origin
  // =======================================================================

  group('audit11.ios-history-and-frequency-widgets-lay', () {
    test('#1 both documents carry the preference, and the extension decodes '
        'it', () async {
      storage.putInt('pref_first_weekday', 2); // Monday, as Java numbers it.
      final Habit habit = fixtures.createLongHabit();
      habitList.add(habit);
      registry.addWidget(7, <int>[habit.id!]);
      await bridge.publish();

      expect(index()['firstWeekday'], 1,
          reason: '$rule3 The catalogue is what an iOS widget configured '
              'through the entity query reads, so the origin rides on it too — '
              'Monday is 1 as `daysSinceSunday`.');
      expect(document(7)['firstWeekday'], 1, reason: rule3);

      final String source = withoutComments(swift('WidgetData.swift'));
      expect(declaration(source, 'struct WidgetIndex'),
          contains('let firstWeekday'),
          reason: '$rule3 A field no struct declares is a field no chart can '
              'read; `WidgetIndex` is where an iOS widget resolves its habit '
              'from.');
      expect(declaration(source, 'struct WidgetDocument'),
          contains('let firstWeekday'),
          reason: '$rule3 …and the per-widget document carries it as well, so '
              'a widget bound the Android way draws the same grid.');

      expect(declaration(source, 'struct WidgetIndex'),
          contains('let firstWeekday: Int?'),
          reason: '$rule3 Optional, like `isSkipEnabled` and '
              '`areQuestionMarksEnabled` beside it: a required field would '
              'fail the whole index for a document written before it existed '
              'and leave every card on the home screen showing the "no habit" '
              'placeholder.');
      expect(
        squashed(withoutComments(source)),
        contains('index()?.firstWeekday ?? '
            'DateNames.firstWeekdayDaysSinceSunday()'),
        reason: '$rule3 …so the device calendar survives as the fallback and '
            'nothing else, which is the value both grids used unconditionally '
            'before.',
      );
    });

    test('#1 neither grid takes its origin from the device calendar', () {
      for (final String file in <String>[
        'HistoryWidget.swift',
        'FrequencyWidget.swift',
      ]) {
        final String source = squashed(withoutComments(swift(file)));
        expect(source, isNot(contains('firstWeekdayDaysSinceSunday')),
            reason: '$rule3 `DateNames.firstWeekdayDaysSinceSunday()` is '
                '`calendar.firstWeekday - 1` — the iOS region setting. A user '
                'on a US-region iPhone who chose Monday in Loop saw the app\'s '
                'grid start on Monday and the widget\'s on Sunday, every '
                'square one row off from the same date in the app.');
        expect(source, contains('firstWeekday'),
            reason: '$rule3 The chart is handed the published origin instead, '
                'exactly as `FrequencyWidget.setFirstWeekday(firstWeekday)` is '
                'handed `preferences.firstWeekday` upstream.');
      }
    });

    test('#1 the timeline entry carries the origin to the charts', () {
      final String timeline =
          squashed(withoutComments(swift('HabitTimeline.swift')));
      expect(timeline, contains('let firstWeekday: Int'),
          reason: '$rule3 The entry is the only thing a widget view is handed, '
              'so it is where app state — `today`, '
              '`areQuestionMarksEnabled` — already travels.');
      expect(timeline, contains('store.firstWeekday()'),
          reason: '$rule3 …read through one accessor, so the two grids cannot '
              'disagree about the same preference.');

      for (final String file in <String>[
        'HistoryWidget.swift',
        'FrequencyWidget.swift',
      ]) {
        expect(squashed(withoutComments(swift(file))),
            contains('firstWeekday: entry.firstWeekday'),
            reason: '$rule3 …and the chart in $file is built with it, the way '
                '`HistoryWidget.kt` builds `HistoryChartView` with '
                '`prefs.firstWeekday`.');
      }
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

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
