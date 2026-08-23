/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/WidgetPreferences.kt
library;

import 'preferences.dart';

/// Port of `format("%06d", value)`: zero-padded to at least six characters,
/// with the minus sign counting towards the width, as `java.util.Formatter`
/// does.
String _format06d(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  return negative
      ? '-${digits.padLeft(5, '0')}'
      : digits.padLeft(6, '0');
}

/// App-scoped wrapper around [PreferencesStorage] holding the per-widget habit
/// mapping and the per-habit snooze times. There is no other per-widget
/// configuration.
class WidgetPreferences {
  WidgetPreferences(this._storage);

  final PreferencesStorage _storage;

  void addWidget(int widgetId, List<int> habitIds) {
    _storage.putLongArray(_getHabitIdKey(widgetId), habitIds);
  }

  List<int> getHabitIdsFromWidgetId(int widgetId) {
    final habitIdKey = _getHabitIdKey(widgetId);
    try {
      return _storage.getLongArray(habitIdKey, <int>[]);
    } on TypeError {
      // Up to Loop 1.7.11, this preference was not an array, but a single
      // long. Trying to read the old preference causes a cast exception
      // (ClassCastException on Android; TypeError in Dart).
      final habitId = _storage.getLong(habitIdKey, -1);
      return habitId == -1 ? <int>[] : <int>[habitId];
    }
  }

  void removeWidget(int id) {
    final habitIdKey = _getHabitIdKey(id);
    _storage.remove(habitIdKey);
  }

  int getSnoozeTime(int id) {
    return _storage.getLong(_getSnoozeKey(id), 0);
  }

  void removeSnoozeTime(int id) {
    _storage.putLong(_getSnoozeKey(id), 0);
  }

  void setSnoozeTime(int id, int time) {
    _storage.putLong(_getSnoozeKey(id), time);
  }

  String _getHabitIdKey(int id) => 'widget-${_format06d(id)}-habit';

  /// Kotlin narrows the habit id with `id.toInt()` before formatting, so the
  /// key of a habit id beyond 32 bits wraps around. Ported as-is.
  String _getSnoozeKey(int id) => 'snooze-${_format06d(id.toSigned(32))}';
}
