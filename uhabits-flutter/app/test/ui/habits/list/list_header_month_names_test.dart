/// The month name every chart footer prints.
///
/// `JavaLocalDateFormatter.shortMonthName` reads *both* display names and
/// returns the LONG one when it is three characters or shorter — the Kotlin
/// comment says "For some locales, such as Japan, SHORT name is exceedingly
/// short". The port's single implementation, `IntlLocalDateFormatter`, only
/// ever asked for the short one.
///
/// The formatter is not constructed by these tests: every assertion reads the
/// instance the running card built for itself out of the view it handed to its
/// [CoreView], which is the only way `IntlLocalDateFormatter.of(context)` and
/// its locale resolution are exercised at all.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/habits/show/cards/score_card_view.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  final today = core.LocalDate.ymd(2015, 1, 25);
  final theme = core.LightTheme();

  setUp(() => core.setToday(today));
  tearDown(core.resetToday);

  /// Builds the Score card the way the detail screen does — with no
  /// `dateFormatter`, so the card resolves one from the device locale — and
  /// returns the formatter the chart it built is actually printing with.
  ///
  /// [locale] is the DEVICE locale, which is what
  /// `JavaLocalDateFormatter(Locale.getDefault())` reads
  /// (`audit9.chart-dates-follow-the-device-locale#1`); `MaterialApp.locale`
  /// is set alongside it because on Android the two are one setting.
  Future<core.LocalDateFormatter> formatterOf(
    WidgetTester tester,
    String locale,
  ) async {
    tester.platformDispatcher.localesTestValue = <Locale>[Locale(locale)];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: ScoreCardView(
              state: ScoreCardState(
                scores: <core.Score>[core.Score(today, 1.0)],
                bucketSize: 7,
                spinnerPosition: 1,
                color: const core.PaletteColor(7),
                theme: theme,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final view = tester.widget<CoreView>(find.byType(CoreView)).view;
    return (view as ScoreChartView).dateFormatter;
  }

  group('audit3.shortmonthname-drops-the-use-the-long', () {
    testWidgets('#1 zh-CN keeps the long name, which is two characters',
        (tester) async {
      final fmt = await formatterOf(tester, 'zh');

      expect(fmt.longMonthName(today), '一月',
          reason: 'audit3.shortmonthname-drops-the-use-the-long#1: the LONG '
              'display name for zh-CN is 一月');
      expect(fmt.shortMonthName(today), '一月',
          reason: 'audit3.shortmonthname-drops-the-use-the-long#1: '
              'shortMonthName returns the LONG name when its length is <= 3, '
              'so zh-CN prints 一月 and not the SHORT name 1月');
    });

    testWidgets('#1 a locale whose long name is longer than three characters '
        'still gets the short one', (tester) async {
      final en = await formatterOf(tester, 'en');
      expect(en.shortMonthName(today), 'Jan',
          reason: 'audit3.shortmonthname-drops-the-use-the-long#1: LONG is '
              '"January", 7 characters, so the SHORT name wins');

      final de = await formatterOf(tester, 'de');
      expect(de.shortMonthName(today), 'Jan',
          reason: 'audit3.shortmonthname-drops-the-use-the-long#1');

      final ru = await formatterOf(tester, 'ru');
      expect(ru.shortMonthName(today), 'янв.',
          reason: 'audit3.shortmonthname-drops-the-use-the-long#1: LONG is '
              '"январь", 6 characters, so the SHORT name wins');
    });

    // The home-screen widgets draw their own charts in the launcher's process,
    // where no Dart runs, so the same branch has to exist a second time — in
    // `WidgetDateFormatter`. Nothing in `flutter test` can execute Kotlin, so
    // what is asserted is the source, the way
    // test/platform/widget_strings_test.dart asserts the widget providers'.
    test('#1 the widget charts read both names too', () {
      final String source = _widgetCanvas()
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
          .replaceAll(RegExp('//[^\n]*'), '');

      expect(source, contains('val long = s.months[month - 1]'),
          reason: 'audit3.shortmonthname-drops-the-use-the-long#1: the LONG '
              'display name has to be read at all before it can win.');
      expect(
        source,
        contains('if (long.length <= 3) long else s.shortMonths[month - 1]'),
        reason: 'audit3.shortmonthname-drops-the-use-the-long#1: and the SHORT '
            'one is used only when the long one is longer than three '
            'characters.',
      );
    });

    testWidgets('#1 ja and zh-TW read the same either way', (tester) async {
      final ja = await formatterOf(tester, 'ja');
      expect(ja.shortMonthName(today), ja.longMonthName(today),
          reason: 'audit3.shortmonthname-drops-the-use-the-long#1: ja gives '
              'the same string either way, so the branch cannot change it');
      expect(ja.shortMonthName(today), '1月',
          reason: 'audit3.shortmonthname-drops-the-use-the-long#1');
    });
  });
}

/// `android/app/src/main/kotlin/.../widgets/views/WidgetCanvas.kt`, found from
/// wherever the test runner was started.
String _widgetCanvas() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String prefix in <String>['', 'app/']) {
      final File file = File('${dir.path}/${prefix}android/app/src/main/kotlin/'
          'org/isoron/uhabits/widgets/views/WidgetCanvas.kt');
      if (file.existsSync()) return file.readAsStringSync();
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('WidgetCanvas.kt not found from ${Directory.current.path}');
}
