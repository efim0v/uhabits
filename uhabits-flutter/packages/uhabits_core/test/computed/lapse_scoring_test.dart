import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';
import 'package:uhabits_core/src/computed/lapse_scoring.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';

void main() {
  late Habit habit;

  setUp(() => habit = MemoryModelFactory().buildHabit()..id = 1);

  test('abstinence halves, and says so', () {
    expect(
      applyLapseScoring(
        habit,
        const HabitDefinition(kind: ComputedKind.abstinence),
      ),
      isTrue,
      reason: 'computed.lapse-score#11',
    );
    expect(habit.scores.halvesOnLapse, isTrue,
        reason: 'computed.lapse-score#11');
  });

  test('no other kind halves', () {
    applyLapseScoring(habit, const HabitDefinition(kind: ComputedKind.sleep));
    expect(habit.scores.halvesOnLapse, isFalse,
        reason: 'computed.lapse-score#11');
  });

  test('a habit with no definition does not halve', () {
    applyLapseScoring(habit, null);
    expect(habit.scores.halvesOnLapse, isFalse,
        reason: 'computed.lapse-score#11');
  });

  test('the switch works in both directions', () {
    // Объект привычки переживает и снятие определения, и смену вида.
    // Включатель, умеющий только включаться, оставил бы бывшее воздержание с
    // чужой арифметикой до перезапуска.
    applyLapseScoring(
      habit,
      const HabitDefinition(kind: ComputedKind.abstinence),
    );
    applyLapseScoring(habit, null);
    expect(habit.scores.halvesOnLapse, isFalse,
        reason: 'computed.lapse-score#11');
  });
}
