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

    test(
        'same kind, committedFrom and payload but different committedAtMillis '
        'are not equal', () {
      const HabitDefinition a = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 9000,
        committedAtMillis: 1724832000000,
      );
      const HabitDefinition b = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 9000,
        committedAtMillis: 1724900000000,
      );

      expect(a == b, isFalse, reason: 'computed.definition#6');
    });

    test('a null committedAtMillis is not equal to a set one', () {
      const HabitDefinition a = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 9000,
      );
      const HabitDefinition b = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 9000,
        committedAtMillis: 1724832000000,
      );

      expect(a == b, isFalse, reason: 'computed.definition#6');
    });

    test('equal definitions including committedAtMillis have equal hash '
        'codes', () {
      const HabitDefinition a = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 9000,
        committedAtMillis: 1724832000000,
      );
      const HabitDefinition b = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 9000,
        committedAtMillis: 1724832000000,
      );

      expect(a, b, reason: 'computed.definition#6');
      expect(a.hashCode, b.hashCode, reason: 'computed.definition#6');
    });
  });

  group('HabitDefinition.copyWith', () {
    test('replaces committedAtMillis when given one', () {
      const HabitDefinition base = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedAtMillis: 1724832000000,
      );

      final HabitDefinition replaced =
          base.copyWith(committedAtMillis: 1724900000000);

      expect(replaced.committedAtMillis, 1724900000000,
          reason: 'computed.definition#11 — передан момент: поле заменяет '
              'прежнее значение');
    });

    test('leaves committedAtMillis alone when not given one', () {
      const HabitDefinition base = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedAtMillis: 1724832000000,
      );

      final HabitDefinition untouched =
          base.copyWith(payload: <String, Object?>{'allowance': 30});

      expect(untouched.committedAtMillis, 1724832000000,
          reason: 'computed.definition#11 — аргумент не передан вовсе: поле '
              'остаётся прежним, а не тем, что подставила бы `??` под '
              'явным null');
    });

    test('clears committedAtMillis when given an explicit null', () {
      // Требование задачи C: перенос дня обязательства назад обязан стирать
      // момент, записанный для другого дня (`computed.commitment#9`). Стереть
      // им было бы нельзя, если бы `null ?? this.committedAtMillis` читал
      // явную пустоту как «не передали» — а именно так вела бы себя эта
      // сигнатура при обычном `int? committedAtMillis`.
      const HabitDefinition base = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 8990,
        committedAtMillis: 1724832000000,
      );

      final HabitDefinition cleared =
          base.copyWith(committedFrom: 8960, committedAtMillis: null);

      expect(cleared.committedAtMillis, isNull,
          reason: 'computed.definition#11 — передан явный null: поле '
              'стирается, а не остаётся прежним значением');
      expect(cleared.committedFrom, 8960,
          reason: 'computed.definition#11 — стирание одного поля не мешает '
              'обычной замене другого в том же вызове');
    });
  });
}
