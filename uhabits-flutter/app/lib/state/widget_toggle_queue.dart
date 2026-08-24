// The core is reached by its `src` path, exactly as lib/state/app_scope.dart
// reaches it.
// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:home_widget/home_widget.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import '../platform/home_widget_bridge.dart';
import 'widget_sync.dart' show WidgetBehavior;

/// The taps a home-screen widget performed while the app was not running.
///
/// ## Why this exists
///
/// Upstream, tapping a boolean Checkmark widget is a broadcast:
/// `WidgetReceiver` runs `WidgetBehavior.onToggleRepetition` in the app's
/// process and the widget flips in place, with nothing appearing on screen
/// (`widgets.checkmark#6`). The port could not do that — a widget runs outside
/// the Flutter engine and cannot execute Dart — and settled for opening the
/// app on every tap, which is the one thing the Checkmark widget exists to
/// avoid (`audit4.tapping-a-boolean-checkmark-widget-now#1`).
///
/// The background isolate the `home_widget` plugin offers is not a way out
/// either: `HomeWidgetBackgroundService` starts a bare `FlutterEngine` and
/// never runs `GeneratedPluginRegistrant`, so that isolate has no
/// `path_provider` to locate the database with and no channel behind
/// `AppDatabase`. It would be handed the URI and have nothing to open.
///
/// So the tap is *staged*. On iOS a widget `Button(intent:)` runs an
/// `AppIntent` inside the widget extension without foregrounding anything;
/// `ToggleHabitIntent` (in `app/ios/HabitsWidget/WidgetData.swift`) advances
/// the value the card draws — so the checkmark flips the instant the finger
/// lifts — and appends the tap to this queue. The app applies the queue at its
/// next publish, which is startup, every resume, every command and the day
/// rollover.
///
/// ## What is and is not preserved
///
/// Preserved: the entry is created by `WidgetBehavior.onToggleRepetition` on
/// the `CommandRunner`, exactly as the broadcast did upstream, so the list
/// cache, the notification tray, the reminder scheduler and the widget updater
/// all see it and the change is undoable. The value cycle is the core's
/// (`Entry.nextToggleValue` with the user's `isSkipEnabled` and
/// `areQuestionMarksEnabled`), because it is recomputed here rather than sent
/// across; the extension paints its own prediction from the same two
/// preferences, which the index publishes for that purpose.
///
/// Not preserved: for as long as the app stays closed, the flipped card is a
/// promise rather than a record. The database, and anything reading it —
/// a reminder that fires in the meantime — still sees the old value. That
/// window is the price of a tap that opens nothing, and it closes at the next
/// launch or resume.
///
/// ## The document
///
/// ```json
/// {"version": 1,
///  "toggles": [{"seq": 3, "habit": 7, "date": "2015-01-26"}]}
/// ```
///
/// `seq` is what makes draining idempotent: entries are removed by sequence
/// number after they are applied, and a tap that arrives while the drain is
/// running survives it. The extension allocates it as `max(seq) + 1`.
///
/// `date` is the day the tap was made on — the day the card was drawing, which
/// is the published day rolled forward to the day the extension is being drawn
/// on (`audit15.ios-home-screen-widgets-never-roll#1`). It is optional, exactly
/// as the Android toggle deep link carries no date at all: a tap staged out of
/// an index that names no day names none either, and [_apply] resolves it to
/// `getToday()` the way `IntentParser.parseDate` resolves a broadcast with no
/// `timestamp` extra.
class WidgetToggleQueue {
  WidgetToggleQueue({
    required WidgetDataStore store,
    required HabitList habitList,
    required WidgetBehavior behavior,
    Logging? logging,
  })  : _store = store,
        _habitList = habitList,
        _behavior = behavior,
        _logger = logging?.getLogger('WidgetToggleQueue');

  /// The key both sides use, in `HomeWidgetBridge`'s namespace because it is
  /// the same shared store and the same contract.
  static const String key = '${HomeWidgetBridge.keyPrefix}.pending';

  /// Bump whenever the shape above changes. A document this build does not
  /// understand is discarded rather than guessed at: a stale toggle is worth
  /// less than a wrong entry.
  static const int schemaVersion = 1;

  final WidgetDataStore _store;

  final HabitList _habitList;

  final WidgetBehavior _behavior;

  final Logger? _logger;

  /// Guards against reentrancy. Applying a tap runs a command, the command
  /// notifies `WidgetSync`, and `WidgetSync` publishes again — which would
  /// otherwise re-enter this method while the first pass is still holding the
  /// list it has not cleared yet.
  bool _draining = false;

  /// Applies every staged tap, then removes the ones that were applied.
  ///
  /// Never throws: this runs on the way to a publish, and a widget that wrote
  /// something unreadable must not stop the app from redrawing the others.
  Future<void> drain() async {
    if (_draining) return;
    _draining = true;
    try {
      await _drain();
    } on Object catch (error) {
      _logger?.error('Pending widget toggles could not be applied: $error');
    } finally {
      _draining = false;
    }
  }

  Future<void> _drain() async {
    final String? raw = await _store.read(key);
    if (raw == null || raw.isEmpty) return;

    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      await _store.write(key, null);
      return;
    }
    if (decoded['version'] != schemaVersion) {
      // A document from a future build. It cannot be applied and it cannot be
      // left to be retried forever.
      await _store.write(key, null);
      return;
    }

    final List<Object?> toggles =
        (decoded['toggles'] as List<Object?>?) ?? const <Object?>[];
    final Set<int> handled = <int>{};
    // The value each (habit, day) has been walked to so far in this pass. See
    // [_apply]: it is what stands in for the seconds that separate two
    // broadcasts upstream.
    final Map<String, Entry> walked = <String, Entry>{};
    for (final Object? entry in toggles) {
      if (entry is! Map<String, Object?>) continue;
      final int? seq = _asInt(entry['seq']);
      if (seq == null) continue;
      handled.add(seq);
      _apply(entry, walked);
    }
    if (handled.isEmpty) {
      await _store.write(key, null);
      return;
    }
    await _remove(handled);
  }

  /// One staged tap. A tap naming a habit that no longer exists, or a day the
  /// app refuses, is dropped: it is still removed from the queue, because
  /// leaving it there would retry it on every publish for the life of the
  /// install.
  ///
  /// ## The day a tap lands on
  ///
  /// Upstream a widget tap carries no day: `ACTION_TOGGLE_REPETITION` has no
  /// `timestamp` extra, and `IntentParser.parseDate` reads the extra with
  /// `getToday().unixTime` as its default and then refuses anything later than
  /// that — `IllegalArgumentException("timestamp is not valid")`, which
  /// `WidgetReceiver.onReceive` catches, leaving the broadcast unhandled. The
  /// same two rules apply to a staged tap, and for the same reason: the date on
  /// the queue was written by another process, out of a document that may be
  /// days old (`audit15.ios-home-screen-widgets-never-roll#1`).
  ///
  ///  * No date, or one that does not parse, means today — never "drop it".
  ///    `WidgetStore.stageToggle` omits the key when the index carries no
  ///    published day, exactly as the Android toggle deep link carries none,
  ///    and a tap the user has already watched the card answer must not vanish.
  ///  * A date later than [getToday] is refused outright. It is a day that has
  ///    not arrived — a clock or timezone that moved backwards between the tap
  ///    and the drain — and upstream nothing at all is written for one.
  ///
  /// A date *earlier* than today is applied as it stands. Upstream the write
  /// happens the instant the finger lifts, so a tap made yesterday belongs to
  /// yesterday; only the write is deferred here, not the day it was made on.
  ///
  /// ## Why the starting value is carried in [walked]
  ///
  /// Upstream every tap is its own `ACTION_TOGGLE_REPETITION` broadcast, and
  /// `WidgetBehavior.onToggleRepetition` re-reads
  /// `habit.originalEntries.get(date)` as its first statement — so tap 2, some
  /// seconds after tap 1, starts from what tap 1 wrote and a run of taps walks
  /// the cycle one step per tap (`audit10.ios-widget-taps-collapse#1`).
  ///
  /// Here the whole run is replayed in one pass, and the command the tap runs
  /// does not execute before this method returns: `CommandRunner.run` hands the
  /// command to the `TaskRunner`, whose production dispatcher is
  /// `AsyncDispatcher` — `Future(() => block())`. So the model still holds the
  /// pre-drain value for every tap in the run, and re-reading it would give
  /// each of them the same starting point: two taps would produce two identical
  /// commands, i.e. one advance, and a user who ticked a habit by mistake and
  /// tapped again to undo it would watch the card un-tick on the home screen
  /// and find the correction gone at the next publish.
  ///
  /// [walked] therefore remembers, per habit and day, the entry the previous
  /// tap in this pass asked for. Only that: a tap on another habit or another
  /// day still reads the model, because upstream it would have too.
  void _apply(Map<String, Object?> entry, Map<String, Entry> walked) {
    final int? habitId = _asInt(entry['habit']);
    if (habitId == null) return;
    final LocalDate today = getToday();
    final LocalDate date = _parseDate(entry['date']) ?? today;
    if (date > today) {
      _logger?.info(
        'Dropping a widget toggle for $date, which is later than $today',
      );
      return;
    }
    final Habit? habit = _habitList.getById(habitId);
    if (habit == null) {
      _logger?.info('Dropping a widget toggle for unknown habit $habitId');
      return;
    }
    final String key = '$habitId@${date.daysSince2000}';
    final Entry current = walked[key] ?? habit.originalEntries.get(date);
    // The same call the broadcast made upstream, on the same CommandRunner:
    // one `CreateRepetitionCommand` per tap, each separately undoable.
    walked[key] = _behavior.onToggleRepetitionFrom(habit, date, current);
  }

  /// Rewrites the queue without [handled], re-reading it first so that a tap
  /// staged while the drain was running is not lost.
  Future<void> _remove(Set<int> handled) async {
    final String? raw = await _store.read(key);
    if (raw == null || raw.isEmpty) return;
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      await _store.write(key, null);
      return;
    }
    final List<Object?> toggles =
        (decoded['toggles'] as List<Object?>?) ?? const <Object?>[];
    final List<Object?> remaining = <Object?>[
      for (final Object? entry in toggles)
        if (!(entry is Map<String, Object?> &&
            handled.contains(_asInt(entry['seq']))))
          entry,
    ];
    if (remaining.isEmpty) {
      await _store.write(key, null);
      return;
    }
    await _store.write(
      key,
      jsonEncode(<String, Object?>{
        'version': schemaVersion,
        'toggles': remaining,
      }),
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// `HomeWidgetBridge.formatDate` read back.
  static LocalDate? _parseDate(Object? value) {
    if (value is! String) return null;
    final List<String> parts = value.split('-');
    if (parts.length != 3) return null;
    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return LocalDate.ymd(year, month, day);
  }
}

/// Read/write access to the store the widgets share with the app.
///
/// [HomeWidgetPlatform] is write-only on purpose — publishing never reads —
/// so the one thing that does read is given its own seam rather than widening
/// an interface half a dozen fakes implement.
abstract interface class WidgetDataStore {
  /// `HomeWidget.getWidgetData(key)`.
  Future<String?> read(String key);

  /// `HomeWidget.saveWidgetData(key, value)`. A null [value] removes the key.
  Future<void> write(String key, String? value);
}

/// [WidgetDataStore] over the `home_widget` plugin.
///
/// Guarded against [MissingPluginException] for the reason [HomeWidgetPlugin]
/// is: a host with no widgets — macOS, a widget test — is a normal condition,
/// and a queue that cannot be read is simply an empty one.
class HomeWidgetStore implements WidgetDataStore {
  HomeWidgetStore({HomeWidgetPlugin? plugin})
      : _plugin = plugin ?? HomeWidgetPlugin();

  /// Only for its [HomeWidgetPlugin.ensureInitialized]: on iOS nothing can be
  /// read out of the App Group until the suite has been named, and this class
  /// may well be the first thing to touch it.
  final HomeWidgetPlugin _plugin;

  @override
  Future<String?> read(String key) async {
    try {
      await _plugin.ensureInitialized();
      return await HomeWidget.getWidgetData<String>(key);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> write(String key, String? value) =>
      _plugin.saveWidgetData(key, value);
}
