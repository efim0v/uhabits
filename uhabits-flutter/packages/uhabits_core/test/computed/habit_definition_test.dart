import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';

void main() {
  group('HabitDefinition equality', () {
    test('different kind, same everything else, are not equal', () {
      const HabitDefinition a =
          HabitDefinition(kind: ComputedKind.sleep, committedFrom: 5);
      const HabitDefinition b =
          HabitDefinition(kind: ComputedKind.abstinence, committedFrom: 5);

      expect(a == b, isFalse, reason: 'computed.definition#6');
    });

    test('same kind but different committedFrom are not equal', () {
      const HabitDefinition a =
          HabitDefinition(kind: ComputedKind.sleep, committedFrom: 1);
      const HabitDefinition b =
          HabitDefinition(kind: ComputedKind.sleep, committedFrom: 2);

      expect(a == b, isFalse, reason: 'computed.definition#6');
    });

    test('same kind and committedFrom but different payload are not equal',
        () {
      const HabitDefinition a = HabitDefinition(
        kind: ComputedKind.sleep,
        payload: <String, Object?>{'allowance': 30},
      );
      const HabitDefinition b = HabitDefinition(
        kind: ComputedKind.sleep,
        payload: <String, Object?>{'allowance': 45},
      );

      expect(a == b, isFalse, reason: 'computed.definition#6');
    });

    test(
        'payloads built with the same keys in a different order compare '
        'equal, with the same hashCode', () {
      const HabitDefinition a = HabitDefinition(
        kind: ComputedKind.abstinence,
        payload: <String, Object?>{'allowance': 30, 'unit': 'min'},
      );
      const HabitDefinition b = HabitDefinition(
        kind: ComputedKind.abstinence,
        payload: <String, Object?>{'unit': 'min', 'allowance': 30},
      );

      expect(a, b, reason: 'computed.definition#6');
      expect(a.hashCode, b.hashCode, reason: 'computed.definition#6');
    });

    test('equal definitions have equal hash codes', () {
      const HabitDefinition a = HabitDefinition(
        kind: ComputedKind.sleep,
        committedFrom: 9000,
        payload: <String, Object?>{'allowance': 30, 'unit': 'min'},
      );
      const HabitDefinition b = HabitDefinition(
        kind: ComputedKind.sleep,
        committedFrom: 9000,
        payload: <String, Object?>{'allowance': 30, 'unit': 'min'},
      );

      expect(a, b, reason: 'computed.definition#6');
      expect(a.hashCode, b.hashCode, reason: 'computed.definition#6');
    });
  });
}
