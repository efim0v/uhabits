/// `audit3.the-calendar-card-on-the-habit#1`: the Calendar card on the habit
/// detail screen is read-only.
///
/// Upstream `HistoryCardView.setState` builds its `HistoryChart` without an
/// `onDateClickedListener`, so the chart keeps the no-op default declared in
/// `HistoryChart.kt`, and `setListener(presenter)` wires only the Edit button.
/// Tapping or long-pressing a day square there does nothing at all; the way to
/// change a past entry from this screen is the Edit button, which opens the
/// history-editor dialog — and only that dialog's chart is given the presenter
/// (`ShowHabitActivity.Screen.showHistoryEditorDialog`).
///
/// The gestures below are made on the screen the app builds for itself, so
/// what is asserted is the wiring, not a widget this test configured.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/show_habit_model.dart';
import 'package:uhabits/ui/common/dialogs/checkmark_dialog.dart';
import 'package:uhabits/ui/common/dialogs/history_editor_dialog.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/habits/show/cards/history_card_view.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/uhabits_core.dart' hide Color, Theme;

const String rule = 'audit3.the-calendar-card-on-the-habit#1 — In the Kotlin '
    'app: Tapping or long-pressing a day square in the Calendar card does '
    'nothing at all. The only way to change past entries from this screen is '
    'the "Edit" button, which opens the history-editor dialog, and only that '
    'dialog\'s chart gets the presenter as its listener.';

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];

  /// Everything the running screen sends to `SystemChannels.platform`, which
  /// is where `Feedback.forTap` — the port of `showFeedback()` — lands.
  final platformCalls = <MethodCall>[];

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_calendar_readonly');
    platformCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final database = AppDatabase.openAndMigrate('${tempDir.path}/habits.db');
    final scope = AppScope.open(database);
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  Habit addHabit(AppScope scope, String name,
      {HabitType type = HabitType.yesNo}) {
    final habit = scope.modelFactory.buildHabit()
      ..name = name
      ..color = const PaletteColor(7)
      ..type = type;
    if (type == HabitType.numerical) {
      habit.unit = 'km';
      habit.targetValue = 5.0;
    }
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  Future<Habit> pumpScreen(WidgetTester tester,
      {HabitType type = HabitType.yesNo}) async {
    final scope = openScope();
    final habit = addHabit(scope, 'Meditate', type: type);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: ShowHabitScreen(
            key: ValueKey<String?>(habit.uuid),
            habit: habit,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(HistoryCardView.editButtonKey));
    await tester.pumpAndSettle();
    return habit;
  }

  ShowHabitModel modelOf(WidgetTester tester) => Provider.of<ShowHabitModel>(
        tester.element(find.byType(HistoryCardView)),
        listen: false,
      );

  /// The chart inside the Calendar card, and the top-left of the box it fills.
  (HistoryChart, Offset) cardChart(WidgetTester tester) {
    final finder = find.descendant(
      of: find.byType(HistoryCardView),
      matching: find.byType(CoreView),
    );
    return (
      tester.widget<CoreView>(finder).view as HistoryChart,
      tester.getTopLeft(finder),
    );
  }

  group('audit3.the-calendar-card-on-the-habit', () {
    testWidgets('#1 the card\'s chart is not given the presenter',
        (tester) async {
      await pumpScreen(tester);
      final (chart, _) = cardChart(tester);

      expect(
        identical(chart.onDateClickedListener,
            modelOf(tester).presenter.historyCardPresenter),
        isFalse,
        reason: rule,
      );
    });

    testWidgets('#1 a tap on a day square opens nothing', (tester) async {
      await pumpScreen(tester);
      final (_, origin) = cardChart(tester);

      // 160dp over eight rows: row 0 is the month header, so (10, 30) is the
      // top-left day square — the same point chart_cards_test.dart clicks.
      await tester.tapAt(origin + const Offset(10, 30));
      await tester.pumpAndSettle();

      expect(find.byType(CheckmarkDialog), findsNothing, reason: rule);
      expect(find.byType(NumberDialog), findsNothing, reason: rule);
      expect(find.byType(HistoryEditorDialog), findsNothing, reason: rule);
    });

    testWidgets('#1 a long press on a day square records nothing',
        (tester) async {
      final habit = await pumpScreen(tester);
      final (chart, origin) = cardChart(tester);
      final date = chart.today.minus(6);

      // isShortToggleEnabled is false by default, so upstream's *long* press is
      // the one that would write an entry without any popup at all.
      await tester.longPressAt(origin + const Offset(10, 30));
      await tester.pumpAndSettle();

      expect(find.byType(CheckmarkDialog), findsNothing, reason: rule);
      expect(habit.originalEntries.getKnown(), isEmpty,
          reason: '$rule A long press must not reach '
              'CreateRepetitionCommand.');
      expect(habit.computedEntries.get(date).value, Entry.unknown,
          reason: rule);
    });

    testWidgets('#1 the Edit button still opens the editor, and that chart '
        'does get the presenter', (tester) async {
      await pumpScreen(tester);
      final model = modelOf(tester);

      await tester.tap(find.byKey(HistoryCardView.editButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryEditorDialog), findsOneWidget,
          reason: '$rule The Edit button is the only way in, and it must keep '
              'working.');
      expect(
        identical(HistoryEditorDialog.current!.chart!.onDateClickedListener,
            model.presenter.historyCardPresenter),
        isTrue,
        reason: '$rule Only that dialog\'s chart gets the presenter.',
      );
    });

    testWidgets('show-habit.history-interaction#13 the one chart that does '
        'have the presenter buzzes first, on both presses', (tester) async {
      await pumpScreen(tester);
      final model = modelOf(tester);
      await tester.tap(find.byKey(HistoryCardView.editButtonKey));
      await tester.pumpAndSettle();
      final listener =
          HistoryEditorDialog.current!.chart!.onDateClickedListener;
      expect(identical(listener, model.presenter.historyCardPresenter), isTrue,
          reason: 'show-habit.history-interaction#13 — HistoryCardPresenter '
              'is itself the OnDateClickedListener.');

      // `Feedback.forTap` is the port of `showFeedback()`; on Android it is a
      // SystemSound.play(click) on SystemChannels.platform.
      platformCalls.clear();
      listener.onDateShortPress(getToday());
      await tester.pumpAndSettle();
      expect(platformCalls.first.method, 'SystemSound.play',
          reason: 'show-habit.history-interaction#13 — showFeedback() comes '
              'first, before the popup');
      expect(find.byType(CheckmarkDialog), findsOneWidget,
          reason: 'show-habit.history-interaction#13');
    });

    testWidgets('show-habit.history-interaction#13 a long press through the '
        'editor buzzes first as well', (tester) async {
      final habit = await pumpScreen(tester);
      await tester.tap(find.byKey(HistoryCardView.editButtonKey));
      await tester.pumpAndSettle();
      final listener =
          HistoryEditorDialog.current!.chart!.onDateClickedListener;

      platformCalls.clear();
      listener.onDateLongPress(getToday().minus(1));
      await tester.pumpAndSettle();

      expect(platformCalls.first.method, 'SystemSound.play',
          reason: 'show-habit.history-interaction#13 — showFeedback() comes '
              'first on a long press too, even though that one ends in a '
              'command rather than a popup');
      expect(habit.computedEntries.get(getToday().minus(1)).value,
          isNot(Entry.unknown),
          reason: 'show-habit.history-interaction#13 — and the press it '
              'precedes is the one that writes the entry');
    });
  });
}
