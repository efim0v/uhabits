// The core is reached by its `src` path, exactly as lib/state/app_scope.dart
// reaches it.
// ignore_for_file: implementation_imports

import 'dart:convert';

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:home_widget/home_widget.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// The data half of the Android home-screen widgets
/// (`uhabits-android/.../widgets/`).
///
/// ## Why this is a data contract and not a port
///
/// On Android every widget is a `BaseWidgetProvider` subclass: the launcher
/// broadcasts `ACTION_APPWIDGET_UPDATE`, the provider reads the habit list out
/// of `HabitsApplication.component` *in the launcher's process*, and draws a
/// `RemoteViews` tree. None of that survives the port, for one reason: a
/// home-screen widget — an `AppWidgetProvider` on Android, a `WidgetKit`
/// extension on iOS — runs outside the Flutter engine and cannot execute Dart.
/// The rendering therefore stays native on both platforms, and what the Dart
/// side owes it is *data*.
///
/// So this class replaces `BaseWidgetProvider.getHabitsFromWidgetId` and the
/// `RemoteViews` building with a publish step: after every command, and at
/// every midnight rollover, it writes one JSON document per widget id plus one
/// index document into the storage both processes share (`SharedPreferences` on
/// Android, the App Group `UserDefaults` on iOS), and then pokes the native
/// widget host — which is the closest thing there is to
/// `context.sendBroadcast(ACTION_APPWIDGET_UPDATE)`.
///
/// ## The contract
///
/// Every document carries `"version"` ([schemaVersion]). The native side must
/// check it and refuse to render a version it does not know, because the shape
/// below will change and an old widget extension can outlive an app update by
/// as long as the user leaves it on the home screen.
///
/// The index, under [indexKey]:
///
/// ```json
/// {
///   "version": 1,
///   "today": "2015-01-26",
///   "providers": ["CheckmarkWidgetProvider", ...],
///   "widgets": [{"id": 1, "key": "uhabits.widget.1", "habits": [3, 7]}]
/// }
/// ```
///
/// One document per widget, under [documentKey]:
///
/// ```json
/// {
///   "version": 1,
///   "widgetId": 1,
///   "today": "2015-01-26",
///   "habits": [{
///     "id": 3, "name": "Run", "question": "...", "color": 1,
///     "type": "NUMERICAL", "unit": "miles",
///     "target": 2.0, "targetType": "AT_LEAST",
///     "value": 500,
///     "entries": [500, 1500, ... 60 values, newest first ...]
///   }],
///   "missingHabitIds": []
/// }
/// ```
///
/// `value` is `entries[0]`, i.e. today's entry, kept as its own field because
/// four of the six widgets need nothing else. `entries` is exactly
/// [entryCount] values read from `computedEntries` — not `originalEntries`, so
/// the YES_AUTO days a frequency implies are already filled in, the way every
/// chart sees them. Numerical values are in thousandths, as everywhere else in
/// the model.
///
/// `missingHabitIds` is where `HabitNotFoundException` went. Upstream a widget
/// bound to a deleted habit throws out of `getHabitsFromWidgetId` and
/// `BaseWidgetProvider` draws the "habit not found" error widget; the bridge
/// cannot throw across the process boundary, so it reports the ids it could not
/// resolve and lets the native side draw that same error state.
class HomeWidgetBridge {
  HomeWidgetBridge({
    required HabitList habitList,
    required WidgetRegistry registry,
    required HomeWidgetPlatform platform,
  })  : _habitList = habitList,
        _registry = registry,
        _platform = platform;

  final HabitList _habitList;

  final WidgetRegistry _registry;

  /// Which widgets exist and which habits each one shows. Exposed because
  /// `HabitPickerDialog.confirm()` writes into it: the picker is the only thing
  /// that ever adds a binding.
  WidgetRegistry get registry => _registry;

  final HomeWidgetPlatform _platform;

  /// Bump whenever a field below changes meaning or disappears.
  static const int schemaVersion = 1;

  /// The number of daily values published per habit. Sixty days covers the
  /// widest of the six widgets (the history grid) at every size the launcher
  /// offers.
  static const int entryCount = 60;

  static const String keyPrefix = 'uhabits';

  static const String indexKey = '$keyPrefix.index';

  /// The Android package the six `AppWidgetProvider` classes live in.
  static const String androidProviderPackage = 'org.isoron.uhabits.widgets';

  /// `widgets.updater#3`, verbatim and in order. On Android these are the
  /// provider class names; on iOS they are the `kind` strings of the WidgetKit
  /// entries, which are deliberately spelled the same.
  static const List<String> providerNames = <String>[
    'CheckmarkWidgetProvider',
    'HistoryWidgetProvider',
    'ScoreWidgetProvider',
    'StreakWidgetProvider',
    'FrequencyWidgetProvider',
    'TargetWidgetProvider',
  ];

  static String documentKey(int widgetId) => '$keyPrefix.widget.$widgetId';

  /// The widget ids whose documents were published last time, so that a widget
  /// the launcher removed has its document cleared rather than left to rot in
  /// shared storage.
  final Set<int> _published = <int>{};

  /// Port of `WidgetUpdater.updateWidgets(modifiedHabitId, providerClass)`'s
  /// filtering step.
  ///
  /// `widgets.updater#4`: a null [modifiedHabitId] means every installed
  /// widget; otherwise only the widgets whose stored habit id array contains
  /// that id.
  List<int> widgetIdsFor(int? modifiedHabitId) {
    final List<int> widgetIds = _registry.widgetIds;
    if (modifiedHabitId == null) return widgetIds;
    return widgetIds
        .where((int w) => _registry.habitIdsOf(w).contains(modifiedHabitId))
        .toList();
  }

  Map<String, Object?> buildIndexDocument() {
    return <String, Object?>{
      'version': schemaVersion,
      'today': formatDate(getToday()),
      'providers': providerNames,
      'widgets': <Object?>[
        for (final int widgetId in _registry.widgetIds)
          <String, Object?>{
            'id': widgetId,
            'key': documentKey(widgetId),
            'habits': _registry.habitIdsOf(widgetId),
          },
      ],
    };
  }

  /// Port of `BaseWidgetProvider.getHabitsFromWidgetId`, minus the exception.
  Map<String, Object?> buildWidgetDocument(int widgetId) {
    final LocalDate today = getToday();
    final List<Object?> habits = <Object?>[];
    final List<int> missing = <int>[];
    for (final int habitId in _registry.habitIdsOf(widgetId)) {
      final Habit? habit = _habitList.getById(habitId);
      if (habit == null) {
        missing.add(habitId);
      } else {
        habits.add(_habitDocument(habit, today));
      }
    }
    return <String, Object?>{
      'version': schemaVersion,
      'widgetId': widgetId,
      'today': formatDate(today),
      'habits': habits,
      'missingHabitIds': missing,
    };
  }

  /// Writes the documents and refreshes the six providers.
  ///
  /// The order matters and mirrors `WidgetUpdater.updateWidgets`: the data is
  /// in shared storage *before* the native side is told to redraw, otherwise
  /// the widget renders the previous day's numbers and only corrects itself on
  /// the next refresh.
  Future<void> publish([int? modifiedHabitId]) async {
    final List<int> installed = _registry.widgetIds;
    final List<int> modified = widgetIdsFor(modifiedHabitId);

    for (final int widgetId in modified) {
      await _platform.saveWidgetData(
        documentKey(widgetId),
        jsonEncode(buildWidgetDocument(widgetId)),
      );
      _published.add(widgetId);
    }

    // A widget the launcher removed: `WidgetPreferences.removeWidget` deleted
    // its habit-id key, so nothing binds it any more and its document is dead
    // weight in a store the native side still reads.
    for (final int stale in _published.difference(installed.toSet()).toList()) {
      await _platform.saveWidgetData(documentKey(stale), null);
      _published.remove(stale);
    }

    await _platform.saveWidgetData(indexKey, jsonEncode(buildIndexDocument()));

    // `widgets.updater#5`: upstream broadcasts to every provider even when the
    // filtered id array is empty, so the refresh below is unconditional too.
    for (final String provider in providerNames) {
      await _platform.updateWidget(
        name: provider,
        qualifiedAndroidName: '$androidProviderPackage.$provider',
        iOSName: provider,
      );
    }
  }

  Map<String, Object?> _habitDocument(Habit habit, LocalDate today) {
    final List<Entry> entries = habit.computedEntries.getByInterval(
      today.minus(entryCount - 1),
      today,
    );
    return <String, Object?>{
      'id': habit.id,
      'name': habit.name,
      'question': habit.question,
      'color': habit.color.paletteIndex,
      'type': habit.type.csvName,
      'unit': habit.unit,
      'target': habit.targetValue,
      'targetType': habit.targetType.csvName,
      'isArchived': habit.isArchived,
      'value': entries.isEmpty ? Entry.unknown : entries.first.value,
      'entries': <int>[for (final Entry entry in entries) entry.value],
    };
  }

  /// ISO-8601 calendar date. [LocalDate.toString] is a debug rendering, so the
  /// wire format is spelled out here.
  static String formatDate(LocalDate date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

// ---------------------------------------------------------------------------
// The widget id registry
// ---------------------------------------------------------------------------

/// The Dart stand-in for `AppWidgetManager.getAppWidgetIds(ComponentName(...))`
/// plus [WidgetPreferences].
///
/// `WidgetUpdater` asks the launcher which widget ids exist and then asks
/// `WidgetPreferences` which habits each one shows. There is no cross-platform
/// equivalent of the first question — `home_widget` cannot enumerate installed
/// widgets, and WidgetKit has no notion of a widget id at all — so the port
/// keeps the answer itself: [addWidget] and [removeWidget] maintain a set of
/// known ids alongside the per-widget habit list that
/// `settings.widget-preferences.habit-ids` specifies, in the same storage.
///
/// The habit mapping itself is untouched: every read and write goes through
/// [WidgetPreferences], so the `widget-%06d-habit` keys, their comma-separated
/// encoding and the Loop <= 1.7.11 migration path are exactly what a user
/// importing old `SharedPreferences` expects.
class WidgetRegistry {
  WidgetRegistry(this._storage, {WidgetPreferences? widgetPreferences})
      : preferences = widgetPreferences ?? WidgetPreferences(_storage);

  /// The set of widget ids the launcher currently shows. Not a per-widget
  /// setting — one key for all of them — so
  /// `settings.widget-preferences.habit-ids#9` still holds.
  static const String widgetIdsKey = 'widget-ids';

  final PreferencesStorage _storage;

  final WidgetPreferences preferences;

  /// In insertion order, which is the order the documents are published in.
  List<int> get widgetIds =>
      List<int>.of(_storage.getLongArray(widgetIdsKey, const <int>[]));

  List<int> habitIdsOf(int widgetId) =>
      preferences.getHabitIdsFromWidgetId(widgetId);

  /// `HabitPickerDialog.confirm()`: bind a freshly created widget to habits.
  void addWidget(int widgetId, List<int> habitIds) {
    preferences.addWidget(widgetId, habitIds);
    final List<int> ids = widgetIds;
    if (!ids.contains(widgetId)) {
      ids.add(widgetId);
      _storage.putLongArray(widgetIdsKey, ids);
    }
  }

  /// `BaseWidget.delete()`: the launcher reported the widget was removed.
  void removeWidget(int widgetId) {
    preferences.removeWidget(widgetId);
    final List<int> ids = widgetIds..remove(widgetId);
    _storage.putLongArray(widgetIdsKey, ids);
  }
}

// ---------------------------------------------------------------------------
// The platform boundary
// ---------------------------------------------------------------------------

/// What [HomeWidgetBridge] needs from the platform: write one value into the
/// shared store, and tell one widget host to redraw.
///
/// A plugin cannot run in a widget test, so this is where the port stops and
/// the fake takes over — the same shape `AlarmPlugin` and
/// `NotificationPresenter` use in this package.
abstract interface class HomeWidgetPlatform {
  /// `HomeWidget.saveWidgetData(id, data)`. A null [value] removes the key.
  Future<void> saveWidgetData(String id, String? value);

  /// `HomeWidget.updateWidget(...)`, the counterpart of
  /// `context.sendBroadcast(Intent(context, providerClass))`.
  Future<void> updateWidget({
    required String name,
    required String qualifiedAndroidName,
    required String iOSName,
  });

  /// `HomeWidget.setAppGroupId(groupId)`. Required on iOS, where the app and
  /// the widget extension only share storage through an App Group; a no-op on
  /// Android.
  Future<void> setAppGroupId(String groupId);
}

/// [HomeWidgetPlatform] over the `home_widget` plugin.
///
/// Every call is guarded against [MissingPluginException], because a host with
/// no home-screen widgets is a normal condition, not a failure: macOS has no
/// widget host at all, and a widget test has no method channel. Letting the
/// exception escape would abort startup and leave the app showing nothing —
/// the same failure mode that a SQLite quoting bug already caused once.
class HomeWidgetPlugin implements HomeWidgetPlatform {
  const HomeWidgetPlugin({this.appGroupId});

  /// The iOS App Group both the app and the widget extension belong to. Null on
  /// Android, where `SharedPreferences` is already shared with the provider.
  final String? appGroupId;

  /// Call once at startup, before the first publish.
  Future<void> ensureInitialized() async {
    final String? id = appGroupId;
    if (id != null) await setAppGroupId(id);
  }

  /// Runs [call], swallowing the "this platform has no widget host" case.
  static Future<void> _ignoringMissingHost(Future<void> Function() call) async {
    try {
      await call();
    } on MissingPluginException {
      // No widget host here. Nothing to publish to, nothing to report.
    }
  }

  @override
  Future<void> saveWidgetData(String id, String? value) =>
      _ignoringMissingHost(() => HomeWidget.saveWidgetData<String>(id, value));

  @override
  Future<void> updateWidget({
    required String name,
    required String qualifiedAndroidName,
    required String iOSName,
  }) =>
      _ignoringMissingHost(() => HomeWidget.updateWidget(
            name: name,
            qualifiedAndroidName: qualifiedAndroidName,
            iOSName: iOSName,
          ));

  @override
  Future<void> setAppGroupId(String groupId) =>
      _ignoringMissingHost(() => HomeWidget.setAppGroupId(groupId));
}
