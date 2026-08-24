/// `audit10.history-home-screen-widget-draws-more`: the History home-screen
/// widget draws more calendar squares than the published document has days
/// for, and paints the overrun as if the user had missed those days.
///
/// Upstream `HistoryWidget.refreshData` builds the card state with
/// `HistoryCardPresenter.buildState(...)` and assigns `historyChart.series =
/// model.series`. That series is built from the habit's *entire* record —
/// `val oldest = habit.computedEntries.getKnown().lastOrNull()?.date ?: today;
/// val entries = habit.computedEntries.getByInterval(oldest, today)` — so
/// however many columns the grid has room for, every square inside the habit's
/// lifetime is filled from the real record. `defaultSquare = OFF` only ever
/// covers days *before* the habit existed.
///
/// In the port the series crosses a process boundary as JSON, and what crossed
/// was a fixed sixty-day window. Both renderers fall back silently past the end
/// of it — Kotlin `drawSquare` does `if (offset >= series.size) defaultSquare`,
/// Swift `square(offset:)` does `guard offset < habit.entries.count else
/// { return .off }` — and neither bounds its column count by the data it holds:
/// `nColumns = floor((width - 2*padding - weekdayColumnWidth) / squareSize)` is
/// purely geometric. The grid therefore spans `7 * nColumns` days, which passes
/// sixty at nine columns and reaches 127-133 days on an iOS `.systemMedium`
/// card — a default offered size. Because `Square.OFF` is drawn in the same
/// low-contrast colour a genuine missed day gets, a day the user completed
/// three months ago is indistinguishable from one they failed.
///
/// ## What this file asserts, and where
///
/// The publishing half is real Dart: a habit whose record reaches back well
/// past the entry window, published, and the History series read back out of
/// the document. The drawing half runs outside the Flutter engine on both
/// platforms, so it is asserted from the source that ships it — the same way
/// app/test/platform/widget_notes_indicator_test.dart asserts the note dot.
library;

// The bridge reaches the core by its `src` path, exactly as
// lib/state/app_scope.dart does.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';

// ---------------------------------------------------------------------------
// Locating the native source sets
// ---------------------------------------------------------------------------

final Directory appDir = _findApp();
final Directory widgetKotlinDir = Directory(
    '${appDir.path}/android/app/src/main/kotlin/org/isoron/uhabits/widgets');
final Directory iosWidgetDir = Directory('${appDir.path}/ios/HabitsWidget');

Directory _findApp() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String prefix in <String>['', '/app']) {
      final Directory candidate = Directory('${dir.path}$prefix');
      if (File('${candidate.path}/ios/HabitsWidget/HistoryWidget.swift')
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

String widgetKotlin(String name) =>
    File('${widgetKotlinDir.path}/$name').readAsStringSync();

String widgetViewKotlin(String name) =>
    File('${widgetKotlinDir.path}/views/$name').readAsStringSync();

String swift(String name) =>
    File('${iosWidgetDir.path}/$name').readAsStringSync();

/// [source] with its comments stripped, so an assertion about what the code
/// does cannot be satisfied — or defeated — by prose that merely names the
/// thing. Same helper, same reason, as android_widgets_test.dart.
String withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// [source] with every run of whitespace collapsed to one space, so an
/// assertion is about the code and not about where the formatter chose to wrap
/// it.
String squashed(String source) => source
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll('( ', '(')
    .replaceAll(' )', ')');

const String rule1 =
    'audit10.history-home-screen-widget-draws-more#1 — In the Kotlin app: '
    '`HistoryWidget.refreshData` assigns `historyChart.series = '
    'HistoryCardPresenter.buildState(habit, ...).series`, and that presenter '
    'builds the series from `computedEntries.getByInterval(oldest, today)` '
    'where `oldest` is the habit\'s oldest known entry. The grid sizes itself '
    'geometrically — `nColumns = floor((width - 2*padding - '
    'weekdayColumnWidth) / squareSize)`, spanning `7 * nColumns` days — so '
    'every square inside the habit\'s lifetime is painted from the real '
    'record however wide the widget is, and `defaultSquare = OFF` covers only '
    'the days before the habit existed.';

void main() {
  // =======================================================================
  // The published document
  // =======================================================================

  group('audit10.history-home-screen-widget-draws-more (the document)', () {
    const TimeZone gmt = FixedTimeZone(0);
    final TimeZone Function() realZone = getDefaultTimeZone;
    final LocalDate today = LocalDate.ymd(2015, 1, 26);

    late MemoryHabitList habitList;
    late HabitFixtures fixtures;
    late MemoryStorage storage;
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
      registry = WidgetRegistry(storage);
      platform = FakeHomeWidgetPlatform();
      bridge = HomeWidgetBridge(
        habitList: habitList,
        registry: registry,
        platform: platform,
      );
    });

    tearDown(() {
      DateUtils.setFixedTimeZone(null);
      getDefaultTimeZone = realZone;
    });

    /// A daily habit checked on every one of the last [days] days.
    Habit longHabit({int days = 200, int noteOffset = -1}) {
      final Habit habit = fixtures.createEmptyHabit(name: 'Meditate');
      for (int offset = 0; offset < days; offset++) {
        habit.originalEntries.add(Entry(
          today.minus(offset),
          Entry.yesManual,
          notes: offset == noteOffset ? 'Felt great' : '',
        ));
      }
      habit.recompute();
      habitList.add(habit);
      return habit;
    }

    Map<String, Object?> habitOfWidget(int widgetId) {
      final Map<String, Object?> document =
          jsonDecode(platform.data[HomeWidgetBridge.documentKey(widgetId)]!)
              as Map<String, Object?>;
      return (document['habits']! as List<Object?>).single
          as Map<String, Object?>;
    }

    test('#1 the History series reaches back to the oldest entry, not to the '
        'edge of the entry window', () async {
      final Habit habit = longHabit(days: 200);
      registry.addWidget(7, <int>[habit.id!]);
      await bridge.publish();

      final Object? series = habitOfWidget(7)['historySeries'];
      expect(series, isA<String>(),
          reason: '$rule1 The series a widget draws is the presenter\'s, over '
              'the habit\'s whole record; a widget process cannot compute it '
              'and the sixty daily values it already has do not reach far '
              'enough to fill the grid.');
      expect((series! as String).length, 200,
          reason: '$rule1 `getByInterval(oldest, today)` yields one square per '
              'day from the oldest known entry to today — 200 for a habit '
              'checked on each of the last 200 days.');
      expect((series as String)[150], '0',
          reason: '$rule1 A day the user completed is Square.ON at its own '
              'offset however old it is; drawn as OFF it is indistinguishable '
              'from a day they missed.');
    });

    test('#1 the series stops at the oldest entry, so days before the habit '
        'existed stay defaultSquare', () async {
      final Habit habit = longHabit(days: 3);
      registry.addWidget(7, <int>[habit.id!]);
      await bridge.publish();

      expect((habitOfWidget(7)['historySeries']! as String).length, 3,
          reason: '$rule1 `oldest` is the habit\'s oldest known entry, so the '
              'series is exactly as long as the habit has existed and the '
              'renderer\'s `defaultSquare = OFF` covers everything before '
              'that — which is the one thing OFF is allowed to mean.');
    });

    test('#1 a numerical habit\'s squares carry the presenter\'s target '
        'comparison over the whole record', () async {
      final Habit habit = fixtures.createEmptyNumericalHabit(
        NumericalHabitType.atLeast,
      );
      habitList.add(habit);
      // target is 2.0; 3000 thousandths clears it, 1000 does not.
      habit.originalEntries.add(Entry(today.minus(100), 3000));
      habit.originalEntries.add(Entry(today.minus(120), 1000));
      habit.originalEntries.add(Entry(today.minus(150), Entry.skip));
      habit.recompute();
      registry.addWidget(7, <int>[habit.id!]);
      await bridge.publish();

      final String series = habitOfWidget(7)['historySeries']! as String;
      expect(series.length, 151,
          reason: '$rule1 The oldest known entry is 150 days back, so the '
              'series spans 151 days.');
      expect(series[100], '0',
          reason: '$rule1 `(targetType == AT_LEAST) && (value / 1000.0 >= '
              'targetValue) -> ON`, at whatever offset the day sits.');
      expect(series[120], '2',
          reason: '$rule1 A numerical day short of its target is GREY, not '
              'OFF — the widget cannot tell the two apart once the day falls '
              'past the published window.');
      expect(series[150], '4',
          reason: '$rule1 SKIP is HATCHED, and is decided before the target '
              'comparison.');
    });

    test('#1 a note older than the entry window still marks its day',
        () async {
      final Habit habit = longHabit(days: 200, noteOffset: 120);
      registry.addWidget(7, <int>[habit.id!]);
      await bridge.publish();

      expect(habitOfWidget(7)['historyNotes'], <int>[120],
          reason: '$rule1 `HistoryCardPresenter.buildState` maps the same '
              'whole-record interval to `notesIndicators`, so the dot follows '
              'the square: a grid that draws a day draws its note too.');
    });

    test('#1 the series is bounded, so a decade-old habit does not ship a '
        'decade of squares', () async {
      final Habit habit = longHabit(days: HomeWidgetBridge.historyDayCount + 40);
      registry.addWidget(7, <int>[habit.id!]);
      await bridge.publish();

      expect((habitOfWidget(7)['historySeries']! as String).length,
          HomeWidgetBridge.historyDayCount,
          reason: '$rule1 The grid can never ask for more days than the widest '
              'cell a launcher offers holds, so the port caps the series there '
              'rather than shipping the unbounded record Kotlin passes '
              'in-process.');
    });
  });

  // =======================================================================
  // The Android renderer
  // =======================================================================

  group('audit10.history-home-screen-widget-draws-more (Android)', () {
    test('#1 the chart draws the published History series, not the entry '
        'window', () {
      final String source =
          squashed(withoutComments(widgetViewKotlin('HistoryChartView.kt')));
      expect(source, contains('historySeries'),
          reason: '$rule1 `HistoryChartView.seriesOf` derived the whole series '
              'from `habit.entries`, which is sixty days long, so every column '
              'past the ninth fell through `if (offset >= series.size) '
              'defaultSquare` and was painted OFF.');
    });

    test('#1 a document rolled forward over a stale day shifts the History '
        'series with it', () {
      final String source =
          squashed(withoutComments(widgetKotlin('WidgetData.kt')));
      expect(source, contains('historySeries'),
          reason: '$rule1 `HabitData.rolledForward` moves every newest-first '
              'array down by the days the widget has gone stale; a series left '
              'unshifted would draw each square one or more days late.');
    });
  });

  // =======================================================================
  // The iOS renderer
  // =======================================================================

  group('audit10.history-home-screen-widget-draws-more (iOS)', () {
    test('#1 the chart draws the published History series, not the entry '
        'window', () {
      final String source =
          squashed(withoutComments(swift('HistoryWidget.swift')));
      expect(source, contains('historySeries'),
          reason: '$rule1 `.systemMedium` is a default offered family for the '
              'History widget and its grid spans 127-133 days, so more than '
              'half of it fell through `guard offset < habit.entries.count '
              'else { return .off }`.');
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
