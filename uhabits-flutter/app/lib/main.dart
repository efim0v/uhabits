import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'state/app_scope.dart';
import 'ui/habits/list/habit_list_screen.dart';

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
    return MaterialApp(
      onGenerateTitle: (context) => L10n.of(context).appName,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      darkTheme: ThemeData(colorSchemeSeed: Colors.blue, brightness: Brightness.dark),
      home: scope == null
          ? const _BootstrapScreen()
          : Provider<AppScope>.value(
              value: scope,
              child: const HabitListScreen(),
            ),
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
