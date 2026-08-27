import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/abstinence_payload.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';

HabitDefinition withPayload(Map<String, Object?> payload) => HabitDefinition(
      kind: ComputedKind.abstinence,
      committedFrom: 9000,
      payload: payload,
    );

void main() {
  test('a bare commitment allows nothing, counted in occurrences', () {
    final HabitDefinition definition = withPayload(abstinencePayload());

    expect(abstinenceAllowanceOf(definition), 0.0,
        reason: 'computed.allowance#2');
    expect(abstinenceUnitOf(definition), abstinenceUnitCount,
        reason: 'computed.allowance#2');
    expect(isAbstinenceLapse(definition, 1), isTrue,
        reason: 'computed.allowance#2 — one tap is a lapse');
  });

  test('a lapse begins past the allowance, not at it', () {
    final HabitDefinition definition = withPayload(abstinencePayload(
        allowance: 30.0, unit: abstinenceUnitMinutes));

    expect(isAbstinenceLapse(definition, 29), isFalse,
        reason: 'computed.allowance#3');
    expect(isAbstinenceLapse(definition, 30), isFalse,
        reason: 'computed.allowance#3 — «не более допуска» keeps the promise');
    expect(isAbstinenceLapse(definition, 31), isTrue,
        reason: 'computed.allowance#3');
  });

  test('lowering the allowance re-judges days already recorded', () {
    // The whole reason the allowance is not frozen onto the row. The same
    // recorded amount is judged by whatever the commitment says now.
    final HabitDefinition lenient = withPayload(abstinencePayload(
        allowance: 30.0, unit: abstinenceUnitMinutes));
    final HabitDefinition strict = lenient.copyWith(
        payload: abstinencePayload(
            allowance: 10.0, unit: abstinenceUnitMinutes));

    expect(isAbstinenceLapse(lenient, 20), isFalse,
        reason: 'computed.allowance#1');
    expect(isAbstinenceLapse(strict, 20), isTrue,
        reason: 'computed.allowance#1 — the day is re-judged, not remembered');
  });

  test('a payload of a shape nobody knows reads as allowing nothing', () {
    // The payload is JSON some build wrote. A value of the wrong shape must
    // not take the habit down, and the safe side of a promise is the strict
    // one: allow nothing.
    for (final Object? junk in <Object?>[null, 'thirty', <int>[30], -5]) {
      final HabitDefinition definition = withPayload(<String, Object?>{
        abstinenceAllowanceKey: junk,
        abstinenceUnitKey: 7,
      });
      expect(abstinenceAllowanceOf(definition), 0.0,
          reason: 'computed.allowance#4');
      expect(abstinenceUnitOf(definition), abstinenceUnitCount,
          reason: 'computed.allowance#4');
    }
    expect(abstinenceUnitOf(withPayload(<String, Object?>{
          abstinenceUnitKey: '',
        })), abstinenceUnitCount,
        reason: 'computed.allowance#4');
  });

  test('a whole number and a fraction read as the same kind of number', () {
    // jsonDecode gives back 30 for one build's payload and 30.0 for another's,
    // and half a glass is an allowance somebody will write. All three are law.
    for (final Object? written in <Object?>[30, 30.0]) {
      expect(
          abstinenceAllowanceOf(withPayload(<String, Object?>{
            abstinenceAllowanceKey: written,
            abstinenceUnitKey: abstinenceUnitMinutes,
          })),
          30.0,
          reason: 'computed.allowance#4');
    }
    expect(
        abstinenceAllowanceOf(withPayload(<String, Object?>{
          abstinenceAllowanceKey: 0.5,
          abstinenceUnitKey: abstinenceUnitCount,
        })),
        0.5,
        reason: 'computed.allowance#4 — «полбокала» есть допуск, а не «ни '
            'капли»');
  });

  test('an empty unit is written as the named default, not as an empty string',
      () {
    // The payload goes into the database, and a reader that takes
    // `payload['unit']` straight would get `''` where the rule promises
    // `count`. The helper is the only writer, so it is the place to settle it.
    expect(abstinencePayload(unit: '')[abstinenceUnitKey], abstinenceUnitCount,
        reason: 'computed.allowance#2');
  });
}
