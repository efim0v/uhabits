/// `audit4.deleting-a-widget-from-the-launcher` — dragging a widget off the
/// home screen has to clear its habit binding.
///
/// Upstream this is three lines and no protocol at all: `BaseWidgetProvider.
/// onDeleted` runs `BaseWidget.delete()`, which runs
/// `WidgetPreferences.removeWidget(id)`, and the provider *is* the app, so the
/// `widget-%06d-habit` key is gone the moment the launcher says the widget is
/// (`widgets.provider-lifecycle#8`).
///
/// The port has a process boundary through the middle of that sentence. The
/// binding lives in the Dart `WidgetRegistry`, the deletion is observed by
/// Kotlin running in the launcher's process, and only one of the two may write
/// the store — a native writer would race the Flutter one with no lock between
/// them. So `onDeleted` records the ids and the next publish reaps them, which
/// is the same two steps in the same order, split across the boundary.
///
/// Both halves are asserted here, because either alone is inert: a Dart reaper
/// nothing reports to never runs, and a Kotlin recorder nothing reads is a key
/// that grows forever.
library;

// The core is reached by its `src` path, exactly as the bridge does.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';

const String rule =
    'audit4.deleting-a-widget-from-the-launcher#1 — Removing a widget from the '
    'home screen deletes its `widget-%06d-habit` preference entry, so the '
    'binding does not outlive the widget.';

// ---------------------------------------------------------------------------
// The platform, with a launcher behind it
// ---------------------------------------------------------------------------

/// A widget host that has a deletion to report.
///
/// It implements both halves of the boundary, because the real one does: the
/// app builds a single `HomeWidgetPlugin` and it is the same object that
/// writes documents and reads back what the providers left behind.
class FakeWidgetHost implements HomeWidgetPlatform, WidgetDeletionSource {
  FakeWidgetHost({List<int> deleted = const <int>[]})
      : _deleted = List<int>.of(deleted);

  List<int> _deleted;

  /// Every `saveWidgetData`, in order. A null value is a key removal.
  final Map<String, String?> written = <String, String?>{};

  final List<String> writeOrder = <String>[];

  /// How many times the reaper asked.
  int takeCount = 0;

  @override
  Future<List<int>> takeDeletedWidgetIds() async {
    takeCount++;
    final List<int> ids = _deleted;
    // Reported once: the launcher's record is consumed, not polled.
    _deleted = <int>[];
    return ids;
  }

  @override
  Future<void> saveWidgetData(String id, String? value) async {
    written[id] = value;
    writeOrder.add(id);
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

// ---------------------------------------------------------------------------
// Reading the Kotlin source set
// ---------------------------------------------------------------------------

final Directory androidMain =
    _find('android/app/src/main', 'AndroidManifest.xml');

Directory _find(String suffix, String marker) {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String prefix in <String>['', 'app/']) {
      final Directory candidate = Directory('${dir.path}/$prefix$suffix');
      if (File('${candidate.path}/$marker').existsSync()) return candidate;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('Could not find $suffix (looking for $marker).');
}

String kotlin(String name) =>
    File('${androidMain.path}/kotlin/org/isoron/uhabits/widgets/$name')
        .readAsStringSync();

/// The body of a Kotlin function, from its signature to the matching brace.
String kotlinFunction(String source, String name) {
  final int start = source.indexOf('fun $name(');
  expect(start, isNot(-1), reason: 'no `fun $name(` in the source');
  final int open = source.indexOf('{', start);
  int depth = 0;
  for (int i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(open, i + 1);
    }
  }
  fail('unbalanced braces after `fun $name(`');
}

void main() {
  const TimeZone gmt = FixedTimeZone(0);

  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late MemoryStorage storage;
  late WidgetRegistry registry;

  setUp(() {
    DateUtils.setFixedTimeZone(gmt);
    getDefaultTimeZone = () => gmt;
    setToday(LocalDate.ymd(2015, 1, 26));
    habitList = MemoryHabitList();
    fixtures = HabitFixtures(MemoryModelFactory(), habitList);
    storage = MemoryStorage();
    registry = WidgetRegistry(storage);
  });

  tearDown(() {
    DateUtils.setFixedTimeZone(null);
    getDefaultTimeZone = systemDefaultTimeZone;
  });

  /// A habit in the list, with the id `HabitList.add` assigns it.
  int addHabit(String name) {
    final habit = fixtures.createEmptyHabit(name: name);
    habitList.add(habit);
    return habit.id!;
  }

  HomeWidgetBridge bridgeOver(HomeWidgetPlatform platform) => HomeWidgetBridge(
        habitList: habitList,
        registry: registry,
        platform: platform,
      );

  // -----------------------------------------------------------------------
  // The Dart half: the binding is reaped
  // -----------------------------------------------------------------------

  group('the reaper', () {
    test('a deleted widget loses its habit binding', () async {
      final int habitId = addHabit('Wake up');
      registry.addWidget(7, <int>[habitId]);
      registry.addWidget(9, <int>[habitId]);

      final FakeWidgetHost host = FakeWidgetHost(deleted: <int>[7]);
      await bridgeOver(host).publish();

      expect(host.takeCount, 1,
          reason: '$rule Every publish is a chance to reap: it is the one thing '
              'that runs at startup, after every command, on resume and at the '
              'day rollover.');
      expect(registry.widgetIds, <int>[9],
          reason: '$rule The widget the launcher removed is gone from the '
              'registry.');
      expect(registry.habitIdsOf(7), isEmpty,
          reason: '$rule …and so is its widget-%06d-habit entry, which is what '
              'BaseWidget.delete() removed upstream.');
      expect(registry.habitIdsOf(9), <int>[habitId],
          reason: '$rule The widget that is still on the home screen keeps '
              'its habit.');
    });

    test('and the app stops republishing its document', () async {
      final int habitId = addHabit('Wake up');
      registry.addWidget(7, <int>[habitId]);

      final FakeWidgetHost host = FakeWidgetHost(deleted: <int>[7]);
      await bridgeOver(host).publish();

      expect(host.written.containsKey(HomeWidgetBridge.documentKey(7)), isFalse,
          reason: '$rule A binding that outlives its widget is a document the '
              'app rewrites forever, for a widget nobody can see.');

      final Object? index =
          jsonDecode(host.written[HomeWidgetBridge.indexKey]!);
      expect((index as Map<String, Object?>)['widgets'], isEmpty,
          reason: '$rule The published index is the registry, so the deleted '
              'widget is absent from it too.');
    });

    test('the reap happens before the publish decides what to write', () async {
      // Order matters exactly as it does upstream, where `removeWidget` runs in
      // `onDeleted` — before any later `updateWidgets()` could look the widget
      // up. Reaping after the write would publish one last dead document.
      final int habitId = addHabit('Wake up');
      registry.addWidget(7, <int>[habitId]);
      registry.addWidget(9, <int>[habitId]);

      final FakeWidgetHost host = FakeWidgetHost(deleted: <int>[7, 9]);
      await bridgeOver(host).publish(habitId);

      expect(host.writeOrder, <String>[HomeWidgetBridge.indexKey],
          reason: '$rule Both widgets were reaped first, so the filtered id '
              'list was empty and only the index went out.');
    });

    test('a host with nothing to report changes nothing', () async {
      final int habitId = addHabit('Wake up');
      registry.addWidget(7, <int>[habitId]);

      final FakeWidgetHost host = FakeWidgetHost();
      await bridgeOver(host).publish();

      expect(registry.widgetIds, <int>[7], reason: rule);
      expect(host.written[HomeWidgetBridge.documentKey(7)], isNotNull,
          reason: rule);
    });

    test('the app\'s own platform is a deletion source', () {
      // The defect this feature records was not a broken reaper — it was that
      // `WidgetRegistry.removeWidget` was never called from anywhere in
      // app/lib. A reaper the app never wires up would be the same defect
      // again, so the object `AppScope` actually builds is checked here.
      expect(HomeWidgetPlugin(), isA<WidgetDeletionSource>(),
          reason: '$rule HomeWidgetPlugin is what app_scope.dart passes as the '
              'platform, and it is the only thing that can read what the '
              'providers left in shared storage.');
    });
  });

  // -----------------------------------------------------------------------
  // The Kotlin half: the launcher records the deletion
  // -----------------------------------------------------------------------

  group('the provider', () {
    test('onDeleted records the ids under the key Dart reads', () {
      // `audit4.harness-blind-spots#3`: this declaration carries behaviour and
      // no journey can reach it, so it is read from the file that ships it.
      final String provider = kotlin('BaseWidgetProvider.kt');
      final String body = kotlinFunction(provider, 'onDeleted');

      expect(body, contains('DELETED_KEY'),
          reason: '$rule onDeleted is the only moment Android tells anyone the '
              'widget is gone; a provider that does not record it leaves the '
              'Dart registry with no way to ever find out.');
      expect(body, contains('documentKey'),
          reason: '$rule It also drops the published document, which is the '
              'launcher-side copy of the data.');

      final String data = kotlin('WidgetData.kt');
      expect(
        data,
        contains('"\$KEY_PREFIX.deleted"'),
        reason: '$rule The two sides have to name one key: '
            '${HomeWidgetPlugin.deletedKey}.',
      );
      expect(HomeWidgetPlugin.deletedKey,
          '${HomeWidgetBridge.keyPrefix}.deleted',
          reason: '$rule …and that is the key the Dart reaper reads.');
    });
  });
}
