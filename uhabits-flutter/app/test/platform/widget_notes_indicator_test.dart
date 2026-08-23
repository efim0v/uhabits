/// `audit6.history-home-screen-widget-never-draws`: the note dot on the
/// History home-screen widget.
///
/// Upstream `HistoryWidget.refreshData` builds the card state with
/// `HistoryCardPresenter.buildState(...)` — the very presenter the detail
/// screen uses — and assigns `historyChart.notesIndicators =
/// model.notesIndicators`. `HistoryChart.drawSquare` then paints a filled
/// circle of radius `width / 12` at `(x + width - width / 5, y + width / 5)` on
/// every calendar square whose entry carries a non-empty note. A day the user
/// annotated is therefore marked on the home screen exactly as it is marked on
/// the detail screen's history card.
///
/// In the port the widget hosts are native and the data crosses a process
/// boundary as JSON, and `Entry.notes` was not part of that JSON: the document
/// carried `'entries': [entry.value …]` and nothing else about an entry. So
/// there was no `notesIndicators` to assign on either host — the Kotlin
/// `HistoryChartView` had no such field at all, and the Swift `drawSquare`
/// carried a comment saying the indicator was "deliberately absent" because
/// "`Entry.notes` is not part of the published contract".
///
/// ## What this file asserts, and where
///
/// The publishing half is real Dart and is exercised for real: a habit with a
/// note on one day, published, and the flags read back out of the document.
/// The drawing half runs outside the Flutter engine on both platforms — an
/// `AppWidgetProvider` in the launcher's process, a WidgetKit extension in its
/// own — so it is asserted from the source that ships it, the same way
/// app/test/platform/widget_question_mark_glyph_test.dart asserts the question
/// mark glyph: that the flags are parsed off the document, that they reach the
/// view before it draws, and that the branch reading them is the one the core
/// chart has, geometry and colours included.
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
    'audit6.history-home-screen-widget-never-draws#1 — In the Kotlin app: '
    '`HistoryWidget.refreshData` builds the card state with '
    '`HistoryCardPresenter.buildState(...)` and assigns '
    '`historyChart.notesIndicators = model.notesIndicators`. '
    '`HistoryChart.drawSquare` then paints a filled circle of radius '
    '`width/12` at `(x + width - width/5, y + width/5)` on every calendar '
    'square whose entry has a non-empty note — `theme.lowContrastTextColor` '
    'over ON/GREY squares, the habit\'s palette colour otherwise. A user who '
    'attaches notes to a day sees that day marked on the home-screen History '
    'widget exactly as it is marked on the detail screen\'s history card.';

void main() {
  // =======================================================================
  // The published document
  // =======================================================================

  group('audit6.history-home-screen-widget-never-draws (the document)', () {
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

    /// A daily habit checked on every one of the last four days, with a note on
    /// the day [noteOffset] days before today.
    Habit annotatedHabit({int noteOffset = 2}) {
      final Habit habit = fixtures.createEmptyHabit(name: 'Meditate');
      for (int offset = 0; offset < 4; offset++) {
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

    test('#1 a note on a day publishes a set flag at that day\'s offset',
        () async {
      final Habit habit = annotatedHabit();
      registry.addWidget(7, <int>[habit.id!]);
      await bridge.publish();

      final Object? flags = habitOfWidget(7)['notesIndicators'];
      expect(flags, isA<List<Object?>>(),
          reason: '$rule1 The indicator the chart reads is one boolean per '
              'published day, in the same newest-first order as `entries`; the '
              'launcher process cannot see `Entry.notes` any other way.');
      expect((flags! as List<Object?>).take(4), <bool>[false, false, true, false],
          reason: '$rule1 `HistoryCardPresenter.buildState` computes it as '
              '`entries.map { it.notes != "" }`, so the flag sits at the same '
              'offset as the entry it belongs to.');
    });

    test('#1 the flags are exactly as long as the entries they index', () async {
      final Habit habit = annotatedHabit();
      registry.addWidget(7, <int>[habit.id!]);
      await bridge.publish();

      final Map<String, Object?> published = habitOfWidget(7);
      expect(
        (published['notesIndicators']! as List<Object?>).length,
        (published['entries']! as List<Object?>).length,
        reason: '$rule1 `drawSquare` indexes both arrays with the same offset '
            'and treats an out-of-range offset as "no note", so a short array '
            'would silently drop the dots off the oldest columns.',
      );
      expect(
        (published['notesIndicators']! as List<Object?>).length,
        HomeWidgetBridge.entryCount,
        reason: '$rule1 …which is the same 60 days the History grid draws.',
      );
    });

    test('#1 a habit nobody annotated publishes all-false, not nothing',
        () async {
      final Habit habit = fixtures.createEmptyHabit(name: 'Run');
      habit.originalEntries.add(Entry(today, Entry.yesManual));
      habit.recompute();
      habitList.add(habit);
      registry.addWidget(3, <int>[habit.id!]);
      await bridge.publish();

      expect(
        habitOfWidget(3)['notesIndicators'],
        everyElement(isFalse),
        reason: '$rule1 The presenter maps every published day, so the absence '
            'of notes is a full array of `false` — the field is missing only '
            'in a document written before it existed.',
      );
    });

    test('#1 the iOS habit catalogue carries the flags too', () async {
      final Habit habit = annotatedHabit();
      registry.addWidget(7, <int>[habit.id!]);
      await bridge.publish();

      final Map<String, Object?> index =
          jsonDecode(platform.data[HomeWidgetBridge.indexKey]!)
              as Map<String, Object?>;
      final Map<String, Object?> catalogued =
          (index['habits']! as List<Object?>).single as Map<String, Object?>;
      expect((catalogued['notesIndicators']! as List<Object?>).take(4),
          <bool>[false, false, true, false],
          reason: '$rule1 A WidgetKit widget has no widget id and is resolved '
              'out of this catalogue instead, so a widget bound that way has '
              'to draw the same dots a bound one does.');
    });
  });

  // =======================================================================
  // Android: document -> widget -> view
  // =======================================================================

  group('audit6.history-home-screen-widget-never-draws (Android)', () {
    test('#1 the document parser carries the flags', () {
      final String data = squashed(withoutComments(widgetKotlin('WidgetData.kt')));

      expect(data, contains('val notesIndicators: List<Boolean>'),
          reason: '$rule1 `HistoryChart.notesIndicators` is a `List<Boolean>` '
              'parallel to the series; the launcher can only get it off the '
              'document.');
      expect(
        data,
        contains('notesIndicators = (0 until notesJson.length()).map '
            '{ notesJson.getBoolean(it) }'),
        reason: '$rule1 …parsed out of the published array itself, not '
            'guessed at from the entry values, which carry no note.',
      );
    });

    test('#1 refreshData hands them to the chart', () {
      final String widget = withoutComments(widgetKotlin('HistoryWidget.kt'));
      final String body =
          widget.substring(widget.indexOf('override fun refreshData'));

      expect(body, contains('notesIndicators = habit.notesIndicators'),
          reason: '$rule1 This is the assignment `HistoryWidget.refreshData` '
              'makes upstream — without it the chart keeps its empty default '
              'and every square takes the `hasNotes == false` branch.');
      expect(body, contains('series = HistoryChartView.seriesOf(habit)'),
          reason: '$rule1 …alongside the series it already assigned, from the '
              'same habit, so the two can never be a day out of step.');
    });

    test('#1 the chart draws the circle the core draws', () {
      final String view =
          squashed(withoutComments(widgetViewKotlin('HistoryChartView.kt')));

      expect(view, contains('var notesIndicators: List<Boolean> = emptyList()'),
          reason: '$rule1 Settable data the widget pushes in, and empty until '
              'it is — a view inflated with no document behind it draws no '
              'dots.');
      expect(
        view,
        contains('val hasNotes = if (offset >= notesIndicators.size) false '
            'else notesIndicators[offset]'),
        reason: '$rule1 `HistoryChart.drawSquare`\'s own guard: the grid is '
            'wider than the published window, and every square past the end of '
            'the array is drawn without a dot rather than crashing.',
      );
      expect(
        view,
        contains('canvas.fillCircle(x + w - w / 5, y + w / 5, w / 12)'),
        reason: '$rule1 The geometry, verbatim: radius width/12, centred at '
            '(x + width - width/5, y + width/5) — the top-right corner of the '
            'square.',
      );
      expect(
        view,
        contains('Square.ON, Square.GREY -> WidgetTheme.LOW_CONTRAST_TEXT_COLOR'),
        reason: '$rule1 The colour table: a filled or grey square is dark '
            'enough that the dot has to be the low-contrast colour…',
      );
      expect(
        RegExp(r'if \(hasNotes\) \{ val circleColor = when \(value\) \{ '
                r'Square\.ON, Square\.GREY -> '
                r'WidgetTheme\.LOW_CONTRAST_TEXT_COLOR else -> color \}')
            .hasMatch(view),
        isTrue,
        reason: '$rule1 …and every other square takes the habit\'s palette '
            'colour.',
      );
    });

    test('#1 a page of a History stack draws them as well', () {
      final String service =
          withoutComments(widgetKotlin('StackWidgetService.kt'));

      expect(
        service,
        contains('StackWidgetType.HISTORY -> HistoryWidget('),
        reason: '$rule1 A stack page is the same widget with `stacked = true`…',
      );
      expect(
        withoutComments(widgetKotlin('HistoryWidgetProvider.kt')),
        contains('document.singleHabit()'),
        reason: '$rule1 …and both routes reach the chart through the same '
            '`HabitData`, so nothing else has to be threaded through for the '
            'dots to appear on both.',
      );
    });
  });

  // =======================================================================
  // iOS: the same dot
  // =======================================================================

  group('audit6.history-home-screen-widget-never-draws (iOS)', () {
    test('#1 the decoded habit carries the flags', () {
      final String store = squashed(swift('WidgetData.swift'));

      expect(store, contains('let notesIndicators: [Bool]?'),
          reason: '$rule1 Optional because a widget can outlive the app update '
              'that started publishing the field, exactly as `score` and '
              '`scores` are.');
    });

    test('#1 the WidgetKit chart paints it', () {
      final String source = squashed(swift('HistoryWidget.swift'));

      expect(
        source,
        contains('hasNotes'),
        reason: '$rule1 The Swift chart had no notion of a note at all.',
      );
      expect(
        source,
        contains('Path(ellipseIn: CGRect(x: x + side - side / 5 - radius, '
            'y: y + side / 5 - radius, width: 2 * radius, '
            'height: 2 * radius))'),
        reason: '$rule1 `Canvas.fillCircle(cx, cy, r)` is a centre and a '
            'radius; SwiftUI wants the bounding box, so the same circle is '
            'spelled out as centre minus radius.',
      );
      expect(
        source,
        contains('let radius = side / 12'),
        reason: '$rule1 …of radius width/12.',
      );
      expect(
        source,
        contains('square == .on || square == .grey ? WidgetTheme.lowContrastText'),
        reason: '$rule1 The same two-arm colour table the core has.',
      );
      expect(
        source,
        isNot(contains('The notes indicator is deliberately absent')),
        reason: '$rule1 The comment that stood in for the feature described '
            'the gap accurately; it must not outlive it.',
      );
    });
  });
}

/// Records what the bridge published, in place of the platform channel.
class FakeHomeWidgetPlatform implements HomeWidgetPlatform {
  final Map<String, String?> data = <String, String?>{};
  final List<String> refreshedProviders = <String>[];

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
  }) async {
    refreshedProviders.add(name);
  }

  @override
  Future<void> setAppGroupId(String groupId) async {}
}
