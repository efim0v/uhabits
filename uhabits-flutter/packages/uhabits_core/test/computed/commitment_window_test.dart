import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
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
  });
}
