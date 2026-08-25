import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/habits/sleep/suggestion_card.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

Future<void> pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      L10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: L10n.supportedLocales,
    builder: (BuildContext context, Widget? widget) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: widget!,
    ),
    home: Scaffold(body: child),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('a suggestion', () {
    testWidgets('offers both an action and a way out', (tester) async {
      var applied = 0;
      var dismissed = 0;
      await pump(
        tester,
        SuggestionCard(
          theme: core.LightTheme(),
          message: 'Your time zone changed.',
          applyLabel: 'Mark',
          onApply: () => applied++,
          onDismiss: () => dismissed++,
        ),
      );

      expect(find.text('Your time zone changed.'), findsOneWidget,
          reason: 'sleep.skip#5');
      expect(find.text('Not now'), findsOneWidget, reason: 'sleep.skip#5');

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(dismissed, 1, reason: 'sleep.skip#5');
      expect(applied, 0, reason: 'sleep.skip#5');

      await tester.tap(find.text('Mark'));
      await tester.pumpAndSettle();
      expect(applied, 1, reason: 'sleep.skip#5');
    });

    testWidgets('does nothing until it is acted on', (tester) async {
      // Building the card must not be the same thing as accepting it: the
      // whole guarantee is that the app proposes and the person decides.
      var applied = 0;
      await pump(
        tester,
        SuggestionCard(
          theme: core.LightTheme(),
          message: 'Move the goal?',
          applyLabel: 'Move',
          onApply: () => applied++,
          onDismiss: () {},
        ),
      );
      expect(applied, 0, reason: 'sleep.suggest-goal#4');
    });
  });

  group('the wording of a goal suggestion', () {
    testWidgets('names the bedtime it found', (tester) async {
      late String message;
      await pump(
        tester,
        Builder(builder: (BuildContext context) {
          message = goalSuggestionMessage(
            context,
            const core.GoalSuggestion(
              bedMinutes: 1420,
              wakeMinutes: null,
              nightsConsidered: 14,
            ),
          );
          return const SizedBox.shrink();
        }),
      );
      expect(message, contains('23:40'), reason: 'sleep.suggest-goal#2');
      expect(message, contains('bed'), reason: 'sleep.suggest-goal#2');
    });

    testWidgets('names the wake time when that is the half that moved',
        (tester) async {
      late String message;
      await pump(
        tester,
        Builder(builder: (BuildContext context) {
          message = goalSuggestionMessage(
            context,
            const core.GoalSuggestion(
              bedMinutes: null,
              wakeMinutes: 480,
              nightsConsidered: 14,
            ),
          );
          return const SizedBox.shrink();
        }),
      );
      expect(message, contains('08:00'), reason: 'sleep.suggest-goal#2');
      expect(message, contains('up'), reason: 'sleep.suggest-goal#2');
    });
  });
}
