/// `audit4.ios-home-screen-widgets-never-receive` and
/// `audit4.ios-the-app-group-is-never`: the shared container the app publishes
/// into, and the catalogue it has to publish there for an iOS widget to have
/// anything to bind to.
///
/// ## Why these two are one test file
///
/// On Android a widget provider runs inside the launcher's process and reads
/// the app's own `SharedPreferences`; there is nothing to configure and nothing
/// that can be forgotten. On iOS the widget extension is a separate process
/// with its own container, and the app and the extension see the same
/// `UserDefaults` only through an App Group — a string that has to be handed to
/// `HomeWidget.setAppGroupId` before the first write. `WidgetData.swift` reads
/// `UserDefaults(suiteName: "group.org.isoron.uhabits")`; if the Dart side
/// never names that suite, every `saveWidgetData` lands in the app's own
/// defaults, the extension reads an empty store, and all six widgets are
/// permanently blank. Nothing about that is visible from a journey: no Dart
/// code fails, no test breaks, the widgets are simply empty on the device.
///
/// The second half is the same wall from the other side. The published index
/// used to enumerate `WidgetRegistry` and nothing else, and the registry is
/// written by exactly one caller — the Android `uhabits://widget/configure`
/// deep link, which is the port of `HabitPickerDialog`. iOS has no configure
/// activity and no widget id at all: a WidgetKit widget is configured by an
/// App Intent whose habit parameter is filled from `HabitEntityQuery`, which
/// lists whatever the app has published (`HabitSelection.swift`). With an empty
/// registry the app publishes an index with no widgets, so the query has no
/// habits, so the user cannot pick one, so the registry stays empty. The index
/// therefore has to carry the habit catalogue itself, independently of any
/// widget binding.
///
/// ## What is asserted where
///
/// The Dart half runs: it publishes through the real [HomeWidgetPlugin] over a
/// mocked `home_widget` method channel, so the order of the calls that cross to
/// the platform is a fact this test observes rather than a claim about source.
/// The native half is read from the files, the way
/// test/platform/ios_widgets_test.dart and test/platform/ios_bundle_test.dart
/// already read the iOS source set: an entitlement and a Swift constant are
/// declarations no Dart test can execute, and reading them is what catches one
/// silently disappearing (`audit4.harness-blind-spots#3`).
library;

// The core is reached by its `src` path, exactly as lib/state/app_scope.dart
// reaches it.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';

// ---------------------------------------------------------------------------
// Locating the source sets
// ---------------------------------------------------------------------------

final Directory appDir = _findApp();

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

String read(String relative) =>
    File('${appDir.path}/$relative').readAsStringSync();

/// The `<string>` entries of the `com.apple.security.application-groups` array
/// of an entitlements plist.
List<String> applicationGroups(String relative) {
  final String plist = read(relative);
  final int key = plist.indexOf('com.apple.security.application-groups');
  if (key < 0) return const <String>[];
  final int start = plist.indexOf('<array>', key);
  final int end = plist.indexOf('</array>', start);
  if (start < 0 || end < 0) return const <String>[];
  return RegExp(r'<string>([^<]*)</string>')
      .allMatches(plist.substring(start, end))
      .map((RegExpMatch m) => m.group(1)!)
      .toList();
}

/// The first capture of [pattern], or a failure naming what was looked for.
String capture(String source, RegExp pattern, {required String what}) {
  final RegExpMatch? match = pattern.firstMatch(source);
  if (match == null) fail('$what: no match for ${pattern.pattern}');
  return match.group(1)!;
}

// ---------------------------------------------------------------------------

const String ruleReceive =
    'audit4.ios-home-screen-widgets-never-receive#1 — In the Kotlin app: On '
    'Android the provider runs in the launcher\'s process and reads the app\'s '
    'own data directly, so a placed widget always shows real habit data. The '
    'port reproduces this cross-platform by publishing JSON into shared '
    'storage; on iOS that storage is the App Group `group.org.isoron.uhabits`, '
    'which `app/ios/HabitsWidget/WidgetData.swift` (WidgetContract.appGroupId, '
    'WidgetStore.init) reads through `UserDefaults(suiteName:)`, and whose own '
    'doc comment says "`HomeWidgetPlugin.ensureInitialized()` passes the same '
    'string to `HomeWidget.setAppGroupId`".';

const String ruleGroup =
    'audit4.ios-the-app-group-is-never#1 — In the Kotlin app: A placed widget '
    'is handed its widget id, the provider resolves the bound habits out of '
    'the running app\'s component, and the widget draws the habit\'s '
    'ring/graph. Every command republishes it through WidgetUpdater.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -----------------------------------------------------------------------
  // The mocked `home_widget` channel
  // -----------------------------------------------------------------------

  const MethodChannel channel = MethodChannel('home_widget');
  final List<MethodCall> platformCalls = <MethodCall>[];

  late MemoryModelFactory modelFactory;
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late MemoryStorage storage;
  late WidgetRegistry registry;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 26));
    platformCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      platformCalls.add(call);
      // `getWidgetData` and `initiallyLaunchedFromHomeWidget` are declared
      // `invokeMethod<String>` by the plugin, so answering every method with
      // `true` throws a cast error the moment anything reads a stored value.
      switch (call.method) {
        case 'getWidgetData':
        case 'initiallyLaunchedFromHomeWidget':
          return null;
        default:
          return true;
      }
    });
    modelFactory = MemoryModelFactory();
    habitList = MemoryHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    storage = MemoryStorage();
    registry = WidgetRegistry(storage);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Habit addHabit(String name) {
    final Habit habit = fixtures.createEmptyHabit(name: name);
    habitList.add(habit);
    return habit;
  }

  HomeWidgetBridge bridgeOver(HomeWidgetPlatform platform) => HomeWidgetBridge(
        habitList: habitList,
        registry: registry,
        platform: platform,
      );

  Map<String, Object?> decode(String? json) =>
      jsonDecode(json!) as Map<String, Object?>;

  // =======================================================================
  // The App Group
  // =======================================================================

  group('audit4.ios-home-screen-widgets-never-receive', () {
    test('#1 the app names the App Group the extension reads', () async {
      final HomeWidgetPlugin plugin = HomeWidgetPlugin();

      expect(plugin.appGroupId, HomeWidgetPlugin.iosAppGroupId,
          reason: '$ruleReceive `HomeWidgetPlugin({this.appGroupId})` with a '
              'null default is what left the group unset: AppScope builds the '
              'plugin with no argument, so `ensureInitialized()` had nothing '
              'to pass on even when it was called.');
      expect(HomeWidgetPlugin.iosAppGroupId, 'group.org.isoron.uhabits',
          reason: '$ruleReceive The rule names the suite verbatim, and '
              'WidgetData.swift reads that one string.');
    });

    test('#1 ensureInitialized() hands the group to the platform', () async {
      await HomeWidgetPlugin().ensureInitialized();

      expect(platformCalls.map((MethodCall c) => c.method),
          contains('setAppGroupId'),
          reason: '$ruleReceive `ensureInitialized()` had no caller at all, '
              'and calling it is the only thing that makes `saveWidgetData` '
              'write into `UserDefaults(suiteName:)` instead of the app\'s own '
              'defaults.');
      expect(
        (platformCalls
            .firstWhere((MethodCall c) => c.method == 'setAppGroupId')
            .arguments as Map<Object?, Object?>)['groupId'],
        'group.org.isoron.uhabits',
        reason: ruleReceive,
      );
    });

    test('#1 the group is set before the first document is written', () async {
      addHabit('Meditate');
      registry.addWidget(1, <int>[habitList.first.id!]);

      await bridgeOver(HomeWidgetPlugin()).publish();

      final List<String> methods =
          platformCalls.map((MethodCall c) => c.method).toList();
      expect(methods, contains('saveWidgetData'), reason: ruleReceive);
      expect(methods, contains('setAppGroupId'),
          reason: '$ruleReceive Publishing without naming the suite first is '
              'the whole defect: the write is refused and the extension keeps '
              'reading an empty store.');
      expect(
        methods.indexOf('setAppGroupId'),
        lessThan(methods.indexOf('saveWidgetData')),
        reason: '$ruleReceive The iOS plugin answers `saveWidgetData` with '
            'error -7 ("AppGroupId not set") until the suite is named, so a '
            'publish that runs first is a publish that is thrown away. The '
            'order is the whole fix: name the suite, then write.',
      );
    });

    test('#1 both entitlements and the Swift contract name the same suite',
        () {
      final String swift = read('ios/HabitsWidget/WidgetData.swift');
      final String declared = capture(
        swift,
        RegExp(r'static let appGroupId = "([^"]+)"'),
        what: 'WidgetContract.appGroupId',
      );

      expect(declared, HomeWidgetPlugin.iosAppGroupId,
          reason: '$ruleReceive The two sides must match exactly or the '
              'extension reads an empty store.');
      expect(swift, contains('UserDefaults(suiteName: appGroupId)'),
          reason: '$ruleReceive WidgetStore reads the suite; that is the read '
              'half of the same contract.');

      for (final String entitlements in <String>[
        'ios/Runner/Runner.entitlements',
        'ios/HabitsWidget/HabitsWidget.entitlements',
      ]) {
        expect(applicationGroups(entitlements),
            contains(HomeWidgetPlugin.iosAppGroupId),
            reason: '$ruleReceive A suite name only opens a shared container '
                'when both targets are entitled to it; $entitlements is one '
                'half of that.');
      }
    });

    test('#1 nothing in lib/ builds the plugin without the group', () {
      // Comments stripped, so an assertion about what the code does cannot be
      // satisfied — or defeated — by prose that merely names the thing. Same
      // helper, same reason, as test/platform/android_widgets_test.dart.
      final String scope = read('lib/state/app_scope.dart')
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
          .replaceAll(RegExp(r'//[^\n]*'), '');

      expect(RegExp(r'HomeWidgetPlugin\(\s*appGroupId:').hasMatch(scope), isTrue,
          reason: '$ruleReceive app_scope.dart:314 built `HomeWidgetPlugin()` '
              'with no arguments, which is where the group went missing.');
      expect(scope, contains('ensureInitialized()'),
          reason: '$ruleReceive …and nothing called `ensureInitialized()`, '
              'which is the only caller `setAppGroupId` was ever going to '
              'have.');
      expect(
        RegExp(r'HomeWidgetPlugin\(\s*\)').hasMatch(scope),
        isFalse,
        reason: '$ruleReceive A bare `HomeWidgetPlugin()` is exactly the bug.',
      );
    });
  });

  // =======================================================================
  // The catalogue
  // =======================================================================

  group('audit4.ios-the-app-group-is-never', () {
    test('#1 the index publishes every habit, with no widget registered',
        () async {
      final Habit meditate = addHabit('Meditate');
      final Habit run = addHabit('Run');

      expect(registry.widgetIds, isEmpty,
          reason: '$ruleGroup The registry is written by the Android '
              '`uhabits://widget/configure` deep link and by nothing else, so '
              'on iOS it is empty for the whole life of the app.');

      final FakeHomeWidgetPlatform platform = FakeHomeWidgetPlatform();
      await bridgeOver(platform).publish();

      final Map<String, Object?> index =
          decode(platform.data[HomeWidgetBridge.indexKey]);
      final List<Object?> habits = index['habits']! as List<Object?>;

      expect(
        habits
            .map((Object? h) => (h! as Map<String, Object?>)['id'])
            .toList(),
        <int?>[meditate.id, run.id],
        reason: '$ruleGroup iOS has no widget id and no configure activity: '
            'the widget is bound by an App Intent whose choices come from '
            '`HabitEntityQuery`, which lists what the app published. An index '
            'that enumerates only registered widget ids offers nothing to '
            'pick, so no widget can ever be configured.',
      );
      expect(
        habits
            .map((Object? h) => (h! as Map<String, Object?>)['name'])
            .toList(),
        <String>['Meditate', 'Run'],
        reason: '$ruleGroup The picker lists habits by name.',
      );
    });

    test('#1 a catalogue entry carries what a widget draws', () async {
      final Habit habit = addHabit('Meditate');
      final FakeHomeWidgetPlatform platform = FakeHomeWidgetPlatform();
      await bridgeOver(platform).publish();

      final Map<String, Object?> entry =
          ((decode(platform.data[HomeWidgetBridge.indexKey])['habits']!
                  as List<Object?>)
              .single as Map<String, Object?>);

      expect(entry.keys, containsAll(<String>['id', 'name', 'color', 'type']),
          reason: '$ruleGroup "the widget draws the habit\'s ring/graph" — a '
              'catalogue entry is the same document shape a bound widget gets, '
              'so a widget resolved out of the catalogue draws exactly what a '
              'widget resolved out of its own document draws.');
      expect(entry['id'], habit.id, reason: ruleGroup);
    });

    test('#1 the extension reads the catalogue out of the index', () {
      final String swift = read('ios/HabitsWidget/WidgetData.swift');
      final int index = swift.indexOf('struct WidgetIndex');
      final int end = swift.indexOf('struct WidgetDocument');
      final String declaration = swift.substring(index, end);

      expect(declaration, contains('let habits: [WidgetHabit]'),
          reason: '$ruleGroup `WidgetIndex` has to decode the catalogue, or '
              'the extension cannot see it. `WidgetBinding.habits` is a list '
              'of ids and is not it.');
      expect(swift, contains('index.habits'),
          reason: '$ruleGroup …and `WidgetStore.allHabits()` — the list '
              '`HabitEntityQuery` offers and `resolve` falls back on — has to '
              'read it.');
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// [HomeWidgetPlatform] over a map, for the assertions about *what* is
/// published rather than about how it crosses to the platform.
class FakeHomeWidgetPlatform implements HomeWidgetPlatform {
  final Map<String, String?> data = <String, String?>{};
  final List<String> calls = <String>[];

  @override
  Future<void> saveWidgetData(String id, String? value) async {
    calls.add('save:$id');
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
    calls.add('update:$name');
  }

  @override
  Future<void> setAppGroupId(String groupId) async {
    calls.add('group:$groupId');
  }
}
