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
