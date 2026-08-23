/// `audit8.the-overview-card-ignores-its-own`.
///
/// `res/layout/show_habit.xml` gives three of its cards an inline padding
/// override on top of `@style/Card`:
///
/// ```xml
/// <OverviewCardView style="@style/Card" android:paddingTop="12dp" />
/// <TargetCardView   style="@style/Card" android:paddingTop="12dp" />
/// <HistoryCardView  style="@style/Card" android:paddingBottom="0dp" />
/// ```
///
/// The port honours the last two — `TargetCardView` and `HistoryCardView` both
/// pass `ChartCard.cardPadding.copyWith(...)` — but the Overview card is built
/// through the shared `_Card`, whose padding is a fixed
/// `EdgeInsets.fromLTRB(16, 16, 4, 16)`, so its score ring sits 4dp lower than
/// upstream's.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/show_habit_model.dart' show ShowHabitCard;
import 'package:uhabits/ui/habits/show/cards/notes_card_view.dart';
import 'package:uhabits/ui/habits/show/cards/overview_card_view.dart';
import 'package:uhabits/ui/habits/show/cards/score_card_view.dart' show ChartCard;
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/uhabits_core.dart' hide Color, Theme;

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_overview_padding');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final database = AppDatabase.openAndMigrate('${tempDir.path}/habits.db');
    final scope = AppScope.open(database)..preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  Future<Habit> pump(WidgetTester tester, {required HabitType type}) async {
    final scope = openScope();
    final habit = scope.modelFactory.buildHabit()
      ..name = 'Meditate'
      ..description = 'every morning'
      ..type = type
      ..targetValue = type == HabitType.numerical ? 3.0 : 0.0
      ..unit = type == HabitType.numerical ? 'min' : '';
    scope.habitList.add(habit);
    habit.recompute();

    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: ShowHabitScreen(habit: habit),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return habit;
  }

  /// The gap between the card's own surface (the `Material` that paints
  /// `?cardBgColor`) and the first pixel of its content — i.e. the resolved
  /// `android:paddingTop`.
  double topPaddingOf(WidgetTester tester, ShowHabitCard card, Finder content) {
    final surface = find
        .descendant(
          of: find.byKey(ShowHabitScreen.cardKey(card)),
          matching: find.byType(Material),
        )
        .first;
    return tester.getTopLeft(content).dy - tester.getTopLeft(surface).dy;
  }

  group('audit8.the-overview-card-ignores-its-own', () {
    testWidgets('#1 the Overview card takes its 12dp paddingTop override',
        (tester) async {
      await pump(tester, type: HabitType.yesNo);

      expect(
        topPaddingOf(
          tester,
          ShowHabitCard.overview,
          find.byType(OverviewCardView),
        ),
        12.0,
        reason: 'audit8.the-overview-card-ignores-its-own#1 — '
            '<OverviewCardView style="@style/Card" '
            'android:paddingTop="12dp"/>: the score ring sits 4dp closer to '
            'the top edge than @style/CardCommon alone would put it',
      );
    });

    testWidgets('#1 the Notes card above it keeps the CardCommon 16dp',
        (tester) async {
      await pump(tester, type: HabitType.yesNo);

      expect(
        topPaddingOf(tester, ShowHabitCard.notes, find.byType(NotesCardView)),
        16.0,
        reason: 'audit8.the-overview-card-ignores-its-own#1 — the Notes card '
            'declares no override, so it keeps @style/CardCommon\'s 16dp; the '
            '4dp difference between the two is the whole finding',
      );
    });

    testWidgets('#1 the other three sides of the Overview card are untouched',
        (tester) async {
      await pump(tester, type: HabitType.yesNo);

      final surface = find
          .descendant(
            of: find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.overview)),
            matching: find.byType(Material),
          )
          .first;
      final surfaceBox = tester.getRect(surface);
      final contentBox = tester.getRect(find.byType(OverviewCardView));

      expect(
        contentBox.left - surfaceBox.left,
        16.0,
        reason: 'audit8.the-overview-card-ignores-its-own#1 — only paddingTop '
            'is overridden; paddingLeft stays @style/CardCommon\'s 16dp',
      );
      expect(
        surfaceBox.right - contentBox.right,
        4.0,
        reason: 'audit8.the-overview-card-ignores-its-own#1 — paddingRight '
            'stays 4dp',
      );
      expect(
        surfaceBox.bottom - contentBox.bottom,
        16.0,
        reason: 'audit8.the-overview-card-ignores-its-own#1 — paddingBottom '
            'stays 16dp',
      );
    });

    testWidgets('#1 the Target card, which carries the identical override, '
        'already honours it', (tester) async {
      await pump(tester, type: HabitType.numerical);

      final target = tester.widget<ChartCard>(
        find.descendant(
          of: find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.target)),
          matching: find.byType(ChartCard),
        ),
      );
      expect(
        target.padding,
        ChartCard.cardPadding.copyWith(top: 12),
        reason: 'audit8.the-overview-card-ignores-its-own#1 — the sibling that '
            'carries the same android:paddingTop="12dp" is the baseline the '
            'Overview card is measured against',
      );
    });
  });
}
