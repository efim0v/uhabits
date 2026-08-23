import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'state/app_scope.dart';
import 'state/theme_model.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushSystemBrightness());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: appThemeData(theme),
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
