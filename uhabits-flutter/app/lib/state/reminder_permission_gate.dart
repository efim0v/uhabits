/// Port of the POST_NOTIFICATIONS half of `ListHabitsActivity.onResume`.
///
/// ```kotlin
/// if (appComponent.reminderScheduler.hasHabitsWithReminders()) {
///     if (SDK_INT < Build.VERSION_CODES.TIRAMISU) {
///         appComponent.reminderScheduler.scheduleAll()
///     } else if (checkSelfPermission(POST_NOTIFICATIONS) == PERMISSION_GRANTED) {
///         appComponent.reminderScheduler.scheduleAll()
///     } else if (!permissionAlreadyRequested) {
///         // Avoids an infinite onResume loop when the user denies.
///         permissionAlreadyRequested = true
///         requestPermissionLauncher.launch(POST_NOTIFICATIONS)
///     }
/// }
/// ```
///
/// Three things make this worth a class of its own rather than a few lines in
/// a `State`:
///
///  * the `permissionAlreadyRequested` flag is the whole reason the app does
///    not loop forever against a user who says no, and a flag on a widget
///    state is invisible to a test;
///  * "SDK_INT < 33" is a question about the *host*, and the only honest way to
///    answer it off-device is to make it an injectable seam
///    ([NotificationPermissions.needsRuntimePermission]);
///  * every branch either schedules or deliberately does not, and that is
///    exactly what a reminder that never fires looks like from the outside.
///
/// The runtime permission is Android 13+'s POST_NOTIFICATIONS. iOS has the
/// same shape under a different name — the alert authorisation — and
/// [LocalNotificationsPermissions] asks whichever one the host has.
library;

// The core's reminder layer is reached by its `src` path, exactly as
// lib/state/app_scope.dart reaches it.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/utils/midnight_timer.dart';

/// `ContextCompat.checkSelfPermission` + `ActivityResultLauncher`, narrowed to
/// the three questions the resume path asks.
abstract interface class NotificationPermissions {
  /// `SDK_INT >= Build.VERSION_CODES.TIRAMISU` — whether posting a
  /// notification needs a runtime grant at all.
  ///
  /// False on every Android below 13, where the permission is granted at
  /// install time and `scheduleAll()` runs unconditionally.
  Future<bool> get needsRuntimePermission;

  /// `checkSelfPermission(POST_NOTIFICATIONS) == PERMISSION_GRANTED`.
  Future<bool> isGranted();

  /// `requestPermissionLauncher.launch(POST_NOTIFICATIONS)`, resolving to the
  /// user's answer.
  Future<bool> request();
}

/// [NotificationPermissions] over `flutter_local_notifications`.
///
/// Never exercised by a widget test — the plugin's method channel has no
/// implementation there.
class LocalNotificationsPermissions implements NotificationPermissions {
  const LocalNotificationsPermissions({required this.plugin});

  final FlutterLocalNotificationsPlugin plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _darwin =>
      plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  /// The plugin answers `areNotificationsEnabled()` on every Android version,
  /// so "does this host gate notifications behind a grant" is asked of the
  /// platform rather than of the SDK level: on Android 12 and below the answer
  /// is always true and this path is never taken.
  @override
  Future<bool> get needsRuntimePermission async =>
      Platform.isAndroid || Platform.isIOS;

  @override
  Future<bool> isGranted() async {
    final android = _android;
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final darwin = _darwin;
    if (darwin != null) {
      return await darwin.checkPermissions().then(
                (permissions) => permissions?.isAlertEnabled ?? false,
              );
    }
    return true;
  }

  @override
  Future<bool> request() async {
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final darwin = _darwin;
    if (darwin != null) {
      return await darwin.requestPermissions(
            alert: true,
            sound: true,
            badge: true,
          ) ??
          false;
    }
    return true;
  }
}

/// The resume-time decision itself.
///
/// `permissionAlreadyRequested` is one field per activity instance upstream,
/// and the port's counterpart is one instance per launch, owned by
/// [AppScope.permissionGate] and shared by every caller — the habit list's
/// `didPopNext` and `main`'s startup path both reach the same gate, so a
/// refusal answered on one is remembered by the other. An activity restart
/// (a rotation, say) re-asks upstream where the port does not; the difference
/// is invisible because dismissing the dialog resumes rather than recreates.
class ReminderPermissionGate {
  ReminderPermissionGate({
    required ReminderScheduler scheduler,
    required NotificationPermissions permissions,
    Logging? logging,
  })  : _scheduler = scheduler,
        _permissions = permissions,
        _logger = (logging ?? StandardLogging()).getLogger(_loggerName);

  static const String _loggerName = 'ListHabitsActivity';

  final ReminderScheduler _scheduler;

  final NotificationPermissions _permissions;

  final Logger _logger;

  /// `private var permissionAlreadyRequested = false`. Its only purpose is to
  /// stop the app asking again on the resume that follows the user's refusal —
  /// which would otherwise be an infinite loop, because dismissing the system
  /// dialog resumes the activity.
  bool _permissionAlreadyRequested = false;

  bool get permissionAlreadyRequested => _permissionAlreadyRequested;

  /// Returns true when this pass armed the alarms.
  Future<bool> onResume() async {
    // A user with no reminders is never asked for anything.
    if (!_scheduler.hasHabitsWithReminders()) return false;

    if (!await _permissions.needsRuntimePermission) {
      // SDK < 33: the permission is granted at install time.
      _scheduler.scheduleAll();
      return true;
    }
    if (await _permissions.isGranted()) {
      _scheduler.scheduleAll();
      return true;
    }
    // The gate has two callers that reach the same instance — the habit
    // list's `didPopNext` and the startup path — so two `onResume()` calls can
    // be in flight at once. This check and the assignment below it are
    // adjacent with no `await` between them, which is what keeps that safe:
    // whichever call arrives here first raises the flag before yielding again,
    // so the second sees it and never opens a second system dialog.
    if (_permissionAlreadyRequested) return false;
    _permissionAlreadyRequested = true;
    if (await _permissions.request()) {
      _scheduler.scheduleAll();
      return true;
    }
    // Denied: no alarms are (re)scheduled from this path, and nothing else
    // happens — in particular the app does not nag.
    _logger.info('POST_NOTIFICATIONS denied');
    return false;
  }
}

/// The two statements that bracket `ListHabitsActivity`'s foreground time.
///
/// ```kotlin
/// override fun onResume() { midnightTimer.onResume(); ... }
/// override fun onPause()  { midnightTimer.onPause(); ... }
/// ```
///
/// It exists as a class rather than two lines in a `State` for one reason:
/// `MidnightTimer.onResume` *replaces* its executor without shutting the
/// previous one down, and `MidnightTimer.onPause` reads a `late` field that
/// only `onResume` assigns. So resuming twice leaks a set of timers that fire
/// forever, and pausing before the first resume throws. Both are one boolean
/// away, and a boolean living inside a widget's state is a boolean no test can
/// see.
class MidnightTimerLifecycle {
  MidnightTimerLifecycle(this._timer);

  final MidnightTimer _timer;

  bool _running = false;

  /// True between [onResume] and [onPause].
  bool get isRunning => _running;

  /// `midnightTimer.onResume()`.
  ///
  /// [testExecutor] is the same injection point the timer itself offers, so a
  /// test can drive the schedule by hand.
  void onResume({
    int delayOffsetInMillis = DateUtils.secondLength,
    ScheduledExecutorService? testExecutor,
  }) {
    if (_running) return;
    _timer.onResume(delayOffsetInMillis, testExecutor);
    _running = true;
  }

  /// `midnightTimer.onPause()`, which answers with the commands that were
  /// still queued. A pause with no matching resume does nothing at all.
  List<void Function()> onPause() {
    if (!_running) return const <void Function()>[];
    _running = false;
    return _timer.onPause();
  }
}
