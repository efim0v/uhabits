/// The horizontal window inset is applied once, to every screen.
///
/// `applyRootViewInsets()` pads one view by `max(systemBars, displayCutout)`
/// left and right and paints it black, and it is installed once per full-window
/// activity. Nothing on that activity re-applies the horizontal number:
/// `SettingsFragment` adds only `applyBottomInset()` to its list, and
/// `EditHabitActivity`'s second call replaces the first on the same view, since
/// `ViewCompat.setOnApplyWindowInsetsListener` has one slot per view. So the
/// ceiling upstream is one horizontal inset — the content is flush with the
/// toolbar above it.
///
/// The port pads at the root, in `MaterialApp.builder`. A screen that then
/// wraps its body in a bare `SafeArea` reads the same untouched
/// `MediaQuery.padding` and pads again, and the content steps in twice as far
/// as its own toolbar. `audit23.the-root-inset-must-be-consumed-once#1`.
///
/// These cases pump the real screens under the real builder with a real inset —
/// the shape every earlier inset test was missing, which is why the habit list
/// carried this defect for a month and its two siblings kept it after the habit
/// list was fixed.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/settings_model.dart';
import 'package:uhabits/ui/common/window_insets.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';
// ignore: implementation_imports
import 'package:uhabits_core/src/preferences/memory_storage.dart';

const String rule =
    'audit23.the-root-inset-must-be-consumed-once#1 — one horizontal inset per '
    'screen, so the content is flush with the toolbar above it.';

/// The inset a notched phone in landscape reports.
const EdgeInsets inset = EdgeInsets.only(left: 44, top: 24, right: 12, bottom: 48);

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];

  setUp(() => tempDir = Directory.systemTemp.createTempSync('uhabits_inset'));
  tearDown(() {
    for (final s in scopes) {
      s.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/u${scopes.length}.db'),
      preferencesStorage: MemoryStorage(),
    );
    scopes.add(scope);
    return scope;
  }

  /// `main()`'s own shape: the inset applied once, above the navigator.
  Future<void> pumpUnderRoot(WidgetTester tester, Widget home,
      {AppScope? scope}) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(
        left: 44, top: 24, right: 12, bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(
        left: 44, top: 24, right: 12, bottom: 48);
    addTearDown(tester.view.reset);

    Widget app = MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      builder: (context, child) => RootViewInsets(child: child!),
      home: home,
    );
    if (scope != null) {
      app = Provider<AppScope>.value(value: scope, child: app);
    }
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  /// The distance from the window's own edge to [finder]'s left edge.
  double leftOf(WidgetTester tester, Finder finder) =>
      tester.getRect(finder).left;

  testWidgets('settings: the list is flush with its toolbar', (tester) async {
    final AppScope scope = openScope();
    await pumpUnderRoot(
      tester,
      ChangeNotifierProvider<SettingsModel>(
        create: (_) => SettingsModel(scope),
        child: const SettingsScreen(),
      ),
      scope: scope,
    );

    final double toolbar = leftOf(tester, find.byType(AppBar));
    final double content =
        leftOf(tester, find.byType(SingleChildScrollView).first);

    expect(toolbar, inset.left, reason: '$rule The toolbar is inset once.');
    expect(content, toolbar,
        reason: '$rule …and the rows start where the toolbar does. Twice the '
            'inset puts a visible step between them and eats about 56 logical '
            'pixels of a landscape window.');
  });

  testWidgets('edit habit: the form is flush with its toolbar', (tester) async {
    final AppScope scope = openScope();
    await pumpUnderRoot(tester, const EditHabitScreen(), scope: scope);

    final double toolbar = leftOf(tester, find.byType(AppBar));
    final double content =
        leftOf(tester, find.byType(SingleChildScrollView).first);

    expect(toolbar, inset.left, reason: rule);
    expect(content, toolbar, reason: rule);
  });
}
