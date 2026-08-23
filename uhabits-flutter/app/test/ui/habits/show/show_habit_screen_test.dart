/// Widget tests for the habit detail screen: the scaffold, the navigation into
/// it, and the three cards that are pure text.
///
/// Every expectation cites the ledger rule it pins, from
/// docs/parity/FEATURES.md, and the two Android baselines under
/// uhabits-android/src/androidTest/assets/views/habits/show/{SubtitleCard,
/// OverviewCard,NotesCard} supply the concrete strings.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/show_habit_model.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/show/cards/notes_card_view.dart';
import 'package:uhabits/ui/habits/show/cards/overview_card_view.dart';
import 'package:uhabits/ui/habits/show/cards/subtitle_card_view.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
// `Color` and `Theme` collide with the Material ones, so they come in under a
// prefix and everything else stays bare.
import 'package:uhabits_core/uhabits_core.dart' hide Color, Theme;
import 'package:uhabits_core/uhabits_core.dart' as core show Color, Theme;

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_show_habit_screen');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope({String name = 'habits.db'}) {
    final database = AppDatabase.openAndMigrate('${tempDir.path}/$name');
    final scope = AppScope.open(database);
    scopes.add(scope);
    return scope;
  }

  Habit addHabit(
    AppScope scope,
    String name, {
    PaletteColor color = const PaletteColor(7),
    HabitType type = HabitType.yesNo,
    String question = '',
    String description = '',
    Frequency? frequency,
    Reminder? reminder,
    double targetValue = 0.0,
    NumericalHabitType targetType = NumericalHabitType.atLeast,
    String unit = '',
  }) {
    final habit = scope.modelFactory.buildHabit()
      ..name = name
      ..color = color
      ..type = type
      ..question = question
      ..description = description
      ..reminder = reminder
      ..targetValue = targetValue
      ..targetType = targetType
      ..unit = unit;
    if (frequency != null) habit.frequency = frequency;
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  Widget wrap(AppScope scope, Habit habit) {
    return MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Provider<AppScope>.value(
        value: scope,
        // A fresh key per habit: without it a second pumpWidget would reuse
        // the element, and with it the ShowHabitModel built for the first one.
        child: ShowHabitScreen(key: ValueKey<String?>(habit.uuid), habit: habit),
      ),
    );
  }

  Widget wrapCard(Widget card) {
    return MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Scaffold(body: card),
    );
  }

  ShowHabitState stateOf(AppScope scope, Habit habit, {core.Theme? theme}) {
    return ShowHabitPresenter.buildState(
      habit: habit,
      preferences: scope.preferences,
      theme: theme ?? LightTheme(),
    );
  }

  ShowHabitModel modelOf(WidgetTester tester) => Provider.of<ShowHabitModel>(
        tester.element(find.byType(Scaffold)),
        listen: false,
      );

  Text textOf(WidgetTester tester, Key key) => tester.widget<Text>(
        find.byKey(key),
      );

  Color colorOf(WidgetTester tester, Key key) => textOf(tester, key).style!.color!;

  double topOf(WidgetTester tester, ShowHabitCard card) =>
      tester.getTopLeft(find.byKey(ShowHabitScreen.cardKey(card))).dy;

  // -----------------------------------------------------------------------
  // The scaffold
  // -----------------------------------------------------------------------

  group('screen scaffold', () {
    testWidgets('show-habit.screen-scaffold#8: the toolbar title is the name',
        (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(wrap(scope, habit));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Meditate')),
        findsOneWidget,
      );
    });

    testWidgets(
        'show-habit.screen-scaffold#9: the toolbar takes the habit colour',
        (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate', color: const PaletteColor(11));

      await tester.pumpWidget(wrap(scope, habit));
      await tester.pumpAndSettle();

      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        _toFlutterColor(LightTheme().colorOf(const PaletteColor(11))),
      );
    });

    testWidgets('show-habit.screen-scaffold#12: the cards scroll under a fixed '
        'toolbar', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(wrap(scope, habit));
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets(
        'show-habit.screen-scaffold#3, #4: every finished command rebuilds the '
        'whole state', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(wrap(scope, habit));
      await tester.pumpAndSettle();

      // Nothing checked yet, so the overview reports a zero total.
      expect(textOf(tester, OverviewCardView.totalCountLabelKey).data, '0');

      scope.commandRunner.run(
        CreateRepetitionCommand(
          scope.habitList,
          habit,
          getToday(),
          Entry.yesManual,
          '',
        ),
      );
      await tester.pumpAndSettle();

      expect(textOf(tester, OverviewCardView.totalCountLabelKey).data, '1');
    });

    test(
        'show-habit.screen-scaffold#4, #6: the model listens to the command '
        'runner only while attached', () {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final model = ShowHabitModel(
        scope: scope,
        habit: habit,
        theme: LightTheme(),
      );
      var notifications = 0;
      model.addListener(() => notifications++);

      final command = CreateRepetitionCommand(
        scope.habitList,
        habit,
        getToday(),
        Entry.yesManual,
        '',
      );

      // Before onResume: the activity is not a listener yet.
      scope.commandRunner.notifyListeners(command);
      expect(notifications, 0);

      // onResume registers and refreshes once.
      model.attach();
      expect(notifications, 1);
      scope.commandRunner.notifyListeners(command);
      expect(notifications, 2);

      // onPause unregisters.
      model.detach();
      scope.commandRunner.notifyListeners(command);
      expect(notifications, 2);

      model.dispose();
    });

    test(
        'show-habit.screen-scaffold#3: the state is rebuilt, never patched',
        () {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final model = ShowHabitModel(
        scope: scope,
        habit: habit,
        theme: LightTheme(),
      );

      final first = model.state;
      habit.name = 'Meditate twice';
      model.refresh();

      expect(identical(model.state, first), isFalse);
      expect(model.state.title, 'Meditate twice');
      model.dispose();
    });
  });

  // -----------------------------------------------------------------------
  // Card order and visibility
  // -----------------------------------------------------------------------

  group('card order and visibility', () {
    testWidgets(
        'show-habit.card-order-and-visibility#1: subtitle, notes, then overview',
        (tester) async {
      final scope = openScope();
      final habit = addHabit(
        scope,
        'Meditate',
        question: 'Did you meditate this morning?',
        description: 'This is a test description',
      );

      await tester.pumpWidget(wrap(scope, habit));
      await tester.pumpAndSettle();

      expect(
        topOf(tester, ShowHabitCard.subtitle),
        lessThan(topOf(tester, ShowHabitCard.notes)),
      );
      expect(
        topOf(tester, ShowHabitCard.notes),
        lessThan(topOf(tester, ShowHabitCard.overview)),
      );
    });

    testWidgets(
        'show-habit.card-order-and-visibility#2, show-habit.overview-card#12: '
        'the overview card is hidden for numerical habits', (tester) async {
      final scope = openScope();
      final boolean = addHabit(scope, 'Meditate');
      final numerical = addHabit(
        scope,
        'Run',
        type: HabitType.numerical,
        targetValue: 5,
        unit: 'km',
      );

      await tester.pumpWidget(wrap(scope, boolean));
      await tester.pumpAndSettle();
      expect(find.byType(OverviewCardView), findsOneWidget);

      await tester.pumpWidget(wrap(scope, numerical));
      await tester.pumpAndSettle();
      expect(find.byType(OverviewCardView), findsNothing);
    });

    testWidgets(
        'show-habit.card-order-and-visibility#3: a card hidden by the habit '
        'type never comes back', (tester) async {
      final scope = openScope();
      final habit = addHabit(
        scope,
        'Run',
        type: HabitType.numerical,
        targetValue: 5,
        unit: 'km',
      );

      await tester.pumpWidget(wrap(scope, habit));
      await tester.pumpAndSettle();
      final model = modelOf(tester);
      expect(model.isVisible(ShowHabitCard.overview), isFalse);

      // Editing the habit into a boolean one hides the target card too, but
      // setState only ever assigns GONE: the overview stays hidden.
      habit.type = HabitType.yesNo;
      model.refresh();
      await tester.pumpAndSettle();

      expect(model.isVisible(ShowHabitCard.overview), isFalse);
      expect(model.isVisible(ShowHabitCard.target), isFalse);
      expect(find.byType(OverviewCardView), findsNothing);
    });

    testWidgets(
        'show-habit.card-order-and-visibility#4, show-habit.notes-card#2: the '
        'notes card follows the description in both directions', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(wrap(scope, habit));
      await tester.pumpAndSettle();
      expect(find.byType(NotesCardView), findsNothing);

      habit.description = 'This is a test description';
      modelOf(tester).refresh();
      await tester.pumpAndSettle();
      expect(find.byType(NotesCardView), findsOneWidget);

      // Unlike the overview/target pair, this one toggles back.
      habit.description = '';
      modelOf(tester).refresh();
      await tester.pumpAndSettle();
      expect(find.byType(NotesCardView), findsNothing);
    });

    testWidgets(
        'show-habit.notes-card#2: a description of one space still shows the '
        'card', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate', description: ' ');

      await tester.pumpWidget(wrap(scope, habit));
      await tester.pumpAndSettle();

      expect(find.byType(NotesCardView), findsOneWidget);
    });
  });

  // -----------------------------------------------------------------------
  // Subtitle card
  // -----------------------------------------------------------------------

  group('subtitle card', () {
    testWidgets(
        'show-habit.subtitle-card#2: the question is tinted with the habit '
        'colour', (tester) async {
      final scope = openScope();
      final habit = addHabit(
        scope,
        'Meditate',
        color: const PaletteColor(7),
        question: 'Did you meditate this morning?',
      );

      await tester.pumpWidget(
        wrapCard(SubtitleCardView(state: stateOf(scope, habit).subtitle)),
      );
      await tester.pumpAndSettle();

      expect(
        textOf(tester, SubtitleCardView.questionKey).data,
        'Did you meditate this morning?',
      );
      expect(
        colorOf(tester, SubtitleCardView.questionKey),
        _toFlutterColor(LightTheme().colorOf(const PaletteColor(7))),
      );
    });

    testWidgets('show-habit.subtitle-card#2: an empty question is GONE',
        (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(
        wrapCard(SubtitleCardView(state: stateOf(scope, habit).subtitle)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(SubtitleCardView.questionKey), findsNothing);
    });

    testWidgets('show-habit.subtitle-card#3: the frequency sentence',
        (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate', frequency: Frequency(3, 7));

      await tester.pumpWidget(
        wrapCard(SubtitleCardView(state: stateOf(scope, habit).subtitle)),
      );
      await tester.pumpAndSettle();

      expect(
        textOf(tester, SubtitleCardView.frequencyLabelKey).data,
        '3 times per week',
      );
    });

    testWidgets(
        'show-habit.subtitle-card#4: 7/7 normalises to 1/1 and reads '
        '"Every day"', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate', frequency: Frequency(7, 7));

      await tester.pumpWidget(
        wrapCard(SubtitleCardView(state: stateOf(scope, habit).subtitle)),
      );
      await tester.pumpAndSettle();

      expect(
        textOf(tester, SubtitleCardView.frequencyLabelKey).data,
        'Every day',
      );
    });

    testWidgets('show-habit.subtitle-card#5: the reminder time, or "Off"',
        (tester) async {
      final scope = openScope();
      final withReminder = addHabit(
        scope,
        'Meditate',
        reminder: Reminder(8, 30, WeekdayList.everyDay),
      );
      final without = addHabit(scope, 'Run');

      // The test harness reports a 12-hour locale, as the SubtitleCard
      // baseline was rendered with.
      await tester.pumpWidget(
        wrapCard(SubtitleCardView(state: stateOf(scope, withReminder).subtitle)),
      );
      await tester.pumpAndSettle();
      expect(
        textOf(tester, SubtitleCardView.reminderLabelKey).data,
        '8:30 AM',
      );

      await tester.pumpWidget(
        wrapCard(
          SubtitleCardView(
            state: stateOf(scope, withReminder).subtitle,
            use24HourFormat: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        textOf(tester, SubtitleCardView.reminderLabelKey).data,
        '08:30',
      );

      await tester.pumpWidget(
        wrapCard(SubtitleCardView(state: stateOf(scope, without).subtitle)),
      );
      await tester.pumpAndSettle();
      expect(textOf(tester, SubtitleCardView.reminderLabelKey).data, 'Off');
    });

    testWidgets(
        'show-habit.subtitle-card#6: the target pair is GONE for boolean '
        'habits', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(
        wrapCard(SubtitleCardView(state: stateOf(scope, habit).subtitle)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(SubtitleCardView.targetIconKey), findsNothing);
      expect(find.byKey(SubtitleCardView.targetTextKey), findsNothing);
    });

    testWidgets(
        'show-habit.subtitle-card#7, #8: the target text and its arrow',
        (tester) async {
      final scope = openScope();
      final atLeast = addHabit(
        scope,
        'Run',
        type: HabitType.numerical,
        targetValue: 200,
        unit: 'steps',
      );
      final atMost = addHabit(
        scope,
        'Smoke',
        type: HabitType.numerical,
        targetValue: 3,
        targetType: NumericalHabitType.atMost,
        unit: 'cigarettes',
      );

      await tester.pumpWidget(
        wrapCard(SubtitleCardView(state: stateOf(scope, atLeast).subtitle)),
      );
      await tester.pumpAndSettle();
      expect(
        textOf(tester, SubtitleCardView.targetTextKey).data,
        '200 steps',
      );
      expect(
        textOf(tester, SubtitleCardView.targetIconKey).data,
        FontAwesome.arrowCircleUp,
      );

      await tester.pumpWidget(
        wrapCard(SubtitleCardView(state: stateOf(scope, atMost).subtitle)),
      );
      await tester.pumpAndSettle();
      expect(
        textOf(tester, SubtitleCardView.targetIconKey).data,
        FontAwesome.arrowCircleDown,
      );
    });

    testWidgets(
        'show-habit.subtitle-card#9: the calendar and bell glyphs, in the '
        'FontAwesome face', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(
        wrapCard(SubtitleCardView(state: stateOf(scope, habit).subtitle)),
      );
      await tester.pumpAndSettle();

      final frequencyIcon = textOf(tester, SubtitleCardView.frequencyIconKey);
      final reminderIcon = textOf(tester, SubtitleCardView.reminderIconKey);
      expect(frequencyIcon.data, FontAwesome.calendar);
      expect(reminderIcon.data, FontAwesome.bellO);
      expect(frequencyIcon.style!.fontFamily, FontAssets.fontAwesomeFamily);
      expect(reminderIcon.style!.fontFamily, FontAssets.fontAwesomeFamily);
    });

    testWidgets(
        'show-habit.subtitle-card#10: the labels below the question use '
        'contrast60', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(
        wrapCard(SubtitleCardView(state: stateOf(scope, habit).subtitle)),
      );
      await tester.pumpAndSettle();

      final contrast60 = _toFlutterColor(LightTheme().mediumContrastTextColor);
      expect(colorOf(tester, SubtitleCardView.frequencyLabelKey), contrast60);
      expect(colorOf(tester, SubtitleCardView.reminderLabelKey), contrast60);
      expect(colorOf(tester, SubtitleCardView.frequencyIconKey), contrast60);
    });
  });

  // -----------------------------------------------------------------------
  // Overview card
  // -----------------------------------------------------------------------

  group('overview card', () {
    OverviewCardState overview({
      double scoreToday = 0.0,
      double scoreMonthDiff = 0.0,
      double scoreYearDiff = 0.0,
      int totalCount = 0,
      PaletteColor color = const PaletteColor(7),
      core.Theme? theme,
    }) {
      return OverviewCardState(
        color: color,
        scoreMonthDiff: scoreMonthDiff,
        scoreYearDiff: scoreYearDiff,
        scoreToday: scoreToday,
        totalCount: totalCount,
        theme: theme ?? LightTheme(),
      );
    }

    testWidgets(
        'show-habit.overview-card#5, #6, #9: the baseline render, verbatim',
        (tester) async {
      // androidTest/assets/views/habits/show/OverviewCard/render.png.
      await tester.pumpWidget(
        wrapCard(
          OverviewCardView(
            state: overview(
              scoreToday: 0.74,
              scoreMonthDiff: 0.23,
              scoreYearDiff: 0.74,
              totalCount: 44,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(textOf(tester, OverviewCardView.scoreLabelKey).data, '74%');
      expect(textOf(tester, OverviewCardView.monthDiffLabelKey).data, '+23%');
      expect(textOf(tester, OverviewCardView.yearDiffLabelKey).data, '+74%');
      expect(textOf(tester, OverviewCardView.totalCountLabelKey).data, '44');
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('Year'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets(
        'show-habit.overview-card#6, #7: a negative diff uses U+2212 and '
        'contrast60', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          OverviewCardView(
            state: overview(scoreMonthDiff: -0.05, scoreYearDiff: 0.0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        textOf(tester, OverviewCardView.monthDiffLabelKey).data,
        '−5%',
      );
      expect(
        colorOf(tester, OverviewCardView.monthDiffLabelKey),
        _toFlutterColor(LightTheme().mediumContrastTextColor),
      );
      // Exactly zero counts as non-negative.
      expect(textOf(tester, OverviewCardView.yearDiffLabelKey).data, '+0%');
      expect(
        colorOf(tester, OverviewCardView.yearDiffLabelKey),
        _toFlutterColor(LightTheme().colorOf(const PaletteColor(7))),
      );
    });

    testWidgets(
        'show-habit.overview-card#8: title, score and total take the habit '
        'colour; the captions take contrast60', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          OverviewCardView(
            state: overview(
              scoreToday: 0.74,
              totalCount: 44,
              color: const PaletteColor(11),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final habitColor =
          _toFlutterColor(LightTheme().colorOf(const PaletteColor(11)));
      expect(colorOf(tester, OverviewCardView.titleKey), habitColor);
      expect(colorOf(tester, OverviewCardView.scoreLabelKey), habitColor);
      expect(colorOf(tester, OverviewCardView.totalCountLabelKey), habitColor);
      expect(
        tester.widget<Text>(find.text('Score')).style!.color,
        _toFlutterColor(LightTheme().mediumContrastTextColor),
      );
    });

    testWidgets('show-habit.overview-card#5: 0.005 rounds up to "1%"',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(OverviewCardView(state: overview(scoreToday: 0.005))),
      );
      await tester.pumpAndSettle();

      expect(textOf(tester, OverviewCardView.scoreLabelKey).data, '1%');
    });

    test(
        'show-habit.overview-card#10: the ring quantises the sweep to the '
        'precision', () {
      RingPainter ring(double percentage) => RingPainter(
            color: const Color(0xFF388E3C),
            inactiveColor: const Color(0x26202020),
            backgroundColor: const Color(0xFFFAFAFA),
            percentage: percentage,
            thickness: 5,
          );

      expect(ring(0.0).sweepDegrees, 0.0);
      expect(ring(1.0).sweepDegrees, closeTo(360.0, 1e-6));
      expect(ring(0.74).sweepDegrees, closeTo(266.4, 1e-6));
      // Everything between two grid points snaps onto the nearest of them.
      expect(ring(0.7449).sweepDegrees, closeTo(266.4, 1e-6));
      expect(ring(0.746).sweepDegrees, closeTo(270.0, 1e-6));
    });
  });

  // -----------------------------------------------------------------------
  // Notes card
  // -----------------------------------------------------------------------

  group('notes card', () {
    testWidgets(
        'show-habit.notes-card#1, #3: the description, verbatim, in contrast100',
        (tester) async {
      final scope = openScope();
      final habit = addHabit(
        scope,
        'Meditate',
        description: 'This is a test description',
      );

      await tester.pumpWidget(
        wrapCard(
          NotesCardView(
            state: stateOf(scope, habit).notes,
            theme: LightTheme(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, 'This is a test description');
      expect(
        text.style!.color,
        _toFlutterColor(LightTheme().highContrastTextColor),
      );
    });
  });

  // -----------------------------------------------------------------------
  // Navigation
  // -----------------------------------------------------------------------

  group('navigation', () {
    testWidgets('tapping a habit in the list opens its detail screen',
        (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate', question: 'Did you meditate this morning?');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Provider<AppScope>.value(
            value: scope,
            child: const HabitListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Meditate'));
      await tester.pumpAndSettle();

      expect(find.byType(ShowHabitScreen), findsOneWidget);
      expect(find.text('Did you meditate this morning?'), findsOneWidget);

      // The Up button goes back to the list.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(ShowHabitScreen), findsNothing);
      expect(find.byType(HabitListScreen), findsOneWidget);
    });
  });
}

/// Same rounding as `FlutterCanvas.setColor` and `core.Color.toInt`.
Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
