// The core drawing vocabulary wins over Flutter's: Canvas, Color, TextAlign
// and Image below are the ones the ported views speak.
import 'package:flutter/material.dart' hide Canvas, Color, Image, TextAlign;
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/habits/list/list_header.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// Widget tests for the date strip above the habit list.
///
/// The strip is drawn by the core `HabitListHeader`, so what the golden images
/// under uhabits-android/src/androidTest/assets/views/habits/list/HeaderView/
/// show — one 48dp column per button, right-aligned, the weekday name above
/// the day number — is asserted here by replaying the hosted core `View` onto
/// [_RecordingCanvas] and reading the call trace back. Colour, font, size and
/// alignment are sticky on a `Canvas`, so the state each call was made under
/// is exactly what a golden would show.
void main() {
  // The date the Android goldens were captured on: Sunday, 25 January 2015.
  final today = LocalDate.ymd(2015, 1, 25);

  setUp(() => setToday(today));
  tearDown(resetToday);

  group('list-habits.header-dates', () {
    testWidgets('#1 #10 a 48dp strip, as wide as the space it is given',
        (tester) async {
      await _pumpHeader(tester, buttonCount: 5);

      expect(tester.getSize(find.byType(ListHeader)), const Size(600, 48),
          reason: 'list-habits.header-dates#10');
      expect(LightTheme().checkmarkButtonSize, 48.0,
          reason: 'list-habits.header-dates#1');
    });

    testWidgets('#1 headerBackgroundColor behind, hairline along the bottom',
        (tester) async {
      await _pumpHeader(tester, buttonCount: 5);
      final canvas = _draw(tester);
      final theme = LightTheme();

      final background = canvas.ops.first;
      expect(background.name, 'fillRect',
          reason: 'list-habits.header-dates#1');
      expect(background.args, [0.0, 0.0, 600.0, 48.0],
          reason: 'list-habits.header-dates#1');
      expect(background.color, theme.headerBackgroundColor,
          reason: 'list-habits.header-dates#1');

      final line = canvas.opsNamed('drawLine').single;
      expect(line.args, [0.0, 47.5, 600.0, 47.5],
          reason: 'list-habits.header-dates#1');
      expect(line.color, theme.headerBorderColor,
          reason: 'list-habits.header-dates#1');
    });

    testWidgets('#1 the background follows the ambient brightness',
        (tester) async {
      await _pumpHeader(tester, buttonCount: 5, brightness: Brightness.dark);

      expect(_draw(tester).ops.first.color, DarkTheme().headerBackgroundColor,
          reason: 'list-habits.header-dates#1');
      expect(DarkTheme().headerBackgroundColor,
          isNot(LightTheme().headerBackgroundColor),
          reason: 'list-habits.header-dates#1');
    });

    testWidgets('#2 #3 one column per button, today leftmost, dates going back',
        (tester) async {
      await _pumpHeader(tester, buttonCount: 5);
      final canvas = _draw(tester);

      expect(canvas.texts, [
        'WED', '21', //
        'THU', '22', //
        'FRI', '23', //
        'SAT', '24', //
        'SUN', '25', //
      ], reason: 'list-habits.header-dates#2');

      // Five columns of 48dp flush against the right edge; today (SUN 25) is
      // the leftmost of them and the dates walk backwards to the right.
      expect(canvas.columnCentres, {
        'SUN': 384.0,
        'SAT': 432.0,
        'FRI': 480.0,
        'THU': 528.0,
        'WED': 576.0,
      }, reason: 'list-habits.header-dates#3');

      // Both lines of a column share the column centre.
      expect(canvas.xOf('25'), 384.0, reason: 'list-habits.header-dates#3');
      expect(canvas.xOf('21'), 576.0, reason: 'list-habits.header-dates#3');
    });

    testWidgets('#2 buttonCount 0 draws no columns at all', (tester) async {
      await _pumpHeader(tester, buttonCount: 0);

      expect(_draw(tester).texts, isEmpty,
          reason: 'list-habits.header-dates#2');
    });

    testWidgets('#2 dataOffset scrolls the columns into the past',
        (tester) async {
      await _pumpHeader(tester, buttonCount: 5, dataOffset: 2);
      final canvas = _draw(tester);

      // Column i shows today.minus(i + dataOffset): the newest column is now
      // FRI 23, still leftmost.
      expect(canvas.texts, [
        'MON', '19', //
        'TUE', '20', //
        'WED', '21', //
        'THU', '22', //
        'FRI', '23', //
      ], reason: 'list-habits.header-dates#2');
      expect(canvas.xOf('FRI'), 384.0, reason: 'list-habits.header-dates#2');
      expect(canvas.xOf('MON'), 576.0, reason: 'list-habits.header-dates#2');
    });

    testWidgets('#4 a reversed checkmark sequence puts today rightmost',
        (tester) async {
      await _pumpHeader(tester, buttonCount: 5, reversed: true);
      final canvas = _draw(tester);

      expect(canvas.texts, [
        'WED', '21', //
        'THU', '22', //
        'FRI', '23', //
        'SAT', '24', //
        'SUN', '25', //
      ], reason: 'list-habits.header-dates#4');

      // The same five columns, in the same right-aligned band, with the order
      // inside it reversed: today is flush against the right edge and the dates
      // walk backwards to the left.
      expect(canvas.columnCentres, {
        'WED': 384.0,
        'THU': 432.0,
        'FRI': 480.0,
        'SAT': 528.0,
        'SUN': 576.0,
      }, reason: 'list-habits.header-dates#4');
      expect(canvas.xOf('25'), 576.0, reason: 'list-habits.header-dates#4');

      // Mirroring the strip does not disturb the background or the hairline:
      // both span the whole header, whichever way the columns run.
      expect(canvas.ops.first.args, [0.0, 0.0, 600.0, 48.0],
          reason: 'list-habits.header-dates#4');
      expect(canvas.opsNamed('drawLine').single.args, [0.0, 47.5, 600.0, 47.5],
          reason: 'list-habits.header-dates#4');
    });

    testWidgets(
        'settings.preferences.checkmark-reverse-order#7 — the two branches are '
        'the same band, measured from the right edge', (tester) async {
      const double w = 48.0; // R.dimen.checkmarkWidth
      const double canvasWidth = 600.0;
      const int buttonCount = 5;

      // `HeaderView.Drawer.draw` starts every column at the right edge and
      // offsets left: `(index - buttonCount) * width` in natural order,
      // `-(index + 1) * width` when reversed. Index 0 is today.
      double naturalLeftEdge(int index) =>
          canvasWidth + (index - buttonCount) * w;
      double reversedLeftEdge(int index) => canvasWidth - (index + 1) * w;

      // Column i shows today.minus(i): SUN 25, SAT 24, FRI 23, THU 22, WED 21.
      const List<String> byIndex = <String>['SUN', 'SAT', 'FRI', 'THU', 'WED'];

      await _pumpHeader(tester, buttonCount: buttonCount);
      final natural = _draw(tester).columnCentres;
      for (var i = 0; i < buttonCount; i++) {
        expect(
          natural[byIndex[i]],
          naturalLeftEdge(i) + w / 2,
          reason: 'settings.preferences.checkmark-reverse-order#7 — with '
              'reverse=false the rect for index $i is offset by '
              '(i - buttonCount) * checkmarkWidth from the right edge',
        );
      }

      await _pumpHeader(tester, buttonCount: buttonCount, reversed: true);
      final reversed = _draw(tester).columnCentres;
      for (var i = 0; i < buttonCount; i++) {
        expect(
          reversed[byIndex[i]],
          reversedLeftEdge(i) + w / 2,
          reason: 'settings.preferences.checkmark-reverse-order#7 — with '
              'reverse=true the rect for index $i is offset by '
              '-(i + 1) * checkmarkWidth from the right edge',
        );
      }

      // Both branches measure from the same right edge, so the strip occupies
      // the same band either way — the band the entry buttons of every habit
      // row sit in.
      expect(
        <double?>[natural['SUN'], natural['WED']],
        <double>[
          canvasWidth - buttonCount * w + w / 2,
          canvasWidth - w / 2,
        ],
        reason: 'settings.preferences.checkmark-reverse-order#7 — the natural '
            'order runs from (i - buttonCount) * checkmarkWidth up to the '
            'right edge',
      );
      expect(
        <double?>[reversed['SUN'], reversed['WED']],
        <double>[
          canvasWidth - w / 2,
          canvasWidth - buttonCount * w + w / 2,
        ],
        reason: 'settings.preferences.checkmark-reverse-order#7 — reversing '
            'swaps the ends of that same band rather than moving it: index 0 '
            'lands at -(0 + 1) * checkmarkWidth from the right edge',
      );
    });

    testWidgets('#6 #12 two centred bold lines at smallTextSize',
        (tester) async {
      await _pumpHeader(tester, buttonCount: 5);
      final canvas = _draw(tester);
      final theme = LightTheme();

      for (final op in canvas.opsNamed('drawText')) {
        expect(op.font, Font.bold, reason: 'list-habits.header-dates#12');
        expect(op.fontSize, theme.smallTextSize,
            reason: 'list-habits.header-dates#12');
        expect(op.fontSize, 10.0, reason: 'list-habits.header-dates#12');
        expect(op.color, theme.headerTextColor,
            reason: 'list-habits.header-dates#12');
        expect(op.textAlign, TextAlign.center,
            reason: 'list-habits.header-dates#12');
      }

      // Weekday name above, day number below.
      final weekday = canvas.opsNamed('drawText')[8];
      final number = canvas.opsNamed('drawText')[9];
      expect([weekday.text, number.text], ['SUN', '25'],
          reason: 'list-habits.header-dates#6');
      expect(weekday.args[1], lessThan(24.0),
          reason: 'list-habits.header-dates#6');
      expect(number.args[1], greaterThan(24.0),
          reason: 'list-habits.header-dates#6');
    });

    testWidgets('#7 the two baselines are -0.25 em and +1.25 em from the '
        'column centre', (tester) async {
      const rule = 'list-habits.header-dates#7';
      await _pumpHeader(tester, buttonCount: 5);
      final canvas = _draw(tester);

      // `val em = paint.measureText("m")`, under the header's own paint: bold,
      // at the tinyTextSize dimension. The recording canvas returns
      // 0.6 * fontSize per character, so one "m" at 10sp is 6.0.
      final em = canvas.measureText('m');
      expect(em, 6.0,
          reason: '$rule — em is measureText("m") at the header text size, a '
              'width rather than a line height');

      // `rect.set(0f, 0f, width, height)` is only ever offset horizontally, so
      // every column's centreY is the strip's own centre.
      const centerY = 48.0 / 2;

      final texts = canvas.opsNamed('drawText');
      expect(texts.length, 10, reason: '$rule — two lines per column');
      for (var column = 0; column < 5; column++) {
        final weekday = texts[column * 2];
        final number = texts[column * 2 + 1];
        expect(weekday.args[1], closeTo(centerY - 0.25 * em, 1e-9),
            reason: '$rule — the weekday baseline is rectCenterY - 0.25 * em');
        expect(number.args[1], closeTo(centerY + 1.25 * em, 1e-9),
            reason: '$rule — the day number baseline is rectCenterY + '
                '1.25 * em');
      }

      // The pair is deliberately asymmetric: 1.5 em apart, and their midpoint
      // sits half an em *below* the centre rather than on it.
      expect(texts[1].args[1] - texts[0].args[1], closeTo(1.5 * em, 1e-9),
          reason: '$rule — 1.25 em - (-0.25 em) = 1.5 em between the two '
              'baselines');
      expect((texts[0].args[1] + texts[1].args[1]) / 2,
          closeTo(centerY + 0.5 * em, 1e-9),
          reason: '$rule — which is not centred on rectCenterY');

      // And they track the em, not the nominal text size: a header drawn under
      // a wider font pushes both lines out proportionally.
      expect(texts[0].args[1], lessThan(centerY),
          reason: '$rule — the weekday name is above the centre');
      expect(texts[1].args[1], greaterThan(centerY),
          reason: '$rule — and the day number below it');
    });

    testWidgets('#6 the day of month carries no leading zero', (tester) async {
      await _pumpHeader(
        tester,
        buttonCount: 1,
        headerToday: LocalDate.ymd(2015, 1, 3),
      );

      expect(_draw(tester).texts, ['SAT', '3'],
          reason: 'list-habits.header-dates#6');
    });

    testWidgets('#6 weekday names come from the device locale',
        (tester) async {
      await _pumpHeader(tester, buttonCount: 1, locale: const Locale('fr'));

      // French short weekday for Sunday, uppercased by the core view.
      expect(_draw(tester).texts.first, startsWith('DIM'),
          reason: 'list-habits.header-dates#6');
    });

    testWidgets('#8 today is a parameter, so a midnight tick repaints',
        (tester) async {
      await _pumpHeader(tester, buttonCount: 1, headerToday: today);
      expect(_draw(tester).texts, ['SUN', '25'],
          reason: 'list-habits.header-dates#8');

      await _pumpHeader(tester, buttonCount: 1, headerToday: today.plus(1));
      expect(_draw(tester).texts, ['MON', '26'],
          reason: 'list-habits.header-dates#8');
    });

    testWidgets('#8 without one it falls back to the global today',
        (tester) async {
      setToday(LocalDate.ymd(2015, 1, 26));
      await _pumpHeader(tester, buttonCount: 1);

      expect(_draw(tester).texts, ['MON', '26'],
          reason: 'list-habits.header-dates#8');
    });
  });

  group('list-habits.header-scrolling', () {
    testWidgets('#1 #2 dragging reports whole columns, never pixels',
        (tester) async {
      final reported = <int>[];
      await _pumpHeader(tester, buttonCount: 5, reported: reported);

      // Half a column: not yet a new offset.
      await _dragBy(tester, -24);
      expect(reported, isEmpty, reason: 'list-habits.header-scrolling#2');

      // Crossing the 48dp bucket boundary reports exactly one column.
      await _dragBy(tester, -24);
      expect(reported, [1], reason: 'list-habits.header-scrolling#2');

      await _dragBy(tester, -48);
      await _dragBy(tester, -48);
      expect(reported, [1, 2, 3], reason: 'list-habits.header-scrolling#2');
    });

    testWidgets('#1 #7 the strip does not move until the parent feeds it back',
        (tester) async {
      final reported = <int>[];
      await _pumpHeader(
        tester,
        buttonCount: 5,
        reported: reported,
        applyOffset: false,
      );

      await _dragBy(tester, -60);
      await tester.pump();

      expect(reported, [1], reason: 'list-habits.header-scrolling#1');
      expect(_draw(tester).texts.last, '25',
          reason: 'list-habits.header-scrolling#1');
    });

    testWidgets('#1 fed back, the columns follow the offset', (tester) async {
      final reported = <int>[];
      await _pumpHeader(
        tester,
        buttonCount: 5,
        reported: reported,
        applyOffset: true,
      );

      await _dragBy(tester, -60);
      await tester.pump();

      expect(reported, [1], reason: 'list-habits.header-scrolling#1');
      expect(_draw(tester).texts, [
        'TUE', '20', //
        'WED', '21', //
        'THU', '22', //
        'FRI', '23', //
        'SAT', '24', //
      ], reason: 'list-habits.header-scrolling#1');
    });

    testWidgets('#7 an offset is reported only when it actually changes',
        (tester) async {
      final reported = <int>[];
      await _pumpHeader(tester, buttonCount: 5, reported: reported);

      await _dragBy(tester, -60);
      await _dragBy(tester, -10);
      await _dragBy(tester, 10);

      expect(reported, [1], reason: 'list-habits.header-scrolling#7');
    });

    testWidgets('#2 the future is out of reach: the offset never goes below 0',
        (tester) async {
      final reported = <int>[];
      await _pumpHeader(tester, buttonCount: 5, reported: reported);

      await _dragBy(tester, 480);
      expect(reported, isEmpty, reason: 'list-habits.header-scrolling#2');

      // And the scroller did not build up any debt on the way.
      await _dragBy(tester, -48);
      expect(reported, [1], reason: 'list-habits.header-scrolling#2');
    });

    testWidgets('#3 maxDataOffset defaults to max(60 - buttonCount, 0)',
        (tester) async {
      await _pumpHeader(tester, buttonCount: 5);
      expect(
        tester.widget<ListHeader>(find.byType(ListHeader)).effectiveMaxDataOffset,
        55,
        reason: 'list-habits.header-scrolling#3',
      );

      await _pumpHeader(tester, buttonCount: 70);
      expect(
        tester.widget<ListHeader>(find.byType(ListHeader)).effectiveMaxDataOffset,
        0,
        reason: 'list-habits.header-scrolling#3',
      );
    });

    testWidgets('#3 the drag stops at maxDataOffset', (tester) async {
      final reported = <int>[];
      await _pumpHeader(
        tester,
        buttonCount: 5,
        maxDataOffset: 2,
        reported: reported,
        applyOffset: true,
      );

      // Ten columns' worth of travel in one event stops at the second column.
      await _dragBy(tester, -480);
      expect(reported, [2], reason: 'list-habits.header-scrolling#3');

      // Coming back is immediate: nothing accumulated past the limit.
      await _dragBy(tester, -480);
      await _dragBy(tester, 48);
      expect(reported, [2, 1], reason: 'list-habits.header-scrolling#3');
    });

    testWidgets('#2 the bucket is one checkmark button wide', (tester) async {
      expect(ListHeader.columnWidth, LightTheme().checkmarkButtonSize,
          reason: 'list-habits.header-scrolling#2');
      expect(ListHeader.columnWidth, 48.0,
          reason: 'list-habits.header-scrolling#2');
    });

    testWidgets('#3 a smaller maxDataOffset clamps the offset and says so',
        (tester) async {
      final reported = <int>[];
      await _pumpHeader(
        tester,
        buttonCount: 5,
        dataOffset: 5,
        maxDataOffset: 5,
        reported: reported,
        applyOffset: true,
      );
      expect(reported, isEmpty, reason: 'list-habits.header-scrolling#3');

      // The screen got wider, fits more columns, and can no longer reach as
      // far back: the header reports the clamped offset it now shows.
      await _pumpHeader(
        tester,
        buttonCount: 5,
        dataOffset: 5,
        maxDataOffset: 2,
        reported: reported,
        applyOffset: true,
      );

      expect(reported, [2], reason: 'list-habits.header-scrolling#3');
      expect(_draw(tester).texts.last, '23',
          reason: 'list-habits.header-scrolling#3');
    });

    testWidgets('#4 a reversed sequence reverses the drag direction',
        (tester) async {
      final reported = <int>[];
      await _pumpHeader(
        tester,
        buttonCount: 5,
        reversed: true,
        reported: reported,
      );

      await _dragBy(tester, -60);
      expect(reported, isEmpty,
          reason: 'list-habits.header-scrolling#4 and '
              'settings.preferences.checkmark-reverse-order#6 — '
              'HeaderView.updateScrollDirection starts at -1 and multiplies '
              'by -1 when isCheckmarkSequenceReversed, so a reversed strip '
              'scrolls the other way. (The further RTL flip is not ported: '
              'the core view always lays its columns out left to right — see '
              'platform-glue.rtl-layout.)');

      await _dragBy(tester, 60);
      expect(reported, [1],
          reason: 'list-habits.header-scrolling#4 and '
              'settings.preferences.checkmark-reverse-order#6 — direction +1');
    });

    testWidgets(
        'settings.preferences.checkmark-reverse-order#6 — the natural order '
        'scrolls in the opposite direction', (tester) async {
      final reported = <int>[];
      await _pumpHeader(tester, buttonCount: 5, reported: reported);

      await _dragBy(tester, 60);
      expect(reported, isEmpty,
          reason: 'settings.preferences.checkmark-reverse-order#6 — with the '
              'flag false the direction is the bare -1');

      await _dragBy(tester, -60);
      expect(reported, [1],
          reason: 'settings.preferences.checkmark-reverse-order#6 — so the '
              'same gesture that scrolled a reversed strip does nothing here, '
              'and its opposite scrolls');
    });

    testWidgets('dates#9 the bucket is one 48dp column over the header colour',
        (tester) async {
      // `ScrollableChart.setScrollerBucketSize(checkmarkWidth)` plus
      // `setBackgroundColor(headerBackgroundColor)`. The third clause of the
      // rule — `elevation = dp(2f)` — is an Android shadow the Flutter strip
      // does not draw; it has no Material wrapper at all.
      await _pumpHeader(tester, buttonCount: 5);

      expect(ListHeader.columnWidth, LightTheme().checkmarkButtonSize,
          reason: 'list-habits.header-dates#9');
      expect(ListHeader.columnWidth, 48.0,
          reason: 'list-habits.header-dates#9');
      expect(_draw(tester).ops.first.color, LightTheme().headerBackgroundColor,
          reason: 'list-habits.header-dates#9');

      final reported = <int>[];
      await _pumpHeader(tester, buttonCount: 5, reported: reported);
      await _dragBy(tester, -47);
      expect(reported, isEmpty, reason: 'list-habits.header-dates#9');
      await _dragBy(tester, -1);
      expect(reported, [1], reason: 'list-habits.header-dates#9');
    });

    testWidgets('dates#11 the direction starts at -1 and the reversed '
        'sequence flips it', (tester) async {
      // `updateScrollDirection()`: `var direction = -1; if (reversed)
      // direction *= -1; if (isRTL) direction *= -1`. The RTL factor is not
      // ported — the core strip always lays its columns out left to right.
      final forward = <int>[];
      await _pumpHeader(tester, buttonCount: 5, reported: forward);
      // Dragging left (negative dx) walks into the past when direction is -1.
      await _dragBy(tester, -60);
      expect(forward, [1], reason: 'list-habits.header-dates#11');
      await _dragBy(tester, 60);
      expect(forward, [1, 0], reason: 'list-habits.header-dates#11');

      final reversed = <int>[];
      await _pumpHeader(
        tester,
        buttonCount: 5,
        reversed: true,
        reported: reversed,
      );
      await _dragBy(tester, -60);
      expect(reversed, isEmpty, reason: 'list-habits.header-dates#11');
      await _dragBy(tester, 60);
      expect(reversed, [1], reason: 'list-habits.header-dates#11');
    });

    testWidgets('#5 a drag is clamped to maxX and does not scroll the list '
        'behind it', (tester) async {
      final reported = <int>[];
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var offset = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) => Column(
              children: <Widget>[
                ListHeader(
                  buttonCount: 5,
                  dataOffset: offset,
                  maxDataOffset: 3,
                  onDataOffsetChanged: (value) {
                    reported.add(value);
                    setState(() => offset = value);
                  },
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: 60,
                    itemBuilder: (context, index) =>
                        SizedBox(height: 50, child: Text('row $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Far past the end of the scrollable range: the offset stops at
      // maxDataOffset and no debt accumulates behind it.
      await _dragBy(tester, -960);
      expect(reported, [3], reason: 'list-habits.header-scrolling#5');
      await _dragBy(tester, 48);
      expect(reported, [3, 2], reason: 'list-habits.header-scrolling#5');

      // The horizontal recogniser owns the gesture, so the vertical list
      // behind the strip never moved (requestDisallowInterceptTouchEvent).
      expect(controller.offset, 0.0,
          reason: 'list-habits.header-scrolling#5');
    });
  });

  group('IntlLocalDateFormatter', () {
    test('falls back to en_US when the locale has no data', () {
      expect(IntlLocalDateFormatter('xx_YY').localeName, 'en_US');
      expect(IntlLocalDateFormatter().localeName, 'en_US');
    });

    test('names the weekdays and months of a date', () {
      final fmt = IntlLocalDateFormatter('en_US');

      expect(fmt.shortWeekdayName(LocalDate.ymd(2015, 1, 25)), 'Sun');
      expect(fmt.shortWeekdayNameOf(DayOfWeek.wednesday), 'Wed');
      expect(fmt.longWeekdayNameOf(DayOfWeek.wednesday), 'Wednesday');
      expect(fmt.shortMonthName(LocalDate.ymd(2015, 1, 25)), 'Jan');
      expect(fmt.longMonthName(LocalDate.ymd(2015, 1, 25)), 'January');
    });

    test('every weekday maps to the day the core model says it is', () {
      final fmt = IntlLocalDateFormatter('en_US');
      final names = <String>[
        for (final day in DayOfWeek.values) fmt.shortWeekdayNameOf(day),
      ];

      expect(names,
          ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']);
    });

    test('platform-glue.time-and-date-formatting#2 — the four names are '
        'skeletons the locale resolves, not patterns', () {
      // `String.toSimpleDataFormat()` hands its receiver to
      // `DateFormat.getBestDateTimePattern(locale, skeleton)`; intl's named
      // DateFormat constructors are the same ICU skeleton API, so 'E', 'EEEE',
      // 'MMM' and 'MMMM' are resolved per locale rather than printed verbatim.
      final en = IntlLocalDateFormatter('en_US');
      final es = IntlLocalDateFormatter('es');
      final date = LocalDate.ymd(2015, 1, 25);

      expect(en.shortMonthName(date), 'Jan',
          reason: 'platform-glue.time-and-date-formatting#2 — '
              'String.toSimpleDataFormat() treats the receiver as a skeleton, '
              'resolves it with DateFormat.getBestDateTimePattern('
              'Locale.getDefault(), skeleton) and returns '
              'DateFormats.fromSkeleton(pattern, locale).');
      expect(es.shortMonthName(date), isNot('Jan'),
          reason: 'platform-glue.time-and-date-formatting#2: the same skeleton '
              'resolves differently per locale, which is the whole point of '
              'resolving rather than formatting');
      expect(es.longMonthName(date), 'enero',
          reason: 'platform-glue.time-and-date-formatting#2: and the resolved '
              'name is the locale\'s');
      expect(es.longWeekdayNameOf(DayOfWeek.wednesday), 'miércoles',
          reason: 'platform-glue.time-and-date-formatting#2');

      // A locale with no data falls back rather than emitting the skeleton
      // itself, the way getBestDateTimePattern falls back to the root locale.
      expect(IntlLocalDateFormatter('xx_YY').shortMonthName(date), 'Jan',
          reason: 'platform-glue.time-and-date-formatting#2: an unknown locale '
              'still yields a resolved name, never the skeleton');
    });
  });

  group('list-habits.header-scrolling, revisited', () {
    testWidgets('#6 a fling keeps scrolling after the finger leaves',
        (tester) async {
      // A slow drag of 96 px is exactly two columns.
      final dragged = <int>[];
      await _pumpHeader(
        tester,
        buttonCount: 5,
        reported: dragged,
        applyOffset: true,
      );
      await _dragBy(tester, -96);
      await tester.pumpAndSettle();
      expect(dragged.last, 2, reason: 'list-habits.header-scrolling#6');

      // The same 96 px thrown rather than dragged goes further: `onFling`
      // hands the scroller `direction * velocityX / 2` and animates for as
      // long as the scroller says.
      final flung = <int>[];
      await _pumpHeader(
        tester,
        buttonCount: 5,
        reported: flung,
        applyOffset: true,
      );
      await tester.fling(find.byType(ListHeader), const Offset(-96, 0), 2000);
      await tester.pumpAndSettle();

      expect(flung.last, greaterThan(dragged.last),
          reason: 'list-habits.header-scrolling#6 — the fling carried the '
              'scroller past where the finger let go');
      // …and it never leaves the scrollable range: `fling(…, 0, maxX, 0, 0)`.
      expect(flung.last, lessThanOrEqualTo(60 - 5),
          reason: 'list-habits.header-scrolling#6');
      expect(flung.every((offset) => offset >= 0), isTrue,
          reason: 'list-habits.header-scrolling#6');
    });

    testWidgets('#6 a fling is bounded by maxX at both ends', (tester) async {
      // Towards the past, hard: the trajectory is constrained to x <= maxX,
      // which for two visible columns is column 58.
      final forwards = <int>[];
      await _pumpHeader(
        tester,
        buttonCount: 2,
        maxDataOffset: 3,
        reported: forwards,
        applyOffset: true,
      );
      await tester.fling(find.byType(ListHeader), const Offset(-600, 0), 8000);
      await tester.pumpAndSettle();
      expect(forwards.last, 3,
          reason: 'list-habits.header-scrolling#6 — x is constrained to '
              '[0, maxX]');

      // …and towards the future it stops at column 0 rather than going
      // negative.
      final backwards = <int>[];
      await _pumpHeader(
        tester,
        buttonCount: 5,
        dataOffset: 3,
        reported: backwards,
        applyOffset: true,
      );
      await tester.fling(find.byType(ListHeader), const Offset(600, 0), 8000);
      await tester.pumpAndSettle();
      expect(backwards.last, 0, reason: 'list-habits.header-scrolling#6');
      expect(backwards.every((offset) => offset >= 0), isTrue,
          reason: 'list-habits.header-scrolling#6');
    });
  });

  group('list-habits.header-dates, right to left', () {
    testWidgets('#5 every column rect is mirrored about the canvas width',
        (tester) async {
      await _pumpHeader(tester, buttonCount: 5);
      final ltr = _draw(tester);
      await _pumpHeader(tester, buttonCount: 5,
          textDirection: TextDirection.rtl);
      final rtl = _draw(tester);

      // The same dates, in the same order…
      expect(rtl.texts, ltr.texts, reason: 'list-habits.header-dates#5');
      // …each one reflected about the canvas width.
      for (final text in ltr.texts) {
        expect(rtl.xOf(text), closeTo(600.0 - ltr.xOf(text), 1e-9),
            reason: 'list-habits.header-dates#5 — "$text"');
      }
      // Today is leftmost in an LTR layout and rightmost in an RTL one.
      expect(rtl.xOf('25'), greaterThan(rtl.xOf('21')),
          reason: 'list-habits.header-dates#5');
      expect(ltr.xOf('25'), lessThan(ltr.xOf('21')),
          reason: 'list-habits.header-dates#5');

      // The background and the hairline span the whole strip and do not move.
      expect(rtl.ops.first.args, ltr.ops.first.args,
          reason: 'list-habits.header-dates#5');
      expect(rtl.opsNamed('drawLine').single.args,
          ltr.opsNamed('drawLine').single.args,
          reason: 'list-habits.header-dates#5');
    });

    testWidgets('#5 a reversed sequence mirrors on top of the RTL mirror',
        (tester) async {
      await _pumpHeader(tester, buttonCount: 5, reversed: true);
      final ltr = _draw(tester);
      await _pumpHeader(tester, buttonCount: 5, reversed: true,
          textDirection: TextDirection.rtl);
      final rtl = _draw(tester);

      for (final text in ltr.texts) {
        expect(rtl.xOf(text), closeTo(600.0 - ltr.xOf(text), 1e-9),
            reason: 'list-habits.header-dates#5');
      }
      // Reversed *and* RTL puts today back on the left.
      expect(rtl.xOf('25'), lessThan(rtl.xOf('21')),
          reason: 'list-habits.header-dates#5');
    });

    testWidgets('#4 an RTL layout flips the scroll direction back',
        (tester) async {
      // direction starts at -1, the reversed sequence makes it +1, and RTL
      // makes it -1 again, so a leftward drag scrolls into the past exactly as
      // it does in a plain LTR layout.
      final reported = <int>[];
      await _pumpHeader(
        tester,
        buttonCount: 5,
        reversed: true,
        reported: reported,
        applyOffset: true,
        textDirection: TextDirection.rtl,
      );

      await _dragBy(tester, -96);
      await tester.pumpAndSettle();
      expect(reported.last, 2,
          reason: 'list-habits.header-scrolling#4 and '
              'list-habits.header-dates#11 — the two flips cancel out');
    });
  });

  group('audit10.canvas-drawn-text-stopped-following-the', () {
    const rule = 'audit10.canvas-drawn-text-stopped-following-the#1 — '
        '`HeaderView.Drawer`\'s paint is sized from '
        '`dim(R.dimen.tinyTextSize)`, and dimens.xml declares tinyTextSize as '
        '**10sp**. `Resources.getDimension` resolves a COMPLEX_UNIT_SP value '
        'against `scaledDensity` (density x fontScale), so the weekday names '
        'and day numbers of the date strip grow with the OS font-size '
        'setting, like every other sp text on the same screen.';

    testWidgets('#1 the two lines follow the OS text-scale setting',
        (tester) async {
      // Android's system font-size slider, two notches up.
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pumpHeader(tester, buttonCount: 5);
      final canvas = _draw(tester);

      final texts = canvas.opsNamed('drawText');
      expect(texts, hasLength(10), reason: rule);
      for (final op in texts) {
        expect(op.fontSize, 10.0 * 1.5, reason: rule);
      }
    });

    testWidgets('#1 the em the two baselines hang off is measured under the '
        'scaled paint', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pumpHeader(tester, buttonCount: 5);
      final canvas = _draw(tester);

      // `val em = paint.measureText("m")` is taken after the textSize
      // assignment, so `centerY - 0.25 * em` / `+ 1.25 * em` open up with the
      // glyphs instead of leaving them overlapping.
      final em = 0.6 * (10.0 * 1.5);
      const centerY = 48.0 / 2;
      final texts = canvas.opsNamed('drawText');
      expect(texts[0].args[1], closeTo(centerY - 0.25 * em, 1e-9),
          reason: rule);
      expect(texts[1].args[1], closeTo(centerY + 1.25 * em, 1e-9),
          reason: rule);
    });
  });
}

/// Pumps a [ListHeader] inside a 600dp-wide slot, the width the Android
/// goldens were captured at.
///
/// [reported] collects every offset the header pushes out; [applyOffset] makes
/// the host behave like the real screen and feed the value back in.
Future<void> _pumpHeader(
  WidgetTester tester, {
  required int buttonCount,
  int dataOffset = 0,
  bool reversed = false,
  int? maxDataOffset,
  LocalDate? headerToday,
  List<int>? reported,
  bool applyOffset = false,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  TextDirection textDirection = TextDirection.ltr,
  String? restorationId,
  String? restorationScopeId,
}) async {
  var offset = dataOffset;
  // `locale` is the DEVICE locale: `HeaderView` builds
  // `JavaLocalDateFormatter(Locale.getDefault())`, so the weekday names follow
  // the device rather than the locale the tree resolved
  // (`audit9.chart-dates-follow-the-device-locale#1`). `MaterialApp.locale` is
  // set alongside it because on Android the two are one setting.
  tester.platformDispatcher.localesTestValue = <Locale>[locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      restorationScopeId: restorationScopeId,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: ThemeData(brightness: brightness),
      home: Directionality(
        textDirection: textDirection,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: StatefulBuilder(
              builder: (context, setState) => ListHeader(
                restorationId: restorationId,
                buttonCount: buttonCount,
                dataOffset: offset,
                isCheckmarkSequenceReversed: reversed,
                maxDataOffset: maxDataOffset,
                today: headerToday,
                onDataOffsetChanged: (value) {
                  reported?.add(value);
                  if (applyOffset) setState(() => offset = value);
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Replays the hosted core view onto a recording canvas the size of the strip.
_RecordingCanvas _draw(WidgetTester tester) {
  final canvas = _RecordingCanvas(width: 600, height: 48);
  tester.widget<CoreView>(find.byType(CoreView)).view.draw(canvas);
  return canvas;
}

/// One horizontal drag of exactly [dx] logical pixels.
///
/// The first move only pays the touch slop: with the default
/// DragStartBehavior.start the recogniser swallows whatever it took to win the
/// arena, so the second move is the one the header sees.
Future<void> _dragBy(WidgetTester tester, double dx) async {
  final gesture =
      await tester.startGesture(tester.getCenter(find.byType(ListHeader)));
  await gesture.moveBy(Offset(dx.isNegative ? -20 : 20, 0));
  await gesture.moveBy(Offset(dx, 0));
  await gesture.up();
  await tester.pump();
}

class _Op {
  _Op(
    this.name,
    this.args, {
    this.text,
    required this.color,
    required this.font,
    required this.fontSize,
    required this.strokeWidth,
    required this.textAlign,
  });

  final String name;
  final List<double> args;
  final String? text;
  final Color color;
  final Font font;
  final double fontSize;
  final double strokeWidth;
  final TextAlign textAlign;

  @override
  String toString() => '$name(${text == null ? '' : '"$text", '}$args)';
}

/// A [Canvas] that logs every call together with the sticky paint state it was
/// made under.
class _RecordingCanvas extends Canvas {
  _RecordingCanvas({required this.width, required this.height});

  final double width;
  final double height;
  final List<_Op> ops = <_Op>[];

  Color _color = Color.BLACK;
  Font _font = Font.regular;
  double _fontSize = 12.0;
  double _strokeWidth = 1.0;
  TextAlign _textAlign = TextAlign.center;

  List<_Op> opsNamed(String name) =>
      ops.where((op) => op.name == name).toList();

  /// The text of every drawText call, in the order it was drawn.
  List<String> get texts =>
      opsNamed('drawText').map((op) => op.text!).toList();

  double xOf(String text) =>
      opsNamed('drawText').firstWhere((op) => op.text == text).args[0];

  /// Where each weekday label sits horizontally.
  Map<String, double> get columnCentres => <String, double>{
        for (final op in opsNamed('drawText'))
          if (double.tryParse(op.text!) == null) op.text!: op.args[0],
      };

  void _record(String name, List<double> args, {String? text}) {
    ops.add(_Op(
      name,
      args,
      text: text,
      color: _color,
      font: _font,
      fontSize: _fontSize,
      strokeWidth: _strokeWidth,
      textAlign: _textAlign,
    ));
  }

  @override
  double getWidth() => width;

  @override
  double getHeight() => height;

  @override
  void setColor(Color color) => _color = color;

  @override
  void setFont(Font font) => _font = font;

  @override
  void setFontSize(double size) => _fontSize = size;

  @override
  void setStrokeWidth(double size) => _strokeWidth = size;

  @override
  void setTextAlign(TextAlign align) => _textAlign = align;

  @override
  void drawLine(double x1, double y1, double x2, double y2) =>
      _record('drawLine', [x1, y1, x2, y2]);

  @override
  void drawText(String text, double x, double y) =>
      _record('drawText', [x, y], text: text);

  @override
  void fillRect(double x, double y, double w, double h) =>
      _record('fillRect', [x, y, w, h]);

  @override
  void drawRect(double x, double y, double w, double h) =>
      _record('drawRect', [x, y, w, h]);

  @override
  void fillRoundRect(double x, double y, double w, double h, double radius) =>
      _record('fillRoundRect', [x, y, w, h, radius]);

  @override
  void fillCircle(double cx, double cy, double radius) =>
      _record('fillCircle', [cx, cy, radius]);

  @override
  void fillArc(
    double cx,
    double cy,
    double radius,
    double startAngle,
    double swipeAngle,
  ) =>
      _record('fillArc', [cx, cy, radius, startAngle, swipeAngle]);

  @override
  double measureText(String text) => text.length * _fontSize * 0.6;

  @override
  Image toImage() => throw UnsupportedError('not recorded');
}
