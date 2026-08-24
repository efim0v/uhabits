import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'l10n/locale_resolution.dart';
import 'platform/auto_backup.dart';
import 'platform/crash_handler.dart';
import 'platform/device_locale.dart';
import 'platform/flutter_files.dart';
import 'platform/locale_first_weekday.dart';
import 'state/app_scope.dart';
import 'state/intent_router.dart';
import 'state/reminder_link.dart';
import 'state/reminder_permission_gate.dart' show MidnightTimerLifecycle;
import 'state/theme_model.dart';
import 'state/widget_link.dart';
import 'state/widget_sync.dart';
import 'ui/common/dialogs/snooze_picker_dialog.dart';
import 'ui/common/screen_route_observer.dart';
import 'ui/common/window_insets.dart';
import 'ui/habits/list/habit_list_screen.dart';
import 'ui/habits/show/show_habit_screen.dart';
import 'ui/theme/app_theme.dart';

/// Port of `HabitsApplication.onCreate` plus `ListHabitsActivity`'s
/// `setContentView`: the whole startup sequence lives in [AppScope.boot], and
/// what is left here is handing the finished scope to the widget tree.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final scope = await AppScope.boot();
  runApp(UhabitsApp(scope: scope));
}

class UhabitsApp extends StatelessWidget {
  const UhabitsApp({super.key, this.scope});

  /// The already-booted scope. When null — `const UhabitsApp()` — the app boots
  /// one itself and shows the toolbar while it waits.
  final AppScope? scope;

  @override
  Widget build(BuildContext context) {
    final scope = this.scope;
    if (scope == null) {
      return MaterialApp(
        onGenerateTitle: (context) => L10n.of(context).appName,
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        // `res/values/` for a language the app does not translate — see
        // lib/l10n/locale_resolution.dart. Without it Flutter's last resort is
        // `supportedLocales.first`, which gen-l10n makes Afrikaans.
        localeListResolutionCallback: resolveAppLocale,
        navigatorObservers: <NavigatorObserver>[screenRouteObserver],
        // `rootView.applyRootViewInsets()` again: this branch also ends on the
        // habit list, and the list no longer pads itself
        // (`audit22.habit-list-applies-the-root-window-inset-twice#1`), so the
        // one root that carries the insets has to be here too
        // (`platform-glue.window-insets#5`).
        builder: (context, child) =>
            RootViewInsets(child: child ?? const SizedBox.shrink()),
        home: const _BootstrapScreen(),
      );
    }
    return MultiProvider(
      providers: [
        Provider<AppScope>.value(value: scope),
        ChangeNotifierProvider<ThemeModel>(
          // `ListHabitsActivity.onCreate` calls
          // `component.themeSwitcher.apply()` BEFORE `setContentView`, so the
          // window is already dark on the very first frame for a user whose
          // theme is Dark (`audit3.one-light-themed-frame-on-every#1`).
          //
          // `create` runs during the first `build` of [_ThemedApp], before it
          // reads `currentTheme` — which is the port's `setContentView` — so
          // applying here is applying before the first layout. The system
          // brightness comes from the binding because there is no `View`
          // ancestor to ask yet, and `platformBrightness` is a property of the
          // platform rather than of one view; [_ThemedAppState] is already
          // registered as a `WidgetsBindingObserver` by now, so a change after
          // this point arrives through `didChangePlatformBrightness`.
          //
          // Deferring this to a post-frame callback — which is what the port
          // used to do — repaints on frame 2 instead, and `currentTheme`
          // starts as `LightTheme()`: every launch flashed white.
          create: (_) => ThemeModel(
            scope.preferences,
            systemBrightness:
                WidgetsBinding.instance.platformDispatcher.platformBrightness,
          )..apply(),
        ),
      ],
      child: const _ThemedApp(),
    );
  }
}

/// Applies whichever theme `AndroidThemeSwitcher` would have chosen.
///
/// The theme is a value in the tree here rather than a property of an activity,
/// so switching it rebuilds in place instead of restarting the screen — see
/// docs/parity/DEVIATIONS.md.
class _ThemedApp extends StatefulWidget {
  const _ThemedApp();

  @override
  State<_ThemedApp> createState() => _ThemedAppState();
}

class _ThemedAppState extends State<_ThemedApp> with WidgetsBindingObserver {
  /// The navigator the home-screen widget deep links push onto. They arrive
  /// from another process, outside any build, so they need a way in that is not
  /// a `BuildContext`.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  WidgetLinkRouter? _widgetLinks;

  /// The scope's reminder router, held from [_attachReminderResponses] so that
  /// [dispose] can detach without looking up an ancestor.
  ReminderResponseRouter? _reminderResponses;

  /// `Thread.setDefaultUncaughtExceptionHandler(BaseExceptionHandler(this))`,
  /// held so it is installed exactly once (`platform-glue.crash-handler#2`).
  BaseExceptionHandler? _exceptionHandler;

  @override
  void initState() {
    super.initState();
    // ListHabitsActivity.onCreate installs the crash handler after the graph
    // and the views exist and before behavior.onStartup(); this is the same
    // point in the port — the scope is built (main() awaited boot()), the app
    // widget is mounting, and nothing on the list screen has run yet. Anything
    // that fails earlier, inside AppScope.boot(), is deliberately not covered:
    // platform-glue.crash-handler#6.
    //
    // `BaseExceptionHandler(this)` dumps through `AndroidBugReporter(activity)`
    // (`io.bug-report-dump#8`); the scope holds that reporter, already pointed
    // at <external files>/Logs, so a crash leaves the same
    // `Log <yyyy-MM-dd HHmmss>.txt` behind that the Troubleshooting row writes.
    _exceptionHandler ??= BaseExceptionHandler(
      context.read<AppScope>().bugReporter,
      hooks: FlutterCrashHandlerHooks(),
    )..install();
    WidgetsBinding.instance.addObserver(this);
    // Built before the first frame, so that the habit list can register with it
    // as it mounts; only the plugin subscription waits for the frame.
    _widgetLinks = _buildWidgetLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Before the resume, because a notification can be what launched the
      // app: the response was decoded during AppScope.boot() and has been
      // waiting for a screen ever since.
      _attachReminderResponses();
      unawaited(_onResume());
      unawaited(_widgetLinks?.start());
    });
  }

  /// Hands the scope's reminder router the three answers that need a screen.
  ///
  /// The router itself is built by `AppScope.startPlatformServices`, because
  /// the plugin callback is registered before `runApp` — see
  /// lib/state/reminder_link.dart. What is missing until now is everything
  /// that needs a `BuildContext`: `ShowHabitActivity` for a tap on the body,
  /// the ACTION_EDIT value dialog for "Enter", and `SnoozeDelayPickerActivity`
  /// for "Later".
  void _attachReminderResponses() {
    if (!mounted) return;
    // Held rather than read back in dispose(), where looking an ancestor up is
    // no longer safe.
    final router = _reminderResponses = context.read<AppScope>().reminderResponses;
    // Null on a host that could not start the platform services, and in every
    // widget test that never does.
    router?.attach(
      // `IntentFactory.startShowHabitActivity`, the notification's content
      // intent — the same push the five graph widgets make.
      showHabit: (habit) {
        final navigatorContext = _navigatorKey.currentContext;
        if (navigatorContext == null) return;
        unawaited(ShowHabitScreen.open(navigatorContext, habit));
      },
      // `PendingIntentFactory.showNumberPicker(habit, date)` is an activity
      // intent to `ListHabitsActivity` with ACTION_EDIT, which the list
      // screen's `parseIntents()` answers. The app has exactly one road to
      // that screen from outside — the deep link `WidgetLinkRouter` rebuilds
      // into that very intent — so "Enter" takes it, and what reaches
      // `parseIntents()` is the intent upstream would have sent.
      openValuePicker: (habit, date) {
        final links = _widgetLinks;
        if (links == null) return;
        final month = date.month.toString().padLeft(2, '0');
        final day = date.day.toString().padLeft(2, '0');
        unawaited(links.handle(Uri.parse(
          'uhabits://widget/${WidgetLink.actionEdit}'
          '?habit=${habit.id}&date=${date.year}-$month-$day',
        )));
      },
      // `SnoozeDelayPickerActivity`, which upstream is a translucent activity
      // the notification action starts and here is a dialog on the running
      // app (see docs/parity/DEVIATIONS.md).
      pickSnoozeDelay: (habit) async {
        final navigatorContext = _navigatorKey.currentContext;
        if (navigatorContext == null) return null;
        return showSnoozePickerDialog(navigatorContext, habit: habit);
      },
    );
  }

  /// Builds the receiver for `uhabits://widget/...`, the four deep links
  /// `android/.../widgets/WidgetIntents.kt` sends.
  ///
  /// Without it a placed widget can never be configured — the native
  /// `HabitPickerDialog` captures the widget id and reports the outcome, but
  /// the habit catalogue it would list only exists on this side — and a tap on
  /// a configured one opens the app on the list instead of acting.
  WidgetLinkRouter? _buildWidgetLinks() {
    final scope = context.read<AppScope>();
    // Null on a host with no widget support, and in every widget test, because
    // `startPlatformServices` is what builds them.
    final sync = scope.widgetSync;
    final tray = scope.notificationTray;
    if (sync == null) return null;
    return WidgetLinkRouter(
      habitList: scope.habitList,
      registry: sync.bridge.registry,
      publish: sync.updateWidgets,
      navigator: _navigatorKey,
      launches: const HomeWidgetLaunches(),
      // `WidgetComponent`, which `WidgetReceiver.onReceive` creates per
      // broadcast: the parser, the behavior, the preferences and the updater.
      receiver: tray == null
          ? null
          : WidgetIntentReceiver(
              parser: IntentParser(scope.habitList),
              controller: WidgetBehavior(
                habitList: scope.habitList,
                commandRunner: scope.commandRunner,
                notificationTray: tray,
                preferences: scope.preferences,
              ),
              preferences: scope.preferences,
              updateWidgets: sync.updateWidgets,
              scheduleStartDayWidgetUpdate: sync.scheduleStartDayWidgetUpdate,
              logging: scope.logging,
            ),
      // `IntentFactory.startShowHabitActivity`, pushed onto the list route the
      // way `TaskStackBuilder` put `ListHabitsActivity` under it.
      showHabit: (habit) {
        final navigatorContext = _navigatorKey.currentContext;
        if (navigatorContext == null) return;
        unawaited(ShowHabitScreen.open(navigatorContext, habit));
      },
    );
  }

  @override
  void dispose() {
    _onPause();
    _reminderResponses?.detach();
    _widgetLinks?.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onResume());
    } else {
      _onPause();
    }
  }

  /// The POST_NOTIFICATIONS half of `ListHabitsActivity.onResume`, preceded by
  /// `midnightTimer.onResume()`.
  ///
  /// Null-safe from top to bottom: a host that could not start the platform
  /// services — macOS, a widget test — has no scheduler to arm and no
  /// permission to ask for, and starts no timer either. That guard is also
  /// what keeps a 24-hour timer out of every widget test.
  Future<void> _onResume() async {
    if (!mounted) return;
    final scope = context.read<AppScope>();
    // Everything the shade did while no Dart was running: the reminder the OS
    // posted from a pre-built alarm — upstream `ReminderReceiver` runs in the
    // app process and hands it to `onShowReminder` — and the swipe upstream
    // delivers through the notification's delete intent.
    // `flutter_local_notifications` reports neither, so both are discovered
    // here, at the first moment after them at which Dart is running again.
    await scope.reminderResponses?.onResumed();
    if (!mounted) return;
    // `ListHabitsActivity.onResume` arms the timer as its fourth statement,
    // before the reminder block and independently of it: the day boundary has
    // to move even on a run where the notification subsystem failed to start,
    // or `getToday()` stays frozen and a tap on the newest column writes the
    // entry to yesterday.
    _resumeMidnightTimer(scope);
    // `ListHabitsActivity`'s `permissionAlreadyRequested` is a field of the
    // activity, and the activity outlives every screen pushed over it — so the
    // gate is the scope's, and the habit list's `didPopNext` runs *this same
    // instance* when the editor or the settings screen closes
    // (`audit15.the-notification-permission-prompt-is-never#1`).
    await scope.reminderPermissionGate?.onResume();
    // Outside the branch above, exactly as upstream: the background block is a
    // sibling of the `hasHabitsWithReminders()` test, not a continuation of it.
    await _runResumeTasks(scope);
  }

  /// The task-runner block `ListHabitsActivity.onResume` ends with:
  ///
  /// ```kotlin
  /// taskRunner.run {
  ///     AutoBackup(this@ListHabitsActivity).run()
  ///     appComponent.widgetUpdater.updateWidgets()
  /// }
  /// ```
  ///
  /// The second statement is what repaints the home screen on a return to the
  /// app even when this process ran no command
  /// (`verify.widgets-not-refreshed-on-resume`, `widgets.updater#10`). It is
  /// not conditional on the backup: a scope with no database *file* — which
  /// only happens in a test — has nothing to back up and still has widgets.
  Future<void> _runResumeTasks(AppScope scope) async {
    await _runAutoBackup(scope);
    await scope.widgetSync?.updateWidgets();
  }

  /// `ListHabitsActivity.onPause`, whose first statement is
  /// `midnightTimer.onPause()`.
  void _onPause() => _midnightTimer?.onPause();

  /// `midnightTimer.onResume()` / `onPause()`, with the resume-once guard the
  /// timer itself does not have.
  MidnightTimerLifecycle? _midnightTimer;

  void _resumeMidnightTimer(AppScope scope) {
    (_midnightTimer ??= MidnightTimerLifecycle(scope.midnightTimer)).onResume();
  }

  /// `AutoBackup(this).run()` inside `ListHabitsActivity.onResume`'s task-runner
  /// block. The block's `try`/`catch` lives in [AutoBackupTask], so a failing
  /// backup is logged and swallowed rather than taking the resume down with it.
  Future<void> _runAutoBackup(AppScope scope) async {
    if (scope.databasePath == null) return;
    final directories = await AppDirectories.resolve();
    scope.taskRunner.execute(
      AutoBackupTask(
        AutoBackup(
          databasePath: scope.databasePath,
          dirFinder: HabitsDirFinder.of(directories),
          logging: scope.logging,
        ),
        logging: scope.logging,
      ),
    );
  }

  @override
  void didChangePlatformBrightness() => _pushSystemBrightness();

  /// `AndroidThemeSwitcher.getSystemTheme()`, which reads
  /// `resources.configuration.uiMode` off the context.
  ///
  /// Read from the binding rather than from `View.of(context)`, so that this
  /// and the initial `apply()` in [UhabitsApp.build] — which has no `View`
  /// ancestor to ask — read the same value: `platformBrightness` is a property
  /// of the platform, not of one view.
  void _pushSystemBrightness() {
    if (!mounted) return;
    context.read<ThemeModel>().systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeModel>().currentTheme;
    return MaterialApp(
      onGenerateTitle: (context) => L10n.of(context).appName,
      navigatorKey: _navigatorKey,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      // Android serves the default `res/values/` strings — English — to any
      // device whose language it ships no `values-<lang>` for
      // (`audit10.untranslated-device-language-serves-english#1`). Flutter
      // would serve `supportedLocales.first` instead, and gen-l10n orders that
      // list by ARB filename, so the untranslated half of the world would read
      // a 22-message Afrikaans UI.
      localeListResolutionCallback: resolveAppLocale,
      // Android runs `onPause` on the activity a new activity covers, and
      // `onResume` when it is finished. This is where a screen hears about
      // that — see lib/ui/common/screen_route_observer.dart.
      navigatorObservers: <NavigatorObserver>[screenRouteObserver],
      theme: appThemeData(theme),
      // `Locale.getDefault()`, which the first weekday, the entry popup's
      // number symbols and every chart's date formatter read
      // (`audit9.first-weekday-follows-the-device-locale#1`). No `locale:` is
      // set on this MaterialApp, so the tree's own locale stays the resolved
      // one and only the data conventions follow the device. Both widgets have
      // to sit below the localizations delegates, which is what
      // `MaterialApp.builder` is: that is where `intl`'s per-locale CLDR table
      // is installed.
      //
      // `rootView.applyRootViewInsets()`, which upstream every full-window
      // activity calls on its own root, lives here for the same reason: this
      // is the one root a Flutter app has (`platform-glue.window-insets#1`,
      // `#5`).
      builder: (context, child) => RootViewInsets(
        child: DeviceLocale(
          child: FirstWeekdayFromLocale(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
      home: HabitListScreen(widgetLinks: _widgetLinks),
    );
  }
}

/// Opens the database on the way in, for entry points that have not booted a
/// scope of their own.
class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();

  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  late final Future<AppScope> _scope = AppScope.boot();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppScope>(
      future: _scope,
      builder: (context, snapshot) {
        final scope = snapshot.data;
        if (scope != null) {
          return Provider<AppScope>.value(
            value: scope,
            child: const HabitListScreen(),
          );
        }
        // Deliberately static while the future is pending: an indeterminate
        // progress indicator animates forever, which no widget test can settle,
        // and opening the database takes a frame or two at most.
        return Scaffold(
          appBar: AppBar(title: Text(L10n.of(context).mainActivityTitle)),
          body: Center(
            child: snapshot.hasError
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
