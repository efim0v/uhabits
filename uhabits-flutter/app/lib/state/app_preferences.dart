// The preferences layer is not re-exported from uhabits_core.dart yet; like
// app_scope.dart, this file reaches it by its `src` path.
// ignore_for_file: implementation_imports

/// The application's [Preferences], plus the change callback Android gets for
/// free from `SharedPreferences`.
///
/// `SharedPreferencesStorage` is a
/// `SharedPreferences.OnSharedPreferenceChangeListener`: every write made
/// anywhere in the process is announced to it, keyed by the preference that
/// changed. Upstream that callback is used for exactly one thing — bridging
/// four keys back into `Preferences.Listener` — because everything else can
/// wait for the next `onCreate`: `SettingsFragment` writes the key, the user
/// presses Back, and the activity underneath is recreated (or, for
/// `pref_pure_black`, restarts itself with a fade from
/// `ListHabitsActivity.onResume`).
///
/// A Flutter app has no `onCreate` to come back to. The models that read
/// [Preferences] — `ThemeModel` above all, which is what `MaterialApp.theme` is
/// built from — are built once per launch and repaint in place, so a write
/// that nobody announces is a write the rest of the app never sees: the
/// settings row moves, `Preferences` is updated, and every other screen keeps
/// the value it read at startup for the remainder of the process.
///
/// This class is that announcement, and it is deliberately general rather than
/// per-preference: it reports *every* key written through it, to anyone who
/// asked, whether the writer was the settings screen, an import, a deep link
/// or the widget bridge. Core is left exactly as Kotlin has it — no
/// `Preferences.Listener` callback is invented for `pref_theme` or
/// `pref_pure_black`, which `settings.preferences.listeners#7` requires to fire
/// nothing — because the announcement belongs to the storage layer, which is
/// where Android puts it too.
library;

import 'package:uhabits_core/src/preferences/preferences.dart';

/// Called with the key that was written, or with null when the whole store was
/// cleared. Both are `onSharedPreferenceChanged(prefs, key)`, whose `key` is
/// null for a committed `clear()`.
typedef PreferenceChangeCallback = void Function(String? key);

class AppPreferences extends Preferences {
  factory AppPreferences(PreferencesStorage storage) {
    final observed = _ObservedStorage(storage);
    final preferences = AppPreferences._(observed);
    // Only now, so that the `onAttached` the super constructor makes cannot
    // reach a listener before this object finished being built.
    observed.onChanged = preferences._dispatch;
    return preferences;
  }

  AppPreferences._(super.storage);

  final List<PreferenceChangeCallback> _listeners =
      <PreferenceChangeCallback>[];

  /// `sharedPrefs.registerOnSharedPreferenceChangeListener(this)`.
  void addChangeListener(PreferenceChangeCallback listener) {
    _listeners.add(listener);
  }

  /// `sharedPrefs.unregisterOnSharedPreferenceChangeListener(this)`.
  void removeChangeListener(PreferenceChangeCallback listener) {
    _listeners.remove(listener);
  }

  void _dispatch(String? key) {
    // Over a copy: a listener is allowed to unsubscribe — or to write another
    // preference — while it is being told about this one.
    for (final listener in List<PreferenceChangeCallback>.of(_listeners)) {
      listener(key);
    }
  }
}

/// The real store, with every write announced after it has landed.
///
/// Reads are forwarded untouched, so a listener that reads the preference back
/// from inside the callback sees the new value — which is what makes the
/// callback usable as "re-read whatever you depend on".
class _ObservedStorage extends PreferencesStorage {
  _ObservedStorage(this._inner);

  final PreferencesStorage _inner;

  /// Null until [AppPreferences] finished construction.
  PreferenceChangeCallback? onChanged;

  void _changed(String? key) => onChanged?.call(key);

  @override
  void onAttached(Preferences preferences) => _inner.onAttached(preferences);

  @override
  void clear() {
    _inner.clear();
    _changed(null);
  }

  @override
  bool getBoolean(String key, bool defValue) =>
      _inner.getBoolean(key, defValue);

  @override
  int getInt(String key, int defValue) => _inner.getInt(key, defValue);

  @override
  int getLong(String key, int defValue) => _inner.getLong(key, defValue);

  @override
  String getString(String key, String defValue) =>
      _inner.getString(key, defValue);

  @override
  void putBoolean(String key, bool value) {
    _inner.putBoolean(key, value);
    _changed(key);
  }

  @override
  void putInt(String key, int value) {
    _inner.putInt(key, value);
    _changed(key);
  }

  @override
  void putLong(String key, int value) {
    _inner.putLong(key, value);
    _changed(key);
  }

  @override
  void putString(String key, String value) {
    _inner.putString(key, value);
    _changed(key);
  }

  @override
  void putLongArray(String key, List<int> values) {
    _inner.putLongArray(key, values);
    _changed(key);
  }

  @override
  List<int> getLongArray(String key, List<int> defValue) =>
      _inner.getLongArray(key, defValue);

  @override
  void remove(String key) {
    _inner.remove(key);
    _changed(key);
  }
}
