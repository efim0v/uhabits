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

// ---------------------------------------------------------------------------
// Reading the iOS source set
// ---------------------------------------------------------------------------

final Directory widgetDir = Directory('${_findApp().path}/ios/HabitsWidget');

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

const String rule15 =
    'audit15.ios-home-screen-widgets-never-roll#1 — In the Kotlin app: a '
    'widget redraws from live app state, so it can never draw a day that has '
    'already passed. `CheckmarkWidget.refreshData` calls `getToday()` on every '
    'ACTION_APPWIDGET_UPDATE and reads `habit.computedEntries.get(today)` and '
    '`habit.scores[today]` out of the database, and '
    '`pendingIntentFactory.showNumberPicker(habit, getToday())` rebuilds the '
    'value-picker intent against that same fresh day. The app-wide '
    '`getToday()` is re-stamped without the app being opened: '
    '`WidgetUpdater.scheduleStartDayWidgetUpdate()` arms an `AlarmManager` RTC '
    'broadcast at `getStartOfTomorrowWithOffset(midnightDelayHours, 0)`, and '
    '`WidgetReceiver`\'s ACTION_UPDATE_WIDGETS_VALUE branch runs '
    '`setToday(computeToday(prefs.midnightDelayHours, 0))` and redraws. The '
    'tap carries no day at all — an ACTION_TOGGLE_REPETITION broadcast has no '
    '`timestamp` extra, so `IntentParser.parseDate` defaults it to '
    '`getToday()` and refuses anything later than that. A Checkmark widget '
    'left on the home screen therefore shows the new day unchecked at the '
    'user\'s own midnight, and a tap on it always records against the day the '
    'app is on.';

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

  // =======================================================================
  // The same rule on the other host: the WidgetKit extension
  // =======================================================================

  group('audit15.ios-home-screen-widgets-never-roll (the document)', () {
    const TimeZone gmt = FixedTimeZone(0);
    final TimeZone Function() realZone = getDefaultTimeZone;
    final LocalDate today = LocalDate.ymd(2015, 1, 26);

    late MemoryStorage storage;
    late Preferences preferences;
    late FakeHomeWidgetPlatform platform;
    late HomeWidgetBridge bridge;

    setUp(() {
      DateUtils.setFixedTimeZone(gmt);
      getDefaultTimeZone = () => gmt;
      setToday(today);
      final MemoryHabitList habitList = MemoryHabitList();
      final HabitFixtures fixtures =
          HabitFixtures(MemoryModelFactory(), habitList);
      storage = MemoryStorage();
      preferences = Preferences(storage);
      platform = FakeHomeWidgetPlatform();
      bridge = HomeWidgetBridge(
        habitList: habitList,
        registry: WidgetRegistry(storage),
        platform: platform,
        preferences: preferences,
      );
      habitList.add(fixtures.createEmptyHabit(name: 'Meditate'));
    });

    tearDown(() {
      DateUtils.setFixedTimeZone(null);
      getDefaultTimeZone = realZone;
    });

    Map<String, Object?> index() =>
        jsonDecode(platform.data[HomeWidgetBridge.indexKey]!)
            as Map<String, Object?>;

    test('#1 the index carries the hour the day turns at', () async {
      await bridge.publish();
      expect(index()['today'], '2015-01-26', reason: rule15);
      expect(index()['midnightDelayHours'], 0,
          reason: '$rule15 An iOS widget has no per-widget document to read: '
              'WidgetKit has no widget id and no configure activity, so the '
              'extension resolves its habit out of the index catalogue and the '
              'index is the only thing it reads. Rolling that snapshot on to '
              'the day it is being drawn on needs the one input of '
              '`computeToday(midnightDelayHours, 0)` that is not the system '
              'clock, and the index published `today` without it.');

      preferences.isMidnightDelayEnabled = true;
      await bridge.publish();
      expect(index()['midnightDelayHours'], 3,
          reason: '$rule15 `WidgetUpdater.scheduleStartDayWidgetUpdate()` arms '
              'its alarm at `getStartOfTomorrowWithOffset(midnightDelayHours, '
              '0)`, so a user whose day starts at 3am sees the widget turn at '
              '3am. An extension that never learns the offset turns the day up '
              'to three hours early.');
    });
  });

  group('audit15.ios-home-screen-widgets-never-roll (the extension)', () {
    String widgetData() => squashed(withoutComments(swift('WidgetData.swift')));

    test('#1 the extension works out which day it is being drawn on', () {
      final String data = widgetData();

      expect(
        data,
        contains('static func logicalToday(midnightDelayHours: Int, '
            'now: Date = Date(), zone: TimeZone = .current) -> Date'),
        reason: '$rule15 `WidgetStore.today()` returned the published string '
            'verbatim, so the day the cards drew was the day the app last ran '
            '— forever. The one thing this process may ask the system is what '
            'instant it is now; which day that instant belongs to is still the '
            'app\'s rule.',
      );
      expect(
        data,
        contains('let local = '
            'now.addingTimeInterval(Double(zone.secondsFromGMT(for: now)))'),
        reason: '$rule15 …and the day that instant belongs to is the LOCAL '
            'civil day, exactly as `DateUtils.getLocalTime()` is `now + '
            'tz.getOffset(now)` before the day is floored. `widgetCalendar` is '
            'pinned to UTC for the wire format, so flooring the raw instant '
            'with it would answer the UTC day instead.',
      );
      expect(
        data,
        contains('local.addingTimeInterval(-Double(midnightDelayHours) * 3600)'),
        reason: '$rule15 …minus the midnight delay the index publishes, '
            'because `computeToday(hourOffset, 0)` is what the app itself '
            'would have answered.',
      );
    });

    test('#1 every document the extension reads is advanced to that day', () {
      final String data = widgetData();

      expect(
        data,
        contains('let document = rolledDocument(forKey: key, in: defaults)'),
        reason: '$rule15 `WidgetStore.decode` is the single point every reader '
            'passes through — `index()`, `document(widgetId:)` and so every '
            'card of all six widgets — which makes it the iOS counterpart of '
            '`WidgetData.readWidget`, where the Android host already turns a '
            'snapshot built for an earlier day into one for this day.',
      );
      expect(
        data,
        contains('let delay = document["midnightDelayHours"] as? Int ?? 0'),
        reason: '$rule15 Read defensively: an index written before the field '
            'existed carries no key, and 0 — a day that turns at midnight — is '
            'the preference\'s own default.',
      );
      expect(
        data,
        contains('let midnightDelayHours: Int?'),
        reason: '$rule15 …and declared optional on `WidgetIndex` for the same '
            'reason. A widget outlives an app update for as long as it sits on '
            'the home screen, and `JSONDecoder` fails the whole struct on one '
            'missing non-optional key — which `WidgetStore.decode` answers nil '
            'for, turning every card into the "no habit" placeholder.',
      );
    });

    test('#1 rolling forward moves the day and shifts the arrays', () {
      final String data = widgetData();

      expect(
        data,
        contains('static func rolledForward(_ document: [String: Any], '
            'to current: Date) -> [String: Any]'),
        reason: '$rule15 The port of `WidgetDocument.rolledForwardTo`, which '
            'app/android/.../widgets/WidgetData.kt has had since '
            '`audit6.home-screen-widgets-go-stale-at#1` and the extension '
            'never got.',
      );
      expect(
        data,
        contains('let days = daysSince(published, to: current) '
            'if days <= 0 { return document }'),
        reason: '$rule15 A document built for today — or, under a timezone '
            'move, for a day still ahead — is already what the extension '
            'should draw.',
      );
      expect(
        data,
        contains('rolled["today"] = formatDate(current)'),
        reason: '$rule15 The day every card dates itself by: the History '
            'grid\'s column origin, the Score chart\'s axis, the Frequency '
            'month buckets, the Streak labels and the `uhabits://widget/edit` '
            'link all derive from it.',
      );
      expect(
        data,
        contains('let shifted = entries.indices.map { \$0 < days ? '
            'EntryValue.unknown : entries[\$0 - days] }'),
        reason: '$rule15 The arrays are newest-first, so a day passing shifts '
            'every value one place down and the days nobody has answered '
            'arrive UNKNOWN — which is what makes the Checkmark widget show '
            'the new day as unchecked.',
      );
      expect(
        data,
        contains('rolled["value"] = shifted.first ?? EntryValue.unknown'),
        reason: '$rule15 `value` is `entries[0]` by definition, and it is what '
            'the tick, the ring glyph and `ToggleHabitIntent`\'s next value '
            'are all read from.',
      );
      expect(
        data,
        contains('notes.indices.map { \$0 < days ? false : '
            'notes[\$0 - days] }'),
        reason: '$rule15 The note dots are indexed by the same offsets, so '
            'they travel with the entries or they mark the wrong days.',
      );
      expect(
        data,
        contains('digits.indices.map { \$0 < days ? offSquare : '
            'digits[\$0 - days] }'),
        reason: '$rule15 The History grid draws `historySeries`, not '
            '`entries` (`audit10.history-home-screen-widget-draws-more#1`); '
            'left unshifted it would paint every square `days` days late.',
      );
    });

    test('#1 what cannot be recomputed here rides along stale', () {
      final String data = widgetData();

      for (final String field in <String>[
        'score',
        'scores',
        'streaks',
        'weekdayFrequency',
        'targetRows',
      ]) {
        expect(data, isNot(contains('rolled["$field"]')),
            reason: '$rule15 Exactly as `WidgetData.kt` documents: `$field` is '
                'a reduction over the habit\'s whole history and there is no '
                'history in this process to reduce. The rollover buys the day, '
                'the grid and the tick; the rest waits for the app.');
      }
    });

    test('#1 a staged tap carries the day it was tapped on', () {
      final String data = widgetData();

      expect(
        data,
        contains('var index = rolledDocument(forKey: WidgetContract.indexKey, '
            'in: defaults)'),
        reason: '$rule15 `stageToggle` read `index["today"]` verbatim and '
            'queued it as the tap\'s date, so a tap made after midnight was '
            'applied to yesterday at the app\'s next launch: yesterday flipped '
            'from YES to NO — the next step of the cycle — and today stayed '
            'blank. The intent never builds a timeline entry, so the '
            'roll-forward has to reach it through the store rather than '
            'through the provider.',
      );
    });

    test('#1 the timeline expires at the day the user\'s day turns', () {
      final String timeline =
          squashed(withoutComments(swift('HabitTimeline.swift')));

      expect(
        timeline,
        contains('WidgetStore.startOfNextDay(midnightDelayHours:'),
        reason: '$rule15 WidgetKit has no `AlarmManager`, so the reload policy '
            'is what stands in for `scheduleStartDayWidgetUpdate()` — and '
            'upstream that alarm is armed at '
            '`getStartOfTomorrowWithOffset(midnightDelayHours, 0)`, not at the '
            'device\'s own midnight.',
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
