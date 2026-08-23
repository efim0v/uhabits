/// `audit6.home-screen-widgets-go-stale-at`: what the hourly widget refresh
/// has to draw.
///
/// Every `appwidget-provider` declares `android:updatePeriodMillis="3600000"`,
/// so Android broadcasts `ACTION_APPWIDGET_UPDATE` to each of the six providers
/// about once an hour — starting the app process if it is dead. Upstream that
/// broadcast is enough on its own: `BaseWidgetProvider.onUpdate` resolves
/// `habitList` and `getToday()` live out of the application component and
/// redraws from the database, so within the hour after the logical midnight the
/// Checkmark widget shows the new day, unchecked, without the user ever opening
/// the app.
///
/// The port kept the declaration and lost the redraw. Its providers do not run
/// inside the app: they read one published JSON document per widget out of
/// shared storage, and that document is a *snapshot* — it names the day it was
/// built for and carries `entries[0] = today`. Nothing in the launcher's
/// process ever moved it on, so the hourly broadcast re-rendered yesterday's
/// snapshot, hour after hour, and the widget only corrected itself when the
/// Flutter side next ran and republished. `audit5.home-screen-widgets-never-
/// roll-over` gave the rollover a clock of its own, but that clock is a Dart
/// timer: it cannot fire in a process that is not running, which is exactly the
/// case this rule is about.
///
/// So the roll-forward has to happen where the drawing happens — in
/// `WidgetData.readWidget`, the one place both `BaseWidgetProvider.update` and
/// `StackWidgetService` obtain a document. The app publishes the midnight-delay
/// preference along with the snapshot; the launcher-side reader computes the
/// logical today the same way `computeToday(midnightDelayHours, 0)` does, and
/// advances the document by the whole days that have passed: today moves, the
/// newest-first entry arrays shift by that many places, and the days nobody
/// answered come back UNKNOWN.
///
/// ## Why the launcher half is asserted from source
///
/// An `AppWidgetProvider` runs in the launcher's process; `flutter test` has
/// neither a launcher nor a JVM, so the Kotlin cannot be executed here — the
/// same constraint app/test/platform/android_widgets_test.dart and
/// app/test/platform/widget_question_mark_glyph_test.dart work under. The
/// publishing half *is* Dart and is run for real.
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
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';

// ---------------------------------------------------------------------------
// Reading the Android source set
// ---------------------------------------------------------------------------

final Directory androidMain = _findAndroidMain();

Directory _findAndroidMain() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String prefix in <String>['', '/app']) {
      final Directory candidate =
          Directory('${dir.path}$prefix/android/app/src/main');
      if (File('${candidate.path}/AndroidManifest.xml').existsSync()) {
        return candidate;
      }
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError(
    'android/app/src/main not found from ${Directory.current.path}',
  );
}

String widgetKotlin(String name) => File(
        '${androidMain.path}/kotlin/org/isoron/uhabits/widgets/$name')
    .readAsStringSync();

String widgetXml(String name) =>
    File('${androidMain.path}/res/xml/$name').readAsStringSync();

/// [source] with its comments stripped, so an assertion about what the code
/// does cannot be satisfied by prose that merely names the thing.
String withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// [source] with every run of whitespace collapsed to one space.
String squashed(String source) => source
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll('( ', '(')
    .replaceAll(' )', ')');

const String rule1 =
    'audit6.home-screen-widgets-go-stale-at#1 — In the Kotlin app: Every '
    'appwidget-provider declares `updatePeriodMillis="3600000"`, so the system '
    'broadcasts APPWIDGET_UPDATE about once an hour. That broadcast starts the '
    'app process if it is dead, and `BaseWidgetProvider.onUpdate` then resolves '
    '`habitList` and `getToday()` live out of the application component and '
    'redraws from the database. Independently, '
    '`WidgetUpdater.scheduleStartDayWidgetUpdate()` arms an `AlarmManager` RTC '
    'broadcast to `WidgetReceiver` at the next logical midnight, which calls '
    '`setToday(...)` and redraws. Between the two, a Checkmark widget left on '
    'the home screen rolls over to the new day, and shows the new day as '
    'unchecked, without the user ever opening the app.';

void main() {
  // =======================================================================
  // The publisher: the preference the launcher needs to date the snapshot
  // =======================================================================

  group('audit6.home-screen-widgets-go-stale-at (the document)', () {
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
      final Habit habit = fixtures.createEmptyHabit(name: 'Meditate');
      habit.originalEntries.add(Entry(today, Entry.yesManual));
      habit.recompute();
      habitList.add(habit);
      registry.addWidget(7, <int>[habit.id!]);
    });

    tearDown(() {
      DateUtils.setFixedTimeZone(null);
      getDefaultTimeZone = realZone;
    });

    Map<String, Object?> document() =>
        jsonDecode(platform.data[HomeWidgetBridge.documentKey(7)]!)
            as Map<String, Object?>;

    test('#1 the snapshot says which day it was built for', () async {
      await bridge.publish();

      expect(document()['today'], '2015-01-26',
          reason: '$rule1 The document is a snapshot of one logical day; the '
              'launcher can only tell that it has gone stale by comparing this '
              'against the day it is being drawn on.');
    });

    test('#1 …and how that day is computed, so the launcher can redo it',
        () async {
      await bridge.publish();
      expect(document()['midnightDelayHours'], 0,
          reason: '$rule1 Upstream the provider calls `getToday()` in the '
              'app\'s own process, where `Preferences` is at hand. Here it '
              'runs in the launcher\'s, so the one input of '
              '`computeToday(midnightDelayHours, 0)` that is not the system '
              'clock has to ride on the document — otherwise a redraw either '
              'cannot move the day at all, or moves it at the wrong hour.');

      preferences.isMidnightDelayEnabled = true;
      await bridge.publish();
      expect(document()['midnightDelayHours'], 3,
          reason: '$rule1 `Preferences.midnightDelayHours` is 3 while the '
              '"new day starts at 3am" row is on, and the widget\'s day has to '
              'turn at the same hour the app\'s does.');
    });
  });

  // =======================================================================
  // The launcher: an hourly broadcast with something fresh to draw
  // =======================================================================

  group('audit6.home-screen-widgets-go-stale-at (the launcher)', () {
    test('#1 all six providers still ask for the hourly broadcast', () {
      for (final String name in <String>[
        'widget_checkmark_info.xml',
        'widget_history_info.xml',
        'widget_score_info.xml',
        'widget_streak_info.xml',
        'widget_frequency_info.xml',
        'widget_target_info.xml',
      ]) {
        expect(
          withoutComments(widgetXml(name)),
          contains('android:updatePeriodMillis="3600000"'),
          reason: '$rule1 The declaration is what makes the redraw below '
              'happen at all, in $name.',
        );
      }
    });

    test('#1 reading a document advances it to the day it is drawn on', () {
      final String data = squashed(withoutComments(widgetKotlin('WidgetData.kt')));

      expect(
        data,
        contains('val document = WidgetDocument.parse(json) return '
            'document.rolledForwardTo(LocalDate.today('
            'document.midnightDelayHours))'),
        reason: '$rule1 `readWidget` is the single place both '
            '`BaseWidgetProvider.update` and `StackWidgetService` obtain a '
            'document, so it is where a snapshot built for an earlier day has '
            'to become one for this day.',
      );
      expect(
        data,
        contains('val midnightDelayHours: Int'),
        reason: '$rule1 …computed from the published preference, not from a '
            'guess: a user whose day turns at 3am must not see the widget turn '
            'at midnight.',
      );
    });

    test('#1 the logical today is `computeToday(midnightDelayHours, 0)`', () {
      final String data = squashed(withoutComments(widgetKotlin('WidgetData.kt')));

      expect(
        data,
        contains('fun today(hourOffset: Int): LocalDate'),
        reason: '$rule1 The one thing the launcher process may ask the system '
            'for: what time it is now.',
      );
      expect(
        data,
        contains('val local = now + TimeZone.getDefault().getOffset(now)'),
        reason: '$rule1 `computeToday` reads the wall clock in the device\'s '
            'own timezone, exactly as `DateUtils` does.',
      );
      expect(
        data,
        contains('val adjusted = local - hourOffset * 60L * 60L * 1000L'),
        reason: '$rule1 …minus the midnight delay, so the day turns at 3am for '
            'a user who asked for that.',
      );
    });

    test('#1 rolling forward moves the day and shifts the entries', () {
      final String data = squashed(withoutComments(widgetKotlin('WidgetData.kt')));

      expect(
        data,
        contains('fun rolledForwardTo(current: LocalDate): WidgetDocument'),
        reason: rule1,
      );
      expect(
        data,
        contains('val days = current.daysSince(today) if (days <= 0) '
            'return this'),
        reason: '$rule1 A document built for today — or, under a timezone move, '
            'for a day still ahead — is already what the launcher should draw, '
            'and re-deriving it would only lose information.',
      );
      expect(
        data,
        contains('IntArray(entries.size) { if (it < days) Entry.UNKNOWN '
            'else entries[it - days] }'),
        reason: '$rule1 The arrays are newest-first, so a day passing shifts '
            'every value one place *down* the array and the day nobody has '
            'answered yet arrives UNKNOWN. That is what makes the Checkmark '
            'widget show the new day as unchecked.',
      );
      expect(
        data,
        contains('List(notesIndicators.size) { if (it < days) false '
            'else notesIndicators[it - days] }'),
        reason: '$rule1 The note dots are indexed by the same offsets, so they '
            'have to travel with the entries or they would mark the wrong '
            'days.',
      );
      expect(
        data,
        contains('value = shifted.firstOrNull() ?: Entry.UNKNOWN'),
        reason: '$rule1 `value` is `entries[0]` by definition, and it is what '
            '`CheckmarkWidget` draws the glyph and the tick from.',
      );
    });

    test('#1 the redrawn widget is dated by the rolled-forward document', () {
      final String provider =
          squashed(withoutComments(widgetKotlin('BaseWidgetProvider.kt')));

      expect(
        provider,
        contains('val document = WidgetData.readWidget(context, widgetId)'),
        reason: '$rule1 Every redraw — the hourly broadcast, a resize, a '
            'launcher restart — goes through this one call, so nothing has to '
            'remember to ask for a fresh day.',
      );
      expect(
        squashed(withoutComments(widgetKotlin('CheckmarkWidgetProvider.kt'))),
        contains('document.today'),
        reason: '$rule1 …and the widget is built with the document\'s day, '
            'which is now the day it is being drawn on. The date the value '
            'picker opens on comes from the same field '
            '(`widgets.checkmark#7`), so a tap after midnight edits today '
            'rather than yesterday.',
      );
    });
  });
}

/// Records what the bridge published, in place of the platform channel.
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
