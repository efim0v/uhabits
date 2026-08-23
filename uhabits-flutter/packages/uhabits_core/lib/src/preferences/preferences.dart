/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/Preferences.kt
///
/// The key catalogue below is load-bearing: the settings screen, the widgets
/// and the reminder scheduler all read these exact key strings, so an existing
/// SharedPreferences file imported from the Android app must keep working.
library;

import 'dart:math' as math;

import '../models/habit_list.dart';
import '../time/local_date.dart';

/// Port of `expect fun getFirstWeekdayNumberAccordingToLocale(): Int` from
/// uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt.
///
/// The value is platform data (JVM reads
/// `GregorianCalendar(Locale.getDefault()).firstDayOfWeek`, JS reads
/// `Intl.Locale(navigator.language).getWeekInfo().firstDay`), which pure Dart
/// cannot see. The app package assigns the platform implementation here; the
/// fallback mirrors the JS one, which defaults to 1 (Sunday).
int Function() getFirstWeekdayNumberAccordingToLocale = () => 1;

/// Port of `org.isoron.platform.utils.StringUtils.joinLongs`.
String _joinLongs(List<int> values) => values.join(',');

/// Port of `org.isoron.platform.utils.StringUtils.splitLongs`. Kotlin catches
/// NumberFormatException and yields an empty array; Dart's `int.parse` throws
/// FormatException in the same situations.
List<int> _splitLongs(String str) {
  try {
    return str.split(',').map(int.parse).toList();
  } on FormatException {
    return <int>[];
  }
}

/// Kotlin stores `HabitList.Order.name`, i.e. the SCREAMING_SNAKE enum name.
/// The Dart enum is flattened to `HabitListOrder` with camelCase constants, so
/// the on-disk names are mapped explicitly instead of derived.
const Map<HabitListOrder, String> _orderNames = <HabitListOrder, String>{
  HabitListOrder.byNameAsc: 'BY_NAME_ASC',
  HabitListOrder.byNameDesc: 'BY_NAME_DESC',
  HabitListOrder.byColorAsc: 'BY_COLOR_ASC',
  HabitListOrder.byColorDesc: 'BY_COLOR_DESC',
  HabitListOrder.byScoreAsc: 'BY_SCORE_ASC',
  HabitListOrder.byScoreDesc: 'BY_SCORE_DESC',
  HabitListOrder.byStatusAsc: 'BY_STATUS_ASC',
  HabitListOrder.byStatusDesc: 'BY_STATUS_DESC',
  HabitListOrder.byPosition: 'BY_POSITION',
};

/// `HabitList.Order.name`.
String habitListOrderName(HabitListOrder order) => _orderNames[order]!;

/// `HabitList.Order.valueOf(name)`: throws when the name is not an enum
/// constant, like Kotlin's IllegalArgumentException.
HabitListOrder habitListOrderValueOf(String name) {
  for (final entry in _orderNames.entries) {
    if (entry.value == name) return entry.key;
  }
  throw ArgumentError('No enum constant HabitList.Order.$name');
}

/// Port of the nested Kotlin interface `Preferences.Listener`. Every method has
/// an empty default implementation, so this is a concrete class in Dart and
/// implementations override only what they care about.
class PreferencesListener {
  void onCheckmarkSequenceChanged() {}

  void onNotificationsChanged() {}

  void onQuestionMarksChanged() {}
}

/// Port of the nested Kotlin interface `Preferences.Storage`.
///
/// The interface carries default implementations for [onAttached],
/// [putLongArray] and [getLongArray]; Dart implementations therefore extend
/// this class rather than implementing it. The Android SharedPreferences
/// bridge lives in the app package.
abstract class PreferencesStorage {
  void clear();

  bool getBoolean(String key, bool defValue);

  int getInt(String key, int defValue);

  int getLong(String key, int defValue);

  String getString(String key, String defValue);

  void onAttached(Preferences preferences) {}

  void putBoolean(String key, bool value);

  void putInt(String key, int value);

  void putLong(String key, int value);

  void putString(String key, String value);

  void remove(String key);

  void putLongArray(String key, List<int> values) {
    putString(key, _joinLongs(values));
  }

  List<int> getLongArray(String key, List<int> defValue) {
    final string = getString(key, '');
    if (string.isEmpty) {
      return defValue;
    } else {
      return _splitLongs(string);
    }
  }
}

class Preferences {
  Preferences(this._storage) {
    _storage.onAttached(this);
  }

  final PreferencesStorage _storage;
  final List<PreferencesListener> _listeners = <PreferencesListener>[];
  bool? _shouldReverseCheckmarks;

  /// Port of `Preferences.MIDNIGHT_DELAY_HOURS`. Renamed to avoid colliding
  /// with the [midnightDelayHours] getter, which Dart does not allow.
  static const int midnightDelayHoursWhenEnabled = 3;

  /// Mirrors `ThemeSwitcher.THEME_AUTOMATIC`, the default of "pref_theme".
  static const int themeAutomatic = 0;

  void addListener(PreferencesListener listener) {
    _listeners.add(listener);
  }

  void removeListener(PreferencesListener listener) {
    _listeners.remove(listener);
  }

  int getDefaultHabitColor(int fallbackColor) {
    return _storage.getInt(
      'pref_default_habit_palette_color',
      fallbackColor,
    );
  }

  void setDefaultHabitColor(int color) {
    _storage.putInt('pref_default_habit_palette_color', color);
  }

  HabitListOrder get defaultPrimaryOrder {
    final name = _storage.getString('pref_default_order', 'BY_POSITION');
    try {
      return habitListOrderValueOf(name);
    } on ArgumentError {
      defaultPrimaryOrder = HabitListOrder.byPosition;
      return HabitListOrder.byPosition;
    }
  }

  set defaultPrimaryOrder(HabitListOrder order) {
    _storage.putString('pref_default_order', habitListOrderName(order));
  }

  HabitListOrder get defaultSecondaryOrder {
    final name =
        _storage.getString('pref_default_secondary_order', 'BY_NAME_ASC');
    try {
      return habitListOrderValueOf(name);
    } on ArgumentError {
      // Upstream writes BY_NAME_ASC but returns BY_POSITION. Ported verbatim.
      defaultSecondaryOrder = HabitListOrder.byNameAsc;
      return HabitListOrder.byPosition;
    }
  }

  set defaultSecondaryOrder(HabitListOrder order) {
    _storage.putString(
        'pref_default_secondary_order', habitListOrderName(order));
  }

  int get scoreCardSpinnerPosition =>
      math.min(4, math.max(0, _storage.getInt('pref_score_view_interval', 1)));

  set scoreCardSpinnerPosition(int position) {
    _storage.putInt('pref_score_view_interval', position);
  }

  int get barCardBoolSpinnerPosition =>
      math.min(3, math.max(0, _storage.getInt('pref_bar_card_bool_spinner', 0)));

  set barCardBoolSpinnerPosition(int position) {
    _storage.putInt('pref_bar_card_bool_spinner', position);
  }

  int get barCardNumericalSpinnerPosition => math.min(
      4, math.max(0, _storage.getInt('pref_bar_card_numerical_spinner', 0)));

  set barCardNumericalSpinnerPosition(int position) {
    _storage.putInt('pref_bar_card_numerical_spinner', position);
  }

  int get lastHintNumber => _storage.getInt('last_hint_number', -1);

  LocalDate? get lastHintDate {
    final unixTime = _storage.getLong('last_hint_timestamp', -1);
    return unixTime < 0 ? null : LocalDate.fromUnixTime(unixTime);
  }

  void updateLastHint(int number, LocalDate date) {
    _storage.putInt('last_hint_number', number);
    _storage.putLong('last_hint_timestamp', date.unixTime);
  }

  bool get showArchived => _storage.getBoolean('pref_show_archived', false);

  set showArchived(bool showArchived) {
    _storage.putBoolean('pref_show_archived', showArchived);
  }

  bool get showCompleted => _storage.getBoolean('pref_show_completed', true);

  set showCompleted(bool showCompleted) {
    _storage.putBoolean('pref_show_completed', showCompleted);
  }

  int get theme => _storage.getInt('pref_theme', themeAutomatic);

  set theme(int theme) {
    _storage.putInt('pref_theme', theme);
  }

  void incrementLaunchCount() {
    _storage.putInt('launch_count', launchCount + 1);
  }

  int get launchCount => _storage.getInt('launch_count', 0);

  bool get isDeveloper => _storage.getBoolean('pref_developer', false);

  set isDeveloper(bool isDeveloper) {
    _storage.putBoolean('pref_developer', isDeveloper);
  }

  bool get isFirstRun => _storage.getBoolean('pref_first_run', true);

  set isFirstRun(bool isFirstRun) {
    _storage.putBoolean('pref_first_run', isFirstRun);
  }

  bool get isPureBlackEnabled => _storage.getBoolean('pref_pure_black', false);

  set isPureBlackEnabled(bool enabled) {
    _storage.putBoolean('pref_pure_black', enabled);
  }

  bool get isShortToggleEnabled =>
      _storage.getBoolean('pref_short_toggle', false);

  set isShortToggleEnabled(bool enabled) {
    _storage.putBoolean('pref_short_toggle', enabled);
  }

  bool get isConfettiAnimationDisabled =>
      _storage.getBoolean('pref_disable_animation', false);

  set isConfettiAnimationDisabled(bool enabled) {
    _storage.putBoolean('pref_disable_animation', enabled);
  }

  void clear() {
    _storage.clear();
  }

  void setNotificationsSticky(bool sticky) {
    _storage.putBoolean('pref_sticky_notifications', sticky);
    for (final l in _listeners) {
      l.onNotificationsChanged();
    }
  }

  bool shouldMakeNotificationsSticky() {
    return _storage.getBoolean('pref_sticky_notifications', false);
  }

  bool get isCheckmarkSequenceReversed {
    _shouldReverseCheckmarks ??=
        _storage.getBoolean('pref_checkmark_reverse_order', false);
    return _shouldReverseCheckmarks!;
  }

  set isCheckmarkSequenceReversed(bool reverse) {
    _shouldReverseCheckmarks = reverse;
    _storage.putBoolean('pref_checkmark_reverse_order', reverse);
    for (final l in _listeners) {
      l.onCheckmarkSequenceChanged();
    }
  }

  bool get isMidnightDelayEnabled =>
      _storage.getBoolean('pref_midnight_delay', false);

  set isMidnightDelayEnabled(bool enabled) {
    _storage.putBoolean('pref_midnight_delay', enabled);
    for (final l in _listeners) {
      l.onCheckmarkSequenceChanged();
    }
  }

  int get midnightDelayHours =>
      isMidnightDelayEnabled ? midnightDelayHoursWhenEnabled : 0;

  int get lastAppVersion => _storage.getInt('last_version', 0);

  set lastAppVersion(int version) {
    _storage.putInt('last_version', version);
  }

  int get widgetOpacity =>
      int.parse(_storage.getString('pref_widget_opacity', '255'));

  set widgetOpacity(int value) {
    _storage.putString('pref_widget_opacity', value.toString());
  }

  bool get isSkipEnabled => _storage.getBoolean('pref_skip_enabled', false);

  set isSkipEnabled(bool value) {
    _storage.putBoolean('pref_skip_enabled', value);
  }

  bool get areQuestionMarksEnabled =>
      _storage.getBoolean('pref_unknown_enabled', false);

  set areQuestionMarksEnabled(bool value) {
    _storage.putBoolean('pref_unknown_enabled', value);
    for (final l in _listeners) {
      l.onQuestionMarksChanged();
    }
  }

  /// An integer representing the first day of the week. Sunday corresponds to
  /// 1, Monday to 2, and so on, until Saturday, which is represented by 7. By
  /// default, this is based on the current system locale, unless the user
  /// changed this in the settings.
  ///
  /// Deprecated upstream (`@get:Deprecated("")`); [firstWeekday] is the
  /// validated replacement.
  int get firstWeekdayInt {
    final weekday = _storage.getString('pref_first_weekday', '');
    return weekday.isEmpty
        ? getFirstWeekdayNumberAccordingToLocale()
        : int.parse(weekday);
  }

  DayOfWeek get firstWeekday {
    var weekday = int.parse(_storage.getString('pref_first_weekday', '-1'));
    if (weekday < 0) weekday = getFirstWeekdayNumberAccordingToLocale();
    switch (weekday) {
      case 1:
        return DayOfWeek.sunday;
      case 2:
        return DayOfWeek.monday;
      case 3:
        return DayOfWeek.tuesday;
      case 4:
        return DayOfWeek.wednesday;
      case 5:
        return DayOfWeek.thursday;
      case 6:
        return DayOfWeek.friday;
      case 7:
        return DayOfWeek.saturday;
      default:
        throw ArgumentError();
    }
  }
}
