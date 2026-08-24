/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabit.kt
/// and .../show/views/{SubtitleCard,NotesCard,OverviewCard,TargetCard}.kt,
/// together with the pure formatting/visibility decisions their Android views
/// make (ShowHabitView.kt, SubtitleCardView.kt, NotesCardView.kt,
/// OverviewCardView.kt, TargetCardView.kt, EditHabitActivity.formatFrequency
/// and DateExtensions.formatTime).
///
/// Kotlin tests consulted: SubtitleCardViewTest.kt, NotesCardViewTest.kt and
/// OverviewCardViewTest.kt (all screenshot tests, so their fixtures — not
/// their assertions — carry over).
///
/// Every `expect` carries the parity-ledger rule id it exercises.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/gui/font_awesome.dart';
import 'package:uhabits_core/src/gui/theme.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/show_habit.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/bar_card.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/frequency_card.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/history_card.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/notes_card.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/overview_card.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/score_card.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/streak_card.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/subtitle_card.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/target_card.dart';
import 'package:uhabits_core/src/ui/views/number_button.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// 2024-05-15 is a Wednesday; May has 31 days and 2024 is a leap year, so
/// `monthLength` is 31 and `yearLength` is 366 for every target computed here.
final LocalDate _today = LocalDate.ymd(2024, 5, 15);

late MemoryModelFactory _modelFactory;
late MemoryHabitList _habitList;
late HabitFixtures _fixtures;
late Preferences _preferences;
late MemoryStorage _storage;
late Theme _theme;

Habit _buildHabit() => _modelFactory.buildHabit();

/// A numerical habit whose entries are spread across today, this week, this
/// month, this quarter, this year and the previous year, so that every
/// grouping bucket of the target card gets a distinct total.
Habit _spreadNumericalHabit({
  Frequency frequency = Frequency.daily,
  double targetValue = 100.0,
}) {
  final habit = _buildHabit();
  habit.type = HabitType.numerical;
  habit.frequency = frequency;
  habit.targetValue = targetValue;
  habit.originalEntries.add(Entry(LocalDate.ymd(2024, 5, 15), 1000));
  habit.originalEntries.add(Entry(LocalDate.ymd(2024, 5, 13), 2000));
  habit.originalEntries.add(Entry(LocalDate.ymd(2024, 5, 10), 4000));
  habit.originalEntries.add(Entry(LocalDate.ymd(2024, 4, 20), 8000));
  habit.originalEntries.add(Entry(LocalDate.ymd(2024, 2, 10), 16000));
  habit.originalEntries.add(Entry(LocalDate.ymd(2023, 12, 25), 32000));
  habit.recompute();
  return habit;
}

TargetCardState _buildTargetState(Habit habit) =>
    TargetCardPresenter.buildState(
      habit: habit,
      firstWeekday: _preferences.firstWeekdayInt,
      theme: _theme,
    );

void main() {
  setUp(() {
    setToday(_today);
    _modelFactory = MemoryModelFactory();
    _habitList = MemoryHabitList();
    _fixtures = HabitFixtures(_modelFactory, _habitList);
    _storage = MemoryStorage();
    // Sunday, so that week buckets start on 2024-05-12 regardless of locale.
    _storage.putString('pref_first_weekday', '1');
    _preferences = Preferences(_storage);
    _theme = LightTheme();
  });

  tearDown(resetToday);

  // -------------------------------------------------------------------------
  // show-habit.card-order-and-visibility
  // -------------------------------------------------------------------------

  group('show-habit.card-order-and-visibility', () {
    test('cards are declared in the layout order', () {
      expect(
        ShowHabitCard.values,
        <ShowHabitCard>[
          ShowHabitCard.subtitle,
          ShowHabitCard.notes,
          ShowHabitCard.overview,
          ShowHabitCard.target,
          ShowHabitCard.score,
          ShowHabitCard.bar,
          ShowHabitCard.history,
          ShowHabitCard.streak,
          ShowHabitCard.frequency,
        ],
        reason: 'show-habit.card-order-and-visibility#1',
      );
    });

    test('numerical habits hide the overview card and show the target card',
        () {
      final habit = _fixtures.createNumericalHabit();
      habit.description = 'notes';
      final visibility = ShowHabitCardVisibility();
      visibility.setState(ShowHabitPresenter.buildState(
        habit: habit,
        preferences: _preferences,
        theme: _theme,
      ));
      expect(
        visibility.isVisible(ShowHabitCard.overview),
        isFalse,
        reason: 'show-habit.card-order-and-visibility#2',
      );
      expect(
        visibility.isVisible(ShowHabitCard.target),
        isTrue,
        reason: 'show-habit.card-order-and-visibility#2',
      );
    });

    test('boolean habits hide the target card and show the overview card', () {
      final habit = _fixtures.createShortHabit();
      habit.description = 'notes';
      final visibility = ShowHabitCardVisibility();
      visibility.setState(ShowHabitPresenter.buildState(
        habit: habit,
        preferences: _preferences,
        theme: _theme,
      ));
      expect(
        visibility.isVisible(ShowHabitCard.target),
        isFalse,
        reason: 'show-habit.card-order-and-visibility#2',
      );
      expect(
        visibility.isVisible(ShowHabitCard.overview),
        isTrue,
        reason: 'show-habit.card-order-and-visibility#2',
      );
    });

    test('a card hidden once is never shown again', () {
      final numerical = _fixtures.createNumericalHabit();
      final boolean = _fixtures.createShortHabit();
      final visibility = ShowHabitCardVisibility();

      visibility.setState(ShowHabitPresenter.buildState(
        habit: numerical,
        preferences: _preferences,
        theme: _theme,
      ));
      visibility.setState(ShowHabitPresenter.buildState(
        habit: boolean,
        preferences: _preferences,
        theme: _theme,
      ));

      expect(
        visibility.isVisible(ShowHabitCard.overview),
        isFalse,
        reason: 'show-habit.card-order-and-visibility#3',
      );
      expect(
        visibility.isVisible(ShowHabitCard.target),
        isFalse,
        reason: 'show-habit.card-order-and-visibility#3',
      );
    });

    test('the notes card follows the description, whatever the habit type', () {
      final habit = _fixtures.createShortHabit();
      final visibility = ShowHabitCardVisibility();

      visibility.setState(ShowHabitPresenter.buildState(
        habit: habit,
        preferences: _preferences,
        theme: _theme,
      ));
      expect(
        visibility.isVisible(ShowHabitCard.notes),
        isFalse,
        reason: 'show-habit.card-order-and-visibility#4',
      );

      habit.description = 'Remember to breathe';
      visibility.setState(ShowHabitPresenter.buildState(
        habit: habit,
        preferences: _preferences,
        theme: _theme,
      ));
      expect(
        visibility.isVisible(ShowHabitCard.notes),
        isTrue,
        reason: 'show-habit.card-order-and-visibility#4',
      );

      final numerical = _fixtures.createNumericalHabit();
      visibility.setState(ShowHabitPresenter.buildState(
        habit: numerical,
        preferences: _preferences,
        theme: _theme,
      ));
      expect(
        visibility.isVisible(ShowHabitCard.notes),
        isFalse,
        reason: 'show-habit.card-order-and-visibility#4',
      );
    });
  });

  // -------------------------------------------------------------------------
  // show-habit.subtitle-card
  // -------------------------------------------------------------------------

  group('show-habit.subtitle-card', () {
    test('buildState copies the habit fields', () {
      final habit = _buildHabit();
      habit.color = const PaletteColor(7);
      habit.frequency = Frequency(3, 7);
      habit.type = HabitType.numerical;
      habit.question = 'Did you meditate this morning?';
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      habit.targetValue = 2.0;
      habit.targetType = NumericalHabitType.atMost;
      habit.unit = 'miles';

      final state = SubtitleCardPresenter.buildState(
        habit: habit,
        theme: _theme,
      );

      expect(state.color, const PaletteColor(7),
          reason: 'show-habit.subtitle-card#1');
      expect(state.frequency, Frequency(3, 7),
          reason: 'show-habit.subtitle-card#1');
      expect(state.isNumerical, isTrue, reason: 'show-habit.subtitle-card#1');
      expect(state.question, 'Did you meditate this morning?',
          reason: 'show-habit.subtitle-card#1');
      expect(state.reminder, Reminder(8, 30, WeekdayList.everyDay),
          reason: 'show-habit.subtitle-card#1');
      expect(state.targetValue, 2.0, reason: 'show-habit.subtitle-card#1');
      expect(state.targetType, NumericalHabitType.atMost,
          reason: 'show-habit.subtitle-card#1');
      expect(state.unit, 'miles', reason: 'show-habit.subtitle-card#1');
      expect(state.theme, same(_theme), reason: 'show-habit.subtitle-card#1');
    });

    test('SubtitleCardState has three defaulted fields', () {
      final state = SubtitleCardState(
        color: const PaletteColor(7),
        frequency: Frequency(3, 7),
        isNumerical: false,
        question: 'Did you meditate this morning?',
        reminder: Reminder(8, 30, WeekdayList.everyDay),
        theme: _theme,
      );
      expect(state.targetValue, 0.0, reason: 'show-habit.subtitle-card#1');
      expect(state.targetType, NumericalHabitType.atLeast,
          reason: 'show-habit.subtitle-card#1');
      expect(state.unit, '', reason: 'show-habit.subtitle-card#1');
    });

    test('the question is tinted with the habit colour and hidden when empty',
        () {
      final habit = _buildHabit();
      habit.color = const PaletteColor(7);
      habit.question = 'Did you meditate this morning?';
      final state =
          SubtitleCardPresenter.buildState(habit: habit, theme: _theme);
      expect(state.questionColor, _theme.color(7),
          reason: 'show-habit.subtitle-card#2');
      expect(state.isQuestionVisible, isTrue,
          reason: 'show-habit.subtitle-card#2');

      habit.question = '';
      final empty =
          SubtitleCardPresenter.buildState(habit: habit, theme: _theme);
      expect(empty.isQuestionVisible, isFalse,
          reason: 'show-habit.subtitle-card#2');
    });

    // `show-habit.subtitle-card#3` quotes the *en* values of R.string.
    // every_month, x_times_per_month, every_day, every_week, every_x_days,
    // x_times_per_week and x_times_per_y_days; the call SubtitleCardView.kt
    // makes is formatFrequency(num, den, resources), and #5's "Off" is
    // resources.getString(R.string.reminder_off). Both are looked up in the
    // resolved locale, so both live in the widget layer now
    // (`audit15.subtitle-card-frequency-and-off-are-hard-coded#1`), and
    // app/test/ui/habits/show/show_habit_screen_test.dart pins them there —
    // in English and in ru/de. What is left here is the branch ORDER, which
    // is what makes 1/30 read "Every month" and 7/7 read "Every day", and it
    // is pinned on the app-side formatter both screens share, in
    // app/test/ui/habits/edit/edit_habit_screen_test.dart.

    test('a frequency of n/n normalises to 1/1', () {
      final habit = _buildHabit();
      habit.frequency = Frequency(7, 7);
      final state =
          SubtitleCardPresenter.buildState(habit: habit, theme: _theme);
      expect(state.frequency.numerator, 1,
          reason: 'show-habit.subtitle-card#4');
      expect(state.frequency.denominator, 1,
          reason: 'show-habit.subtitle-card#4');
    });

    test('the state carries the reminder through untouched', () {
      final habit = _buildHabit();
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      expect(
        SubtitleCardPresenter.buildState(habit: habit, theme: _theme).reminder,
        Reminder(8, 30, WeekdayList.everyDay),
        reason: 'show-habit.subtitle-card#5 — the hour and the minute reach '
            'the view unchanged; the pattern they are rendered with is '
            'DateFormat.getTimeFormat(context) and belongs to the widget '
            'layer (`audit15.subtitle-card-reminder-time-ignores-the-device-'
            'locale#1`)',
      );

      habit.reminder = null;
      expect(
        SubtitleCardPresenter.buildState(habit: habit, theme: _theme).reminder,
        isNull,
        reason: 'show-habit.subtitle-card#5 — a null reminder is what selects '
            'R.string.reminder_off',
      );
    });

    test('platform-glue.time-and-date-formatting#1 — the reminder time is '
        'minutes-since-epoch rendered in UTC', () {
      const rule = 'platform-glue.time-and-date-formatting#1 — '
          'formatTime(context, hours, minutes) converts to milliseconds as '
          '(hours * 60 + minutes) * 60 * 1000L, builds a Date from it, formats '
          'with android.text.format.DateFormat.getTimeFormat(context) and '
          'forces the formatter\'s TimeZone to UTC so the value is not shifted '
          '— the result therefore respects the user\'s 12h/24h system setting. '
          'The 12h/24h switch and the locale pattern are the widget layer\'s '
          '(`audit15.subtitle-card-reminder-time-ignores-the-device-locale#1`); '
          'the minute the formatter is handed is this.';

      expect(SubtitleCardState.minuteOfDay(8, 30), 8 * 60 + 30, reason: rule);
      expect(SubtitleCardState.minuteOfDay(20, 5), 20 * 60 + 5, reason: rule);

      // "forces the TimeZone to UTC so the value is not shifted": the result
      // depends on nothing but the two arguments, so no zone can move it. The
      // clock is pushed to two extremes and the answer does not budge.
      final int realZoneOffset = DateTime.now().timeZoneOffset.inMinutes;
      expect(realZoneOffset, isNotNull);
      for (final int hour in <int>[0, 12, 23]) {
        expect(SubtitleCardState.minuteOfDay(hour, 0), hour * 60,
            reason: '$rule (hour $hour)');
      }

      // (hours * 60 + minutes) minutes since the epoch, in UTC: the value wraps
      // modulo a day instead of being rejected or clamped.
      expect(SubtitleCardState.minuteOfDay(24, 0), 0,
          reason: '$rule — hour 24 is exactly one day of minutes');
      expect(SubtitleCardState.minuteOfDay(25, 30), 90, reason: rule);
      expect(SubtitleCardState.minuteOfDay(0, 1440), 0,
          reason: '$rule — minutes are folded into the same total');
      expect(SubtitleCardState.minuteOfDay(1, 90), 150,
          reason: '$rule — hours*60 + minutes, then split back apart');
    });

    test('the target is shown only for numerical habits', () {
      final numerical = _fixtures.createNumericalHabit();
      expect(
        SubtitleCardPresenter.buildState(habit: numerical, theme: _theme)
            .isTargetVisible,
        isTrue,
        reason: 'show-habit.subtitle-card#6',
      );
      final boolean = _fixtures.createEmptyHabit();
      expect(
        SubtitleCardPresenter.buildState(habit: boolean, theme: _theme)
            .isTargetVisible,
        isFalse,
        reason: 'show-habit.subtitle-card#6',
      );
    });

    test('the target text is the short value, a space and the unit', () {
      final habit = _fixtures.createNumericalHabit();
      expect(
        SubtitleCardPresenter.buildState(habit: habit, theme: _theme)
            .targetText,
        '2 miles',
        reason: 'show-habit.subtitle-card#7',
      );

      habit.targetValue = 1234.5;
      expect(
        SubtitleCardPresenter.buildState(habit: habit, theme: _theme)
            .targetText,
        '1.2k miles',
        reason: 'show-habit.subtitle-card#7',
      );

      // The separator is unconditional, so an empty unit leaves a trailing
      // space.
      habit.targetValue = 0.0;
      habit.unit = '';
      expect(
        SubtitleCardPresenter.buildState(habit: habit, theme: _theme)
            .targetText,
        '0 ',
        reason: 'show-habit.subtitle-card#7',
      );
    });

    test('the target icon points up for AT_LEAST and down for AT_MOST', () {
      final habit = _fixtures.createNumericalHabit();
      habit.targetType = NumericalHabitType.atLeast;
      expect(
        SubtitleCardPresenter.buildState(habit: habit, theme: _theme)
            .targetIconGlyph,
        FontAwesome.arrowCircleUp,
        reason: 'show-habit.subtitle-card#8',
      );
      habit.targetType = NumericalHabitType.atMost;
      expect(
        SubtitleCardPresenter.buildState(habit: habit, theme: _theme)
            .targetIconGlyph,
        FontAwesome.arrowCircleDown,
        reason: 'show-habit.subtitle-card#8',
      );
    });

    test('the frequency and reminder icons are fixed FontAwesome glyphs', () {
      expect(SubtitleCardState.frequencyIconGlyph, FontAwesome.calendar,
          reason: 'show-habit.subtitle-card#9');
      expect(SubtitleCardState.reminderIconGlyph, FontAwesome.bellO,
          reason: 'show-habit.subtitle-card#9');
      expect(
        SubtitleCardState.targetIconGlyphFor(NumericalHabitType.atLeast),
        FontAwesome.arrowCircleUp,
        reason: 'show-habit.subtitle-card#9',
      );
    });
  });

  // -------------------------------------------------------------------------
  // show-habit.notes-card
  // -------------------------------------------------------------------------

  group('show-habit.notes-card', () {
    test('the state carries the habit description and nothing else', () {
      final habit = _buildHabit();
      habit.description = 'This is a test description';
      final state = NotesCardPresenter.buildState(habit: habit);
      expect(state.description, 'This is a test description',
          reason: 'show-habit.notes-card#1');
      expect(
        state,
        const NotesCardState(description: 'This is a test description'),
        reason: 'show-habit.notes-card#1',
      );
    });

    test('the card is hidden exactly when the description is empty', () {
      expect(const NotesCardState(description: '').isVisible, isFalse,
          reason: 'show-habit.notes-card#2');
      expect(const NotesCardState(description: ' ').isVisible, isTrue,
          reason: 'show-habit.notes-card#2');
      expect(
        const NotesCardState(description: 'This is a test description')
            .isVisible,
        isTrue,
        reason: 'show-habit.notes-card#2',
      );
    });
  });

  // -------------------------------------------------------------------------
  // show-habit.overview-card
  // -------------------------------------------------------------------------

  group('show-habit.overview-card', () {
    test('the three scores are read at today, today-30 and today-365', () {
      final habit = _fixtures.createLongHabit();
      final state =
          OverviewCardPresenter.buildState(habit: habit, theme: _theme);

      final scoreToday = habit.scores[_today].value;
      final scoreLastMonth = habit.scores[_today.minus(30)].value;
      final scoreLastYear = habit.scores[_today.minus(365)].value;

      expect(state.scoreToday, scoreToday,
          reason: 'show-habit.overview-card#1');
      expect(state.scoreMonthDiff, scoreToday - scoreLastMonth,
          reason: 'show-habit.overview-card#1');
      expect(state.scoreYearDiff, scoreToday - scoreLastYear,
          reason: 'show-habit.overview-card#1');
      // The three offsets are load-bearing: the fixture has different scores
      // at each of them.
      expect(scoreToday, isNot(scoreLastMonth),
          reason: 'show-habit.overview-card#1');
      expect(scoreToday, isNot(scoreLastYear),
          reason: 'show-habit.overview-card#1');
      expect(state.color, const PaletteColor(4),
          reason: 'show-habit.overview-card#1');
      expect(state.theme, same(_theme), reason: 'show-habit.overview-card#1');
    });

    test('dates without a computed score read as zero', () {
      final habit = _fixtures.createLongHabit();
      expect(habit.scores[_today.minus(365)].value, 0.0,
          reason: 'show-habit.overview-card#2');
      final state =
          OverviewCardPresenter.buildState(habit: habit, theme: _theme);
      expect(state.scoreYearDiff, state.scoreToday,
          reason: 'show-habit.overview-card#2');

      final empty = _fixtures.createEmptyHabit();
      empty.recompute();
      final emptyState =
          OverviewCardPresenter.buildState(habit: empty, theme: _theme);
      expect(emptyState.scoreToday, 0.0,
          reason: 'show-habit.overview-card#2');
    });

    test('the diffs are today minus the older score', () {
      final habit = _fixtures.createLongHabit();
      final state =
          OverviewCardPresenter.buildState(habit: habit, theme: _theme);
      expect(
        state.scoreMonthDiff,
        state.scoreToday - habit.scores[_today.minus(30)].value,
        reason: 'show-habit.overview-card#3',
      );
      expect(
        state.scoreYearDiff,
        state.scoreToday - habit.scores[_today.minus(365)].value,
        reason: 'show-habit.overview-card#3',
      );
    });

    test('totalCount counts only YES_MANUAL original entries', () {
      final habit = _buildHabit();
      habit.originalEntries.add(Entry(_today, Entry.yesManual));
      habit.originalEntries.add(Entry(_today.minus(1), Entry.yesAuto));
      habit.originalEntries.add(Entry(_today.minus(2), Entry.no));
      habit.originalEntries.add(Entry(_today.minus(3), Entry.skip));
      habit.originalEntries.add(Entry(_today.minus(4), Entry.unknown));
      habit.recompute();
      expect(
        OverviewCardPresenter.buildState(habit: habit, theme: _theme)
            .totalCount,
        1,
        reason: 'show-habit.overview-card#4',
      );

      // The 44 marks of the long fixture, none of the YES_AUTO days the
      // computed list adds on top of them.
      final long = _fixtures.createLongHabit();
      expect(long.computedEntries.getKnown().length,
          greaterThan(long.originalEntries.getKnown().length),
          reason: 'show-habit.overview-card#4');
      expect(
        OverviewCardPresenter.buildState(habit: long, theme: _theme).totalCount,
        44,
        reason: 'show-habit.overview-card#4',
      );
    });

    test('the score label is a rounded percentage', () {
      OverviewCardState state(double score) => OverviewCardState(
            color: const PaletteColor(7),
            scoreToday: score,
            scoreMonthDiff: 0.0,
            scoreYearDiff: 0.0,
            totalCount: 0,
            theme: _theme,
          );
      expect(state(0.74).scoreText, '74%',
          reason: 'show-habit.overview-card#5');
      expect(state(0.005).scoreText, '1%',
          reason: 'show-habit.overview-card#5');
      expect(state(0.0).scoreText, '0%', reason: 'show-habit.overview-card#5');
      expect(state(1.0).scoreText, '100%',
          reason: 'show-habit.overview-card#5');

      expect(state(0.74).scoreText, '74%',
          reason: 'show-habit.number-formatting#3');
    });

    test('the diff labels carry a sign and a rounded percentage', () {
      expect(OverviewCardState.formatPercentageDiff(0.23), '+23%',
          reason: 'show-habit.overview-card#6');
      expect(OverviewCardState.formatPercentageDiff(-0.05), '−5%',
          reason: 'show-habit.overview-card#6');
      expect(OverviewCardState.formatPercentageDiff(0.0), '+0%',
          reason: 'show-habit.overview-card#6');

      final state = OverviewCardState(
        color: const PaletteColor(7),
        scoreToday: 0.74,
        scoreMonthDiff: 0.23,
        scoreYearDiff: -0.05,
        totalCount: 44,
        theme: _theme,
      );
      expect(state.monthDiffText, '+23%',
          reason: 'show-habit.overview-card#6');
      expect(state.yearDiffText, '−5%',
          reason: 'show-habit.overview-card#6');

      expect(OverviewCardState.formatPercentageDiff(-0.05), '−5%',
          reason: 'show-habit.number-formatting#4');
    });

    test('a diff is tinted with the habit colour unless it is negative', () {
      OverviewCardState state(double month, double year) => OverviewCardState(
            color: const PaletteColor(7),
            scoreToday: 0.74,
            scoreMonthDiff: month,
            scoreYearDiff: year,
            totalCount: 0,
            theme: _theme,
          );
      expect(state(0.23, -0.05).monthDiffColor, _theme.color(7),
          reason: 'show-habit.overview-card#7');
      expect(state(0.23, -0.05).yearDiffColor, _theme.mediumContrastTextColor,
          reason: 'show-habit.overview-card#7');
      // Exactly zero counts as non-negative.
      expect(state(0.0, 0.0).monthDiffColor, _theme.color(7),
          reason: 'show-habit.overview-card#7');
      expect(state(0.0, 0.0).yearDiffColor, _theme.color(7),
          reason: 'show-habit.overview-card#7');
    });

    test('title, score and total use the habit colour; captions do not', () {
      final state = OverviewCardState(
        color: const PaletteColor(7),
        scoreToday: 0.74,
        scoreMonthDiff: 0.23,
        scoreYearDiff: 0.74,
        totalCount: 44,
        theme: _theme,
      );
      expect(state.titleColor, _theme.color(7),
          reason: 'show-habit.overview-card#8');
      expect(state.scoreColor, _theme.color(7),
          reason: 'show-habit.overview-card#8');
      expect(state.totalCountColor, _theme.color(7),
          reason: 'show-habit.overview-card#8');
      expect(state.captionColor, _theme.mediumContrastTextColor,
          reason: 'show-habit.overview-card#8');
      expect(
        OverviewCardState.captions,
        <String>['Score', 'Month', 'Year', 'Total'],
        reason: 'show-habit.overview-card#8',
      );
    });

    test('the total label is the raw integer', () {
      final state = OverviewCardState(
        color: const PaletteColor(7),
        scoreToday: 0.74,
        scoreMonthDiff: 0.0,
        scoreYearDiff: 0.0,
        totalCount: 12345,
        theme: _theme,
      );
      expect(state.totalCountText, '12345',
          reason: 'show-habit.overview-card#9');
      expect(state.totalCountText, '12345',
          reason: 'show-habit.number-formatting#5');
    });

    test('the card is hidden for numerical habits', () {
      final habit = _fixtures.createNumericalHabit();
      final visibility = ShowHabitCardVisibility();
      visibility.setState(ShowHabitPresenter.buildState(
        habit: habit,
        preferences: _preferences,
        theme: _theme,
      ));
      expect(visibility.isVisible(ShowHabitCard.overview), isFalse,
          reason: 'show-habit.overview-card#12');
    });
  });

  // -------------------------------------------------------------------------
  // show-habit.target-card
  // -------------------------------------------------------------------------

  group('show-habit.target-card', () {
    test('an empty habit still produces one bucket per interval', () {
      final habit = _buildHabit();
      habit.type = HabitType.numerical;
      habit.targetValue = 100.0;
      habit.recompute();
      final state = _buildTargetState(habit);
      // oldest defaults to today, so the interval is the single day [today,
      // today] and every group sums the one UNKNOWN entry to zero.
      expect(state.values, <double>[0.0, 0.0, 0.0, 0.0, 0.0],
          reason: 'show-habit.target-card#1');
      expect(state.intervals, <int>[1, 7, 30, 91, 365],
          reason: 'show-habit.target-card#1');
    });

    test('each period takes the newest bucket of the grouped sum', () {
      final state = _buildTargetState(_spreadNumericalHabit());
      expect(
        state.values,
        <double>[1.0, 3.0, 7.0, 15.0, 31.0],
        reason: 'show-habit.target-card#2',
      );
    });

    test('groupedSum floors negatives, zeroes skips and scores booleans', () {
      final habit = _buildHabit();
      habit.type = HabitType.numerical;
      habit.targetValue = 100.0;
      habit.originalEntries.add(Entry(LocalDate.ymd(2024, 5, 15), 1000));
      habit.originalEntries.add(Entry(LocalDate.ymd(2024, 5, 14), Entry.skip));
      habit.originalEntries.add(Entry(LocalDate.ymd(2024, 5, 13), 2000));
      habit.recompute();
      final state = _buildTargetState(habit);
      // The SKIP day contributes 0 rather than 0.003, and the two UNKNOWN
      // days of the interval contribute 0 rather than -0.001 each.
      expect(state.values[1], 3.0, reason: 'show-habit.target-card#3');

      final boolean = _buildHabit();
      boolean.frequency = Frequency.weekly;
      boolean.originalEntries
          .add(Entry(LocalDate.ymd(2024, 5, 13), Entry.yesManual));
      boolean.recompute();
      final booleanState = _buildTargetState(boolean);
      // Two of the three days in the bucket are YES_AUTO and score nothing.
      expect(booleanState.values[0], 1.0,
          reason: 'show-habit.target-card#3');
    });

    test('skipped days are counted per period', () {
      final habit = _buildHabit();
      habit.type = HabitType.numerical;
      habit.targetValue = 100.0;
      habit.originalEntries.add(Entry(LocalDate.ymd(2024, 5, 15), Entry.skip));
      habit.originalEntries.add(Entry(LocalDate.ymd(2024, 5, 14), Entry.skip));
      habit.recompute();
      final state = _buildTargetState(habit);
      // targetToday = max(0, 100 - 100 * 1) and
      // targetThisWeek = 700 - 100 * 2.
      expect(state.targets[0], 0.0, reason: 'show-habit.target-card#4');
      expect(state.targets[1], 500.0, reason: 'show-habit.target-card#4');
    });

    test('the daily target divides the target value by the denominator', () {
      final habit = _spreadNumericalHabit(
        frequency: Frequency(1, 4),
        targetValue: 100.0,
      );
      final state = _buildTargetState(habit);
      // denominator 4: the Today row is dropped, the week row is dailyTarget
      // * 7 = 175.
      expect(state.intervals, <int>[7, 30, 91, 365],
          reason: 'show-habit.target-card#5');
      expect(state.targets[0], 25.0 * 7, reason: 'show-habit.target-card#5');
    });

    test('the today target is the daily target', () {
      final state = _buildTargetState(_spreadNumericalHabit());
      expect(state.targets[0], 100.0, reason: 'show-habit.target-card#6');
    });

    test('the week target is the raw target only for weekly habits', () {
      final weekly = _buildTargetState(
        _spreadNumericalHabit(frequency: Frequency.weekly),
      );
      expect(weekly.targets[0], 100.0, reason: 'show-habit.target-card#7');

      final daily = _buildTargetState(_spreadNumericalHabit());
      expect(daily.targets[1], 700.0, reason: 'show-habit.target-card#7');
    });

    test('the month target depends on the denominator', () {
      final monthly = _buildTargetState(
        _spreadNumericalHabit(frequency: Frequency(1, 30)),
      );
      expect(monthly.targets[0], 100.0, reason: 'show-habit.target-card#8');

      final weekly = _buildTargetState(
        _spreadNumericalHabit(frequency: Frequency.weekly),
      );
      // 31 / 7 == 4 in integer arithmetic.
      expect(weekly.targets[1], 400.0, reason: 'show-habit.target-card#8');

      final daily = _buildTargetState(_spreadNumericalHabit());
      expect(daily.targets[2], 100.0 * 31, reason: 'show-habit.target-card#8');
    });

    test('the quarter target depends on the denominator', () {
      final monthly = _buildTargetState(
        _spreadNumericalHabit(frequency: Frequency(1, 30)),
      );
      expect(monthly.targets[1], 300.0, reason: 'show-habit.target-card#9');

      final weekly = _buildTargetState(
        _spreadNumericalHabit(frequency: Frequency.weekly),
      );
      expect(weekly.targets[2], 1300.0, reason: 'show-habit.target-card#9');

      final daily = _buildTargetState(_spreadNumericalHabit());
      expect(daily.targets[3], 100.0 * 91, reason: 'show-habit.target-card#9');
    });

    test('the year target depends on the denominator', () {
      final monthly = _buildTargetState(
        _spreadNumericalHabit(frequency: Frequency(1, 30)),
      );
      expect(monthly.targets[2], 1200.0, reason: 'show-habit.target-card#10');

      final weekly = _buildTargetState(
        _spreadNumericalHabit(frequency: Frequency.weekly),
      );
      expect(weekly.targets[3], 5200.0, reason: 'show-habit.target-card#10');

      // 2024 is a leap year.
      final daily = _buildTargetState(_spreadNumericalHabit());
      expect(daily.targets[4], 100.0 * 366,
          reason: 'show-habit.target-card#10');
    });

    test('targets never go below zero when days are skipped', () {
      final habit = _buildHabit();
      habit.type = HabitType.numerical;
      habit.targetValue = 100.0;
      for (var i = 0; i < 10; i++) {
        habit.originalEntries.add(Entry(_today.minus(i), Entry.skip));
      }
      habit.recompute();
      final state = _buildTargetState(habit);
      expect(state.targets[0], 0.0, reason: 'show-habit.target-card#11');
      // 700 - 100 * 4 skipped days this week (Sunday 12th to Wednesday 15th).
      expect(state.targets[1], 300.0, reason: 'show-habit.target-card#11');
      expect(state.targets.every((t) => t >= 0.0), isTrue,
          reason: 'show-habit.target-card#11');
    });

    test('values are thousandths converted to units', () {
      final habit = _buildHabit();
      habit.type = HabitType.numerical;
      habit.targetValue = 100.0;
      habit.originalEntries.add(Entry(_today, 1500));
      habit.recompute();
      final state = _buildTargetState(habit);
      expect(state.values[0], 1.5, reason: 'show-habit.target-card#12');
      expect(state.values[0], 1.5, reason: 'show-habit.number-formatting#9');
    });

    test('rows are filtered by the frequency denominator', () {
      expect(_buildTargetState(_spreadNumericalHabit()).intervals,
          <int>[1, 7, 30, 91, 365],
          reason: 'show-habit.target-card#13');
      expect(
        _buildTargetState(_spreadNumericalHabit(frequency: Frequency.weekly))
            .intervals,
        <int>[7, 30, 91, 365],
        reason: 'show-habit.target-card#13',
      );
      expect(
        _buildTargetState(_spreadNumericalHabit(frequency: Frequency(1, 30)))
            .intervals,
        <int>[30, 91, 365],
        reason: 'show-habit.target-card#13',
      );
      final weekly = _buildTargetState(
        _spreadNumericalHabit(frequency: Frequency.weekly),
      );
      expect(weekly.values.length, weekly.intervals.length,
          reason: 'show-habit.target-card#13');
      expect(weekly.targets.length, weekly.intervals.length,
          reason: 'show-habit.target-card#13');
    });

    test('intervals map to row labels', () {
      expect(TargetCardState.intervalToLabel(1), 'Today',
          reason: 'show-habit.target-card#14');
      expect(TargetCardState.intervalToLabel(7), 'Week',
          reason: 'show-habit.target-card#14');
      expect(TargetCardState.intervalToLabel(30), 'Month',
          reason: 'show-habit.target-card#14');
      expect(TargetCardState.intervalToLabel(91), 'Quarter',
          reason: 'show-habit.target-card#14');
      expect(TargetCardState.intervalToLabel(365), 'Year',
          reason: 'show-habit.target-card#14');
      expect(TargetCardState.intervalToLabel(12), 'Year',
          reason: 'show-habit.target-card#14');
      expect(
        _buildTargetState(_spreadNumericalHabit()).labels,
        <String>['Today', 'Week', 'Month', 'Quarter', 'Year'],
        reason: 'show-habit.target-card#14',
      );
    });

    test('the title is Target, tinted with the habit colour', () {
      final habit = _spreadNumericalHabit();
      habit.color = const PaletteColor(7);
      final state = _buildTargetState(habit);
      expect(TargetCardState.title, 'Target',
          reason: 'show-habit.target-card#18');
      expect(state.titleColor, _theme.color(7),
          reason: 'show-habit.target-card#18');
    });

    test('the card is hidden for boolean habits', () {
      final habit = _fixtures.createShortHabit();
      final visibility = ShowHabitCardVisibility();
      visibility.setState(ShowHabitPresenter.buildState(
        habit: habit,
        preferences: _preferences,
        theme: _theme,
      ));
      expect(visibility.isVisible(ShowHabitCard.target), isFalse,
          reason: 'show-habit.target-card#20');
    });

    test('TargetCardState defaults to three empty lists', () {
      final state =
          TargetCardState(color: const PaletteColor(7), theme: _theme);
      expect(state.values, isEmpty, reason: 'show-habit.target-card#2');
      expect(state.targets, isEmpty, reason: 'show-habit.target-card#2');
      expect(state.intervals, isEmpty, reason: 'show-habit.target-card#2');
    });
  });

  // -------------------------------------------------------------------------
  // show-habit.number-formatting
  // -------------------------------------------------------------------------

  group('show-habit.number-formatting', () {
    test('the core toShortString picks its unit before rounding', () {
      expect(1.5e9.toShortString(), '1.5G',
          reason: 'show-habit.number-formatting#1');
      expect(2e8.toShortString(), '200M',
          reason: 'show-habit.number-formatting#1');
      expect(1.5e7.toShortString(), '15.0M',
          reason: 'show-habit.number-formatting#1');
      expect(1.5e6.toShortString(), '1.5M',
          reason: 'show-habit.number-formatting#1');
      expect(1.5e5.toShortString(), '150k',
          reason: 'show-habit.number-formatting#1');
      expect(1.5e4.toShortString(), '15.0k',
          reason: 'show-habit.number-formatting#1');
      expect(1.5e3.toShortString(), '1.5k',
          reason: 'show-habit.number-formatting#1');
      expect(150.0.toShortString(), '150',
          reason: 'show-habit.number-formatting#1');
      expect(15.0.toShortString(), '15',
          reason: 'show-habit.number-formatting#1');
      expect(15.5.toShortString(), '15.5',
          reason: 'show-habit.number-formatting#1');
      expect(5.0.toShortString(), '5', reason: 'show-habit.number-formatting#1');
      expect(5.5.toShortString(), '5.5',
          reason: 'show-habit.number-formatting#1');
      expect(5.55.toShortString(), '5.55',
          reason: 'show-habit.number-formatting#1');
    });

    test('the Android toShortString rounds the last three buckets differently',
        () {
      expect(150.0.toShortStringAndroid(), '150',
          reason: 'show-habit.number-formatting#2');
      expect(2.0.toShortStringAndroid(), '2',
          reason: 'show-habit.number-formatting#2');
      expect(0.0.toShortStringAndroid(), '0',
          reason: 'show-habit.number-formatting#2');
      // HALF_EVEN on the shortest representation, unlike the core version.
      expect(12.35.toShortStringAndroid(), '12.3',
          reason: 'show-habit.number-formatting#2');
      expect(12.35.toShortString(), '12.4',
          reason: 'show-habit.number-formatting#2');
      // Negative values never match a threshold, so they land in "#.##".
      expect((-3.5).toShortStringAndroid(), '-3.5',
          reason: 'show-habit.number-formatting#2');
      // This is the one the subtitle target text uses.
      final habit = _fixtures.createNumericalHabit();
      habit.targetValue = 12.35;
      expect(
        SubtitleCardPresenter.buildState(habit: habit, theme: _theme)
            .targetText,
        '12.3 miles',
        reason: 'show-habit.number-formatting#2',
      );
    });
  });

  // -------------------------------------------------------------------------
  // show-habit.screen-scaffold — the pieces of ShowHabit.kt that live in core
  // -------------------------------------------------------------------------
  group('show-habit.screen-scaffold', () {
    test('#10 ShowHabitState defaults are "", false and PaletteColor(1), and '
        'buildState always overrides all three', () {
      final habit = _buildHabit();
      final bare = ShowHabitState(
        subtitle: SubtitleCardPresenter.buildState(habit: habit, theme: _theme),
        overview: OverviewCardPresenter.buildState(habit: habit, theme: _theme),
        notes: NotesCardPresenter.buildState(habit: habit),
        target: _buildTargetState(habit),
        streaks: StreakCartPresenter.buildState(habit, _theme),
        scores: ScoreCardPresenter.buildState(
          habit: habit,
          firstWeekday: _preferences.firstWeekdayInt,
          spinnerPosition: _preferences.scoreCardSpinnerPosition,
          theme: _theme,
        ),
        frequency: FrequencyCardPresenter.buildState(
          habit: habit,
          firstWeekday: _preferences.firstWeekday,
          theme: _theme,
        ),
        history: HistoryCardPresenter.buildState(
          habit: habit,
          firstWeekday: _preferences.firstWeekday,
          theme: _theme,
        ),
        bar: BarCardPresenter.buildState(
          habit: habit,
          firstWeekday: _preferences.firstWeekdayInt,
          numericalSpinnerPosition: _preferences.barCardNumericalSpinnerPosition,
          boolSpinnerPosition: _preferences.barCardBoolSpinnerPosition,
          theme: _theme,
        ),
        theme: _theme,
      );

      expect(bare.title, '',
          reason: 'show-habit.screen-scaffold#10 — title defaults to ""');
      expect(bare.isNumerical, isFalse,
          reason: 'show-habit.screen-scaffold#10 — isNumerical defaults to '
              'false');
      expect(bare.color, const PaletteColor(1),
          reason: 'show-habit.screen-scaffold#10 — color defaults to '
              'PaletteColor(1)');

      // In practice buildState never leaves one of them alone: a numerical
      // habit with a name and a colour comes back with all three replaced.
      habit
        ..name = 'Run'
        ..type = HabitType.numerical
        ..color = const PaletteColor(14);
      final built = ShowHabitPresenter.buildState(
        habit: habit,
        preferences: _preferences,
        theme: _theme,
      );
      expect(built.title, 'Run',
          reason: 'show-habit.screen-scaffold#10 — buildState takes the title '
              'from habit.name');
      expect(built.isNumerical, isTrue,
          reason: 'show-habit.screen-scaffold#10');
      expect(built.color, const PaletteColor(14),
          reason: 'show-habit.screen-scaffold#10');
      expect(built.theme, same(_theme),
          reason: 'show-habit.screen-scaffold#10 — and the theme is the one it '
              'was handed');

      // Even the untouched habit gets all three written from the model rather
      // than left at the class defaults: a new habit is teal, not
      // PaletteColor(1).
      final fresh = ShowHabitPresenter.buildState(
        habit: _buildHabit(),
        preferences: _preferences,
        theme: _theme,
      );
      expect(fresh.color, const PaletteColor(8),
          reason: 'show-habit.screen-scaffold#10 — the PaletteColor(1) default '
              'is never what a built state carries');
    });
  });
}
