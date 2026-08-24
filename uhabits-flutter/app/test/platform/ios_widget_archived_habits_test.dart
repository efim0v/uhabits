/// `audit10.ios-widget-picker-offers-archived`: an archived habit is not a
/// habit a widget can be pointed at.
///
/// Upstream every one of the six widgets is configured by `HabitPickerDialog`
/// or one of its two subclasses, and the list they build starts with a single
/// line (`widgets.config-picker#3`):
///
/// ```kotlin
/// for (h in habitList) {
///     if (h.isArchived) continue
///     if (h.isNumerical and shouldHideNumerical()) continue
///     if (!h.isNumerical and shouldHideBoolean()) continue
///     ...
/// }
/// ```
///
/// So a habit the user archived six months ago to get it out of sight can
/// never be chosen for a Checkmark, History, Score, Frequency, Streak or Target
/// widget. The port's Android half keeps that line —
/// `widgetPickerCandidates` in lib/ui/common/dialogs/widget_picker_dialog.dart
/// opens with `if (habit.isArchived) continue` — and the iOS half dropped it.
///
/// ## What iOS makes of a picker
///
/// WidgetKit has no configure activity. The habit is a parameter of an
/// `AppIntent`, and the list of choices for that parameter is whatever the
/// entity's `defaultQuery.suggestedEntities()` returns
/// (`app/ios/HabitsWidget/HabitSelection.swift`). Those three queries *are*
/// the picker, so the archived clause has to be in them.
///
/// There is a second half with no Android counterpart at all. WidgetKit places
/// a widget before the user has configured it — there is no
/// `RESULT_CANCELED` to return, so "the launcher drops the placement"
/// (`widgets.config-picker#11`) is not available — and `WidgetStore.resolve`
/// covers that by falling back to the first eligible published habit. That
/// fallback is a *render-time* default; it persists nothing. But it stands in
/// for the picker, so it has to refuse the same habits the picker refuses, or
/// a user whose oldest habits are archived drops a Checkmark widget on the home
/// screen and gets a live toggle button for a habit they retired.
///
/// ## What stays unfiltered, deliberately
///
/// Looking a habit up *by id* — `entities(for:)`, `WidgetStore.habit(id:)` —
/// must not filter on archived. Upstream, archiving a habit does not touch
/// `WidgetPreferences`, and `BaseWidgetProvider.getHabitsFromWidgetId` looks
/// its habits up by id with no archived test at all
/// (uhabits-android/.../widgets/BaseWidgetProvider.kt:111-119). A widget bound
/// before the habit was archived goes on drawing it. Filtering the by-id path
/// would flip such a widget to the "habit deleted / not found" card, which is
/// a different upstream state entirely (`widgets.error-states#1`).
///
/// ## What is asserted, and what cannot be
///
/// The Swift half is read from the file, exactly as
/// test/platform/ios_widgets_test.dart reads the `isNumerical` filters of the
/// same three queries: an `EntityQuery` runs inside a WidgetKit extension and
/// nothing in this repository can execute it. What runs is the Dart half of
/// the boundary — that the catalogue the extension filters carries the flag for
/// every habit, and that an archived habit is still published so the by-id path
/// can find it.
library;

// The core is reached by its `src` path, exactly as lib/state does.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits/ui/common/dialogs/widget_picker_dialog.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
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
      if (File('${candidate.path}/ios/HabitsWidget/HabitSelection.swift')
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

/// The text of one Swift declaration: from its header line to the start of the
/// next top-level declaration, so an assertion about one query cannot be
/// satisfied by the contents of the next one. Same helper as
/// test/platform/ios_widgets_test.dart.
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

/// The body of one `func name(...)` inside [source], up to the blank line that
/// ends it — enough to tell what a query filters on without dragging in its
/// neighbour.
String function(String source, String name) {
  final int start = source.indexOf(name);
  if (start < 0) fail('$name is not declared in this scope');
  final int end = source.indexOf('\n    }', start);
  if (end < 0) fail('$name has no closing brace');
  return source.substring(start, end);
}

/// The three entity queries that stand in for `HabitPickerDialog` and its two
/// subclasses, keyed by the Kotlin activity each one replaces.
const Map<String, String> queries = <String, String>{
  'HabitPickerDialog': 'HabitEntityQuery',
  'BooleanHabitPickerDialog': 'BooleanHabitEntityQuery',
  'NumericalHabitPickerDialog': 'NumericalHabitEntityQuery',
};

const String rule =
    'audit10.ios-widget-picker-offers-archived#1 — In the Kotlin app: every '
    'widget is configured by HabitPickerDialog or one of its two subclasses, '
    'and the list they offer starts with `if (h.isArchived) continue` '
    '(HabitPickerDialog.kt:69). An archived habit can never be chosen for any '
    'of the six widgets. Looking a habit up by id is not filtered: archiving '
    'leaves WidgetPreferences untouched and BaseWidgetProvider.'
    'getHabitsFromWidgetId has no archived test, so a widget bound before the '
    'habit was archived goes on drawing it.';

void main() {
  // =======================================================================
  // The extension side: the three pickers, and the placement fallback
  // =======================================================================

  group('audit10.ios-widget-picker-offers-archived (extension)', () {
    late String selection;

    setUp(() => selection = swift('HabitSelection.swift'));

    for (final MapEntry<String, String> entry in queries.entries) {
      test('#1 ${entry.value} does not offer archived habits', () {
        final String body = function(
          declaration(selection, 'struct ${entry.value}'),
          'func suggestedEntities()',
        );

        expect(body, contains(r'!$0.isArchived'),
            reason: '$rule ${entry.value}.suggestedEntities() is the list the '
                "widget's edit sheet shows, which is what ${entry.key} builds "
                'upstream — and its first clause is the archived one. Without '
                'it a user who archived "Quit smoking" six months ago is '
                'offered it again the moment they long-press a Loop widget.');
      });
    }

    test('#1 the two type filters survive alongside it', () {
      final String boolean = function(
        declaration(selection, 'struct BooleanHabitEntityQuery'),
        'func suggestedEntities()',
      );
      final String numerical = function(
        declaration(selection, 'struct NumericalHabitEntityQuery'),
        'func suggestedEntities()',
      );

      expect(boolean, contains(r'!$0.isNumerical'),
          reason: '$rule `widgets.config-picker#4` — BooleanHabitPickerDialog '
              'sets shouldHideNumerical(), and the archived clause is added '
              'to that filter, not in place of it.');
      expect(numerical, contains(r'$0.isNumerical'),
          reason: '$rule `widgets.config-picker#5` — and '
              'NumericalHabitPickerDialog sets shouldHideBoolean().');
      expect(numerical.contains(r'!$0.isNumerical'), isFalse,
          reason: '$rule …the two the other way round from each other, as '
              'test/platform/ios_widgets_test.dart already pins down.');
    });

    test('#1 an unconfigured widget lands on a habit its picker would offer',
        () {
      final String body = function(
        declaration(selection, 'extension WidgetStore'),
        'func resolve(',
      );

      expect(body, contains(r'!$0.isArchived'),
          reason: '$rule WidgetKit places a widget before it is configured — '
              'there is no configure activity to leave RESULT_CANCELED with '
              '(`widgets.config-picker#11`), so this fallback stands in for '
              'the picker on every freshly dropped widget. A fallback that '
              'the picker itself would refuse hands the user a Checkmark card '
              'whose Button toggles a habit they retired.');
      expect(body, contains('eligible'),
          reason: '$rule …and it still respects the per-widget type filter: '
              'a Target widget must never fall back onto a boolean habit '
              '(`widgets.target#8`).');
    });

    test('#1 looking a habit up by id stays unfiltered', () {
      for (final String query in queries.values) {
        final String body = function(
          declaration(selection, 'struct $query'),
          'func entities(for identifiers:',
        );
        expect(body.contains('isArchived'), isFalse,
            reason: '$rule $query.entities(for:) resolves an id the system '
                'already stored. Archiving does not unbind a widget upstream, '
                'so filtering here would flip a working widget to the "habit '
                'deleted / not found" card (`widgets.error-states#1`) the day '
                'its habit was archived.');
        expect(body.contains('suggestedEntities()'), isFalse,
            reason: '$rule …and it cannot borrow the picker\'s list to do it: '
                'suggestedEntities() is now the filtered one, so delegating '
                'to it would apply the archived clause by the back door.');
        expect(body, contains('allHabits()'),
            reason: '$rule It reads the published catalogue directly, which '
                'is `HabitList.getById` on the Android side of the same '
                'lookup.');
      }

      final String lookup = function(
        declaration(swift('WidgetData.swift'), 'struct WidgetStore'),
        'func habit(id:',
      );
      expect(lookup.contains('isArchived'), isFalse,
          reason: '$rule …and neither does WidgetStore.habit(id:), which is '
              'what `resolve` uses once a habit has actually been picked.');
    });
  });

  // =======================================================================
  // The Dart side of the boundary: what the extension has to filter on
  // =======================================================================

  group('audit10.ios-widget-picker-offers-archived (catalogue)', () {
    late MemoryHabitList habitList;
    late HabitFixtures fixtures;
    late HomeWidgetBridge bridge;

    setUp(() {
      setToday(LocalDate.ymd(2015, 1, 26));
      final MemoryModelFactory modelFactory = MemoryModelFactory();
      habitList = MemoryHabitList();
      fixtures = HabitFixtures(modelFactory, habitList);
      final MemoryStorage storage = MemoryStorage();
      bridge = HomeWidgetBridge(
        habitList: habitList,
        registry: WidgetRegistry(storage),
        platform: _NullPlatform(),
        preferences: Preferences(storage),
      );
    });

    test('#1 every published habit carries the flag the picker filters on',
        () {
      final Habit active = fixtures.createEmptyHabit(name: 'Meditate');
      final Habit retired = fixtures.createEmptyHabit(name: 'Quit smoking')
        ..isArchived = true;
      habitList
        ..add(active)
        ..add(retired);

      final List<Object?> catalogue =
          bridge.buildIndexDocument()['habits']! as List<Object?>;
      final Map<int, bool> archived = <int, bool>{
        for (final Object? habit in catalogue)
          (habit! as Map<String, Object?>)['id']! as int:
              (habit as Map<String, Object?>)['isArchived']! as bool,
      };

      expect(archived[active.id], isFalse, reason: rule);
      expect(archived[retired.id], isTrue,
          reason: '$rule The catalogue is the only thing an extension can '
              'read, so `isArchived` has to cross for the three queries to '
              'have anything to filter on.');
    });

    test('#1 an archived habit is still published, so a bound widget finds it',
        () {
      final Habit retired = fixtures.createEmptyHabit(name: 'Quit smoking')
        ..isArchived = true;
      habitList.add(retired);

      final List<Object?> catalogue =
          bridge.buildIndexDocument()['habits']! as List<Object?>;

      expect(
          catalogue.map(
              (Object? h) => (h! as Map<String, Object?>)['id']),
          contains(retired.id),
          reason: '$rule Dropping it from the catalogue instead of filtering '
              'the pickers would be the other bug: a widget an install bound '
              'before the habit was archived would lose the only copy of the '
              "habit it draws, and show the deleted card upstream never "
              'shows.');
    });

    test('#1 the Android picker still applies the same clause', () {
      final Habit active = fixtures.createEmptyHabit(name: 'Meditate');
      final Habit retired = fixtures.createEmptyHabit(name: 'Quit smoking')
        ..isArchived = true;
      habitList
        ..add(active)
        ..add(retired);

      expect(
          widgetPickerCandidates(habitList, WidgetPickerFilter.all)
              .map((Habit h) => h.name),
          <String>['Meditate'],
          reason: '$rule Both platforms answer the same question and have to '
              'answer it the same way; this is the half that already did.');
    });
  });
}

/// The bridge's platform seam, reduced to nothing: these tests read the
/// documents it would publish, never the publishing.
class _NullPlatform implements HomeWidgetPlatform {
  @override
  Future<void> saveWidgetData(String id, String? value) async {}

  @override
  Future<void> setAppGroupId(String groupId) async {}

  @override
  Future<void> updateWidget({
    required String name,
    required String qualifiedAndroidName,
    required String iOSName,
  }) async {}
}
