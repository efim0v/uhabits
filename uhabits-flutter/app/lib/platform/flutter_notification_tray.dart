// The core's platform seams live under `src`, exactly as
// lib/state/app_scope.dart reaches them; the barrel only re-exports the models,
// database, time and drawing layers.
// ignore_for_file: implementation_imports

/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/notifications/AndroidNotificationTray.kt
/// plus the pieces of `PendingIntentFactory` / `ReminderReceiver` that decide
/// what each notification action carries.
///
/// The split is the same one the core already draws: [NotificationTray] decides
/// *whether* a reminder is shown and under which id, and everything here is the
/// other half — the content, the channel, the action buttons, and the calls
/// into the platform.
///
/// Three seams keep this file testable and keep the plugin out of widget tests:
///
///  * [NotificationSpec] is a plain description of one notification, with no
///    plugin type in it;
///  * [ReminderNotificationBuilder] turns a habit into a [NotificationSpec] and
///    is pure Dart;
///  * [NotificationPresenter] is the one-method-per-platform-call interface
///    that [FlutterNotificationTray] talks to. [LocalNotificationsPresenter] is
///    the real implementation over `flutter_local_notifications`; tests use a
///    fake.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';
import 'package:uhabits_core/uhabits_core.dart' show Habit, LocalDate;

import '../l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Strings
// ---------------------------------------------------------------------------

/// The six strings a reminder notification needs.
///
/// `AndroidNotificationTray` reads them from the application `Context`, which
/// has no Flutter counterpart outside the widget tree: notifications are posted
/// from a background alarm, where there is no `BuildContext`. The integrator
/// resolves them once — `NotificationStrings.from(await L10n.delegate.load(locale))`
/// — and hands them over.
class NotificationStrings {
  const NotificationStrings({
    required this.yes,
    required this.no,
    required this.enter,
    required this.snooze,
    required this.defaultReminderQuestion,
    required this.channelName,
  });

  /// `R.string.yes`, the label of the "check" action.
  final String yes;

  /// `R.string.no`.
  final String no;

  /// `R.string.enter`, the single action of a numerical habit.
  final String enter;

  /// `R.string.snooze`, whose English value is "Later".
  final String snooze;

  /// `R.string.default_reminder_question`, used when the habit has no question.
  final String defaultReminderQuestion;

  /// `R.string.reminder`, the user-visible name of the "REMINDERS" channel.
  final String channelName;

  factory NotificationStrings.from(L10n l10n) => NotificationStrings(
        yes: l10n.yes,
        no: l10n.no,
        enter: l10n.enter,
        snooze: l10n.snooze,
        defaultReminderQuestion: l10n.defaultReminderQuestion,
        channelName: l10n.reminder,
      );
}

// ---------------------------------------------------------------------------
// Actions and payloads
// ---------------------------------------------------------------------------

/// The intent actions of `ReminderReceiver` and `WidgetReceiver`, reused as the
/// action ids of the notification buttons (`intents.actions-and-extras#1` to
/// `#9`). Keeping the exact strings means a notification posted by the Android
/// build and one posted here are answered by the same identifiers.
class ReminderActions {
  ReminderActions._();

  /// `ReminderReceiver.ACTION_SHOW_REMINDER`.
  static const String showReminder = 'org.isoron.uhabits.ACTION_SHOW_REMINDER';

  /// `ReminderReceiver.ACTION_DISMISS_REMINDER`.
  static const String dismissReminder =
      'org.isoron.uhabits.ACTION_DISMISS_REMINDER';

  /// `ReminderReceiver.ACTION_SNOOZE_REMINDER`.
  static const String snoozeReminder =
      'org.isoron.uhabits.ACTION_SNOOZE_REMINDER';

  /// `WidgetReceiver.ACTION_ADD_REPETITION`, the "Yes" button.
  static const String addRepetition = 'org.isoron.uhabits.ACTION_ADD_REPETITION';

  /// `WidgetReceiver.ACTION_REMOVE_REPETITION`, the "No" button.
  static const String removeRepetition =
      'org.isoron.uhabits.ACTION_REMOVE_REPETITION';

  /// `ListHabitsActivity.ACTION_EDIT`, the "Enter" button of a numerical habit.
  static const String edit = 'org.isoron.uhabits.ACTION_EDIT';
}

/// The drawable each reminder button is built with — the first argument of
/// `NotificationCompat.Action`, which has no icon-less constructor
/// (`audit8.reminder-notification-action-buttons-are-built#1`).
///
/// Android draws these wherever action icons still render — Wear OS (which the
/// `WearableExtender` in `buildNotification()` exists to serve), Android Auto,
/// and Android 6 and below — so the buttons are identifiable as icons and not
/// only as words. Like the small icon, the plugin resolves them by *name* out
/// of `android/app/src/main/res/drawable`, so each name here has to be a file
/// there.
class ReminderActionIcons {
  ReminderActionIcons._();

  /// `R.drawable.ic_action_check` — "Yes" (`notifications.actions#2`) and
  /// "Enter" (`notifications.actions#1`).
  static const String check = 'ic_action_check';

  /// `R.drawable.ic_action_cancel` — "No" (`notifications.actions#2`).
  static const String cancel = 'ic_action_cancel';

  /// `R.drawable.ic_action_snooze` — "Later" (`notifications.actions#3`).
  static const String snooze = 'ic_action_snooze';
}

/// The `UNNotificationCategory` identifiers. iOS needs the action buttons
/// declared once, at initialisation, grouped into categories; a notification
/// then names the category it belongs to. Android has no such indirection, so
/// the identifiers only ever reach the Darwin side.
class ReminderCategories {
  ReminderCategories._();

  /// The two-button category: "Yes" / "No" (plus "Later").
  static const String yesNo = 'REMINDERS_YES_NO';

  /// The one-button category: "Enter" (plus "Later").
  static const String numerical = 'REMINDERS_NUMERICAL';
}

/// What an Android reminder intent carries, squeezed into the single string
/// `flutter_local_notifications` gives back with a tapped action.
///
/// `intents.actions-and-extras#10`: the habit is identified by the data URI
/// `content://org.isoron.uhabits/habit/<id>`. `#11`: the show-reminder intent
/// adds the long extras `timestamp` (the local-midnight checkmark day computed
/// by `ReminderScheduler`) and `reminderTime` (the alarm instant). Both extras
/// become query parameters here, so the whole payload is still one URI.
class ReminderPayload {
  const ReminderPayload({
    required this.habitId,
    required this.timestamp,
    required this.reminderTime,
  });

  final int habitId;

  /// `LocalDate.unixTime` of the day a checkmark would be written to.
  final int timestamp;

  /// The UTC instant the alarm was set for.
  final int reminderTime;

  /// The day the notification targets — what `NotificationTray` gates on.
  LocalDate get date => LocalDate.fromUnixTime(timestamp);

  String encode() => 'content://org.isoron.uhabits/habit/$habitId'
      '?timestamp=$timestamp&reminderTime=$reminderTime';

  /// Returns null for anything this app did not write, the way
  /// `ReminderReceiver` returns early when `intent.data` is null or resolves to
  /// no habit.
  static ReminderPayload? decode(String? raw) {
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.pathSegments.isEmpty) return null;
    final habitId = int.tryParse(uri.pathSegments.last);
    if (habitId == null) return null;
    final timestamp = int.tryParse(uri.queryParameters['timestamp'] ?? '');
    final reminderTime =
        int.tryParse(uri.queryParameters['reminderTime'] ?? '');
    if (timestamp == null || reminderTime == null) return null;
    return ReminderPayload(
      habitId: habitId,
      timestamp: timestamp,
      reminderTime: reminderTime,
    );
  }
}

/// What the user did to a reminder notification.
enum ReminderResponseKind {
  /// The notification body was tapped. `notifications.content#5`: Android opens
  /// `ShowHabitActivity` with `ListHabitsActivity` beneath it on the back
  /// stack.
  open,

  /// "Yes" — `WidgetBehavior.onAddRepetition`.
  addRepetition,

  /// "No" — `WidgetBehavior.onRemoveRepetition`.
  removeRepetition,

  /// "Enter" — opens the numeric value dialog for that habit and day.
  edit,

  /// "Later" — `ReminderController.onSnoozePressed`.
  snooze,

  /// The notification was swiped away — `ReminderController.onDismiss`.
  dismiss,
}

/// One decoded tap, ready to be handed to `ReminderController` or
/// `WidgetBehavior`.
///
/// This is the seam the app wires: the tray never runs a command itself, the
/// same way `ReminderReceiver` and `WidgetReceiver` only translate an intent
/// into a controller call.
class ReminderResponse {
  const ReminderResponse({
    required this.kind,
    required this.payload,
  });

  final ReminderResponseKind kind;

  final ReminderPayload payload;

  int get habitId => payload.habitId;

  LocalDate get date => payload.date;

  int get reminderTime => payload.reminderTime;

  /// Maps `(actionId, payload)` back onto an action.
  ///
  /// A null [actionId] is a tap on the notification itself, which is Android's
  /// content intent.
  static ReminderResponse? decode({String? actionId, String? payload}) {
    final decoded = ReminderPayload.decode(payload);
    if (decoded == null) return null;
    final kind = switch (actionId) {
      null => ReminderResponseKind.open,
      ReminderActions.addRepetition => ReminderResponseKind.addRepetition,
      ReminderActions.removeRepetition => ReminderResponseKind.removeRepetition,
      ReminderActions.edit => ReminderResponseKind.edit,
      ReminderActions.snoozeReminder => ReminderResponseKind.snooze,
      ReminderActions.dismissReminder => ReminderResponseKind.dismiss,
      _ => null,
    };
    if (kind == null) return null;
    return ReminderResponse(kind: kind, payload: decoded);
  }
}

// ---------------------------------------------------------------------------
// The plugin-free description of a notification
// ---------------------------------------------------------------------------

/// One action button: `NotificationCompat.Action(icon, title, pendingIntent)`,
/// with the pending intent replaced by the [id] the plugin hands back.
class ReminderNotificationAction {
  const ReminderNotificationAction(this.id, this.title, {required this.icon});

  /// One of [ReminderActions].
  final String id;

  final String title;

  /// One of [ReminderActionIcons]: the drawable resource name Android draws
  /// the button with (`audit8.reminder-notification-action-buttons-are-built#1`).
  /// iOS has no per-action icon, so this reaches the Android side only.
  final String icon;

  @override
  bool operator ==(Object other) =>
      other is ReminderNotificationAction &&
      other.id == id &&
      other.title == title &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(id, title, icon);

  @override
  String toString() => 'ReminderNotificationAction($id, $title, $icon)';
}

/// The set of buttons one kind of habit shows, as iOS wants them at
/// initialisation time.
class ReminderNotificationCategory {
  const ReminderNotificationCategory(this.identifier, this.actions);

  final String identifier;

  final List<ReminderNotificationAction> actions;
}

/// Everything `AndroidNotificationTray.buildNotification` decides, with no
/// plugin type in sight so that it can be asserted in a widget test.
class NotificationSpec {
  const NotificationSpec({
    required this.id,
    required this.channelId,
    required this.channelName,
    required this.categoryId,
    required this.title,
    required this.body,
    required this.whenMillis,
    required this.ongoing,
    required this.playSound,
    required this.actions,
    required this.payload,
    this.showWhen = true,
    this.groupKey,
    this.color,
  });

  /// `NotificationTray.getNotificationId(habit)`.
  final int id;

  /// Always [NotificationTray.remindersChannelId].
  final String channelId;

  final String channelName;

  /// The iOS category, one of [ReminderCategories].
  final String categoryId;

  /// `notifications.content#3`: `habit.name`, verbatim.
  final String title;

  /// `notifications.content#4`: `habit.question`, or the default question when
  /// the habit's question is blank.
  final String body;

  /// `notifications.content#7`: `setWhen(reminderTime)` — the reminder instant,
  /// not the moment the notification was posted.
  final int whenMillis;

  /// `notifications.content#7`: `setShowWhen(true)`.
  final bool showWhen;

  /// `notifications.content#8`: `setOngoing(preferences.shouldMakeNotificationsSticky())`.
  final bool ongoing;

  /// `notifications.content#9`: the builder starts from `setSound(null)` and
  /// only applies the ringtone when `disableSound` is false.
  final bool playSound;

  final List<ReminderNotificationAction> actions;

  /// [ReminderPayload.encode].
  final String payload;

  /// `notifications.content#11`: reminders carry no group or summary.
  final String? groupKey;

  /// `notifications.content#10`: the habit's colour is NOT applied.
  final int? color;

  NotificationSpec copyWith({bool? playSound}) => NotificationSpec(
        id: id,
        channelId: channelId,
        channelName: channelName,
        categoryId: categoryId,
        title: title,
        body: body,
        whenMillis: whenMillis,
        ongoing: ongoing,
        playSound: playSound ?? this.playSound,
        actions: actions,
        payload: payload,
        showWhen: showWhen,
        groupKey: groupKey,
        color: color,
      );

  @override
  String toString() => 'NotificationSpec(id=$id, title=$title, body=$body, '
      'when=$whenMillis, ongoing=$ongoing, playSound=$playSound, '
      'actions=$actions)';
}

// ---------------------------------------------------------------------------
// Building a notification from a habit
// ---------------------------------------------------------------------------

/// Port of `NotificationTray.getNotificationId`, which is private in the core.
///
/// `notifications.id-and-registry#1`: `(habit.id % Int.MAX_VALUE).toInt()`, or 0
/// when the id is null. Kotlin's `%` on a `Long` is a truncated remainder, so a
/// negative id yields a negative notification id; [int.remainder] reproduces
/// that where Dart's `%` would not.
///
/// The scheduler needs this too — the alarm it sets IS the notification, so it
/// must be filed under the id the core will later cancel.
int reminderNotificationId(Habit habit) {
  final id = habit.id;
  if (id == null) return 0;
  return id.remainder(2147483647);
}

/// Port of `AndroidNotificationTray.buildNotification`.
class ReminderNotificationBuilder {
  ReminderNotificationBuilder({
    required Preferences preferences,
    required NotificationStrings strings,
    bool snoozeActionEnabled = true,
  })  : _preferences = preferences,
        _strings = strings,
        _snoozeActionEnabled = snoozeActionEnabled;

  final Preferences _preferences;

  final NotificationStrings _strings;

  /// `reminders.snooze-android12-gate#1` hides the "Later" action on Android
  /// 12+, because a broadcast receiver may no longer trampoline into the snooze
  /// picker activity. Nothing here trampolines — the action is answered in Dart
  /// — so the gate does not apply and the button is shown everywhere. Set this
  /// to false to reproduce the Android 12+ behaviour exactly.
  final bool _snoozeActionEnabled;

  NotificationStrings get strings => _strings;

  NotificationSpec build(
    Habit habit,
    int notificationId,
    LocalDate date,
    int reminderTime, {
    bool disableSound = false,
  }) {
    // notifications.content#4: the question, unless it is blank.
    final body = habit.question.trim().isEmpty
        ? _strings.defaultReminderQuestion
        : habit.question;
    return NotificationSpec(
      id: notificationId,
      // notifications.content#1 / notifications.channel#1.
      channelId: NotificationTray.remindersChannelId,
      channelName: _strings.channelName,
      categoryId: habit.isNumerical
          ? ReminderCategories.numerical
          : ReminderCategories.yesNo,
      title: habit.name,
      body: body,
      whenMillis: reminderTime,
      showWhen: true,
      ongoing: _preferences.shouldMakeNotificationsSticky(),
      playSound: !disableSound,
      actions: _actionsFor(habit.isNumerical),
      payload: ReminderPayload(
        habitId: habit.id ?? 0,
        timestamp: date.unixTime,
        reminderTime: reminderTime,
      ).encode(),
      // notifications.content#11 and #10: no group, no colour.
      groupKey: null,
      color: null,
    );
  }

  List<ReminderNotificationAction> _actionsFor(bool isNumerical) {
    final actions = <ReminderNotificationAction>[
      // notifications.actions#1: a numerical habit gets exactly one action,
      // carrying the same check icon "Yes" does.
      if (isNumerical)
        ReminderNotificationAction(
          ReminderActions.edit,
          _strings.enter,
          icon: ReminderActionIcons.check,
        )
      else ...[
        // notifications.actions#2: "Yes" then "No", in that order, with a
        // check and a cross.
        ReminderNotificationAction(
          ReminderActions.addRepetition,
          _strings.yes,
          icon: ReminderActionIcons.check,
        ),
        ReminderNotificationAction(
          ReminderActions.removeRepetition,
          _strings.no,
          icon: ReminderActionIcons.cancel,
        ),
      ],
    ];
    // notifications.actions#3: "Later" is appended after the others, with the
    // clock.
    if (_snoozeActionEnabled) {
      actions.add(
        ReminderNotificationAction(
          ReminderActions.snoozeReminder,
          _strings.snooze,
          icon: ReminderActionIcons.snooze,
        ),
      );
    }
    return List<ReminderNotificationAction>.unmodifiable(actions);
  }

  /// The `UNNotificationCategory` list iOS needs at initialisation, built from
  /// the same action lists a notification will name. Declaring them anywhere
  /// else is how the two drift apart.
  List<ReminderNotificationCategory> categories() => [
        ReminderNotificationCategory(
          ReminderCategories.yesNo,
          _actionsFor(false),
        ),
        ReminderNotificationCategory(
          ReminderCategories.numerical,
          _actionsFor(true),
        ),
      ];
}

// ---------------------------------------------------------------------------
// The platform seam
// ---------------------------------------------------------------------------

/// The two calls `AndroidNotificationTray` makes into
/// `NotificationManagerCompat`.
///
/// A plugin cannot run in a widget test, so this is where the port stops and
/// the fake takes over.
abstract interface class NotificationPresenter {
  /// `NotificationManagerCompat.notify(spec.id, notification)`.
  Future<void> show(NotificationSpec spec);

  /// `NotificationManagerCompat.cancel(id)`.
  Future<void> cancel(int id);
}

/// Port of `AndroidNotificationTray`, the `NotificationTray.SystemTray` half of
/// the reminder pipeline.
class FlutterNotificationTray implements SystemTray {
  FlutterNotificationTray({
    required NotificationPresenter presenter,
    required ReminderNotificationBuilder builder,
    Logging? logging,
    ReminderSchedulerApi? scheduler,
  })  : _presenter = presenter,
        _builder = builder,
        _scheduler = scheduler,
        _logger = (logging ?? StandardLogging()).getLogger(_loggerName);

  static const String _loggerName = 'AndroidNotificationTray';

  final NotificationPresenter _presenter;

  final ReminderNotificationBuilder _builder;

  /// The alarm half of the pipeline, or null where there is none — a widget
  /// test that only inspects what is posted, for instance.
  ///
  /// `AndroidNotificationTray` has no such collaborator and needs none: on
  /// Android the alarm and the notification are separate objects, so cancelling
  /// one leaves the other armed. Here they are the same object under the same
  /// id, which is what [removeNotification] has to make up for.
  final ReminderSchedulerApi? _scheduler;

  final Logger _logger;

  /// Port of `private var active = HashSet<Int>()`
  /// (`notifications.id-and-registry#6`). It is the tray's own bookkeeping —
  /// the core keeps a separate registry keyed by habit.
  ///
  /// The habit is kept beside the id, which the `HashSet<Int>` upstream does
  /// not need: Android answers a dismissal with an intent that names the
  /// habit, and this plugin answers it with nothing at all, so the id that
  /// vanished from the shade has to be translatable back into the habit
  /// [ReminderController.onDismiss] wants. See [DismissedReminderDetector].
  final Map<int, Habit> _active = <int, Habit>{};

  /// Every platform call, in order.
  ///
  /// `NotificationManagerCompat` is synchronous on Android; the plugin is not,
  /// and [SystemTray] returns void, so the calls are chained instead of
  /// awaited. Chaining preserves the one property the Android code relies on:
  /// a `cancel` issued after a `show` reaches the platform after it.
  Future<void> _pending = Future<void>.value();

  Set<int> get activeNotificationIds => Set<int>.unmodifiable(_active.keys);

  /// The notifications this tray believes are on screen, by notification id.
  Map<int, Habit> get activeReminders => Map<int, Habit>.unmodifiable(_active);

  /// Drops one entry from the registry without touching the platform.
  ///
  /// The one caller is [DismissedReminderDetector]: a notification the user
  /// swiped away is already gone from the shade, so cancelling it would be a
  /// no-op, but the bookkeeping still has to let go of it before
  /// `ReminderController.onDismiss` decides whether to put it back.
  void forgetNotification(int notificationId) {
    _active.remove(notificationId);
  }

  /// Awaits every platform call issued so far. For tests and for shutdown.
  Future<void> settle() => _pending;

  void _enqueue(Future<void> Function() operation) {
    _pending = _pending.then((_) => operation()).catchError((Object error) {
      _logger.error('Notification operation failed: $error');
    });
  }

  @override
  void log(String msg) => _logger.debug(msg);

  /// `NotificationManagerCompat.cancel(id)` — and then the alarm that call
  /// also took down.
  ///
  /// `audit3.recording-a-non-completing-entry-silently#1`: upstream, entering a
  /// value cancels the notification currently in the shade and nothing else.
  /// The `AlarmManager` alarm `IntentScheduler` filed is untouched, so an entry
  /// that does not *complete* the habit — "No" on a yes/no habit, a value below
  /// an AT_LEAST target, any value at all on an AT_MOST habit — still gets its
  /// reminder later that day, because gate 1 lets it through at fire time.
  ///
  /// This port has no fire-time hook, so the alarm is the finished notification
  /// filed under this very id (see `FlutterAlarmScheduler`): the cancel below
  /// is also what disarms it, and without the re-arm the day's reminder would
  /// be silently destroyed by any entry at all. `scheduleAll` puts it back —
  /// and puts it back on the *next* day the gates allow, so a completing entry
  /// still ends the day's reminder. Which of the two happened is decided in
  /// `FlutterAlarmScheduler._advanceToReminderDay`, the one place that can read
  /// the habit; all this tray is handed is an id.
  ///
  /// Order matters twice over, which is why the re-arm sits inside the queued
  /// operation rather than beside it:
  ///
  ///  * the platform has to see the cancel *before* the alarm that replaces it,
  ///    or the fresh alarm is the one that disappears;
  ///  * `ReminderController.onSnoozeDelayPicked` snoozes first and cancels
  ///    second, on purpose. `scheduleAll` re-reads the snooze from
  ///    `WidgetPreferences`, so the alarm that comes back is the snoozed one.
  @override
  void removeNotification(int notificationId) {
    _enqueue(() async {
      await _presenter.cancel(notificationId);
      _active.remove(notificationId);
      _scheduler?.scheduleAll();
    });
  }

  @override
  void showNotification(
    Habit habit,
    int notificationId,
    LocalDate date,
    int reminderTime,
  ) {
    _enqueue(() async {
      final spec = _builder.build(habit, notificationId, date, reminderTime);
      try {
        await _presenter.show(spec);
      } on Exception catch (_) {
        // notifications.sound#8: some Xiaomi phones throw when a custom
        // notification sound is used. Rebuild without sound and post again —
        // a second failure is not caught upstream either.
        _logger.info('Failed to show notification. Retrying without sound.');
        await _presenter.show(spec.copyWith(playSound: false));
      }
      _active[notificationId] = habit;
    });
  }
}

// ---------------------------------------------------------------------------
// The delete intent, which this plugin does not have
// ---------------------------------------------------------------------------

/// What the platform still has in its shade.
///
/// Upstream every reminder carries `setDeleteIntent(pendingIntents
/// .dismissNotification(habit))`, so a swipe is *delivered*:
/// `ReminderReceiver` gets ACTION_DISMISS_REMINDER and calls
/// `ReminderController.onDismiss`. `flutter_local_notifications` 18.0.1 has no
/// delete intent and no notification-dismissed callback of any kind — there is
/// no `setDeleteIntent` anywhere in its Android source — so the port cannot be
/// told. What it can do is *ask*, which is what this seam is: the plugin does
/// expose the set of notifications that are still posted.
abstract interface class ActiveNotificationQuery {
  /// The ids the platform still shows, or null when this host cannot say.
  ///
  /// Null rather than an empty set matters: "nothing is posted" and "I cannot
  /// see what is posted" must not look alike, or every reminder would be
  /// treated as swiped away. Only Android reports ids at all.
  Future<Set<int>?> activeNotificationIds();
}

/// Port of the delete intent's effect: `ReminderController.onDismiss(habit)`
/// for every reminder that has left the shade.
///
/// It runs when the app comes back to the foreground, because that is the
/// first moment after a swipe at which Dart is running again. Upstream the
/// call is immediate; here it is late, and the difference is visible for
/// sticky notifications on Android 14+ — the reminder reappears when the user
/// next opens the app rather than the instant they dismiss it. Both of the
/// consequences the ledger names are nevertheless repaired: the sticky
/// reminder comes back (`notifications.sticky-and-dismiss#5`), and the core
/// tray's `active` registry stops claiming a notification that is no longer on
/// screen (`#6`).
class DismissedReminderDetector {
  DismissedReminderDetector({
    required FlutterNotificationTray tray,
    required ActiveNotificationQuery platform,
    required void Function(Habit habit) onDismiss,
    Logging? logging,
  })  : _tray = tray,
        _platform = platform,
        _onDismiss = onDismiss,
        _logger = (logging ?? StandardLogging()).getLogger('ReminderReceiver');

  final FlutterNotificationTray _tray;

  final ActiveNotificationQuery _platform;

  /// `ReminderController.onDismiss`.
  final void Function(Habit habit) _onDismiss;

  final Logger _logger;

  Future<void> reconcile() async {
    // Everything already queued has to reach the platform first, or a
    // notification posted a moment ago would be read back as missing.
    await _tray.settle();
    final Map<int, Habit> believed = _tray.activeReminders;
    if (believed.isEmpty) return;
    final Set<int>? live;
    try {
      live = await _platform.activeNotificationIds();
    } on Object catch (error) {
      _logger.debug('Could not read the active notifications: $error');
      return;
    }
    if (live == null) return;
    for (final MapEntry<int, Habit> entry in believed.entries) {
      if (live.contains(entry.key)) continue;
      // The registry lets go first: onDismiss either re-posts the
      // notification, which files it again, or cancels it, which is a no-op
      // on a notification the user has already removed.
      _tray.forgetNotification(entry.key);
      _logger.debug('onDismiss habit=${entry.value.id}');
      _onDismiss(entry.value);
    }
  }
}

// ---------------------------------------------------------------------------
// The real implementation
// ---------------------------------------------------------------------------

/// [NotificationPresenter] over `flutter_local_notifications`.
///
/// Never exercised by a widget test — the plugin's method channel has no
/// implementation there. Everything worth asserting was pushed up into
/// [ReminderNotificationBuilder] and [FlutterNotificationTray].
class LocalNotificationsPresenter
    implements NotificationPresenter, ActiveNotificationQuery {
  LocalNotificationsPresenter({
    required this.plugin,
    required ReminderNotificationBuilder builder,
  })  : _builder = builder;

  final FlutterLocalNotificationsPlugin plugin;

  final ReminderNotificationBuilder _builder;

  /// `notifications.content#2`: `setSmallIcon(R.drawable.ic_notification)`.
  ///
  /// The plugin takes the drawable by *name* — it resolves
  /// `@drawable/<androidSmallIcon>` out of the app's own resources — so the
  /// file has to exist under `android/app/src/main/res/drawable`. It is the
  /// same white-on-transparent vector the Android build ships; a missing one
  /// is not a compile error, it is a reminder that never appears.
  static const String androidSmallIcon = 'ic_notification';

  /// Initialises the plugin, declares the iOS categories and creates the
  /// Android channel.
  ///
  /// `notifications.content#2`: the small icon is the drawable `ic_notification`
  /// — the integrator has to place it under `android/app/src/main/res`.
  /// `notifications.channel#1`: the channel is "REMINDERS", named after
  /// `R.string.reminder`, at default importance. Android recreates it before
  /// every post (`notifications.channel#2`); once is enough, since creating a
  /// channel that exists is a no-op and the name is the only thing that could
  /// change.
  static Future<LocalNotificationsPresenter> initialize({
    required ReminderNotificationBuilder builder,
    FlutterLocalNotificationsPlugin? plugin,
    DidReceiveNotificationResponseCallback? onResponse,
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse,
  }) async {
    final resolved = plugin ?? FlutterLocalNotificationsPlugin();
    final presenter =
        LocalNotificationsPresenter(plugin: resolved, builder: builder);
    await resolved.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings(androidSmallIcon),
        iOS: DarwinInitializationSettings(
          // The permission prompt is raised from the habit list, the way
          // `ListHabitsActivity.onResume` asks for POST_NOTIFICATIONS only when
          // there is at least one habit with a reminder
          // (`reminders.app-start-and-permission#6`).
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: presenter._darwinCategories(),
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: presenter._darwinCategories(),
        ),
      ),
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );
    await resolved
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            NotificationTray.remindersChannelId,
            builder.strings.channelName,
            importance: Importance.defaultImportance,
          ),
        );
    return presenter;
  }

  /// `ListHabitsActivity`'s POST_NOTIFICATIONS flow, and its iOS counterpart.
  Future<bool> requestPermission() async {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final darwin = plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (darwin != null) {
      return await darwin.requestPermissions(alert: true, sound: true, badge: true) ??
          false;
    }
    return false;
  }

  List<DarwinNotificationCategory> _darwinCategories() => [
        for (final category in _builder.categories())
          DarwinNotificationCategory(
            category.identifier,
            actions: [
              for (final action in category.actions)
                DarwinNotificationAction.plain(
                  action.id,
                  action.title,
                  options: _optionsFor(action),
                ),
            ],
            options: const {
              DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
            },
          ),
      ];

  /// Mirrors the Android split: "Yes" and "No" are broadcasts that write an
  /// entry without any UI, so their iOS counterparts stay background actions;
  /// "Enter" opens the numeric value dialog and "Later" the snooze picker, so
  /// both bring the app forward.
  ///
  /// A background action only reaches Dart through
  /// `onDidReceiveBackgroundNotificationResponse`, which the app must register
  /// with a top-level `@pragma('vm:entry-point')` function.
  static Set<DarwinNotificationActionOption> _optionsFor(
    ReminderNotificationAction action,
  ) =>
      action.id == ReminderActions.edit ||
              action.id == ReminderActions.snoozeReminder
          ? const {DarwinNotificationActionOption.foreground}
          : const <DarwinNotificationActionOption>{};

  /// Translates a [NotificationSpec] into the plugin's per-platform details.
  NotificationDetails detailsFor(NotificationSpec spec) => NotificationDetails(
        android: AndroidNotificationDetails(
          spec.channelId,
          spec.channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          // `buildNotification()` never calls `setAutoCancel(...)`, so the
          // reminder is posted without FLAG_AUTO_CANCEL: tapping the body opens
          // the habit and the reminder stays in the shade until the entry is
          // recorded, until it is swiped away, or until it is snoozed. The
          // plugin defaults this to true, which would defeat `ongoing` with a
          // single tap and leave the core tray's `active` map out of step.
          autoCancel: false,
          when: spec.whenMillis,
          showWhen: spec.showWhen,
          ongoing: spec.ongoing,
          playSound: spec.playSound,
          groupKey: spec.groupKey,
          actions: [
            for (final action in spec.actions)
              AndroidNotificationAction(
                action.id,
                action.title,
                // `Action(R.drawable.…, title, pendingIntent)`: upstream has no
                // icon-less button, and the plugin resolves the drawable by
                // name out of the app's own resources
                // (`audit8.reminder-notification-action-buttons-are-built#1`).
                icon: DrawableResourceAndroidBitmap(action.icon),
                // "Yes" and "No" write an entry without opening the app, the
                // way the Android broadcast actions do; "Enter" and "Later"
                // both need UI.
                showsUserInterface: action.id == ReminderActions.edit ||
                    action.id == ReminderActions.snoozeReminder,
                cancelNotification: false,
              ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: spec.categoryId,
          presentSound: spec.playSound,
        ),
        macOS: DarwinNotificationDetails(
          categoryIdentifier: spec.categoryId,
          presentSound: spec.playSound,
        ),
      );

  @override
  Future<void> show(NotificationSpec spec) => plugin.show(
        spec.id,
        spec.title,
        spec.body,
        detailsFor(spec),
        payload: spec.payload,
      );

  @override
  Future<void> cancel(int id) => plugin.cancel(id);

  /// `NotificationManagerCompat.getActiveNotifications()`.
  ///
  /// Only Android fills the id in — on Darwin `ActiveNotification.id` is null,
  /// because the notifications it lists were not necessarily posted by this
  /// plugin — so every other host answers "I cannot say" rather than "nothing
  /// is posted". See [ActiveNotificationQuery].
  @override
  Future<Set<int>?> activeNotificationIds() async {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return null;
    final active = await android.getActiveNotifications();
    return <int>{
      for (final notification in active)
        if (notification.id != null) notification.id!,
    };
  }
}

// ---------------------------------------------------------------------------
// The system's own notification-channel screen
// ---------------------------------------------------------------------------

/// Port of the `reminderCustomize` click handler in `SettingsFragment`:
///
/// ```kotlin
/// AndroidNotificationTray.createAndroidNotificationChannel(context)
/// val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
///     .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
///     .putExtra(Settings.EXTRA_CHANNEL_ID, NotificationTray.REMINDERS_CHANNEL_ID)
/// startActivity(intent)
/// ```
///
/// The order is the whole point (`notifications.channel#3`): the settings
/// screen the intent opens shows *one* channel, and a channel Android has
/// never been told about does not exist, so creating it first is what stops
/// the user landing on an empty page.
///
/// Notification channels are an Android concept; [openReminderChannelSettings]
/// answers false everywhere else, which is the `ActivityNotFoundException`
/// branch of `startActivitySafely`.
abstract interface class NotificationChannelSettings {
  Future<bool> openReminderChannelSettings();
}

/// The half of the flow that talks to `flutter_local_notifications`:
/// `NotificationManager.createNotificationChannel(...)`.
///
/// Split out from [PlatformNotificationChannelSettings] so the *order* of the
/// two calls can be observed without a plugin.
abstract interface class NotificationChannelCreator {
  /// `AndroidNotificationTray.createAndroidNotificationChannel(context)`.
  Future<void> createReminderChannel();
}

/// [NotificationChannelCreator] over `flutter_local_notifications`.
class LocalNotificationsChannelCreator implements NotificationChannelCreator {
  const LocalNotificationsChannelCreator({
    required this.plugin,
    required this.channelName,
  });

  final FlutterLocalNotificationsPlugin plugin;

  /// `R.string.reminder`, the user-visible channel name
  /// (`notifications.channel#1`).
  final String channelName;

  @override
  Future<void> createReminderChannel() async {
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            NotificationTray.remindersChannelId,
            channelName,
            importance: Importance.defaultImportance,
          ),
        );
  }
}

/// [NotificationChannelSettings] over a method channel handled by
/// `MainActivity`.
///
/// `Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS` is not exposed by any
/// package this app depends on, and `EXTRA_APP_PACKAGE` has to be the running
/// package, which only the Android side knows — so the Dart side sends the
/// channel id and the activity supplies its own package name.
class PlatformNotificationChannelSettings
    implements NotificationChannelSettings {
  const PlatformNotificationChannelSettings({
    required this.creator,
    this.channel = const MethodChannel(methodChannelName),
  });

  final NotificationChannelCreator creator;

  final MethodChannel channel;

  /// Must match the constant in
  /// `android/app/src/main/kotlin/org/isoron/uhabits/MainActivity.kt`.
  static const String methodChannelName = 'org.isoron.uhabits/notifications';

  /// The method `MainActivity` answers.
  static const String openChannelSettingsMethod = 'openChannelSettings';

  /// The argument key carrying `Settings.EXTRA_CHANNEL_ID`.
  static const String channelIdArgument = 'channelId';

  @override
  Future<bool> openReminderChannelSettings() async {
    // The channel first, always: the screen the intent opens is a view onto
    // one channel and cannot render a channel that does not exist yet.
    await creator.createReminderChannel();
    try {
      final opened = await channel.invokeMethod<bool>(
        openChannelSettingsMethod,
        <String, Object?>{
          channelIdArgument: NotificationTray.remindersChannelId,
        },
      );
      return opened ?? false;
    } on MissingPluginException {
      // No Android side to answer — iOS, macOS, a test host.
      return false;
    } on PlatformException {
      // `startActivitySafely`: nothing could handle the intent.
      return false;
    }
  }
}
