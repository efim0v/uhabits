/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/MemoryStorage.kt
library;

import 'preferences.dart';

/// In-memory [PreferencesStorage], backed by a single map of strings.
///
/// Every value is converted with `toString()` on the way in, which is what
/// makes the parsing behaviour of the getters observable: a value written as a
/// boolean and read as an int falls back to the default, while a value that is
/// present but unparsable as a boolean reads as false rather than the default.
class MemoryStorage extends PreferencesStorage {
  final Map<String, String> _map = <String, String>{};

  @override
  void clear() {
    _map.clear();
  }

  /// Kotlin: `map[key]?.toBoolean() ?: defValue`, and `String.toBoolean()` is
  /// `equals("true", ignoreCase = true)`.
  @override
  bool getBoolean(String key, bool defValue) {
    final value = _map[key];
    return value == null ? defValue : value.toLowerCase() == 'true';
  }

  @override
  int getInt(String key, int defValue) {
    final value = _map[key];
    return value == null ? defValue : (int.tryParse(value) ?? defValue);
  }

  @override
  int getLong(String key, int defValue) {
    final value = _map[key];
    return value == null ? defValue : (int.tryParse(value) ?? defValue);
  }

  @override
  String getString(String key, String defValue) => _map[key] ?? defValue;

  @override
  void onAttached(Preferences preferences) {}

  @override
  void putBoolean(String key, bool value) {
    _map[key] = value.toString();
  }

  @override
  void putInt(String key, int value) {
    _map[key] = value.toString();
  }

  @override
  void putLong(String key, int value) {
    _map[key] = value.toString();
  }

  @override
  void putString(String key, String value) {
    _map[key] = value;
  }

  @override
  void remove(String key) {
    _map.remove(key);
  }
}
