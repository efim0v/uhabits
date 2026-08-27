import 'dart:math' as math;

import '../computed/habit_definition.dart';
import '../time/local_date.dart';
import 'entry.dart';
import 'entry_list.dart';
import 'frequency.dart';
import 'habit_type.dart';
import 'model_observable.dart';
import 'palette_color.dart';
import 'reminder.dart';
import 'score_list.dart';
import 'streak_list.dart';

/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Habit.kt
///
/// Kotlin declares this as a `data class` whose fourteen model fields are all
/// `var` with defaults, plus four `val` collaborators with none; the Dart port
/// keeps the same split, with the collaborators as required named arguments
/// because `ModelFactory.buildHabit()` is the only thing that supplies them.
///
/// `equals`/`hashCode` are hand written in Kotlin too: they cover the fourteen
/// model fields and deliberately ignore [computedEntries], [originalEntries],
/// [scores], [streaks] and [observable] — and [definition], which the Kotlin
/// data class does not have at all.
class Habit {
  Habit({
    this.color = const PaletteColor(8),
    this.description = '',
    this.frequency = Frequency.daily,
    this.id,
    this.isArchived = false,
    this.name = '',
    this.position = 0,
    this.question = '',
    this.reminder,
    this.targetType = NumericalHabitType.atLeast,
    this.targetValue = 0.0,
    this.type = HabitType.yesNo,
    this.unit = '',
    this.uuid,
    required this.computedEntries,
    required this.originalEntries,
    required this.scores,
    required this.streaks,
  }) {
    // Kotlin's `init` block: `if (uuid == null) this.uuid = Uuid.random()
    // .toHexString()`.
    uuid ??= _randomUuidHexString();
  }

  PaletteColor color;

  String description;

  Frequency frequency;

  int? id;

  bool isArchived;

  String name;

  int position;

  String question;

  Reminder? reminder;

  NumericalHabitType targetType;

  double targetValue;

  HabitType type;

  String unit;

  String? uuid;

  /// The entries derived from [originalEntries] by [recompute]; this is what
  /// every chart and predicate reads.
  final EntryList computedEntries;

  /// The entries the user actually edited.
  final EntryList originalEntries;

  final ScoreList scores;

  final StreakList streaks;

  /// Kotlin declares this as `var observable = ModelObservable()`, so it is a
  /// fresh observable per habit and can be replaced.
  ModelObservable observable = ModelObservable();

  /// Определение, по которому приложение считает дни этой привычки, или null
  /// у обычной.
  ///
  /// Едет на модели, а не спрашивается у репозитория, потому что [recompute]
  /// зовут пятнадцать мест — команды, импорт, смена суток, — и ни одно из них
  /// репозитория не видит. Прикрепляется одной дверью,
  /// `computed/attach_definition.dart`.
  ///
  /// Не участвует ни в [==], ни в [hashCode], ни в [copyFrom] — ровно как
  /// четыре сотрудника выше. Для `copyFrom` это не только паритет:
  /// `EditHabitCommand` делает `habit.copyFrom(modified)`, где `modified`
  /// собран формой и определения не несёт, так что копирование стирало бы
  /// день обязательства живой привычки (`computed.commitment#4`).
  HabitDefinition? definition;

  bool get isNumerical => type == HabitType.numerical;

  String get uriString => 'content://org.isoron.uhabits/habit/$id';

  bool hasReminder() => reminder != null;

  bool isCompletedToday() {
    final today = getToday();
    final value = computedEntries.get(today).value;
    if (isNumerical) {
      switch (targetType) {
        case NumericalHabitType.atLeast:
          return value / 1000.0 >= targetValue;
        case NumericalHabitType.atMost:
          return false;
      }
    } else {
      return value != Entry.no && value != Entry.unknown;
    }
  }

  bool isEnteredToday() {
    final today = getToday();
    final value = computedEntries.get(today).value;
    return value != Entry.unknown;
  }

  /// Rebuilds [computedEntries], then [scores], then [streaks].
  ///
  /// Nothing here is lazy: callers must invoke this after every change to
  /// [originalEntries], [frequency], [type], [targetType] or [targetValue].
  ///
  /// Kotlin passes the `EntryList` itself to `scores.recompute` and
  /// `streaks.recompute`; the Dart ScoreList and StreakList take the
  /// `getByInterval` callable instead, so it is passed as a tear-off.
  void recompute() {
    computedEntries.recomputeFrom(
      originalEntries,
      frequency,
      isNumerical: isNumerical,
    );

    final today = getToday();
    final to = today.plus(30);
    final entries = computedEntries.getKnown();
    var from = entries.isEmpty ? today : entries.last.date;
    // Расширение: у вычисляемой привычки нижняя граница не опирается на
    // записи вовсе. Привычка, которая ничего не пишет, пока её держат,
    // старейшей записи не имеет, и её сорок чистых дней не существовали бы
    // (`computed.commitment#1`). День обязательства задаёт границу целиком, в
    // обе стороны: запись старше него — это день, о котором обязательства
    // ещё не было, и он не вправе ни начинать серию, ни делить оценку
    // пополам. Перенесённый вперёд день обязательства иначе разводил бы
    // счётчик с подписью под ним: «40 дней без срыва / С 1 августа» при
    // девятнадцати прошедших днях (`computed.commitment#2`).
    final int? committedFrom = definition?.committedFrom;
    if (committedFrom != null) from = LocalDate(committedFrom);
    if (from.isNewerThan(to)) from = to;

    scores.recompute(
      frequency: frequency,
      isNumerical: isNumerical,
      numericalHabitType: targetType,
      targetValue: targetValue,
      computedEntries: computedEntries.getByInterval,
      from: from,
      to: to,
    );

    streaks.recompute(
      computedEntries.getByInterval,
      from,
      to,
      isNumerical,
      targetValue,
      targetType,
      // Молчание — свойство вида, а не привычки: у сна непрослеженная ночь не
      // хорошая ночь, у воздержания день без отметки и есть тот день, ради
      // которого обязывались (`computed.streak#1`).
      silenceQualifies: definition?.kind.silenceQualifies ?? false,
    );
  }

  /// Copies every model field of [other] except the id. The uuid IS copied.
  void copyFrom(Habit other) {
    color = other.color;
    description = other.description;
    frequency = other.frequency;
    // id should not be copied
    isArchived = other.isArchived;
    name = other.name;
    position = other.position;
    question = other.question;
    reminder = other.reminder;
    targetType = other.targetType;
    targetValue = other.targetValue;
    type = other.type;
    unit = other.unit;
    uuid = other.uuid;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Habit) return false;

    if (color != other.color) return false;
    if (description != other.description) return false;
    if (frequency != other.frequency) return false;
    if (id != other.id) return false;
    if (isArchived != other.isArchived) return false;
    if (name != other.name) return false;
    if (position != other.position) return false;
    if (question != other.question) return false;
    if (reminder != other.reminder) return false;
    if (targetType != other.targetType) return false;
    if (targetValue != other.targetValue) return false;
    if (type != other.type) return false;
    if (unit != other.unit) return false;
    if (uuid != other.uuid) return false;

    return true;
  }

  /// The Kotlin `31 * result + field.hashCode()` chain, field for field. The
  /// individual hash values differ from the JVM's (Dart computes its own), and
  /// the multiplication wraps at 64 bits here rather than 32; what is ported is
  /// the set of fields and the way they are combined.
  @override
  int get hashCode {
    var result = color.hashCode;
    result = 31 * result + description.hashCode;
    result = 31 * result + frequency.hashCode;
    result = 31 * result + (id?.hashCode ?? 0);
    result = 31 * result + isArchived.hashCode;
    result = 31 * result + name.hashCode;
    result = 31 * result + position;
    result = 31 * result + question.hashCode;
    result = 31 * result + (reminder?.hashCode ?? 0);
    result = 31 * result + targetType.value;
    result = 31 * result + targetValue.hashCode;
    result = 31 * result + type.value;
    result = 31 * result + unit.hashCode;
    result = 31 * result + (uuid?.hashCode ?? 0);
    return result;
  }

  @override
  String toString() => 'Habit(color=$color, description=$description, '
      'frequency=$frequency, id=$id, isArchived=$isArchived, name=$name, '
      'position=$position, question=$question, reminder=$reminder, '
      'targetType=$targetType, targetValue=$targetValue, type=$type, '
      'unit=$unit, uuid=$uuid)';
}

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitNotFoundException.kt
///
/// `class HabitNotFoundException : RuntimeException()` — no message, thrown by
/// callers that fail to resolve a habit.
class HabitNotFoundException implements Exception {
  HabitNotFoundException();

  @override
  String toString() => 'HabitNotFoundException';
}

final math.Random _random = math.Random.secure();

/// Kotlin's `Uuid.random().toHexString()`: a version-4 UUID rendered as 32
/// lowercase hex digits with no dashes.
String _randomUuidHexString() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // IETF variant
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
