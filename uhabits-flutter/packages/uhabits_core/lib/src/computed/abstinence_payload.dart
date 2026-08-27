/// Where an abstinence habit keeps its allowance, and in what.
///
/// The allowance belongs to the commitment, not to a day: it is set once in the
/// editor — "no more than 30 minutes" — and it applies to every day the
/// commitment covers, including days already recorded. Freezing it onto a lapse
/// row would leave a person who lowers their allowance with yesterday still
/// judged by the old one, and a person who raises it unable ever to forgive a
/// day already written. So the row carries the measured amount and this carries
/// the line it is measured against.
///
/// The unit is here for the same reason and one more: two rows in different
/// units are not comparable, so neither a sum nor a comparison with the
/// allowance would mean anything. It is named once.
library;

import 'habit_definition.dart';

/// Key under which the definition states how much one day may hold.
const String abstinenceAllowanceKey = 'allowance';

/// Key under which the definition states what it is all counted in.
const String abstinenceUnitKey = 'unit';

/// Counted in occurrences. With the default allowance of zero, any recorded
/// amount at all is a lapse — which is the "one tap" case.
const String abstinenceUnitCount = 'count';

/// Counted in minutes.
const String abstinenceUnitMinutes = 'minutes';

/// What a commitment allows until it says otherwise: nothing.
const double defaultAbstinenceAllowance = 0.0;

/// The payload of a commitment allowing [allowance] [unit]s a day.
///
/// `double`, not `int`: the editor's field is numeric with `decimal: true`,
/// `Habit.targetValue` is a `double`, and half a glass is an allowance somebody
/// will write. `LapseRepository.amount` — whole units — is a different quantity
/// in a different column.
///
/// An empty [unit] reads back as [abstinenceUnitCount] rather than being stored
/// as `''`: the unit is named once, and a caller that writes a bare
/// `unitController.text.trim()` would put in the database something other than
/// what `computed.allowance#2` promises.
Map<String, Object?> abstinencePayload({
  double allowance = defaultAbstinenceAllowance,
  String unit = abstinenceUnitCount,
}) =>
    <String, Object?>{
      abstinenceAllowanceKey: allowance,
      abstinenceUnitKey: unit.trim().isEmpty ? abstinenceUnitCount : unit,
    };

/// The allowance [definition] states, or [defaultAbstinenceAllowance] when it
/// states none, states a negative one, or states something that is not a
/// number.
///
/// Tolerant on purpose: the payload is JSON written by some build, and a value
/// of the wrong shape must not take the habit down. Falling back to zero is the
/// strict reading — every recorded amount is a lapse — which is the side to err
/// on for a promise.
double abstinenceAllowanceOf(HabitDefinition definition) {
  final Object? value = definition.payload[abstinenceAllowanceKey];
  if (value is! num) return defaultAbstinenceAllowance;
  final double allowance = value.toDouble();
  return allowance < 0 ? defaultAbstinenceAllowance : allowance;
}

/// The unit [definition] states, or [abstinenceUnitCount] when it states none.
String abstinenceUnitOf(HabitDefinition definition) {
  final Object? value = definition.payload[abstinenceUnitKey];
  return value is String && value.isNotEmpty ? value : abstinenceUnitCount;
}

/// Whether [amount], recorded for one day, breaks the promise [definition]
/// makes.
///
/// For the interface — the editor, its hints, anything that has to *say* where
/// a lapse begins. **Not** for scoring: the scoring loop lives in the ported
/// `ScoreList`, never sees a definition, and judges by
/// `normalizedRollingSum > targetValue`. There is exactly one judge, and it is
/// `Habit.targetValue`; this is the same comparison spelled for a reader
/// (`computed.allowance#1`, `computed.lapse-score#5`).
///
/// `>` and not `>=`: the condition is "no more than the allowance", so an
/// amount exactly equal to it is still keeping the promise.
bool isAbstinenceLapse(HabitDefinition definition, num amount) =>
    amount > abstinenceAllowanceOf(definition);
