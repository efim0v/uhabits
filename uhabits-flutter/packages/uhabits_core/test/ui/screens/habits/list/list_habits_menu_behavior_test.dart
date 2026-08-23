import 'package:test/test.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/habit_matcher.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/score_list.dart';
import 'package:uhabits_core/src/models/streak_list.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_menu_behavior.dart';

/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsMenuBehaviorTest.kt
///
/// The Kotlin test uses Mokkery mocks; there is no mocking framework here, so
/// [FakeAdapter], [FakeScreen] and [FakeThemeSwitcher] record their calls and
/// the assertions read the recordings. The comparator and preference rules of
/// `list-habits.sort-modes` and the matcher rules of `list-habits.filters` /
/// `list-habits.search` are asserted against the already-ported
/// `MemoryHabitList`, `HabitMatcher` and `Preferences`.

// ---------------------------------------------------------------------------
// Fakes for the three collaborators the behaviour talks to.
// ---------------------------------------------------------------------------

class FakeAdapter implements ListHabitsMenuBehaviorAdapter {
  FakeAdapter({
    HabitListOrder primaryOrder = HabitListOrder.byPosition,
    HabitListOrder secondaryOrder = HabitListOrder.byNameAsc,
  })  : _primaryOrder = primaryOrder,
        _secondaryOrder = secondaryOrder;

  /// Every call, in order, as `'setFilter'` / `'refresh'` / `'primaryOrder='` /
  /// `'secondaryOrder='`.
  final List<String> log = <String>[];

  final List<HabitMatcher> filters = <HabitMatcher>[];
  final List<HabitListOrder> primaryOrderWrites = <HabitListOrder>[];
  final List<HabitListOrder> secondaryOrderWrites = <HabitListOrder>[];

  int refreshCount = 0;

  HabitListOrder _primaryOrder;
  HabitListOrder _secondaryOrder;

  HabitMatcher get lastFilter => filters.last;

  void clearLog() {
    log.clear();
    filters.clear();
    primaryOrderWrites.clear();
    secondaryOrderWrites.clear();
    refreshCount = 0;
  }

  @override
  void refresh() {
    refreshCount++;
    log.add('refresh');
  }

  @override
  void setFilter(HabitMatcher matcher) {
    filters.add(matcher);
    log.add('setFilter');
  }

  @override
  HabitListOrder get primaryOrder => _primaryOrder;

  @override
  set primaryOrder(HabitListOrder value) {
    _primaryOrder = value;
    primaryOrderWrites.add(value);
    log.add('primaryOrder=');
  }

  @override
  HabitListOrder get secondaryOrder => _secondaryOrder;

  @override
  set secondaryOrder(HabitListOrder value) {
    _secondaryOrder = value;
    secondaryOrderWrites.add(value);
    log.add('secondaryOrder=');
  }
}

class FakeScreen implements ListHabitsMenuBehaviorScreen {
  final List<String> log = <String>[];

  @override
  void applyTheme() => log.add('applyTheme');

  @override
  void showAboutScreen() => log.add('showAboutScreen');

  @override
  void showFAQScreen() => log.add('showFAQScreen');

  @override
  void showSelectHabitTypeDialog() => log.add('showSelectHabitTypeDialog');

  @override
  void showSettingsScreen() => log.add('showSettingsScreen');
}

class FakeThemeSwitcher implements ListHabitsMenuThemeSwitcher {
  FakeThemeSwitcher({this.isNightMode = false});

  @override
  bool isNightMode;

  int toggleCount = 0;

  @override
  void toggleNightMode() => toggleCount++;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Habit buildHabit({
  String name = '',
  String question = '',
  String description = '',
  PaletteColor color = const PaletteColor(8),
  int position = 0,
  bool isArchived = false,
  Reminder? reminder,
  HabitType type = HabitType.yesNo,
  NumericalHabitType targetType = NumericalHabitType.atLeast,
  double targetValue = 0.0,
}) {
  final habit = Habit(
    computedEntries: EntryList(),
    originalEntries: EntryList(),
    scores: ScoreList(),
    streaks: StreakList(),
  );
  habit.name = name;
  habit.question = question;
  habit.description = description;
  habit.color = color;
  habit.position = position;
  habit.isArchived = isArchived;
  habit.reminder = reminder;
  habit.type = type;
  habit.targetType = targetType;
  habit.targetValue = targetValue;
  habit.frequency = Frequency.daily;
  return habit;
}

/// Writes [value] straight into the *computed* entry list for today, which is
/// what `isCompletedToday`, `isEnteredToday` and the status comparator read.
Habit withTodayValue(Habit habit, int value) {
  habit.computedEntries.add(Entry(getToday(), value));
  return habit;
}

class Fixture {
  Fixture({
    bool showArchived = false,
    bool showCompleted = true,
    bool areQuestionMarksEnabled = false,
    HabitListOrder primaryOrder = HabitListOrder.byPosition,
    HabitListOrder secondaryOrder = HabitListOrder.byNameAsc,
  })  : storage = MemoryStorage(),
        screen = FakeScreen(),
        themeSwitcher = FakeThemeSwitcher() {
    preferences = Preferences(storage);
    preferences.showArchived = showArchived;
    preferences.showCompleted = showCompleted;
    preferences.areQuestionMarksEnabled = areQuestionMarksEnabled;
    adapter = FakeAdapter(
      primaryOrder: primaryOrder,
      secondaryOrder: secondaryOrder,
    );
    behavior = ListHabitsMenuBehavior(
      screen,
      adapter,
      preferences,
      themeSwitcher,
    );
  }

  final MemoryStorage storage;
  final FakeScreen screen;
  final FakeThemeSwitcher themeSwitcher;
  late final Preferences preferences;
  late final FakeAdapter adapter;
  late final ListHabitsMenuBehavior behavior;
}

/// Runs a search over [habits] and returns the matching names.
Set<String> search(List<Habit> habits, String query) {
  final matcher = HabitMatcher(searchQuery: query);
  return habits.where(matcher.matches).map((h) => h.name).toSet();
}

void main() {
  setUp(() => setToday(LocalDate.ymd(2015, 1, 25)));
  tearDown(resetToday);

  // =========================================================================
  // list-habits.filters
  // =========================================================================

  group('list-habits.filters', () {
    test('initial state comes from the preferences, applied on construction',
        () {
      final f = Fixture();
      expect(
        f.adapter.filters.length,
        1,
        reason: 'list-habits.filters#1',
      );
      expect(
        f.adapter.lastFilter.isArchivedAllowed,
        isFalse,
        reason: 'list-habits.filters#1',
      );
      expect(
        f.adapter.lastFilter.isCompletedAllowed,
        isTrue,
        reason: 'list-habits.filters#1',
      );

      // The defaults themselves, read straight off an untouched storage.
      final prefs = Preferences(MemoryStorage());
      expect(
        prefs.showCompleted,
        isTrue,
        reason: 'list-habits.filters#1',
      );
      expect(
        prefs.showArchived,
        isFalse,
        reason: 'list-habits.filters#1',
      );

      // The exact storage keys the initial state is read from.
      final storage = MemoryStorage();
      storage.putBoolean('pref_show_archived', true);
      storage.putBoolean('pref_show_completed', false);
      final adapter = FakeAdapter();
      ListHabitsMenuBehavior(
        FakeScreen(),
        adapter,
        Preferences(storage),
        FakeThemeSwitcher(),
      );
      expect(
        adapter.lastFilter.isArchivedAllowed,
        isTrue,
        reason: 'list-habits.filters#1',
      );
      expect(
        adapter.lastFilter.isCompletedAllowed,
        isFalse,
        reason: 'list-habits.filters#1',
      );
    });

    test('onToggleShowArchived flips, persists, rebuilds and refreshes', () {
      final f = Fixture();
      f.adapter.clearLog();

      f.behavior.onToggleShowArchived();
      expect(
        f.preferences.showArchived,
        isTrue,
        reason: 'list-habits.filters#2',
      );
      expect(
        f.storage.getString('pref_show_archived', ''),
        'true',
        reason: 'list-habits.filters#2',
      );
      expect(
        f.adapter.lastFilter.isArchivedAllowed,
        isTrue,
        reason: 'list-habits.filters#2',
      );
      expect(
        f.adapter.log,
        <String>['setFilter', 'refresh'],
        reason: 'list-habits.filters#2',
      );

      f.adapter.clearLog();
      f.behavior.onToggleShowArchived();
      expect(
        f.preferences.showArchived,
        isFalse,
        reason: 'list-habits.filters#2',
      );
      expect(
        f.adapter.lastFilter.isArchivedAllowed,
        isFalse,
        reason: 'list-habits.filters#2',
      );
      expect(
        f.adapter.log,
        <String>['setFilter', 'refresh'],
        reason: 'list-habits.filters#2',
      );
    });

    test('onToggleShowCompleted flips, persists, rebuilds and refreshes', () {
      final f = Fixture();
      f.adapter.clearLog();

      f.behavior.onToggleShowCompleted();
      expect(
        f.preferences.showCompleted,
        isFalse,
        reason: 'list-habits.filters#3',
      );
      expect(
        f.storage.getString('pref_show_completed', ''),
        'false',
        reason: 'list-habits.filters#3',
      );
      expect(
        f.adapter.lastFilter.isCompletedAllowed,
        isFalse,
        reason: 'list-habits.filters#3',
      );
      expect(
        f.adapter.log,
        <String>['setFilter', 'refresh'],
        reason: 'list-habits.filters#3',
      );

      f.adapter.clearLog();
      f.behavior.onToggleShowCompleted();
      expect(
        f.preferences.showCompleted,
        isTrue,
        reason: 'list-habits.filters#3',
      );
      expect(
        f.adapter.lastFilter.isCompletedAllowed,
        isTrue,
        reason: 'list-habits.filters#3',
      );
      expect(
        f.adapter.log,
        <String>['setFilter', 'refresh'],
        reason: 'list-habits.filters#3',
      );
    });

    test('filter construction branches on areQuestionMarksEnabled', () {
      final withoutQuestionMarks = Fixture(
        showArchived: true,
        showCompleted: false,
      );
      expect(
        withoutQuestionMarks.adapter.lastFilter,
        const HabitMatcher(
          isArchivedAllowed: true,
          isCompletedAllowed: false,
        ),
        reason: 'list-habits.filters#4 and '
            'settings.preferences.question-marks#5 — with question marks off '
            'updateAdapterFilter() builds '
            'HabitMatcher(isCompletedAllowed = showCompleted)',
      );
      expect(
        withoutQuestionMarks.adapter.lastFilter.isEnteredAllowed,
        isTrue,
        reason: 'list-habits.filters#4 and '
            'settings.preferences.question-marks#5 — the other field keeps its '
            'default',
      );

      final withQuestionMarks = Fixture(
        showArchived: true,
        showCompleted: false,
        areQuestionMarksEnabled: true,
      );
      expect(
        withQuestionMarks.adapter.lastFilter,
        const HabitMatcher(
          isArchivedAllowed: true,
          isEnteredAllowed: false,
        ),
        reason: 'list-habits.filters#4 and '
            'settings.preferences.question-marks#5 — with question marks on '
            'the flag is routed to isEnteredAllowed instead',
      );
      expect(
        withQuestionMarks.adapter.lastFilter.isCompletedAllowed,
        isTrue,
        reason: 'list-habits.filters#4 and '
            'settings.preferences.question-marks#5',
      );

      // The search query rides along on both branches.
      withoutQuestionMarks.behavior.onSearchQueryChanged('yoga');
      expect(
        withoutQuestionMarks.adapter.lastFilter.searchQuery,
        'yoga',
        reason: 'list-habits.filters#4',
      );
      withQuestionMarks.behavior.onSearchQueryChanged('yoga');
      expect(
        withQuestionMarks.adapter.lastFilter.searchQuery,
        'yoga',
        reason: 'list-habits.filters#4',
      );
    });

    test('HabitMatcher.matches rejects on each clause', () {
      final archived = buildHabit(name: 'Archived', isArchived: true);
      expect(
        const HabitMatcher(isArchivedAllowed: false).matches(archived),
        isFalse,
        reason: 'list-habits.filters#5',
      );
      expect(
        const HabitMatcher(isArchivedAllowed: true).matches(archived),
        isTrue,
        reason: 'list-habits.filters#5',
      );

      final noReminder = buildHabit(name: 'No reminder');
      final withReminder = buildHabit(
        name: 'With reminder',
        reminder: Reminder(8, 30, WeekdayList(127)),
      );
      expect(
        const HabitMatcher(isReminderRequired: true).matches(noReminder),
        isFalse,
        reason: 'list-habits.filters#5',
      );
      expect(
        const HabitMatcher(isReminderRequired: true).matches(withReminder),
        isTrue,
        reason: 'list-habits.filters#5',
      );

      final completed =
          withTodayValue(buildHabit(name: 'Completed'), Entry.yesManual);
      expect(
        const HabitMatcher(isCompletedAllowed: false).matches(completed),
        isFalse,
        reason: 'list-habits.filters#5',
      );
      expect(
        const HabitMatcher(isCompletedAllowed: true).matches(completed),
        isTrue,
        reason: 'list-habits.filters#5',
      );

      final entered = withTodayValue(buildHabit(name: 'Entered'), Entry.no);
      expect(
        const HabitMatcher(isEnteredAllowed: false).matches(entered),
        isFalse,
        reason: 'list-habits.filters#5',
      );
      expect(
        const HabitMatcher(isEnteredAllowed: true).matches(entered),
        isTrue,
        reason: 'list-habits.filters#5',
      );

      final yoga = buildHabit(name: 'Yoga');
      expect(
        const HabitMatcher(searchQuery: 'swimming').matches(yoga),
        isFalse,
        reason: 'list-habits.filters#5',
      );
      expect(
        const HabitMatcher(searchQuery: 'yog').matches(yoga),
        isTrue,
        reason: 'list-habits.filters#5',
      );

      // The archived clause is evaluated before the others: an archived habit
      // that would pass every later clause is still rejected.
      expect(
        const HabitMatcher(isArchivedAllowed: false).matches(archived),
        isFalse,
        reason: 'list-habits.filters#5',
      );
    });

    test('Habit.isCompletedToday', () {
      const matcher = HabitMatcher(isCompletedAllowed: false);

      for (final value in <int>[Entry.yesManual, Entry.yesAuto, Entry.skip]) {
        final habit = withTodayValue(buildHabit(name: 'Yes/No'), value);
        expect(
          habit.isCompletedToday(),
          isTrue,
          reason: 'list-habits.filters#6',
        );
        expect(
          matcher.matches(habit),
          isFalse,
          reason: 'list-habits.filters#6',
        );
      }
      for (final value in <int>[Entry.no, Entry.unknown]) {
        final habit = withTodayValue(buildHabit(name: 'Yes/No'), value);
        expect(
          habit.isCompletedToday(),
          isFalse,
          reason: 'list-habits.filters#6',
        );
      }
      expect(
        buildHabit(name: 'Untouched').isCompletedToday(),
        isFalse,
        reason: 'list-habits.filters#6',
      );

      Habit numerical(NumericalHabitType targetType, int value) =>
          withTodayValue(
            buildHabit(
              name: 'Run',
              type: HabitType.numerical,
              targetType: targetType,
              targetValue: 2.0,
            ),
            value,
          );

      expect(
        numerical(NumericalHabitType.atLeast, 2000).isCompletedToday(),
        isTrue,
        reason: 'list-habits.filters#6',
      );
      expect(
        numerical(NumericalHabitType.atLeast, 1999).isCompletedToday(),
        isFalse,
        reason: 'list-habits.filters#6',
      );
      expect(
        numerical(NumericalHabitType.atMost, 0).isCompletedToday(),
        isFalse,
        reason: 'list-habits.filters#6',
      );
      expect(
        numerical(NumericalHabitType.atMost, 5000).isCompletedToday(),
        isFalse,
        reason: 'list-habits.filters#6',
      );
    });

    test('Habit.isEnteredToday', () {
      for (final value in <int>[
        Entry.no,
        Entry.yesAuto,
        Entry.yesManual,
        Entry.skip,
        1000,
      ]) {
        expect(
          withTodayValue(buildHabit(name: 'H'), value).isEnteredToday(),
          isTrue,
          reason: 'list-habits.filters#7',
        );
      }
      expect(
        withTodayValue(buildHabit(name: 'H'), Entry.unknown).isEnteredToday(),
        isFalse,
        reason: 'list-habits.filters#7',
      );
      expect(
        buildHabit(name: 'H').isEnteredToday(),
        isFalse,
        reason: 'list-habits.filters#7',
      );
    });

    test('HabitMatcher defaults', () {
      const matcher = HabitMatcher();
      expect(
        matcher.isArchivedAllowed,
        isFalse,
        reason: 'list-habits.filters#8',
      );
      expect(
        matcher.isReminderRequired,
        isFalse,
        reason: 'list-habits.filters#8',
      );
      expect(
        matcher.isCompletedAllowed,
        isTrue,
        reason: 'list-habits.filters#8',
      );
      expect(
        matcher.isEnteredAllowed,
        isTrue,
        reason: 'list-habits.filters#8',
      );
      expect(
        matcher.searchQuery,
        '',
        reason: 'list-habits.filters#8',
      );
    });

    test('rebuilding the filter always refreshes, and refreshes last', () {
      final f = Fixture();
      expect(
        f.adapter.log,
        <String>['setFilter', 'refresh'],
        reason: 'list-habits.filters#9',
      );

      f.adapter.clearLog();
      f.behavior.onSearchQueryChanged('a');
      f.behavior.onToggleShowArchived();
      f.behavior.onToggleShowCompleted();
      f.behavior.onPreferencesChanged();
      expect(
        f.adapter.log,
        <String>[
          'setFilter', 'refresh', //
          'setFilter', 'refresh',
          'setFilter', 'refresh',
          'setFilter', 'refresh',
        ],
        reason: 'list-habits.filters#9',
      );
      expect(
        f.adapter.refreshCount,
        f.adapter.filters.length,
        reason: 'list-habits.filters#9',
      );
    });
  });

  // =========================================================================
  // list-habits.search
  // =========================================================================

  group('list-habits.search', () {
    test('searchQuery starts empty and is stored verbatim', () {
      final f = Fixture();
      expect(
        f.behavior.searchQuery,
        '',
        reason: 'list-habits.search#1',
      );
      expect(
        f.adapter.lastFilter.searchQuery,
        '',
        reason: 'list-habits.search#1',
      );

      f.adapter.clearLog();
      f.behavior.onSearchQueryChanged('  Yoga  ');
      expect(
        f.behavior.searchQuery,
        '  Yoga  ',
        reason: 'list-habits.search#1',
      );
      expect(
        f.adapter.lastFilter.searchQuery,
        '  Yoga  ',
        reason: 'list-habits.search#1',
      );
      expect(
        f.adapter.log,
        <String>['setFilter', 'refresh'],
        reason: 'list-habits.search#1',
      );
    });

    test('matching trims the query and looks at name, question, description',
        () {
      final yogaPractice = buildHabit(name: 'Yoga practice');
      final running = buildHabit(
        name: 'Running',
        question: 'Did you run today?',
        description: 'daily jog',
      );
      final exercise = buildHabit(
        name: 'Exercise',
        question: 'Did you do yoga today?',
      );
      final habits = <Habit>[yogaPractice, running, exercise];

      expect(
        search(habits, 'yoga'),
        <String>{'Yoga practice', 'Exercise'},
        reason: 'list-habits.search#2',
      );
      expect(
        search(habits, '   yoga'),
        <String>{'Yoga practice', 'Exercise'},
        reason: 'list-habits.search#2',
      );
      expect(
        search(habits, 'jog'),
        <String>{'Running'},
        reason: 'list-habits.search#2',
      );
      expect(
        const HabitMatcher(searchQuery: ' ').matches(yogaPractice),
        isTrue,
        reason: 'list-habits.search#2',
      );
    });

    test('empty and whitespace-only queries match everything', () {
      final habits = <Habit>[
        buildHabit(name: 'Yoga practice'),
        buildHabit(name: 'Running', question: 'Did you run today?'),
        buildHabit(name: '🧘 Stretching'),
      ];
      const all = <String>{'Yoga practice', 'Running', '🧘 Stretching'};

      expect(
        search(habits, ''),
        all,
        reason: 'list-habits.search#3',
      );
      expect(
        search(habits, '   '),
        all,
        reason: 'list-habits.search#3',
      );
    });

    test('matching is case-insensitive and whitespace-insensitive', () {
      final habits = <Habit>[
        buildHabit(name: 'Yoga practice'),
        buildHabit(name: 'Exercise', question: 'Did you do yoga today?'),
        buildHabit(name: 'Running'),
      ];

      expect(
        search(habits, 'YOGA'),
        <String>{'Yoga practice', 'Exercise'},
        reason: 'list-habits.search#4',
      );
      expect(
        search(habits, '  yoga  '),
        <String>{'Yoga practice', 'Exercise'},
        reason: 'list-habits.search#4',
      );
      expect(
        search(habits, 'yoga'),
        search(habits, '  yoga  '),
        reason: 'list-habits.search#4',
      );
    });

    test('no accent folding', () {
      final mediter =
          buildHabit(name: 'Méditer', description: 'mindfulness session');
      final habits = <Habit>[mediter, buildHabit(name: 'Running')];

      expect(
        search(habits, 'méditer'),
        <String>{'Méditer'},
        reason: 'list-habits.search#5',
      );
      expect(
        search(habits, 'MÉDITER'),
        <String>{'Méditer'},
        reason: 'list-habits.search#5',
      );
      expect(
        search(habits, 'mediter'),
        <String>{},
        reason: 'list-habits.search#5',
      );
    });

    test('substring match anywhere in any of the three fields', () {
      final running = buildHabit(
        name: 'Running',
        question: 'Did you run today?',
        description: 'daily jog',
      );
      final run10k = buildHabit(name: '10k Run');
      final habits = <Habit>[
        buildHabit(name: 'Yoga practice'),
        running,
        run10k,
        buildHabit(name: 'Méditer', description: 'mindfulness session'),
      ];

      expect(
        search(habits, 'run'),
        <String>{'Running', '10k Run'},
        reason: 'list-habits.search#6',
      );
      expect(
        search(habits, 'jog'),
        <String>{'Running'},
        reason: 'list-habits.search#6',
      );
      expect(
        search(habits, '10k'),
        <String>{'10k Run'},
        reason: 'list-habits.search#6',
      );
    });

    test('over-long queries match nothing; single characters match broadly',
        () {
      final habits = <Habit>[
        buildHabit(name: 'Yoga practice'),
        buildHabit(
          name: 'Running',
          question: 'Did you run today?',
          description: 'daily jog',
        ),
        buildHabit(name: 'Exercise', question: 'Did you do yoga today?'),
        buildHabit(name: 'Méditer', description: 'mindfulness session'),
        buildHabit(name: '🧘 Stretching'),
        buildHabit(name: '10k Run'),
      ];

      expect(
        search(habits, 'a' * 100),
        <String>{},
        reason: 'list-habits.search#7',
      );
      expect(
        search(habits, 'swimming'),
        <String>{},
        reason: 'list-habits.search#7',
      );
      expect(
        search(habits, 'y'),
        <String>{'Yoga practice', 'Running', 'Exercise'},
        reason: 'list-habits.search#7',
      );
    });

    test('search composes with the archived and completed filters', () {
      final f = Fixture();
      f.behavior.onSearchQueryChanged('yoga');

      final archivedYoga =
          buildHabit(name: 'Yoga practice', isArchived: true);
      final completedYoga = withTodayValue(
        buildHabit(name: 'Yoga evening'),
        Entry.yesManual,
      );
      final plainYoga = buildHabit(name: 'Yoga morning');

      expect(
        f.adapter.lastFilter.matches(archivedYoga),
        isFalse,
        reason: 'list-habits.search#8',
      );
      expect(
        f.adapter.lastFilter.matches(plainYoga),
        isTrue,
        reason: 'list-habits.search#8',
      );

      f.behavior.onToggleShowCompleted();
      expect(
        f.adapter.lastFilter.searchQuery,
        'yoga',
        reason: 'list-habits.search#8',
      );
      expect(
        f.adapter.lastFilter.matches(completedYoga),
        isFalse,
        reason: 'list-habits.search#8',
      );
      expect(
        f.adapter.lastFilter.matches(plainYoga),
        isTrue,
        reason: 'list-habits.search#8',
      );
      expect(
        f.adapter.lastFilter.matches(buildHabit(name: 'Swimming')),
        isFalse,
        reason: 'list-habits.search#8',
      );
    });
  });

  // =========================================================================
  // list-habits.sort-modes
  // =========================================================================

  group('list-habits.sort-modes', () {
    test('HabitList.Order has exactly nine values', () {
      expect(
        HabitListOrder.values,
        <HabitListOrder>[
          HabitListOrder.byNameAsc,
          HabitListOrder.byNameDesc,
          HabitListOrder.byColorAsc,
          HabitListOrder.byColorDesc,
          HabitListOrder.byScoreAsc,
          HabitListOrder.byScoreDesc,
          HabitListOrder.byStatusAsc,
          HabitListOrder.byStatusDesc,
          HabitListOrder.byPosition,
        ],
        reason: 'list-habits.sort-modes#1',
      );
      expect(
        HabitListOrder.values.length,
        9,
        reason: 'list-habits.sort-modes#1',
      );
    });

    test('onSortByManually sets BY_POSITION and never writes secondaryOrder',
        () {
      final f = Fixture(primaryOrder: HabitListOrder.byNameAsc);
      f.adapter.clearLog();
      f.behavior.onSortByManually();
      expect(
        f.adapter.primaryOrderWrites,
        <HabitListOrder>[HabitListOrder.byPosition],
        reason: 'list-habits.sort-modes#2',
      );
      expect(
        f.adapter.secondaryOrderWrites,
        isEmpty,
        reason: 'list-habits.sort-modes#2',
      );

      // Unconditional: it writes BY_POSITION again even when already there.
      f.adapter.clearLog();
      f.behavior.onSortByManually();
      expect(
        f.adapter.primaryOrderWrites,
        <HabitListOrder>[HabitListOrder.byPosition],
        reason: 'list-habits.sort-modes#2',
      );
      expect(
        f.adapter.secondaryOrderWrites,
        isEmpty,
        reason: 'list-habits.sort-modes#2',
      );
    });

    test('each sort entry has its own (default, reversed) pair', () {
      final pairs = <String, List<HabitListOrder>>{
        'name': <HabitListOrder>[
          HabitListOrder.byNameAsc,
          HabitListOrder.byNameDesc,
        ],
        'color': <HabitListOrder>[
          HabitListOrder.byColorAsc,
          HabitListOrder.byColorDesc,
        ],
        'score': <HabitListOrder>[
          HabitListOrder.byScoreDesc,
          HabitListOrder.byScoreAsc,
        ],
        'status': <HabitListOrder>[
          HabitListOrder.byStatusAsc,
          HabitListOrder.byStatusDesc,
        ],
      };

      void tap(ListHabitsMenuBehavior behavior, String entry) {
        switch (entry) {
          case 'name':
            behavior.onSortByName();
          case 'color':
            behavior.onSortByColor();
          case 'score':
            behavior.onSortByScore();
          case 'status':
            behavior.onSortByStatus();
        }
      }

      pairs.forEach((entry, orders) {
        final defaultOrder = orders[0];
        final reversedOrder = orders[1];

        // From an unrelated order, the first tap lands on the default order.
        final fresh = Fixture(primaryOrder: HabitListOrder.byPosition);
        tap(fresh.behavior, entry);
        expect(
          fresh.adapter.primaryOrderWrites,
          <HabitListOrder>[defaultOrder],
          reason: 'list-habits.sort-modes#3',
        );

        // Tapping again flips to the reversed order.
        fresh.adapter.clearLog();
        tap(fresh.behavior, entry);
        expect(
          fresh.adapter.primaryOrderWrites,
          <HabitListOrder>[reversedOrder],
          reason: 'list-habits.sort-modes#3',
        );

        // And once more flips back to the default order.
        fresh.adapter.clearLog();
        tap(fresh.behavior, entry);
        expect(
          fresh.adapter.primaryOrderWrites,
          <HabitListOrder>[defaultOrder],
          reason: 'list-habits.sort-modes#3',
        );
      });
    });

    test('toggle rule', () {
      // primaryOrder is neither the default nor the reversed order: the old
      // primary order is copied into secondaryOrder first.
      final unrelated = Fixture(primaryOrder: HabitListOrder.byColorDesc);
      unrelated.adapter.clearLog();
      unrelated.behavior.onSortByName();
      expect(
        unrelated.adapter.log,
        <String>['secondaryOrder=', 'primaryOrder='],
        reason: 'list-habits.sort-modes#4',
      );
      expect(
        unrelated.adapter.secondaryOrderWrites,
        <HabitListOrder>[HabitListOrder.byColorDesc],
        reason: 'list-habits.sort-modes#4',
      );
      expect(
        unrelated.adapter.primaryOrderWrites,
        <HabitListOrder>[HabitListOrder.byNameAsc],
        reason: 'list-habits.sort-modes#4',
      );

      // primaryOrder is the reversed order: primaryOrder goes to the default
      // order, but secondaryOrder is left alone.
      final reversed = Fixture(primaryOrder: HabitListOrder.byNameDesc);
      reversed.adapter.clearLog();
      reversed.behavior.onSortByName();
      expect(
        reversed.adapter.secondaryOrderWrites,
        isEmpty,
        reason: 'list-habits.sort-modes#4',
      );
      expect(
        reversed.adapter.primaryOrderWrites,
        <HabitListOrder>[HabitListOrder.byNameAsc],
        reason: 'list-habits.sort-modes#4',
      );

      // primaryOrder is already the default order: flip to reversed, leave
      // secondaryOrder alone.
      final already = Fixture(primaryOrder: HabitListOrder.byNameAsc);
      already.adapter.clearLog();
      already.behavior.onSortByName();
      expect(
        already.adapter.secondaryOrderWrites,
        isEmpty,
        reason: 'list-habits.sort-modes#4',
      );
      expect(
        already.adapter.primaryOrderWrites,
        <HabitListOrder>[HabitListOrder.byNameDesc],
        reason: 'list-habits.sort-modes#4',
      );
    });

    test('worked example: BY_NAME_ASC then two taps on By status', () {
      final f = Fixture(primaryOrder: HabitListOrder.byNameAsc);
      f.adapter.clearLog();

      f.behavior.onSortByStatus();
      expect(
        f.adapter.secondaryOrder,
        HabitListOrder.byNameAsc,
        reason: 'list-habits.sort-modes#5',
      );
      expect(
        f.adapter.primaryOrder,
        HabitListOrder.byStatusAsc,
        reason: 'list-habits.sort-modes#5',
      );

      f.adapter.clearLog();
      f.behavior.onSortByStatus();
      expect(
        f.adapter.primaryOrder,
        HabitListOrder.byStatusDesc,
        reason: 'list-habits.sort-modes#5',
      );
      expect(
        f.adapter.secondaryOrderWrites,
        isEmpty,
        reason: 'list-habits.sort-modes#5',
      );
    });

    test('ordering composes primary then secondary', () {
      final list = MemoryHabitList();
      final blueB = buildHabit(name: 'B', color: const PaletteColor(1));
      final blueA = buildHabit(name: 'A', color: const PaletteColor(1));
      final redC = buildHabit(name: 'C', color: const PaletteColor(0));
      list.add(blueB);
      list.add(blueA);
      list.add(redC);

      list.primaryOrder = HabitListOrder.byColorAsc;
      list.secondaryOrder = HabitListOrder.byNameAsc;
      expect(
        list.map((h) => h.name).toList(),
        <String>['C', 'A', 'B'],
        reason: 'list-habits.sort-modes#6',
      );

      list.secondaryOrder = HabitListOrder.byNameDesc;
      expect(
        list.map((h) => h.name).toList(),
        <String>['C', 'B', 'A'],
        reason: 'list-habits.sort-modes#6',
      );

      // The secondary order is consulted only when the primary one ties.
      list.primaryOrder = HabitListOrder.byNameAsc;
      list.secondaryOrder = HabitListOrder.byColorDesc;
      expect(
        list.map((h) => h.name).toList(),
        <String>['A', 'B', 'C'],
        reason: 'list-habits.sort-modes#6',
      );
    });

    test('position, name and color comparators', () {
      final list = MemoryHabitList();
      final zebra = buildHabit(
        name: 'Zebra',
        position: 2,
        color: const PaletteColor(7),
      );
      final apple = buildHabit(
        name: 'apple',
        position: 0,
        color: const PaletteColor(3),
      );
      final mango = buildHabit(
        name: 'Mango',
        position: 1,
        color: const PaletteColor(11),
      );
      list.add(zebra);
      list.add(apple);
      list.add(mango);

      list.primaryOrder = HabitListOrder.byPosition;
      expect(
        list.map((h) => h.name).toList(),
        <String>['apple', 'Mango', 'Zebra'],
        reason: 'list-habits.sort-modes#7',
      );

      // Plain compareTo: uppercase letters sort before lowercase ones.
      list.primaryOrder = HabitListOrder.byNameAsc;
      expect(
        list.map((h) => h.name).toList(),
        <String>['Mango', 'Zebra', 'apple'],
        reason: 'list-habits.sort-modes#7',
      );

      list.primaryOrder = HabitListOrder.byNameDesc;
      expect(
        list.map((h) => h.name).toList(),
        <String>['apple', 'Zebra', 'Mango'],
        reason: 'list-habits.sort-modes#7',
      );

      list.primaryOrder = HabitListOrder.byColorAsc;
      expect(
        list.map((h) => h.color.paletteIndex).toList(),
        <int>[3, 7, 11],
        reason: 'list-habits.sort-modes#7',
      );

      list.primaryOrder = HabitListOrder.byColorDesc;
      expect(
        list.map((h) => h.color.paletteIndex).toList(),
        <int>[11, 7, 3],
        reason: 'list-habits.sort-modes#7',
      );
    });

    test('BY_SCORE_DESC actually sorts ascending by score value', () {
      final today = getToday();
      final high = buildHabit(name: 'High');
      for (var i = 0; i < 60; i++) {
        high.originalEntries.add(Entry(today.minus(i), Entry.yesManual));
      }
      high.recompute();

      final low = buildHabit(name: 'Low');
      low.recompute();

      expect(
        high.scores[today].value > low.scores[today].value,
        isTrue,
        reason: 'list-habits.sort-modes#8',
      );

      final list = MemoryHabitList();
      list.add(high);
      list.add(low);

      list.primaryOrder = HabitListOrder.byScoreDesc;
      expect(
        list.map((h) => h.name).toList(),
        <String>['Low', 'High'],
        reason: 'list-habits.sort-modes#8',
      );

      list.primaryOrder = HabitListOrder.byScoreAsc;
      expect(
        list.map((h) => h.name).toList(),
        <String>['High', 'Low'],
        reason: 'list-habits.sort-modes#8',
      );
    });

    test('BY_STATUS_DESC: completed first, then numerical, then value', () {
      // Completed beats not-completed.
      final completed =
          withTodayValue(buildHabit(name: 'Completed'), Entry.yesManual);
      final pending = withTodayValue(buildHabit(name: 'Pending'), Entry.no);
      var list = MemoryHabitList();
      list.add(pending);
      list.add(completed);
      list.primaryOrder = HabitListOrder.byStatusDesc;
      expect(
        list.map((h) => h.name).toList(),
        <String>['Completed', 'Pending'],
        reason: 'list-habits.sort-modes#9',
      );
      list.primaryOrder = HabitListOrder.byStatusAsc;
      expect(
        list.map((h) => h.name).toList(),
        <String>['Pending', 'Completed'],
        reason: 'list-habits.sort-modes#9',
      );

      // Equally uncompleted: the numerical habit sorts first.
      final numerical = withTodayValue(
        buildHabit(
          name: 'Numerical',
          type: HabitType.numerical,
          targetType: NumericalHabitType.atLeast,
          targetValue: 100.0,
        ),
        1000,
      );
      final boolean = withTodayValue(buildHabit(name: 'Boolean'), Entry.no);
      expect(
        numerical.isCompletedToday(),
        isFalse,
        reason: 'list-habits.sort-modes#9',
      );
      list = MemoryHabitList();
      list.add(boolean);
      list.add(numerical);
      list.primaryOrder = HabitListOrder.byStatusDesc;
      expect(
        list.map((h) => h.name).toList(),
        <String>['Numerical', 'Boolean'],
        reason: 'list-habits.sort-modes#9',
      );
      list.primaryOrder = HabitListOrder.byStatusAsc;
      expect(
        list.map((h) => h.name).toList(),
        <String>['Boolean', 'Numerical'],
        reason: 'list-habits.sort-modes#9',
      );

      // Same completion and same numerical-ness: higher value first.
      final skipped = withTodayValue(buildHabit(name: 'Skipped'), Entry.skip);
      final checked =
          withTodayValue(buildHabit(name: 'Checked'), Entry.yesManual);
      list = MemoryHabitList();
      list.add(checked);
      list.add(skipped);
      list.primaryOrder = HabitListOrder.byStatusDesc;
      expect(
        list.map((h) => h.name).toList(),
        <String>['Skipped', 'Checked'],
        reason: 'list-habits.sort-modes#9',
      );
      list.primaryOrder = HabitListOrder.byStatusAsc;
      expect(
        list.map((h) => h.name).toList(),
        <String>['Checked', 'Skipped'],
        reason: 'list-habits.sort-modes#9',
      );
    });

    test('default order preferences', () {
      final storage = MemoryStorage();
      final prefs = Preferences(storage);

      expect(
        prefs.defaultPrimaryOrder,
        HabitListOrder.byPosition,
        reason: 'list-habits.sort-modes#10',
      );
      expect(
        prefs.defaultSecondaryOrder,
        HabitListOrder.byNameAsc,
        reason: 'list-habits.sort-modes#10',
      );

      prefs.defaultPrimaryOrder = HabitListOrder.byScoreDesc;
      expect(
        storage.getString('pref_default_order', ''),
        'BY_SCORE_DESC',
        reason: 'list-habits.sort-modes#10',
      );
      prefs.defaultSecondaryOrder = HabitListOrder.byColorAsc;
      expect(
        storage.getString('pref_default_secondary_order', ''),
        'BY_COLOR_ASC',
        reason: 'list-habits.sort-modes#10',
      );
      expect(
        prefs.defaultPrimaryOrder,
        HabitListOrder.byScoreDesc,
        reason: 'list-habits.sort-modes#10',
      );
      expect(
        prefs.defaultSecondaryOrder,
        HabitListOrder.byColorAsc,
        reason: 'list-habits.sort-modes#10',
      );

      storage.putString('pref_default_order', 'NOT_AN_ORDER');
      expect(
        prefs.defaultPrimaryOrder,
        HabitListOrder.byPosition,
        reason: 'list-habits.sort-modes#10',
      );
      expect(
        storage.getString('pref_default_order', ''),
        'BY_POSITION',
        reason: 'list-habits.sort-modes#10',
      );
    });

    test('reordering is rejected unless the primary order is BY_POSITION', () {
      final list = MemoryHabitList();
      final a = buildHabit(name: 'A', position: 0);
      final b = buildHabit(name: 'B', position: 1);
      list.add(a);
      list.add(b);

      list.primaryOrder = HabitListOrder.byNameAsc;
      expect(
        () => list.reorder(b, a),
        throwsA(isA<StateError>()),
        reason: 'list-habits.sort-modes#13',
      );

      list.primaryOrder = HabitListOrder.byPosition;
      list.reorder(b, a);
      expect(
        list.map((h) => h.name).toList(),
        <String>['B', 'A'],
        reason: 'list-habits.sort-modes#13',
      );
    });
  });

  // =========================================================================
  // list-habits.menu.overflow-items (presenter half only)
  // =========================================================================

  group('list-habits.menu.overflow-items', () {
    test('Add habit asks the screen for the habit-type dialog', () {
      final f = Fixture();
      f.behavior.onCreateHabit();
      expect(
        f.screen.log,
        <String>['showSelectHabitTypeDialog'],
        reason: 'list-habits.menu.overflow-items#6',
      );
    });

    test('Help & FAQ, About and Settings open their screens', () {
      final f = Fixture();
      f.behavior.onViewFAQ();
      f.behavior.onViewAbout();
      f.behavior.onViewSettings();
      expect(
        f.screen.log,
        <String>['showFAQScreen', 'showAboutScreen', 'showSettingsScreen'],
        reason: 'list-habits.menu.overflow-items#7',
      );
    });

    test('Hide archived and Hide completed toggle their filters', () {
      final f = Fixture();
      f.adapter.clearLog();

      f.behavior.onToggleShowArchived();
      expect(
        f.adapter.lastFilter.isArchivedAllowed,
        isTrue,
        reason: 'list-habits.menu.overflow-items#8 and '
            'settings.preferences.show-archived-completed#3 — pref_show_archived '
            'has no settings-screen row; the main-screen "Hide archived" item '
            'is what toggles it',
      );
      expect(
        f.preferences.showArchived,
        isTrue,
        reason: 'settings.preferences.show-archived-completed#3 — the filter '
            'menu item is the only writer of pref_show_archived',
      );
      f.behavior.onToggleShowCompleted();
      expect(
        f.adapter.lastFilter.isCompletedAllowed,
        isFalse,
        reason: 'list-habits.menu.overflow-items#8 and '
            'settings.preferences.show-archived-completed#3 — likewise '
            'pref_show_completed and "Hide completed"',
      );
      expect(
        f.preferences.showCompleted,
        isFalse,
        reason: 'settings.preferences.show-archived-completed#3',
      );
      expect(
        f.adapter.refreshCount,
        2,
        reason: 'list-habits.menu.overflow-items#8',
      );
    });

    test('a question-marks change recomputes the filter', () {
      final f = Fixture(showCompleted: false);
      expect(
        f.adapter.lastFilter,
        const HabitMatcher(isCompletedAllowed: false),
        reason: 'list-habits.menu.overflow-items#10',
      );

      f.adapter.clearLog();
      f.preferences.areQuestionMarksEnabled = true;
      f.behavior.onPreferencesChanged();
      expect(
        f.adapter.lastFilter,
        const HabitMatcher(isEnteredAllowed: false),
        reason: 'list-habits.menu.overflow-items#10 and '
            'settings.preferences.question-marks#7 — flipping the switch in '
            'settings reaches onPreferencesChanged(), which re-applies the '
            'adapter filter immediately (invalidateOptionsMenu() is the '
            'Android half and has no Flutter analogue)',
      );
      expect(
        f.adapter.log,
        <String>['setFilter', 'refresh'],
        reason: 'list-habits.menu.overflow-items#10 and '
            'settings.preferences.question-marks#7',
      );
    });

    // Not this slice's feature, but it is the last method on the behaviour:
    // see settings.theme.toggle-night-mode.
    test('Dark theme toggles the switcher and reapplies the theme', () {
      final f = Fixture();
      f.behavior.onToggleNightMode();
      expect(
        f.themeSwitcher.toggleCount,
        1,
        reason: 'settings.theme.toggle-night-mode#2',
      );
      expect(
        f.screen.log,
        <String>['applyTheme'],
        reason: 'settings.theme.toggle-night-mode#2',
      );
    });
  });
}
