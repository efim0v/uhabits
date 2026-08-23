import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'platform/auto_backup.dart';
import 'platform/crash_handler.dart';
import 'platform/flutter_files.dart';
import 'platform/locale_first_weekday.dart';
import 'state/app_scope.dart';
import 'state/reminder_permission_gate.dart';
import 'state/theme_model.dart';
import 'state/widget_link.dart';
import 'ui/habits/list/habit_list_screen.dart';
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
        home: const _BootstrapScreen(),
      );
    }
    return MultiProvider(
      providers: [
        Provider<AppScope>.value(value: scope),
        ChangeNotifierProvider<ThemeModel>(
          create: (_) => ThemeModel(scope.preferences),
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
  /// `ListHabitsActivity`'s `permissionAlreadyRequested` lives here, because
  /// this is the object with the activity's lifetime: one instance per launch,
  /// asking at most once (`reminders.app-start-and-permission#4`).
  ReminderPermissionGate? _permissionGate;

  /// The navigator the home-screen widget deep links push onto. They arrive
  /// from another process, outside any build, so they need a way in that is not
  /// a `BuildContext`.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  WidgetLinkRouter? _widgetLinks;

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
    _exceptionHandler ??= BaseExceptionHandler(
      const UnportedBugReporter(),
      hooks: FlutterCrashHandlerHooks(),
    )..install();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pushSystemBrightness();
      unawaited(_onResume());
      _startWidgetLinks();
    });
  }

  /// Subscribes to `uhabits://widget/...`, which is how a freshly placed
  /// home-screen widget asks for the habit picker (`widgets.config-picker#1`).
  ///
  /// Without it a placed widget can never be configured: the native
  /// `HabitPickerDialog` captures the widget id and reports the outcome, but
  /// the habit catalogue it would list only exists on this side.
  void _startWidgetLinks() {
    if (!mounted || _widgetLinks != null) return;
    final scope = context.read<AppScope>();
    // Null on a host with no widget support, and in every widget test, because
    // `startPlatformServices` is what builds it.
    final sync = scope.widgetSync;
    if (sync == null) return;
    _widgetLinks = WidgetLinkRouter(
      habitList: scope.habitList,
      registry: sync.bridge.registry,
      publish: sync.updateWidgets,
      navigator: _navigatorKey,
      launches: const HomeWidgetLaunches(),
    );
    unawaited(_widgetLinks!.start());
  }

  @override
  void dispose() {
    _onPause();
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
    final scheduler = scope.reminderScheduler;
    if (scheduler == null) return;
    _resumeMidnightTimer(scope);
    final gate = _permissionGate ??= ReminderPermissionGate(
      scheduler: scheduler,
      permissions: LocalNotificationsPermissions(
        plugin: FlutterLocalNotificationsPlugin(),
      ),
      logging: scope.logging,
    );
    await gate.onResume();
    await _runAutoBackup(scope);
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

  void _pushSystemBrightness() {
    if (!mounted) return;
    context.read<ThemeModel>().systemBrightness =
        View.of(context).platformDispatcher.platformBrightness;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeModel>().currentTheme;
    return MaterialApp(
      onGenerateTitle: (context) => L10n.of(context).appName,
      navigatorKey: _navigatorKey,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: appThemeData(theme),
      // `getFirstWeekdayNumberAccordingToLocale()`, which on Android is
      // `GregorianCalendar(Locale.getDefault()).firstDayOfWeek`. It has to be
      // installed below the localizations delegates, which is what
      // `MaterialApp.builder` is.
      builder: (context, child) =>
          FirstWeekdayFromLocale(child: child ?? const SizedBox.shrink()),
      home: const HabitListScreen(),
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
