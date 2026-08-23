import 'package:test/test.dart';
import 'package:uhabits_core/src/gui/canvas.dart';
import 'package:uhabits_core/src/gui/color.dart';
import 'package:uhabits_core/src/gui/font_awesome.dart';
import 'package:uhabits_core/src/gui/image.dart';
import 'package:uhabits_core/src/gui/theme.dart';
import 'package:uhabits_core/src/gui/view.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/views/checkmark_button.dart';
import 'package:uhabits_core/src/ui/views/habit_list_header.dart';
import 'package:uhabits_core/src/ui/views/number_button.dart';

/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/CheckmarkButton.kt,
/// .../NumberButton.kt, .../HabitListHeader.kt and
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/NumberButtonView.kt
/// (whose `toShortString` duplicate is exercised by
/// uhabits-android/src/androidTest/java/org/isoron/uhabits/activities/habits/list/views/NumberButtonViewTest.kt).
///
/// These three views own no state: every pixel is a function of the
/// constructor arguments and of the canvas size. The tests therefore drive
/// them against [RecordingCanvas], a fake backend defined at the bottom of
/// this file which logs every call together with the paint state it was made
/// under. Colour, font, font size, stroke width and text alignment are sticky
/// on a [Canvas], so "what state was this drawText made under" is exactly what
/// the goldens would show.
void main() {
  group('charts-canvas-theming.checkmark-button-core', () {
    test('#1 stateless View drawn entirely from its constructor arguments', () {
      final theme = LightTheme();
      final button = CheckmarkButton(2, Color.RED, theme);

      expect(button, isA<View>(),
          reason: 'charts-canvas-theming.checkmark-button-core#1');

      // Drawing the same instance twice produces the identical call trace:
      // nothing is memoised, mutated or carried over between draws.
      final canvas = RecordingCanvas(width: 48.0, height: 48.0);
      button.draw(canvas);
      final firstTrace = canvas.drawTrace;
      canvas.ops.clear();
      button.draw(canvas);
      expect(canvas.drawTrace, firstTrace,
          reason: 'charts-canvas-theming.checkmark-button-core#1');

      // A second instance built from equal arguments draws identically…
      String traceOf(CheckmarkButton button, {double size = 48.0}) {
        final canvas = RecordingCanvas(width: size, height: size);
        button.draw(canvas);
        return canvas.drawTrace;
      }

      expect(traceOf(CheckmarkButton(2, Color.RED, theme)), firstTrace,
          reason: 'charts-canvas-theming.checkmark-button-core#1');

      // …and every constructor argument, plus the canvas size, is
      // load-bearing: there is no other input.
      expect(traceOf(CheckmarkButton(0, Color.RED, theme)), isNot(firstTrace),
          reason: 'charts-canvas-theming.checkmark-button-core#1');
      expect(traceOf(CheckmarkButton(2, Color.BLUE, theme)), isNot(firstTrace),
          reason: 'charts-canvas-theming.checkmark-button-core#1');
      expect(traceOf(CheckmarkButton(2, Color.RED, theme), size: 96.0),
          isNot(firstTrace),
          reason: 'charts-canvas-theming.checkmark-button-core#1');
      expect(traceOf(CheckmarkButton(1, Color.RED, DarkTheme())),
          isNot(traceOf(CheckmarkButton(1, Color.RED, theme))),
          reason: 'charts-canvas-theming.checkmark-button-core#1');
    });

    test('#2 FONT_AWESOME at smallTextSize * 1.5 (15.0 by default)', () {
      final theme = LightTheme();
      final canvas = RecordingCanvas(width: 48.0, height: 48.0);
      CheckmarkButton(2, Color.RED, theme).draw(canvas);

      expect(theme.smallTextSize * 1.5, 15.0,
          reason: 'charts-canvas-theming.checkmark-button-core#2');
      expect(canvas.names, contains('setFont'),
          reason: 'charts-canvas-theming.checkmark-button-core#2');
      expect(canvas.names, contains('setFontSize'),
          reason: 'charts-canvas-theming.checkmark-button-core#2');
      final glyph = canvas.opNamed('drawText');
      expect(glyph.state.font, Font.fontAwesome,
          reason: 'charts-canvas-theming.checkmark-button-core#2');
      expect(glyph.state.fontSize, 15.0,
          reason: 'charts-canvas-theming.checkmark-button-core#2');
    });

    test('#3 color only when value == 2, lowContrastTextColor otherwise', () {
      final theme = LightTheme();
      Color colorFor(int value, [Theme? t]) {
        final canvas = RecordingCanvas(width: 48.0, height: 48.0);
        CheckmarkButton(value, Color.RED, t ?? theme).draw(canvas);
        return canvas.opNamed('drawText').state.color;
      }

      expect(colorFor(2), Color.RED,
          reason: 'charts-canvas-theming.checkmark-button-core#3');
      for (final value in [-1, 0, 1, 3, 4]) {
        expect(colorFor(value), theme.lowContrastTextColor,
            reason: 'charts-canvas-theming.checkmark-button-core#3');
      }
      // Value 1 (implicit/automatic check) and 3 (skip) are *not* special.
      expect(colorFor(1), isNot(Color.RED),
          reason: 'charts-canvas-theming.checkmark-button-core#3');
      expect(colorFor(3), isNot(Color.RED),
          reason: 'charts-canvas-theming.checkmark-button-core#3');
      // The fallback is read off the theme, not hardcoded.
      final dark = DarkTheme();
      expect(colorFor(1, dark), dark.lowContrastTextColor,
          reason: 'charts-canvas-theming.checkmark-button-core#3');
      expect(dark.lowContrastTextColor, isNot(theme.lowContrastTextColor),
          reason: 'charts-canvas-theming.checkmark-button-core#3');
    });

    test('#4 TIMES when value == 0, CHECK otherwise', () {
      String glyphFor(int value) {
        final canvas = RecordingCanvas(width: 48.0, height: 48.0);
        CheckmarkButton(value, Color.RED, LightTheme()).draw(canvas);
        return canvas.opNamed('drawText').text;
      }

      expect(glyphFor(0), FontAwesome.times,
          reason: 'charts-canvas-theming.checkmark-button-core#4');
      expect(glyphFor(0), '\u{f00d}',
          reason: 'charts-canvas-theming.checkmark-button-core#4');
      for (final value in [-1, 1, 2, 3]) {
        expect(glyphFor(value), FontAwesome.check,
            reason: 'charts-canvas-theming.checkmark-button-core#4');
      }
      expect(glyphFor(2), '\u{f00c}',
          reason: 'charts-canvas-theming.checkmark-button-core#4');
    });

    test('#5 glyph centred on the canvas, with the inherited text align', () {
      final canvas = RecordingCanvas(width: 80.0, height: 40.0);
      CheckmarkButton(2, Color.RED, LightTheme()).draw(canvas);

      final glyph = canvas.opNamed('drawText');
      expect([glyph.arg(1), glyph.arg(2)], [40.0, 20.0],
          reason: 'charts-canvas-theming.checkmark-button-core#5');
      expect([glyph.arg(1), glyph.arg(2)],
          [canvas.getWidth() / 2, canvas.getHeight() / 2],
          reason: 'charts-canvas-theming.checkmark-button-core#5');
      expect(canvas.names, isNot(contains('setTextAlign')),
          reason: 'charts-canvas-theming.checkmark-button-core#5');
      expect(glyph.state.textAlign, TextAlign.center,
          reason: 'charts-canvas-theming.checkmark-button-core#5');

      // Whatever alignment the host left behind is what the glyph gets.
      final preset = RecordingCanvas(width: 80.0, height: 40.0);
      preset.setTextAlign(TextAlign.left);
      preset.ops.clear();
      CheckmarkButton(2, Color.RED, LightTheme()).draw(preset);
      expect(preset.opNamed('drawText').state.textAlign, TextAlign.left,
          reason: 'charts-canvas-theming.checkmark-button-core#5');
    });

    test('#6 draws no background', () {
      final canvas = RecordingCanvas(width: 48.0, height: 48.0);
      CheckmarkButton(0, Color.RED, LightTheme()).draw(canvas);

      expect(canvas.names, ['setFont', 'setFontSize', 'setColor', 'drawText'],
          reason: 'charts-canvas-theming.checkmark-button-core#6');
      expect(canvas.drawOps.map((o) => o.name), ['drawText'],
          reason: 'charts-canvas-theming.checkmark-button-core#6');
      for (final name in [
        'fillRect',
        'fillRoundRect',
        'fillCircle',
        'fillArc',
        'drawRect',
        'drawLine',
      ]) {
        expect(canvas.opsNamed(name), isEmpty,
            reason: 'charts-canvas-theming.checkmark-button-core#6');
      }
    });
  });

  group('charts-canvas-theming.number-button-core', () {
    test('#1 the numeric value is drawn above the unit label', () {
      final theme = LightTheme();
      final button = NumberButton(Color.RED, 500.0, 100.0, 'steps', theme);
      expect(button, isA<View>(),
          reason: 'charts-canvas-theming.number-button-core#1');

      final canvas = RecordingCanvas(width: 48.0, height: 48.0);
      button.draw(canvas);

      final texts = canvas.opsNamed('drawText');
      expect(texts.length, 2,
          reason: 'charts-canvas-theming.number-button-core#1');
      expect(texts[0].text, '500',
          reason: 'charts-canvas-theming.number-button-core#1');
      expect(texts[1].text, 'steps',
          reason: 'charts-canvas-theming.number-button-core#1');
      expect(texts[0].arg(2) < texts[1].arg(2), isTrue,
          reason: 'charts-canvas-theming.number-button-core#1');
      expect(texts[0].arg(1), texts[1].arg(1),
          reason: 'charts-canvas-theming.number-button-core#1');
      // Stateless: same arguments, same trace.
      final twin = RecordingCanvas(width: 48.0, height: 48.0);
      NumberButton(Color.RED, 500.0, 100.0, 'steps', theme).draw(twin);
      expect(twin.drawTrace, canvas.drawTrace,
          reason: 'charts-canvas-theming.number-button-core#1');
    });

    test('#2 active colour: color / mediumContrast / lowContrast', () {
      final theme = LightTheme();
      Color colorFor(double value, double threshold, [Theme? t]) {
        final canvas = RecordingCanvas(width: 48.0, height: 48.0);
        NumberButton(Color.RED, value, threshold, 'steps', t ?? theme)
            .draw(canvas);
        final texts = canvas.opsNamed('drawText');
        expect(texts.map((o) => o.state.color).toSet().length, 1,
            reason: 'charts-canvas-theming.number-button-core#2');
        return texts.first.state.color;
      }

      expect(colorFor(500.0, 100.0), Color.RED,
          reason: 'charts-canvas-theming.number-button-core#2');
      expect(colorFor(100.0, 100.0), Color.RED,
          reason: 'charts-canvas-theming.number-button-core#2');
      expect(colorFor(99.0, 100.0), theme.mediumContrastTextColor,
          reason: 'charts-canvas-theming.number-button-core#2');
      expect(colorFor(0.01, 100.0), theme.mediumContrastTextColor,
          reason: 'charts-canvas-theming.number-button-core#2');
      expect(colorFor(0.009, 100.0), theme.lowContrastTextColor,
          reason: 'charts-canvas-theming.number-button-core#2');
      expect(colorFor(0.0, 100.0), theme.lowContrastTextColor,
          reason: 'charts-canvas-theming.number-button-core#2');
      expect(colorFor(-5.0, 100.0), theme.lowContrastTextColor,
          reason: 'charts-canvas-theming.number-button-core#2');
      // The first branch wins even for a zero value at a zero threshold.
      expect(colorFor(0.0, 0.0), Color.RED,
          reason: 'charts-canvas-theming.number-button-core#2');
      // Both fallbacks come off the theme.
      final dark = DarkTheme();
      expect(colorFor(99.0, 100.0, dark), dark.mediumContrastTextColor,
          reason: 'charts-canvas-theming.number-button-core#2');
      expect(colorFor(0.0, 100.0, dark), dark.lowContrastTextColor,
          reason: 'charts-canvas-theming.number-button-core#2');
      expect(dark.lowContrastTextColor, isNot(dark.mediumContrastTextColor),
          reason: 'charts-canvas-theming.number-button-core#2');
    });

    test('#3 fonts, font sizes and the 0.6em offsets around the centre', () {
      final theme = LightTheme();
      final canvas = RecordingCanvas(width: 80.0, height: 40.0);
      NumberButton(Color.RED, 500.0, 100.0, 'steps', theme).draw(canvas);

      final em = theme.smallTextSize;
      expect(em, 10.0, reason: 'charts-canvas-theming.number-button-core#3');
      expect(theme.regularTextSize, 17.0,
          reason: 'charts-canvas-theming.number-button-core#3');

      final number = canvas.opsNamed('drawText')[0];
      final units = canvas.opsNamed('drawText')[1];

      expect(number.state.font, Font.bold,
          reason: 'charts-canvas-theming.number-button-core#3');
      expect(number.state.fontSize, theme.regularTextSize,
          reason: 'charts-canvas-theming.number-button-core#3');
      expect([number.arg(1), number.arg(2)], [40.0, 20.0 - 0.6 * em],
          reason: 'charts-canvas-theming.number-button-core#3');
      expect([number.arg(1), number.arg(2)],
          [canvas.getWidth() / 2, canvas.getHeight() / 2 - 0.6 * em],
          reason: 'charts-canvas-theming.number-button-core#3');

      expect(units.state.font, Font.regular,
          reason: 'charts-canvas-theming.number-button-core#3');
      expect(units.state.fontSize, theme.smallTextSize,
          reason: 'charts-canvas-theming.number-button-core#3');
      expect([units.arg(1), units.arg(2)], [40.0, 20.0 + 0.6 * em],
          reason: 'charts-canvas-theming.number-button-core#3');
      expect([units.arg(1), units.arg(2)],
          [canvas.getWidth() / 2, canvas.getHeight() / 2 + 0.6 * em],
          reason: 'charts-canvas-theming.number-button-core#3');

      // The size is set before each drawText, so the order matters.
      expect(canvas.names, [
        'setColor',
        'setFontSize',
        'setFont',
        'drawText',
        'setFontSize',
        'setFont',
        'drawText',
      ], reason: 'charts-canvas-theming.number-button-core#3');
    });

    test('#4 number is toShortString(), units are drawn verbatim', () {
      final theme = LightTheme();
      List<String> textsFor(double value, String units) {
        final canvas = RecordingCanvas(width: 48.0, height: 48.0);
        NumberButton(Color.RED, value, 100.0, units, theme).draw(canvas);
        return canvas.opsNamed('drawText').map((o) => o.text).toList();
      }

      expect(textsFor(1500.0, 'steps'), ['1.5k', 'steps'],
          reason: 'charts-canvas-theming.number-button-core#4');
      expect(textsFor(1500.0, 'steps').first, 1500.0.toShortString(),
          reason: 'charts-canvas-theming.number-button-core#4');
      // No truncation, no ellipsis, no trimming — that is NumberButtonView's
      // job on Android, not the core view's.
      const longUnits = 'kilometres walked per week';
      expect(textsFor(0.0, longUnits), ['0', longUnits],
          reason: 'charts-canvas-theming.number-button-core#4');
      expect(textsFor(0.0, '  ').last, '  ',
          reason: 'charts-canvas-theming.number-button-core#4');
      expect(textsFor(0.0, '').last, '',
          reason: 'charts-canvas-theming.number-button-core#4');
    });

    test('#5 toShortString branch order', () {
      // One value per branch, chosen just above the branch boundary…
      expect(1e9.toShortString(), '1.0G',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(1e8.toShortString(), '100M',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(1e7.toShortString(), '10.0M',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(1e6.toShortString(), '1.0M',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(1e5.toShortString(), '100k',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(1e4.toShortString(), '10.0k',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(1e3.toShortString(), '1.0k',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(1e2.toShortString(), '100',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(1e1.toShortString(), '10',
          reason: 'charts-canvas-theming.number-button-core#5');

      // …and one just below it, which is where the branch order shows: each
      // branch rounds inside its own unit, so 99999 becomes "100.0k" rather
      // than "100k" and 999999 becomes "1000k" rather than "1.0M".
      expect(999999999.0.toShortString(), '1000M',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(99999999.0.toShortString(), '100.0M',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(9999999.0.toShortString(), '10.0M',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(999999.0.toShortString(), '1000k',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(99999.0.toShortString(), '100.0k',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(9999.0.toShortString(), '10.0k',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(999.0.toShortString(), '999',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(99.99.toShortString(), '100.0',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(9.99.toShortString(), '9.99',
          reason: 'charts-canvas-theming.number-button-core#5');

      // The two smallest branches: whole numbers lose the decimals, one
      // decimal digit is kept when it round-trips, two otherwise.
      expect(10.0.toShortString(), '10',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(10.5.toShortString(), '10.5',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(12.3456.toShortString(), '12.3',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(5.0.toShortString(), '5',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(0.1.toShortString(), '0.1',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(0.1235.toShortString(), '0.12',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect(5.25.toShortString(), '5.25',
          reason: 'charts-canvas-theming.number-button-core#5');
      // Negative values fall through every branch into the last one.
      expect((-1.0).toShortString(), '-1',
          reason: 'charts-canvas-theming.number-button-core#5');
      expect((-12.5).toShortString(), '-12.5',
          reason: 'charts-canvas-theming.number-button-core#5');
    });

    test('#6 the documented examples', () {
      expect(0.0.toShortString(), '0',
          reason: 'charts-canvas-theming.number-button-core#6');
      expect(0.5.toShortString(), '0.5',
          reason: 'charts-canvas-theming.number-button-core#6');
      expect(0.25.toShortString(), '0.25',
          reason: 'charts-canvas-theming.number-button-core#6');
      expect(5.0.toShortString(), '5',
          reason: 'charts-canvas-theming.number-button-core#6');
      expect(12.0.toShortString(), '12',
          reason: 'charts-canvas-theming.number-button-core#6');
      expect(12.5.toShortString(), '12.5',
          reason: 'charts-canvas-theming.number-button-core#6');
      expect(123.4.toShortString(), '123',
          reason: 'charts-canvas-theming.number-button-core#6');
      expect(1500.0.toShortString(), '1.5k',
          reason: 'charts-canvas-theming.number-button-core#6');
      expect(15000.0.toShortString(), '15.0k',
          reason: 'charts-canvas-theming.number-button-core#6');
      expect(150000.0.toShortString(), '150k',
          reason: 'charts-canvas-theming.number-button-core#6');
      expect(1.5e6.toShortString(), '1.5M',
          reason: 'charts-canvas-theming.number-button-core#6');
      expect(1.5e8.toShortString(), '150M',
          reason: 'charts-canvas-theming.number-button-core#6');
      expect(1.5e9.toShortString(), '1.5G',
          reason: 'charts-canvas-theming.number-button-core#6');
    });

    test('#7 the Android duplicate strips trailing zeros', () {
      // The seven largest branches are shared verbatim with the core version.
      for (final value in [
        1e9,
        1.5e9,
        1e8,
        1.5e8,
        1e7,
        1e6,
        1.5e6,
        1e5,
        150000.0,
        1e4,
        15000.0,
        1e3,
        1500.0,
      ]) {
        expect(value.toShortStringAndroid(), value.toShortString(),
            reason: 'charts-canvas-theming.number-button-core#7');
      }

      // The three smallest branches use DecimalFormat("#"), ("#.#") and
      // ("#.##") instead of %f. Integral values agree with the core version…
      for (final value in [0.0, 5.0, 12.0, 100.0, 123.0, 999.0]) {
        expect(value.toShortStringAndroid(), value.toShortString(),
            reason: 'charts-canvas-theming.number-button-core#7');
      }
      expect(123.4.toShortStringAndroid(), '123',
          reason: 'charts-canvas-theming.number-button-core#7');

      // …and trailing zeros are stripped, which is what the pattern-based
      // formatter buys: "#.#" never emits a lone ".0".
      expect(12.5.toShortStringAndroid(), '12.5',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(12.50.toShortStringAndroid(), '12.5',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(0.10.toShortStringAndroid(), '0.1',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(0.001.toShortStringAndroid(), '0',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(0.001.toShortString(), '0.00',
          reason: 'charts-canvas-theming.number-button-core#7');

      // The values asserted by NumberButtonViewTest.testFormatValue.
      expect(0.1235.toShortStringAndroid(), '0.12',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(0.1000.toShortStringAndroid(), '0.1',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(5.0.toShortStringAndroid(), '5',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(5.25.toShortStringAndroid(), '5.25',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(12.3456.toShortStringAndroid(), '12.3',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(123.123.toShortStringAndroid(), '123',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(321.2.toShortStringAndroid(), '321',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(4321.2.toShortStringAndroid(), '4.3k',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(54321.2.toShortStringAndroid(), '54.3k',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(654321.2.toShortStringAndroid(), '654k',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(7654321.2.toShortStringAndroid(), '7.7M',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(87654321.2.toShortStringAndroid(), '87.7M',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(987654321.2.toShortStringAndroid(), '988M',
          reason: 'charts-canvas-theming.number-button-core#7');
      expect(1987654321.2.toShortStringAndroid(), '2.0G',
          reason: 'charts-canvas-theming.number-button-core#7');
    });
  });

  // The label a NumberButtonView draws is `value.toShortString()` from
  // `org.isoron.uhabits.activities.habits.list.views` — the Android duplicate,
  // i.e. [ShortString.toShortStringAndroid]. The rest of that view (the skip
  // and question-mark glyphs, the AT_MOST colouring, the unit trimming, the
  // notes indicator) is not ported; only the number formatting is.
  group('list-habits.number-button', () {
    test('#5 the branch chosen is the first one the value clears', () {
      // Each branch rounds inside its own unit, so the boundary values pin the
      // order the ladder is walked: >=1e9 G, >=1e8 M with no decimal, >=1e7
      // and >=1e6 M with one, >=1e5 k with none, >=1e4 and >=1e3 k with one,
      // then the three DecimalFormat patterns.
      expect(1e9.toShortStringAndroid(), '1.0G',
          reason: 'list-habits.number-button#5');
      expect(1e8.toShortStringAndroid(), '100M',
          reason: 'list-habits.number-button#5');
      expect(1e7.toShortStringAndroid(), '10.0M',
          reason: 'list-habits.number-button#5');
      expect(1e6.toShortStringAndroid(), '1.0M',
          reason: 'list-habits.number-button#5');
      expect(1e5.toShortStringAndroid(), '100k',
          reason: 'list-habits.number-button#5');
      expect(1e4.toShortStringAndroid(), '10.0k',
          reason: 'list-habits.number-button#5');
      expect(1e3.toShortStringAndroid(), '1.0k',
          reason: 'list-habits.number-button#5');
      // DecimalFormat("#"): no fractional digits at all above 100.
      expect(123.99.toShortStringAndroid(), '124',
          reason: 'list-habits.number-button#5');
      // DecimalFormat("#.#") between 10 and 100…
      expect(12.34.toShortStringAndroid(), '12.3',
          reason: 'list-habits.number-button#5');
      // …and DecimalFormat("#.##") below 10.
      expect(1.234.toShortStringAndroid(), '1.23',
          reason: 'list-habits.number-button#5');
    });

    test('#6 the concrete examples of NumberButtonViewTest.testFormatValue', () {
      const expected = <(double, String)>[
        (0.1235, '0.12'),
        (0.1, '0.1'),
        (5.0, '5'),
        (5.25, '5.25'),
        (12.3456, '12.3'),
        (123.123, '123'),
        (321.2, '321'),
        (4321.2, '4.3k'),
        (54321.2, '54.3k'),
        (654321.2, '654k'),
        (7654321.2, '7.7M'),
        (87654321.2, '87.7M'),
        (987654321.2, '988M'),
        (1987654321.2, '2.0G'),
      ];
      for (final (value, text) in expected) {
        expect(value.toShortStringAndroid(), text,
            reason: 'list-habits.number-button#6');
      }
    });
  });

  group('charts-canvas-theming.habit-list-header-core', () {
    // The core goldens are rendered with Locale.US and a fixed today of
    // 2015-01-25 (a Sunday), which is what [_UsDateFormatter] reproduces.
    final today = LocalDate.ymd(2015, 1, 25);
    final fmt = _UsDateFormatter();

    test('#1 the weekday / day-number strip', () {
      final theme = LightTheme();
      final header = HabitListHeader(today, 7, theme, fmt);
      expect(header, isA<View>(),
          reason: 'charts-canvas-theming.habit-list-header-core#1');

      final canvas = RecordingCanvas(width: 600.0, height: 48.0);
      header.draw(canvas);

      expect(canvas.drawOps.map((o) => o.name),
          ['fillRect', 'drawLine', ...List.filled(14, 'drawText')],
          reason: 'charts-canvas-theming.habit-list-header-core#1');
      expect(canvas.opsNamed('drawText').map((o) => o.text), [
        'MON', '19', //
        'TUE', '20', //
        'WED', '21', //
        'THU', '22', //
        'FRI', '23', //
        'SAT', '24', //
        'SUN', '25', //
      ], reason: 'charts-canvas-theming.habit-list-header-core#1');

      // Stateless: same arguments, same trace.
      final twin = RecordingCanvas(width: 600.0, height: 48.0);
      HabitListHeader(today, 7, theme, fmt).draw(twin);
      expect(twin.drawTrace, canvas.drawTrace,
          reason: 'charts-canvas-theming.habit-list-header-core#1');

      // nButtons == 0 paints the background and the border only.
      final empty = RecordingCanvas(width: 600.0, height: 48.0);
      HabitListHeader(today, 0, theme, fmt).draw(empty);
      expect(empty.opsNamed('drawText'), isEmpty,
          reason: 'charts-canvas-theming.habit-list-header-core#1');
    });

    test('#2 the whole rect is filled with headerBackgroundColor first', () {
      final theme = LightTheme();
      final canvas = RecordingCanvas(width: 600.0, height: 48.0);
      HabitListHeader(today, 7, theme, fmt).draw(canvas);

      final fill = canvas.drawOps.first;
      expect(fill.name, 'fillRect',
          reason: 'charts-canvas-theming.habit-list-header-core#2');
      expect(fill.args, [0.0, 0.0, 600.0, 48.0],
          reason: 'charts-canvas-theming.habit-list-header-core#2');
      expect(fill.args, [0.0, 0.0, canvas.getWidth(), canvas.getHeight()],
          reason: 'charts-canvas-theming.habit-list-header-core#2');
      expect(fill.state.color, theme.headerBackgroundColor,
          reason: 'charts-canvas-theming.habit-list-header-core#2');

      final dark = DarkTheme();
      final darkCanvas = RecordingCanvas(width: 600.0, height: 48.0);
      HabitListHeader(today, 7, dark, fmt).draw(darkCanvas);
      expect(darkCanvas.drawOps.first.state.color, dark.headerBackgroundColor,
          reason: 'charts-canvas-theming.habit-list-header-core#2');
      expect(dark.headerBackgroundColor, isNot(theme.headerBackgroundColor),
          reason: 'charts-canvas-theming.habit-list-header-core#2');
    });

    test('#3 a 0.5-wide separator hugging the bottom edge', () {
      final theme = LightTheme();
      final canvas = RecordingCanvas(width: 600.0, height: 48.0);
      HabitListHeader(today, 7, theme, fmt).draw(canvas);

      final line = canvas.opNamed('drawLine');
      expect(line.args, [0.0, 47.5, 600.0, 47.5],
          reason: 'charts-canvas-theming.habit-list-header-core#3');
      expect(line.args, [
        0.0,
        canvas.getHeight() - 0.5,
        canvas.getWidth(),
        canvas.getHeight() - 0.5,
      ], reason: 'charts-canvas-theming.habit-list-header-core#3');
      expect(line.state.strokeWidth, 0.5,
          reason: 'charts-canvas-theming.habit-list-header-core#3');
      expect(line.state.color, theme.headerBorderColor,
          reason: 'charts-canvas-theming.habit-list-header-core#3');
      // It is painted after the background, so it stays visible.
      expect(canvas.drawOps.indexOf(line), 1,
          reason: 'charts-canvas-theming.habit-list-header-core#3');
    });

    test('#4 text in headerTextColor, BOLD, smallTextSize', () {
      final theme = LightTheme();
      final canvas = RecordingCanvas(width: 600.0, height: 48.0);
      HabitListHeader(today, 7, theme, fmt).draw(canvas);

      expect(theme.smallTextSize, 10.0,
          reason: 'charts-canvas-theming.habit-list-header-core#4');
      for (final text in canvas.opsNamed('drawText')) {
        expect(text.state.color, theme.headerTextColor,
            reason: 'charts-canvas-theming.habit-list-header-core#4');
        expect(text.state.font, Font.bold,
            reason: 'charts-canvas-theming.habit-list-header-core#4');
        expect(text.state.fontSize, theme.smallTextSize,
            reason: 'charts-canvas-theming.habit-list-header-core#4');
      }
      // The colour is set once, after the border colour, and never per column.
      expect(canvas.opsNamed('setColor').length, 3,
          reason: 'charts-canvas-theming.habit-list-header-core#4');
    });

    test('#5 buttonSize is theme.checkmarkButtonSize (48.0)', () {
      final theme = LightTheme();
      expect(theme.checkmarkButtonSize, 48.0,
          reason: 'charts-canvas-theming.habit-list-header-core#5');

      final canvas = RecordingCanvas(width: 600.0, height: 48.0);
      HabitListHeader(today, 7, theme, fmt).draw(canvas);
      final xs = canvas
          .opsNamed('drawText')
          .map((o) => o.arg(1))
          .toSet()
          .toList()
        ..sort();
      // Consecutive columns are exactly one button apart.
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i] - xs[i - 1], theme.checkmarkButtonSize,
            reason: 'charts-canvas-theming.habit-list-header-core#5');
      }
      expect(xs.last, 600.0 - theme.checkmarkButtonSize / 2,
          reason: 'charts-canvas-theming.habit-list-header-core#5');
    });

    test('#6 index 0 is the oldest date and sits at the right edge', () {
      final theme = LightTheme();
      final canvas = RecordingCanvas(width: 600.0, height: 48.0);
      const nButtons = 7;
      HabitListHeader(today, nButtons, theme, fmt).draw(canvas);

      final texts = canvas.opsNamed('drawText');
      for (var index = 0; index < nButtons; index++) {
        final date = today.minus(nButtons - index - 1);
        final x = 600.0 - (index + 1) * 48.0 + 48.0 / 2;
        final name = texts[2 * index];
        final number = texts[2 * index + 1];
        expect(name.arg(1), x,
            reason: 'charts-canvas-theming.habit-list-header-core#6');
        expect(number.arg(1), x,
            reason: 'charts-canvas-theming.habit-list-header-core#6');
        expect(number.text, date.day.toString(),
            reason: 'charts-canvas-theming.habit-list-header-core#6');
      }
      // Index 0: oldest date, flush against the right edge.
      expect(texts[0].arg(1), 576.0,
          reason: 'charts-canvas-theming.habit-list-header-core#6');
      expect(texts[1].text, today.minus(6).day.toString(),
          reason: 'charts-canvas-theming.habit-list-header-core#6');
      expect(texts[1].text, '19',
          reason: 'charts-canvas-theming.habit-list-header-core#6');
      // Index nButtons - 1: today, leftmost.
      expect(texts[12].arg(1), 288.0,
          reason: 'charts-canvas-theming.habit-list-header-core#6');
      expect(texts[13].text, today.day.toString(),
          reason: 'charts-canvas-theming.habit-list-header-core#6');
      expect(texts[13].text, '25',
          reason: 'charts-canvas-theming.habit-list-header-core#6');
      // Columns run right to left as the index grows.
      final xs = texts.map((o) => o.arg(1)).toList();
      expect(xs.first > xs.last, isTrue,
          reason: 'charts-canvas-theming.habit-list-header-core#6');
    });

    test('#7 two lines per column, 0.6 * smallTextSize above and below', () {
      final theme = LightTheme();
      final canvas = RecordingCanvas(width: 600.0, height: 48.0);
      HabitListHeader(today, 7, theme, fmt).draw(canvas);

      final texts = canvas.opsNamed('drawText');
      for (var index = 0; index < 7; index++) {
        final date = today.minus(7 - index - 1);
        final name = texts[2 * index];
        final number = texts[2 * index + 1];
        expect(name.text, fmt.shortWeekdayName(date).toUpperCase(),
            reason: 'charts-canvas-theming.habit-list-header-core#7');
        expect(name.text, fmt.shortWeekdayName(date).toUpperCase(),
            reason: 'charts-canvas-theming.habit-list-header-core#7');
        expect(name.arg(2), 48.0 / 2 - theme.smallTextSize * 0.6,
            reason: 'charts-canvas-theming.habit-list-header-core#7');
        expect(number.text, date.day.toString(),
            reason: 'charts-canvas-theming.habit-list-header-core#7');
        expect(number.arg(2), 48.0 / 2 + theme.smallTextSize * 0.6,
            reason: 'charts-canvas-theming.habit-list-header-core#7');
      }
      expect(texts[0].arg(2), 18.0,
          reason: 'charts-canvas-theming.habit-list-header-core#7');
      expect(texts[1].arg(2), 30.0,
          reason: 'charts-canvas-theming.habit-list-header-core#7');
      // The names are uppercased by the view, not by the formatter.
      expect(fmt.shortWeekdayName(today), 'Sun',
          reason: 'charts-canvas-theming.habit-list-header-core#7');
      expect(texts[12].text, 'SUN',
          reason: 'charts-canvas-theming.habit-list-header-core#7');
      // The vertical centre follows the canvas height.
      final tall = RecordingCanvas(width: 600.0, height: 96.0);
      HabitListHeader(today, 7, theme, fmt).draw(tall);
      expect(tall.opsNamed('drawText').first.arg(2), 48.0 - 6.0,
          reason: 'charts-canvas-theming.habit-list-header-core#7');
    });

    test('#8 never sets a text alignment', () {
      final canvas = RecordingCanvas(width: 600.0, height: 48.0);
      HabitListHeader(today, 7, LightTheme(), fmt).draw(canvas);

      expect(canvas.names, isNot(contains('setTextAlign')),
          reason: 'charts-canvas-theming.habit-list-header-core#8');
      for (final text in canvas.opsNamed('drawText')) {
        expect(text.state.textAlign, TextAlign.center,
            reason: 'charts-canvas-theming.habit-list-header-core#8');
      }

      // Whatever the host left behind is what the labels get.
      final preset = RecordingCanvas(width: 600.0, height: 48.0);
      preset.setTextAlign(TextAlign.right);
      preset.ops.clear();
      HabitListHeader(today, 7, LightTheme(), fmt).draw(preset);
      expect(preset.opsNamed('drawText').first.state.textAlign, TextAlign.right,
          reason: 'charts-canvas-theming.habit-list-header-core#8');
    });
  });
}

/// `JavaLocalDateFormatter(Locale.US)`, reduced to what the header needs.
class _UsDateFormatter implements LocalDateFormatter {
  static const List<String> _shortWeekdayNames = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  static const List<String> _longWeekdayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  static const List<String> _shortMonthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _longMonthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  String shortWeekdayNameOf(DayOfWeek weekday) =>
      _shortWeekdayNames[weekday.daysSinceSunday];

  @override
  String shortWeekdayName(LocalDate date) => shortWeekdayNameOf(date.dayOfWeek);

  @override
  String shortMonthName(LocalDate date) => _shortMonthNames[date.month - 1];

  @override
  String longWeekdayNameOf(DayOfWeek weekday) =>
      _longWeekdayNames[weekday.daysSinceSunday];

  @override
  String longMonthName(LocalDate date) => _longMonthNames[date.month - 1];
}

/// The sticky paint state a call was made under.
class CanvasState {
  const CanvasState({
    required this.color,
    required this.font,
    required this.fontSize,
    required this.strokeWidth,
    required this.textAlign,
  });

  final Color color;
  final Font font;
  final double fontSize;
  final double strokeWidth;
  final TextAlign textAlign;

  @override
  String toString() =>
      'color=$color font=$font fontSize=$fontSize strokeWidth=$strokeWidth '
      'textAlign=$textAlign';
}

class RecordedOp {
  RecordedOp(this.name, this.args, this.state);

  final String name;
  final List<Object?> args;
  final CanvasState state;

  double arg(int index) => args[index] as double;

  String get text => args[0] as String;

  @override
  String toString() => '$name(${args.join(', ')}) {$state}';
}

/// A [Canvas] that paints nothing and remembers everything.
///
/// Sizes are given in logical units directly — the density conversion the real
/// backends do is not what these three views are being tested for. The initial
/// paint state mirrors a freshly created backend: BLACK, regular font, and
/// TextAlign.center, which is the default both AndroidCanvas and JavaCanvas
/// install and which CheckmarkButton, NumberButton and HabitListHeader all
/// rely on.
class RecordingCanvas extends Canvas {
  RecordingCanvas({required this.width, required this.height});

  final double width;
  final double height;

  final List<RecordedOp> ops = [];

  Color _color = Color.BLACK;
  Font _font = Font.regular;
  double _fontSize = 12.0;
  double _strokeWidth = 1.0;
  TextAlign _textAlign = TextAlign.center;

  CanvasState get _state => CanvasState(
        color: _color,
        font: _font,
        fontSize: _fontSize,
        strokeWidth: _strokeWidth,
        textAlign: _textAlign,
      );

  void _record(String name, List<Object?> args) {
    ops.add(RecordedOp(name, args, _state));
  }

  List<String> get names => ops.map((o) => o.name).toList();

  List<RecordedOp> opsNamed(String name) =>
      ops.where((o) => o.name == name).toList();

  RecordedOp opNamed(String name) => ops.firstWhere((o) => o.name == name);

  /// Every call that puts ink on the surface, in order.
  List<RecordedOp> get drawOps =>
      ops.where((o) => !o.name.startsWith('set')).toList();

  String get trace => ops.join('\n');

  /// The ink only: every drawing call, with the paint state it was made
  /// under. Two views that produce the same [drawTrace] paint the same
  /// pixels.
  String get drawTrace => drawOps.join('\n');

  @override
  void setColor(Color color) {
    _color = color;
    _record('setColor', [color]);
  }

  @override
  void drawLine(double x1, double y1, double x2, double y2) {
    _record('drawLine', [x1, y1, x2, y2]);
  }

  @override
  void drawText(String text, double x, double y) {
    _record('drawText', [text, x, y]);
  }

  @override
  void fillRect(double x, double y, double width, double height) {
    _record('fillRect', [x, y, width, height]);
  }

  @override
  void fillRoundRect(
    double x,
    double y,
    double width,
    double height,
    double cornerRadius,
  ) {
    _record('fillRoundRect', [x, y, width, height, cornerRadius]);
  }

  @override
  void drawRect(double x, double y, double width, double height) {
    _record('drawRect', [x, y, width, height]);
  }

  @override
  double getHeight() => height;

  @override
  double getWidth() => width;

  @override
  void setFont(Font font) {
    _font = font;
    _record('setFont', [font]);
  }

  @override
  void setFontSize(double size) {
    _fontSize = size;
    _record('setFontSize', [size]);
  }

  @override
  void setStrokeWidth(double size) {
    _strokeWidth = size;
    _record('setStrokeWidth', [size]);
  }

  @override
  void fillArc(
    double centerX,
    double centerY,
    double radius,
    double startAngle,
    double swipeAngle,
  ) {
    _record('fillArc', [centerX, centerY, radius, startAngle, swipeAngle]);
  }

  @override
  void fillCircle(double centerX, double centerY, double radius) {
    _record('fillCircle', [centerX, centerY, radius]);
  }

  @override
  void setTextAlign(TextAlign align) {
    _textAlign = align;
    _record('setTextAlign', [align]);
  }

  @override
  Image toImage() => _FakeImage(width.toInt(), height.toInt());

  @override
  double measureText(String text) => text.length * 0.6 * _fontSize;
}

class _FakeImage extends Image {
  _FakeImage(this.width, this.height);

  @override
  final int width;

  @override
  final int height;

  @override
  Color getPixel(int x, int y) => Color.BLACK;

  @override
  void setPixel(int x, int y, Color color) {}

  @override
  Future<void> export(String path) async {}
}
