// The preference model is reached by its `src` path, exactly as
// lib/state/app_scope.dart reaches it; the core barrel only re-exports the
// models, database, time and drawing layers.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';

/// Name of the settings file, which lives next to `uhabits.db`.
const String preferencesFilename = 'preferences.json';

/// A [PreferencesStorage] that keeps every setting in a small JSON file.
///
/// This is the Flutter counterpart of
/// uhabits-android/src/main/java/org/isoron/uhabits/preferences/SharedPreferencesStorage.kt:
/// one app-scoped store, holding the keys of
/// `settings.preferences.key-catalog`, seeded on the first launch with the
/// defaults declared in res/xml/preferences.xml, and able to bridge an outside
/// change back into [Preferences].
///
/// Two deliberate deviations from the Android bridge, both platform-inherent:
///
///  * `settings.preferences.android-storage-bridge#1` — the backing store is a
///    JSON file rather than `PreferenceManager.getDefaultSharedPreferences`,
///    which does not exist on iOS. The file is the app's single canonical
///    settings file, so the "app-scoped singleton" half of the rule still
///    holds: one file, one instance, wired into `AppScope`.
///  * `settings.preferences.android-storage-bridge#3` — Kotlin force-unwraps
///    the `SharedPreferences` result, so a key stored as null throws. Dart's
///    `String` is non-nullable and this storage never returns null, so a JSON
///    null is treated as an absent key and yields the caller's default, which
///    is what every [Preferences] getter already expects.
///
/// Everything a [Preferences] getter can observe otherwise matches
/// `MemoryStorage` exactly (`settings.preferences.storage-contract#4` to `#9`):
/// values are held as strings, a present-but-unparsable boolean reads as false
/// while a present-but-unparsable number falls back to the caller's default.
///
/// Writes are durable. Every mutator serialises the whole map into
/// `preferences.json.tmp`, flushes it and renames it over `preferences.json`;
/// rename is atomic, so a crash mid-write can never leave a truncated settings
/// file behind. This is stricter than Android's `SharedPreferences.apply()`,
/// which returns before the write reaches the disk — the file is a few hundred
/// bytes and preferences change at human speed, so the synchronous write is
/// not worth batching.
class FilePreferencesStorage extends PreferencesStorage {
  /// Opens the settings file at [path], loading it if it is already there and
  /// materialising [xmlDefaults] if it is not.
  ///
  /// Prefer [open], which resolves the canonical location. This constructor is
  /// for tests and for callers that already know the application directory.
  FilePreferencesStorage.atPath(String path)
      : _file = File(path),
        _temp = File('$path.tmp') {
    // PreferenceManager.setDefaultValues(context, R.xml.preferences, false):
    // the XML defaults are written once, and never again over a file that
    // already exists — not even after the user cleared every setting.
    if (!_load()) {
      _values.addAll(xmlDefaults);
      _flush();
    }
  }

  /// Opens `preferences.json` inside [directory], defaulting to the same
  /// application support directory that holds the database.
  static Future<FilePreferencesStorage> open({String? directory}) async {
    final resolved =
        directory ?? (await getApplicationSupportDirectory()).path;
    return FilePreferencesStorage.atPath(
      p.join(resolved, preferencesFilename),
    );
  }

  /// The defaults declared in `res/xml/preferences.xml`
  /// (`settings.preferences.android-storage-bridge#8`), which Android writes
  /// into the store the first time the app runs.
  ///
  /// `pref_first_weekday` is deliberately absent: it is a `ListPreference`
  /// with no `android:defaultValue`, populated at runtime from the locale
  /// (`settings.preferences.android-storage-bridge#9`).
  static const Map<String, String> xmlDefaults = <String, String>{
    'pref_short_toggle': 'false',
    'pref_midnight_delay': 'false',
    'pref_skip_enabled': 'false',
    'pref_unknown_enabled': 'false',
    'pref_checkmark_reverse_order': 'false',
    'pref_pure_black': 'false',
    'pref_disable_animation': 'false',
    'pref_widget_opacity': '255',
    'pref_sticky_notifications': 'false',
    'pref_developer': 'false',
    'pref_sync_base_url': 'https://sync.loophabits.org',
    'pref_sync_key': '',
    'pref_encryption_key': '',
  };

  /// The only four keys an outside change is reported back on
  /// (`settings.preferences.android-storage-bridge#5`), in the order of the
  /// `when` branches of `onSharedPreferenceChanged`. Every other key — short
  /// toggle, skip, pure black, animations, widget opacity, first weekday — is
  /// read on demand and fires no listener (`#6`).
  static const List<String> bridgedKeys = <String>[
    'pref_checkmark_reverse_order',
    'pref_midnight_delay',
    'pref_sticky_notifications',
    'pref_unknown_enabled',
  ];

  final File _file;
  final File _temp;
  final Map<String, String> _values = <String, String>{};

  Preferences? _preferences;
  bool _dispatching = false;

  /// Where the settings are stored.
  String get path => _file.path;

  /// Re-reads the file and reports the four bridged keys to the attached
  /// [Preferences].
  ///
  /// This is `onSharedPreferenceChanged`, made explicit: Flutter has no
  /// equivalent of a `SharedPreferences` change callback, so whoever knows
  /// that the file changed underneath the app — an import, a restore, a home
  /// screen widget writing from another process — calls this.
  void reload() {
    final preferences = _preferences;
    if (preferences == null) {
      // `settings.preferences.android-storage-bridge#7`: with nothing
      // attached, the new values are picked up but nothing is dispatched.
      _load();
      return;
    }
    if (_dispatching) {
      // `settings.preferences.android-storage-bridge#4`: Android unregisters
      // itself for the duration of the dispatch, so the write a listener
      // performs cannot re-enter the handler. The flag is the same guard
      // without the unregister/register dance.
      return;
    }
    final previous = <String, bool>{
      for (final key in bridgedKeys) key: getBoolean(key, false),
    };
    _load();
    _dispatching = true;
    try {
      for (final key in bridgedKeys) {
        // Each bridged read uses false as its default, so a key that
        // disappeared reads as false and turns the preference off.
        final value = getBoolean(key, false);
        if (value == previous[key]) continue;
        switch (key) {
          case 'pref_checkmark_reverse_order':
            preferences.isCheckmarkSequenceReversed = value;
          case 'pref_midnight_delay':
            preferences.isMidnightDelayEnabled = value;
          case 'pref_sticky_notifications':
            preferences.setNotificationsSticky(value);
          case 'pref_unknown_enabled':
            preferences.areQuestionMarksEnabled = value;
        }
      }
    } finally {
      _dispatching = false;
    }
  }

  @override
  void onAttached(Preferences preferences) {
    _preferences = preferences;
  }

  @override
  void clear() {
    _values.clear();
    _flush();
  }

  @override
  bool getBoolean(String key, bool defValue) {
    final value = _values[key];
    return value == null ? defValue : value.toLowerCase() == 'true';
  }

  @override
  int getInt(String key, int defValue) {
    final value = _values[key];
    return value == null ? defValue : (int.tryParse(value) ?? defValue);
  }

  @override
  int getLong(String key, int defValue) => getInt(key, defValue);

  @override
  String getString(String key, String defValue) => _values[key] ?? defValue;

  @override
  void putBoolean(String key, bool value) => putString(key, value.toString());

  @override
  void putInt(String key, int value) => putString(key, value.toString());

  @override
  void putLong(String key, int value) => putString(key, value.toString());

  @override
  void putString(String key, String value) {
    _values[key] = value;
    _flush();
  }

  @override
  void remove(String key) {
    _values.remove(key);
    _flush();
  }

  /// Reads the file into [_values], returning whether any previous state was
  /// found. A file that is missing, unreadable or not a JSON object counts as
  /// no state: the caller then materialises the declared defaults, exactly as
  /// on a fresh install.
  bool _load() {
    final stored = _decode(_read(_file));
    if (stored != null) {
      _values
        ..clear()
        ..addAll(stored);
      // A leftover temp file means an interrupted write whose rename never
      // happened. The committed file won, so the remains are dropped.
      _delete(_temp);
      return true;
    }
    // No committed file, but a complete temp one: the app crashed between the
    // write and the rename of the very first save. Adopt it.
    final recovered = _decode(_read(_temp));
    if (recovered != null) {
      _values
        ..clear()
        ..addAll(recovered);
      _flush();
      return true;
    }
    _values.clear();
    return false;
  }

  /// Serialises [_values] into the temp file and renames it over the real one.
  /// Rename is atomic on every platform the app targets, so readers see either
  /// the whole previous file or the whole new one, never a partial write.
  void _flush() {
    final directory = _file.parent;
    if (!directory.existsSync()) directory.createSync(recursive: true);
    final keys = _values.keys.toList()..sort();
    final ordered = <String, String>{
      for (final key in keys) key: _values[key]!,
    };
    _temp.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(ordered)}\n',
      flush: true,
    );
    _temp.renameSync(_file.path);
  }

  static String? _read(File file) {
    try {
      return file.readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  static void _delete(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // A settings file that cannot be tidied up is not worth a crash.
    }
  }

  /// Parses one JSON object of strings, tolerating a file edited by hand: a
  /// number or a boolean is read as its string form, and anything else — a
  /// null, a list, a nested object — is dropped, so the getters keep the
  /// `MemoryStorage` semantics the core preference tests were written against.
  static Map<String, String>? _decode(String? content) {
    if (content == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final values = <String, String>{};
    decoded.forEach((Object? key, Object? value) {
      if (key is! String) return;
      if (value is String) {
        values[key] = value;
      } else if (value is num || value is bool) {
        values[key] = value.toString();
      }
    });
    return values;
  }
}
