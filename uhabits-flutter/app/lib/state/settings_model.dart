// The preferences layer is not re-exported from uhabits_core.dart yet; see
// app_scope.dart for the same note.
// ignore_for_file: implementation_imports

/// Port of the state half of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/settings/SettingsFragment.kt
/// plus uhabits-core/.../ui/ThemeSwitcher.kt.
///
/// `SettingsFragment` is an androidx `PreferenceFragmentCompat`: every row is
/// bound straight to `SharedPreferences`, and `Preferences` (the core object)
/// merely reads the same file. Flutter has no preference framework, so this
/// model is the missing half — it exposes one property per row, and every one
/// of them reads and writes through the scope's [Preferences]. Nothing is
/// cached here: a getter always asks core, which is what keeps the settings
/// screen and the rest of the app looking at a single source of truth.
///
/// Two groups of keys cannot go through [Preferences] because core has no
/// accessor for them — `pref_first_weekday` (Android's `ListPreference` writes
/// it directly and `Preferences` only reads it) and the three inert sync keys
/// of the Development category. For those the model needs the same
/// [PreferencesStorage] instance that backs the scope's [Preferences]; pass it
/// in as [storage]. Without it those rows render read-only.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import 'app_scope.dart';

/// Port of the result codes `SettingsFragment.setResultOnPreferenceClick`
/// hands back to `ListHabitsActivity`
/// (`RESULT_IMPORT_DATA` … `RESULT_REPAIR_DB`).
///
/// The Android rows call `setResult(code); finish()`: the settings screen never
/// does the work itself, it closes and lets the list screen do it. The Flutter
/// screen pops with one of these instead.
enum SettingsResult {
  importData(101),
  exportCsv(102),
  exportDb(103),
  bugReport(104),
  repairDb(105);

  const SettingsResult(this.code);

  /// The numeric `RESULT_*` constant, kept so an importer of an existing
  /// Android intent contract can still match on it.
  final int code;
}

/// `Environment.getExternalStorageDirectory().absolutePath` on every Android
/// device since the storage rework: the primary shared volume.
///
/// A constant rather than a lookup, because no plugin this app depends on
/// exposes shared storage — the same reason `getSDCardDir` takes its parent as
/// an argument (`platform-glue.dir-finder#4`).
const String primaryExternalStorageDir = '/storage/emulated/0';

/// Port of `SettingsFragment.fullPathFor(uri)`
/// (`settings.screen.database-category#9`).
///
/// ```kotlin
/// when (uri.scheme) {
///     "content" -> {
///         val docId = DocumentsContract.getTreeDocumentId(uri)
///         val (type, rel) = docId.split(":", limit = 2)...
///         val base = if (type.equals("primary", true))
///             Environment.getExternalStorageDirectory().absolutePath
///         else "/storage/$type"
///         if (rel.isEmpty()) base else "$base/$rel"
///     }
///     "file" -> java.io.File(uri.path!!).absolutePath
///     else -> null
/// }
/// ```
///
/// Returns null for any other scheme, which is the caller's signal to show the
/// raw URI instead. Like the original it does not defend against a `content`
/// URI that is not a tree URI: `DocumentsContract.getTreeDocumentId` throws
/// `IllegalArgumentException` there, and so does this
/// ([ArgumentError] being Dart's counterpart).
String? fullPathFor(Uri uri, {String primaryDir = primaryExternalStorageDir}) {
  switch (uri.scheme) {
    case 'content':
      final docId = _treeDocumentId(uri);
      final separator = docId.indexOf(':');
      // `split(":", limit = 2)`: everything after the FIRST colon is the
      // relative path, colons included.
      final type = separator < 0 ? docId : docId.substring(0, separator);
      final rel = separator < 0 ? '' : docId.substring(separator + 1);
      final base = type.toLowerCase() == 'primary' ? primaryDir : '/storage/$type';
      return rel.isEmpty ? base : '$base/$rel';
    case 'file':
      // `java.io.File(uri.path!!).absolutePath`.
      return File(uri.path).absolute.path;
    default:
      return null;
  }
}

/// `DocumentsContract.getTreeDocumentId(uri)`: the second path segment of a
/// `content://<authority>/tree/<documentId>` URI.
String _treeDocumentId(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length < 2 || segments.first != 'tree') {
    throw ArgumentError('Invalid URI: $uri');
  }
  return segments[1];
}

class SettingsModel extends ChangeNotifier {
  SettingsModel(this.scope, {PreferencesStorage? storage})
      : _storage = storage {
    // `SettingsFragment.onResume` recomputes the Development category's
    // visibility once per entry; flipping the switch therefore does not hide
    // the category until settings is opened again.
    _developerCategoryVisible = preferences.isDeveloper;
  }

  final AppScope scope;

  final PreferencesStorage? _storage;

  Preferences get preferences => scope.preferences;

  late final _Relay _relay = _Relay(notifyListeners);

  bool _attached = false;

  late bool _developerCategoryVisible;

  // -------------------------------------------------------------------
  // ThemeSwitcher constants. Kotlin: ThemeSwitcher.Companion.
  // -------------------------------------------------------------------

  static const int themeAutomatic = 0;
  static const int themeDark = 1;
  static const int themeLight = 2;

  /// `R.array.widget_opacity_entries` and `R.array.widget_opacity_values`,
  /// index-aligned.
  static const List<String> widgetOpacityLabels = <String>[
    '100%',
    '80%',
    '60%',
    '40%',
    '20%',
    '0%',
  ];

  static const List<String> widgetOpacityValues = <String>[
    '255',
    '204',
    '153',
    '102',
    '51',
    '0',
  ];

  /// `SettingsFragment.updateWeekdayPreference`: entry values are exactly
  /// `["7","1","2","3","4","5","6"]`, i.e. Saturday first, in the
  /// `java.util.Calendar` convention where 1 is Sunday.
  static const List<int> firstWeekdayValues = <int>[7, 1, 2, 3, 4, 5, 6];

  /// `@string/syncBaseURL`, the XML default of `pref_sync_base_url`.
  static const String defaultSyncBaseUrl = 'https://sync.loophabits.org';

  // -------------------------------------------------------------------
  // Lifecycle. Port of SettingsFragment.onResume / onPause, which register and
  // unregister the shared-preferences change listener.
  // -------------------------------------------------------------------

  void attach() {
    if (_attached) return;
    _attached = true;
    preferences.addListener(_relay);
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    preferences.removeListener(_relay);
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Interface category
  // -------------------------------------------------------------------

  bool get isShortToggleEnabled => preferences.isShortToggleEnabled;

  set isShortToggleEnabled(bool value) {
    preferences.isShortToggleEnabled = value;
    notifyListeners();
  }

  bool get isMidnightDelayEnabled => preferences.isMidnightDelayEnabled;

  set isMidnightDelayEnabled(bool value) {
    preferences.isMidnightDelayEnabled = value;
    notifyListeners();
  }

  bool get isSkipEnabled => preferences.isSkipEnabled;

  set isSkipEnabled(bool value) {
    preferences.isSkipEnabled = value;
    notifyListeners();
  }

  bool get areQuestionMarksEnabled => preferences.areQuestionMarksEnabled;

  set areQuestionMarksEnabled(bool value) {
    preferences.areQuestionMarksEnabled = value;
    notifyListeners();
  }

  bool get isCheckmarkSequenceReversed =>
      preferences.isCheckmarkSequenceReversed;

  set isCheckmarkSequenceReversed(bool value) {
    preferences.isCheckmarkSequenceReversed = value;
    notifyListeners();
  }

  bool get isPureBlackEnabled => preferences.isPureBlackEnabled;

  set isPureBlackEnabled(bool value) {
    preferences.isPureBlackEnabled = value;
    notifyListeners();
  }

  bool get isConfettiAnimationDisabled =>
      preferences.isConfettiAnimationDisabled;

  set isConfettiAnimationDisabled(bool value) {
    preferences.isConfettiAnimationDisabled = value;
    notifyListeners();
  }

  int get widgetOpacity => preferences.widgetOpacity;

  /// `SettingsFragment.onSharedPreferenceChanged`:
  ///
  /// ```kotlin
  /// if (key == "pref_widget_opacity" && widgetUpdater != null) {
  ///     Log.d("SettingsFragment", "updating widgets")
  ///     widgetUpdater!!.updateWidgets()
  /// }
  /// ```
  ///
  /// The one preference whose change repaints the home screen, and the only
  /// key the fragment special-cases — every other row is read by whoever needs
  /// it, next time it needs it. `widgetSync` is null on a host with no widget
  /// support and in every widget test, which is the `widgetUpdater != null`
  /// guard (`settings.preferences.widget-opacity#4`).
  set widgetOpacity(int value) {
    preferences.widgetOpacity = value;
    scope.widgetSync?.updateWidgets();
    notifyListeners();
  }

  /// `prefs.firstWeekday.daysSinceSunday + 1` — the number
  /// `updateWeekdayPreference` reads back out of core, in the Calendar
  /// convention (1 = Sunday … 7 = Saturday).
  int get firstWeekday => preferences.firstWeekday.daysSinceSunday + 1;

  /// Writes `pref_first_weekday` exactly as the `ListPreference` does: as a
  /// string, straight into storage. [Preferences] has no setter for it.
  set firstWeekday(int value) {
    final storage = _storage;
    if (storage == null) return;
    storage.putString('pref_first_weekday', value.toString());
    notifyListeners();
  }

  /// False when no [PreferencesStorage] was supplied, in which case the
  /// first-weekday and sync rows can only be read.
  bool get canWriteRawKeys => _storage != null;

  // -------------------------------------------------------------------
  // Reminder category
  // -------------------------------------------------------------------

  bool get areNotificationsSticky =>
      preferences.shouldMakeNotificationsSticky();

  set areNotificationsSticky(bool value) {
    preferences.setNotificationsSticky(value);
    // `audit3.toggling-make-notifications-sticky-does-not#1`: on Android the
    // ongoing flag is read inside `buildNotification`, which runs when the
    // alarm fires, so flipping the switch applies to the very next reminder
    // with nothing to reschedule. This port has no fire-time hook — a pending
    // alarm already carries a finished notification (see FlutterAlarmScheduler)
    // — so the pending alarms have to be re-armed here for the new flag to
    // reach the user. `scheduleAll` rebuilds every one of them.
    scope.reminderScheduler?.scheduleAll();
    notifyListeners();
  }

  // -------------------------------------------------------------------
  // Development category
  // -------------------------------------------------------------------

  bool get isDeveloperCategoryVisible => _developerCategoryVisible;

  bool get isDeveloper => preferences.isDeveloper;

  set isDeveloper(bool value) {
    preferences.isDeveloper = value;
    notifyListeners();
  }

  String get syncBaseUrl => _rawString('pref_sync_base_url', defaultSyncBaseUrl);

  set syncBaseUrl(String value) => _putRawString('pref_sync_base_url', value);

  String get syncKey => _rawString('pref_sync_key', '');

  set syncKey(String value) => _putRawString('pref_sync_key', value);

  String get encryptionKey => _rawString('pref_encryption_key', '');

  set encryptionKey(String value) =>
      _putRawString('pref_encryption_key', value);

  // -------------------------------------------------------------------
  // Database category
  // -------------------------------------------------------------------

  /// The raw `publicBackupFolder` key: an `android.net.Uri` as a string, or
  /// null when it was never written.
  ///
  /// The picker behind it is the Storage Access Framework, so nothing ever
  /// writes this key in the Flutter build; the getter is here so the row can
  /// already render the stored value once a platform picker exists.
  String? get publicBackupFolder {
    final value = _rawString('publicBackupFolder', '');
    return value.isEmpty ? null : value;
  }

  /// `updatePublicBackupFolderSummary()`: the human-readable path the row
  /// shows, or null for "No folder selected".
  ///
  /// ```kotlin
  /// val uriString = sharedPrefs?.getString("publicBackupFolder", null)
  /// if (uriString == null) { pref.summary = ...no_public_backup_folder_selected; return }
  /// pref.summary = fullPathFor(Uri.parse(uriString)) ?: uriString
  /// ```
  String? get publicBackupFolderSummary {
    final uriString = publicBackupFolder;
    if (uriString == null) return null;
    return fullPathFor(Uri.parse(uriString)) ?? uriString;
  }

  // -------------------------------------------------------------------
  // ThemeSwitcher
  // -------------------------------------------------------------------

  int get theme => preferences.theme;

  set theme(int value) {
    preferences.theme = value;
    notifyListeners();
  }

  /// `ThemeSwitcher.isNightMode`. [systemTheme] is [themeLight] or [themeDark],
  /// which the widget layer derives from `MediaQuery.platformBrightness`.
  bool isNightMode(int systemTheme) {
    final userTheme = theme;
    return userTheme == themeDark ||
        (systemTheme == themeDark && userTheme == themeAutomatic);
  }

  /// `ThemeSwitcher.apply()`, minus the Android styles: pure black when night
  /// mode and `pref_pure_black`, dark when night mode alone, light otherwise.
  core.Theme currentTheme(int systemTheme) {
    if (isNightMode(systemTheme)) {
      return isPureBlackEnabled ? core.PureBlackTheme() : core.DarkTheme();
    }
    return core.LightTheme();
  }

  /// `ThemeSwitcher.toggleNightMode()`, ported verbatim including its
  /// three-state cycle through [themeAutomatic].
  void toggleNightMode(int systemTheme) {
    final userTheme = theme;
    if (userTheme == themeAutomatic) {
      if (systemTheme == themeLight) theme = themeDark;
      if (systemTheme == themeDark) theme = themeLight;
    } else if (userTheme == themeLight) {
      if (systemTheme == themeLight) theme = themeDark;
      if (systemTheme == themeDark) theme = themeAutomatic;
    } else if (userTheme == themeDark) {
      if (systemTheme == themeLight) theme = themeAutomatic;
      if (systemTheme == themeDark) theme = themeLight;
    }
  }

  // -------------------------------------------------------------------

  String _rawString(String key, String defValue) =>
      _storage?.getString(key, defValue) ?? defValue;

  void _putRawString(String key, String value) {
    _storage?.putString(key, value);
    notifyListeners();
  }
}

/// `Preferences.Listener`, forwarded to the [ChangeNotifier] so that a change
/// made anywhere else in the app repaints the open settings screen. This is the
/// role `SettingsFragment.onSharedPreferenceChanged` plays on Android.
class _Relay extends PreferencesListener {
  _Relay(this._notify);

  final VoidCallback _notify;

  @override
  void onCheckmarkSequenceChanged() => _notify();

  @override
  void onNotificationsChanged() => _notify();

  @override
  void onQuestionMarksChanged() => _notify();
}
