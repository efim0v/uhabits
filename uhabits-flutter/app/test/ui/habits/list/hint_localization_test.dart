/// `verify.hints-hardcoded-english`.
///
/// The startup hint box is fed by `R.array.hints`, a resource array of two
/// `@string` references (`@string/hint_drag`, `@string/hint_landscape`), so
/// `resources.getStringArray(R.array.hints)` in `ListHabitsRootView` resolves
/// both through the device locale. The port ships all 47 translations of both
/// strings, so the only thing that can go wrong is the wiring: the array the
/// screen hands its `HintList` has to come out of [L10n], not out of a
/// hard-coded English list.
///
/// Every case here drives the *screen*, the way the app does — a scope, a
/// locale on the `MaterialApp`, and a preference store that says a hint is due
/// — and reads the text that actually reached the box.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_root_view.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/hint_list.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_hint_l10n');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
    resetToday();
  });

  /// A scope over a fresh database. `AppScope.open` stamps `getToday()`, which
  /// is what the hint list compares `lastHintDate` against.
  AppScope openScope() {
    final scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    // `BaseUserInterfaceTest.setUp`: a first run opens the intro on top of the
    // list, which would cover the hint box.
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  /// `HintList.shouldShow()` is true only for a `lastHintDate` strictly before
  /// today, and `pop()` returns `hints[lastHintNumber + 1]`.
  void makeHintDue(Preferences preferences, {int lastNumber = -1}) {
    preferences.updateLastHint(lastNumber, getToday().minus(1));
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    AppScope scope,
    Locale locale,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: const HabitListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The body of the hint box: the second [Text] under [HintView], the first
  /// being `R.string.hint_title`.
  String hintBody(WidgetTester tester) {
    final texts = tester.widgetList<Text>(
      find.descendant(of: find.byType(HintView), matching: find.byType(Text)),
    );
    expect(texts.length, 2,
        reason: 'the hint box is a title over a body; found '
            '${texts.length} Text widgets instead');
    return texts.last.data!;
  }

  group('verify.hints-hardcoded-english', () {
    testWidgets('#1 a French user gets the French hint body', (tester) async {
      final scope = openScope();
      makeHintDue(scope.preferences);
      final fr = await L10n.delegate.load(const Locale('fr'));

      await pumpScreen(tester, scope, const Locale('fr'));

      expect(hintBody(tester), fr.hintDrag,
          reason: 'verify.hints-hardcoded-english#1 — `R.array.hints` is a '
              'resource array of two @string references, so getStringArray '
              'resolves both through the device locale: a French user sees '
              'the indigo card with a French body');
      expect(find.text(listHabitsHints.first), findsNothing,
          reason: 'verify.hints-hardcoded-english#2 — the port must do the '
              'same, instead of handing `core.listHabitsHints`, a const list '
              'of the two English sentences, to the HintList');
      // The title has been localized all along; the point is that the body now
      // comes from the same place.
      expect(find.text(fr.hintTitle), findsOneWidget,
          reason: 'verify.hints-hardcoded-english#2 — no more half-translated '
              'card: localized heading, English body');
    });

    testWidgets('#1 a Russian user gets the Russian hint body',
        (tester) async {
      final scope = openScope();
      makeHintDue(scope.preferences);
      final ru = await L10n.delegate.load(const Locale('ru'));

      await pumpScreen(tester, scope, const Locale('ru'));

      expect(hintBody(tester), ru.hintDrag,
          reason: 'verify.hints-hardcoded-english#1 — a Russian user sees a '
              'Russian body, and so on for all 47 shipped locales');
    });

    testWidgets('#1 the second hint is `@string/hint_landscape`, translated',
        (tester) async {
      final scope = openScope();
      // `last_hint_number` = 0: hint 0 has been shown, so the next pop returns
      // the second entry of the array.
      makeHintDue(scope.preferences, lastNumber: 0);
      final fr = await L10n.delegate.load(const Locale('fr'));

      await pumpScreen(tester, scope, const Locale('fr'));

      expect(hintBody(tester), fr.hintLandscape,
          reason: 'verify.hints-hardcoded-english#1 — the array is '
              '@string/hint_drag followed by @string/hint_landscape, and both '
              'resolve through the device locale');
      expect(hintBody(tester), isNot(listHabitsHints[1]),
          reason: 'verify.hints-hardcoded-english#2 — the whole translated '
              'array must stop being dead code, not just its first entry');
    });

    testWidgets('#2 an English user is unaffected: the same two sentences',
        (tester) async {
      final scope = openScope();
      makeHintDue(scope.preferences);
      final en = await L10n.delegate.load(const Locale('en'));

      await pumpScreen(tester, scope, const Locale('en'));

      expect(hintBody(tester), en.hintDrag,
          reason: 'verify.hints-hardcoded-english#2 — the English ARB carries '
              'the very sentence the hard-coded list held');
      expect(en.hintDrag, listHabitsHints.first,
          reason: 'verify.hints-hardcoded-english#2 — and the two agree, so '
              'the swap is invisible in the source locale');
      expect(en.hintLandscape, listHabitsHints[1],
          reason: 'verify.hints-hardcoded-english#2');
    });
  });
}
