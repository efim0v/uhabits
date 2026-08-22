import 'package:test/test.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_matcher.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/score_list.dart';
import 'package:uhabits_core/src/models/streak_list.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitMatcherTest.kt
///
/// The Kotlin test only exercises `searchQuery`; the non-search clauses of
/// `matches()` are covered here from HabitMatcher.kt itself (and from the
/// `getFiltered` fixtures in HabitListTest.kt, which build the same
/// archived/completed matchers).

/// The Kotlin test builds through `modelFactory.buildHabit()`; the in-memory
/// factory is a different slice, so the four collaborators are built directly
/// here. `MemoryModelFactory` supplies exactly these four plain instances.
Habit buildHabit({
  String name = '',
  String question = '',
  String description = '',
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
  return habit;
}

/// The Kotlin test compares habit *sets*; habits here are identified by name,
/// which is unique across the fixture.
Set<String> search(List<Habit> habits, String query) {
  final matcher = HabitMatcher(searchQuery: query);
  return habits.where(matcher.matches).map((h) => h.name).toSet();
}

void main() {
  setUp(() => setToday(LocalDate.ymd(2015, 1, 25)));
  tearDown(resetToday);

  group('construction', () {
    test('has the Kotlin data class defaults', () {
      const matcher = HabitMatcher();
      expect(
        matcher.isArchivedAllowed,
        isFalse,
        reason: 'models.habit-matcher#1',
      );
      expect(
        matcher.isReminderRequired,
        isFalse,
        reason: 'models.habit-matcher#1',
      );
      expect(
        matcher.isCompletedAllowed,
        isTrue,
        reason: 'models.habit-matcher#1',
      );
      expect(
        matcher.isEnteredAllowed,
        isTrue,
        reason: 'models.habit-matcher#1',
      );
      expect(matcher.searchQuery, '', reason: 'models.habit-matcher#1');
    });

    test('is an immutable value type', () {
      const a = HabitMatcher(isArchivedAllowed: true, searchQuery: 'yoga');
      const b = HabitMatcher(isArchivedAllowed: true, searchQuery: 'yoga');
      expect(a, equals(b), reason: 'models.habit-matcher#1');
      expect(a.hashCode, equals(b.hashCode), reason: 'models.habit-matcher#1');
      expect(
        a == const HabitMatcher(isArchivedAllowed: true, searchQuery: 'run'),
        isFalse,
        reason: 'models.habit-matcher#1',
      );
      expect(
        const HabitMatcher() == const HabitMatcher(isCompletedAllowed: false),
        isFalse,
        reason: 'models.habit-matcher#1',
      );
    });

    test('WITH_ALARM allows archived habits and requires a reminder', () {
      expect(
        HabitMatcher.withAlarm,
        equals(
          const HabitMatcher(isArchivedAllowed: true, isReminderRequired: true),
        ),
        reason: 'models.habit-matcher#8',
      );
      expect(
        HabitMatcher.withAlarm.isArchivedAllowed,
        isTrue,
        reason: 'models.habit-matcher#8',
      );
      expect(
        HabitMatcher.withAlarm.isReminderRequired,
        isTrue,
        reason: 'models.habit-matcher#8',
      );
      expect(
        HabitMatcher.withAlarm.isCompletedAllowed,
        isTrue,
        reason: 'models.habit-matcher#8',
      );
      expect(
        HabitMatcher.withAlarm.isEnteredAllowed,
        isTrue,
        reason: 'models.habit-matcher#8',
      );
      expect(
        HabitMatcher.withAlarm.searchQuery,
        '',
        reason: 'models.habit-matcher#8',
      );
    });
  });

  group('matches', () {
    test('the default matcher accepts an untouched habit', () {
      expect(
        const HabitMatcher().matches(buildHabit(name: 'Meditate')),
        isTrue,
        reason: 'models.habit-matcher#2',
      );
    });

    test('rejects archived habits unless isArchivedAllowed', () {
      final archived = buildHabit(name: 'Meditate')..isArchived = true;
      final active = buildHabit(name: 'Run');

      expect(
        const HabitMatcher().matches(archived),
        isFalse,
        reason: 'models.habit-matcher#2',
      );
      expect(
        const HabitMatcher().matches(active),
        isTrue,
        reason: 'models.habit-matcher#2',
      );
      expect(
        const HabitMatcher(isArchivedAllowed: true).matches(archived),
        isTrue,
        reason: 'models.habit-matcher#2',
      );
    });

    test('rejects habits without a reminder when isReminderRequired', () {
      final withReminder = buildHabit(name: 'Meditate')
        ..reminder = Reminder(8, 30, WeekdayList.everyDay);
      final withoutReminder = buildHabit(name: 'Run');

      expect(
        const HabitMatcher(isReminderRequired: true).matches(withoutReminder),
        isFalse,
        reason: 'models.habit-matcher#2',
      );
      expect(
        const HabitMatcher(isReminderRequired: true).matches(withReminder),
        isTrue,
        reason: 'models.habit-matcher#2',
      );
      expect(
        const HabitMatcher().matches(withoutReminder),
        isTrue,
        reason: 'models.habit-matcher#2',
      );
    });

    test('rejects habits completed today when !isCompletedAllowed', () {
      final today = getToday();
      final completed = buildHabit(name: 'Meditate')
        ..computedEntries.add(Entry(today, Entry.yesManual));
      final notCompleted = buildHabit(name: 'Run')
        ..computedEntries.add(Entry(today, Entry.no));

      expect(
        const HabitMatcher(isCompletedAllowed: false).matches(completed),
        isFalse,
        reason: 'models.habit-matcher#2',
      );
      expect(
        const HabitMatcher(isCompletedAllowed: false).matches(notCompleted),
        isTrue,
        reason: 'models.habit-matcher#2',
      );
      expect(
        const HabitMatcher().matches(completed),
        isTrue,
        reason: 'models.habit-matcher#2',
      );
    });

    test('rejects habits entered today when !isEnteredAllowed', () {
      final today = getToday();
      final entered = buildHabit(name: 'Run')
        ..computedEntries.add(Entry(today, Entry.no));
      final untouched = buildHabit(name: 'Swim');

      expect(
        const HabitMatcher(isEnteredAllowed: false).matches(entered),
        isFalse,
        reason: 'models.habit-matcher#2',
      );
      expect(
        const HabitMatcher(isEnteredAllowed: false).matches(untouched),
        isTrue,
        reason: 'models.habit-matcher#2',
      );
      expect(
        const HabitMatcher().matches(entered),
        isTrue,
        reason: 'models.habit-matcher#2',
      );
    });

    test('every clause is independent: any one of them can reject', () {
      final today = getToday();
      final habit = buildHabit(name: 'Meditate')
        ..isArchived = true
        ..reminder = Reminder(8, 30, WeekdayList.everyDay)
        ..computedEntries.add(Entry(today, Entry.yesManual));

      // Passes every clause only when all four flags allow it.
      expect(
        const HabitMatcher(
          isArchivedAllowed: true,
          isReminderRequired: true,
        ).matches(habit),
        isTrue,
        reason: 'models.habit-matcher#2',
      );
      expect(
        const HabitMatcher(
          isArchivedAllowed: true,
          isReminderRequired: true,
          isCompletedAllowed: false,
        ).matches(habit),
        isFalse,
        reason: 'models.habit-matcher#2',
      );
      expect(
        const HabitMatcher(
          isArchivedAllowed: true,
          isReminderRequired: true,
          isEnteredAllowed: false,
        ).matches(habit),
        isFalse,
        reason: 'models.habit-matcher#2',
      );
    });

    test('the search clause is applied on top of the other clauses', () {
      final archived = buildHabit(name: 'Yoga practice')..isArchived = true;
      expect(
        const HabitMatcher(searchQuery: 'yoga').matches(archived),
        isFalse,
        reason: 'models.habit-matcher#2',
      );
      expect(
        const HabitMatcher(
          isArchivedAllowed: true,
          searchQuery: 'yoga',
        ).matches(archived),
        isTrue,
        reason: 'models.habit-matcher#2',
      );
    });
  });

  group('search', () {
    late Habit yogaPractice;
    late Habit running;
    late Habit exercise;
    late Habit mediter;
    late Habit stretching;
    late Habit run10k;
    late List<Habit> habits;

    setUp(() {
      yogaPractice = buildHabit(name: 'Yoga practice');
      running = buildHabit(
        name: 'Running',
        question: 'Did you run today?',
        description: 'daily jog',
      );
      exercise = buildHabit(
        name: 'Exercise',
        question: 'Did you do yoga today?',
      );
      mediter = buildHabit(
        name: 'Méditer',
        description: 'mindfulness session',
      );
      stretching = buildHabit(name: '🧘 Stretching');
      run10k = buildHabit(name: '10k Run');
      habits = [
        yogaPractice,
        running,
        exercise,
        mediter,
        stretching,
        run10k,
      ];
    });

    test('an empty query skips the search filter entirely', () {
      expect(
        search(habits, ''),
        {
          'Yoga practice',
          'Running',
          'Exercise',
          'Méditer',
          '🧘 Stretching',
          '10k Run',
        },
        reason: 'models.habit-matcher#3',
      );
    });

    test('a whitespace-only query trims to empty and matches everything', () {
      expect(
        search(habits, '   '),
        {
          'Yoga practice',
          'Running',
          'Exercise',
          'Méditer',
          '🧘 Stretching',
          '10k Run',
        },
        reason: 'models.habit-matcher#3',
      );
      expect(
        search(habits, '\t\n '),
        {
          'Yoga practice',
          'Running',
          'Exercise',
          'Méditer',
          '🧘 Stretching',
          '10k Run',
        },
        reason: 'models.habit-matcher#3',
      );
    });

    test('leading and trailing whitespace is trimmed off the query', () {
      expect(
        search(habits, '  yoga  '),
        {'Yoga practice', 'Exercise'},
        reason: 'models.habit-matcher#3',
      );
    });

    test('matches the name, the question or the description', () {
      // Name only (Yoga practice) and question only (Exercise).
      expect(
        search(habits, 'yoga'),
        {'Yoga practice', 'Exercise'},
        reason: 'models.habit-matcher#4',
      );
      // Description only.
      expect(
        search(habits, 'jog'),
        {'Running'},
        reason: 'models.habit-matcher#4',
      );
      expect(
        search(habits, 'mindfulness session'),
        {'Méditer'},
        reason: 'models.habit-matcher#4',
      );
      // Substring, not prefix or whole word.
      expect(
        search(habits, 'ractic'),
        {'Yoga practice'},
        reason: 'models.habit-matcher#4',
      );
    });

    test('matching is case-insensitive in both directions', () {
      expect(
        search(habits, 'YOGA'),
        {'Yoga practice', 'Exercise'},
        reason: 'models.habit-matcher#4',
      );
      expect(
        search(habits, 'yOgA'),
        {'Yoga practice', 'Exercise'},
        reason: 'models.habit-matcher#4',
      );
      // Query in lower case, field in mixed case.
      expect(
        search(habits, 'exercise'),
        {'Exercise'},
        reason: 'models.habit-matcher#4',
      );
    });

    test('case folding does not strip accents', () {
      expect(
        search(habits, 'méditer'),
        {'Méditer'},
        reason: 'models.habit-matcher#5',
      );
      expect(
        search(habits, 'MÉDITER'),
        {'Méditer'},
        reason: 'models.habit-matcher#5',
      );
      expect(
        search(habits, 'mediter'),
        <String>{},
        reason: 'models.habit-matcher#5',
      );
    });

    test('emoji do not block matching and digits match', () {
      expect(
        search(habits, 'stretching'),
        {'🧘 Stretching'},
        reason: 'models.habit-matcher#6',
      );
      expect(
        search(habits, '🧘'),
        {'🧘 Stretching'},
        reason: 'models.habit-matcher#6',
      );
      expect(
        search(habits, '10k'),
        {'10k Run'},
        reason: 'models.habit-matcher#6',
      );
      expect(
        search(habits, '10K'),
        {'10k Run'},
        reason: 'models.habit-matcher#6',
      );
    });

    test('a query that fits no field matches nothing', () {
      expect(
        search(habits, 'a' * 100),
        <String>{},
        reason: 'models.habit-matcher#7',
      );
      expect(
        search(habits, 'swimming'),
        <String>{},
        reason: 'models.habit-matcher#7',
      );
    });

    test('the concrete fixture from HabitMatcherTest.kt', () {
      expect(
        search(habits, 'yoga'),
        {'Yoga practice', 'Exercise'},
        reason: 'models.habit-matcher#9',
      );
      expect(
        search(habits, 'run'),
        {'Running', '10k Run'},
        reason: 'models.habit-matcher#9',
      );
      expect(
        search(habits, 'jog'),
        {'Running'},
        reason: 'models.habit-matcher#9',
      );
      expect(
        search(habits, 'y'),
        {'Yoga practice', 'Running', 'Exercise'},
        reason: 'models.habit-matcher#9',
      );
    });
  });
}
