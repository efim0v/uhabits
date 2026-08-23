/// The Dart end of Android's intent plumbing.
///
/// Upstream, three components receive an `android.content.Intent` and turn it
/// into a call on a presenter:
///
///  * `receivers/WidgetReceiver.kt` — a home-screen widget tap, and the
///    Yes/No buttons of a reminder notification;
///  * `receivers/ReminderReceiver.kt` — the alarm that shows a reminder, the
///    notification's dismiss and snooze intents, and BOOT_COMPLETED;
///  * `activities/habits/list/ListHabitsActivity.parseIntents()` — the
///    ACTION_EDIT deep link that pops the value-entry dialog.
///
/// None of the three survives as a `BroadcastReceiver`: a receiver runs in the
/// launcher's or the system's process and cannot execute Dart. What survives is
/// the dispatch — which action does what, in which order, with what defaults,
/// and what happens when the intent is stale or malformed — and that is what
/// this file is. The two receivers become plain objects the app owns, fed by
/// whatever the platform hands over: a `uhabits://widget/...` deep link from
/// `android/.../widgets/WidgetIntents.kt`, or a notification response from
/// `flutter_local_notifications`.
///
/// Everything crosses the boundary as the core's [Intent] — the same
/// action/data/extras triple `IntentParser` already reads — so the deep link is
/// translated back into upstream's intent *once*, in [widgetLinkIntent], and
/// every branch downstream of that is the Kotlin one line for line.
///
/// ## The upstream bugs kept on purpose
///
///  * `WidgetReceiver` compares the action with Kotlin's `!==` — reference
///    inequality — before deciding whether to parse the intent. [identical] is
///    the same test, and it is used here for the same reason: see
///    [WidgetIntentReceiver.onReceive].
///  * `ACTION_SET_NUMERICAL_VALUE` is advertised by the manifest and has no
///    branch: such an intent is parsed and then dropped. [WidgetActions]
///    carries the constant and [WidgetActions.dispatched] deliberately does
///    not.
///  * `ACTION_DISMISS_REMINDER` is declared on `WidgetReceiver` too, with the
///    identical string, but only `ReminderReceiver` acts on it.
library;

// The core's presenters, models and logging are reached by their `src` path,
// exactly as the rest of lib/state does.
// ignore_for_file: implementation_imports

import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/intent_parser.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';

import 'widget_link.dart';
import 'widget_sync.dart';

export 'package:uhabits_core/src/ui/intent_parser.dart'
    show Intent, IntentParser, parseContentUriId;

// ---------------------------------------------------------------------------
// The constants
// ---------------------------------------------------------------------------

/// `WidgetReceiver`'s companion object, verbatim.
///
/// The strings are the persisted contract: a Tasker task, a launcher shortcut
/// or a widget placed by the Android build addresses the app with exactly
/// these, so they may never be renamed.
class WidgetActions {
  WidgetActions._();

  /// `WidgetReceiver.ACTION_ADD_REPETITION`.
  static const String addRepetition =
      'org.isoron.uhabits.ACTION_ADD_REPETITION';

  /// `WidgetReceiver.ACTION_DISMISS_REMINDER`.
  ///
  /// Declared here as upstream declares it — and, as upstream, never dispatched
  /// here: dismissal belongs to [ReminderIntentReceiver].
  static const String dismissReminder =
      'org.isoron.uhabits.ACTION_DISMISS_REMINDER';

  /// `WidgetReceiver.ACTION_REMOVE_REPETITION`.
  static const String removeRepetition =
      'org.isoron.uhabits.ACTION_REMOVE_REPETITION';

  /// `WidgetReceiver.ACTION_TOGGLE_REPETITION`.
  static const String toggleRepetition =
      'org.isoron.uhabits.ACTION_TOGGLE_REPETITION';

  /// `WidgetReceiver.ACTION_UPDATE_WIDGETS_VALUE`.
  static const String updateWidgetsValue =
      'org.isoron.uhabits.ACTION_UPDATE_WIDGETS_VALUE';

  /// Declared by the manifest's fourth `WidgetReceiver` intent-filter and by no
  /// Kotlin constant at all — a filter with no branch behind it.
  static const String setNumericalValue =
      'org.isoron.uhabits.ACTION_SET_NUMERICAL_VALUE';

  /// The four actions the `when` block really has a branch for, in the order
  /// they appear in `WidgetReceiver.onReceive`.
  static const List<String> dispatched = <String>[
    addRepetition,
    toggleRepetition,
    removeRepetition,
    updateWidgetsValue,
  ];

  /// The four actions the manifest exposes to other apps, in declaration
  /// order. `ACTION_SET_NUMERICAL_VALUE` is first and is the dead one.
  static const List<String> exported = <String>[
    setNumericalValue,
    toggleRepetition,
    addRepetition,
    removeRepetition,
  ];
}

/// `ReminderReceiver`'s companion object, verbatim.
class ReminderIntentActions {
  ReminderIntentActions._();

  /// `ReminderReceiver.ACTION_SHOW_REMINDER`.
  static const String showReminder = 'org.isoron.uhabits.ACTION_SHOW_REMINDER';

  /// `ReminderReceiver.ACTION_DISMISS_REMINDER` — the same string
  /// `WidgetReceiver` also declares.
  static const String dismissReminder =
      'org.isoron.uhabits.ACTION_DISMISS_REMINDER';

  /// `ReminderReceiver.ACTION_SNOOZE_REMINDER`.
  static const String snoozeReminder =
      'org.isoron.uhabits.ACTION_SNOOZE_REMINDER';

  /// `android.content.Intent.ACTION_BOOT_COMPLETED`, the receiver's only
  /// manifest filter.
  static const String bootCompleted = 'android.intent.action.BOOT_COMPLETED';
}

/// `ListHabitsActivity.ACTION_EDIT`.
const String actionEdit = 'org.isoron.uhabits.ACTION_EDIT';

/// `Habit.uriString`: `content://org.isoron.uhabits/habit/<id>`.
///
/// The authority is the application id, which is why it may not change: every
/// widget already on a home screen holds a `PendingIntent` addressed with it.
Uri habitUri(int id) => Uri.parse('content://org.isoron.uhabits/habit/$id');

/// Android's `Intent.toString()`, near enough for a log line.
///
/// `Log.i(TAG, "Received intent: %s".format(intent))` is the first statement of
/// both receivers, and a log line that says only "an intent arrived" is worth
/// nothing when a widget stops responding.
String describeIntent(Intent intent) {
  final StringBuffer out = StringBuffer('Intent { ');
  if (intent.action != null) out.write('act=${intent.action} ');
  if (intent.data != null) out.write('dat=${intent.data} ');
  if (intent.extras.isNotEmpty) out.write('(has extras) ');
  out.write('}');
  return out.toString();
}

// ---------------------------------------------------------------------------
// WidgetReceiver
// ---------------------------------------------------------------------------

/// Port of `uhabits-android/.../receivers/WidgetReceiver.kt`.
///
/// Upstream this is a `BroadcastReceiver` whose `onReceive` builds a
/// `WidgetComponent` per broadcast; here the collaborators are injected once,
/// because there is no process to rebuild them in.
class WidgetIntentReceiver {
  WidgetIntentReceiver({
    required IntentParser parser,
    required WidgetBehavior controller,
    required Preferences preferences,
    required Future<void> Function() updateWidgets,
    required void Function() scheduleStartDayWidgetUpdate,
    required Logging logging,
  })  : _parser = parser,
        _controller = controller,
        _preferences = preferences,
        _updateWidgets = updateWidgets,
        _scheduleStartDayWidgetUpdate = scheduleStartDayWidgetUpdate,
        _logger = logging.getLogger(tag);

  /// `private const val TAG = "WidgetReceiver"`.
  static const String tag = 'WidgetReceiver';

  final IntentParser _parser;
  final WidgetBehavior _controller;
  final Preferences _preferences;
  final Future<void> Function() _updateWidgets;
  final void Function() _scheduleStartDayWidgetUpdate;
  final Logger _logger;

  /// `WidgetReceiver.lastReceivedIntent`, a `var` with a private setter on the
  /// companion object.
  ///
  /// It exists for the instrumentation tests, which have no other way to see
  /// that a broadcast arrived; it is static there and static here for the same
  /// reason — the observer never holds the receiver.
  static Intent? get lastReceivedIntent => _lastReceivedIntent;

  static Intent? _lastReceivedIntent;

  /// `WidgetReceiver.clearLastReceivedIntent()`: the only way to null it.
  static void clearLastReceivedIntent() {
    _lastReceivedIntent = null;
  }

  /// `WidgetReceiver.onReceive(context, intent)`.
  void onReceive(Intent intent) {
    _logger.info('Received intent: ${describeIntent(intent)}');
    _lastReceivedIntent = intent;
    try {
      CheckmarkIntentData? data;
      // Kotlin: `if (intent.action !== ACTION_UPDATE_WIDGETS_VALUE)`. That is
      // reference inequality, not equality, and [identical] is its exact
      // counterpart. Kept rather than corrected because the difference is
      // observable: an update-widgets intent whose action is an equal but
      // distinct string is sent through `parseCheckmarkIntent`, which throws on
      // its missing data uri, and the rollover silently does nothing. Every
      // caller inside the app passes the constant itself, so the live path is
      // the fast one either way.
      if (!identical(intent.action, WidgetActions.updateWidgetsValue)) {
        data = _parser.parseCheckmarkIntent(intent);
      }
      switch (intent.action) {
        case WidgetActions.addRepetition:
          _logger.debug(
            'onAddRepetition habit=${data!.habit.id} date=${data.date}',
          );
          _controller.onAddRepetition(data.habit, data.date);
        case WidgetActions.toggleRepetition:
          _logger.debug(
            'onToggleRepetition habit=${data!.habit.id} date=${data.date}',
          );
          _controller.onToggleRepetition(data.habit, data.date);
        case WidgetActions.removeRepetition:
          _logger.debug(
            'onRemoveRepetition habit=${data!.habit.id} date=${data.date}',
          );
          _controller.onRemoveRepetition(data.habit, data.date);
        case WidgetActions.updateWidgetsValue:
          setToday(computeToday(_preferences.midnightDelayHours, 0));
          _updateWidgets();
          _scheduleStartDayWidgetUpdate();
        default:
          // `ACTION_SET_NUMERICAL_VALUE` and anything else the manifest lets
          // through: parsed above, then dropped.
          break;
      }
    } catch (error, stackTrace) {
      // Kotlin catches `RuntimeException`. Its Dart counterpart is not
      // `Exception` — `IntentParser` signals a stale widget with
      // `ArgumentError`, which is an `Error` — so the clause has to be the
      // untyped one or the very failure the catch exists for would escape.
      _logger.error('could not process intent');
      _logger.error(error, stackTrace);
    }
  }
}

// ---------------------------------------------------------------------------
// ReminderReceiver
// ---------------------------------------------------------------------------

/// Port of `uhabits-android/.../receivers/ReminderReceiver.kt`.
class ReminderIntentReceiver {
  ReminderIntentReceiver({
    required HabitList habits,
    required ReminderController controller,
    required Logging logging,
    void Function(Habit habit)? onSnoozePressed,
  })  : _habits = habits,
        _controller = controller,
        _onSnoozePressed = onSnoozePressed,
        _logger = logging.getLogger(tag);

  /// `private const val TAG = "ReminderReceiver"`.
  static const String tag = 'ReminderReceiver';

  final HabitList _habits;
  final ReminderController _controller;
  final Logger _logger;

  /// `ReminderController.onSnoozePressed(habit, context)`, whose entire Kotlin
  /// body is `startActivity(SnoozeDelayPickerActivity)`. The app supplies the
  /// dialog; a host with nowhere to show one supplies nothing.
  final void Function(Habit habit)? _onSnoozePressed;

  /// `ReminderReceiver.lastReceivedIntent`. See
  /// [WidgetIntentReceiver.lastReceivedIntent] — a separate field on a separate
  /// companion, so one receiver's traffic never hides the other's.
  static Intent? get lastReceivedIntent => _lastReceivedIntent;

  static Intent? _lastReceivedIntent;

  /// `ReminderReceiver.clearLastReceivedIntent()`.
  static void clearLastReceivedIntent() {
    _lastReceivedIntent = null;
  }

  /// `ReminderReceiver.onReceive(context, intent)`.
  ///
  /// The nullable parameter is Kotlin's: `onReceive(context: Context?, intent:
  /// Intent?)` returns immediately when either is null, and again when the
  /// action is null.
  void onReceive(Intent? intent) {
    if (intent == null) return;
    if (intent.action == null) return;
    _lastReceivedIntent = intent;
    _logger.info('Received intent: ${describeIntent(intent)}');

    Habit? habit;
    final int todayMillis = getToday().unixTime;
    final Uri? data = intent.data;
    if (data != null) habit = _habits.getById(parseContentUriId(data));
    // Both extras fall back to today's local midnight, so an intent that lost
    // them still targets a real day instead of the epoch.
    final int timestamp = intent.getLongExtra('timestamp', todayMillis);
    final int reminderTime = intent.getLongExtra('reminderTime', todayMillis);

    try {
      switch (intent.action) {
        case ReminderIntentActions.showReminder:
          if (habit == null) return;
          _logger.debug('onShowReminder habit=${habit.id} '
              'timestamp=$timestamp reminderTime=$reminderTime');
          _controller.onShowReminder(
            habit,
            LocalDate.fromUnixTime(timestamp),
            reminderTime,
          );
        case ReminderIntentActions.dismissReminder:
          if (habit == null) return;
          _logger.debug('onDismiss habit=${habit.id}');
          _controller.onDismiss(habit);
        case ReminderIntentActions.snoozeReminder:
          if (habit == null) return;
          // Upstream gates this on `SDK_INT < S`: from Android 12 a
          // notification action may not start an activity, so the branch only
          // logs a warning and the "Later" button does nothing. The port
          // answers the tap in Dart and shows a dialog inside the running app,
          // so there is no trampoline to forbid and no version to gate on —
          // the same decision DEVIATIONS.md records for
          // `reminders.snooze-android12-gate`.
          _logger.debug('onSnoozePressed habit=${habit.id}');
          _onSnoozePressed?.call(habit);
        case ReminderIntentActions.bootCompleted:
          _logger.debug('onBootCompleted');
          _controller.onBootCompleted();
        default:
          break;
      }
    } catch (error, stackTrace) {
      _logger.error('could not process intent');
      _logger.error(error, stackTrace);
    }
  }
}

// ---------------------------------------------------------------------------
// The deep link, as the Intent it stands for
// ---------------------------------------------------------------------------

/// Translates one `uhabits://widget/...` link into the Android intent the
/// upstream widget would have sent.
///
/// Returns null for a link with no upstream intent behind it — `configure`,
/// which is answered by the picker dialog rather than by a receiver — and for a
/// link missing the habit id every other action needs.
///
/// [today] is the app-wide today, i.e. `getToday()`. It is passed rather than
/// read so that the caller decides when the clock is sampled — and so that a
/// `show` link, which carries no date at all, can be routed without one:
/// `getToday()` throws until the app has booted, and a deep link must not be
/// what discovers that.
Intent? widgetLinkIntent(WidgetLink link, {required LocalDate today}) {
  final int? habitId = link.habitId;
  if (habitId == null) return null;
  // `LocalDate.unixTime` — the same long the Kotlin `PendingIntent` factory
  // puts in the 'timestamp' extra. A link with no date, or with one this app
  // did not write, falls back to today, exactly as `IntentParser._parseDate`
  // falls back to `getToday().unixTime` when the extra is missing.
  final int timestamp = (parseIsoDate(link.date) ?? today).unixTime;

  switch (link.action) {
    case WidgetLink.actionToggle:
      // `PendingIntentFactory.toggleCheckmark(habit, timestamp)`: broadcast to
      // WidgetReceiver, data = habit.uriString, 'timestamp' extra.
      return Intent(
        action: WidgetActions.toggleRepetition,
        data: habitUri(habitId),
        extras: <String, Object?>{'timestamp': timestamp},
      );
    case WidgetLink.actionEdit:
      // `PendingIntentFactory.showNumberPicker(habit, date)`: an *activity*
      // intent to ListHabitsActivity with ACTION_EDIT and the two extras
      // 'habit' and 'timestamp' — note the key is 'habit', not 'habitId', and
      // that this intent carries no data uri at all.
      return Intent(
        action: actionEdit,
        extras: <String, Object?>{'habit': habitId, 'timestamp': timestamp},
      );
    case WidgetLink.actionShow:
      // `IntentFactory.startShowHabitActivity(context, habit)`: no action, the
      // habit uri as data. ShowHabitActivity reads nothing else.
      return Intent(data: habitUri(habitId));
    default:
      return null;
  }
}

/// The inverse of `HomeWidgetBridge.formatDate`: `yyyy-MM-dd` back to a
/// [LocalDate], or null when the text is absent or not a calendar date.
///
/// Nothing here trusts its input — the string arrives from another process —
/// so a malformed date degrades to "no date", never to an exception.
LocalDate? parseIsoDate(String? text) {
  if (text == null) return null;
  final RegExpMatch? match =
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (match == null) return null;
  final int year = int.parse(match.group(1)!);
  final int month = int.parse(match.group(2)!);
  final int day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final LocalDate date = LocalDate.ymd(year, month, day);
  // `LocalDate.ymd` goes through a millisecond instant, so 2025-02-31 comes
  // back as 2025-03-03 rather than as an error. Rejecting the round-trip
  // mismatch is what makes this a parser instead of a normaliser.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}
