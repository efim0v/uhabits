import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';
import 'package:uhabits_core/src/computed/lapse_scoring.dart' show applyLapseScoring, abstinenceHalfLifeDays;
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

  test('the switch sets the growth curve as well as the halving', () {
    final Habit habit = MemoryModelFactory().buildHabit()..id = 1;

    applyLapseScoring(habit, const HabitDefinition(kind: ComputedKind.abstinence));

    expect(habit.scores.growthHalfLifeDays, abstinenceHalfLifeDays,
        reason: 'computed.lapse-score#15 — деление пополам и рост включаются '
            'вместе: одно без другого не имеет смысла');
  });

  test('the switch clears the growth curve for every other kind', () {
    final Habit habit = MemoryModelFactory().buildHabit()..id = 1;
    applyLapseScoring(habit, const HabitDefinition(kind: ComputedKind.abstinence));

    applyLapseScoring(habit, const HabitDefinition(kind: ComputedKind.sleep));

    expect(habit.scores.growthHalfLifeDays, isNull,
        reason: 'computed.lapse-score#16 — бывшее воздержание не остаётся с '
            'чужой кривой до перезапуска');
  });
}
