/// Journey: the user places a home-screen widget, and it is handed everything
/// it has to draw.
///
/// `audit4.harness-blind-spots#2` — "The widget bridge is Dart and still
/// escaped every test, because no journey places a widget and inspects what it
/// was given. The port needs a test that asserts the published document against
/// what each widget kind needs to draw: the score for the checkmark ring, the
/// score series for the score widget, enough history for the streak and
/// frequency widgets, and the first-weekday preference."
///
/// ## Why this is a journey and not a bridge unit test
///
/// app/test/platform/home_widget_bridge_test.dart builds a [HomeWidgetBridge]
/// and hands it a habit list, a registry and a fake platform. That shape can
/// prove the bridge encodes what it is asked to encode; it cannot notice that
/// nothing in the shipped app ever asks for a score, that the preference the
/// document should carry never reaches the bridge, or that a window sized for
/// one widget starves two others. Four audit passes found exactly that class of
/// defect, so this file starts where the app starts — `AppScope.boot()`,
/// `runApp` — places a widget the way a launcher does (the
/// `uhabits://widget/configure` deep link that is the port of
/// `HabitPickerDialog`), and then reads the JSON that crossed the `home_widget`
/// method channel.
///
/// Nothing below constructs a bridge, a registry or a document. Every byte
/// asserted here was produced by the running app and handed to the platform.
///
/// ## What each widget needs, and which test covers it
///
///  * Checkmark — `habit.scores[today].value` for the ring around the glyph.
///  * Score — the bucketed score series and the bucket size the user picked.
///  * Streaks — streaks computed over the habit's whole history.
///  * Frequency — the weekday buckets of the user's own marks, every month the
///    habit has existed, laid out from the chosen first weekday.
///  * History — the same first weekday for its grid.
///  * Target — one row per window the habit's frequency admits, with the
///    calendar-truncated sums and the scaled targets.
library;

// The core's models and time helpers are reached by their `src` path, exactly
// as lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits/ui/common/dialogs/widget_picker_dialog.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits/ui/habits/show/cards/score_card_view.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import 'journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  setUp(() {
    device = TestDevice.create('uhabits_journey_widget_data');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

  // -----------------------------------------------------------------------
  // Reading what crossed the platform boundary
  // -----------------------------------------------------------------------

  /// The most recent `HomeWidget.saveWidgetData(key, …)` payload, decoded.
  ///
  /// Newest first, because every publish rewrites every key and only the last
  /// one is what the launcher would read.
  Map<String, Object?>? published(String key) {
    for (final MethodCall call in device.homeWidgetCalls.reversed) {
      if (call.method != 'saveWidgetData') continue;
      final Map<Object?, Object?> arguments =
          call.arguments as Map<Object?, Object?>;
      if (arguments['id'] != key) continue;
      final Object? data = arguments['data'];
      if (data == null) return null;
      return jsonDecode(data as String) as Map<String, Object?>;
    }
    return null;
  }

  /// The document a placed widget reads.
  Map<String, Object?> widgetDocument(int widgetId) {
    final Map<String, Object?>? document =
        published(HomeWidgetBridge.documentKey(widgetId));
    expect(document, isNotNull,
        reason: 'the app has to have published a document for widget '
            '$widgetId; without one the launcher draws the "open Loop Habit '
            'Tracker to set up this widget" card');
    return document!;
  }

  /// The one habit a single-habit widget is bound to.
  Map<String, Object?> boundHabit(int widgetId) {
    final List<Object?> habits =
        widgetDocument(widgetId)['habits']! as List<Object?>;
    expect(habits, hasLength(1),
        reason: 'the picker binds exactly one habit to a widget');
    return habits.single! as Map<String, Object?>;
  }

  /// The habit named [name], as the app holds it. Read only to compare the
  /// published numbers against the model they claim to describe.
  Habit modelHabit(String name) => app.scope.habitList
      .toList()
      .firstWhere((Habit habit) => habit.name == name);

  // -----------------------------------------------------------------------
  // Steps
  // -----------------------------------------------------------------------

  /// A `uhabits://widget/...` deep link, delivered the way the launcher
  /// delivers it: an event on the `home_widget/updates` channel, which is what
  /// `HomeWidget.widgetClicked` listens to.
  Future<void> deliverWidgetLink(WidgetTester tester, String uri) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      homeWidgetUpdatesChannelName,
      const StandardMethodCodec().encodeSuccessEnvelope(uri),
      (ByteData? _) {},
    );
    await settleIo(tester);
  }

  /// The user drops a widget on the home screen and picks a habit for it.
  ///
  /// `widgets.config-picker#1`, `#9`, `#10`: the launcher starts the configure
  /// activity with the new widget id, the picker lists the habits the widget
  /// type accepts, and tapping one confirms immediately.
  Future<void> placeWidget(
    WidgetTester tester, {
    required int widgetId,
    required String habit,
    String filter = 'all',
  }) async {
    await deliverWidgetLink(
      tester,
      'uhabits://widget/configure?widgetId=$widgetId&filter=$filter',
    );
    expect(find.byType(WidgetPickerDialog), findsOneWidget,
        reason: 'the configure link has to open the habit picker — a widget '
            'the user has just placed has nothing bound to it yet');
    // Inside the dialog: the list behind it shows the same names.
    await tester.tap(find.descendant(
      of: find.byType(WidgetPickerDialog),
      matching: find.text(habit),
    ));
    await settleIo(tester);
  }

  /// The number editor a numerical cell opens: tap, type, save.
  Future<void> enterNumericalValue(
    WidgetTester tester, {
    required String habit,
    required LocalDate date,
    required String value,
  }) async {
    await tester.tap(find.descendant(
      of: habitRow(habit),
      matching: find.byKey(entryButtonKey(date)),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey<String>('number_value')), value);
    await tester.tap(
        find.byKey(const ValueKey<String>('number_save_button')));
    await settleIo(tester);
  }

  // =======================================================================
  // The Checkmark ring and the Score chart
  // =======================================================================

  testWidgets('a placed widget is handed the score its ring and its chart '
      'are drawn from', (WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(tester, name: 'Meditate');
    final LocalDate today = getToday();
    await toggleCheckmark(tester, 'Meditate', today);
    await toggleCheckmark(tester, 'Meditate', today.minus(1));

    await placeWidget(tester, widgetId: 1, habit: 'Meditate');

    final Map<String, Object?> habit = boundHabit(1);
    final double score = modelHabit('Meditate').scores[today].value;

    expect(score, greaterThan(0.0),
        reason: 'the precondition: two ticked days give the habit a non-zero '
            'score, so an empty ring below can only be the bridge');
    expect(habit['score'], closeTo(score, 1e-9),
        reason: 'audit4.checkmark-widget-s-score-ring-is#1 — The ring around '
            'the glyph fills proportionally to the habit\'s score for today — '
            'that partial arc is the Checkmark widget\'s main piece of '
            'information beyond the tick mark. `CheckmarkWidget.refreshData` '
            'sets percentage = habit.scores[today].value, and the only place '
            'that number can come from here is the published document.');

    expect(habit['bucketSize'], 7,
        reason: 'audit4.score-widget-draws-an-empty-chart#1 — the Score widget '
            'plots the habit\'s BUCKETED score history; the bucket comes from '
            'Preferences.scoreCardSpinnerPosition, whose default is 1 = weekly '
            '(widgets.score#3, #4)');

    final List<Object?> scores = habit['scores']! as List<Object?>;
    expect(scores, isNotEmpty,
        reason: 'audit4.score-widget-draws-an-empty-chart#1 — The Score widget '
            'plots the habit\'s bucketed score history; that curve is the '
            'entire content of the widget. An unpublished series draws an '
            'empty chart.');
    expect(scores.first, greaterThan(0.0),
        reason: 'newest bucket first, and this week holds the two ticks');
    for (final Object? value in scores) {
      expect(value, isA<double>());
      expect(value! as double, inInclusiveRange(0.0, 1.0),
          reason: 'a score is a fraction, exactly as ScoreCardState carries '
              'it');
    }

    // The iOS half of the same contract. A WidgetKit widget has no widget id
    // and no configure activity: it is bound by an App Intent whose habit comes
    // out of the published catalogue, so a habit there has to carry everything
    // a bound habit carries or the same six widgets are blank on iOS only.
    final List<Object?> catalogue =
        published(HomeWidgetBridge.indexKey)!['habits']! as List<Object?>;
    final Map<String, Object?> listed =
        catalogue.single! as Map<String, Object?>;
    for (final String field in <String>[
      'score',
      'scores',
      'bucketSize',
      'streaks',
      'weekdayFrequency',
      'targetRows',
    ]) {
      expect(listed[field], isNotNull,
          reason: 'audit4.harness-blind-spots#2 — the catalogue entry and the '
              'bound habit are the same shape, so a widget resolved out of the '
              'index draws exactly what a widget resolved out of a document '
              'draws. "$field" is missing from the catalogue.');
    }
  });

  testWidgets('the bucket the user picked on the detail screen is the bucket '
      'the widget plots', (WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(tester, name: 'Meditate');
    await toggleCheckmark(tester, 'Meditate', getToday());
    await placeWidget(tester, widgetId: 1, habit: 'Meditate');

    expect(boundHabit(1)['bucketSize'], 7, reason: 'the default, weekly');

    // The Score card's spinner, on the habit detail screen: Day, Week, Month,
    // Quarter, Year.
    await tapHabit(tester, 'Meditate');
    await tester.tap(find.byKey(ScoreCardView.spinnerKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(stringsOf(tester).month).last);
    await settleIo(tester);
    await pressBack(tester);
    // Any command republishes; the preference is read at publish time.
    await toggleCheckmark(tester, 'Meditate', getToday().minus(1));

    expect(boundHabit(1)['bucketSize'], 31,
        reason: 'audit4.score-widget-draws-an-empty-chart#1 — ScoreWidget '
            'builds its state with spinnerPosition = '
            'prefs.scoreCardSpinnerPosition and publishes bucketSize with the '
            'series (widgets.score#3): the interval the user last chose on the '
            'detail screen is the one the widget draws.');
  });

  // =======================================================================
  // The Streak and Frequency windows
  // =======================================================================

  testWidgets('streaks and weekday buckets survive past the published entry '
      'window', (WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(tester, name: 'Meditate');
    final LocalDate firstDay = getToday();
    for (int back = 0; back < 3; back++) {
      await toggleCheckmark(tester, 'Meditate', firstDay.minus(back));
    }
    await placeWidget(tester, widgetId: 1, habit: 'Meditate');

    // The user comes back three months later. Nothing about the app changes;
    // the ticks are simply older than the sixty days the document carries.
    travelTo(DateTime.now().millisecondsSinceEpoch +
        const Duration(days: 100).inMilliseconds);
    await app.restart();

    final Map<String, Object?> habit = boundHabit(1);
    final List<Object?> entries = habit['entries']! as List<Object?>;
    expect(entries.every((Object? value) => value == Entry.unknown), isTrue,
        reason: 'the precondition: the published entry window ends 60 days '
            'ago, so nothing derived from it alone could still see the run');

    expect(habit['streaks'], isA<List<Object?>>(),
        reason: 'audit4.streak-and-frequency-widgets-only-see#1 — Streaks come '
            'from habit.streaks, computed over the habit\'s whole history, so '
            'the widget shows the genuinely longest runs. StreakWidget cannot '
            'recompute them: the document would have to carry the history, and '
            'it carries sixty days.');
    final List<Object?> streaks = habit['streaks']! as List<Object?>;
    expect(streaks, isNotEmpty,
        reason: 'audit4.streak-and-frequency-widgets-only-see#1: three ticked '
            'days are a run, and a run is a streak');
    final Map<String, Object?> best = streaks.first! as Map<String, Object?>;
    expect(best['length'], 3,
        reason: 'audit4.streak-and-frequency-widgets-only-see#1: the three '
            'ticked days are one run, and it is still the best one — a streak '
            'rebuilt from the 60 published days would have vanished with them');
    expect(best['end'], HomeWidgetBridge.formatDate(firstDay),
        reason: 'and it ends on the day the user ticked, not at the edge of '
            'the window');

    expect(habit['weekdayFrequency'], isA<Map<String, Object?>>(),
        reason: 'audit4.streak-and-frequency-widgets-only-see#1 — The '
            'Frequency chart buckets originalEntries — the user\'s manual '
            'marks — across every month the habit has existed, which is a '
            'window the sixty published days cannot supply.');
    final Map<String, Object?> frequency =
        habit['weekdayFrequency']! as Map<String, Object?>;
    final int marks = frequency.values.fold<int>(
      0,
      (int sum, Object? bucket) => sum +
          (bucket! as List<Object?>)
              .cast<int>()
              .fold<int>(0, (int a, int b) => a + b),
    );
    expect(marks, 3,
        reason: 'audit4.streak-and-frequency-widgets-only-see#1 — The '
            'Frequency chart buckets originalEntries — the user\'s manual '
            'marks — across every month the habit has existed. Three marks '
            'went in, all of them older than the published entry window, and '
            'all three have to be in the buckets.');
    expect(frequency.keys, contains(HomeWidgetBridge.formatDate(
        LocalDate.ymd(firstDay.year, firstDay.month, 1))),
        reason: 'keyed by the first day of the month the marks fall in, which '
            'is the column the chart draws');
  });

  // =======================================================================
  // The Target rows
  // =======================================================================

  testWidgets('the target rows are the windows the habit\'s frequency admits',
      (WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    // A measurable habit of 10 miles *every week*: the frequency control of
    // the editor is what makes the Target card drop its "Today" row.
    await tapListMenuItem(tester, ListHabitsMenuItems.createHabit);
    await tester.tap(find.byKey(EditHabitScreen.measurableTypeCardKey));
    await tester.pumpAndSettle();
    await fillHabitForm(tester, name: 'Run', target: '10', unit: 'miles');
    await tester.tap(find.byKey(EditHabitScreen.numericalFrequencyPickerKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(stringsOf(tester).everyWeek).last);
    await tester.pumpAndSettle();
    await saveHabit(tester);

    await placeWidget(tester, widgetId: 1, habit: 'Run', filter: 'numerical');
    await enterNumericalValue(
        tester, habit: 'Run', date: getToday(), value: '4');

    final Map<String, Object?> habit = boundHabit(1);
    expect(habit['targetRows'], isA<List<Object?>>(),
        reason: 'audit4.target-widget-shows-the-wrong-rows#1 — The row list is '
            'dynamic and its values are calendar-truncated grouped sums over '
            'the habit\'s whole history; neither the frequency nor that '
            'history is in the document, so the rows have to be published '
            'ready to draw.');
    final List<Object?> rows = habit['targetRows']! as List<Object?>;
    expect(
      rows
          .map((Object? row) => (row! as Map<String, Object?>)['interval'])
          .toList(),
      <int>[7, 30, 91, 365],
      reason: 'audit4.target-widget-shows-the-wrong-rows#1 — The row list is '
          'dynamic: "Today" only when frequency.denominator <= 1, "Week" only '
          'when <= 7, so a weekly habit shows 4 bars and a monthly one 3.',
    );
    expect(
      rows
          .map((Object? row) => (row! as Map<String, Object?>)['target'])
          .toList(),
      <double>[10.0, 40.0, 130.0, 520.0],
      reason: 'audit4.target-widget-shows-the-wrong-rows#1 — Targets are '
          'targetValue / frequency.denominator scaled per window: a habit of '
          '10 miles every 7 days is 10 this week, 10 * (daysInMonth ~/ 7) = 40 '
          'this month, 10 * 13 this quarter and 10 * 52 this year — not '
          'target * interval.',
    );
    expect((rows.first! as Map<String, Object?>)['value'], closeTo(4.0, 1e-9),
        reason: 'audit4.target-widget-shows-the-wrong-rows#1 — Values are '
            'calendar-truncated grouped sums computed over the habit\'s whole '
            'history, in units rather than thousandths.');
  });

  // =======================================================================
  // The first weekday
  // =======================================================================

  testWidgets('the first weekday the user chose in Settings reaches the '
      'widget', (WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(tester, name: 'Meditate');
    await placeWidget(tester, widgetId: 1, habit: 'Meditate');

    expect(widgetDocument(1)['firstWeekday'], isNotNull,
        reason: 'audit4.history-and-frequency-home-screen-widgets#1 — Both '
            'widgets lay their grids out starting on the weekday the user '
            'chose in Settings, matching the habit list header and the detail '
            'screen. The preference has to be in the document: a widget runs '
            'in another process and can only read what was published.');

    await openSettings(tester);
    // `pref_first_weekday`, whose options are keyed by the Calendar constant:
    // 2 is Monday.
    await tapSettingsRow(tester, 'pref_first_weekday');
    await tester.tap(find.byKey(const ValueKey<Object?>('option-2')));
    await settleIo(tester);
    await pressBack(tester);
    await toggleCheckmark(tester, 'Meditate', getToday());

    expect(widgetDocument(1)['firstWeekday'], 1,
        reason: 'audit4.history-and-frequency-home-screen-widgets#1: Monday, '
            'as daysSinceSunday — the convention HistoryChartView.firstWeekday '
            'and FrequencyChartView.firstWeekday are documented in, and the '
            'one DateNames.firstWeekdayDaysSinceSunday uses on iOS.');
    expect(published(HomeWidgetBridge.indexKey)!['firstWeekday'], 1,
        reason: 'and in the index too, which is the only document an iOS '
            'widget configured from the habit catalogue ever reads');
  });
}
