import 'dart:convert';

/// What kind of computation stands behind a habit.
///
/// The name goes to the database, so it is written out rather than derived
/// from the Dart identifier: renaming a field must never re-key a table.
enum ComputedKind {
  sleep('sleep'),
  abstinence('abstinence');

  const ComputedKind(this.wireName);

  final String wireName;

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

  final Map<String, Object?> payload;

  HabitDefinition copyWith(
          {int? committedFrom, Map<String, Object?>? payload}) =>
      HabitDefinition(
        kind: kind,
        committedFrom: committedFrom ?? this.committedFrom,
        payload: payload ?? this.payload,
      );

  String get encodedPayload => jsonEncode(payload);

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
      other.encodedPayload == encodedPayload;

  @override
  int get hashCode => Object.hash(kind, committedFrom, encodedPayload);

  @override
  String toString() =>
      'HabitDefinition(${kind.wireName}, from=$committedFrom, $payload)';
}
