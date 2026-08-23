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
import 'package:uhabits/l10n/app_localizations_en.dart';
import 'package:uhabits/l10n/app_localizations_es.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/show_habit_model.dart';
import 'package:uhabits/state/widget_sync.dart';
import 'package:uhabits/ui/common/dialogs/checkmark_dialog.dart';
import 'package:uhabits/ui/common/dialogs/confirm_delete_dialog.dart';
import 'package:uhabits/ui/common/dialogs/history_editor_dialog.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/show/cards/history_card_view.dart';
import 'package:uhabits/ui/habits/show/cards/notes_card_view.dart';
import 'package:uhabits/ui/habits/show/cards/overview_card_view.dart';
import 'package:uhabits/ui/habits/show/cards/subtitle_card_view.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits/ui/theme/app_theme.dart' show appThemeData;
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/io/files.dart' show LocalUserFile, UserFile;
import 'package:uhabits_core/src/preferences/preferences.dart' show Preferences;
import 'package:uhabits_core/src/ui/intent_parser.dart' show parseContentUriId;
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

    testWidgets('show-habit.edit-action#4: Back from the refreshed detail '
        'screen lands on a list that shows the new name', (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');

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
      await tester.tap(find.byKey(ShowHabitScreen.editActionKey));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(EditHabitScreen.nameFieldKey),
        'Meditate longer',
      );
      await tester.tap(find.byKey(EditHabitScreen.saveButtonKey));
      await tester.pumpAndSettle();

      // The editor finished; the show screen underneath refreshed on the
      // finished command (show-habit.edit-action#3).
      expect(find.byType(EditHabitScreen), findsNothing,
          reason: 'show-habit.edit-action#4');
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Meditate longer'),
        ),
        findsOneWidget,
        reason: 'show-habit.edit-action#4 — the refreshed detail screen shows '
            'the new name',
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(ShowHabitScreen), findsNothing,
          reason: 'show-habit.edit-action#4 — Back returns to the habit list');
      expect(find.byType(HabitListScreen), findsOneWidget,
          reason: 'show-habit.edit-action#4');
      expect(find.text('Meditate longer'), findsOneWidget,
          reason: 'show-habit.edit-action#4 — which also shows the updated '
              'name');
      expect(find.text('Meditate'), findsNothing,
          reason: 'show-habit.edit-action#4');
    });
  });

  // =======================================================================
  // reminders.show-habit-subtitle — the same row, seen from the reminders
  // domain of the ledger
  // =======================================================================

  group('reminders.show-habit-subtitle', () {
    testWidgets('#1 the reminder row is the formatted time, or "Off"',
        (tester) async {
      final scope = openScope();
      final withReminder = addHabit(
        scope,
        'Meditate',
        reminder: Reminder(21, 5, WeekdayList.everyDay),
      );
      final without = addHabit(scope, 'Run');

      await tester.pumpWidget(
        wrapCard(SubtitleCardView(state: stateOf(scope, withReminder).subtitle)),
      );
      await tester.pumpAndSettle();
      expect(
        textOf(tester, SubtitleCardView.reminderLabelKey).data,
        '9:05 PM',
        reason: 'reminders.show-habit-subtitle#1: when state.reminder is '
            'non-null the label is formatTime(context, reminder.hour, '
            'reminder.minute)',
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
        '21:05',
        reason: 'reminders.show-habit-subtitle#1: through the same 12/24-hour '
            'system preference the rest of the app uses',
      );

      await tester.pumpWidget(
        wrapCard(SubtitleCardView(state: stateOf(scope, without).subtitle)),
      );
      await tester.pumpAndSettle();
      expect(
        textOf(tester, SubtitleCardView.reminderLabelKey).data,
        'Off',
        reason: 'reminders.show-habit-subtitle#1: when it is null the label is '
            'the string reminder_off',
      );
    });

    testWidgets('#2 the reminder icon uses the FontAwesome typeface',
        (tester) async {
      final scope = openScope();
      final habit = addHabit(
        scope,
        'Meditate',
        reminder: Reminder(8, 30, WeekdayList.everyDay),
      );

      await tester.pumpWidget(
        wrapCard(SubtitleCardView(state: stateOf(scope, habit).subtitle)),
      );
      await tester.pumpAndSettle();

      final icon = textOf(tester, SubtitleCardView.reminderIconKey);
      expect(icon.style!.fontFamily, FontAssets.fontAwesomeFamily,
          reason: 'reminders.show-habit-subtitle#2: the reminder icon uses the '
              'FontAwesome typeface');
      expect(icon.data, FontAwesome.bellO,
          reason: 'reminders.show-habit-subtitle#2: and its glyph is the bell');
    });
  });
  // -----------------------------------------------------------------------
  // Scaffold: how the screen is reached, refreshed and themed
  // -----------------------------------------------------------------------

  group('scaffold, revisited', () {
    test('show-habit.screen-scaffold#1: the route is the habit URI, and '
        'the id in it resolves through habitList.getById', () {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      final route = ShowHabitScreen.route(scope: scope, habit: habit);
      expect(route.settings.name, 'content://org.isoron.uhabits/habit/${habit.id}',
          reason: 'show-habit.screen-scaffold#1 — the screen is identified by '
              'Habit.uriString');
      expect(route.settings.name, habit.uriString,
          reason: 'show-habit.screen-scaffold#1');

      // Parsing the trailing id back out and asking the habit list for it
      // returns the very same habit, which is the whole of the Android
      // resolution step.
      final id = parseContentUriId(Uri.parse(route.settings.name!));
      expect(id, habit.id,
          reason: 'show-habit.screen-scaffold#1 — the id is the trailing path '
              'segment');
      expect(scope.habitList.getById(id), same(habit),
          reason: 'show-habit.screen-scaffold#1 — habitList.getById(id) is the '
              'habit the screen shows');
    });

    test('show-habit.screen-scaffold#5: refresh() completes before it '
        'returns, on the one UI isolate', () {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final model =
          ShowHabitModel(scope: scope, habit: habit, theme: LightTheme());
      addTearDown(model.dispose);

      var notifications = 0;
      model.addListener(() => notifications++);
      habit.name = 'Meditate twice';

      model.refresh();
      // No await, no pump: Kotlin launches refresh on Dispatchers.Main and
      // Dart's UI isolate *is* that thread, so the new state and the
      // notification are both already there.
      expect(model.state.title, 'Meditate twice',
          reason: 'show-habit.screen-scaffold#5 — refresh runs on the main '
              'dispatcher');
      expect(notifications, 1,
          reason: 'show-habit.screen-scaffold#5 — and its listeners with it');
    });

    test('show-habit.screen-scaffold#6: onResume registers the command '
        'listener and onPause unregisters it', () {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final model =
          ShowHabitModel(scope: scope, habit: habit, theme: LightTheme());
      addTearDown(model.dispose);
      var notifications = 0;
      model.addListener(() => notifications++);

      final command = CreateRepetitionCommand(
        scope.habitList,
        habit,
        getToday(),
        Entry.yesManual,
        '',
      );

      scope.commandRunner.notifyListeners(command);
      expect(notifications, 0,
          reason: 'show-habit.screen-scaffold#6 — nothing is registered before '
              'onResume');

      model.attach();
      expect(notifications, 1,
          reason: 'show-habit.screen-scaffold#6 — onResume registers and '
              'refreshes');
      scope.commandRunner.notifyListeners(command);
      expect(notifications, 2,
          reason: 'show-habit.screen-scaffold#6 — and the screen is now a '
              'CommandRunner.Listener');

      model.detach();
      scope.commandRunner.notifyListeners(command);
      expect(notifications, 2,
          reason: 'show-habit.screen-scaffold#6 — onPause unregisters the '
              'listener');

      // Re-attaching is idempotent: a second onResume does not double-register.
      model.attach();
      final before = notifications;
      scope.commandRunner.notifyListeners(command);
      expect(notifications, before + 1,
          reason: 'show-habit.screen-scaffold#6');
    });

    testWidgets('show-habit.screen-scaffold#11: every card state carries the '
        'theme variant the app was built from', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      Future<core.Theme> themeUnder(core.Theme appTheme) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: appThemeData(appTheme),
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            home: Provider<AppScope>.value(
              value: scope,
              // One key for all three: the screen stays mounted and the
              // theme really is switched under it, as a night-mode toggle
              // would.
              child: ShowHabitScreen(
                key: const ValueKey<String>('themeProbe'),
                habit: habit,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return modelOf(tester).state.theme;
      }

      expect(await themeUnder(LightTheme()), isA<LightTheme>(),
          reason: 'show-habit.screen-scaffold#11');
      final dark = await themeUnder(DarkTheme());
      expect(dark, isA<DarkTheme>(), reason: 'show-habit.screen-scaffold#11');
      expect(dark, isNot(isA<PureBlackTheme>()),
          reason: 'show-habit.screen-scaffold#11');
      expect(await themeUnder(PureBlackTheme()), isA<PureBlackTheme>(),
          reason: 'show-habit.screen-scaffold#11 — pure black is its own '
              'variant, not just a dark one');

      // And the theme really is the one every card state is built with.
      final state = modelOf(tester).state;
      expect(state.subtitle.theme, same(state.theme),
          reason: 'show-habit.screen-scaffold#11');
      expect(state.overview.theme, same(state.theme),
          reason: 'show-habit.screen-scaffold#11');
      expect(state.target.theme, same(state.theme),
          reason: 'show-habit.screen-scaffold#11');
    });
  });

  // -----------------------------------------------------------------------
  // Card chrome
  // -----------------------------------------------------------------------

  group('card chrome', () {
    testWidgets('show-habit.card-order-and-visibility#6: the subtitle card is '
        'the one card that is not a @style/Card', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate', description: 'notes');

      await tester.pumpWidget(wrap(scope, habit));
      await tester.pumpAndSettle();

      final subtitle = find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.subtitle));
      final material = tester.widget<Material>(
        find.descendant(of: subtitle, matching: find.byType(Material)).first,
      );
      expect(material.color,
          _toFlutterColor(LightTheme().headerBackgroundColor),
          reason: 'show-habit.card-order-and-visibility#6 — '
              'headerBackgroundColor, not cardBgColor');
      expect(material.elevation, 2.0,
          reason: 'show-habit.card-order-and-visibility#6 — 2dp of elevation');

      final padding = tester
          .widgetList<Padding>(
            find.descendant(of: subtitle, matching: find.byType(Padding)),
          )
          .map((p) => p.padding)
          .whereType<EdgeInsetsDirectional>()
          .single;
      expect(padding.start, 60.0,
          reason: 'show-habit.card-order-and-visibility#6 — 60dp of side '
              'padding');
      expect(padding.top, 15.0,
          reason: 'show-habit.card-order-and-visibility#6 — 15dp top padding');
      expect(padding.bottom, 10.0,
          reason: 'show-habit.card-order-and-visibility#6 — 10dp bottom '
              'padding');

      // The notes card next to it is a plain @style/Card instead.
      final notes = find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.notes));
      final notesMaterial = tester.widget<Material>(
        find.descendant(of: notes, matching: find.byType(Material)).first,
      );
      expect(notesMaterial.color,
          _toFlutterColor(LightTheme().cardBackgroundColor),
          reason: 'show-habit.card-order-and-visibility#6 — every other card '
              'takes cardBgColor and 1dp');
      expect(notesMaterial.elevation, 1.0,
          reason: 'show-habit.card-order-and-visibility#6');
    });

    testWidgets('show-habit.notes-card#3 #4: the description is plain text, '
        'and a new state always redraws it', (tester) async {
      final scope = openScope();
      final habit = addHabit(
        scope,
        'Meditate',
        description: '**not bold** https://example.com',
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
      expect(text.data, '**not bold** https://example.com',
          reason: 'show-habit.notes-card#3 — rendered verbatim: no markdown, '
              'no links, no formatting');
      expect(text.textSpan, isNull,
          reason: 'show-habit.notes-card#3 — a single plain string, not a rich '
              'span tree');
      expect(text.style!.color,
          _toFlutterColor(LightTheme().highContrastTextColor),
          reason: 'show-habit.notes-card#3 — in contrast100');

      // setState always invalidates: pushing a new state repaints, with
      // nothing memoised from the previous one.
      habit.description = 'edited';
      await tester.pumpWidget(
        wrapCard(
          NotesCardView(
            state: stateOf(scope, habit).notes,
            theme: LightTheme(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byType(Text)).data, 'edited',
          reason: 'show-habit.notes-card#4 — setState always calls '
              'invalidate() after updating');
    });

    testWidgets('show-habit.overview-card#11: the row is weighted 5, 4, 4, 4, '
        '4', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(
        wrapCard(OverviewCardView(state: stateOf(scope, habit).overview)),
      );
      await tester.pumpAndSettle();

      expect(OverviewCardView.ringWeight, 5,
          reason: 'show-habit.overview-card#11 — the ring column has weight 5');
      expect(OverviewCardView.columnWeight, 4,
          reason: 'show-habit.overview-card#11 — the four value columns have '
              'weight 4');

      final flexes = tester
          .widgetList<Expanded>(
            find.descendant(of: find.byType(Row), matching: find.byType(Expanded)),
          )
          .map((e) => e.flex)
          .toList();
      expect(flexes, <int>[5, 4, 4, 4, 4],
          reason: 'show-habit.overview-card#11 — in that order: ring, Score, '
              'Month, Year, Total');
    });

    test('charts-canvas-theming.ring-view-android#3 #4 #10: the ring the '
        'overview card draws', () {
      final theme = LightTheme();
      final ring = RingPainter(
        color: _toFlutterColor(theme.colorOf(const PaletteColor(7))),
        inactiveColor: _toFlutterColor(theme.highContrastTextColor)
            .withValues(alpha: RingPainter.inactiveAlpha),
        backgroundColor: _toFlutterColor(theme.cardBackgroundColor),
        percentage: 0.6,
        thickness: OverviewCardView.ringThickness,
      );

      expect(RingPainter.inactiveAlpha, 0.15,
          reason: 'charts-canvas-theming.ring-view-android#3 — inactiveColor '
              'is forced to 15% alpha at construction');
      expect(ring.inactiveColor.a, closeTo(0.15, 1e-6),
          reason: 'charts-canvas-theming.ring-view-android#3');

      expect(RingPainter.defaultPrecision, 0.01,
          reason: 'charts-canvas-theming.ring-view-android#4 — the default '
              'precision is 0.01');
      expect(ring.precision, 0.01,
          reason: 'charts-canvas-theming.ring-view-android#4 — which the '
              'overview layout does not override');
      expect(ring.sweepDegrees, closeTo(216.0, 1e-6),
          reason: 'charts-canvas-theming.ring-view-android#4 — angle = 360 * '
              'round(percentage / precision) * precision');
      // 1% steps: 3.6 degrees apart, with everything between snapping.
      expect(
        RingPainter(
          color: ring.color,
          inactiveColor: ring.inactiveColor,
          backgroundColor: ring.backgroundColor,
          percentage: 0.6049,
          thickness: 5,
        ).sweepDegrees,
        closeTo(216.0, 1e-6),
        reason: 'charts-canvas-theming.ring-view-android#4',
      );
      expect(
        RingPainter(
          color: ring.color,
          inactiveColor: ring.inactiveColor,
          backgroundColor: ring.backgroundColor,
          percentage: 0.606,
          thickness: 5,
        ).sweepDegrees,
        closeTo(219.6, 1e-6),
        reason: 'charts-canvas-theming.ring-view-android#4',
      );

      expect(OverviewCardView.ringSize, 30.0,
          reason: 'charts-canvas-theming.ring-view-android#10 — the show-habit '
              'overview ring is 30dp');
      expect(OverviewCardView.ringThickness, 5.0,
          reason: 'charts-canvas-theming.ring-view-android#10 — with thickness '
              '5dp');
    });
  });

  // -----------------------------------------------------------------------
  // Menu actions the screen exposes, and the strings they use
  // -----------------------------------------------------------------------

  group('menu actions', () {
    testWidgets('show-habit.edit-action#2: the editor is opened with the habit '
        'id and the habit type', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Run', type: HabitType.numerical);

      await tester.pumpWidget(wrap(scope, habit));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ShowHabitScreen.editActionKey));
      await tester.pumpAndSettle();

      final editor =
          tester.widget<EditHabitScreen>(find.byType(EditHabitScreen));
      expect(editor.habitId, habit.id,
          reason: 'show-habit.edit-action#2 — the long extra "habitId" is '
              'habit.id');
      expect(editor.habitType, HabitType.numerical,
          reason: 'show-habit.edit-action#2 — and the extra "habitType" is '
              'habit.type');

      // Back to the detail screen: the show screen is not finished by Edit
      // (show-habit.edit-action#3), so the editor sits on top of it.
      await tester.pageBack();
      await tester.pumpAndSettle();

      final boolean = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope, boolean));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ShowHabitScreen.editActionKey));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditHabitScreen>(find.byType(EditHabitScreen)).habitType,
        HabitType.yesNo,
        reason: 'show-habit.edit-action#2',
      );
    });

    testWidgets('show-habit.menu#6 and show-habit.archive-unarchive#3: the '
        'menu titles and the two confirmation messages', (tester) async {
      late L10n l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Builder(builder: (context) {
            l10n = L10n.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        <String>[
          l10n.export,
          l10n.archive,
          l10n.unarchive,
          l10n.delete,
          l10n.edit,
        ],
        <String>['Export', 'Archive', 'Unarchive', 'Delete', 'Edit'],
        reason: 'show-habit.menu#6 — the five translated menu titles',
      );

      // ShowHabitMenuPresenter.Message.HABIT_ARCHIVED / HABIT_UNARCHIVED, at
      // the quantity the show screen always uses.
      expect(l10n.toastHabitsArchived(1), 'Habit archived',
          reason: 'show-habit.archive-unarchive#3 — HABIT_ARCHIVED renders the '
              'quantity-1 string "Habit archived"');
      expect(l10n.toastHabitsUnarchived(1), 'Habit unarchived',
          reason: 'show-habit.archive-unarchive#3 — and HABIT_UNARCHIVED '
              '"Habit unarchived"');
    });
  });

  // -----------------------------------------------------------------------
  // The overflow menu — ShowHabitMenu.kt and res/menu/show_habit.xml
  // -----------------------------------------------------------------------

  group('overflow menu', () {
    ShowHabitModel menuModel(AppScope scope, Habit habit) {
      final model = ShowHabitModel(
        scope: scope,
        habit: habit,
        theme: LightTheme(),
        system: _TempCSVOutputDir(tempDir.path),
      );
      addTearDown(model.dispose);
      return model;
    }

    test('show-habit.menu#1: the six items, in the order show_habit.xml '
        'declares them', () {
      expect(
        ShowHabitMenuItem.values,
        <ShowHabitMenuItem>[
          ShowHabitMenuItem.export,
          ShowHabitMenuItem.archive,
          ShowHabitMenuItem.unarchive,
          ShowHabitMenuItem.delete,
          ShowHabitMenuItem.edit,
          ShowHabitMenuItem.randomize,
        ],
        reason: 'show-habit.menu#1 — Export, Archive, Unarchive, Delete, '
            'Edit, Randomize',
      );

      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      // An unarchived habit hides Unarchive, and Randomize is off by default,
      // so what the toolbar actually inflates keeps the same relative order.
      expect(
        menuModel(scope, habit).menu.onCreateOptionsMenu(),
        <ShowHabitMenuItem>[
          ShowHabitMenuItem.export,
          ShowHabitMenuItem.archive,
          ShowHabitMenuItem.delete,
          ShowHabitMenuItem.edit,
        ],
        reason: 'show-habit.menu#1',
      );
    });

    test('show-habit.menu#2: Edit is the only action button; the other five '
        'are overflow-only', () {
      expect(
        ShowHabitMenuItem.values.where((i) => i.isActionButton).toList(),
        <ShowHabitMenuItem>[ShowHabitMenuItem.edit],
        reason: 'show-habit.menu#2 — showAsAction="ifRoom" on Edit alone',
      );
      for (final item in <ShowHabitMenuItem>[
        ShowHabitMenuItem.export,
        ShowHabitMenuItem.archive,
        ShowHabitMenuItem.unarchive,
        ShowHabitMenuItem.delete,
        ShowHabitMenuItem.randomize,
      ]) {
        expect(item.isActionButton, isFalse,
            reason: 'show-habit.menu#2 — $item is showAsAction="never"');
      }
    });

    testWidgets('show-habit.menu#2: the toolbar shows Edit and hides the rest '
        'behind the overflow button', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(wrap(scope, habit));
      await tester.pumpAndSettle();

      expect(find.byKey(ShowHabitScreen.editActionKey), findsOneWidget,
          reason: 'show-habit.menu#2 — Edit is an action button');
      expect(find.byKey(ShowHabitScreen.overflowMenuKey), findsOneWidget,
          reason: 'show-habit.menu#2 — the other five need the overflow');
      expect(
        find.byKey(ShowHabitScreen.menuItemKey(ShowHabitMenuItem.delete)),
        findsNothing,
        reason: 'show-habit.menu#2 — and are not on the toolbar',
      );

      await tester.tap(find.byKey(ShowHabitScreen.overflowMenuKey));
      await tester.pumpAndSettle();

      for (final item in <ShowHabitMenuItem>[
        ShowHabitMenuItem.export,
        ShowHabitMenuItem.archive,
        ShowHabitMenuItem.delete,
      ]) {
        expect(find.byKey(ShowHabitScreen.menuItemKey(item)), findsOneWidget,
            reason: 'show-habit.menu#2 — $item is in the overflow');
      }
      expect(
        find.byKey(ShowHabitScreen.menuItemKey(ShowHabitMenuItem.edit)),
        findsNothing,
        reason: 'show-habit.menu#2 — Edit is not repeated in the overflow',
      );
    });

    test('show-habit.menu#5 and show-habit.randomize#1: Randomize is hidden '
        'unless pref_developer is set', () {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final model = menuModel(scope, habit);

      expect(scope.preferences.isDeveloper, isFalse,
          reason: 'show-habit.menu#5 — pref_developer defaults to false');
      expect(
        model.menu.onCreateOptionsMenu(),
        isNot(contains(ShowHabitMenuItem.randomize)),
        reason: 'show-habit.menu#5 — android:visible="false" until the '
            'developer flag turns it on',
      );
      expect(
        model.menu.onCreateOptionsMenu(),
        isNot(contains(ShowHabitMenuItem.randomize)),
        reason: 'show-habit.randomize#1 — the action is unreachable without '
            'preferences.isDeveloper',
      );

      scope.preferences.isDeveloper = true;
      expect(model.menu.onCreateOptionsMenu(),
          contains(ShowHabitMenuItem.randomize),
          reason: 'show-habit.menu#5 — and visible once it is');
      expect(model.menu.onCreateOptionsMenu(),
          contains(ShowHabitMenuItem.randomize),
          reason: 'show-habit.randomize#1 — which is the only way in');
    });

    testWidgets('show-habit.randomize#1: the overflow carries Randomize only '
        'for a developer build', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(wrap(scope, habit));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ShowHabitScreen.overflowMenuKey));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ShowHabitScreen.menuItemKey(ShowHabitMenuItem.randomize)),
        findsNothing,
        reason: 'show-habit.randomize#1 — not reachable from a normal build',
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      scope.preferences.isDeveloper = true;
      modelOf(tester).refresh();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ShowHabitScreen.overflowMenuKey));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ShowHabitScreen.menuItemKey(ShowHabitMenuItem.randomize)),
        findsOneWidget,
        reason: 'show-habit.randomize#1 — reachable once isDeveloper is set',
      );
      expect(find.text(ShowHabitMenuItem.randomizeTitle), findsOneWidget,
          reason: 'show-habit.menu#5 — titled with the literal "Randomize"');
    });

    test('show-habit.menu#5: the Randomize title is never translated', () {
      expect(ShowHabitMenuItem.randomize.title(L10nEn()), 'Randomize',
          reason: 'show-habit.menu#5 — an untranslated XML literal');
      expect(ShowHabitMenuItem.randomize.title(L10nEs()), 'Randomize',
          reason: 'show-habit.menu#5 — the same in every locale, unlike the '
              'other five titles');
      expect(ShowHabitMenuItem.delete.title(L10nEs()),
          isNot(ShowHabitMenuItem.delete.title(L10nEn())),
          reason: 'show-habit.menu#6 — which do follow the locale');
    });

    test('show-habit.menu#7: the six known ids return true, route to their own '
        'presenter call, and anything else returns false', () {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      // A recording presenter: the routing is what the `when` block decides,
      // and running the real commands here would only exercise
      // ShowHabitMenuPresenter, which has its own tests.
      final presenter = _RecordingMenuPresenter(scope, habit);
      final menu = ShowHabitMenu(
        presenter: presenter,
        preferences: scope.preferences,
      );

      const expected = <ShowHabitMenuItem, String>{
        ShowHabitMenuItem.edit: 'onEditHabit',
        ShowHabitMenuItem.archive: 'onArchiveHabits',
        ShowHabitMenuItem.unarchive: 'onUnarchiveHabits',
        ShowHabitMenuItem.delete: 'onDeleteHabit',
        ShowHabitMenuItem.randomize: 'onRandomize',
        ShowHabitMenuItem.export: 'onExportCSV',
      };
      for (final entry in expected.entries) {
        presenter.calls.clear();
        expect(menu.onOptionsItemSelected(entry.key), isTrue,
            reason: 'show-habit.menu#7 — ${entry.key} is one of the six '
                'handled ids');
        expect(presenter.calls, <String>[entry.value],
            reason: 'show-habit.menu#7 — and it reaches ${entry.value}');
      }

      // android.R.id.home, the Up button, is the id that matters: falling
      // through is what lets the platform's default handler navigate up.
      presenter.calls.clear();
      expect(menu.onOptionsItemSelected('android.R.id.home'), isFalse,
          reason: 'show-habit.menu#7 — anything else falls through');
      expect(menu.onOptionsItemSelected(null), isFalse,
          reason: 'show-habit.menu#7');
      expect(menu.onOptionsItemSelected(0), isFalse,
          reason: 'show-habit.menu#7');
      expect(presenter.calls, isEmpty,
          reason: 'show-habit.menu#7 — and nothing at all is dispatched');
    });
  });

  // -----------------------------------------------------------------------
  // Messages, deletion and widgets
  // -----------------------------------------------------------------------

  group('menu actions, wired', () {
    testWidgets('show-habit.archive-unarchive#3: archiving shows a white '
        'snackbar at the bottom of the screen', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(wrap(scope, habit));
      await tester.pumpAndSettle();

      modelOf(tester).menuPresenter.onArchiveHabits();
      await tester.pump();
      final snack = tester.widget<Text>(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Habit archived'),
        ),
      );
      expect(snack.style!.color, Colors.white,
          reason: 'show-habit.archive-unarchive#3 — white text at the bottom '
              'of the screen');
      // Let the snackbar time out and the command finish, so neither outlives
      // the test.
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('show-habit.archive-unarchive#5: a message with no suitable '
        'parent view is dropped in silence', (tester) async {
      // `Activity.showMessage` wraps `Snackbar.make(findViewById(content), …)`
      // in a try/catch for IllegalArgumentException.
      late BuildContext hostless;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(builder: (context) {
            hostless = context;
            return const SizedBox.shrink();
          }),
        ),
      );
      expect(ScaffoldMessenger.maybeOf(hostless), isNull,
          reason: 'show-habit.archive-unarchive#5 — no suitable parent view');
      expect(() => showShowHabitMessage(hostless, 'Habit archived'),
          returnsNormally,
          reason: 'show-habit.archive-unarchive#5 — the '
              'IllegalArgumentException is swallowed');
      await tester.pump();
      expect(find.text('Habit archived'), findsNothing,
          reason: 'show-habit.archive-unarchive#5 — and nothing is shown');
    });

    testWidgets('show-habit.delete#4: the confirmation is shown with '
        'dismissCurrentAndShow, so the open entry popup goes first',
        (tester) async {
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

      // A tap on a calendar day opens the number popup, which is one of the
      // dialogs `dismissCurrentAndShow` tracks.
      model.presenter.historyCardPresenter.onDateShortPress(getToday());
      await tester.pumpAndSettle();
      expect(find.byType(NumberDialog), findsOneWidget);

      model.menuPresenter.onDeleteHabit();
      await tester.pumpAndSettle();

      expect(find.byType(NumberDialog), findsNothing,
          reason: 'show-habit.delete#4 and confirm-delete.dialog#7 — it is '
              'shown with dismissCurrentAndShow(), so it closes any other '
              'tracked dialog first');
      expect(find.byType(ConfirmDeleteDialog), findsOneWidget,
          reason: 'show-habit.delete#4 and confirm-delete.dialog#7 — and the '
              'confirmation takes its place');
      expect(
        tester
            .widget<ConfirmDeleteDialog>(find.byType(ConfirmDeleteDialog))
            .quantity,
        1,
        reason: 'confirm-delete.dialog#8 — ShowHabitActivity always passes '
            'quantity = 1',
      );
      expect(find.text('Delete habit?'), findsOneWidget,
          reason: 'confirm-delete.dialog#8 — so the detail screen always asks '
              'about one habit, whatever the list has selected');

      // And "No" still leaves the habit alone.
      await tester.tap(find.byKey(const ValueKey<String>('confirm_delete_no')));
      await tester.pumpAndSettle();
      expect(scope.habitList.getById(habit.id!), same(habit),
          reason: 'show-habit.delete#2');
    });

    test('show-habit.widget-refresh#2: updateWidgets pushes new data '
        'to every home-screen widget', () async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final platform = _RecordingHomeWidgetPlatform();
      final sync = WidgetSync(
        bridge: HomeWidgetBridge(
          habitList: scope.habitList,
          registry: WidgetRegistry(scope.preferencesStorage),
          platform: platform,
        ),
        commandRunner: scope.commandRunner,
        taskRunner: scope.taskRunner,
        midnightTimer: scope.midnightTimer,
        preferences: scope.preferences,
      );
      final model = ShowHabitModel(
        scope: scope,
        habit: habit,
        theme: LightTheme(),
        widgetUpdater: sync.updateWidgets,
      );
      addTearDown(model.dispose);

      // `ScoreCardPresenter.onSpinnerPosition` writes the preference, then
      // calls screen.updateWidgets() and screen.refresh()
      // (`show-habit.widget-refresh#1`).
      model.presenter.scoreCardPresenter.onSpinnerPosition(3);
      await sync.settle();

      expect(platform.refreshed, HomeWidgetBridge.providerNames,
          reason: 'show-habit.widget-refresh#2 — updateWidgets delegates to '
              'the WidgetUpdater, which pushes to all app widgets');
      expect(scope.preferences.scoreCardSpinnerPosition, 3,
          reason: 'show-habit.widget-refresh#2 — the spinner preference is '
              'the one the widgets read their bucket size from');
      expect(Preferences(scope.preferencesStorage).scoreCardSpinnerPosition, 3,
          reason: 'show-habit.widget-refresh#2 — and it is shared storage, '
              'not screen-local state');
    });

    testWidgets('show-habit.delete#3: confirming deletes the habit and closes '
        'the screen', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final other = addHabit(scope, 'Run');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Provider<AppScope>.value(
            value: scope,
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => ShowHabitScreen.open(context, habit),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      modelOf(tester).menuPresenter.onDeleteHabit();
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey<String>('confirm_delete_yes')));
      await tester.pumpAndSettle();

      expect(find.byType(ShowHabitScreen), findsNothing,
          reason: 'show-habit.delete#3 — the screen finishes');
      expect(scope.habitList.getById(habit.id!), isNull,
          reason: 'show-habit.delete#3 — and the habit is gone');
      expect(scope.habitList.getById(other.id!), same(other),
          reason: 'show-habit.delete#3 — only that one');
    });
  });

  // -----------------------------------------------------------------------
  // The History card's date-clicked path
  // -----------------------------------------------------------------------

  group('history card wiring', () {
    testWidgets('history-editor.dialog#11: a day tapped on the card opens the '
        'check-mark popup, or the number popup for a numerical habit',
        (tester) async {
      final scope = openScope();
      final boolean = addHabit(scope, 'Meditate');

      await tester.pumpWidget(wrap(scope, boolean));
      await tester.pumpAndSettle();
      modelOf(tester)
          .presenter
          .historyCardPresenter
          .onDateShortPress(getToday());
      await tester.pumpAndSettle();
      expect(find.byType(CheckmarkDialog), findsOneWidget,
          reason: 'history-editor.dialog#11 — a yes/no habit gets the '
              'check-mark popup');

      // Saving from the popup runs a CreateRepetitionCommand, which refreshes
      // the whole screen.
      await tester
          .tap(find.byKey(const ValueKey<String>('checkmark_yes_button')));
      await tester.pumpAndSettle();
      expect(boolean.computedEntries.get(getToday()).value, Entry.yesManual,
          reason: 'history-editor.dialog#11');

      final numerical = addHabit(
        scope,
        'Run',
        type: HabitType.numerical,
        targetValue: 5,
        unit: 'km',
      );
      await tester.pumpWidget(wrap(scope, numerical));
      await tester.pumpAndSettle();
      modelOf(tester)
          .presenter
          .historyCardPresenter
          .onDateShortPress(getToday());
      await tester.pumpAndSettle();
      expect(find.byType(NumberDialog), findsOneWidget,
          reason: 'history-editor.dialog#11 — a numerical habit gets the '
              'number popup');
    });

    testWidgets('history-editor.dialog#14: the card\'s Edit button opens the '
        'editor, wired to the card\'s own presenter', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(wrap(scope, habit));
      await tester.pumpAndSettle();
      final model = modelOf(tester);

      await tester.ensureVisible(find.byKey(HistoryCardView.editButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistoryCardView.editButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryEditorDialog), findsOneWidget,
          reason: 'history-editor.dialog#14');
      expect(
        identical(
          HistoryEditorDialog.current!.chart!.onDateClickedListener,
          model.presenter.historyCardPresenter,
        ),
        isTrue,
        reason: 'history-editor.dialog#17 — the dialog is routed to the same '
            'HistoryCardPresenter as the card',
      );

      // And a day tapped inside the dialog reaches the popup through it.
      HistoryEditorDialog.current!.chart!.onDateClickedListener
          .onDateShortPress(getToday());
      await tester.pumpAndSettle();
      expect(find.byType(CheckmarkDialog), findsOneWidget,
          reason: 'history-editor.dialog#11');
      // The editor stays open underneath the popup.
      expect(find.byType(HistoryEditorDialog), findsOneWidget,
          reason: 'history-editor.dialog#10');
    });

    testWidgets('show-habit.screen-scaffold#7 and history-editor.dialog#13: '
        'onResume re-attaches the editor\'s date-clicked listener',
        (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(wrap(scope, habit));
      await tester.pumpAndSettle();
      final model = modelOf(tester);

      await tester.ensureVisible(find.byKey(HistoryCardView.editButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistoryCardView.editButtonKey));
      await tester.pumpAndSettle();

      // `findFragmentByTag("historyEditor")` finds it.
      final editor = HistoryEditorDialog.current;
      expect(editor, isNotNull,
          reason: 'show-habit.screen-scaffold#7 — the dialog is still present');

      // A configuration change recreates the fragment, which comes back with
      // whatever listener its own arguments gave it — here, a stranger.
      final stranger = _RecordingDateListener();
      editor!.setOnDateClickedListener(stranger);
      expect(identical(editor.chart!.onDateClickedListener, stranger), isTrue);

      // onPause / onResume.
      model.detach();
      model.attach();
      await tester.pumpAndSettle();

      expect(
        identical(
          editor.chart!.onDateClickedListener,
          model.presenter.historyCardPresenter,
        ),
        isTrue,
        reason: 'show-habit.screen-scaffold#7 — onResume re-attaches the '
            'screen\'s HistoryCardPresenter',
      );
      expect(
        identical(
          HistoryEditorDialog.current!.chart!.onDateClickedListener,
          model.presenter.historyCardPresenter,
        ),
        isTrue,
        reason: 'history-editor.dialog#13 — so the reopened dialog stays '
            'interactive after a configuration change',
      );

      // And it really is interactive again.
      editor.chart!.onDateClickedListener.onDateShortPress(getToday());
      await tester.pumpAndSettle();
      expect(find.byType(CheckmarkDialog), findsOneWidget,
          reason: 'history-editor.dialog#13');
      expect(stranger.presses, isEmpty,
          reason: 'history-editor.dialog#13 — the stale listener is gone');
    });
  });

  // -----------------------------------------------------------------------
  // Intent resolution
  // -----------------------------------------------------------------------

  group('intent resolution', () {
    test('show-habit.screen-scaffold#2: an unknown id crashes; there is no '
        '"habit not found" screen', () {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      expect(
        ShowHabitScreen.habitFromUri(
          scope.habitList,
          Uri.parse(habit.uriString),
        ),
        same(habit),
        reason: 'show-habit.screen-scaffold#1 — the URI resolves through '
            'habitList.getById',
      );

      final unknown =
          Uri.parse('content://org.isoron.uhabits/habit/${habit.id! + 4242}');
      expect(scope.habitList.getById(parseContentUriId(unknown)), isNull,
          reason: 'show-habit.screen-scaffold#2 — getById returns null for an '
              'id that is not in the list');
      expect(
        () => ShowHabitScreen.habitFromUri(scope.habitList, unknown),
        throwsA(isA<TypeError>()),
        reason: 'show-habit.screen-scaffold#2 — and the `!!` dereferences it '
            'rather than falling back to an empty state',
      );
    });
  });
}

/// A [ShowHabitMenuPresenter] that records which method the menu called
/// instead of running it. Every member `ShowHabitMenu` can reach is overridden,
/// so the constructor arguments are never touched.
class _RecordingMenuPresenter extends ShowHabitMenuPresenter {
  _RecordingMenuPresenter(AppScope scope, Habit habit)
      : super(
          commandRunner: scope.commandRunner,
          habit: habit,
          habitList: scope.habitList,
          screen: _NullMenuScreen(),
          system: _TempCSVOutputDir('/dev/null'),
          taskRunner: scope.taskRunner,
        );

  final List<String> calls = <String>[];

  @override
  void onEditHabit() => calls.add('onEditHabit');

  @override
  void onArchiveHabits() => calls.add('onArchiveHabits');

  @override
  void onUnarchiveHabits() => calls.add('onUnarchiveHabits');

  @override
  void onDeleteHabit() => calls.add('onDeleteHabit');

  @override
  void onRandomize() => calls.add('onRandomize');

  @override
  void onExportCSV() => calls.add('onExportCSV');
}

class _NullMenuScreen implements ShowHabitMenuPresenterScreen {
  @override
  void close() {}

  @override
  void refresh() {}

  @override
  void showDeleteConfirmationScreen(void Function() callback) {}

  @override
  void showEditHabitScreen(Habit habit) {}

  @override
  void showMessage(ShowHabitMenuPresenterMessage? m) {}

  @override
  void showSendFileScreen(String filename) {}
}

/// `HabitsDirFinder(AndroidDirFinder(this))` over a directory the test owns.
class _TempCSVOutputDir implements ShowHabitMenuPresenterSystem {
  _TempCSVOutputDir(this.path);

  final String path;

  @override
  UserFile getCSVOutputDir() => LocalUserFile(path);
}

/// [HomeWidgetPlatform] over nothing, recording which providers were told to
/// redraw.
class _RecordingHomeWidgetPlatform implements HomeWidgetPlatform {
  final List<String> refreshed = <String>[];

  @override
  Future<void> saveWidgetData(String id, String? value) async {}

  @override
  Future<void> updateWidget({
    required String name,
    required String qualifiedAndroidName,
    required String iOSName,
  }) async {
    refreshed.add(name);
  }

  @override
  Future<void> setAppGroupId(String groupId) async {}
}

/// The listener a recreated dialog would come back with.
class _RecordingDateListener extends OnDateClickedListener {
  final List<LocalDate> presses = <LocalDate>[];

  @override
  void onDateShortPress(LocalDate date) => presses.add(date);

  @override
  void onDateLongPress(LocalDate date) => presses.add(date);
}

/// Same rounding as `FlutterCanvas.setColor` and `core.Color.toInt`.
Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
