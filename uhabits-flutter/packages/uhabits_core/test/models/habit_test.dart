import 'package:test/test.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/model_observable.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/score_list.dart';
import 'package:uhabits_core/src/models/streak_list.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitTest.kt
///
/// The Kotlin test builds habits through `modelFactory.buildHabit()`.
/// ModelFactory is a later slice, so [buildHabit] below does exactly what
/// `ModelFactory.buildHabit()` does: it hands Habit four freshly built
/// collaborators.

Habit buildHabit({
  EntryList? computedEntries,
  EntryList? originalEntries,
  ScoreList? scores,
  StreakList? streaks,
}) {
  return Habit(
    computedEntries: computedEntries ?? EntryList(),
    originalEntries: originalEntries ?? EntryList(),
    scores: scores ?? ScoreList(),
    streaks: streaks ?? StreakList(),
  );
}

/// Records the order in which Habit.recompute() drives its collaborators.
class CallLog {
  final List<String> calls = <String>[];
}

class SpyEntryList extends EntryList {
  SpyEntryList(this.log);

  final CallLog log;

  EntryList? capturedOriginalEntries;
  Frequency? capturedFrequency;
  bool? capturedIsNumerical;

  @override
  void recomputeFrom(
    EntryList originalEntries,
    Frequency frequency, {
    required bool isNumerical,
  }) {
    log.calls.add('computedEntries.recomputeFrom');
    capturedOriginalEntries = originalEntries;
    capturedFrequency = frequency;
    capturedIsNumerical = isNumerical;
    super.recomputeFrom(originalEntries, frequency, isNumerical: isNumerical);
  }
}

class SpyScoreList extends ScoreList {
  SpyScoreList(this.log);

  final CallLog log;

  Frequency? capturedFrequency;
  bool? capturedIsNumerical;
  NumericalHabitType? capturedNumericalHabitType;
  double? capturedTargetValue;
  List<Entry> Function(LocalDate, LocalDate)? capturedComputedEntries;
  LocalDate? capturedFrom;
  LocalDate? capturedTo;

  @override
  void recompute({
    required Frequency frequency,
    required bool isNumerical,
    required NumericalHabitType numericalHabitType,
    required double targetValue,
    required List<Entry> Function(LocalDate from, LocalDate to) computedEntries,
    required LocalDate from,
    required LocalDate to,
  }) {
    log.calls.add('scores.recompute');
    capturedFrequency = frequency;
    capturedIsNumerical = isNumerical;
    capturedNumericalHabitType = numericalHabitType;
    capturedTargetValue = targetValue;
    capturedComputedEntries = computedEntries;
    capturedFrom = from;
    capturedTo = to;
    super.recompute(
      frequency: frequency,
      isNumerical: isNumerical,
      numericalHabitType: numericalHabitType,
      targetValue: targetValue,
      computedEntries: computedEntries,
      from: from,
      to: to,
    );
  }
}

class SpyStreakList extends StreakList {
  SpyStreakList(this.log);

  final CallLog log;

  List<Entry> Function(LocalDate, LocalDate)? capturedEntries;
  LocalDate? capturedFrom;
  LocalDate? capturedTo;
  bool? capturedIsNumerical;
  double? capturedTargetValue;
  NumericalHabitType? capturedTargetType;

  @override
  void recompute(
    List<Entry> Function(LocalDate from, LocalDate to) getEntriesByInterval,
    LocalDate from,
    LocalDate to,
    bool isNumerical,
    double targetValue,
    NumericalHabitType targetType,
  ) {
    log.calls.add('streaks.recompute');
    capturedEntries = getEntriesByInterval;
    capturedFrom = from;
    capturedTo = to;
    capturedIsNumerical = isNumerical;
    capturedTargetValue = targetValue;
    capturedTargetType = targetType;
    super.recompute(
      getEntriesByInterval,
      from,
      to,
      isNumerical,
      targetValue,
      targetType,
    );
  }
}

/// A habit whose four collaborators are spies, so the arguments and the call
/// order of recompute() can be asserted.
class SpiedHabit {
  factory SpiedHabit() {
    final log = CallLog();
    final computed = SpyEntryList(log);
    final scores = SpyScoreList(log);
    final streaks = SpyStreakList(log);
    return SpiedHabit._(
      log,
      computed,
      scores,
      streaks,
      Habit(
        computedEntries: computed,
        originalEntries: EntryList(),
        scores: scores,
        streaks: streaks,
      ),
    );
  }

  SpiedHabit._(this.log, this.computed, this.scores, this.streaks, this.habit);

  final CallLog log;
  final SpyEntryList computed;
  final SpyScoreList scores;
  final SpyStreakList streaks;
  final Habit habit;
}

/// The hashCode formula of `models.habit-fields-defaults#9`, spelled out
/// independently of the implementation.
int expectedHashCode(Habit h) {
  var result = h.color.hashCode;
  result = 31 * result + h.description.hashCode;
  result = 31 * result + h.frequency.hashCode;
  result = 31 * result + (h.id?.hashCode ?? 0);
  result = 31 * result + h.isArchived.hashCode;
  result = 31 * result + h.name.hashCode;
  result = 31 * result + h.position;
  result = 31 * result + h.question.hashCode;
  result = 31 * result + (h.reminder?.hashCode ?? 0);
  result = 31 * result + h.targetType.value;
  result = 31 * result + h.targetValue.hashCode;
  result = 31 * result + h.type.value;
  result = 31 * result + h.unit.hashCode;
  result = 31 * result + (h.uuid?.hashCode ?? 0);
  return result;
}

void main() {
  late LocalDate today;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    today = getToday();
  });

  tearDown(resetToday);

  group('fields and defaults', () {
    test('default field values', () {
      final h = buildHabit();
      expect(h.color, const PaletteColor(8),
          reason: 'models.habit-fields-defaults#1');
      expect(h.description, '', reason: 'models.habit-fields-defaults#1');
      expect(h.frequency, Frequency.daily,
          reason: 'models.habit-fields-defaults#1');
      expect(h.frequency.numerator, 1, reason: 'models.habit-fields-defaults#1');
      expect(h.frequency.denominator, 1,
          reason: 'models.habit-fields-defaults#1');
      expect(h.id, isNull, reason: 'models.habit-fields-defaults#1');
      expect(h.isArchived, isFalse, reason: 'models.habit-fields-defaults#1');
      expect(h.name, '', reason: 'models.habit-fields-defaults#1');
      expect(h.position, 0, reason: 'models.habit-fields-defaults#1');
      expect(h.question, '', reason: 'models.habit-fields-defaults#1');
      expect(h.reminder, isNull, reason: 'models.habit-fields-defaults#1');
      expect(h.targetType, NumericalHabitType.atLeast,
          reason: 'models.habit-fields-defaults#1');
      expect(h.targetValue, 0.0, reason: 'models.habit-fields-defaults#1');
      expect(h.type, HabitType.yesNo, reason: 'models.habit-fields-defaults#1');
      expect(h.unit, '', reason: 'models.habit-fields-defaults#1');
    });

    test('uuid is generated when none is supplied', () {
      final uuid1 = buildHabit().uuid!;
      final uuid2 = buildHabit().uuid!;
      expect(uuid1, matches(RegExp(r'^[0-9a-f]{32}$')),
          reason: 'models.habit-fields-defaults#2');
      expect(uuid1.length, 32, reason: 'models.habit-fields-defaults#2');
      expect(uuid1.contains('-'), isFalse,
          reason: 'models.habit-fields-defaults#2');
      expect(uuid2, matches(RegExp(r'^[0-9a-f]{32}$')),
          reason: 'models.habit-fields-defaults#2');
      // Ported from HabitTest.testUuidGeneration.
      expect(uuid1, isNot(uuid2), reason: 'models.habit-fields-defaults#2');
    });

    test('a supplied uuid is kept as is', () {
      final h = Habit(
        uuid: 'ffffffffffffffffffffffffffffffff',
        computedEntries: EntryList(),
        originalEntries: EntryList(),
        scores: ScoreList(),
        streaks: StreakList(),
      );
      expect(h.uuid, 'ffffffffffffffffffffffffffffffff',
          reason: 'models.habit-fields-defaults#2');
    });

    test('holds four distinct collaborators', () {
      final computed = EntryList();
      final original = EntryList();
      final scores = ScoreList();
      final streaks = StreakList();
      final h = Habit(
        computedEntries: computed,
        originalEntries: original,
        scores: scores,
        streaks: streaks,
      );
      expect(identical(h.computedEntries, computed), isTrue,
          reason: 'models.habit-fields-defaults#3');
      expect(identical(h.originalEntries, original), isTrue,
          reason: 'models.habit-fields-defaults#3');
      expect(identical(h.scores, scores), isTrue,
          reason: 'models.habit-fields-defaults#3');
      expect(identical(h.streaks, streaks), isTrue,
          reason: 'models.habit-fields-defaults#3');
      // originalEntries is what the user edits; computedEntries is derived.
      h.originalEntries.add(Entry(today, Entry.yesManual));
      expect(h.computedEntries.get(today).value, Entry.unknown,
          reason: 'models.habit-fields-defaults#3');
      h.recompute();
      expect(h.computedEntries.get(today).value, Entry.yesManual,
          reason: 'models.habit-fields-defaults#3');
    });

    test('isNumerical follows type', () {
      final h = buildHabit();
      expect(h.isNumerical, isFalse, reason: 'models.habit-fields-defaults#4');
      h.type = HabitType.numerical;
      expect(h.isNumerical, isTrue, reason: 'models.habit-fields-defaults#4');
      h.type = HabitType.yesNo;
      expect(h.isNumerical, isFalse, reason: 'models.habit-fields-defaults#4');
    });

    test('uriString', () {
      // Ported from HabitTest.testURI.
      final h = buildHabit();
      h.id = 0;
      expect(h.uriString, 'content://org.isoron.uhabits/habit/0',
          reason: 'models.habit-fields-defaults#5');
      h.id = 17;
      expect(h.uriString, 'content://org.isoron.uhabits/habit/17',
          reason: 'models.habit-fields-defaults#5');
      h.id = null;
      expect(h.uriString, 'content://org.isoron.uhabits/habit/null',
          reason: 'models.habit-fields-defaults#5');
    });

    test('hasReminder', () {
      // Ported from HabitTest.test_hasReminder.
      final h = buildHabit();
      expect(h.hasReminder(), isFalse,
          reason: 'models.habit-fields-defaults#6');
      h.reminder = Reminder(8, 30, WeekdayList.everyDay);
      expect(h.hasReminder(), isTrue, reason: 'models.habit-fields-defaults#6');
      h.reminder = null;
      expect(h.hasReminder(), isFalse,
          reason: 'models.habit-fields-defaults#6');
    });

    test('observable is fresh per instance', () {
      final h1 = buildHabit();
      final h2 = buildHabit();
      expect(h1.observable, isNotNull,
          reason: 'models.habit-fields-defaults#7');
      expect(identical(h1.observable, h2.observable), isFalse,
          reason: 'models.habit-fields-defaults#7');
      var notified = 0;
      h1.observable.addListener(ModelObservableListener(() => notified++));
      h2.observable.notifyListeners();
      expect(notified, 0, reason: 'models.habit-fields-defaults#7');
      h1.observable.notifyListeners();
      expect(notified, 1, reason: 'models.habit-fields-defaults#7');
    });

    test('equals compares the model fields only', () {
      Habit template() {
        final h = buildHabit(computedEntries: EntryList());
        h.uuid = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        h.id = 5;
        return h;
      }

      expect(template(), template(), reason: 'models.habit-fields-defaults#8');

      final mutations = <String, void Function(Habit)>{
        'color': (h) => h.color = const PaletteColor(0),
        'description': (h) => h.description = 'x',
        'frequency': (h) => h.frequency = Frequency(3, 7),
        'id': (h) => h.id = 6,
        'isArchived': (h) => h.isArchived = true,
        'name': (h) => h.name = 'x',
        'position': (h) => h.position = 3,
        'question': (h) => h.question = 'x',
        'reminder': (h) =>
            h.reminder = Reminder(8, 30, WeekdayList.everyDay),
        'targetType': (h) => h.targetType = NumericalHabitType.atMost,
        'targetValue': (h) => h.targetValue = 100.0,
        'type': (h) => h.type = HabitType.numerical,
        'unit': (h) => h.unit = 'km',
        'uuid': (h) => h.uuid = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      };
      for (final entry in mutations.entries) {
        final mutated = template();
        entry.value(mutated);
        expect(mutated, isNot(template()),
            reason: 'models.habit-fields-defaults#8 (${entry.key})');
      }

      // The collaborators and the observable are deliberately ignored.
      final a = template();
      final b = template();
      a.originalEntries.add(Entry(today, Entry.yesManual));
      a.recompute();
      b.observable = ModelObservable();
      expect(a, b, reason: 'models.habit-fields-defaults#8');
      expect(a.computedEntries.get(today).value, Entry.yesManual,
          reason: 'models.habit-fields-defaults#8');
      expect(b.computedEntries.get(today).value, Entry.unknown,
          reason: 'models.habit-fields-defaults#8');

      final Object notAHabit = 'not a habit';
      expect(a == notAHabit, isFalse,
          reason: 'models.habit-fields-defaults#8');
      expect(a == a, isTrue, reason: 'models.habit-fields-defaults#8');
    });

    test('hashCode combines the same fourteen fields', () {
      final h = buildHabit();
      h.uuid = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      h.id = 5;
      h.color = const PaletteColor(3);
      h.description = 'desc';
      h.frequency = Frequency(3, 7);
      h.isArchived = true;
      h.name = 'name';
      h.position = 4;
      h.question = 'question?';
      h.reminder = Reminder(8, 30, WeekdayList.everyDay);
      h.targetType = NumericalHabitType.atMost;
      h.targetValue = 100.0;
      h.type = HabitType.numerical;
      h.unit = 'km';
      expect(h.hashCode, expectedHashCode(h),
          reason: 'models.habit-fields-defaults#9');

      // 0 stands in for null id, reminder and uuid.
      final n = buildHabit();
      n.uuid = null;
      n.id = null;
      n.reminder = null;
      expect(n.hashCode, expectedHashCode(n),
          reason: 'models.habit-fields-defaults#9');

      // Equal habits hash the same, whatever their collaborators hold.
      final a = buildHabit();
      a.uuid = 'cccccccccccccccccccccccccccccccc';
      final b = buildHabit();
      b.uuid = 'cccccccccccccccccccccccccccccccc';
      b.originalEntries.add(Entry(today, Entry.yesManual));
      b.recompute();
      expect(a.hashCode, b.hashCode, reason: 'models.habit-fields-defaults#9');
    });

    test('copyFrom copies everything except the id', () {
      // Ported from HabitTest.test_copyAttributes.
      final model = buildHabit();
      model.isArchived = true;
      model.color = const PaletteColor(0);
      model.frequency = Frequency(10, 20);
      model.reminder = Reminder(8, 30, WeekdayList(1));
      model.description = 'desc';
      model.id = 99;
      model.name = 'name';
      model.position = 4;
      model.question = 'question?';
      model.targetType = NumericalHabitType.atMost;
      model.targetValue = 100.0;
      model.type = HabitType.numerical;
      model.unit = 'km';

      final habit = buildHabit();
      habit.id = 7;
      final originalUuid = habit.uuid;
      habit.copyFrom(model);

      expect(habit.isArchived, model.isArchived,
          reason: 'models.habit-fields-defaults#10');
      expect(habit.color, model.color,
          reason: 'models.habit-fields-defaults#10');
      expect(habit.frequency, model.frequency,
          reason: 'models.habit-fields-defaults#10');
      expect(habit.reminder, model.reminder,
          reason: 'models.habit-fields-defaults#10');
      expect(habit.description, model.description,
          reason: 'models.habit-fields-defaults#10');
      expect(habit.name, model.name, reason: 'models.habit-fields-defaults#10');
      expect(habit.position, model.position,
          reason: 'models.habit-fields-defaults#10');
      expect(habit.question, model.question,
          reason: 'models.habit-fields-defaults#10');
      expect(habit.targetType, model.targetType,
          reason: 'models.habit-fields-defaults#10');
      expect(habit.targetValue, model.targetValue,
          reason: 'models.habit-fields-defaults#10');
      expect(habit.type, model.type, reason: 'models.habit-fields-defaults#10');
      expect(habit.unit, model.unit, reason: 'models.habit-fields-defaults#10');
      // The uuid IS copied.
      expect(habit.uuid, model.uuid,
          reason: 'models.habit-fields-defaults#10');
      expect(habit.uuid, isNot(originalUuid),
          reason: 'models.habit-fields-defaults#10');
      // The id is NOT copied.
      expect(habit.id, 7, reason: 'models.habit-fields-defaults#10');
    });

    test('HabitNotFoundException carries no message', () {
      final e = HabitNotFoundException();
      expect(() => throw e, throwsA(isA<HabitNotFoundException>()),
          reason: 'models.habit-fields-defaults#11');
      expect(e.toString().contains(':'), isFalse,
          reason: 'models.habit-fields-defaults#11');
    });
  });

  group('recompute', () {
    test('runs the three steps in order', () {
      final s = SpiedHabit();
      s.habit.originalEntries.add(Entry(today, Entry.yesManual));
      s.habit.recompute();
      expect(
        s.log.calls,
        <String>[
          'computedEntries.recomputeFrom',
          'scores.recompute',
          'streaks.recompute',
        ],
        reason: 'models.habit-recompute#1',
      );
      expect(identical(s.computed.capturedOriginalEntries,
              s.habit.originalEntries), isTrue,
          reason: 'models.habit-recompute#1');
      expect(s.computed.capturedFrequency, s.habit.frequency,
          reason: 'models.habit-recompute#1');
      expect(s.computed.capturedIsNumerical, isFalse,
          reason: 'models.habit-recompute#1');
      s.habit.type = HabitType.numerical;
      s.habit.recompute();
      expect(s.computed.capturedIsNumerical, isTrue,
          reason: 'models.habit-recompute#1');
    });

    test('window ends 30 days into the future', () {
      final s = SpiedHabit();
      s.habit.originalEntries.add(Entry(today, Entry.yesManual));
      s.habit.recompute();
      expect(s.scores.capturedTo, today.plus(30),
          reason: 'models.habit-recompute#2');
      expect(s.streaks.capturedTo, today.plus(30),
          reason: 'models.habit-recompute#2');
      expect(s.habit.scores[today.plus(30)].value, greaterThan(0.0),
          reason: 'models.habit-recompute#2');
    });

    test('window starts at the oldest computed entry', () {
      final s = SpiedHabit();
      s.habit.originalEntries.add(Entry(today.minus(10), Entry.yesManual));
      s.habit.originalEntries.add(Entry(today.minus(3), Entry.yesManual));
      s.habit.originalEntries.add(Entry(today, Entry.yesManual));
      s.habit.recompute();
      expect(s.scores.capturedFrom, today.minus(10),
          reason: 'models.habit-recompute#3');
      expect(s.streaks.capturedFrom, today.minus(10),
          reason: 'models.habit-recompute#3');
      expect(
        s.habit.computedEntries.getKnown().last.date,
        today.minus(10),
        reason: 'models.habit-recompute#3',
      );
    });

    test('window starts today when there are no entries', () {
      final s = SpiedHabit();
      s.habit.recompute();
      expect(s.habit.computedEntries.getKnown(), isEmpty,
          reason: 'models.habit-recompute#3');
      expect(s.scores.capturedFrom, today,
          reason: 'models.habit-recompute#3');
      expect(s.streaks.capturedFrom, today,
          reason: 'models.habit-recompute#3');
    });

    test('from is clamped to to when it is newer', () {
      final s = SpiedHabit();
      s.habit.type = HabitType.numerical;
      s.habit.originalEntries.add(Entry(today.plus(40), 1000));
      s.habit.recompute();
      expect(s.habit.computedEntries.getKnown().last.date, today.plus(40),
          reason: 'models.habit-recompute#4');
      expect(s.scores.capturedFrom, today.plus(30),
          reason: 'models.habit-recompute#4');
      expect(s.scores.capturedTo, today.plus(30),
          reason: 'models.habit-recompute#4');
      expect(s.streaks.capturedFrom, today.plus(30),
          reason: 'models.habit-recompute#4');
    });

    test('scores.recompute receives the habit configuration', () {
      final s = SpiedHabit();
      s.habit.type = HabitType.numerical;
      s.habit.targetType = NumericalHabitType.atMost;
      s.habit.targetValue = 100.0;
      s.habit.frequency = Frequency(3, 7);
      s.habit.originalEntries.add(Entry(today.minus(2), 50000));
      s.habit.recompute();
      expect(s.scores.capturedFrequency, Frequency(3, 7),
          reason: 'models.habit-recompute#5');
      expect(s.scores.capturedIsNumerical, isTrue,
          reason: 'models.habit-recompute#5');
      expect(s.scores.capturedNumericalHabitType, NumericalHabitType.atMost,
          reason: 'models.habit-recompute#5');
      expect(s.scores.capturedTargetValue, 100.0,
          reason: 'models.habit-recompute#5');
      expect(s.scores.capturedFrom, today.minus(2),
          reason: 'models.habit-recompute#5');
      expect(s.scores.capturedTo, today.plus(30),
          reason: 'models.habit-recompute#5');
      // The entries handed over are the COMPUTED ones, not the original ones.
      final from = s.scores.capturedFrom!;
      final to = s.scores.capturedTo!;
      expect(
        s.scores.capturedComputedEntries!(from, to),
        s.habit.computedEntries.getByInterval(from, to),
        reason: 'models.habit-recompute#5',
      );
    });

    test('streaks.recompute receives the habit configuration', () {
      final s = SpiedHabit();
      s.habit.type = HabitType.numerical;
      s.habit.targetType = NumericalHabitType.atMost;
      s.habit.targetValue = 100.0;
      s.habit.originalEntries.add(Entry(today.minus(2), 50000));
      s.habit.recompute();
      expect(s.streaks.capturedFrom, today.minus(2),
          reason: 'models.habit-recompute#6');
      expect(s.streaks.capturedTo, today.plus(30),
          reason: 'models.habit-recompute#6');
      expect(s.streaks.capturedIsNumerical, isTrue,
          reason: 'models.habit-recompute#6');
      expect(s.streaks.capturedTargetValue, 100.0,
          reason: 'models.habit-recompute#6');
      expect(s.streaks.capturedTargetType, NumericalHabitType.atMost,
          reason: 'models.habit-recompute#6');
      final from = s.streaks.capturedFrom!;
      final to = s.streaks.capturedTo!;
      expect(
        s.streaks.capturedEntries!(from, to),
        s.habit.computedEntries.getByInterval(from, to),
        reason: 'models.habit-recompute#6',
      );
    });

    test('nothing recomputes lazily', () {
      final h = buildHabit();
      h.originalEntries.add(Entry(today, Entry.yesManual));
      expect(h.computedEntries.get(today).value, Entry.unknown,
          reason: 'models.habit-recompute#7');
      expect(h.scores[today].value, 0.0, reason: 'models.habit-recompute#7');
      expect(h.streaks.getBest(10), isEmpty,
          reason: 'models.habit-recompute#7');
      h.recompute();
      expect(h.computedEntries.get(today).value, Entry.yesManual,
          reason: 'models.habit-recompute#7');
      final scoreBefore = h.scores[today].value;
      expect(scoreBefore, greaterThan(0.0),
          reason: 'models.habit-recompute#7');
      expect(h.streaks.getBest(10).length, 1,
          reason: 'models.habit-recompute#7');

      // Changing the frequency does not touch the already computed scores.
      h.frequency = Frequency(1, 7);
      expect(h.scores[today].value, scoreBefore,
          reason: 'models.habit-recompute#7');
      h.recompute();
      expect(h.scores[today].value, isNot(scoreBefore),
          reason: 'models.habit-recompute#7');

      // Same for targetValue on a numerical habit.
      final n = buildHabit();
      n.type = HabitType.numerical;
      n.targetValue = 100.0;
      n.originalEntries.add(Entry(today, 100000));
      n.recompute();
      final numericalScore = n.scores[today].value;
      n.targetValue = 1000000.0;
      expect(n.scores[today].value, numericalScore,
          reason: 'models.habit-recompute#7');
      n.recompute();
      expect(n.scores[today].value, lessThan(numericalScore),
          reason: 'models.habit-recompute#7');
    });

    test('results move when the day rolls over', () {
      final s = SpiedHabit();
      s.habit.originalEntries.add(Entry(today, Entry.yesManual));
      s.habit.recompute();
      expect(s.scores.capturedTo, today.plus(30),
          reason: 'models.habit-recompute#8');
      expect(s.habit.isCompletedToday(), isTrue,
          reason: 'models.habit-recompute#8');

      setToday(today.plus(1));
      s.habit.recompute();
      expect(s.scores.capturedTo, today.plus(31),
          reason: 'models.habit-recompute#8');
      expect(s.streaks.capturedTo, today.plus(31),
          reason: 'models.habit-recompute#8');
      expect(s.habit.isCompletedToday(), isFalse,
          reason: 'models.habit-recompute#8');

      // With no entries at all, the window start follows today as well.
      final empty = SpiedHabit();
      empty.habit.recompute();
      expect(empty.scores.capturedFrom, today.plus(1),
          reason: 'models.habit-recompute#8');
      setToday(today.plus(2));
      empty.habit.recompute();
      expect(empty.scores.capturedFrom, today.plus(2),
          reason: 'models.habit-recompute#8');
    });
  });

  group('isCompletedToday and isEnteredToday', () {
    test('both read the computed entry for today', () {
      final h = buildHabit();
      // An entry that has not been recomputed yet is invisible to both.
      h.originalEntries.add(Entry(today, Entry.yesManual));
      expect(h.isCompletedToday(), isFalse,
          reason: 'models.habit-completed-entered#1');
      expect(h.isEnteredToday(), isFalse,
          reason: 'models.habit-completed-entered#1');
      // Writing straight into computedEntries is enough for both.
      h.computedEntries.add(Entry(today, Entry.yesManual));
      expect(h.isCompletedToday(), isTrue,
          reason: 'models.habit-completed-entered#1');
      expect(h.isEnteredToday(), isTrue,
          reason: 'models.habit-completed-entered#1');
      // Yesterday's entry does not count for either.
      final other = buildHabit();
      other.computedEntries.add(Entry(today.minus(1), Entry.yesManual));
      expect(other.isCompletedToday(), isFalse,
          reason: 'models.habit-completed-entered#1');
      expect(other.isEnteredToday(), isFalse,
          reason: 'models.habit-completed-entered#1');
    });

    test('isEnteredToday is value != UNKNOWN', () {
      // Ported from HabitTest.test_isEntered.
      final h = buildHabit();
      expect(h.isEnteredToday(), isFalse,
          reason: 'models.habit-completed-entered#2');
      h.originalEntries.add(Entry(today, Entry.no));
      h.recompute();
      expect(h.isEnteredToday(), isTrue,
          reason: 'models.habit-completed-entered#2');

      for (final value in <int>[
        Entry.no,
        Entry.yesAuto,
        Entry.yesManual,
        Entry.skip,
      ]) {
        final e = buildHabit();
        e.computedEntries.add(Entry(today, value));
        expect(e.isEnteredToday(), isTrue,
            reason: 'models.habit-completed-entered#2 (value $value)');
      }
      final unknown = buildHabit();
      unknown.computedEntries.add(Entry(today, Entry.unknown));
      expect(unknown.isEnteredToday(), isFalse,
          reason: 'models.habit-completed-entered#2');
    });

    test('isCompletedToday for boolean habits', () {
      // Ported from HabitTest.test_isCompleted.
      final h = buildHabit();
      expect(h.isCompletedToday(), isFalse,
          reason: 'models.habit-completed-entered#3');
      h.originalEntries.add(Entry(today, Entry.yesManual));
      h.recompute();
      expect(h.isCompletedToday(), isTrue,
          reason: 'models.habit-completed-entered#3');

      for (final value in <int>[Entry.yesManual, Entry.yesAuto, Entry.skip]) {
        final c = buildHabit();
        c.computedEntries.add(Entry(today, value));
        expect(c.isCompletedToday(), isTrue,
            reason: 'models.habit-completed-entered#3 (value $value)');
      }
      for (final value in <int>[Entry.no, Entry.unknown]) {
        final c = buildHabit();
        c.computedEntries.add(Entry(today, value));
        expect(c.isCompletedToday(), isFalse,
            reason: 'models.habit-completed-entered#3 (value $value)');
      }
    });

    test('isCompletedToday for numerical AT_LEAST habits', () {
      final h = buildHabit();
      h.type = HabitType.numerical;
      h.targetType = NumericalHabitType.atLeast;
      h.targetValue = 100.0;
      h.computedEntries.add(Entry(today, 99999));
      expect(h.isCompletedToday(), isFalse,
          reason: 'models.habit-completed-entered#4');
      h.computedEntries.add(Entry(today, 100000));
      expect(h.isCompletedToday(), isTrue,
          reason: 'models.habit-completed-entered#4');
      h.computedEntries.add(Entry(today, 100001));
      expect(h.isCompletedToday(), isTrue,
          reason: 'models.habit-completed-entered#4');
      // The raw value is divided by 1000 with no special case for UNKNOWN, so
      // a target of zero is met by an explicit zero (0 / 1000 >= 0) but not by
      // a day with no entry at all (-1 / 1000 = -0.001).
      final zero = buildHabit();
      zero.type = HabitType.numerical;
      zero.targetValue = 0.0;
      zero.computedEntries.add(Entry(today, 0));
      expect(zero.isCompletedToday(), isTrue,
          reason: 'models.habit-completed-entered#4');
      final empty = buildHabit();
      empty.type = HabitType.numerical;
      empty.targetValue = 0.0;
      expect(empty.computedEntries.get(today).value, Entry.unknown,
          reason: 'models.habit-completed-entered#4');
      expect(empty.isCompletedToday(), isFalse,
          reason: 'models.habit-completed-entered#4');
    });

    test('isCompletedToday for numerical AT_MOST habits is always false', () {
      for (final value in <int>[Entry.unknown, 0, 50000, 100000, 200000]) {
        final h = buildHabit();
        h.type = HabitType.numerical;
        h.targetType = NumericalHabitType.atMost;
        h.targetValue = 100.0;
        h.computedEntries.add(Entry(today, value));
        expect(h.isCompletedToday(), isFalse,
            reason: 'models.habit-completed-entered#5 (value $value)');
      }
    });

    test('numerical completion, concrete', () {
      // Ported from HabitTest.test_isCompleted_numerical.
      final h = buildHabit();
      h.type = HabitType.numerical;
      h.targetType = NumericalHabitType.atLeast;
      h.targetValue = 100.0;
      expect(h.isCompletedToday(), isFalse,
          reason: 'models.habit-completed-entered#6');
      h.originalEntries.add(Entry(today, 200000));
      h.recompute();
      expect(h.isCompletedToday(), isTrue,
          reason: 'models.habit-completed-entered#6');
      h.originalEntries.add(Entry(today, 100000));
      h.recompute();
      expect(h.isCompletedToday(), isTrue,
          reason: 'models.habit-completed-entered#6');
      h.originalEntries.add(Entry(today, 50000));
      h.recompute();
      expect(h.isCompletedToday(), isFalse,
          reason: 'models.habit-completed-entered#6');
      h.targetType = NumericalHabitType.atMost;
      h.originalEntries.add(Entry(today, 200000));
      h.recompute();
      expect(h.isCompletedToday(), isFalse,
          reason: 'models.habit-completed-entered#6');
      h.originalEntries.add(Entry(today, 100000));
      h.recompute();
      expect(h.isCompletedToday(), isFalse,
          reason: 'models.habit-completed-entered#6');
      h.originalEntries.add(Entry(today, 50000));
      h.recompute();
      expect(h.isCompletedToday(), isFalse,
          reason: 'models.habit-completed-entered#6');
    });
  });
}
