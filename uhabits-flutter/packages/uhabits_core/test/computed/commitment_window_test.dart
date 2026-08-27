import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/streak.dart';
import 'package:uhabits_core/src/time/local_date.dart';

void main() {
  late LocalDate today;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    today = getToday();
  });

  tearDown(resetToday);

  Habit buildHabit() => MemoryModelFactory().buildHabit();

  group('computed.commitment', () {
    Habit buildAbstinence({required int committedFrom}) => buildHabit()
      ..name = 'No sugar'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0.0
      ..definition = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: committedFrom,
      );

    test('#4 a fresh habit carries no definition', () {
      expect(buildHabit().definition, isNull, reason: 'computed.commitment#4');
    });

    test('#4 the definition is outside equality, hashCode and copyFrom', () {
      final Habit plain = buildHabit()..name = 'No sugar';
      final Habit marked = buildHabit()
        ..name = 'No sugar'
        ..uuid = plain.uuid
        ..definition = HabitDefinition(
          kind: ComputedKind.abstinence,
          committedFrom: today.minus(40).daysSince2000,
        );

      expect(marked, plain, reason: 'computed.commitment#4');
      expect(marked.hashCode, plain.hashCode, reason: 'computed.commitment#4');

      // copyFrom не переносит его ни туда, ни обратно: форма редактирования
      // собирает привычку-черновик без определения, и её копирование в живую
      // стёрло бы день обязательства.
      marked.copyFrom(plain);
      expect(marked.definition?.committedFrom, today.minus(40).daysSince2000,
          reason: 'computed.commitment#4');
      plain.copyFrom(marked);
      expect(plain.definition, isNull, reason: 'computed.commitment#4');
    });

    test('#1 a kind says whether silence is success', () {
      expect(ComputedKind.abstinence.silenceQualifies, isTrue,
          reason: 'computed.streak#1');
      expect(ComputedKind.sleep.silenceQualifies, isFalse,
          reason: 'computed.streak#1');
    });

    test('#1 forty clean days before the first lapse exist', () {
      final Habit habit =
          buildAbstinence(committedFrom: today.minus(40).daysSince2000);
      habit.recompute();

      // Ни одной записи — и всё равно есть серия, и она начинается в день
      // решения, а не сегодня.
      expect(habit.computedEntries.getKnown(), isEmpty,
          reason: 'computed.commitment#1');
      final Streak? current = habit.streaks.getCurrent(today);
      expect(current?.start, today.minus(40), reason: 'computed.commitment#1');
    });

    test('#1 the scores of those forty days exist too', () {
      final Habit habit =
          buildAbstinence(committedFrom: today.minus(40).daysSince2000);
      habit.recompute();

      // За день вне посчитанного окна ScoreList отдаёт ноль, так что
      // ненулевой балл сорока днями раньше и есть доказательство, что окно
      // туда дотянулось. Сегодняшний — контраст: он ненулевой всегда.
      expect(habit.scores[today].value, greaterThan(0.0),
          reason: 'computed.commitment#1');
      expect(habit.scores[today.minus(40)].value, greaterThan(0.0),
          reason: 'computed.commitment#1');
    });

    test('#2 the commitment day is the whole lower bound, in both directions',
        () {
      final Habit habit =
          buildAbstinence(committedFrom: today.minus(10).daysSince2000);
      habit.originalEntries.add(Entry(today.minus(50), 1000));
      habit.recompute();

      // Срыв старше дня обязательства — это день, о котором обязательства ещё
      // не было. Серия начинается в день решения, а не сорока днями раньше:
      // иначе счётчик говорил бы «49 дней без срыва» под подписью «С <день
      // обязательства>», которой десять.
      final Streak? current = habit.streaks.getCurrent(today);
      expect(current?.start, today.minus(10), reason: 'computed.commitment#2');

      // И оценки за те дни не существует: балл вне посчитанного окна есть
      // ноль, и старый срыв ничего не делит пополам. Сегодняшний — контраст,
      // он ненулевой.
      expect(habit.scores[today].value, greaterThan(0.0),
          reason: 'computed.commitment#2');
      expect(habit.scores[today.minus(40)].value, 0.0,
          reason: 'computed.commitment#2');
    });

    test('#3 a habit without a definition keeps the ported window', () {
      final Habit habit = buildHabit()
        ..type = HabitType.numerical
        ..targetType = NumericalHabitType.atMost
        ..targetValue = 0.0;
      habit.recompute();

      // Записей нет — значит граница сегодня, и сорока днями раньше баллов не
      // существует вовсе. Сегодняшний балл ненулевой, так что ноль сорока
      // днями раньше говорит про границу окна, а не про пустой список.
      expect(habit.scores[today].value, greaterThan(0.0),
          reason: 'computed.commitment#3');
      expect(habit.scores[today.minus(40)].value, 0.0,
          reason: 'computed.commitment#3');
      expect(habit.streaks.getBest(10), isEmpty,
          reason: 'computed.commitment#3');

      // И вид без дня обязательства — тоже: у сна committedFrom есть null.
      habit.definition = const HabitDefinition(kind: ComputedKind.sleep);
      habit.recompute();
      expect(habit.scores[today].value, greaterThan(0.0),
          reason: 'computed.commitment#3');
      expect(habit.scores[today.minus(40)].value, 0.0,
          reason: 'computed.commitment#3');
      expect(habit.streaks.getBest(10), isEmpty,
          reason: 'computed.commitment#3');
    });
  });
}
