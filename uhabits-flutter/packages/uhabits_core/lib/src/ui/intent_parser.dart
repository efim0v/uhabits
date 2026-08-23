import '../models/habit.dart';
import '../models/habit_list.dart';
import '../time/local_date.dart';

/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentParser.kt
///
/// Only the validation logic is portable: `android.content.Intent`,
/// `android.net.Uri` and `android.content.ContentUris` cannot come along, so
/// this file carries the smallest plain-Dart stand-ins the parser actually
/// touches — an intent is an action, a data uri (which is where the habit id
/// travels) and a bag of extras holding the `timestamp` long.
///
/// The Kotlin class is annotated `@Inject @AppScope`; Dart has no DI graph
/// here, so the annotation is dropped and the [HabitList] is passed to the
/// constructor exactly as the generated component would pass it.

/// The plain data class standing in for `android.content.Intent`.
///
/// Only the three members `IntentParser` reads are modelled: [action] (which
/// the receivers switch on and the parser ignores), [data] — the
/// `content://org.isoron.uhabits/habit/<id>` uri built from
/// `Habit.uriString` — and the extras map behind [getLongExtra]/[putExtra].
class Intent {
  Intent({this.action, this.data, Map<String, Object?>? extras})
      : extras = extras ?? <String, Object?>{};

  /// Android's `intent.action`. Never read by the parser.
  String? action;

  /// Android's `intent.data`. Null models an intent built without a data uri.
  Uri? data;

  final Map<String, Object?> extras;

  /// Android's `Intent.getLongExtra(name, defaultValue)`: a missing extra —
  /// and, on Android, one stored under another type — yields the default.
  int getLongExtra(String name, int defaultValue) {
    final value = extras[name];
    return value is int ? value : defaultValue;
  }

  /// Android's `Intent.putExtra(name, value)`.
  void putExtra(String name, Object? value) {
    extras[name] = value;
  }
}

/// Port of `android.content.ContentUris.parseId(uri)`.
///
/// Android returns -1 when the uri has no path segments and otherwise parses
/// the last one as a long, throwing when it is not a number. Android's
/// `Uri.getPathSegments` skips empty segments, so a trailing slash does not
/// change the answer; Dart's [Uri.pathSegments] keeps them, hence the filter.
int parseContentUriId(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return -1;
  return int.parse(segments.last);
}

class IntentParser {
  IntentParser(this.habits);

  final HabitList habits;

  CheckmarkIntentData parseCheckmarkIntent(Intent intent) {
    final uri = intent.data;
    if (uri == null) throw ArgumentError('uri is null');
    return CheckmarkIntentData(_parseHabit(uri), _parseDate(intent));
  }

  void copyIntentData(Intent source, Intent destination) {
    destination.data = source.data;
    final todayMillis = getToday().unixTime;
    destination.putExtra(
      'timestamp',
      source.getLongExtra('timestamp', todayMillis),
    );
  }

  Habit _parseHabit(Uri uri) {
    final habit = habits.getById(parseContentUriId(uri));
    if (habit == null) throw ArgumentError('habit not found');
    return habit;
  }

  LocalDate _parseDate(Intent intent) {
    final todayMillis = getToday().unixTime;
    var timestamp = intent.getLongExtra('timestamp', todayMillis);
    // Snap to local midnight before validating: a timestamp anywhere inside
    // today is accepted, and anything from tomorrow on is not.
    timestamp = LocalDate.fromUnixTime(timestamp).unixTime;

    if (timestamp < 0 || timestamp > todayMillis) {
      throw ArgumentError('timestamp is not valid');
    }

    return LocalDate.fromUnixTime(timestamp);
  }
}

/// Kotlin's `IntentParser.CheckmarkIntentData(var habit, var date)`; both
/// fields are mutable there, so they are mutable here too.
class CheckmarkIntentData {
  CheckmarkIntentData(this.habit, this.date);

  Habit habit;

  LocalDate date;
}
