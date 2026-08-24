// The storage under test implements a core interface that is reached by its
// `src` path, exactly as lib/state/app_scope.dart reaches it.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uhabits/platform/file_preferences_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart' show HabitListOrder, LocalDate;

/// Tests for the persistent [PreferencesStorage] behind the Flutter app.
///
/// This is the counterpart of `SharedPreferencesStorage` in uhabits-android, so
/// the rules of `settings.preferences.android-storage-bridge` are the
/// specification. Two of them (#1 and #3) are met by a documented,
/// platform-inherent deviation, flagged where they are asserted.
///
/// Everything a `Preferences` getter can observe — the parsing semantics of
/// `settings.preferences.storage-contract` — must stay indistinguishable from
/// `MemoryStorage`, because the core preference tests were written against
/// that behaviour and the same getters now read from a file.
void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhabits_prefs');
    path = p.join(dir.path, 'preferences.json');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('settings.preferences.storage-contract', () {
    test('#1 every Storage method round-trips through the file', () {
      final storage = FilePreferencesStorage.atPath(path);

      storage.putBoolean('a_bool', true);
      storage.putInt('an_int', 42);
      storage.putLong('a_long', 946684800000);
      storage.putString('a_string', 'hello');

      final reopened = FilePreferencesStorage.atPath(path);
      expect(reopened.getBoolean('a_bool', false), isTrue,
          reason: 'settings.preferences.storage-contract#1');
      expect(reopened.getInt('an_int', 0), 42,
          reason: 'settings.preferences.storage-contract#1');
      expect(reopened.getLong('a_long', 0), 946684800000,
          reason: 'settings.preferences.storage-contract#1');
      expect(reopened.getString('a_string', ''), 'hello',
          reason: 'settings.preferences.storage-contract#1');
    });

    test('#2 #3 putLongArray and getLongArray keep their default behaviour',
        () {
      final storage = FilePreferencesStorage.atPath(path);

      storage.putLongArray('ids', <int>[1, 2, 3]);
      expect(FilePreferencesStorage.atPath(path).getString('ids', ''), '1,2,3',
          reason: 'settings.preferences.storage-contract#2');
      expect(FilePreferencesStorage.atPath(path).getLongArray('ids', <int>[9]),
          <int>[1, 2, 3],
          reason: 'settings.preferences.storage-contract#3');

      // An empty array writes the empty string, which reads back as the
      // caller's default rather than as an empty array.
      storage.putLongArray('ids', <int>[]);
      expect(FilePreferencesStorage.atPath(path).getString('ids', 'x'), '',
          reason: 'settings.preferences.storage-contract#2');
      expect(FilePreferencesStorage.atPath(path).getLongArray('ids', <int>[9]),
          <int>[9],
          reason: 'settings.preferences.storage-contract#3');

      // An unparsable element yields an empty array, NOT the default.
      storage.putString('ids', '1,x,3');
      expect(FilePreferencesStorage.atPath(path).getLongArray('ids', <int>[9]),
          isEmpty,
          reason: 'settings.preferences.storage-contract#3');
    });

    test('#4 every value is stored as its string form', () {
      final storage = FilePreferencesStorage.atPath(path);
      storage.putBoolean('a_bool', false);
      storage.putInt('an_int', -7);
      storage.putLong('a_long', 12);
      storage.putString('a_string', 'text');

      final stored = _readFile(path);
      expect(stored['a_bool'], 'false',
          reason: 'settings.preferences.storage-contract#4');
      expect(stored['an_int'], '-7',
          reason: 'settings.preferences.storage-contract#4');
      expect(stored['a_long'], '12',
          reason: 'settings.preferences.storage-contract#4');
      expect(stored['a_string'], 'text',
          reason: 'settings.preferences.storage-contract#4');
    });

    test('#5 a present but unparsable boolean reads as false, not the default',
        () {
      final storage = FilePreferencesStorage.atPath(path);
      storage.putString('weird', '7');

      final reopened = FilePreferencesStorage.atPath(path);
      expect(reopened.getBoolean('weird', true), isFalse,
          reason: 'settings.preferences.storage-contract#5');
      expect(reopened.getBoolean('absent', true), isTrue,
          reason: 'settings.preferences.storage-contract#5');
      expect(reopened.getBoolean('absent', false), isFalse,
          reason: 'settings.preferences.storage-contract#5');

      // toBoolean() is case insensitive.
      storage.putString('weird', 'TRUE');
      expect(
          FilePreferencesStorage.atPath(path).getBoolean('weird', false), isTrue,
          reason: 'settings.preferences.storage-contract#5');
    });

    test('#6 #7 a present non-numeric value falls back to the default', () {
      final storage = FilePreferencesStorage.atPath(path);
      storage.putString('weird', 'abc');

      final reopened = FilePreferencesStorage.atPath(path);
      expect(reopened.getInt('weird', 13), 13,
          reason: 'settings.preferences.storage-contract#6');
      expect(reopened.getInt('absent', 13), 13,
          reason: 'settings.preferences.storage-contract#6');
      expect(reopened.getLong('weird', 13), 13,
          reason: 'settings.preferences.storage-contract#7');
      expect(reopened.getLong('absent', 13), 13,
          reason: 'settings.preferences.storage-contract#7');
    });

    test('#8 getString returns the stored value, or the default when absent',
        () {
      final storage = FilePreferencesStorage.atPath(path);
      storage.putString('present', '');

      final reopened = FilePreferencesStorage.atPath(path);
      expect(reopened.getString('present', 'fallback'), '',
          reason: 'settings.preferences.storage-contract#8');
      expect(reopened.getString('absent', 'fallback'), 'fallback',
          reason: 'settings.preferences.storage-contract#8');
    });

    test('#9 remove deletes one key, clear empties the whole file', () {
      final storage = FilePreferencesStorage.atPath(path);
      storage.putString('one', '1');
      storage.putString('two', '2');

      storage.remove('one');
      var reopened = FilePreferencesStorage.atPath(path);
      expect(reopened.getString('one', 'gone'), 'gone',
          reason: 'settings.preferences.storage-contract#9');
      expect(reopened.getString('two', 'gone'), '2',
          reason: 'settings.preferences.storage-contract#9');

      storage.clear();
      expect(_readFile(path), isEmpty,
          reason: 'settings.preferences.storage-contract#9');
      reopened = FilePreferencesStorage.atPath(path);
      expect(reopened.getString('two', 'gone'), 'gone',
          reason: 'settings.preferences.storage-contract#9');
    });
  });

  group('settings.preferences.android-storage-bridge', () {
    test('#1 the app has a single canonical preferences file', () async {
      final storage = await FilePreferencesStorage.open(directory: dir.path);
      expect(storage.path, p.join(dir.path, 'preferences.json'),
          reason: 'settings.preferences.android-storage-bridge#1 (deviation: '
              'a JSON file stands in for the default SharedPreferences, which '
              'does not exist on iOS)');

      storage.putString('shared', 'yes');
      final second = await FilePreferencesStorage.open(directory: dir.path);
      expect(second.path, storage.path,
          reason: 'settings.preferences.android-storage-bridge#1');
      expect(second.getString('shared', ''), 'yes',
          reason: 'settings.preferences.android-storage-bridge#1');
    });

    test('#2 #8 the XML-declared defaults are written on the first launch', () {
      expect(File(path).existsSync(), isFalse);
      FilePreferencesStorage.atPath(path);

      expect(_readFile(path), <String, String>{
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
      }, reason: 'settings.preferences.android-storage-bridge#8');
      expect(FilePreferencesStorage.xmlDefaults, _readFile(path),
          reason: 'settings.preferences.android-storage-bridge#2');
    });

    test('#2 the defaults are not written again over an existing file', () {
      FilePreferencesStorage.atPath(path).putBoolean('pref_short_toggle', true);

      final reopened = FilePreferencesStorage.atPath(path);
      expect(reopened.getBoolean('pref_short_toggle', false), isTrue,
          reason: 'settings.preferences.android-storage-bridge#2');

      // A key removed after the defaults were materialised stays removed.
      reopened.remove('pref_widget_opacity');
      expect(
          FilePreferencesStorage.atPath(path)
              .getString('pref_widget_opacity', 'absent'),
          'absent',
          reason: 'settings.preferences.android-storage-bridge#2');
    });

    test('#3 a null value reads as an absent key instead of throwing', () {
      // Deviation: Kotlin force-unwraps the SharedPreferences result, so a key
      // stored as null throws. Dart's String is non-nullable and this storage
      // never returns null, so a null reads as an absent key and yields the
      // caller's default — which is what every Preferences getter expects.
      File(path).writeAsStringSync(
          jsonEncode(<String, Object?>{'pref_sync_key': null}));

      final storage = FilePreferencesStorage.atPath(path);
      expect(storage.getString('pref_sync_key', 'fallback'), 'fallback',
          reason: 'settings.preferences.android-storage-bridge#3 (deviation: '
              'a non-nullable String cannot reproduce the force-unwrap)');
    });

    test('#5 the four bridged keys reach Preferences on an external change',
        () {
      final storage = FilePreferencesStorage.atPath(path);
      final preferences = Preferences(storage);
      final listener = _RecordingListener();
      preferences.addListener(listener);

      _writeFile(path, <String, String>{
        'pref_checkmark_reverse_order': 'true',
        'pref_midnight_delay': 'true',
        'pref_sticky_notifications': 'true',
        'pref_unknown_enabled': 'true',
      });
      storage.reload();

      expect(preferences.isCheckmarkSequenceReversed, isTrue,
          reason: 'settings.preferences.android-storage-bridge#5');
      expect(preferences.isMidnightDelayEnabled, isTrue,
          reason: 'settings.preferences.android-storage-bridge#5');
      expect(preferences.shouldMakeNotificationsSticky(), isTrue,
          reason: 'settings.preferences.android-storage-bridge#5');
      expect(preferences.areQuestionMarksEnabled, isTrue,
          reason: 'settings.preferences.android-storage-bridge#5');
      // isMidnightDelayEnabled reports through onCheckmarkSequenceChanged too.
      expect(listener.events, <String>[
        'checkmark',
        'checkmark',
        'notifications',
        'questionMarks',
      ], reason: 'settings.preferences.android-storage-bridge#5');

      // Each bridged read uses false as its default, so a key that disappears
      // turns the preference off rather than leaving it alone.
      listener.events.clear();
      _writeFile(path, <String, String>{});
      storage.reload();
      expect(preferences.isMidnightDelayEnabled, isFalse,
          reason: 'settings.preferences.android-storage-bridge#5');
      expect(preferences.shouldMakeNotificationsSticky(), isFalse,
          reason: 'settings.preferences.android-storage-bridge#5');
      expect(listener.events, contains('notifications'),
          reason: 'settings.preferences.android-storage-bridge#5');
    });

    test('#6 no other key is bridged back into Preferences', () {
      final storage = FilePreferencesStorage.atPath(path);
      final preferences = Preferences(storage);
      final listener = _RecordingListener();
      preferences.addListener(listener);

      _writeFile(path, <String, String>{
        'pref_short_toggle': 'true',
        'pref_skip_enabled': 'true',
        'pref_pure_black': 'true',
        'pref_disable_animation': 'true',
        'pref_widget_opacity': '128',
        'pref_first_weekday': '2',
      });
      storage.reload();

      expect(listener.events, isEmpty,
          reason: 'settings.preferences.android-storage-bridge#6');
      // The values themselves are visible; only the callbacks are withheld.
      expect(preferences.isShortToggleEnabled, isTrue,
          reason: 'settings.preferences.android-storage-bridge#6');
      expect(preferences.widgetOpacity, 128,
          reason: 'settings.preferences.android-storage-bridge#6');
    });

    test('#7 an external change before onAttached dispatches nothing', () {
      final storage = FilePreferencesStorage.atPath(path);
      // No Preferences was ever built around this storage, so nothing has
      // called onAttached.
      _writeFile(path, <String, String>{'pref_midnight_delay': 'true'});

      expect(storage.reload, returnsNormally,
          reason: 'settings.preferences.android-storage-bridge#7');
      expect(storage.getBoolean('pref_midnight_delay', false), isTrue,
          reason: 'settings.preferences.android-storage-bridge#7');
    });

    test('#9 pref_first_weekday has no declared default', () {
      final storage = FilePreferencesStorage.atPath(path);
      expect(_readFile(path).containsKey('pref_first_weekday'), isFalse,
          reason: 'settings.preferences.android-storage-bridge#9');
      // Both readers in Preferences therefore see their own default and fall
      // back to the locale.
      expect(storage.getString('pref_first_weekday', ''), '',
          reason: 'settings.preferences.android-storage-bridge#9');
      expect(storage.getString('pref_first_weekday', '-1'), '-1',
          reason: 'settings.preferences.android-storage-bridge#9');
    });

    test('#4 a write performed while dispatching does not re-enter', () {
      final storage = FilePreferencesStorage.atPath(path);
      final preferences = Preferences(storage);
      final listener = _RecordingListener();
      preferences.addListener(listener);

      listener.onCheckmark = () {
        // The Android bridge unregisters itself before dispatching, so a write
        // made from inside a callback cannot re-enter the handler.
        _writeFile(path, <String, String>{
          'pref_checkmark_reverse_order': 'true',
          'pref_sticky_notifications': 'true',
        });
        storage.reload();
      };

      _writeFile(
          path, <String, String>{'pref_checkmark_reverse_order': 'true'});
      storage.reload();

      expect(listener.events, <String>['checkmark'],
          reason: 'settings.preferences.android-storage-bridge#4');
      expect(preferences.shouldMakeNotificationsSticky(), isFalse,
          reason: 'settings.preferences.android-storage-bridge#4');

      // The suppressed change is picked up by the next explicit reload.
      listener.onCheckmark = null;
      storage.reload();
      expect(listener.events, <String>['checkmark', 'notifications'],
          reason: 'settings.preferences.android-storage-bridge#4');
      expect(preferences.shouldMakeNotificationsSticky(), isTrue,
          reason: 'settings.preferences.android-storage-bridge#4');
    });
  });

  group('preferences survive a restart', () {
    test('the settings a user changes are still there next launch', () {
      final preferences = Preferences(FilePreferencesStorage.atPath(path));
      preferences.theme = 1;
      preferences.isPureBlackEnabled = true;
      preferences.widgetOpacity = 128;
      preferences.defaultPrimaryOrder = HabitListOrder.byScoreDesc;
      preferences.showArchived = true;
      preferences.showCompleted = false;
      preferences.setDefaultHabitColor(7);
      preferences.updateLastHint(3, LocalDate.ymd(2015, 1, 25));
      preferences.incrementLaunchCount();

      final restarted = Preferences(FilePreferencesStorage.atPath(path));
      expect(restarted.theme, 1, reason: 'settings.preferences.key-catalog#12');
      expect(restarted.isPureBlackEnabled, isTrue,
          reason: 'settings.preferences.key-catalog#16');
      expect(restarted.widgetOpacity, 128,
          reason: 'settings.preferences.key-catalog#23');
      expect(restarted.defaultPrimaryOrder, HabitListOrder.byScoreDesc,
          reason: 'settings.preferences.key-catalog#3');
      expect(restarted.showArchived, isTrue,
          reason: 'settings.preferences.key-catalog#10');
      expect(restarted.showCompleted, isFalse,
          reason: 'settings.preferences.key-catalog#11');
      expect(restarted.getDefaultHabitColor(0), 7,
          reason: 'settings.preferences.key-catalog#2');
      expect(restarted.lastHintNumber, 3,
          reason: 'settings.preferences.key-catalog#8');
      expect(restarted.lastHintDate, LocalDate.ymd(2015, 1, 25),
          reason: 'settings.preferences.key-catalog#9');
      expect(restarted.launchCount, 1,
          reason: 'settings.preferences.key-catalog#13');
    });

    test('the on-disk keys are the catalogued ones', () {
      final preferences = Preferences(FilePreferencesStorage.atPath(path));
      preferences.theme = 2;
      preferences.widgetOpacity = 64;
      preferences.isCheckmarkSequenceReversed = true;
      preferences.lastAppVersion = 30;

      final stored = _readFile(path);
      expect(stored['pref_theme'], '2',
          reason: 'settings.preferences.key-catalog#12');
      expect(stored['pref_widget_opacity'], '64',
          reason: 'settings.preferences.key-catalog#23');
      expect(stored['pref_checkmark_reverse_order'], 'true',
          reason: 'settings.preferences.key-catalog#20');
      expect(stored['last_version'], '30',
          reason: 'settings.preferences.key-catalog#22');
    });

    test('clear() empties the file and restores every default', () {
      final preferences = Preferences(FilePreferencesStorage.atPath(path));
      preferences.setDefaultHabitColor(9);
      preferences.clear();

      expect(_readFile(path), isEmpty,
          reason: 'settings.preferences.key-catalog#27');
      expect(preferences.getDefaultHabitColor(0), 0,
          reason: 'settings.preferences.key-catalog#27');
      // The XML defaults are materialised once and never again, exactly like
      // PreferenceManager.setDefaultValues(context, xml, false).
      expect(
          FilePreferencesStorage.atPath(path)
              .getString('pref_widget_opacity', 'absent'),
          'absent',
          reason: 'settings.preferences.android-storage-bridge#2');
    });
  });

  group('durable writes', () {
    test('a put leaves no temporary file behind', () {
      FilePreferencesStorage.atPath(path).putString('a', '1');

      final leftovers =
          dir.listSync().map((entity) => p.basename(entity.path)).toList()
            ..sort();
      expect(leftovers, <String>['preferences.json']);
    });

    test('the file stays readable JSON of strings', () {
      FilePreferencesStorage.atPath(path).putInt('an_int', 3);

      final decoded = jsonDecode(File(path).readAsStringSync());
      expect(decoded, isA<Map<String, dynamic>>());
      expect((decoded as Map<String, dynamic>).values,
          everyElement(isA<String>()));
    });

    test('a crash between the temp write and the rename keeps the old file',
        () {
      final storage = FilePreferencesStorage.atPath(path);
      storage.putString('committed', 'old');
      // The half-written temp file of a later put, interrupted before rename.
      File('$path.tmp').writeAsStringSync('{"committed": "new"');

      final reopened = FilePreferencesStorage.atPath(path);
      expect(reopened.getString('committed', ''), 'old');
      expect(File('$path.tmp').existsSync(), isFalse);
    });

    test('a crash during the very first write is recovered from the temp file',
        () {
      // Nothing was ever committed, but a complete temp file survived.
      File('$path.tmp')
          .writeAsStringSync(jsonEncode(<String, String>{'rescued': 'yes'}));

      final storage = FilePreferencesStorage.atPath(path);
      expect(storage.getString('rescued', ''), 'yes');
      expect(File(path).existsSync(), isTrue);
    });

    test('a corrupt file does not crash the app', () {
      File(path).writeAsStringSync('this is not json');

      final storage = FilePreferencesStorage.atPath(path);
      expect(storage.getString('anything', 'default'), 'default');
      // It is rewritten with the declared defaults, as on a first launch.
      expect(_readFile(path), FilePreferencesStorage.xmlDefaults);
    });

    test('a JSON value that is not a string is coerced or dropped', () {
      File(path).writeAsStringSync(jsonEncode(<String, Object?>{
        'as_number': 128,
        'as_bool': true,
        'as_null': null,
        'as_list': <int>[1, 2],
      }));

      final storage = FilePreferencesStorage.atPath(path);
      expect(storage.getInt('as_number', 0), 128);
      expect(storage.getBoolean('as_bool', false), isTrue);
      expect(storage.getString('as_null', 'default'), 'default');
      expect(storage.getString('as_list', 'default'), 'default');
    });

    test('a missing parent directory is created', () {
      final nested = p.join(dir.path, 'a', 'b', 'preferences.json');
      FilePreferencesStorage.atPath(nested).putString('a', '1');
      expect(FilePreferencesStorage.atPath(nested).getString('a', ''), '1');
    });
  });

  // =========================================================================
  // audit10.every-preference-write-can-throw-out
  //
  // A write is best-effort, exactly as on Android: every mutator of
  // SharedPreferencesStorage ends in `.apply()`, which commits the value to
  // memory and hands the XML write to a background thread. The call site is
  // told nothing, so a device that cannot write — one that has run out of
  // storage — keeps running with the setting live for this session, and the
  // startup write of `last_version` cannot take the app down with it.
  // =========================================================================

  group('audit10.every-preference-write-can-throw-out', () {
    const rule = 'audit10.every-preference-write-can-throw-out#1: on Android '
        'every Preferences.Storage mutator ends in SharedPreferences.Editor'
        '.apply(), which commits to memory and writes on a background thread, '
        'so a failed write is never reported to the caller and never throws.';

    /// Puts a directory where the temp file has to go, so the very
    /// `writeAsStringSync` that fails on a full device fails here too —
    /// deterministically, and on every platform.
    void blockWrites() => Directory('$path.tmp').createSync();

    test('#1 a write that cannot reach the disk is dropped, not thrown', () {
      final storage = FilePreferencesStorage.atPath(path);
      storage.putString('committed', 'old');
      blockWrites();

      expect(() => storage.putBoolean('pref_short_toggle', true),
          returnsNormally,
          reason: rule);
      expect(() => storage.putInt('last_version', 30), returnsNormally,
          reason: rule);
      expect(() => storage.putLong('a_long', 946684800000), returnsNormally,
          reason: rule);
      expect(() => storage.putString('a_string', 'hello'), returnsNormally,
          reason: rule);
      expect(() => storage.putLongArray('ids', <int>[1, 2]), returnsNormally,
          reason: rule);
      expect(() => storage.remove('committed'), returnsNormally, reason: rule);
      // clear() is the Settings "delete all data" path, where Kotlin's
      // sharedPrefs.edit().clear().apply() equally cannot throw.
      expect(storage.clear, returnsNormally, reason: rule);
    });

    test('#1 the value still applies for the session, and the committed file '
        'is untouched', () {
      final storage = FilePreferencesStorage.atPath(path);
      storage.putString('committed', 'old');
      blockWrites();

      storage.putBoolean('pref_midnight_delay', true);
      expect(storage.getBoolean('pref_midnight_delay', false), isTrue,
          reason: '$rule apply() commits to memory before it queues the '
              'write, so the setting holds until the app is restarted.');

      // The failure is in the temp write, before the rename, so the settings
      // the user already had are still on disk and still readable.
      expect(_readFile(path)['committed'], 'old',
          reason: '$rule a failed write cannot damage the committed file.');
      expect(FilePreferencesStorage.atPath(path).getString('committed', ''),
          'old',
          reason: '$rule and the store reopens on them.');
    });

    test('#1 a first launch that cannot write its defaults still opens', () {
      blockWrites();

      late FilePreferencesStorage storage;
      expect(() => storage = FilePreferencesStorage.atPath(path),
          returnsNormally,
          reason: '$rule PreferenceManager.setDefaultValues writes through the '
              'same editor, so a first launch on a full device cannot fail '
              'either.');
      expect(storage.getString('pref_sync_base_url', ''),
          'https://sync.loophabits.org',
          reason: '$rule the XML defaults are live in memory even though '
              'nothing reached the disk.');
      expect(File(path).existsSync(), isFalse, reason: rule);
    });
  });
}

Map<String, String> _readFile(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>)
        .map((key, value) => MapEntry(key, value as String));

void _writeFile(String path, Map<String, String> values) =>
    File(path).writeAsStringSync(jsonEncode(values));

class _RecordingListener extends PreferencesListener {
  final List<String> events = <String>[];

  /// Fired from inside onCheckmarkSequenceChanged, to reproduce a listener
  /// that writes preferences while the storage is dispatching.
  void Function()? onCheckmark;

  @override
  void onCheckmarkSequenceChanged() {
    events.add('checkmark');
    onCheckmark?.call();
  }

  @override
  void onNotificationsChanged() {
    events.add('notifications');
  }

  @override
  void onQuestionMarksChanged() {
    events.add('questionMarks');
  }
}
