// The core is reached by its `src` path, exactly as lib/state/app_scope.dart
// reaches it.
// ignore_for_file: implementation_imports

import 'dart:convert';

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:home_widget/home_widget.dart';
import 'package:uhabits_core/src/gui/theme.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/score.dart';
import 'package:uhabits_core/src/models/streak.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/score_card.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/target_card.dart';

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
///   "midnightDelayHours": 0,
///   "widgetOpacity": 255,
///   "firstWeekday": 0,
///   "habits": [{
///     "id": 3, "name": "Run", "question": "...", "color": 1,
///     "type": "NUMERICAL", "unit": "miles",
///     "target": 2.0, "targetType": "AT_LEAST",
///     "value": 500,
///     "entries": [500, 1500, ... 60 values, newest first ...],
///     "notesIndicators": [false, true, ... one per entry ...],
///     "score": 0.63,
///     "scores": [0.63, 0.41, ... newest bucket first ...],
///     "bucketSize": 7,
///     "streaks": [{"start": "2015-01-20", "end": "2015-01-26", "length": 7}],
///     "weekdayFrequency": {"2015-01-01": [0, 1, 0, 2, 0, 0, 1]},
///     "targetRows": [{"interval": 7, "value": 4.0, "target": 10.0}]
///   }],
///   "missingHabitIds": []
/// }
/// ```
///
/// `value` is `entries[0]`, i.e. today's entry, kept as its own field because
/// the tick mark needs nothing else. `entries` is exactly [entryCount] values
/// read from `computedEntries` — not `originalEntries`, so the YES_AUTO days a
/// frequency implies are already filled in, the way every chart sees them.
/// Numerical values are in thousandths, as everywhere else in the model.
///
/// `notesIndicators` is `entries` seen from the other side: one boolean per
/// published day saying whether that entry carries a note, which is what the
/// History grid marks with a dot (`widgets.history#4`,
/// `audit6.history-home-screen-widget-never-draws#1`).
///
/// ## Why the derived fields are here rather than in the widget
///
/// Everything from `score` down is something a widget *draws* and cannot
/// compute: the score algorithm needs the habit's whole history and its
/// frequency, the streak list needs every entry ever recorded, the frequency
/// chart buckets the user's manual marks month by month for as long as the
/// habit has existed, and the target rows are calendar-truncated sums whose row
/// list depends on `frequency.denominator`. A widget process has none of that —
/// it has this document — so a contract carrying only sixty daily values leaves
/// the Checkmark ring empty, the Score chart blank, the Streak chart limited to
/// the last two months and the Target chart drawing rows the habit does not
/// have (`audit4.checkmark-widget-s-score-ring-is`,
/// `audit4.score-widget-draws-an-empty-chart`,
/// `audit4.streak-and-frequency-widgets-only-see`,
/// `audit4.target-widget-shows-the-wrong-rows`).
///
/// Each one is produced by the very presenter the detail screen uses —
/// [ScoreCardPresenter], [TargetCardPresenter], `computeWeekdayFrequency`,
/// `StreakList.getBest` — so a widget and the card behind it can never drift
/// apart, which is exactly what `widgets.score#3` and `widgets.target#5`
/// describe upstream, where the widget calls the same presenter.
///
/// `firstWeekday` is a preference rather than a habit property and so sits at
/// the top of the document, next to `widgetOpacity`. It is published as
/// `daysSinceSunday` (0 = Sunday … 6 = Saturday), the convention
/// `HistoryChartView.firstWeekday`, `FrequencyChartView.firstWeekday` and
/// `DateNames.firstWeekdayDaysSinceSunday` all read
/// (`audit4.history-and-frequency-home-screen-widgets`).
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
    Preferences? preferences,
    WidgetDeletionSource? deletions,
  })  : _habitList = habitList,
        _registry = registry,
        _platform = platform,
        _preferences = preferences,
        _deletions = deletions;

  final HabitList _habitList;

  final WidgetRegistry _registry;

  /// Which widgets exist and which habits each one shows. Exposed because
  /// `HabitPickerDialog.confirm()` writes into it: the picker is the only thing
  /// that ever adds a binding.
  WidgetRegistry get registry => _registry;

  final HomeWidgetPlatform _platform;

  final WidgetDeletionSource? _deletions;

  /// Who reports the widgets the launcher removed.
  ///
  /// Defaults to the platform itself, because on a real device it is one
  /// object: [HomeWidgetPlugin] both writes the documents and reads back what
  /// the providers left in the shared store. The constructor parameter is for
  /// a host that separates the two.
  WidgetDeletionSource? get _deletionSource {
    final WidgetDeletionSource? explicit = _deletions;
    if (explicit != null) return explicit;
    final Object platform = _platform;
    return platform is WidgetDeletionSource ? platform : null;
  }

  /// The half of `BaseWidget.prefs` a widget actually reads:
  /// `Preferences.widgetOpacity`.
  ///
  /// Optional because a host that publishes no preferences — every test that
  /// only cares about habit data — should not have to build one; absent, the
  /// document carries [defaultWidgetOpacity], which is the value the
  /// preference itself defaults to.
  final Preferences? _preferences;

  /// Bump whenever a field below changes meaning or disappears.
  static const int schemaVersion = 1;

  /// `android:defaultValue="255"` on the `pref_widget_opacity` row
  /// (`settings.preferences.widget-opacity#2`), i.e. fully opaque.
  static const int defaultWidgetOpacity = 255;

  /// `Preferences.widgetOpacity`, as the native side will read it.
  ///
  /// `BaseWidget.preferedBackgroundAlpha` is `if (stacked) 255 else
  /// prefs.widgetOpacity` (`settings.preferences.widget-opacity#5`), and the
  /// `stacked` half is decided in the launcher's process — so what crosses is
  /// the preference, not the alpha.
  int get widgetOpacity =>
      _preferences?.widgetOpacity ?? defaultWidgetOpacity;

  /// `Preferences.isSkipEnabled` and `Preferences.areQuestionMarksEnabled`,
  /// the two inputs of `Entry.nextToggleValue` (`widgets.behavior#3`).
  ///
  /// Their defaults are the preference's own, so a host that publishes no
  /// preferences describes a user who has changed neither.
  ///
  /// The second one is read twice over. It predicts the value a tap will write
  /// — that is the `nextToggleValue` half, and the reason it started life in
  /// the index — and it decides the glyph an unanswered day is *drawn* with:
  /// `CheckmarkWidgetView`'s `text` getter is `if
  /// (preferences.areQuestionMarksEnabled) fa_question else fa_times` for an
  /// UNKNOWN entry. Only the first half was ever published, so the Interface
  /// row "Show question marks for missing data" changed nothing on the home
  /// screen (`audit5.checkmark-home-screen-widget-never-draws#1`,
  /// `audit5.checkmark-widget-always-draws-for-an#1`).
  bool get isSkipEnabled => _preferences?.isSkipEnabled ?? false;

  bool get areQuestionMarksEnabled =>
      _preferences?.areQuestionMarksEnabled ?? false;

  /// `Preferences.firstWeekday`, as `daysSinceSunday` (0 = Sunday).
  ///
  /// `widgets.history#4` and `widgets.frequency#3`: both grids are laid out
  /// from the weekday the user chose in Settings, and neither widget can ask
  /// the preference store — it lives in the app's process.
  ///
  /// Sunday when no preferences were supplied, which is the default both native
  /// charts already carry.
  int get firstWeekday =>
      (_preferences?.firstWeekday ?? DayOfWeek.sunday).daysSinceSunday;

  /// `Preferences.midnightDelayHours` — 3 while the "new day starts at 3am"
  /// row is on, 0 otherwise.
  ///
  /// The one input of `computeToday(midnightDelayHours, 0)` that is not the
  /// system clock, and therefore the one thing a widget host needs in order to
  /// work out that the snapshot it is holding was built for an earlier day
  /// (`audit6.home-screen-widgets-go-stale-at#1`). Upstream the provider simply
  /// called `getToday()` — it ran inside the app, with `Preferences` at hand.
  ///
  /// Zero when no preferences were supplied, which is the preference's own
  /// default: a day that turns at midnight.
  int get midnightDelayHours => _preferences?.midnightDelayHours ?? 0;

  /// `Preferences.scoreCardSpinnerPosition` — the bucket the user last chose on
  /// the detail screen, which `widgets.score#3` says the Score widget follows.
  ///
  /// The preference's own default is 1 (weekly), so a host that publishes no
  /// preferences describes a user who has never touched the spinner.
  int get scoreCardSpinnerPosition => _preferences?.scoreCardSpinnerPosition ?? 1;

  /// The number of daily values published per habit. Sixty days covers the
  /// history grid at every size the launcher offers.
  ///
  /// It deliberately does *not* cover the Streak, Frequency, Score or Target
  /// widgets: each of those needs the habit's whole history, and widening this
  /// array until it did would put years of daily values in every document.
  /// What crosses instead is what those four draw, already reduced — `streaks`,
  /// `weekdayFrequency`, `scores`, `targetRows`.
  static const int entryCount = 60;

  /// How many score buckets travel with a habit, newest first.
  ///
  /// The Android chart plots six columns (`ScoreChartView`: `columnWidth =
  /// width / 6`) and the iOS one as many as its width admits; sixty is more
  /// than any launcher cell can show and bounds a document whose habit may have
  /// years of daily buckets behind it.
  static const int scoreBucketCount = 60;

  /// How many streaks travel with a habit — `habit.streaks.getBest(n)`.
  ///
  /// `widgets.streak#4`: the chart draws `floor(height / 20dp)` bars, so thirty
  /// covers a 600dp-tall widget. The native side re-selects the longest ones
  /// that fit out of these, which is `getBest` again on a superset and
  /// therefore the same answer.
  static const int streakCount = 30;

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

  /// The index, plus the habit catalogue iOS configures its widgets from.
  ///
  /// `widgets` is the Android half: one entry per registered widget id, which
  /// is what `WidgetPreferences` knows and what `HabitPickerDialog` writes.
  ///
  /// `habits` is the iOS half, and it is not derivable from the first. A
  /// WidgetKit widget has no widget id and no configure activity: it is bound
  /// by an App Intent whose habit parameter is filled from `HabitEntityQuery`,
  /// which lists "whatever the app has published"
  /// (`app/ios/HabitsWidget/HabitSelection.swift`). The registry is written by
  /// exactly one caller — the `uhabits://widget/configure` deep link, which
  /// only Android sends — so on iOS it is empty forever, and an index built
  /// from it alone offers no habit to pick, which leaves every widget stuck on
  /// its "open Loop Habit Tracker to set up this widget" card. Publishing the
  /// catalogue is what replaces the picker: the whole habit list, in list
  /// order, in the same per-habit shape a bound widget's own document carries,
  /// so a widget resolved out of the catalogue draws exactly what a widget
  /// resolved out of a document draws.
  ///
  /// Android reads none of it — `BaseWidgetProvider` resolves its habits from
  /// the widget id it was handed — but it is published on both platforms
  /// anyway: a `Platform.isIOS` branch here would be one more thing a widget
  /// test cannot reach, which is the class of defect this document is being
  /// fixed for.
  Map<String, Object?> buildIndexDocument() {
    final LocalDate today = getToday();
    return <String, Object?>{
      'version': schemaVersion,
      'today': formatDate(today),
      'providers': providerNames,
      'widgets': <Object?>[
        for (final int widgetId in _registry.widgetIds)
          <String, Object?>{
            'id': widgetId,
            'key': documentKey(widgetId),
            'habits': _registry.habitIdsOf(widgetId),
          },
      ],
      'habits': <Object?>[
        for (final Habit habit in _habitList) _habitDocument(habit, today),
      ],
      // `widgets.behavior#3`: the two preferences `Entry.nextToggleValue`
      // reads. They cross because an iOS widget flips its own card the instant
      // the finger lifts — `ToggleHabitIntent` — and has to predict the value
      // this app will write; a widget that guessed would show SKIP to a user
      // who has skip disabled and then correct itself on the next launch.
      'isSkipEnabled': isSkipEnabled,
      'areQuestionMarksEnabled': areQuestionMarksEnabled,
      // `widgets.history#4`, `widgets.frequency#3`: an iOS widget resolved out
      // of this catalogue draws the same grids a bound one does, so it needs
      // the same weekday origin.
      'firstWeekday': firstWeekday,
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
      // `audit6.home-screen-widgets-go-stale-at#1`: how the day above was
      // computed, so the host that redraws this document an hour — or a week —
      // later can work out whether it has gone stale and by how many days.
      // Upstream needed nothing of the sort: the provider ran inside the app
      // and called `getToday()` itself on every broadcast.
      'midnightDelayHours': midnightDelayHours,
      // `settings.preferences.widget-opacity#5`: the alpha the card's
      // background paint is drawn at, unless the widget is a page of a stack.
      'widgetOpacity': widgetOpacity,
      // `audit4.history-and-frequency-home-screen-widgets#1`: the History grid
      // and the Frequency grid both start on the weekday the user chose.
      'firstWeekday': firstWeekday,
      // `audit5.checkmark-home-screen-widget-never-draws#1`: upstream
      // `CheckmarkWidgetView` holds a live `Preferences` and reads
      // `areQuestionMarksEnabled` on every redraw, so an UNKNOWN entry is "?"
      // rather than "✗" for a user who turned the Interface row on. A widget
      // process cannot read `Preferences`, and this document is the only thing
      // it can read — so the flag rides here, next to the other two
      // preferences a widget draws with. It was published in the index (for
      // `Entry.nextToggleValue` on iOS) and nowhere else, which left the flag
      // reachable by the toggle that predicts the next value and unreachable by
      // the glyph that draws the current one.
      'areQuestionMarksEnabled': areQuestionMarksEnabled,
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
    // First, because everything below reads the registry: a widget the launcher
    // has already thrown away must not be looked up, published, or counted in
    // the index (`audit4.deleting-a-widget-from-the-launcher#1`).
    await reapDeletedWidgets();

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

  /// `BaseWidgetProvider.onDeleted` → `BaseWidget.delete()` →
  /// `WidgetPreferences.removeWidget(id)` (`widgets.provider-lifecycle#8`).
  ///
  /// Upstream those three calls are one statement in one process: the provider
  /// *is* the app, so the launcher's "this widget is gone" reaches the
  /// preference store directly. Here they are split by a process boundary, and
  /// only one side may write the store — a native writer would race the Flutter
  /// one with no lock between them. So the provider records the ids it was
  /// handed and this reaps them, which is the same two steps in the same order.
  ///
  /// Left undone, a deleted widget's `widget-%06d-habit` entry outlives the
  /// widget forever: `widgetIdsFor` keeps returning it, every command
  /// republishes a document for it, and the index the iOS side reads lists a
  /// widget nobody can see.
  ///
  /// The id stays in [_published] on purpose: dropping it from the registry is
  /// what makes the sweep in [publish] recognise it as stale and clear its
  /// document, which is the same key the provider removed — idempotent, and the
  /// only thing that cleans up after a launcher that reported the deletion
  /// while the app was not running.
  Future<void> reapDeletedWidgets() async {
    final WidgetDeletionSource? source = _deletionSource;
    if (source == null) return;
    for (final int widgetId in await source.takeDeletedWidgetIds()) {
      _registry.removeWidget(widgetId);
    }
  }

  Map<String, Object?> _habitDocument(Habit habit, LocalDate today) {
    final List<Entry> entries = habit.computedEntries.getByInterval(
      today.minus(entryCount - 1),
      today,
    );
    // The theme is part of every card state upstream and of none of this
    // document: a widget's palette is the compile-time `WidgetTheme` on both
    // native sides (`widgets.theme#5`). It is passed because the presenter
    // signature carries it, and it is the same one `ScoreWidget.refreshData`
    // and `TargetWidget.refreshData` pass upstream.
    final Theme theme = WidgetTheme();
    final ScoreCardState scoreCard = ScoreCardPresenter.buildState(
      habit: habit,
      firstWeekday: firstWeekday + 1,
      spinnerPosition: scoreCardSpinnerPosition,
      theme: theme,
    );
    final TargetCardState targetCard = TargetCardPresenter.buildState(
      habit: habit,
      firstWeekday: firstWeekday + 1,
      theme: theme,
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
      // `audit6.history-home-screen-widget-never-draws#1`: the note dot on the
      // History grid. `HistoryCardPresenter.buildState` computes it as
      // `entries.map { it.notes != "" }` and `HistoryWidget.refreshData`
      // assigns the result to `historyChart.notesIndicators`; a widget process
      // cannot see `Entry.notes`, and this array — one flag per published day,
      // in the same newest-first order as `entries` — is the whole of what it
      // needs. The text itself stays behind: the chart draws a dot, never a
      // note, and shipping a user's prose to the launcher's process buys
      // nothing.
      'notesIndicators': <bool>[
        for (final Entry entry in entries) entry.notes != '',
      ],
      // `widgets.checkmark#2`: the ring around the glyph is
      // `habit.scores[today].value`.
      'score': habit.scores[today].value,
      // `widgets.score#5`, `#6`: the bucketed series the chart plots, newest
      // bucket first, with the bucket it was built at (`widgets.score#3`).
      'scores': <double>[
        for (final Score score in scoreCard.scores.take(scoreBucketCount))
          score.value,
      ],
      'bucketSize': scoreCard.bucketSize,
      // `widgets.streak#3`: `habit.streaks.getBest(n)`, over the whole history.
      'streaks': <Object?>[
        for (final Streak streak in habit.streaks.getBest(streakCount))
          <String, Object?>{
            'start': formatDate(streak.start),
            'end': formatDate(streak.end),
            'length': streak.length,
          },
      ],
      // `widgets.frequency#3`, `#5`: the ORIGINAL entries — the user's own
      // marks — bucketed by month and weekday, so the YES_AUTO days a non-daily
      // frequency generates never appear.
      'weekdayFrequency': <String, Object?>{
        for (final MapEntry<LocalDate, List<int>> bucket
            in habit.originalEntries
                .computeWeekdayFrequency(isNumerical: habit.isNumerical)
                .entries)
          formatDate(bucket.key): bucket.value,
      },
      // `widgets.target#5`, `#6`, `#7`: one row per window this habit's
      // frequency admits, each with its calendar-truncated sum and its scaled,
      // skip-reduced target — in units, not thousandths.
      'targetRows': <Object?>[
        for (int i = 0; i < targetCard.intervals.length; i++)
          <String, Object?>{
            'interval': targetCard.intervals[i],
            'value': targetCard.values[i],
            'target': targetCard.targets[i],
          },
      ],
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

/// Which widgets the launcher has removed since anyone last asked.
///
/// Deliberately a second interface rather than another [HomeWidgetPlatform]
/// method: publishing and reaping are opposite directions across the same
/// boundary, and a host that can only be written to — an iOS build, where
/// WidgetKit has no `onDeleted` and no widget id to report — is a complete
/// [HomeWidgetPlatform] with nothing to say here.
///
/// The contract is *take*, not *read*: the ids are consumed, so a widget is
/// reaped once and a second publish does not walk the same list again.
abstract interface class WidgetDeletionSource {
  /// The widget ids `BaseWidgetProvider.onDeleted` recorded, and clears them.
  ///
  /// Never throws for the ordinary reasons a platform has no widget host; an
  /// empty list is the answer for "nothing was deleted" and for "there is
  /// nowhere for a widget to be deleted from" alike.
  Future<List<int>> takeDeletedWidgetIds();
}

/// [HomeWidgetPlatform] over the `home_widget` plugin.
///
/// Every call is guarded against [MissingPluginException], because a host with
/// no home-screen widgets is a normal condition, not a failure: macOS has no
/// widget host at all, and a widget test has no method channel. Letting the
/// exception escape would abort startup and leave the app showing nothing —
/// the same failure mode that a SQLite quoting bug already caused once.
class HomeWidgetPlugin implements HomeWidgetPlatform, WidgetDeletionSource {
  HomeWidgetPlugin({this.appGroupId = iosAppGroupId});

  /// Where `BaseWidgetProvider.onDeleted` leaves the ids it was handed —
  /// `WidgetData.DELETED_KEY` in
  /// `android/app/src/main/kotlin/org/isoron/uhabits/widgets/WidgetData.kt`.
  ///
  /// A JSON array of widget ids in the same shared store the documents live in,
  /// which is the only channel the two processes have: `onDeleted` runs in a
  /// broadcast receiver that may well have started the process, long before any
  /// Dart exists to be called (`audit4.deleting-a-widget-from-the-launcher#1`).
  static const String deletedKey = '${HomeWidgetBridge.keyPrefix}.deleted';

  /// The App Group both the app and `ios/HabitsWidget` belong to, and the one
  /// string that makes an iOS widget see anything at all.
  ///
  /// `WidgetContract.appGroupId` in `app/ios/HabitsWidget/WidgetData.swift` is
  /// the same literal, and both `ios/Runner/Runner.entitlements` and
  /// `ios/HabitsWidget/HabitsWidget.entitlements` declare it: three
  /// declarations that have to agree, and none of which the compiler checks.
  /// Until `HomeWidget.setAppGroupId` is given this value the iOS plugin
  /// answers every `saveWidgetData` with error -7 ("AppGroupId not set"), so
  /// the extension reads an empty suite and all six widgets stay blank.
  ///
  /// It is also the default, deliberately. The parameter existed before and
  /// defaulted to null; `AppScope` built `HomeWidgetPlugin()` and nothing ever
  /// called [ensureInitialized], so the group was never set — a gap nothing
  /// could observe from Dart. A default that is the real group makes the wiring
  /// impossible to forget.
  static const String iosAppGroupId = 'group.org.isoron.uhabits';

  /// The iOS App Group both the app and the widget extension belong to.
  /// Ignored on Android, where `SharedPreferences` is already shared with the
  /// provider and the plugin answers `setAppGroupId` with a plain `true`.
  final String? appGroupId;

  /// The one `setAppGroupId` call, memoised.
  Future<void>? _initialized;

  /// Names the App Group, once, before anything is written.
  ///
  /// Called at startup by `AppScope.startPlatformServices`, and again — for
  /// free, because the future is memoised — from every [saveWidgetData] and
  /// [updateWidget] below, so that a host which publishes without having
  /// booted through `AppScope` still writes into the shared suite instead of
  /// the app's own defaults.
  Future<void> ensureInitialized() {
    final String? id = appGroupId;
    if (id == null) return Future<void>.value();
    return _initialized ??= setAppGroupId(id);
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
  Future<void> saveWidgetData(String id, String? value) async {
    // Before the write, never after: a write that reaches the plugin first is
    // refused outright on iOS and lands in the wrong suite everywhere else.
    await ensureInitialized();
    await _ignoringMissingHost(
        () => HomeWidget.saveWidgetData<String>(id, value));
  }

  @override
  Future<void> updateWidget({
    required String name,
    required String qualifiedAndroidName,
    required String iOSName,
  }) async {
    await ensureInitialized();
    await _ignoringMissingHost(() => HomeWidget.updateWidget(
          name: name,
          qualifiedAndroidName: qualifiedAndroidName,
          iOSName: iOSName,
        ));
  }

  @override
  Future<void> setAppGroupId(String groupId) =>
      _ignoringMissingHost(() => HomeWidget.setAppGroupId(groupId));

  @override
  Future<List<int>> takeDeletedWidgetIds() async {
    await ensureInitialized();
    final String? recorded;
    try {
      recorded = await HomeWidget.getWidgetData<String>(deletedKey);
    } on MissingPluginException {
      // No widget host here, so no widget was ever placed to be deleted.
      return const <int>[];
    }
    if (recorded == null || recorded.isEmpty) return const <int>[];

    // Consumed before it is parsed: a record this build cannot read is still a
    // record of widgets that no longer exist, and leaving it behind would make
    // every later publish retry the same unparsable string forever.
    await saveWidgetData(deletedKey, null);

    final List<int> ids = <int>[];
    try {
      final Object? decoded = jsonDecode(recorded);
      if (decoded is List) {
        for (final Object? id in decoded) {
          if (id is int) ids.add(id);
          if (id is String) {
            final int? parsed = int.tryParse(id);
            if (parsed != null) ids.add(parsed);
          }
        }
      }
    } on FormatException {
      // Written by another process; a malformed record must not take the
      // publish — and with it every widget on the home screen — down with it.
    }
    return ids;
  }
}
