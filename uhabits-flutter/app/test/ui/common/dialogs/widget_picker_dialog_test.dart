/// `widgets.config-picker` — the Flutter half of the widget configuration flow.
///
/// The Android half (`HabitPickerDialog`, its two subclasses and the manifest
/// declarations) is asserted in test/platform/android_widgets_test.dart; rules
/// #1, #4, #5, #6, #10 and #11 live there because they are facts about the
/// activity the launcher starts. Everything the activity *cannot* do here — it
/// has no habit catalogue, only the app does — moved to the dialog this file
/// exercises, which the activity reaches through the
/// `uhabits://widget/configure` deep link.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits/state/widget_link.dart';
import 'package:uhabits/ui/common/dialogs/widget_picker_dialog.dart';
import 'package:uhabits/ui/theme/app_theme.dart';
// The core's preferences and fixtures are only reachable by their `src` path.
// ignore_for_file: implementation_imports
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  late core.MemoryHabitList habitList;
  late HabitFixtures fixtures;

  /// Five habits: two boolean, one numerical, and two archived ones (one of
  /// each kind) wedged in the middle so that "natural order minus the archived"
  /// is distinguishable from "the first three".
  ///
  /// The positions are explicit because `MemoryHabitList` sorts by position and
  /// then by name, so leaving them all at 0 would put the list in alphabetical
  /// order and the test could not tell the two apart.
  void seed() {
    final core.MemoryModelFactory factory = core.MemoryModelFactory();
    habitList = core.MemoryHabitList();
    fixtures = HabitFixtures(factory, habitList);

    habitList.add(
      fixtures.createEmptyHabit(name: 'Wake up early', position: 0),
    );
    final core.Habit archivedBoolean =
        fixtures.createEmptyHabit(name: 'Old habit', position: 1)
          ..isArchived = true;
    habitList.add(archivedBoolean);
    final core.Habit run =
        fixtures.createEmptyNumericalHabit(core.NumericalHabitType.atLeast)
          ..name = 'Run'
          ..position = 2;
    habitList.add(run);
    final core.Habit archivedNumerical =
        fixtures.createEmptyNumericalHabit(core.NumericalHabitType.atLeast)
          ..name = 'Swim'
          ..position = 3
          ..isArchived = true;
    habitList.add(archivedNumerical);
    habitList.add(fixtures.createEmptyHabit(name: 'Meditate', position: 4));
  }

  setUp(seed);

  List<String> namesOf(WidgetPickerFilter filter) =>
      widgetPickerCandidates(habitList, filter)
          .map((core.Habit h) => h.name)
          .toList();

  // =======================================================================
  // widgets.config-picker — which habits the picker may offer (rule 3)
  // =======================================================================

  group('widgets.config-picker candidates', () {
    test('the base picker takes habitList in order, minus the archived', () {
      expect(
        namesOf(WidgetPickerFilter.all),
        <String>['Wake up early', 'Run', 'Meditate'],
        reason: 'widgets.config-picker#3 — The candidate habit list is built '
            'by iterating habitList in its natural order and skipping (a) '
            'every archived habit, (b) numerical habits when '
            'shouldHideNumerical() is true, (c) boolean habits when '
            'shouldHideBoolean() is true.',
      );
    });

    test('the boolean picker also drops the numerical habits', () {
      expect(
        namesOf(WidgetPickerFilter.boolean),
        <String>['Wake up early', 'Meditate'],
        reason: 'widgets.config-picker#3: shouldHideNumerical() is true, so '
            'the numerical habits go as well as the archived ones',
      );
    });

    test('the numerical picker also drops the boolean habits', () {
      expect(
        namesOf(WidgetPickerFilter.numerical),
        <String>['Run'],
        reason: 'widgets.config-picker#3: shouldHideBoolean() is true, so the '
            'boolean habits go as well as the archived ones',
      );
    });

    test('an archived habit is skipped whichever filter is applied', () {
      for (final WidgetPickerFilter filter in WidgetPickerFilter.values) {
        expect(
          namesOf(filter),
          isNot(contains('Old habit')),
          reason: 'widgets.config-picker#3: the archived boolean habit never '
              'appears (${filter.name})',
        );
        expect(
          namesOf(filter),
          isNot(contains('Swim')),
          reason: 'widgets.config-picker#3: nor the archived numerical one '
              '(${filter.name})',
        );
      }
    });

    test('the three filters are the three the deep link can carry', () {
      expect(
        <String, WidgetPickerFilter?>{
          'all': WidgetPickerFilter.fromName('all'),
          'boolean': WidgetPickerFilter.fromName('boolean'),
          'numerical': WidgetPickerFilter.fromName('numerical'),
          'nonsense': WidgetPickerFilter.fromName('nonsense'),
        },
        <String, WidgetPickerFilter?>{
          'all': WidgetPickerFilter.all,
          'boolean': WidgetPickerFilter.boolean,
          'numerical': WidgetPickerFilter.numerical,
          'nonsense': null,
        },
        reason: 'widgets.config-picker#3: the filter that decides which habits '
            'are hidden is the one WidgetIntents.FILTER_* put in the URI',
      );
    });
  });

  // =======================================================================
  // widgets.config-picker — what the picker shows, and what a tap does
  // =======================================================================

  group('widgets.config-picker dialog', () {
    testWidgets('it is a list of habit names and nothing else', (tester) async {
      final _Result result = await _open(tester, habitList: habitList);

      expect(
        _rowLabels(tester),
        <String>['Wake up early', 'Run', 'Meditate'],
        reason: 'widgets.config-picker#8 — Otherwise the activity shows '
            'R.layout.widget_configure_activity: a wrap_content vertical '
            'LinearLayout containing only a ListView id=listView, whose adapter '
            'is an ArrayAdapter over habit names using '
            'android.R.layout.simple_list_item_1.',
      );
      expect(
        find.byType(ListView),
        findsOneWidget,
        reason: 'widgets.config-picker#8: one list, and only a list',
      );
      expect(
        result.completed,
        isFalse,
        reason: 'widgets.config-picker#8: showing the list decides nothing',
      );
    });

    testWidgets('there is no Save button and no multi-select', (tester) async {
      await _open(tester, habitList: habitList);

      Finder inside(Type type) => find.descendant(
        of: find.byType(WidgetPickerDialog),
        matching: find.byType(type),
      );

      expect(
        inside(TextButton),
        findsNothing,
        reason: 'widgets.config-picker#9 — Tapping a list row immediately '
            'confirms with exactly that one habit id — there is no '
            'multi-select and no Save button in the layout (a saveButton '
            'lookup remains in the code but resolves to null and is unused).',
      );
      expect(
        inside(ElevatedButton),
        findsNothing,
        reason: 'widgets.config-picker#9: nor any other kind of button',
      );
      expect(
        inside(Checkbox),
        findsNothing,
        reason: 'widgets.config-picker#9: and nothing to tick, because there '
            'is no multi-select',
      );
    });

    testWidgets('tapping a row confirms with exactly that habit', (
      tester,
    ) async {
      final _Result result = await _open(tester, habitList: habitList);

      await tester.tap(find.text('Run'));
      await tester.pumpAndSettle();

      expect(
        result.completed,
        isTrue,
        reason: 'widgets.config-picker#9: the tap confirms immediately, with '
            'nothing else to press',
      );
      expect(
        result.value?.name,
        'Run',
        reason: 'widgets.config-picker#9 — Tapping a list row immediately '
            'confirms with exactly that one habit id.',
      );
      expect(
        find.byType(WidgetPickerDialog),
        findsNothing,
        reason: 'widgets.config-picker#9: and closes the picker',
      );
    });

    testWidgets('backing out confirms nothing', (tester) async {
      final _Result result = await _open(tester, habitList: habitList);

      Navigator.of(tester.element(find.byType(WidgetPickerDialog))).pop();
      await tester.pumpAndSettle();

      expect(
        result.value,
        isNull,
        reason: 'widgets.config-picker#11 — Backing out of the picker without '
            'choosing leaves the default RESULT_CANCELED, so the widget is '
            'not added.',
      );
    });

    testWidgets('an empty candidate list is a 250x150 centred message', (
      tester,
    ) async {
      habitList = core.MemoryHabitList();
      final _Result result = await _open(tester, habitList: habitList);

      final Finder message = find.byKey(
        const ValueKey<String>('widget_picker_message'),
      );
      expect(
        tester.getSize(message),
        const Size(250, 150),
        reason: 'widgets.config-picker#7 — When no habit survives the filter, '
            'the activity shows R.layout.widget_empty_activity (a 250dp x '
            '150dp centred TextView at R.dimen.regularTextSize = 16sp) with '
            'the type-specific empty message and returns early — no result is '
            'set, so the pending widget placement is cancelled by the '
            'launcher.',
      );
      final Text text = tester.widget<Text>(
        find.descendant(of: message, matching: find.byType(Text)),
      );
      expect(
        <Object?>[text.style?.fontSize, text.textAlign],
        <Object?>[16.0, TextAlign.center],
        reason: 'widgets.config-picker#7: regularTextSize = 16sp, centred',
      );
      expect(
        find.byType(ListView),
        findsNothing,
        reason: 'widgets.config-picker#7: the list is not shown at all',
      );
      expect(
        result.completed,
        isFalse,
        reason: 'widgets.config-picker#7: and nothing is confirmed, so the '
            'launcher cancels the placement',
      );
    });

    testWidgets('the empty message is the one the filter names', (tester) async {
      final Map<WidgetPickerFilter, String> expected =
          <WidgetPickerFilter, String>{
            WidgetPickerFilter.all: 'No habits found',
            WidgetPickerFilter.boolean: 'No yes-or-no habits found',
            WidgetPickerFilter.numerical: 'No measurable habits found',
          };

      for (final MapEntry<WidgetPickerFilter, String> entry
          in expected.entries) {
        await _open(
          tester,
          habitList: core.MemoryHabitList(),
          filter: entry.key,
        );
        expect(
          find.text(entry.value),
          findsOneWidget,
          reason: 'widgets.config-picker#7: the type-specific empty message '
              '(${entry.key.name})',
        );
        // The next iteration re-pumps into the same Navigator, so this route
        // has to go or it stays on the stack behind the new one.
        Navigator.of(tester.element(find.byType(WidgetPickerDialog))).pop();
        await tester.pumpAndSettle();
      }
    });
  });

  // =======================================================================
  // widgets.config-picker — the dialog theme (rule 2)
  // =======================================================================

  group('widgets.config-picker theme', () {
    testWidgets('night mode paints the picker grey_900', (tester) async {
      await _open(
        tester,
        habitList: habitList,
        theme: appThemeData(core.DarkTheme()),
      );

      expect(
        _dialogColor(tester),
        const Color(0xFF212121),
        reason: 'widgets.config-picker#2 — The dialog theme is applied via '
            'AndroidThemeSwitcher.applyDialog(): in night mode it applies '
            'R.style.BaseDialogDark and paints the window decor grey_900, '
            'otherwise it applies R.style.BaseDialog. The Android styles have '
            'no Flutter counterpart, but grey_900 does, and this port paints '
            'the picker with it under either dark variant.',
      );
      expect(
        WidgetPickerMetrics.nightBackgroundColor,
        const Color(0xFF212121),
        reason: 'widgets.config-picker#2: grey_900 is #212121',
      );
    });

    testWidgets('the pure black theme is night mode too', (tester) async {
      await _open(
        tester,
        habitList: habitList,
        theme: appThemeData(core.PureBlackTheme()),
      );

      expect(
        _dialogColor(tester),
        const Color(0xFF212121),
        reason: 'widgets.config-picker#2: applyDialog() branches on '
            'isNightMode, which both dark variants satisfy',
      );
    });

    testWidgets('day mode keeps the ordinary dialog background', (
      tester,
    ) async {
      final ThemeData theme = appThemeData(core.LightTheme());
      await _open(tester, habitList: habitList, theme: theme);

      expect(
        _dialogColor(tester),
        theme.dialogTheme.backgroundColor,
        reason: 'widgets.config-picker#2: outside night mode nothing is '
            'repainted — the picker takes the theme it is shown under',
      );
    });
  });

  // =======================================================================
  // The deep link that reaches the picker
  // =======================================================================

  group('widgets.config-picker deep link', () {
    late MemoryStorage storage;
    late WidgetRegistry registry;
    late _FakeLaunches launches;
    late int publishes;

    setUp(() {
      storage = MemoryStorage();
      registry = WidgetRegistry(storage);
      launches = _FakeLaunches();
      publishes = 0;
    });

    Future<void> pumpRouter(WidgetTester tester) async {
      final GlobalKey<NavigatorState> navigatorKey =
          GlobalKey<NavigatorState>();
      final WidgetLinkRouter router = WidgetLinkRouter(
        habitList: habitList,
        registry: registry,
        publish: () async => publishes++,
        navigator: navigatorKey,
        launches: launches,
      );
      addTearDown(router.stop);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );
      await router.start();
      await tester.pumpAndSettle();
    }

    testWidgets('a configure link opens the picker its filter asked for', (
      tester,
    ) async {
      launches.initial = Uri.parse(
        'uhabits://widget/configure?widgetId=7&filter=boolean',
      );
      await pumpRouter(tester);

      expect(
        _rowLabels(tester),
        <String>['Wake up early', 'Meditate'],
        reason: 'widgets.config-picker#3: the deep link carries the filter, '
            'and the picker hides what it names',
      );
    });

    testWidgets('picking a habit binds it to the widget id and republishes', (
      tester,
    ) async {
      launches.initial = Uri.parse(
        'uhabits://widget/configure?widgetId=7&filter=all',
      );
      await pumpRouter(tester);

      final int runId = habitList.firstWhere((h) => h.name == 'Run').id!;
      await tester.tap(find.text('Run'));
      await tester.pumpAndSettle();

      expect(
        registry.habitIdsOf(7),
        <int>[runId],
        reason: 'widgets.config-picker#10 — confirm(selectedIds) calls '
            'widgetPreferences.addWidget(widgetId, ids), then '
            'widgetUpdater.updateWidgets() (all widgets, all providers), then '
            'setResult(RESULT_OK, Intent with EXTRA_APPWIDGET_ID = widgetId), '
            'then finish().',
      );
      expect(
        registry.widgetIds,
        contains(7),
        reason: 'widgets.config-picker#10: the widget id joins the registry, '
            'which is what makes the bridge publish a document for it',
      );
      expect(
        publishes,
        1,
        reason: 'widgets.config-picker#10: and then every widget is refreshed',
      );
    });

    testWidgets('dismissing the picker binds nothing', (tester) async {
      launches.initial = Uri.parse(
        'uhabits://widget/configure?widgetId=7&filter=all',
      );
      await pumpRouter(tester);

      Navigator.of(tester.element(find.byType(WidgetPickerDialog))).pop();
      await tester.pumpAndSettle();

      expect(
        registry.widgetIds,
        isEmpty,
        reason: 'widgets.config-picker#11 — Backing out of the picker without '
            'choosing leaves the default RESULT_CANCELED, so the widget is '
            'not added. The activity decides that by looking for a published '
            'document, so nothing may be written here.',
      );
      expect(
        publishes,
        0,
        reason: 'widgets.config-picker#11: and nothing is refreshed either',
      );
    });

    testWidgets('a link that arrives while the app is running is honoured too', (
      tester,
    ) async {
      await pumpRouter(tester);
      expect(
        find.byType(WidgetPickerDialog),
        findsNothing,
        reason: 'widgets.config-picker#1: with no configure intent there is '
            'nothing to configure',
      );

      launches.emit(
        Uri.parse('uhabits://widget/configure?widgetId=3&filter=numerical'),
      );
      await tester.pumpAndSettle();

      expect(
        _rowLabels(tester),
        <String>['Run'],
        reason: 'widgets.config-picker#1 — HabitPickerDialog is launched by '
            'the launcher as the widget\'s APPWIDGET_CONFIGURE activity and '
            'reads the widget id from '
            'intent.extras.getInt(EXTRA_APPWIDGET_ID, INVALID_APPWIDGET_ID); '
            'if the intent has no extras at all, widgetId falls back to 0. '
            'Here the id and the filter travel in the deep link, and it '
            'reaches the app whether it was already running or not.',
      );
    });

    testWidgets('the same launch link is never handled twice', (tester) async {
      launches.initial = Uri.parse(
        'uhabits://widget/configure?widgetId=7&filter=all',
      );
      await pumpRouter(tester);

      // The plugin reports the launch URI both from
      // `initiallyLaunchedFromHomeWidget()` and on the click stream.
      launches.emit(launches.initial);
      await tester.pumpAndSettle();

      expect(
        find.byType(WidgetPickerDialog),
        findsOneWidget,
        reason: 'widgets.config-picker#1: one placement, one picker — the '
            'intent is consumed once, as ListHabitsActivity clears its own',
      );
    });

    testWidgets('a link for another action never opens the picker', (
      tester,
    ) async {
      launches.initial = Uri.parse('uhabits://widget/show?widgetId=7&habit=1');
      await pumpRouter(tester);

      expect(
        find.byType(WidgetPickerDialog),
        findsNothing,
        reason: 'widgets.config-picker#1: only APPWIDGET_CONFIGURE starts the '
            'picker',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _Result {
  core.Habit? value;

  bool completed = false;
}

/// Pumps a one-button app, taps the button and lets it open the picker.
Future<_Result> _open(
  WidgetTester tester, {
  required core.HabitList habitList,
  WidgetPickerFilter filter = WidgetPickerFilter.all,
  ThemeData? theme,
}) async {
  final _Result result = _Result();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: theme,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result.value = await showWidgetPickerDialog(
                  context,
                  habits: habitList,
                  filter: filter,
                );
                result.completed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

List<String> _rowLabels(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(WidgetPickerDialog),
        matching: find.byType(Text),
      ),
    )
    .map((Text text) => text.data ?? '')
    .toList();

Color? _dialogColor(WidgetTester tester) => tester
    .widget<Material>(
      find
          .descendant(
            of: find.byType(WidgetPickerDialog),
            matching: find.byType(Material),
          )
          .first,
    )
    .color;

/// [WidgetLaunchSource] with no plugin behind it.
class _FakeLaunches implements WidgetLaunchSource {
  Uri? initial;

  final StreamController<Uri?> _controller = StreamController<Uri?>.broadcast();

  void emit(Uri? uri) => _controller.add(uri);

  @override
  Future<Uri?> initialLaunchUri() async => initial;

  @override
  Stream<Uri?> get launchUris => _controller.stream;
}
