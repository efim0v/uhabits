/// Three preferences whose only visible effect is on the main screen's menu.
///
/// `settings.preferences.skip-enabled#5`,
/// `settings.preferences.show-archived-completed#4` and
/// `settings.preferences.habit-list-orders#6` are each the last rule of a
/// preference feature, and each of them is a claim about `ListHabitsMenu`
/// rather than about `Preferences`: what the "Hide completed" item is called,
/// what the two filter checkboxes are ticked from, and which sort entry carries
/// an arrow. The rest of those three features — keys, defaults, fallbacks — is
/// asserted in the core package and in
/// test/ui/settings/settings_screen_test.dart.
///
/// The menu itself belongs to `list-habits.menu.overflow-items` and is tested
/// as a whole in test/ui/habits/list/list_habits_menu_test.dart; this file
/// drives the same widget from the preference side, which is the side that
/// owns these three rules.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/habit_list_model.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  final List<AppScope> scopes = <AppScope>[];
  int databaseIndex = 0;

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_menu_prefs');
  });

  tearDown(() {
    for (final AppScope scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope(PreferencesStorage storage) {
    final AppScope scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits${databaseIndex++}.db'),
      preferencesStorage: storage,
    );
    scopes.add(scope);
    return scope;
  }

  /// The toolbar on its own, over a scope whose preferences the test owns.
  Future<({ListHabitsMenuState menu, L10n l10n, Preferences preferences})> pump(
    WidgetTester tester, {
    PreferencesStorage? storage,
  }) async {
    final AppScope scope = openScope(storage ?? MemoryStorage());
    final HabitListModel model = HabitListModel(scope);
    addTearDown(model.dispose);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Scaffold(
        appBar: ListHabitsMenu(
          model: model,
          title: 'Habits',
          backgroundColor: Colors.blue,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (
      menu: tester.state<ListHabitsMenuState>(find.byType(ListHabitsMenu)),
      l10n: L10n.of(tester.element(find.byType(ListHabitsMenu))),
      preferences: scope.preferences,
    );
  }

  group('settings.preferences.skip-enabled', () {
    testWidgets('#5 either extra entry value relabels "Hide completed"',
        (WidgetTester tester) async {
      const String rule =
          'settings.preferences.skip-enabled#5 — ListHabitsMenu relabels the '
          '"Hide completed" filter item to "Hide entered" when either '
          'areQuestionMarksEnabled or isSkipEnabled is true.';

      final harness = await pump(tester);
      final ListHabitsMenuState menu = harness.menu;
      final L10n l10n = harness.l10n;
      final Preferences preferences = harness.preferences;

      expect(l10n.hideCompleted, 'Hide completed', reason: rule);
      expect(l10n.hideEntered, 'Hide entered', reason: rule);

      // Both off — the default of both keys.
      expect(preferences.isSkipEnabled, isFalse, reason: rule);
      expect(preferences.areQuestionMarksEnabled, isFalse, reason: rule);
      expect(menu.hideCompletedTitle(l10n), l10n.hideCompleted, reason: rule);

      // Skip alone.
      preferences.isSkipEnabled = true;
      expect(menu.hideCompletedTitle(l10n), l10n.hideEntered,
          reason: '$rule Skip days alone is enough.');

      // Question marks alone.
      preferences
        ..isSkipEnabled = false
        ..areQuestionMarksEnabled = true;
      expect(menu.hideCompletedTitle(l10n), l10n.hideEntered,
          reason: '$rule …and so is question marks alone.');

      // Both — "either", not "exactly one".
      preferences.isSkipEnabled = true;
      expect(menu.hideCompletedTitle(l10n), l10n.hideEntered, reason: rule);

      // Back to neither.
      preferences
        ..isSkipEnabled = false
        ..areQuestionMarksEnabled = false;
      expect(menu.hideCompletedTitle(l10n), l10n.hideCompleted,
          reason: '$rule The label is derived on every build, not latched.');
    });
  });

  group('settings.preferences.show-archived-completed', () {
    testWidgets('#4 the two filter items are ticked from the NEGATION of the '
        'preference', (WidgetTester tester) async {
      const String rule =
          'settings.preferences.show-archived-completed#4 — ListHabitsMenu sets '
          'the checked state of the filter items to the NEGATION of the '
          'preference: hideArchivedItem.isChecked = !preferences.showArchived '
          'and hideCompletedItem.isChecked = !preferences.showCompleted. The '
          'items say "hide", the preferences say "show", so the inversion is '
          'the whole rule — getting it backwards would tick both boxes on a '
          'fresh install.';

      final harness = await pump(tester);
      final ListHabitsMenuState menu = harness.menu;
      final Preferences preferences = harness.preferences;

      // The defaults: showArchived false, showCompleted true. So on a fresh
      // install "Hide archived" is ticked and "Hide completed" is not.
      expect(preferences.showArchived, isFalse, reason: rule);
      expect(preferences.showCompleted, isTrue, reason: rule);
      expect(menu.isHideArchivedChecked, isTrue,
          reason: '$rule !showArchived == true');
      expect(menu.isHideCompletedChecked, isFalse,
          reason: '$rule !showCompleted == false');

      // Both flipped: the checkboxes flip with them, still inverted.
      preferences
        ..showArchived = true
        ..showCompleted = false;
      expect(menu.isHideArchivedChecked, isFalse, reason: rule);
      expect(menu.isHideCompletedChecked, isTrue, reason: rule);

      // Independently, so neither reads the other's key.
      preferences.showCompleted = true;
      expect(menu.isHideArchivedChecked, isFalse, reason: rule);
      expect(menu.isHideCompletedChecked, isFalse, reason: rule);
    });
  });

  group('settings.preferences.habit-list-orders', () {
    testWidgets('#6 updateArrows reads defaultPrimaryOrder',
        (WidgetTester tester) async {
      const String rule =
          'settings.preferences.habit-list-orders#6 — ListHabitsMenu.'
          'updateArrows reads defaultPrimaryOrder to decide which sort menu '
          'item shows an up or down arrow icon. It is the persisted preference '
          'that is read, not the adapter\'s in-memory order, which is why the '
          'arrow survives a relaunch.';

      final MemoryStorage storage = MemoryStorage();
      final harness = await pump(tester, storage: storage);
      final ListHabitsMenuState menu = harness.menu;
      final Preferences preferences = harness.preferences;

      /// Every sort item that carries an arrow, and which arrow.
      Map<String, IconData> arrows() => <String, IconData>{
            for (final String id in <String>[
              ListHabitsMenuItems.sortManual,
              ListHabitsMenuItems.sortName,
              ListHabitsMenuItems.sortColor,
              ListHabitsMenuItems.sortScore,
              ListHabitsMenuItems.sortStatus,
            ])
              if (menu.sortArrowFor(id) != null) id: menu.sortArrowFor(id)!,
          };

      // The default order is BY_POSITION, which is the 'Manually' entry.
      expect(preferences.defaultPrimaryOrder, HabitListOrder.byPosition,
          reason: rule);
      expect(arrows().keys, <String>[ListHabitsMenuItems.sortManual],
          reason: '$rule Exactly one entry is marked at a time.');

      // Every order the preference can hold moves the arrow, and nothing but
      // the preference does.
      const Map<HabitListOrder, String> owner = <HabitListOrder, String>{
        HabitListOrder.byNameAsc: ListHabitsMenuItems.sortName,
        HabitListOrder.byNameDesc: ListHabitsMenuItems.sortName,
        HabitListOrder.byColorAsc: ListHabitsMenuItems.sortColor,
        HabitListOrder.byColorDesc: ListHabitsMenuItems.sortColor,
        HabitListOrder.byScoreAsc: ListHabitsMenuItems.sortScore,
        HabitListOrder.byScoreDesc: ListHabitsMenuItems.sortScore,
        HabitListOrder.byStatusAsc: ListHabitsMenuItems.sortStatus,
        HabitListOrder.byStatusDesc: ListHabitsMenuItems.sortStatus,
        HabitListOrder.byPosition: ListHabitsMenuItems.sortManual,
      };
      for (final MapEntry<HabitListOrder, String> entry in owner.entries) {
        preferences.defaultPrimaryOrder = entry.key;
        expect(arrows().keys, <String>[entry.value],
            reason: '$rule ${entry.key} marks ${entry.value}, and nothing '
                'else.');
      }

      // It is the stored string that is read: writing the key behind the
      // preference's back still moves the arrow.
      storage.putString('pref_default_order', 'BY_SCORE_DESC');
      expect(arrows().keys, <String>[ListHabitsMenuItems.sortScore],
          reason: '$rule The read goes all the way to storage on every build.');

      // A stored value that is not an enum name falls back to BY_POSITION
      // (`#2`), and the arrow follows the fallback rather than disappearing.
      storage.putString('pref_default_order', 'BY_NOTHING');
      expect(arrows().keys, <String>[ListHabitsMenuItems.sortManual],
          reason: rule);
    });
  });
}
