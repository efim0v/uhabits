/// The Dart end of a reminder notification: what happens when the user taps
/// one, or one of its buttons.
///
/// ## What this replaces
///
/// Upstream a reminder is a bundle of `PendingIntent`s built by
/// `intents/PendingIntentFactory.kt`, and each one lands somewhere inside the
/// same process:
///
///  * the content intent — a tap on the body — starts `ShowHabitActivity` with
///    `ListHabitsActivity` beneath it on the back stack;
///  * "Yes" and "No" broadcast ACTION_ADD_REPETITION / ACTION_REMOVE_REPETITION
///    to `WidgetReceiver`, which writes the entry without any UI;
///  * "Enter" is an activity intent to `ListHabitsActivity` with ACTION_EDIT,
///    whose `parseIntents()` pops the numeric value dialog;
///  * "Later" broadcasts ACTION_SNOOZE_REMINDER to `ReminderReceiver`, which
///    starts `SnoozeDelayPickerActivity`;
///  * the delete intent — a swipe — broadcasts ACTION_DISMISS_REMINDER to the
///    same receiver.
///
/// None of those exists here. `flutter_local_notifications` reports every one
/// of them as a single `NotificationResponse`, whose only content is the
/// action id and the payload string the notification was posted with. This
/// file is what turns that back into the intent upstream would have sent and
/// hands it to the ported receiver — [WidgetIntentReceiver] for the two
/// checkmark actions, [ReminderIntentReceiver] for snooze and dismiss — so
/// that every decision after the translation is the Kotlin one, line for line.
///
/// ## Why the router is owned by the scope and not by a widget
///
/// A notification can *start* the app. The callback therefore has to be
/// registered during `AppScope.startPlatformServices`, which runs inside
/// `AppScope.boot()` before `runApp`, and it has to belong to an object with
/// the application's lifetime rather than a screen's — by the time the first
/// frame is built, the response has already arrived. The three answers that
/// need a screen (open the habit, open the value dialog, open the snooze
/// picker) are hooks the app widget installs when it mounts, and a response
/// that arrives before it does waits in [_pending], exactly as an `Intent`
/// waits on an activity that has not been created yet.
///
/// Two deliveries exist that the callback alone does not cover, and both are
/// handled here:
///
///  * the response that *launched* the process is not replayed through
///    `onDidReceiveNotificationResponse` on Android — the plugin hands it over
///    through `getNotificationAppLaunchDetails()` instead
///    ([replayLaunchResponse]);
///  * an Android action button that shows no user interface ("Yes" and "No")
///    is delivered to a background isolate and to nothing else, so
///    [reminderBackgroundResponse] is registered as the background entry point
///    and forwards to the running app through [IsolateNameServer].
library;

// The core's models, presenters and logging are reached by their `src` path,
// exactly as the rest of lib/state does.
// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';

import '../platform/flutter_notification_tray.dart';
import '../ui/common/dialogs/snooze_picker_dialog.dart';
import 'intent_router.dart';

export '../ui/common/dialogs/snooze_picker_dialog.dart'
    show SnoozeChoice, SnoozeDelay, SnoozeUntilTime;
export 'intent_router.dart' show ReminderIntentActions, ReminderIntentReceiver;

/// The name the running app publishes its response port under.
///
/// An Android action button that shows no user interface is delivered by
/// `ActionBroadcastReceiver`, which spins up a *second* Flutter engine and
/// calls the background entry point there. That isolate has no scope, no
/// database handle and no screen; when the app is alive, the only thing worth
/// doing with the response is handing it to the isolate that has all three.
/// The name is fixed in production, and has to be: the background entry point
/// runs in a second engine with no reference to the app and can only find it by
/// a name both halves already agree on.
///
/// It is a variable, not a constant, for one reason. `IsolateNameServer` is
/// global to the *process*, and `flutter test` runs many test files in one
/// process — so two files that each boot an app fight over this single name,
/// and the loser's notification responses are delivered into the winner's
/// isolate. A test that boots an app gives itself a unique name here and
/// restores this default afterwards.
String reminderResponsePortName = defaultReminderResponsePortName;

/// The production name. Never changes; [reminderResponsePortName] is what code
/// reads.
const String defaultReminderResponsePortName =
    'org.isoron.uhabits/reminder-responses';

/// The background half of the response callback.
///
/// Registered with `plugin.initialize(onDidReceiveBackgroundNotificationResponse:
/// ...)`, which is why it is a top-level function annotated for the AOT
/// compiler: the plugin looks it up by callback handle and calls it in an
/// isolate that was created for this one message.
///
/// It forwards to the live app and does nothing else. Answering the tap here
/// would mean opening a second connection to the same database from a second
/// isolate while the first one may be holding the models in memory, and the
/// entry it wrote would be invisible to the running app until it restarted —
/// so a "Yes" tapped while the process is dead is dropped rather than written
/// twice or written behind the app's back.
@pragma('vm:entry-point')
void reminderBackgroundResponse(NotificationResponse response) {
  final SendPort? port =
      IsolateNameServer.lookupPortByName(reminderResponsePortName);
  port?.send(<String, Object?>{
    'actionId': response.actionId,
    'payload': response.payload,
  });
}

/// Receives notification responses and acts on them.
class ReminderResponseRouter {
  ReminderResponseRouter({
    required HabitList habits,
    required ReminderController controller,
    required WidgetIntentReceiver checkmarks,
    required Logging logging,
    DismissedReminderDetector? dismissals,
  })  : _habits = habits,
        _controller = controller,
        _checkmarks = checkmarks,
        _dismissals = dismissals,
        _logger = logging.getLogger(ReminderIntentReceiver.tag) {
    _receiver = ReminderIntentReceiver(
      habits: habits,
      controller: controller,
      logging: logging,
      onSnoozePressed: _onSnoozePressed,
    );
    _listenForBackgroundResponses();
  }

  final HabitList _habits;

  /// Held for the two answers the snooze picker produces; every other action
  /// reaches it through [_receiver].
  final ReminderController _controller;

  /// The port of `WidgetReceiver`, which is what upstream addresses with the
  /// "Yes" and "No" buttons. It is a second instance — the app builds one for
  /// widget deep links too — the way upstream builds a fresh `WidgetComponent`
  /// for every broadcast it receives.
  final WidgetIntentReceiver _checkmarks;

  /// The port of the delete intent. Null on a host that cannot see its own
  /// notification shade.
  final DismissedReminderDetector? _dismissals;

  final Logger _logger;

  /// The port of `ReminderReceiver`.
  late final ReminderIntentReceiver _receiver;

  ReminderIntentReceiver get receiver => _receiver;

  // -----------------------------------------------------------------------
  // The hooks a screen supplies
  // -----------------------------------------------------------------------

  /// `IntentFactory.startShowHabitActivity(context, habit)`.
  void Function(Habit habit)? _showHabit;

  /// `ListHabitsActivity.parseIntents()`'s ACTION_EDIT branch: the numeric
  /// value dialog for one habit and one day.
  void Function(Habit habit, LocalDate date)? _openValuePicker;

  /// `SnoozeDelayPickerActivity`, which `ReminderController.onSnoozePressed`
  /// starts and which answers with one of the two `onSnooze*Picked` calls.
  Future<SnoozeChoice?> Function(Habit habit)? _pickSnoozeDelay;

  bool _attached = false;

  bool get isAttached => _attached;

  /// Responses that arrived with no screen to answer them — everything a cold
  /// start delivers, since the plugin is initialised before `runApp`.
  final List<void Function()> _pending = <void Function()>[];

  /// Called by the app widget once it is mounted.
  void attach({
    required void Function(Habit habit) showHabit,
    required void Function(Habit habit, LocalDate date) openValuePicker,
    required Future<SnoozeChoice?> Function(Habit habit) pickSnoozeDelay,
  }) {
    _showHabit = showHabit;
    _openValuePicker = openValuePicker;
    _pickSnoozeDelay = pickSnoozeDelay;
    _attached = true;
    final List<void Function()> waiting = List<void Function()>.of(_pending);
    _pending.clear();
    for (final void Function() action in waiting) {
      action();
    }
  }

  /// Called when that widget goes away.
  void detach() {
    _attached = false;
    _showHabit = null;
    _openValuePicker = null;
    _pickSnoozeDelay = null;
  }

  // -----------------------------------------------------------------------
  // Delivery
  // -----------------------------------------------------------------------

  /// `onDidReceiveNotificationResponse`.
  ///
  /// Every response is acted on, with no de-duplication of any kind, because
  /// upstream has none: each interaction is its own `PendingIntent` that
  /// Android delivers exactly once and delivers every time, so two taps on
  /// the same notification start two `ShowHabitActivity`s and two "Later"
  /// taps start two `SnoozeDelayPickerActivity`s.
  ///
  /// Nor does the plugin ever deliver one response twice — the launching one
  /// included, which is the case a guard here would have been for
  /// (`audit12.launch-response-guard-swallows-the-next-tap#1`).
  /// `flutter_local_notifications` 18.0.1:
  ///
  ///  * Android — `FlutterLocalNotificationsPlugin.onAttachedToActivity`
  ///    inspects the launch intent only to honour the plugin's own cancel
  ///    flag (`processForegroundNotificationAction`) and never invokes
  ///    `didReceiveNotificationResponse`; the channel call comes from
  ///    `onNewIntent` alone, i.e. from a *later* tap.
  ///  * iOS — `userNotificationCenter:didReceiveNotificationResponse:` sets
  ///    `_launchingAppFromNotification` / `_launchNotificationResponseDict`
  ///    only in its `!_initialized` branches, the very branches in which it
  ///    did *not* invoke the channel. So
  ///    `getNotificationAppLaunchDetails()` reports a response precisely when
  ///    the callback never saw it.
  ///
  /// A guard would therefore never catch a duplicate and would only ever
  /// discard a real second tap, which is a dead button.
  void handleResponse(NotificationResponse response) {
    handle(actionId: response.actionId, payload: response.payload);
  }

  /// The same, from the two decoded fields.
  void handle({String? actionId, String? payload}) {
    final ReminderResponse? response =
        ReminderResponse.decode(actionId: actionId, payload: payload);
    if (response == null) {
      // Not a reminder this app posted — the way `ReminderReceiver` returns
      // early when the intent's data resolves to no habit.
      _logger.debug('Ignoring notification response action=$actionId');
      return;
    }
    _dispatch(response);
  }

  void _dispatch(ReminderResponse response) {
    final int habitId = response.habitId;
    switch (response.kind) {
      case ReminderResponseKind.addRepetition:
        // `PendingIntentFactory.addCheckmark(habit, timestamp)`: a broadcast to
        // WidgetReceiver, data = habit.uriString, with the checkmark day in the
        // 'timestamp' extra.
        _checkmarks.onReceive(
          Intent(
            action: WidgetActions.addRepetition,
            data: habitUri(habitId),
            extras: <String, Object?>{'timestamp': response.payload.timestamp},
          ),
        );
      case ReminderResponseKind.removeRepetition:
        _checkmarks.onReceive(
          Intent(
            action: WidgetActions.removeRepetition,
            data: habitUri(habitId),
            extras: <String, Object?>{'timestamp': response.payload.timestamp},
          ),
        );
      case ReminderResponseKind.open:
        _whenAttached(() {
          final Habit? habit = _habits.getById(habitId);
          if (habit != null) _showHabit?.call(habit);
        });
      case ReminderResponseKind.edit:
        _whenAttached(() {
          final Habit? habit = _habits.getById(habitId);
          if (habit != null) _openValuePicker?.call(habit, response.date);
        });
      case ReminderResponseKind.snooze:
        // Through the receiver, because the branch it takes — and the log line
        // it writes — is `ReminderReceiver`'s.
        _receiver.onReceive(
          Intent(
            action: ReminderIntentActions.snoozeReminder,
            data: habitUri(habitId),
          ),
        );
      case ReminderResponseKind.dismiss:
        _receiver.onReceive(
          Intent(
            action: ReminderIntentActions.dismissReminder,
            data: habitUri(habitId),
          ),
        );
    }
  }

  void _whenAttached(void Function() action) {
    if (_attached) {
      action();
      return;
    }
    _pending.add(action);
  }

  /// `ReminderController.onSnoozePressed(habit, context)`, whose Kotlin body is
  /// the intent that starts the picker activity, followed — once the user has
  /// chosen — by `onSnoozeDelayPicked` or `onSnoozeTimePicked`.
  void _onSnoozePressed(Habit habit) {
    _whenAttached(() {
      final Future<SnoozeChoice?> Function(Habit habit)? pick =
          _pickSnoozeDelay;
      if (pick == null) return;
      unawaited(_askAndSnooze(pick, habit));
    });
  }

  Future<void> _askAndSnooze(
    Future<SnoozeChoice?> Function(Habit habit) pick,
    Habit habit,
  ) async {
    final SnoozeChoice? choice = await pick(habit);
    switch (choice) {
      case SnoozeDelay(minutes: final int minutes):
        _controller.onSnoozeDelayPicked(habit, minutes);
      case SnoozeUntilTime(hour: final int hour, minute: final int minute):
        _controller.onSnoozeTimePicked(habit, hour, minute);
      case null:
        // `reminders.snooze-picker-ui#7`: backing out of the picker writes
        // nothing and leaves the notification where it is.
        break;
    }
  }

  // -----------------------------------------------------------------------
  // The two deliveries the callback does not carry
  // -----------------------------------------------------------------------

  /// The tap that started the process.
  ///
  /// `initialize`'s callback is registered too late for it: the notification
  /// was touched before this isolate existed, and the plugin keeps the
  /// response in `getNotificationAppLaunchDetails()` instead. An app that
  /// never asks silently loses every action taken while it was not running.
  Future<void> replayLaunchResponse(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    final NotificationAppLaunchDetails? details;
    try {
      details = await plugin.getNotificationAppLaunchDetails();
    } on Object catch (error) {
      _logger.debug('Could not read the launch details: $error');
      return;
    }
    if (details == null || !details.didNotificationLaunchApp) return;
    final NotificationResponse? response = details.notificationResponse;
    if (response == null) return;
    _logger.info('Launched by a notification: action=${response.actionId}');
    handle(actionId: response.actionId, payload: response.payload);
  }

  /// The two deliveries the shade never announces: a reminder the OS posted
  /// from a pre-built alarm, which upstream would have arrived as
  /// `ReminderController.onShowReminder`, and a swipe, which upstream would
  /// have arrived through the notification's delete intent. See
  /// [DismissedReminderDetector], which answers both by comparing the
  /// registry against what is actually on screen.
  Future<void> onResumed() async {
    await _dismissals?.reconcile();
  }

  ReceivePort? _backgroundResponses;

  void _listenForBackgroundResponses() {
    final ReceivePort port = ReceivePort();
    _backgroundResponses = port;
    // A previous mapping would keep the background isolate talking to a scope
    // that has been closed — which is what a hot restart, and a test that
    // opens a second scope, both produce.
    IsolateNameServer.removePortNameMapping(reminderResponsePortName);
    IsolateNameServer.registerPortWithName(port.sendPort, reminderResponsePortName);
    port.listen((Object? message) {
      if (message is! Map) return;
      handle(
        actionId: message['actionId'] as String?,
        payload: message['payload'] as String?,
      );
    });
  }

  /// Releases the port. Called from `AppScope.close`.
  void dispose() {
    detach();
    _pending.clear();
    final ReceivePort? port = _backgroundResponses;
    if (port != null &&
        IsolateNameServer.lookupPortByName(reminderResponsePortName) ==
            port.sendPort) {
      // Only ours: a scope closed after a newer one registered must not take
      // the live mapping down with it.
      IsolateNameServer.removePortNameMapping(reminderResponsePortName);
    }
    port?.close();
    _backgroundResponses = null;
  }
}
