/// Ported from the five presenters under
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/:
/// ScoreCard.kt, BarCard.kt, HistoryCard.kt, StreakCart.kt (sic) and
/// FrequencyCard.kt.
///
/// The Kotlin tests cited by the ledger
/// (uhabits-android/src/androidTest/.../show/views/{ScoreCard,HistoryCard,
/// StreakCard,FrequencyCard}ViewTest.kt) are golden-image tests: they call
/// `buildState(...)` and then diff a rendered PNG. There is no Android view
/// layer and no raster backend here, so the *state* those tests feed into the
/// views is asserted directly instead, which is the whole of the presenter
/// contract. Rules that describe the Android chart views (ScoreChart,
/// StreakChart, FrequencyChart), the card XML or the spinner widgets are left
/// to the widget layer and are reported as blocked.
///
/// Every `expect` carries the parity-ledger rule id it exercises.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/gui/theme.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/models/score.dart';
import 'package:uhabits_core/src/models/streak.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/bar_card.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/frequency_card.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/history_card.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/score_card.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/streak_card.dart';
import 'package:uhabits_core/src/ui/views/history_chart.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// 2015-01-25, a Sunday — the same reference day the ported chart tests use.
final LocalDate today = LocalDate.ymd(2015, 1, 25);

Habit buildHabit({
  HabitType type = HabitType.yesNo,
  Frequency frequency = Frequency.daily,
  NumericalHabitType targetType = NumericalHabitType.atLeast,
  double targetValue = 2.0,
  PaletteColor color = const PaletteColor(4),
  List<Entry> entries = const <Entry>[],
}) {
  final habit = MemoryModelFactory().buildHabit();
  habit.type = type;
  habit.frequency = frequency;
  habit.targetType = targetType;
  habit.targetValue = targetValue;
  habit.color = color;
  for (final entry in entries) {
    habit.originalEntries.add(entry);
  }
  habit.recompute();
  return habit;
}

/// Two manual checkmarks 40 days apart, so the oldest known computed entry is
/// 2014-12-16 and every bucket size produces a different grouping.
Habit scoreFixture() => buildHabit(entries: <Entry>[
      Entry(today, Entry.yesManual),
      Entry(today.minus(40), Entry.yesManual),
    ]);

/// Kotlin `List<Double>.average()`.
double mean(Iterable<double> values) {
  final list = values.toList();
  return list.reduce((a, b) => a + b) / list.length;
}

Preferences memoryPreferences([MemoryStorage? storage]) =>
    Preferences(storage ?? MemoryStorage());

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Records the call order of the two `Screen` methods and, at each call, the
/// preference value visible at that instant — which is how the "preference is
/// written first" half of the rules is pinned.
class _FakeCardScreen implements ScoreCardScreen, BarCardScreen {
  _FakeCardScreen(this.readPreference);

  final int Function() readPreference;

  final List<String> log = <String>[];
  final List<int> observed = <int>[];

  @override
  void updateWidgets() {
    log.add('updateWidgets');
    observed.add(readPreference());
  }

  @override
  void refresh() {
    log.add('refresh');
    observed.add(readPreference());
  }
}

void main() {
  setUp(() => setToday(today));
  tearDown(resetToday);

  // -------------------------------------------------------------------------
  // show-habit.score-card
  // -------------------------------------------------------------------------
  group('show-habit.score-card', () {
    test('#1 BUCKET_SIZES is [1, 7, 31, 92, 365] indexed by spinner position',
        () {
      expect(ScoreCardPresenter.bucketSizes, <int>[1, 7, 31, 92, 365],
          reason: 'show-habit.score-card#1');
      expect(ScoreCardPresenter.bucketSizes.length, 5,
          reason: 'show-habit.score-card#1');
      for (var position = 0; position <= 4; position++) {
        final state = ScoreCardPresenter.buildState(
          habit: scoreFixture(),
          firstWeekday: 1,
          spinnerPosition: position,
          theme: LightTheme(),
        );
        expect(state.bucketSize, ScoreCardPresenter.bucketSizes[position],
            reason: 'show-habit.score-card#1');
        expect(state.spinnerPosition, position,
            reason: 'show-habit.score-card#1');
      }
    });

    test('#2 spinner position persists in pref_score_view_interval, default 1',
        () {
      final storage = MemoryStorage();
      final prefs = memoryPreferences(storage);

      expect(prefs.scoreCardSpinnerPosition, 1,
          reason: 'show-habit.score-card#2');

      storage.putInt('pref_score_view_interval', 3);
      expect(prefs.scoreCardSpinnerPosition, 3,
          reason: 'show-habit.score-card#2');

      prefs.scoreCardSpinnerPosition = 9;
      expect(storage.getInt('pref_score_view_interval', -1), 9,
          reason: 'show-habit.score-card#2');
      expect(prefs.scoreCardSpinnerPosition, 4,
          reason: 'show-habit.score-card#2');

      prefs.scoreCardSpinnerPosition = -5;
      expect(prefs.scoreCardSpinnerPosition, 0,
          reason: 'show-habit.score-card#2');
    });

    test('#3 getTruncateField maps each bucket size, others to MONTH', () {
      expect(ScoreCardPresenter.getTruncateField(1), TruncateField.day,
          reason: 'show-habit.score-card#3');
      expect(ScoreCardPresenter.getTruncateField(7), TruncateField.weekNumber,
          reason: 'show-habit.score-card#3');
      expect(ScoreCardPresenter.getTruncateField(31), TruncateField.month,
          reason: 'show-habit.score-card#3');
      expect(ScoreCardPresenter.getTruncateField(92), TruncateField.quarter,
          reason: 'show-habit.score-card#3');
      expect(ScoreCardPresenter.getTruncateField(365), TruncateField.year,
          reason: 'show-habit.score-card#3');
      expect(ScoreCardPresenter.getTruncateField(0), TruncateField.month,
          reason: 'show-habit.score-card#3');
      expect(ScoreCardPresenter.getTruncateField(30), TruncateField.month,
          reason: 'show-habit.score-card#3');
      expect(ScoreCardPresenter.getTruncateField(-1), TruncateField.month,
          reason: 'show-habit.score-card#3');
    });

    test('#4 scores are the daily scores grouped and averaged, newest first',
        () {
      final habit = scoreFixture();
      final oldest = LocalDate.ymd(2014, 12, 16);
      final daily = habit.scores.getByInterval(oldest, today);
      final theme = LightTheme();

      // Bucket size 1: every group holds a single day, so the state is the raw
      // daily series, newest first.
      final byDay = ScoreCardPresenter.buildState(
        habit: habit,
        firstWeekday: 1,
        spinnerPosition: 0,
        theme: theme,
      );
      expect(byDay.scores.length, daily.length,
          reason: 'show-habit.score-card#4');
      expect(byDay.scores.map((Score s) => s.date).toList(),
          daily.map((Score s) => s.date).toList(),
          reason: 'show-habit.score-card#4');
      expect(byDay.scores.map((Score s) => s.value).toList(),
          daily.map((Score s) => s.value).toList(),
          reason: 'show-habit.score-card#4');
      expect(byDay.scores.first.date, today,
          reason: 'show-habit.score-card#4');
      expect(byDay.scores.last.date, oldest, reason: 'show-habit.score-card#4');
      expect(byDay.color, const PaletteColor(4),
          reason: 'show-habit.score-card#4');
      expect(identical(byDay.theme, theme), isTrue,
          reason: 'show-habit.score-card#4');

      // Bucket size 31: two groups, each the arithmetic mean of its days,
      // newest bucket first.
      final byMonth = ScoreCardPresenter.buildState(
        habit: habit,
        firstWeekday: 1,
        spinnerPosition: 2,
        theme: theme,
      );
      final january = LocalDate.ymd(2015, 1, 1);
      expect(byMonth.scores.length, 2, reason: 'show-habit.score-card#4');
      expect(byMonth.scores[0].date, january,
          reason: 'show-habit.score-card#4');
      expect(byMonth.scores[1].date, LocalDate.ymd(2014, 12, 1),
          reason: 'show-habit.score-card#4');
      expect(
          byMonth.scores[0].value,
          closeTo(
              mean(daily
                  .where((Score s) => !s.date.isOlderThan(january))
                  .map((Score s) => s.value)),
              1e-12),
          reason: 'show-habit.score-card#4');
      expect(
          byMonth.scores[1].value,
          closeTo(
              mean(daily
                  .where((Score s) => s.date.isOlderThan(january))
                  .map((Score s) => s.value)),
              1e-12),
          reason: 'show-habit.score-card#4');

      // Every bucket size keeps the newest-first ordering.
      for (var position = 0; position <= 4; position++) {
        final state = ScoreCardPresenter.buildState(
          habit: habit,
          firstWeekday: 1,
          spinnerPosition: position,
          theme: theme,
        );
        for (var i = 1; i < state.scores.length; i++) {
          expect(state.scores[i - 1].date.isNewerThan(state.scores[i].date),
              isTrue,
              reason: 'show-habit.score-card#4');
        }
      }
    });

    test('#4 with no entries the interval collapses onto today', () {
      final state = ScoreCardPresenter.buildState(
        habit: buildHabit(),
        firstWeekday: 1,
        spinnerPosition: 0,
        theme: LightTheme(),
      );
      expect(state.scores.length, 1, reason: 'show-habit.score-card#4');
      expect(state.scores.single.date, today,
          reason: 'show-habit.score-card#4');
    });

    test('#5 week buckets start on DayOfWeek.entries[firstWeekday - 1]', () {
      final habit = scoreFixture();

      ScoreCardState weekly(int firstWeekday) =>
          ScoreCardPresenter.buildState(
            habit: habit,
            firstWeekday: firstWeekday,
            spinnerPosition: 1,
            theme: LightTheme(),
          );

      // firstWeekday 1 == Sunday; 2015-01-25 is itself a Sunday.
      expect(weekly(1).scores.first.date, LocalDate.ymd(2015, 1, 25),
          reason: 'show-habit.score-card#5');
      // firstWeekday 2 == Monday: the week containing today starts 6 days back.
      expect(weekly(2).scores.first.date, LocalDate.ymd(2015, 1, 19),
          reason: 'show-habit.score-card#5');
      // firstWeekday 7 == Saturday: one day back.
      expect(weekly(7).scores.first.date, LocalDate.ymd(2015, 1, 24),
          reason: 'show-habit.score-card#5');
      expect(weekly(1).bucketSize, 7, reason: 'show-habit.score-card#5');

      // ((dayOfWeek.daysSinceSunday - firstWeekday.daysSinceSunday) mod 7)
      // days are subtracted.
      expect(today.startOfWeek(DayOfWeek.values[2 - 1]),
          LocalDate.ymd(2015, 1, 19),
          reason: 'show-habit.score-card#5');
      expect(today.startOfWeek(DayOfWeek.values[7 - 1]),
          LocalDate.ymd(2015, 1, 24),
          reason: 'show-habit.score-card#5');
    });

    test('#6 month, quarter, year and day truncation', () {
      final habit = scoreFixture();

      List<LocalDate> datesFor(int position) => ScoreCardPresenter.buildState(
            habit: habit,
            firstWeekday: 1,
            spinnerPosition: position,
            theme: LightTheme(),
          ).scores.map((Score s) => s.date).toList();

      expect(datesFor(2),
          <LocalDate>[LocalDate.ymd(2015, 1, 1), LocalDate.ymd(2014, 12, 1)],
          reason: 'show-habit.score-card#6');
      expect(datesFor(3),
          <LocalDate>[LocalDate.ymd(2015, 1, 1), LocalDate.ymd(2014, 10, 1)],
          reason: 'show-habit.score-card#6');
      expect(datesFor(4),
          <LocalDate>[LocalDate.ymd(2015, 1, 1), LocalDate.ymd(2014, 1, 1)],
          reason: 'show-habit.score-card#6');
      expect(datesFor(0).first, today, reason: 'show-habit.score-card#6');
      expect(datesFor(0).length, 41, reason: 'show-habit.score-card#6');
    });

    test('#7 onSpinnerPosition writes the preference, then updates widgets, '
        'then refreshes', () {
      final prefs = memoryPreferences();
      final screen = _FakeCardScreen(() => prefs.scoreCardSpinnerPosition);
      final presenter =
          ScoreCardPresenter(preferences: prefs, screen: screen);

      presenter.onSpinnerPosition(3);

      expect(prefs.scoreCardSpinnerPosition, 3,
          reason: 'show-habit.score-card#7');
      expect(screen.log, <String>['updateWidgets', 'refresh'],
          reason: 'show-habit.score-card#7');
      // The preference is already written when the screen is called back.
      expect(screen.observed, <int>[3, 3], reason: 'show-habit.score-card#7');

      // Selecting the same position again repeats the whole sequence: nothing
      // is deduplicated, which is why the Android spinner loops.
      presenter.onSpinnerPosition(3);
      expect(screen.log,
          <String>['updateWidgets', 'refresh', 'updateWidgets', 'refresh'],
          reason: 'show-habit.score-card#7');
    });
  });

  // -------------------------------------------------------------------------
  // show-habit.bar-card
  // -------------------------------------------------------------------------
  group('show-habit.bar-card', () {
    test('#1 numericalBucketSizes and boolBucketSizes', () {
      expect(BarCardPresenter.numericalBucketSizes, <int>[1, 7, 31, 92, 365],
          reason: 'show-habit.bar-card#1');
      expect(BarCardPresenter.boolBucketSizes, <int>[7, 31, 92, 365],
          reason: 'show-habit.bar-card#1');
    });

    test('#2 numerical habits take the bucket from numericalBucketSizes', () {
      final habit = buildHabit(
        type: HabitType.numerical,
        entries: <Entry>[Entry(today, 5000)],
      );
      for (var position = 0; position <= 4; position++) {
        final state = BarCardPresenter.buildState(
          habit: habit,
          firstWeekday: 1,
          numericalSpinnerPosition: position,
          boolSpinnerPosition: 3,
          theme: LightTheme(),
        );
        expect(state.isNumerical, isTrue, reason: 'show-habit.bar-card#2');
        expect(state.bucketSize,
            BarCardPresenter.numericalBucketSizes[position],
            reason: 'show-habit.bar-card#2');
        expect(state.numericalSpinnerPosition, position,
            reason: 'show-habit.bar-card#2');
        // The boolean position is still carried in the state; only the Android
        // spinner is hidden.
        expect(state.boolSpinnerPosition, 3, reason: 'show-habit.bar-card#2');
      }
    });

    test('#3 boolean habits take the bucket from boolBucketSizes, which has '
        'no Day entry', () {
      final habit = buildHabit(entries: <Entry>[Entry(today, Entry.yesManual)]);
      for (var position = 0; position <= 3; position++) {
        final state = BarCardPresenter.buildState(
          habit: habit,
          firstWeekday: 1,
          numericalSpinnerPosition: 4,
          boolSpinnerPosition: position,
          theme: LightTheme(),
        );
        expect(state.isNumerical, isFalse, reason: 'show-habit.bar-card#3');
        expect(state.bucketSize, BarCardPresenter.boolBucketSizes[position],
            reason: 'show-habit.bar-card#3');
        expect(state.boolSpinnerPosition, position,
            reason: 'show-habit.bar-card#3');
        expect(state.numericalSpinnerPosition, 4,
            reason: 'show-habit.bar-card#3');
      }
      // Position 0 is Week (7), never Day (1).
      expect(BarCardPresenter.boolBucketSizes.first, 7,
          reason: 'show-habit.bar-card#3');
    });

    test('#4 preference keys, defaults and clamps', () {
      final storage = MemoryStorage();
      final prefs = memoryPreferences(storage);

      expect(prefs.barCardNumericalSpinnerPosition, 0,
          reason: 'show-habit.bar-card#4');
      expect(prefs.barCardBoolSpinnerPosition, 0,
          reason: 'show-habit.bar-card#4');

      storage.putInt('pref_bar_card_numerical_spinner', 2);
      storage.putInt('pref_bar_card_bool_spinner', 2);
      expect(prefs.barCardNumericalSpinnerPosition, 2,
          reason: 'show-habit.bar-card#4');
      expect(prefs.barCardBoolSpinnerPosition, 2,
          reason: 'show-habit.bar-card#4');

      prefs.barCardNumericalSpinnerPosition = 11;
      expect(prefs.barCardNumericalSpinnerPosition, 4,
          reason: 'show-habit.bar-card#4');
      prefs.barCardNumericalSpinnerPosition = -2;
      expect(prefs.barCardNumericalSpinnerPosition, 0,
          reason: 'show-habit.bar-card#4');

      prefs.barCardBoolSpinnerPosition = 11;
      expect(prefs.barCardBoolSpinnerPosition, 3,
          reason: 'show-habit.bar-card#4');
      prefs.barCardBoolSpinnerPosition = -2;
      expect(prefs.barCardBoolSpinnerPosition, 0,
          reason: 'show-habit.bar-card#4');
    });

    test('#4 the spinner setters go through the presenter callbacks', () {
      final prefs = memoryPreferences();
      final numericalScreen =
          _FakeCardScreen(() => prefs.barCardNumericalSpinnerPosition);
      final numericalPresenter =
          BarCardPresenter(preferences: prefs, screen: numericalScreen);
      numericalPresenter.onNumericalSpinnerPosition(2);
      expect(prefs.barCardNumericalSpinnerPosition, 2,
          reason: 'show-habit.bar-card#4');
      expect(numericalScreen.log, <String>['updateWidgets', 'refresh'],
          reason: 'show-habit.bar-card#4');
      expect(numericalScreen.observed, <int>[2, 2],
          reason: 'show-habit.bar-card#4');

      final boolScreen =
          _FakeCardScreen(() => prefs.barCardBoolSpinnerPosition);
      final boolPresenter =
          BarCardPresenter(preferences: prefs, screen: boolScreen);
      boolPresenter.onBoolSpinnerPosition(1);
      expect(prefs.barCardBoolSpinnerPosition, 1,
          reason: 'show-habit.bar-card#4');
      expect(boolScreen.log, <String>['updateWidgets', 'refresh'],
          reason: 'show-habit.bar-card#4');
      expect(boolScreen.observed, <int>[1, 1],
          reason: 'show-habit.bar-card#4');
    });

    test('#5 entries are the grouped sum of the computed entries', () {
      final habit = buildHabit(
        type: HabitType.numerical,
        entries: <Entry>[
          Entry(today, 5000),
          Entry(today.minus(1), 3000),
          Entry(today.minus(7), 1000),
        ],
      );

      // Bucket 7, firstWeekday 1 (Sunday): 2015-01-25 opens its own week.
      final weekly = BarCardPresenter.buildState(
        habit: habit,
        firstWeekday: 1,
        numericalSpinnerPosition: 1,
        boolSpinnerPosition: 0,
        theme: LightTheme(),
      );
      expect(weekly.entries.map((Entry e) => e.date).toList(),
          <LocalDate>[LocalDate.ymd(2015, 1, 25), LocalDate.ymd(2015, 1, 18)],
          reason: 'show-habit.bar-card#5');
      expect(weekly.entries.map((Entry e) => e.value).toList(),
          <int>[5000, 4000], reason: 'show-habit.bar-card#5');

      // firstWeekday 2 (Monday) moves both boundaries.
      final weeklyMonday = BarCardPresenter.buildState(
        habit: habit,
        firstWeekday: 2,
        numericalSpinnerPosition: 1,
        boolSpinnerPosition: 0,
        theme: LightTheme(),
      );
      expect(weeklyMonday.entries.map((Entry e) => e.date).toList(),
          <LocalDate>[LocalDate.ymd(2015, 1, 19), LocalDate.ymd(2015, 1, 12)],
          reason: 'show-habit.bar-card#5');
      expect(weeklyMonday.entries.map((Entry e) => e.value).toList(),
          <int>[8000, 1000], reason: 'show-habit.bar-card#5');

      // Bucket 1 keeps one bucket per day of [oldest, today], newest first,
      // with the unknown days summed as zero.
      final daily = BarCardPresenter.buildState(
        habit: habit,
        firstWeekday: 1,
        numericalSpinnerPosition: 0,
        boolSpinnerPosition: 0,
        theme: LightTheme(),
      );
      expect(daily.entries.length, 8, reason: 'show-habit.bar-card#5');
      expect(daily.entries.map((Entry e) => e.value).toList(),
          <int>[5000, 3000, 0, 0, 0, 0, 0, 1000],
          reason: 'show-habit.bar-card#5');
      expect(
          daily.entries,
          habit.computedEntries
              .getByInterval(today.minus(7), today)
              .groupedSum(
                  truncateField: TruncateField.day,
                  firstWeekday: 1,
                  isNumerical: true),
          reason: 'show-habit.bar-card#5');
    });

    test('#5 boolean habits convert each YES_MANUAL to 1000 and SKIP to 0',
        () {
      final habit = buildHabit(entries: <Entry>[
        Entry(today, Entry.yesManual),
        Entry(today.minus(1), Entry.yesManual),
        Entry(today.minus(2), Entry.skip),
      ]);
      final state = BarCardPresenter.buildState(
        habit: habit,
        firstWeekday: 1,
        numericalSpinnerPosition: 0,
        boolSpinnerPosition: 0,
        theme: LightTheme(),
      );
      expect(state.bucketSize, 7, reason: 'show-habit.bar-card#5');
      expect(state.entries.map((Entry e) => e.date).toList(),
          <LocalDate>[LocalDate.ymd(2015, 1, 25), LocalDate.ymd(2015, 1, 18)],
          reason: 'show-habit.bar-card#5');
      expect(state.entries.map((Entry e) => e.value).toList(),
          <int>[1000, 1000], reason: 'show-habit.bar-card#5');
    });

    test('#5 with no entries the interval collapses onto today', () {
      final state = BarCardPresenter.buildState(
        habit: buildHabit(),
        firstWeekday: 1,
        numericalSpinnerPosition: 0,
        boolSpinnerPosition: 0,
        theme: LightTheme(),
      );
      expect(state.entries.length, 1, reason: 'show-habit.bar-card#5');
      expect(state.entries.single.date, LocalDate.ymd(2015, 1, 25),
          reason: 'show-habit.bar-card#5');
      expect(state.entries.single.value, 0, reason: 'show-habit.bar-card#5');
    });
  });

  // -------------------------------------------------------------------------
  // show-habit.history-card
  // -------------------------------------------------------------------------
  group('show-habit.history-card', () {
    /// A weekly habit, so recompute() produces YES_AUTO days, plus one
    /// explicit SKIP, one explicit NO and one UNKNOWN-with-notes day.
    Habit historyFixture() => buildHabit(
          frequency: Frequency.weekly,
          entries: <Entry>[
            Entry(today.minus(6), Entry.yesManual, notes: 'ran'),
            Entry(today.minus(10), Entry.skip),
            Entry(today.minus(12), Entry.no),
            Entry(today.minus(14), Entry.unknown, notes: 'note-a'),
          ],
        );

    test('#1 one square per day of [oldest known entry, today], newest first',
        () {
      final habit = historyFixture();
      final state = HistoryCardPresenter.buildState(
        habit: habit,
        firstWeekday: DayOfWeek.sunday,
        theme: LightTheme(),
      );
      // Oldest known computed entry is today - 14.
      expect(state.series.length, 15, reason: 'show-habit.history-card#1');
      expect(state.notesIndicators.length, 15,
          reason: 'show-habit.history-card#1');
      expect(state.today, today, reason: 'show-habit.history-card#1');
      expect(state.firstWeekday, DayOfWeek.sunday,
          reason: 'show-habit.history-card#1');
      expect(state.color, const PaletteColor(4),
          reason: 'show-habit.history-card#1');
      expect(
          habit.computedEntries.getByInterval(today.minus(14), today).length,
          15,
          reason: 'show-habit.history-card#1');
    });

    test('#1 with no entries the interval collapses onto today', () {
      final state = HistoryCardPresenter.buildState(
        habit: buildHabit(),
        firstWeekday: DayOfWeek.monday,
        theme: LightTheme(),
      );
      expect(state.series, <Square>[Square.off],
          reason: 'show-habit.history-card#1');
      expect(state.notesIndicators, <bool>[false],
          reason: 'show-habit.history-card#1');
    });

    test('#2 numerical squares follow the UNKNOWN/SKIP/target priority order',
        () {
      final atMost = buildHabit(
        type: HabitType.numerical,
        targetType: NumericalHabitType.atMost,
        entries: <Entry>[
          Entry(today, 1000), // 1.0 <= 2.0 -> ON
          Entry(today.minus(1), 5000), // 5.0 > 2.0 -> GREY
          Entry(today.minus(2), Entry.skip), // HATCHED beats AT_MOST
          Entry(today.minus(3), Entry.unknown), // OFF beats everything
        ],
      );
      final atMostState = HistoryCardPresenter.buildState(
        habit: atMost,
        firstWeekday: DayOfWeek.sunday,
        theme: LightTheme(),
      );
      expect(
          atMostState.series,
          <Square>[Square.on, Square.grey, Square.hatched, Square.off],
          reason: 'show-habit.history-card#2');

      final atLeast = buildHabit(
        type: HabitType.numerical,
        entries: <Entry>[
          Entry(today, 5000), // 5.0 >= 2.0 -> ON
          Entry(today.minus(1), 1000), // 1.0 < 2.0 -> GREY
          Entry(today.minus(2), Entry.skip), // HATCHED
          Entry(today.minus(3), Entry.unknown), // OFF
          Entry(today.minus(4), 2000), // exactly the target -> ON
        ],
      );
      final atLeastState = HistoryCardPresenter.buildState(
        habit: atLeast,
        firstWeekday: DayOfWeek.sunday,
        theme: LightTheme(),
      );
      expect(
          atLeastState.series,
          <Square>[
            Square.on,
            Square.grey,
            Square.hatched,
            Square.off,
            Square.on,
          ],
          reason: 'show-habit.history-card#2');
    });

    test('#3 boolean squares: 2 ON, 1 DIMMED, 3 HATCHED, everything else OFF',
        () {
      final state = HistoryCardPresenter.buildState(
        habit: historyFixture(),
        firstWeekday: DayOfWeek.sunday,
        theme: LightTheme(),
      );
      expect(
          state.series,
          <Square>[
            Square.dimmed, // today       YES_AUTO
            Square.dimmed, // today - 1   YES_AUTO
            Square.dimmed, // today - 2   YES_AUTO
            Square.dimmed, // today - 3   YES_AUTO
            Square.dimmed, // today - 4   YES_AUTO
            Square.dimmed, // today - 5   YES_AUTO
            Square.on, //     today - 6   YES_MANUAL
            Square.off, //    today - 7   UNKNOWN
            Square.off, //    today - 8   UNKNOWN
            Square.off, //    today - 9   UNKNOWN
            Square.hatched, // today - 10 SKIP
            Square.off, //    today - 11  UNKNOWN
            Square.off, //    today - 12  NO
            Square.off, //    today - 13  UNKNOWN
            Square.off, //    today - 14  UNKNOWN (kept for its notes)
          ],
          reason: 'show-habit.history-card#3');
    });

    test('#4 notesIndicators is true exactly where notes are non-empty', () {
      final state = HistoryCardPresenter.buildState(
        habit: historyFixture(),
        firstWeekday: DayOfWeek.sunday,
        theme: LightTheme(),
      );
      final expected = List<bool>.filled(15, false);
      expected[6] = true; // 'ran'
      expected[14] = true; // 'note-a'
      expect(state.notesIndicators, expected,
          reason: 'show-habit.history-card#4');
    });

    test('#5 defaultSquare is OFF', () {
      expect(
          HistoryCardPresenter.buildState(
            habit: historyFixture(),
            firstWeekday: DayOfWeek.sunday,
            theme: LightTheme(),
          ).defaultSquare,
          Square.off,
          reason: 'show-habit.history-card#5');
      expect(
          HistoryCardPresenter.buildState(
            habit: buildHabit(type: HabitType.numerical),
            firstWeekday: DayOfWeek.sunday,
            theme: LightTheme(),
          ).defaultSquare,
          Square.off,
          reason: 'show-habit.history-card#5');
    });
  });

  // -------------------------------------------------------------------------
  // show-habit.streak-card
  // -------------------------------------------------------------------------
  group('show-habit.streak-card', () {
    /// Twelve streaks of lengths 1..12, newest first, separated by one gap day.
    Habit twelveStreaks() {
      final entries = <Entry>[];
      var offset = 0;
      for (var length = 1; length <= 12; length++) {
        for (var i = 0; i < length; i++) {
          entries.add(Entry(today.minus(offset + i), Entry.yesManual));
        }
        offset += length + 1;
      }
      return buildHabit(entries: entries);
    }

    /// The offset of the first (newest) day of the streak whose length is
    /// [length] in [twelveStreaks].
    int startOffset(int length) {
      var offset = 0;
      for (var i = 1; i < length; i++) {
        offset += i + 1;
      }
      return offset;
    }

    test('#1 bestStreaks is habit.streaks.getBest(10)', () {
      final habit = twelveStreaks();
      final theme = LightTheme();
      final state = StreakCartPresenter.buildState(habit, theme);

      expect(state.bestStreaks.length, 10,
          reason: 'show-habit.streak-card#1');
      expect(state.bestStreaks, habit.streaks.getBest(10),
          reason: 'show-habit.streak-card#1');
      expect(state.color, const PaletteColor(4),
          reason: 'show-habit.streak-card#1');
      expect(identical(state.theme, theme), isTrue,
          reason: 'show-habit.streak-card#1');

      // Fewer streaks than the limit: all of them are kept.
      final short = buildHabit(entries: <Entry>[
        Entry(today, Entry.yesManual),
        Entry(today.minus(1), Entry.yesManual),
      ]);
      expect(StreakCartPresenter.buildState(short, theme).bestStreaks.length, 1,
          reason: 'show-habit.streak-card#1');
    });

    test('#2 the ten longest streaks, then re-sorted newest-ending first', () {
      final state =
          StreakCartPresenter.buildState(twelveStreaks(), LightTheme());

      // The two shortest streaks (lengths 1 and 2) are dropped.
      expect(state.bestStreaks.map((Streak s) => s.length).toList(),
          <int>[3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
          reason: 'show-habit.streak-card#2');
      // ...and what survives is ordered by end date, newest first.
      for (var i = 1; i < state.bestStreaks.length; i++) {
        expect(
            state.bestStreaks[i - 1].end
                .isNewerThan(state.bestStreaks[i].end),
            isTrue,
            reason: 'show-habit.streak-card#2');
      }
      expect(state.bestStreaks.first.end, today.minus(startOffset(3)),
          reason: 'show-habit.streak-card#2');
      expect(state.bestStreaks.last.end, today.minus(startOffset(12)),
          reason: 'show-habit.streak-card#2');

      // compareLonger breaks ties by the newer end date, so a limit of one
      // over two equal-length streaks keeps the newer one.
      final tied = buildHabit(entries: <Entry>[
        Entry(today, Entry.yesManual),
        Entry(today.minus(1), Entry.yesManual),
        Entry(today.minus(5), Entry.yesManual),
        Entry(today.minus(6), Entry.yesManual),
      ]);
      expect(tied.streaks.getBest(1),
          <Streak>[Streak(today.minus(1), today)],
          reason: 'show-habit.streak-card#2');
    });

    test('#3 Streak.length counts both endpoints', () {
      expect(Streak(today, today).length, 1,
          reason: 'show-habit.streak-card#3');
      expect(Streak(today.minus(4), today).length, 5,
          reason: 'show-habit.streak-card#3');

      final state = StreakCartPresenter.buildState(
        buildHabit(entries: <Entry>[
          Entry(today, Entry.yesManual),
          Entry(today.minus(1), Entry.yesManual),
          Entry(today.minus(2), Entry.yesManual),
        ]),
        LightTheme(),
      );
      expect(state.bestStreaks.single.start, today.minus(2),
          reason: 'show-habit.streak-card#3');
      expect(state.bestStreaks.single.end, today,
          reason: 'show-habit.streak-card#3');
      expect(state.bestStreaks.single.length,
          state.bestStreaks.single.start.daysUntil(
                  state.bestStreaks.single.end) +
              1,
          reason: 'show-habit.streak-card#3');
      expect(state.bestStreaks.single.length, 3,
          reason: 'show-habit.streak-card#3');
    });

    test('#4 qualifying days: boolean value > 0, numerical against the target',
        () {
      // Boolean: YES_AUTO (1) counts as well as YES_MANUAL (2); SKIP (3) also
      // has value > 0, while NO (0) and UNKNOWN (-1) break the streak.
      final boolean = buildHabit(entries: <Entry>[
        Entry(today, Entry.yesManual),
        Entry(today.minus(1), Entry.skip),
        Entry(today.minus(2), Entry.yesManual),
        Entry(today.minus(3), Entry.no),
        Entry(today.minus(4), Entry.yesManual),
      ]);
      expect(
          StreakCartPresenter.buildState(boolean, LightTheme()).bestStreaks,
          <Streak>[
            Streak(today.minus(2), today),
            Streak(today.minus(4), today.minus(4)),
          ],
          reason: 'show-habit.streak-card#4');

      // Numerical AT_LEAST: value / 1000.0 >= targetValue.
      final atLeast = buildHabit(
        type: HabitType.numerical,
        entries: <Entry>[
          Entry(today, 5000),
          Entry(today.minus(1), 2000), // exactly the target
          Entry(today.minus(2), 1000), // below the target
          Entry(today.minus(3), 9000),
        ],
      );
      expect(
          StreakCartPresenter.buildState(atLeast, LightTheme()).bestStreaks,
          <Streak>[
            Streak(today.minus(1), today),
            Streak(today.minus(3), today.minus(3)),
          ],
          reason: 'show-habit.streak-card#4');

      // Numerical AT_MOST: value != UNKNOWN and value / 1000.0 <= targetValue.
      final atMost = buildHabit(
        type: HabitType.numerical,
        targetType: NumericalHabitType.atMost,
        entries: <Entry>[
          Entry(today, 1000),
          Entry(today.minus(1), 2000), // exactly the target
          Entry(today.minus(2), Entry.unknown), // excluded despite -1 <= 2000
          Entry(today.minus(3), 0),
        ],
      );
      expect(
          StreakCartPresenter.buildState(atMost, LightTheme()).bestStreaks,
          <Streak>[
            Streak(today.minus(1), today),
            Streak(today.minus(3), today.minus(3)),
          ],
          reason: 'show-habit.streak-card#4');
    });

    test('#11 a habit with no qualifying days has an empty streak list', () {
      expect(
          StreakCartPresenter.buildState(buildHabit(), LightTheme())
              .bestStreaks,
          isEmpty,
          reason: 'show-habit.streak-card#11');
      expect(
          StreakCartPresenter.buildState(
            buildHabit(entries: <Entry>[Entry(today, Entry.no)]),
            LightTheme(),
          ).bestStreaks,
          isEmpty,
          reason: 'show-habit.streak-card#11');
    });
  });

  // -------------------------------------------------------------------------
  // show-habit.frequency-card
  // -------------------------------------------------------------------------
  group('show-habit.frequency-card', () {
    test('#1 the histogram is built from originalEntries, never from the '
        'YES_AUTO days in computedEntries', () {
      // A weekly habit checked on 2014-12-29 (a Monday). recompute() fills
      // 2014-12-30..2015-01-04 with YES_AUTO, so computedEntries reaches into
      // January while originalEntries does not.
      final habit = buildHabit(
        frequency: Frequency.weekly,
        entries: <Entry>[
          Entry(LocalDate.ymd(2014, 12, 29), Entry.yesManual),
        ],
      );
      expect(habit.computedEntries.get(LocalDate.ymd(2015, 1, 2)).value,
          Entry.yesAuto,
          reason: 'show-habit.frequency-card#1');

      final theme = LightTheme();
      final state = FrequencyCardPresenter.buildState(
        habit: habit,
        firstWeekday: DayOfWeek.saturday,
        theme: theme,
      );

      expect(state.frequency.keys.toList(),
          <LocalDate>[LocalDate.ymd(2014, 12, 1)],
          reason: 'show-habit.frequency-card#1');
      expect(state.frequency[LocalDate.ymd(2014, 12, 1)],
          <int>[0, 0, 1, 0, 0, 0, 0],
          reason: 'show-habit.frequency-card#1');
      expect(state.frequency[LocalDate.ymd(2015, 1, 1)], isNull,
          reason: 'show-habit.frequency-card#1');

      expect(state.color, const PaletteColor(4),
          reason: 'show-habit.frequency-card#1');
      expect(state.firstWeekday, DayOfWeek.saturday,
          reason: 'show-habit.frequency-card#1');
      expect(state.isNumerical, isFalse,
          reason: 'show-habit.frequency-card#1');
      expect(identical(state.theme, theme), isTrue,
          reason: 'show-habit.frequency-card#1');
    });

    test('#2 keyed by startOfMonth, indexed Saturday-first', () {
      final habit = buildHabit(entries: <Entry>[
        Entry(LocalDate.ymd(2015, 1, 24), Entry.yesManual), // Saturday -> 0
        Entry(LocalDate.ymd(2015, 1, 25), Entry.yesManual), // Sunday   -> 1
        Entry(LocalDate.ymd(2015, 1, 19), Entry.yesManual), // Monday   -> 2
        Entry(LocalDate.ymd(2015, 1, 23), Entry.yesManual), // Friday   -> 6
        Entry(LocalDate.ymd(2014, 12, 30), Entry.yesManual), // Tuesday -> 3
      ]);
      final state = FrequencyCardPresenter.buildState(
        habit: habit,
        firstWeekday: DayOfWeek.sunday,
        theme: LightTheme(),
      );

      expect(state.frequency[LocalDate.ymd(2015, 1, 1)],
          <int>[1, 1, 1, 0, 0, 0, 1],
          reason: 'show-habit.frequency-card#2');
      expect(state.frequency[LocalDate.ymd(2014, 12, 1)],
          <int>[0, 0, 0, 1, 0, 0, 0],
          reason: 'show-habit.frequency-card#2');
      // The key is the first day of the month, not the entry date.
      expect(state.frequency.containsKey(LocalDate.ymd(2015, 1, 24)), isFalse,
          reason: 'show-habit.frequency-card#2');
      expect(LocalDate.ymd(2015, 1, 24).dayOfWeek, DayOfWeek.saturday,
          reason: 'show-habit.frequency-card#2');
      expect((DayOfWeek.saturday.daysSinceSunday + 1) % 7, 0,
          reason: 'show-habit.frequency-card#2');
      expect((DayOfWeek.sunday.daysSinceSunday + 1) % 7, 1,
          reason: 'show-habit.frequency-card#2');
      expect((DayOfWeek.friday.daysSinceSunday + 1) % 7, 6,
          reason: 'show-habit.frequency-card#2');
    });

    test('#3 boolean counts only YES_MANUAL; numerical adds the raw value', () {
      final boolean = buildHabit(entries: <Entry>[
        Entry(LocalDate.ymd(2015, 1, 24), Entry.yesManual), // Saturday -> 1
        Entry(LocalDate.ymd(2015, 1, 25), Entry.yesAuto), // Sunday    -> 0
        Entry(LocalDate.ymd(2015, 1, 19), Entry.skip), // Monday       -> 0
        Entry(LocalDate.ymd(2015, 1, 20), Entry.no), // Tuesday        -> 0
        Entry(LocalDate.ymd(2015, 1, 21), Entry.unknown), // Wednesday -> 0
      ]);
      expect(
          FrequencyCardPresenter.buildState(
            habit: boolean,
            firstWeekday: DayOfWeek.sunday,
            theme: LightTheme(),
          ).frequency[LocalDate.ymd(2015, 1, 1)],
          <int>[1, 0, 0, 0, 0, 0, 0],
          reason: 'show-habit.frequency-card#3');

      final numerical = buildHabit(
        type: HabitType.numerical,
        entries: <Entry>[
          Entry(LocalDate.ymd(2015, 1, 24), 5000), // Saturday  -> 5000
          Entry(LocalDate.ymd(2015, 1, 25), Entry.skip), // Sunday -> 3
          Entry(LocalDate.ymd(2015, 1, 19), Entry.unknown), // Monday -> -1
          Entry(LocalDate.ymd(2015, 1, 17), 250), // Saturday  -> +250
        ],
      );
      final numericalState = FrequencyCardPresenter.buildState(
        habit: numerical,
        firstWeekday: DayOfWeek.sunday,
        theme: LightTheme(),
      );
      expect(numericalState.isNumerical, isTrue,
          reason: 'show-habit.frequency-card#3');
      expect(numericalState.frequency[LocalDate.ymd(2015, 1, 1)],
          <int>[5250, 3, -1, 0, 0, 0, 0],
          reason: 'show-habit.frequency-card#3');
    });

    test('#4 months with no known entries are absent from the map', () {
      final habit = buildHabit(entries: <Entry>[
        Entry(LocalDate.ymd(2015, 1, 24), Entry.yesManual),
        Entry(LocalDate.ymd(2014, 11, 24), Entry.yesManual),
      ]);
      final state = FrequencyCardPresenter.buildState(
        habit: habit,
        firstWeekday: DayOfWeek.sunday,
        theme: LightTheme(),
      );
      expect(state.frequency.length, 2,
          reason: 'show-habit.frequency-card#4');
      expect(state.frequency.containsKey(LocalDate.ymd(2014, 12, 1)), isFalse,
          reason: 'show-habit.frequency-card#4');
      expect(state.frequency.containsKey(LocalDate.ymd(2014, 11, 1)), isTrue,
          reason: 'show-habit.frequency-card#4');
      expect(state.frequency.containsKey(LocalDate.ymd(2015, 1, 1)), isTrue,
          reason: 'show-habit.frequency-card#4');
      expect(
          FrequencyCardPresenter.buildState(
            habit: buildHabit(),
            firstWeekday: DayOfWeek.sunday,
            theme: LightTheme(),
          ).frequency,
          isEmpty,
          reason: 'show-habit.frequency-card#4');
    });
  });
}
