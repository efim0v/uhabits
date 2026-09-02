import 'dart:convert';

/// What kind of computation stands behind a habit.
///
/// The name goes to the database, so it is written out rather than derived
/// from the Dart identifier: renaming a field must never re-key a table.
enum ComputedKind {
  sleep('sleep', silenceQualifies: false),
  abstinence('abstinence', silenceQualifies: true);

  const ComputedKind(this.wireName, {required this.silenceQualifies});

  final String wireName;

  /// Считается ли день, о котором ничего не записано, удавшимся.
  ///
  /// Свойство вида, а не привычки: непрослеженная ночь — не хорошая ночь, а
  /// день, в который человек не отметил срыв, — это ровно тот день, ради
  /// которого он и обязался. В базу не идёт: туда идёт только [wireName].
  final bool silenceQualifies;

  /// Null for a name this build does not know — a file written by a newer
  /// one. Guessing would be worse than admitting there is nothing here.
  static ComputedKind? fromWire(String name) {
    for (final ComputedKind kind in values) {
      if (kind.wireName == name) return kind;
    }
    return null;
  }
}

/// The mark that says a habit's day value is computed, and by what.
///
/// Deliberately thin. It is a marker first and a container second: the
/// parameters of a kind live wherever that kind already keeps them — sleep
/// keeps its own in `SleepGoals` — and [payload] is for kinds that have
/// nowhere else to put a handful of numbers.
class HabitDefinition {
  const HabitDefinition({
    required this.kind,
    this.committedFrom,
    this.committedAtMillis,
    this.payload = const <String, Object?>{},
  });

  final ComputedKind kind;

  /// The day the person committed, as `daysSince2000`, or null when the kind
  /// has no such moment.
  ///
  /// It exists because the recompute range cannot be taken from the entries: a
  /// habit that records nothing while it is being kept — which is exactly what
  /// an abstinence habit does — has no oldest entry to start from.
  final int? committedFrom;

  /// Момент обязательства в миллисекундах эпохи, или null, когда он неизвестен.
  ///
  /// Неизвестность — не полночь [committedFrom]: так честно выглядит
  /// определение, записанное до миграции 105, или приехавшее из чужой копии,
  /// которая этой колонки ещё не знала. Тот же выбор уже сделан для срыва —
  /// там null тоже значит «неизвестно», а не «полночь» (`computed.schema#9`,
  /// `computed.schema#11`).
  final int? committedAtMillis;

  /// A flat map of scalars — numbers, strings, booleans, null — for a kind
  /// that has nowhere else of its own to keep a handful of values.
  ///
  /// "Flat" is load-bearing: [encodedPayload] sorts this map's own keys so
  /// that two payloads built in a different order — which different call
  /// sites will do — compare equal, but it does not walk into a nested map or
  /// list to sort that too. A kind that needs more structure than a flat map
  /// gives it should not put it here.
  final Map<String, Object?> payload;

  HabitDefinition copyWith(
          {int? committedFrom,
          int? committedAtMillis,
          Map<String, Object?>? payload}) =>
      HabitDefinition(
        kind: kind,
        committedFrom: committedFrom ?? this.committedFrom,
        committedAtMillis: committedAtMillis ?? this.committedAtMillis,
        payload: payload ?? this.payload,
      );

  /// [payload], as JSON with its keys sorted.
  ///
  /// The sort makes this a function of the payload's content rather than of
  /// the order it happened to be built in, which is what lets `==` and
  /// [hashCode] — both built from this string — treat `{'x': 1, 'y': 2}` and
  /// `{'y': 2, 'x': 1}` as the same value. It is also what gets persisted, so
  /// the stored bytes get the same benefit: two saves of an equal payload
  /// write identical rows.
  String get encodedPayload {
    final List<String> sortedKeys = payload.keys.toList()..sort();
    final Map<String, Object?> sorted = <String, Object?>{
      for (final String key in sortedKeys) key: payload[key],
    };
    return jsonEncode(sorted);
  }

  static Map<String, Object?> decodePayload(String encoded) {
    if (encoded.isEmpty) return const <String, Object?>{};
    final Object? decoded = jsonDecode(encoded);
    return decoded is Map<String, Object?> ? decoded : const <String, Object?>{};
  }

  @override
  bool operator ==(Object other) =>
      other is HabitDefinition &&
      other.kind == kind &&
      other.committedFrom == committedFrom &&
      other.committedAtMillis == committedAtMillis &&
      other.encodedPayload == encodedPayload;

  @override
  int get hashCode =>
      Object.hash(kind, committedFrom, committedAtMillis, encodedPayload);

  @override
  String toString() => 'HabitDefinition(${kind.wireName}, '
      'from=$committedFrom, at=$committedAtMillis, $payload)';
}
