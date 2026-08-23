import 'package:test/test.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/preferences/PreferencesTest.kt
/// plus the rules of the `settings.preferences.*` and
/// `settings.widget-preferences.*` features, whose Kotlin sources are
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/preferences/{Preferences,MemoryStorage,WidgetPreferences}.kt

/// Records everything Preferences asks of its Storage, so the key catalogue and
/// the defaults handed to the storage can be asserted directly.
class SpyStorage extends MemoryStorage {
  int onAttachedCount = 0;
  Object? attachedTo;
  int clearCount = 0;
  final List<String> writtenKeys = <String>[];
  final List<String> removedKeys = <String>[];
  final Map<String, String> stringDefaults = <String, String>{};
  final Map<String, bool> booleanDefaults = <String, bool>{};
  final Map<String, int> intDefaults = <String, int>{};
  final Map<String, int> longDefaults = <String, int>{};
  final Map<String, int> booleanReads = <String, int>{};

  @override
  void onAttached(Preferences preferences) {
    onAttachedCount++;
    attachedTo = preferences;
    super.onAttached(preferences);
  }

  @override
  void clear() {
    clearCount++;
    super.clear();
  }

  @override
  bool getBoolean(String key, bool defValue) {
    booleanDefaults[key] = defValue;
    booleanReads[key] = (booleanReads[key] ?? 0) + 1;
    return super.getBoolean(key, defValue);
  }

  @override
  int getInt(String key, int defValue) {
    intDefaults[key] = defValue;
    return super.getInt(key, defValue);
  }

  @override
  int getLong(String key, int defValue) {
    longDefaults[key] = defValue;
    return super.getLong(key, defValue);
  }

  @override
  String getString(String key, String defValue) {
    stringDefaults[key] = defValue;
    return super.getString(key, defValue);
  }

  @override
  void putBoolean(String key, bool value) {
    writtenKeys.add(key);
    super.putBoolean(key, value);
  }

  @override
  void putInt(String key, int value) {
    writtenKeys.add(key);
    super.putInt(key, value);
  }

  @override
  void putLong(String key, int value) {
    writtenKeys.add(key);
    super.putLong(key, value);
  }

  @override
  void putString(String key, String value) {
    writtenKeys.add(key);
    super.putString(key, value);
  }

  @override
  void remove(String key) {
    removedKeys.add(key);
    super.remove(key);
  }
}

class CountingListener extends PreferencesListener {
  int checkmarkSequenceChanged = 0;
  int notificationsChanged = 0;
  int questionMarksChanged = 0;

  int get total =>
      checkmarkSequenceChanged + notificationsChanged + questionMarksChanged;

  @override
  void onCheckmarkSequenceChanged() => checkmarkSequenceChanged++;

  @override
  void onNotificationsChanged() => notificationsChanged++;

  @override
  void onQuestionMarksChanged() => questionMarksChanged++;
}

/// Storage that only implements the abstract members of [PreferencesStorage],
/// so the default implementations of onAttached/putLongArray/getLongArray are
/// the ones under test.
class BareStorage extends PreferencesStorage {
  final Map<String, String> map = <String, String>{};

  @override
  void clear() => map.clear();

  @override
  bool getBoolean(String key, bool defValue) =>
      map.containsKey(key) ? map[key]!.toLowerCase() == 'true' : defValue;

  @override
  int getInt(String key, int defValue) =>
      map.containsKey(key) ? (int.tryParse(map[key]!) ?? defValue) : defValue;

  @override
  int getLong(String key, int defValue) =>
      map.containsKey(key) ? (int.tryParse(map[key]!) ?? defValue) : defValue;

  @override
  String getString(String key, String defValue) => map[key] ?? defValue;

  @override
  void putBoolean(String key, bool value) => map[key] = '$value';

  @override
  void putInt(String key, int value) => map[key] = '$value';

  @override
  void putLong(String key, int value) => map[key] = '$value';

  @override
  void putString(String key, String value) => map[key] = value;

  @override
  void remove(String key) => map.remove(key);
}

/// Reproduces Loop <= 1.7.11 data, where the widget habit-id key held a single
/// Long. SharedPreferences.getString then throws ClassCastException; the Dart
/// equivalent of a failed cast is TypeError.
class LegacyLongStorage extends MemoryStorage {
  @override
  String getString(String key, String defValue) {
    final Object stored = super.getLong(key, -1);
    return stored as String;
  }
}

void main() {
  late SpyStorage storage;
  late Preferences prefs;
  late CountingListener listener;

  setUp(() {
    storage = SpyStorage();
    prefs = Preferences(storage);
    listener = CountingListener();
    prefs.addListener(listener);
  });

  group('settings.preferences.key-catalog', () {
    test('#1 constructor attaches the storage once, with no listeners', () {
      final freshStorage = SpyStorage();
      final freshPrefs = Preferences(freshStorage);
      expect(freshStorage.onAttachedCount, 1,
          reason: 'settings.preferences.key-catalog#1');
      expect(identical(freshStorage.attachedTo, freshPrefs), isTrue,
          reason: 'settings.preferences.key-catalog#1');

      // The listener list starts empty: a listener that was never added to this
      // Preferences instance is never notified.
      final never = CountingListener();
      freshPrefs.isCheckmarkSequenceReversed = true;
      freshPrefs.setNotificationsSticky(true);
      freshPrefs.areQuestionMarksEnabled = true;
      expect(never.total, 0, reason: 'settings.preferences.key-catalog#1');
    });

    test('#2 pref_default_habit_palette_color has no fixed default', () {
      expect(prefs.getDefaultHabitColor(999), 999,
          reason: 'settings.preferences.key-catalog#2');
      expect(prefs.getDefaultHabitColor(7), 7,
          reason: 'settings.preferences.key-catalog#2');
      prefs.setDefaultHabitColor(10);
      expect(prefs.getDefaultHabitColor(999), 10,
          reason: 'settings.preferences.key-catalog#2');
      expect(storage.getString('pref_default_habit_palette_color', ''), '10',
          reason: 'settings.preferences.key-catalog#2');
    });

    test('#3 pref_default_order is a String defaulting to BY_POSITION', () {
      expect(prefs.defaultPrimaryOrder, HabitListOrder.byPosition,
          reason: 'settings.preferences.key-catalog#3');
      expect(storage.stringDefaults['pref_default_order'], 'BY_POSITION',
          reason: 'settings.preferences.key-catalog#3');
      prefs.defaultPrimaryOrder = HabitListOrder.byScoreDesc;
      expect(storage.getString('pref_default_order', ''), 'BY_SCORE_DESC',
          reason: 'settings.preferences.key-catalog#3');
    });

    test('#4 pref_default_secondary_order defaults to BY_NAME_ASC', () {
      expect(prefs.defaultSecondaryOrder, HabitListOrder.byNameAsc,
          reason: 'settings.preferences.key-catalog#4');
      expect(storage.stringDefaults['pref_default_secondary_order'],
          'BY_NAME_ASC',
          reason: 'settings.preferences.key-catalog#4');
      prefs.defaultSecondaryOrder = HabitListOrder.byColorAsc;
      expect(storage.getString('pref_default_secondary_order', ''),
          'BY_COLOR_ASC',
          reason: 'settings.preferences.key-catalog#4');
    });

    test('#5 pref_score_view_interval raw default 1, clamped to 0..4', () {
      expect(prefs.scoreCardSpinnerPosition, 1,
          reason: 'settings.preferences.key-catalog#5');
      expect(storage.intDefaults['pref_score_view_interval'], 1,
          reason: 'settings.preferences.key-catalog#5');
      storage.putInt('pref_score_view_interval', 9000);
      expect(prefs.scoreCardSpinnerPosition, 4,
          reason: 'settings.preferences.key-catalog#5');
      storage.putInt('pref_score_view_interval', -3);
      expect(prefs.scoreCardSpinnerPosition, 0,
          reason: 'settings.preferences.key-catalog#5');
    });

    test('#6 pref_bar_card_bool_spinner raw default 0, clamped to 0..3', () {
      expect(prefs.barCardBoolSpinnerPosition, 0,
          reason: 'settings.preferences.key-catalog#6');
      expect(storage.intDefaults['pref_bar_card_bool_spinner'], 0,
          reason: 'settings.preferences.key-catalog#6');
      storage.putInt('pref_bar_card_bool_spinner', 9000);
      expect(prefs.barCardBoolSpinnerPosition, 3,
          reason: 'settings.preferences.key-catalog#6');
    });

    test('#7 pref_bar_card_numerical_spinner raw default 0, clamp 0..4', () {
      expect(prefs.barCardNumericalSpinnerPosition, 0,
          reason: 'settings.preferences.key-catalog#7');
      expect(storage.intDefaults['pref_bar_card_numerical_spinner'], 0,
          reason: 'settings.preferences.key-catalog#7');
      storage.putInt('pref_bar_card_numerical_spinner', 9000);
      expect(prefs.barCardNumericalSpinnerPosition, 4,
          reason: 'settings.preferences.key-catalog#7');
    });

    test('#8 last_hint_number is an Int defaulting to -1', () {
      expect(prefs.lastHintNumber, -1,
          reason: 'settings.preferences.key-catalog#8');
      expect(storage.intDefaults['last_hint_number'], -1,
          reason: 'settings.preferences.key-catalog#8');
      prefs.updateLastHint(34, LocalDate.ymd(2015, 3, 15));
      expect(prefs.lastHintNumber, 34,
          reason: 'settings.preferences.key-catalog#8');
      expect(storage.getString('last_hint_number', ''), '34',
          reason: 'settings.preferences.key-catalog#8');
    });

    test('#9 last_hint_timestamp is a Long defaulting to -1', () {
      expect(prefs.lastHintDate, isNull,
          reason: 'settings.preferences.key-catalog#9');
      expect(storage.longDefaults['last_hint_timestamp'], -1,
          reason: 'settings.preferences.key-catalog#9');
      storage.putLong('last_hint_timestamp', -1);
      expect(prefs.lastHintDate, isNull,
          reason: 'settings.preferences.key-catalog#9');
      final date = LocalDate.ymd(2015, 3, 15);
      storage.putLong('last_hint_timestamp', date.unixTime);
      expect(prefs.lastHintDate, date,
          reason: 'settings.preferences.key-catalog#9');
    });

    test('#10 pref_show_archived is a Boolean defaulting to false', () {
      expect(prefs.showArchived, isFalse,
          reason: 'settings.preferences.key-catalog#10');
      expect(storage.booleanDefaults['pref_show_archived'], isFalse,
          reason: 'settings.preferences.key-catalog#10');
      prefs.showArchived = true;
      expect(storage.getString('pref_show_archived', ''), 'true',
          reason: 'settings.preferences.key-catalog#10');
    });

    test('#11 pref_show_completed is a Boolean defaulting to true', () {
      expect(prefs.showCompleted, isTrue,
          reason: 'settings.preferences.key-catalog#11');
      expect(storage.booleanDefaults['pref_show_completed'], isTrue,
          reason: 'settings.preferences.key-catalog#11');
      prefs.showCompleted = false;
      expect(storage.getString('pref_show_completed', ''), 'false',
          reason: 'settings.preferences.key-catalog#11');
    });

    test('#12 pref_theme is an Int defaulting to THEME_AUTOMATIC (0)', () {
      expect(Preferences.themeAutomatic, 0,
          reason: 'settings.preferences.key-catalog#12');
      expect(prefs.theme, 0, reason: 'settings.preferences.key-catalog#12');
      expect(storage.intDefaults['pref_theme'], 0,
          reason: 'settings.preferences.key-catalog#12');
      prefs.theme = 1;
      expect(prefs.theme, 1, reason: 'settings.preferences.key-catalog#12');
      expect(storage.getString('pref_theme', ''), '1',
          reason: 'settings.preferences.key-catalog#12');
    });

    test('#13 launch_count is an Int defaulting to 0', () {
      expect(prefs.launchCount, 0,
          reason: 'settings.preferences.key-catalog#13');
      expect(storage.intDefaults['launch_count'], 0,
          reason: 'settings.preferences.key-catalog#13');
      prefs.incrementLaunchCount();
      expect(storage.getString('launch_count', ''), '1',
          reason: 'settings.preferences.key-catalog#13');
    });

    test('#14 pref_developer is a Boolean defaulting to false', () {
      expect(prefs.isDeveloper, isFalse,
          reason: 'settings.preferences.key-catalog#14');
      expect(storage.booleanDefaults['pref_developer'], isFalse,
          reason: 'settings.preferences.key-catalog#14');
      prefs.isDeveloper = true;
      expect(prefs.isDeveloper, isTrue,
          reason: 'settings.preferences.key-catalog#14');
      expect(storage.getString('pref_developer', ''), 'true',
          reason: 'settings.preferences.key-catalog#14');
    });

    test('#15 pref_first_run is a Boolean defaulting to true', () {
      expect(prefs.isFirstRun, isTrue,
          reason: 'settings.preferences.key-catalog#15');
      expect(storage.booleanDefaults['pref_first_run'], isTrue,
          reason: 'settings.preferences.key-catalog#15');
      prefs.isFirstRun = false;
      expect(storage.getString('pref_first_run', ''), 'false',
          reason: 'settings.preferences.key-catalog#15');
    });

    test('#16 pref_pure_black is a Boolean defaulting to false', () {
      expect(prefs.isPureBlackEnabled, isFalse,
          reason: 'settings.preferences.key-catalog#16');
      expect(storage.booleanDefaults['pref_pure_black'], isFalse,
          reason: 'settings.preferences.key-catalog#16');
      prefs.isPureBlackEnabled = true;
      expect(prefs.isPureBlackEnabled, isTrue,
          reason: 'settings.preferences.key-catalog#16');
      expect(storage.getString('pref_pure_black', ''), 'true',
          reason: 'settings.preferences.key-catalog#16');
    });

    test('#17 pref_short_toggle is a Boolean defaulting to false', () {
      expect(prefs.isShortToggleEnabled, isFalse,
          reason: 'settings.preferences.key-catalog#17');
      expect(storage.booleanDefaults['pref_short_toggle'], isFalse,
          reason: 'settings.preferences.key-catalog#17');
      prefs.isShortToggleEnabled = true;
      expect(storage.getString('pref_short_toggle', ''), 'true',
          reason: 'settings.preferences.key-catalog#17');
    });

    test('#18 pref_disable_animation is a Boolean defaulting to false', () {
      expect(prefs.isConfettiAnimationDisabled, isFalse,
          reason: 'settings.preferences.key-catalog#18');
      expect(storage.booleanDefaults['pref_disable_animation'], isFalse,
          reason: 'settings.preferences.key-catalog#18');
      prefs.isConfettiAnimationDisabled = true;
      expect(storage.getString('pref_disable_animation', ''), 'true',
          reason: 'settings.preferences.key-catalog#18');
    });

    test('#19 pref_sticky_notifications is a Boolean defaulting to false', () {
      expect(prefs.shouldMakeNotificationsSticky(), isFalse,
          reason: 'settings.preferences.key-catalog#19');
      expect(storage.booleanDefaults['pref_sticky_notifications'], isFalse,
          reason: 'settings.preferences.key-catalog#19');
      prefs.setNotificationsSticky(true);
      expect(prefs.shouldMakeNotificationsSticky(), isTrue,
          reason: 'settings.preferences.key-catalog#19');
      expect(storage.getString('pref_sticky_notifications', ''), 'true',
          reason: 'settings.preferences.key-catalog#19');
    });

    test('#20 pref_checkmark_reverse_order is a Boolean defaulting to false',
        () {
      expect(prefs.isCheckmarkSequenceReversed, isFalse,
          reason: 'settings.preferences.key-catalog#20');
      expect(storage.booleanDefaults['pref_checkmark_reverse_order'], isFalse,
          reason: 'settings.preferences.key-catalog#20');
      prefs.isCheckmarkSequenceReversed = true;
      expect(storage.getString('pref_checkmark_reverse_order', ''), 'true',
          reason: 'settings.preferences.key-catalog#20');
    });

    test('#21 pref_midnight_delay is a Boolean defaulting to false', () {
      expect(prefs.isMidnightDelayEnabled, isFalse,
          reason: 'settings.preferences.key-catalog#21');
      expect(storage.booleanDefaults['pref_midnight_delay'], isFalse,
          reason: 'settings.preferences.key-catalog#21');
      prefs.isMidnightDelayEnabled = true;
      expect(storage.getString('pref_midnight_delay', ''), 'true',
          reason: 'settings.preferences.key-catalog#21');
    });

    test('#22 last_version is an Int defaulting to 0', () {
      expect(prefs.lastAppVersion, 0,
          reason: 'settings.preferences.key-catalog#22');
      expect(storage.intDefaults['last_version'], 0,
          reason: 'settings.preferences.key-catalog#22');
      prefs.lastAppVersion = 23;
      expect(prefs.lastAppVersion, 23,
          reason: 'settings.preferences.key-catalog#22');
      expect(storage.getString('last_version', ''), '23',
          reason: 'settings.preferences.key-catalog#22');
    });

    test('#23 pref_widget_opacity is a decimal String defaulting to 255', () {
      expect(prefs.widgetOpacity, 255,
          reason: 'settings.preferences.key-catalog#23');
      expect(storage.stringDefaults['pref_widget_opacity'], '255',
          reason: 'settings.preferences.key-catalog#23');
      prefs.widgetOpacity = 153;
      expect(storage.getString('pref_widget_opacity', ''), '153',
          reason: 'settings.preferences.key-catalog#23');
      expect(prefs.widgetOpacity, 153,
          reason: 'settings.preferences.key-catalog#23');
    });

    test('#24 pref_skip_enabled is a Boolean defaulting to false', () {
      expect(prefs.isSkipEnabled, isFalse,
          reason: 'settings.preferences.key-catalog#24');
      expect(storage.booleanDefaults['pref_skip_enabled'], isFalse,
          reason: 'settings.preferences.key-catalog#24');
      prefs.isSkipEnabled = true;
      expect(storage.getString('pref_skip_enabled', ''), 'true',
          reason: 'settings.preferences.key-catalog#24');
    });

    test('#25 pref_unknown_enabled is a Boolean defaulting to false', () {
      expect(prefs.areQuestionMarksEnabled, isFalse,
          reason: 'settings.preferences.key-catalog#25');
      expect(storage.booleanDefaults['pref_unknown_enabled'], isFalse,
          reason: 'settings.preferences.key-catalog#25');
      prefs.areQuestionMarksEnabled = true;
      expect(storage.getString('pref_unknown_enabled', ''), 'true',
          reason: 'settings.preferences.key-catalog#25');
    });

    test('#26 pref_first_weekday is read with two different defaults', () {
      storage.putString('pref_first_weekday', '3');
      expect(prefs.firstWeekday, DayOfWeek.tuesday,
          reason: 'settings.preferences.key-catalog#26');
      expect(storage.stringDefaults['pref_first_weekday'], '-1',
          reason: 'settings.preferences.key-catalog#26');
      expect(prefs.firstWeekdayInt, 3,
          reason: 'settings.preferences.key-catalog#26');
      expect(storage.stringDefaults['pref_first_weekday'], '',
          reason: 'settings.preferences.key-catalog#26');
    });

    test('#27 clear() delegates to storage.clear()', () {
      prefs.setDefaultHabitColor(99);
      prefs.clear();
      expect(storage.clearCount, 1,
          reason: 'settings.preferences.key-catalog#27');
      expect(prefs.getDefaultHabitColor(0), 0,
          reason: 'settings.preferences.key-catalog#27');
    });

    test('#28 MIDNIGHT_DELAY_HOURS is 3', () {
      expect(Preferences.midnightDelayHoursWhenEnabled, 3,
          reason: 'settings.preferences.key-catalog#28');
    });
  });

  group('settings.preferences.storage-contract', () {
    test('#1 the Storage interface declares the whole API', () {
      final bare = BareStorage();
      bare.putBoolean('b', true);
      bare.putInt('i', 3);
      bare.putLong('l', 4);
      bare.putString('s', 'v');
      expect(bare.getBoolean('b', false), isTrue,
          reason: 'settings.preferences.storage-contract#1');
      expect(bare.getInt('i', 0), 3,
          reason: 'settings.preferences.storage-contract#1');
      expect(bare.getLong('l', 0), 4,
          reason: 'settings.preferences.storage-contract#1');
      expect(bare.getString('s', ''), 'v',
          reason: 'settings.preferences.storage-contract#1');
      bare.remove('s');
      expect(bare.getString('s', 'default'), 'default',
          reason: 'settings.preferences.storage-contract#1');
      bare.clear();
      expect(bare.getInt('i', -7), -7,
          reason: 'settings.preferences.storage-contract#1');
      // onAttached has a default (no-op) implementation, so a Storage that
      // does not override it still satisfies the interface.
      expect(() => Preferences(bare), returnsNormally,
          reason: 'settings.preferences.storage-contract#1');
    });

    test('#2 putLongArray joins with commas; empty array writes ""', () {
      final bare = BareStorage();
      bare.putLongArray('k', <int>[1, 2, 3]);
      expect(bare.getString('k', 'MISSING'), '1,2,3',
          reason: 'settings.preferences.storage-contract#2');
      bare.putLongArray('empty', <int>[]);
      expect(bare.getString('empty', 'MISSING'), '',
          reason: 'settings.preferences.storage-contract#2');
    });

    test('#3 getLongArray splits on commas; bad parts yield an empty array',
        () {
      final bare = BareStorage();
      expect(bare.getLongArray('missing', <int>[9]), <int>[9],
          reason: 'settings.preferences.storage-contract#3');
      bare.putString('empty', '');
      expect(bare.getLongArray('empty', <int>[9]), <int>[9],
          reason: 'settings.preferences.storage-contract#3');
      bare.putString('k', '1,2,3');
      expect(bare.getLongArray('k', <int>[9]), <int>[1, 2, 3],
          reason: 'settings.preferences.storage-contract#3');
      bare.putString('bogus', '1,x,3');
      expect(bare.getLongArray('bogus', <int>[9]), <int>[],
          reason: 'settings.preferences.storage-contract#3');
    });

    test('#4 MemoryStorage stores every value as a String', () {
      final memory = MemoryStorage();
      memory.putBoolean('b', true);
      memory.putInt('i', 42);
      memory.putLong('l', 43);
      memory.putString('s', 'text');
      expect(memory.getString('b', ''), 'true',
          reason: 'settings.preferences.storage-contract#4');
      expect(memory.getString('i', ''), '42',
          reason: 'settings.preferences.storage-contract#4');
      expect(memory.getString('l', ''), '43',
          reason: 'settings.preferences.storage-contract#4');
      expect(memory.getString('s', ''), 'text',
          reason: 'settings.preferences.storage-contract#4');
    });

    test('#5 getBoolean parses with toBoolean(): "7" is false, not default',
        () {
      final memory = MemoryStorage();
      expect(memory.getBoolean('missing', true), isTrue,
          reason: 'settings.preferences.storage-contract#5');
      memory.putString('k', '7');
      expect(memory.getBoolean('k', true), isFalse,
          reason: 'settings.preferences.storage-contract#5');
      memory.putString('k', 'TRUE');
      expect(memory.getBoolean('k', false), isTrue,
          reason: 'settings.preferences.storage-contract#5');
    });

    test('#6 getInt falls back to the default for non-numeric values', () {
      final memory = MemoryStorage();
      expect(memory.getInt('missing', 5), 5,
          reason: 'settings.preferences.storage-contract#6');
      memory.putString('k', 'abc');
      expect(memory.getInt('k', 5), 5,
          reason: 'settings.preferences.storage-contract#6');
      memory.putString('k', '-12');
      expect(memory.getInt('k', 5), -12,
          reason: 'settings.preferences.storage-contract#6');
    });

    test('#7 getLong falls back to the default for non-numeric values', () {
      final memory = MemoryStorage();
      expect(memory.getLong('missing', 5), 5,
          reason: 'settings.preferences.storage-contract#7');
      memory.putString('k', 'abc');
      expect(memory.getLong('k', 5), 5,
          reason: 'settings.preferences.storage-contract#7');
      memory.putLong('k', 9007199254740991);
      expect(memory.getLong('k', 5), 9007199254740991,
          reason: 'settings.preferences.storage-contract#7');
    });

    test('#8 getString returns the default only when the key is missing', () {
      final memory = MemoryStorage();
      expect(memory.getString('missing', 'def'), 'def',
          reason: 'settings.preferences.storage-contract#8');
      memory.putString('k', '');
      expect(memory.getString('k', 'def'), '',
          reason: 'settings.preferences.storage-contract#8');
    });

    test('#9 remove deletes one key; clear empties the whole map', () {
      final memory = MemoryStorage();
      memory.putString('a', '1');
      memory.putString('b', '2');
      memory.remove('a');
      expect(memory.getString('a', 'MISSING'), 'MISSING',
          reason: 'settings.preferences.storage-contract#9');
      expect(memory.getString('b', 'MISSING'), '2',
          reason: 'settings.preferences.storage-contract#9');
      memory.clear();
      expect(memory.getString('b', 'MISSING'), 'MISSING',
          reason: 'settings.preferences.storage-contract#9');
    });

    test('#10 MemoryStorage.onAttached is a no-op', () {
      final memory = MemoryStorage();
      final attached = Preferences(memory);
      expect(() => memory.onAttached(attached), returnsNormally,
          reason: 'settings.preferences.storage-contract#10');
      expect(memory.getString('anything', 'MISSING'), 'MISSING',
          reason: 'settings.preferences.storage-contract#10');
    });
  });

  group('settings.preferences.listeners', () {
    test('#1 Listener has three methods with empty default implementations',
        () {
      final bare = PreferencesListener();
      expect(() {
        bare.onCheckmarkSequenceChanged();
        bare.onNotificationsChanged();
        bare.onQuestionMarksChanged();
      }, returnsNormally, reason: 'settings.preferences.listeners#1');

      prefs.addListener(bare);
      expect(() {
        prefs.isCheckmarkSequenceReversed = true;
        prefs.setNotificationsSticky(true);
        prefs.areQuestionMarksEnabled = true;
      }, returnsNormally, reason: 'settings.preferences.listeners#1');
    });

    test('#2 addListener appends without de-duplicating; removeListener drops',
        () {
      prefs.addListener(listener);
      prefs.setNotificationsSticky(true);
      expect(listener.notificationsChanged, 2,
          reason: 'settings.preferences.listeners#2');
      prefs.removeListener(listener);
      prefs.setNotificationsSticky(false);
      expect(listener.notificationsChanged, 3,
          reason: 'settings.preferences.listeners#2');
      prefs.removeListener(listener);
      prefs.setNotificationsSticky(true);
      expect(listener.notificationsChanged, 3,
          reason: 'settings.preferences.listeners#2');
    });

    test('#3 isCheckmarkSequenceReversed notifies onCheckmarkSequenceChanged',
        () {
      prefs.isCheckmarkSequenceReversed = true;
      expect(listener.checkmarkSequenceChanged, 1,
          reason: 'settings.preferences.listeners#3');
      expect(listener.notificationsChanged, 0,
          reason: 'settings.preferences.listeners#3');
      expect(listener.questionMarksChanged, 0,
          reason: 'settings.preferences.listeners#3');
    });

    test('#4 isMidnightDelayEnabled also fires onCheckmarkSequenceChanged', () {
      prefs.isMidnightDelayEnabled = true;
      expect(listener.checkmarkSequenceChanged, 1,
          reason: 'settings.preferences.listeners#4');
      expect(listener.notificationsChanged, 0,
          reason: 'settings.preferences.listeners#4');
      expect(listener.questionMarksChanged, 0,
          reason: 'settings.preferences.listeners#4');
    });

    test('#5 setNotificationsSticky notifies onNotificationsChanged', () {
      prefs.setNotificationsSticky(false);
      expect(listener.notificationsChanged, 1,
          reason: 'settings.preferences.listeners#5');
      prefs.setNotificationsSticky(true);
      expect(listener.notificationsChanged, 2,
          reason: 'settings.preferences.listeners#5');
      expect(listener.checkmarkSequenceChanged, 0,
          reason: 'settings.preferences.listeners#5');
    });

    test('#6 areQuestionMarksEnabled notifies onQuestionMarksChanged', () {
      prefs.areQuestionMarksEnabled = true;
      expect(listener.questionMarksChanged, 1,
          reason: 'settings.preferences.listeners#6');
      expect(listener.checkmarkSequenceChanged, 0,
          reason: 'settings.preferences.listeners#6');
      expect(listener.notificationsChanged, 0,
          reason: 'settings.preferences.listeners#6');
    });

    test('#7 no other setter fires any listener callback', () {
      prefs.theme = 1;
      prefs.isPureBlackEnabled = true;
      prefs.isShortToggleEnabled = true;
      prefs.isSkipEnabled = true;
      prefs.widgetOpacity = 51;
      prefs.showArchived = true;
      prefs.showCompleted = false;
      prefs.isDeveloper = true;
      prefs.isFirstRun = false;
      prefs.isConfettiAnimationDisabled = true;
      prefs.lastAppVersion = 5;
      prefs.incrementLaunchCount();
      prefs.setDefaultHabitColor(4);
      prefs.updateLastHint(1, LocalDate.ymd(2015, 3, 15));
      prefs.defaultPrimaryOrder = HabitListOrder.byNameDesc;
      prefs.defaultSecondaryOrder = HabitListOrder.byColorAsc;
      prefs.scoreCardSpinnerPosition = 2;
      prefs.barCardBoolSpinnerPosition = 2;
      prefs.barCardNumericalSpinnerPosition = 2;
      expect(listener.total, 0, reason: 'settings.preferences.listeners#7');
    });
  });

  group('settings.preferences.checkmark-reverse-order', () {
    test('#1 key pref_checkmark_reverse_order, Boolean, default false', () {
      expect(prefs.isCheckmarkSequenceReversed, isFalse,
          reason: 'settings.preferences.checkmark-reverse-order#1');
      expect(storage.booleanDefaults['pref_checkmark_reverse_order'], isFalse,
          reason: 'settings.preferences.checkmark-reverse-order#1');
    });

    test('#2 the getter memoises the first read', () {
      storage.putBoolean('pref_checkmark_reverse_order', true);
      expect(prefs.isCheckmarkSequenceReversed, isTrue,
          reason: 'settings.preferences.checkmark-reverse-order#2');
      expect(storage.booleanReads['pref_checkmark_reverse_order'], 1,
          reason: 'settings.preferences.checkmark-reverse-order#2');
      // An external write straight to storage is not observed.
      storage.putBoolean('pref_checkmark_reverse_order', false);
      expect(prefs.isCheckmarkSequenceReversed, isTrue,
          reason: 'settings.preferences.checkmark-reverse-order#2');
      expect(storage.booleanReads['pref_checkmark_reverse_order'], 1,
          reason: 'settings.preferences.checkmark-reverse-order#2');
      // Writing through the setter updates the cache.
      prefs.isCheckmarkSequenceReversed = false;
      expect(prefs.isCheckmarkSequenceReversed, isFalse,
          reason: 'settings.preferences.checkmark-reverse-order#2');
      expect(storage.booleanReads['pref_checkmark_reverse_order'], 1,
          reason: 'settings.preferences.checkmark-reverse-order#2');
    });

    test('#3 the setter writes storage and notifies every listener', () {
      final second = CountingListener();
      prefs.addListener(second);
      prefs.isCheckmarkSequenceReversed = true;
      expect(storage.getString('pref_checkmark_reverse_order', ''), 'true',
          reason: 'settings.preferences.checkmark-reverse-order#3');
      expect(listener.checkmarkSequenceChanged, 1,
          reason: 'settings.preferences.checkmark-reverse-order#3');
      expect(second.checkmarkSequenceChanged, 1,
          reason: 'settings.preferences.checkmark-reverse-order#3');
    });
  });

  group('settings.preferences.first-weekday', () {
    late int Function() savedLocaleWeekday;

    setUp(() {
      savedLocaleWeekday = getFirstWeekdayNumberAccordingToLocale;
    });

    tearDown(() {
      getFirstWeekdayNumberAccordingToLocale = savedLocaleWeekday;
    });

    test('#1 firstWeekday reads "pref_first_weekday" with default "-1"', () {
      getFirstWeekdayNumberAccordingToLocale = () => 2;
      expect(prefs.firstWeekday, DayOfWeek.monday,
          reason: 'settings.preferences.first-weekday#1');
      expect(storage.stringDefaults['pref_first_weekday'], '-1',
          reason: 'settings.preferences.first-weekday#1');
      storage.putString('pref_first_weekday', '-5');
      expect(prefs.firstWeekday, DayOfWeek.monday,
          reason: 'settings.preferences.first-weekday#1');
      storage.putString('pref_first_weekday', '5');
      expect(prefs.firstWeekday, DayOfWeek.thursday,
          reason: 'settings.preferences.first-weekday#1');
    });

    test('#2 #12 the 1..7 mapping, other positive values throw', () {
      const expected = <String, DayOfWeek>{
        '1': DayOfWeek.sunday,
        '2': DayOfWeek.monday,
        '3': DayOfWeek.tuesday,
        '4': DayOfWeek.wednesday,
        '5': DayOfWeek.thursday,
        '6': DayOfWeek.friday,
        '7': DayOfWeek.saturday,
      };
      expected.forEach((stored, day) {
        storage.putString('pref_first_weekday', stored);
        expect(prefs.firstWeekday, day,
            reason: 'settings.preferences.first-weekday#2');
        expect(prefs.firstWeekday, day,
            reason: 'settings.preferences.first-weekday#12');
      });
      storage.putString('pref_first_weekday', '8');
      expect(() => prefs.firstWeekday, throwsA(isA<ArgumentError>()),
          reason: 'settings.preferences.first-weekday#2');
      storage.putString('pref_first_weekday', '0');
      expect(() => prefs.firstWeekday, throwsA(isA<ArgumentError>()),
          reason: 'settings.preferences.first-weekday#2');
    });

    test('#3 firstWeekdayInt uses "" and performs no range validation', () {
      getFirstWeekdayNumberAccordingToLocale = () => 6;
      expect(prefs.firstWeekdayInt, 6,
          reason: 'settings.preferences.first-weekday#3');
      expect(storage.stringDefaults['pref_first_weekday'], '',
          reason: 'settings.preferences.first-weekday#3');
      storage.putString('pref_first_weekday', '42');
      expect(prefs.firstWeekdayInt, 42,
          reason: 'settings.preferences.first-weekday#3');
      storage.putString('pref_first_weekday', '-1');
      expect(prefs.firstWeekdayInt, -1,
          reason: 'settings.preferences.first-weekday#3');
    });

    test('#5 DayOfWeek.daysSinceSunday values', () {
      expect(DayOfWeek.sunday.daysSinceSunday, 0,
          reason: 'settings.preferences.first-weekday#5');
      expect(DayOfWeek.monday.daysSinceSunday, 1,
          reason: 'settings.preferences.first-weekday#5');
      expect(DayOfWeek.tuesday.daysSinceSunday, 2,
          reason: 'settings.preferences.first-weekday#5');
      expect(DayOfWeek.wednesday.daysSinceSunday, 3,
          reason: 'settings.preferences.first-weekday#5');
      expect(DayOfWeek.thursday.daysSinceSunday, 4,
          reason: 'settings.preferences.first-weekday#5');
      expect(DayOfWeek.friday.daysSinceSunday, 5,
          reason: 'settings.preferences.first-weekday#5');
      expect(DayOfWeek.saturday.daysSinceSunday, 6,
          reason: 'settings.preferences.first-weekday#5');
    });

    test('#6 getWeekdaySequence rotates the week', () {
      expect(getWeekdaySequence(DayOfWeek.monday), <DayOfWeek>[
        DayOfWeek.monday,
        DayOfWeek.tuesday,
        DayOfWeek.wednesday,
        DayOfWeek.thursday,
        DayOfWeek.friday,
        DayOfWeek.saturday,
        DayOfWeek.sunday,
      ], reason: 'settings.preferences.first-weekday#6');
      expect(getWeekdaySequence(DayOfWeek.saturday).first, DayOfWeek.saturday,
          reason: 'settings.preferences.first-weekday#6');
      expect(getWeekdaySequence(DayOfWeek.saturday).last, DayOfWeek.friday,
          reason: 'settings.preferences.first-weekday#6');
    });

    test('#7 startOfWeek subtracts a non-negative delta', () {
      // 2015-01-25 is a Sunday.
      final sunday = LocalDate.ymd(2015, 1, 25);
      expect(sunday.dayOfWeek, DayOfWeek.sunday,
          reason: 'settings.preferences.first-weekday#7');
      expect(sunday.startOfWeek(DayOfWeek.sunday), sunday,
          reason: 'settings.preferences.first-weekday#7');
      expect(sunday.startOfWeek(DayOfWeek.saturday), LocalDate.ymd(2015, 1, 24),
          reason: 'settings.preferences.first-weekday#7');
      expect(sunday.startOfWeek(DayOfWeek.monday), LocalDate.ymd(2015, 1, 19),
          reason: 'settings.preferences.first-weekday#7');
    });

    test('#14 raw Int firstWeekday is a 1-based DayOfWeek index, default 7',
        () {
      final entries = <Entry>[
        Entry(LocalDate.ymd(2015, 1, 25), Entry.yesManual),
      ];
      final defaulted = entries.groupedSum(
        truncateField: TruncateField.weekNumber,
        isNumerical: false,
      );
      expect(defaulted.first.date, LocalDate.ymd(2015, 1, 24),
          reason: 'settings.preferences.first-weekday#14');
      final sundayFirst = entries.groupedSum(
        truncateField: TruncateField.weekNumber,
        firstWeekday: 1,
        isNumerical: false,
      );
      expect(sundayFirst.first.date, LocalDate.ymd(2015, 1, 25),
          reason: 'settings.preferences.first-weekday#14');
      final skips = <Entry>[Entry(LocalDate.ymd(2015, 1, 25), Entry.skip)];
      expect(
          skips
              .countSkippedDays(truncateField: TruncateField.weekNumber)
              .first
              .date,
          LocalDate.ymd(2015, 1, 24),
          reason: 'settings.preferences.first-weekday#14');
    });

    test('#15 only week bucketing moves; scores, streaks and intervals never '
        'see the first weekday', () {
      setToday(LocalDate.ymd(2015, 1, 25));
      addTearDown(resetToday);

      // 2015-01-24 is a Saturday and 2015-01-25 the Sunday after it, so the
      // two days fall in one bucket with firstWeekday=7 and in two with
      // firstWeekday=1.
      final entries = <Entry>[
        Entry(LocalDate.ymd(2015, 1, 25), Entry.yesManual),
        Entry(LocalDate.ymd(2015, 1, 24), Entry.yesManual),
      ];
      expect(
          entries
              .groupedSum(
                truncateField: TruncateField.weekNumber,
                firstWeekday: 7,
                isNumerical: false,
              )
              .length,
          1,
          reason: 'settings.preferences.first-weekday#15');
      expect(
          entries
              .groupedSum(
                truncateField: TruncateField.weekNumber,
                firstWeekday: 1,
                isNumerical: false,
              )
              .length,
          2,
          reason: 'settings.preferences.first-weekday#15');

      // Every other truncation ignores it entirely.
      for (final field in <TruncateField>[
        TruncateField.day,
        TruncateField.month,
        TruncateField.quarter,
        TruncateField.year,
      ]) {
        expect(
            entries.groupedSum(
              truncateField: field,
              firstWeekday: 1,
              isNumerical: false,
            ),
            entries.groupedSum(
              truncateField: field,
              firstWeekday: 7,
              isNumerical: false,
            ),
            reason: 'settings.preferences.first-weekday#15');
      }

      // Score, streak and interval computation take no firstWeekday argument
      // at all, so flipping the preference cannot move them. A 3/7 habit is
      // the interesting case: its interval logic is week-shaped but is driven
      // by the frequency denominator, not by the calendar week.
      final factory = MemoryModelFactory();
      final habitList = factory.buildHabitList();
      final habit = factory.buildHabit()
        ..name = 'Meditate'
        ..frequency = Frequency.threeTimesPerWeek;
      habitList.add(habit);
      for (final entry in entries) {
        habit.originalEntries.add(entry);
      }

      List<double> scoresOf() => <double>[
            for (var i = 0; i < 10; i++) habit.scores[getToday().minus(i)].value
          ];
      List<String> streaksOf() => habit.streaks
          .getBest(10)
          .map((streak) => '${streak.start}..${streak.end}')
          .toList();
      List<int> computedOf() => <int>[
            for (var i = 0; i < 10; i++)
              habit.computedEntries.get(getToday().minus(i)).value
          ];

      storage.putString('pref_first_weekday', '7');
      expect(prefs.firstWeekday, DayOfWeek.saturday,
          reason: 'settings.preferences.first-weekday#15');
      habit.recompute();
      final saturdayScores = scoresOf();
      final saturdayStreaks = streaksOf();
      final saturdayComputed = computedOf();

      storage.putString('pref_first_weekday', '2');
      expect(prefs.firstWeekday, DayOfWeek.monday,
          reason: 'settings.preferences.first-weekday#15');
      habit.recompute();

      expect(scoresOf(), saturdayScores,
          reason: 'settings.preferences.first-weekday#15');
      expect(streaksOf(), saturdayStreaks,
          reason: 'settings.preferences.first-weekday#15');
      expect(computedOf(), saturdayComputed,
          reason: 'settings.preferences.first-weekday#15');
    });
  });

  group('settings.preferences.sticky-notifications', () {
    test('#2 the listener fires on every write, even a redundant one', () {
      expect(prefs.shouldMakeNotificationsSticky(), isFalse,
          reason: 'settings.preferences.sticky-notifications#2');

      prefs.setNotificationsSticky(true);
      expect(listener.notificationsChanged, 1,
          reason: 'settings.preferences.sticky-notifications#2');

      // Same value again: nothing changed, and the listener is notified all
      // the same.
      prefs.setNotificationsSticky(true);
      expect(prefs.shouldMakeNotificationsSticky(), isTrue,
          reason: 'settings.preferences.sticky-notifications#2');
      expect(listener.notificationsChanged, 2,
          reason: 'settings.preferences.sticky-notifications#2');

      prefs.setNotificationsSticky(false);
      prefs.setNotificationsSticky(false);
      expect(listener.notificationsChanged, 4,
          reason: 'settings.preferences.sticky-notifications#2');
      expect(listener.checkmarkSequenceChanged, 0,
          reason: 'settings.preferences.sticky-notifications#2');
      expect(listener.questionMarksChanged, 0,
          reason: 'settings.preferences.sticky-notifications#2');
    });
  });

  group('settings.preferences.midnight-delay', () {
    test('#1 key pref_midnight_delay, Boolean, default false', () {
      expect(prefs.isMidnightDelayEnabled, isFalse,
          reason: 'settings.preferences.midnight-delay#1');
      expect(storage.booleanDefaults['pref_midnight_delay'], isFalse,
          reason: 'settings.preferences.midnight-delay#1');
    });

    test('#2 #9 the setter writes and fires onCheckmarkSequenceChanged', () {
      prefs.isMidnightDelayEnabled = true;
      expect(storage.getString('pref_midnight_delay', ''), 'true',
          reason: 'settings.preferences.midnight-delay#9');
      expect(prefs.isMidnightDelayEnabled, isTrue,
          reason: 'settings.preferences.midnight-delay#9');
      expect(listener.checkmarkSequenceChanged, 1,
          reason: 'settings.preferences.midnight-delay#2');
      expect(listener.notificationsChanged, 0,
          reason: 'settings.preferences.midnight-delay#9');
    });

    test('#3 #10 midnightDelayHours is 3 when enabled and 0 otherwise', () {
      expect(prefs.midnightDelayHours, 0,
          reason: 'settings.preferences.midnight-delay#3');
      prefs.isMidnightDelayEnabled = true;
      expect(prefs.midnightDelayHours, 3,
          reason: 'settings.preferences.midnight-delay#3');
      expect(prefs.midnightDelayHours, Preferences.midnightDelayHoursWhenEnabled,
          reason: 'settings.preferences.midnight-delay#10');
    });
  });

  group('settings.preferences.short-toggle', () {
    test('#1 key pref_short_toggle, Boolean, default false', () {
      expect(prefs.isShortToggleEnabled, isFalse,
          reason: 'settings.preferences.short-toggle#1');
      expect(storage.booleanDefaults['pref_short_toggle'], isFalse,
          reason: 'settings.preferences.short-toggle#1');
      prefs.isShortToggleEnabled = true;
      expect(prefs.isShortToggleEnabled, isTrue,
          reason: 'settings.preferences.short-toggle#1');
    });

    test('#5 the setter fires no listener callback', () {
      prefs.isShortToggleEnabled = true;
      expect(listener.total, 0,
          reason: 'settings.preferences.short-toggle#5');
      // Not memoised either: views read it lazily on the next interaction.
      storage.putBoolean('pref_short_toggle', false);
      expect(prefs.isShortToggleEnabled, isFalse,
          reason: 'settings.preferences.short-toggle#5');
    });
  });

  group('settings.preferences.skip-enabled', () {
    test('#1 key pref_skip_enabled, Boolean, default false', () {
      expect(prefs.isSkipEnabled, isFalse,
          reason: 'settings.preferences.skip-enabled#1');
      expect(storage.booleanDefaults['pref_skip_enabled'], isFalse,
          reason: 'settings.preferences.skip-enabled#1');
      prefs.isSkipEnabled = true;
      expect(prefs.isSkipEnabled, isTrue,
          reason: 'settings.preferences.skip-enabled#1');
    });

    test('#3 feeds Entry.nextToggleValue: YES_MANUAL -> SKIP when enabled', () {
      expect(
        Entry.nextToggleValue(Entry.yesManual,
            isSkipEnabled: true, areQuestionMarksEnabled: false),
        Entry.skip,
        reason: 'settings.preferences.skip-enabled#3',
      );
      expect(
        Entry.nextToggleValue(Entry.yesManual,
            isSkipEnabled: false, areQuestionMarksEnabled: false),
        Entry.no,
        reason: 'settings.preferences.skip-enabled#3',
      );
    });
  });

  group('settings.preferences.question-marks', () {
    test('#1 key pref_unknown_enabled, Boolean, default false', () {
      expect(prefs.areQuestionMarksEnabled, isFalse,
          reason: 'settings.preferences.question-marks#1');
      expect(storage.booleanDefaults['pref_unknown_enabled'], isFalse,
          reason: 'settings.preferences.question-marks#1');
    });

    test('#2 the setter writes then fires onQuestionMarksChanged', () {
      final second = CountingListener();
      prefs.addListener(second);
      prefs.areQuestionMarksEnabled = true;
      expect(storage.getString('pref_unknown_enabled', ''), 'true',
          reason: 'settings.preferences.question-marks#2');
      expect(listener.questionMarksChanged, 1,
          reason: 'settings.preferences.question-marks#2');
      expect(second.questionMarksChanged, 1,
          reason: 'settings.preferences.question-marks#2');
    });

    test('#4 feeds Entry.nextToggleValue: NO -> UNKNOWN when enabled', () {
      expect(
        Entry.nextToggleValue(Entry.no,
            isSkipEnabled: false, areQuestionMarksEnabled: true),
        Entry.unknown,
        reason: 'settings.preferences.question-marks#4',
      );
      expect(
        Entry.nextToggleValue(Entry.no,
            isSkipEnabled: false, areQuestionMarksEnabled: false),
        Entry.yesManual,
        reason: 'settings.preferences.question-marks#4',
      );
    });
  });

  group('settings.preferences.disable-animations', () {
    test('#1 key pref_disable_animation, Boolean, default false', () {
      expect(prefs.isConfettiAnimationDisabled, isFalse,
          reason: 'settings.preferences.disable-animations#1');
      expect(storage.booleanDefaults['pref_disable_animation'], isFalse,
          reason: 'settings.preferences.disable-animations#1');
      prefs.isConfettiAnimationDisabled = true;
      expect(prefs.isConfettiAnimationDisabled, isTrue,
          reason: 'settings.preferences.disable-animations#1');
    });
  });

  group('settings.preferences.habit-list-orders', () {
    test('#1 defaultPrimaryOrder resolves the stored enum name', () {
      expect(prefs.defaultPrimaryOrder, HabitListOrder.byPosition,
          reason: 'settings.preferences.habit-list-orders#1');
      storage.putString('pref_default_order', 'BY_SCORE_DESC');
      expect(prefs.defaultPrimaryOrder, HabitListOrder.byScoreDesc,
          reason: 'settings.preferences.habit-list-orders#1');
      expect(storage.stringDefaults['pref_default_order'], 'BY_POSITION',
          reason: 'settings.preferences.habit-list-orders#1');
    });

    test('#2 a bogus primary order is rewritten to BY_POSITION', () {
      storage.putString('pref_default_order', 'BOGUS');
      expect(prefs.defaultPrimaryOrder, HabitListOrder.byPosition,
          reason: 'settings.preferences.habit-list-orders#2');
      expect(storage.getString('pref_default_order', ''), 'BY_POSITION',
          reason: 'settings.preferences.habit-list-orders#2');
    });

    test('#3 defaultSecondaryOrder defaults to BY_NAME_ASC', () {
      expect(prefs.defaultSecondaryOrder, HabitListOrder.byNameAsc,
          reason: 'settings.preferences.habit-list-orders#3');
      expect(storage.stringDefaults['pref_default_secondary_order'],
          'BY_NAME_ASC',
          reason: 'settings.preferences.habit-list-orders#3');
      storage.putString('pref_default_secondary_order', 'BY_COLOR_DESC');
      expect(prefs.defaultSecondaryOrder, HabitListOrder.byColorDesc,
          reason: 'settings.preferences.habit-list-orders#3');
    });

    test('#4 a bogus secondary order writes BY_NAME_ASC but returns '
        'BY_POSITION (upstream inversion)', () {
      storage.putString('pref_default_secondary_order', 'BOGUS');
      expect(prefs.defaultSecondaryOrder, HabitListOrder.byPosition,
          reason: 'settings.preferences.habit-list-orders#4');
      expect(storage.getString('pref_default_secondary_order', ''),
          'BY_NAME_ASC',
          reason: 'settings.preferences.habit-list-orders#4');
    });

    test('#5 both setters write order.name', () {
      prefs.defaultPrimaryOrder = HabitListOrder.byStatusDesc;
      prefs.defaultSecondaryOrder = HabitListOrder.byNameDesc;
      expect(storage.getString('pref_default_order', ''), 'BY_STATUS_DESC',
          reason: 'settings.preferences.habit-list-orders#5');
      expect(storage.getString('pref_default_secondary_order', ''),
          'BY_NAME_DESC',
          reason: 'settings.preferences.habit-list-orders#5');
      for (final order in HabitListOrder.values) {
        prefs.defaultPrimaryOrder = order;
        expect(prefs.defaultPrimaryOrder, order,
            reason: 'settings.preferences.habit-list-orders#5');
      }
    });
  });

  group('settings.preferences.card-spinner-positions', () {
    test('#1 scoreCardSpinnerPosition clamps reads but not writes', () {
      expect(prefs.scoreCardSpinnerPosition, 1,
          reason: 'settings.preferences.card-spinner-positions#1');
      prefs.scoreCardSpinnerPosition = 4;
      expect(prefs.scoreCardSpinnerPosition, 4,
          reason: 'settings.preferences.card-spinner-positions#1');
      prefs.scoreCardSpinnerPosition = 9000;
      expect(storage.getString('pref_score_view_interval', ''), '9000',
          reason: 'settings.preferences.card-spinner-positions#1');
      expect(prefs.scoreCardSpinnerPosition, 4,
          reason: 'settings.preferences.card-spinner-positions#1');
    });

    test('#2 barCardBoolSpinnerPosition clamps to 0..3', () {
      expect(prefs.barCardBoolSpinnerPosition, 0,
          reason: 'settings.preferences.card-spinner-positions#2');
      prefs.barCardBoolSpinnerPosition = 2;
      expect(prefs.barCardBoolSpinnerPosition, 2,
          reason: 'settings.preferences.card-spinner-positions#2');
      prefs.barCardBoolSpinnerPosition = 9000;
      expect(storage.getString('pref_bar_card_bool_spinner', ''), '9000',
          reason: 'settings.preferences.card-spinner-positions#2');
      expect(prefs.barCardBoolSpinnerPosition, 3,
          reason: 'settings.preferences.card-spinner-positions#2');
    });

    test('#3 barCardNumericalSpinnerPosition clamps to 0..4', () {
      expect(prefs.barCardNumericalSpinnerPosition, 0,
          reason: 'settings.preferences.card-spinner-positions#3');
      prefs.barCardNumericalSpinnerPosition = 9000;
      expect(storage.getString('pref_bar_card_numerical_spinner', ''), '9000',
          reason: 'settings.preferences.card-spinner-positions#3');
      expect(prefs.barCardNumericalSpinnerPosition, 4,
          reason: 'settings.preferences.card-spinner-positions#3');
    });

    test('#4 negative stored values clamp to 0 in all three cases', () {
      storage.putInt('pref_score_view_interval', -1);
      storage.putInt('pref_bar_card_bool_spinner', -2);
      storage.putInt('pref_bar_card_numerical_spinner', -3);
      expect(prefs.scoreCardSpinnerPosition, 0,
          reason: 'settings.preferences.card-spinner-positions#4');
      expect(prefs.barCardBoolSpinnerPosition, 0,
          reason: 'settings.preferences.card-spinner-positions#4');
      expect(prefs.barCardNumericalSpinnerPosition, 0,
          reason: 'settings.preferences.card-spinner-positions#4');
    });
  });

  group('settings.preferences.hints', () {
    test('#1 lastHintNumber is read-only, key last_hint_number, default -1',
        () {
      expect(prefs.lastHintNumber, -1,
          reason: 'settings.preferences.hints#1');
      storage.putInt('last_hint_number', 12);
      expect(prefs.lastHintNumber, 12,
          reason: 'settings.preferences.hints#1');
    });

    test('#2 lastHintDate is null while the timestamp is negative', () {
      expect(prefs.lastHintDate, isNull, reason: 'settings.preferences.hints#2');
      storage.putLong('last_hint_timestamp', -1);
      expect(prefs.lastHintDate, isNull, reason: 'settings.preferences.hints#2');
      storage.putLong('last_hint_timestamp', -12345);
      expect(prefs.lastHintDate, isNull, reason: 'settings.preferences.hints#2');
      // Zero is not negative, so it resolves through LocalDate.fromUnixTime.
      storage.putLong('last_hint_timestamp', 0);
      expect(prefs.lastHintDate, LocalDate.ymd(1970, 1, 1),
          reason: 'settings.preferences.hints#2');
    });

    test('#3 updateLastHint writes both keys', () {
      final date = LocalDate.ymd(2015, 3, 15);
      prefs.updateLastHint(34, date);
      expect(storage.getString('last_hint_number', ''), '34',
          reason: 'settings.preferences.hints#3');
      expect(storage.getString('last_hint_timestamp', ''), '${date.unixTime}',
          reason: 'settings.preferences.hints#3');
      expect(prefs.lastHintNumber, 34, reason: 'settings.preferences.hints#3');
      expect(prefs.lastHintDate, date, reason: 'settings.preferences.hints#3');
    });

    test('#4 unixTime = 946684800000 + daysSince2000 * 86400000', () {
      expect(LocalDate(0).unixTime, 946684800000,
          reason: 'settings.preferences.hints#4');
      expect(LocalDate(1).unixTime, 946684800000 + 86400000,
          reason: 'settings.preferences.hints#4');
      final date = LocalDate.ymd(2015, 3, 15);
      expect(date.unixTime, 946684800000 + date.daysSince2000 * 86400000,
          reason: 'settings.preferences.hints#4');
    });
  });

  group('settings.preferences.first-run-and-launch-count', () {
    test('#1 isFirstRun defaults to true and is settable', () {
      expect(prefs.isFirstRun, isTrue,
          reason: 'settings.preferences.first-run-and-launch-count#1');
      expect(storage.booleanDefaults['pref_first_run'], isTrue,
          reason: 'settings.preferences.first-run-and-launch-count#1');
      prefs.isFirstRun = false;
      expect(prefs.isFirstRun, isFalse,
          reason: 'settings.preferences.first-run-and-launch-count#1');
    });

    test('#2 launchCount is read-only and incremented by one', () {
      expect(prefs.launchCount, 0,
          reason: 'settings.preferences.first-run-and-launch-count#2');
      expect(storage.intDefaults['launch_count'], 0,
          reason: 'settings.preferences.first-run-and-launch-count#2');
      prefs.incrementLaunchCount();
      expect(prefs.launchCount, 1,
          reason: 'settings.preferences.first-run-and-launch-count#2');
      prefs.incrementLaunchCount();
      expect(prefs.launchCount, 2,
          reason: 'settings.preferences.first-run-and-launch-count#2');
    });

    test('#3 lastAppVersion reads and writes last_version', () {
      expect(prefs.lastAppVersion, 0,
          reason: 'settings.preferences.first-run-and-launch-count#3');
      prefs.lastAppVersion = 23;
      expect(prefs.lastAppVersion, 23,
          reason: 'settings.preferences.first-run-and-launch-count#3');
      expect(storage.getString('last_version', ''), '23',
          reason: 'settings.preferences.first-run-and-launch-count#3');
    });
  });

  group('settings.preferences.show-archived-completed', () {
    test('#1 showArchived reads/writes pref_show_archived, default false', () {
      expect(prefs.showArchived, isFalse,
          reason: 'settings.preferences.show-archived-completed#1');
      expect(storage.booleanDefaults['pref_show_archived'], isFalse,
          reason: 'settings.preferences.show-archived-completed#1');
      prefs.showArchived = true;
      expect(prefs.showArchived, isTrue,
          reason: 'settings.preferences.show-archived-completed#1');
      expect(storage.getString('pref_show_archived', ''), 'true',
          reason: 'settings.preferences.show-archived-completed#1');
    });

    test('#2 showCompleted reads/writes pref_show_completed, default true', () {
      expect(prefs.showCompleted, isTrue,
          reason: 'settings.preferences.show-archived-completed#2');
      expect(storage.booleanDefaults['pref_show_completed'], isTrue,
          reason: 'settings.preferences.show-archived-completed#2');
      prefs.showCompleted = false;
      expect(prefs.showCompleted, isFalse,
          reason: 'settings.preferences.show-archived-completed#2');
      expect(storage.getString('pref_show_completed', ''), 'false',
          reason: 'settings.preferences.show-archived-completed#2');
    });
  });

  group('settings.widget-preferences.habit-ids', () {
    late SpyStorage widgetStorage;
    late WidgetPreferences widgetPrefs;

    setUp(() {
      widgetStorage = SpyStorage();
      widgetPrefs = WidgetPreferences(widgetStorage);
    });

    test('#1 the habit-id key is widget-%06d-habit', () {
      widgetPrefs.addWidget(42, <int>[1]);
      expect(widgetStorage.writtenKeys, contains('widget-000042-habit'),
          reason: 'settings.widget-preferences.habit-ids#1');
      widgetPrefs.addWidget(1234567, <int>[1]);
      expect(widgetStorage.writtenKeys, contains('widget-1234567-habit'),
          reason: 'settings.widget-preferences.habit-ids#1');
      widgetPrefs.addWidget(0, <int>[1]);
      expect(widgetStorage.writtenKeys, contains('widget-000000-habit'),
          reason: 'settings.widget-preferences.habit-ids#1');
    });

    test('#2 addWidget serialises the ids as a comma-separated string', () {
      widgetPrefs.addWidget(42, <int>[3, 1, 2]);
      expect(widgetStorage.getString('widget-000042-habit', ''), '3,1,2',
          reason: 'settings.widget-preferences.habit-ids#2');
      expect(widgetPrefs.getHabitIdsFromWidgetId(42), <int>[3, 1, 2],
          reason: 'settings.widget-preferences.habit-ids#2');
    });

    test('#3 legacy single-long data falls back to storage.getLong', () {
      final legacy = LegacyLongStorage();
      final legacyPrefs = WidgetPreferences(legacy);
      legacy.putLong('widget-000042-habit', 99);
      expect(legacyPrefs.getHabitIdsFromWidgetId(42), <int>[99],
          reason: 'settings.widget-preferences.habit-ids#3');
      expect(legacyPrefs.getHabitIdsFromWidgetId(43), <int>[],
          reason: 'settings.widget-preferences.habit-ids#3');
      legacy.putLong('widget-000044-habit', -1);
      expect(legacyPrefs.getHabitIdsFromWidgetId(44), <int>[],
          reason: 'settings.widget-preferences.habit-ids#3');
    });

    test('#4 #7 removeWidget removes the same formatted key', () {
      widgetPrefs.addWidget(42, <int>[1, 2]);
      widgetPrefs.addWidget(43, <int>[3]);
      widgetPrefs.removeWidget(42);
      expect(widgetStorage.removedKeys, <String>['widget-000042-habit'],
          reason: 'settings.widget-preferences.habit-ids#4');
      expect(widgetStorage.getString('widget-000042-habit', 'MISSING'),
          'MISSING',
          reason: 'settings.widget-preferences.habit-ids#7');
      expect(widgetPrefs.getHabitIdsFromWidgetId(43), <int>[3],
          reason: 'settings.widget-preferences.habit-ids#7');
    });

    test('#5 a widget stored with no habits reads back as an empty array', () {
      widgetPrefs.addWidget(42, <int>[]);
      expect(widgetStorage.getString('widget-000042-habit', 'MISSING'), '',
          reason: 'settings.widget-preferences.habit-ids#5');
      expect(widgetPrefs.getHabitIdsFromWidgetId(42), <int>[],
          reason: 'settings.widget-preferences.habit-ids#5');
      expect(widgetPrefs.getHabitIdsFromWidgetId(99), <int>[],
          reason: 'settings.widget-preferences.habit-ids#5');
    });

    test('#6 WidgetPreferences wraps a Preferences.Storage', () {
      final shared = MemoryStorage();
      final wrapping = WidgetPreferences(shared);
      wrapping.addWidget(7, <int>[5]);
      expect(shared.getString('widget-000007-habit', 'MISSING'), '5',
          reason: 'settings.widget-preferences.habit-ids#6');
      // The same Storage implementation also backs Preferences.
      final sharedPrefs = Preferences(shared);
      sharedPrefs.isSkipEnabled = true;
      expect(shared.getString('pref_skip_enabled', ''), 'true',
          reason: 'settings.widget-preferences.habit-ids#6');
      expect(wrapping.getHabitIdsFromWidgetId(7), <int>[5],
          reason: 'settings.widget-preferences.habit-ids#6');
    });

    test('#8 snooze times use snooze-%06d and default to 0', () {
      expect(widgetPrefs.getSnoozeTime(7), 0,
          reason: 'settings.widget-preferences.habit-ids#8');
      widgetPrefs.setSnoozeTime(7, 1234567890);
      expect(widgetStorage.getString('snooze-000007', 'MISSING'), '1234567890',
          reason: 'settings.widget-preferences.habit-ids#8');
      expect(widgetPrefs.getSnoozeTime(7), 1234567890,
          reason: 'settings.widget-preferences.habit-ids#8');
      widgetPrefs.removeSnoozeTime(7);
      expect(widgetStorage.getString('snooze-000007', 'MISSING'), '0',
          reason: 'settings.widget-preferences.habit-ids#8');
      expect(widgetStorage.removedKeys, isNot(contains('snooze-000007')),
          reason: 'settings.widget-preferences.habit-ids#8');
      expect(widgetPrefs.getSnoozeTime(7), 0,
          reason: 'settings.widget-preferences.habit-ids#8');
    });

    test('#9 the mapping survives a restart and is the only widget setting',
        () {
      final shared = MemoryStorage();
      WidgetPreferences(shared).addWidget(42, <int>[1, 2]);
      final afterRestart = WidgetPreferences(shared);
      expect(afterRestart.getHabitIdsFromWidgetId(42), <int>[1, 2],
          reason: 'settings.widget-preferences.habit-ids#9');

      final spy = SpyStorage();
      final spyPrefs = WidgetPreferences(spy);
      spyPrefs.addWidget(42, <int>[1, 2]);
      expect(spy.writtenKeys, <String>['widget-000042-habit'],
          reason: 'settings.widget-preferences.habit-ids#9');
    });
  });
}
