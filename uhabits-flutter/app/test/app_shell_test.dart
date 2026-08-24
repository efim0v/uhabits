import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/main.dart';

void main() {
  testWidgets('app boots and shows the localized habit list title',
      (tester) async {
    await tester.pumpWidget(const UhabitsApp());
    await tester.pumpAndSettle();
    expect(find.text('Habits'), findsOneWidget);
  });

  testWidgets('the habit list is inset by the window insets exactly once',
      (tester) async {
    const String rule =
        'audit22.habit-list-applies-the-root-window-inset-twice#1 — '
        'ListHabitsActivity.onCreate calls rootView.applyRootViewInsets() once, '
        'and no second view on the list screen pads by the same insets again.';

    // A landscape notch on the left and a navigation bar on the right, the
    // window shape test/ui/window_insets_test.dart uses. On the default 800x600
    // harness surface every inset is zero, which is what let one rule live in
    // two hosts unnoticed.
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(
          size: Size(800, 600),
          padding: EdgeInsets.only(left: 44, top: 24, right: 12, bottom: 48),
          viewPadding:
              EdgeInsets.only(left: 44, top: 24, right: 12, bottom: 48),
        ),
        child: UhabitsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Habits'), findsOneWidget, reason: rule);
    final Rect scaffold = tester.getRect(find.byType(Scaffold).first);
    expect(scaffold.left, 44.0, reason: rule);
    expect(800.0 - scaffold.right, 12.0, reason: rule);
  });

  testWidgets('localization resolves for a non-English locale', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ru'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: _TitleProbe(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Привычки'), findsOneWidget);
  });
}

class _TitleProbe extends StatelessWidget {
  const _TitleProbe();

  @override
  Widget build(BuildContext context) =>
      Text(L10n.of(context).mainActivityTitle, textDirection: TextDirection.ltr);
}
