/// The app's one transient message.
///
/// Port target: `View.showMessage` / `Activity.showMessage` in
/// uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt:105-119.
/// Every user-visible message in the Android app goes through that single
/// function — the list screen's command toasts, the import/export/repair
/// results, the habit-detail archive/unarchive/export messages, "You are now a
/// developer" and `startActivitySafely`'s "No app was found to support this
/// action" — so all of them share one lifetime, one colour and one queue
/// discipline.
///
/// The colour half is asserted in test/ui/theme/snackbar_theme_test.dart
/// (`feedback.toasts-must-be-dark-with-white-text#1`); what is asserted here is
/// the lifetime and the replace-don't-queue behaviour that the port had decided
/// separately at each of five copied call sites
/// (`audit24.one-show-message-helper-one-lifetime#1`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/common/show_message.dart';

void main() {
  const String rule = 'audit24.one-show-message-helper-one-lifetime#1';

  /// A screen with a `ScaffoldMessenger`, i.e. `android.R.id.content`.
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext host;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          host = context;
          return const SizedBox.shrink();
        }),
      ),
    ));
    return host;
  }

  testWidgets('$rule Snackbar.LENGTH_SHORT is 1500 ms, not Flutter\'s 4000',
      (tester) async {
    final BuildContext host = await pumpHost(tester);

    showMessage(host, 'Habit archived');
    await tester.pump();

    expect(snackbarLengthShort, const Duration(milliseconds: 1500),
        reason: '$rule — LENGTH_SHORT is the sentinel -1, which '
            'SnackbarManager turns into SHORT_DURATION_MS = 1500 ms');
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        snackbarLengthShort,
        reason: '$rule — Snackbar.make(this, msg, Snackbar.LENGTH_SHORT)');
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).action, isNull,
        reason: '$rule — the helper never sets an action button');

    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('$rule the text is white, the way setTextColor(Color.WHITE) '
      'makes it', (tester) async {
    final BuildContext host = await pumpHost(tester);

    showMessage(host, 'Habit archived');
    await tester.pump();

    final Text content = tester.widget<Text>(find.descendant(
      of: find.byType(SnackBar),
      matching: find.text('Habit archived'),
    ));
    expect(content.style?.color, Colors.white,
        reason: '$rule — tv?.setTextColor(Color.WHITE), unconditionally and '
            'with no branch on the theme');

    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('$rule a second message replaces the first instead of queueing '
      'behind it', (tester) async {
    final BuildContext host = await pumpHost(tester);

    showMessage(host, 'Habit archived');
    await tester.pump();
    expect(find.text('Habit archived'), findsOneWidget, reason: rule);

    // `SnackbarManager` shows a new snackbar in place of the one on screen —
    // it never lets two lifetimes add up.
    showMessage(host, 'Habit unarchived');
    await tester.pumpAndSettle();

    expect(find.text('Habit unarchived'), findsOneWidget,
        reason: '$rule — the second message is on screen at once, because the '
            'first was hidden rather than left to time out');
    expect(find.text('Habit archived'), findsNothing,
        reason: '$rule — and the first is gone');
    expect(find.byType(SnackBar), findsOneWidget, reason: rule);

    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('$rule no suitable parent view drops the message in silence',
      (tester) async {
    // `catch (e: IllegalArgumentException) { return }`.
    late BuildContext hostless;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(builder: (context) {
        hostless = context;
        return const SizedBox.shrink();
      }),
    ));

    expect(ScaffoldMessenger.maybeOf(hostless), isNull, reason: rule);
    expect(() => showMessage(hostless, 'Habit archived'), returnsNormally,
        reason: '$rule — the IllegalArgumentException is swallowed');
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing, reason: rule);
  });
}
