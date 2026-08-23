/// The Export item of the habit-detail overflow menu, from the tap to the
/// share sheet.
///
/// `ShowHabitActivity.onCreate` builds its menu presenter with
/// `system = HabitsDirFinder(AndroidDirFinder(this))` and its `Screen` answers
/// `showSendFileScreen(filename)` with `ACTION_SEND`. This file pins both ends
/// of that wiring on the Flutter side; the routing of the menu item itself is
/// covered by show_habit_screen_test.dart.
library;

// The io layer and the menu presenter are reached by their `src` path, exactly
// as lib/state/show_habit_model.dart does.
// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/flutter_files.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/show_habit_model.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
// `Color` and `Theme` collide with the Material ones and nothing here needs
// them.
import 'package:uhabits_core/uhabits_core.dart' hide Color, Theme;

/// The `ACTION_SEND` half of `Activity.showSendFileScreen`, recorded.
class _RecordingSharer implements FileSharer {
  _RecordingSharer({this.throws = false});

  final bool throws;
  final List<({String path, String mimeType})> shared =
      <({String path, String mimeType})>[];

  @override
  Future<void> shareFile(String path, {required String mimeType, Rect? origin}) async {
    shared.add((path: path, mimeType: mimeType));
    // `startActivitySafely` catches ActivityNotFoundException.
    if (throws) throw StateError('no activity found');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory supportDir;
  final scopes = <AppScope>[];
  var databaseIndex = 0;

  setUp(() {
    resetToday();
    supportDir = Directory.systemTemp.createTempSync('uhabits_show_export');
    // `flutter test` registers no plugins, so answering the channel is what
    // points `AppDirectories.resolve()` at a temporary root — the stand-in for
    // `ContextCompat.getExternalFilesDirs(context, null)`.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => supportDir.path,
    );
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    supportDir.deleteSync(recursive: true);
    resetToday();
  });

  AppScope openScope() {
    final database = AppDatabase.openAndMigrate(
      '${supportDir.path}/habits${databaseIndex++}.db',
    );
    final scope = AppScope.open(database);
    scopes.add(scope);
    return scope;
  }

  Habit addHabit(AppScope scope, String name) {
    final habit = scope.modelFactory.buildHabit()..name = name;
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  Directory csvDir() =>
      Directory('${supportDir.path}/${HabitsDirFinder.csvDirName}');

  Widget wrap(Widget child) => MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: child,
      );

  ShowHabitModel modelOf(WidgetTester tester) => Provider.of<ShowHabitModel>(
        tester.element(find.byType(Scaffold)),
        listen: false,
      );

  /// The same `system` the route builds, already resolved.
  ///
  /// Constructed inside [WidgetTester.runAsync] so that path_provider's reply
  /// lands on the real event loop instead of in the fake-async queue a widget
  /// test body runs in.
  Future<ShowHabitCSVOutputDir> resolvedSystem(WidgetTester tester) async {
    late final ShowHabitCSVOutputDir system;
    await tester.runAsync(() async {
      system = ShowHabitCSVOutputDir();
      await system.ready;
    });
    return system;
  }

  /// `ShowHabitMenu.onOptionsItemSelected(R.id.export)` — the very callback the
  /// overflow item's `onSelected` is bound to.
  ///
  /// Driven from the model rather than by tapping the item because the export
  /// writes a real zip: only `runAsync` lets that I/O finish, and a tap cannot
  /// be made from inside it. That the item is in the overflow and reaches this
  /// callback is pinned by show_habit_screen_test.dart
  /// (`show-habit.menu#2`, `show-habit.menu#7`).
  Future<void> exportFromMenu(WidgetTester tester, AppScope scope) async {
    final model = modelOf(tester);
    await tester.runAsync(() async {
      model.menu.onOptionsItemSelected(ShowHabitMenuItem.export);
      await scope.taskRunner.awaitAll();
    });
    await tester.pumpAndSettle();
  }

  group('audit.export-from-the-show-habit-overflow', () {
    testWidgets('#2 the route hands the screen the CSV output directory',
        (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(wrap(
        Navigator(
          key: navigatorKey,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      ));
      unawaited(navigatorKey.currentState!
          .push(ShowHabitScreen.route(scope: scope, habit: habit)));
      await tester.pumpAndSettle();

      final screen = tester.widget<ShowHabitScreen>(
        find.byType(ShowHabitScreen),
      );
      expect(screen.system, isNotNull,
          reason: 'audit.export-from-the-show-habit-overflow#2 — '
              'ShowHabitScreen.route must pass the `system` collaborator, or '
              'ShowHabitModel falls back to a getCSVOutputDir() that throws');

      // And it is the real one: `HabitsDirFinder(AndroidDirFinder(this))`,
      // which names `<external files dir>/CSV`. The resolution the route
      // kicked off is over by the time the screen has finished coming up.
      final system = screen.system!;
      expect(system.getCSVOutputDir().pathString, csvDir().path,
          reason: 'audit.export-from-the-show-habit-overflow#1 — '
              '`system.getCSVOutputDir()` is the CSV folder ExportCSVTask '
              'writes the archive into');
    });

    testWidgets('#1 Export runs ExportCSVTask and hands the archive to the '
        'share sheet', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final sharer = _RecordingSharer();
      final system = await resolvedSystem(tester);

      await tester.pumpWidget(wrap(
        Provider<AppScope>.value(
          value: scope,
          child: ShowHabitScreen(
            habit: habit,
            system: system,
            fileSharer: sharer,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await exportFromMenu(tester, scope);

      final written = csvDir().listSync();
      expect(written, hasLength(1),
          reason: 'audit.export-from-the-show-habit-overflow#1 — '
              'onExportCSV() runs ExportCSVTask(habitList, listOf(habit), '
              'system.getCSVOutputDir())');
      expect(sharer.shared, hasLength(1),
          reason: 'audit.export-from-the-show-habit-overflow#1 — and then '
              'screen.showSendFileScreen(filename)');
      expect(sharer.shared.single.path, written.single.path,
          reason: 'audit.export-from-the-show-habit-overflow#2 — the archive '
              'the task wrote is the file that is shared');
      expect(sharer.shared.single.path, endsWith('.zip'),
          reason: 'audit.export-from-the-show-habit-overflow#1');
      expect(sharer.shared.single.mimeType, 'application/zip',
          reason: 'audit.export-from-the-show-habit-overflow#1 — '
              'type = "application/zip"');
      expect(tester.takeException(), isNull,
          reason: 'audit.export-from-the-show-habit-overflow#2 — selecting '
              'Export must not raise an unhandled error');
    });

    testWidgets('#1 a share sheet nobody can answer shows the '
        'activity-not-found message', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final sharer = _RecordingSharer(throws: true);
      final system = await resolvedSystem(tester);

      await tester.pumpWidget(wrap(
        Provider<AppScope>.value(
          value: scope,
          child: ShowHabitScreen(
            habit: habit,
            system: system,
            fileSharer: sharer,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await exportFromMenu(tester, scope);

      expect(tester.takeException(), isNull,
          reason: 'audit.export-from-the-show-habit-overflow#1 — '
              'startActivitySafely swallows ActivityNotFoundException');
      expect(find.text('No app was found to support this action'), findsOneWidget,
          reason: 'audit.export-from-the-show-habit-overflow#1 — and shows '
              'R.string.activity_not_found instead');
    });

    testWidgets('#2 the default share seam is the real one', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(wrap(
        Navigator(
          key: navigatorKey,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      ));
      unawaited(navigatorKey.currentState!
          .push(ShowHabitScreen.route(scope: scope, habit: habit)));
      await tester.pumpAndSettle();

      expect(
        tester.widget<ShowHabitScreen>(find.byType(ShowHabitScreen)).fileSharer,
        isA<PlatformFileSharer>(),
        reason: 'audit.export-from-the-show-habit-overflow#2 — the screen '
            'shares through share_plus unless a test replaces the seam',
      );
    });
  });
}
