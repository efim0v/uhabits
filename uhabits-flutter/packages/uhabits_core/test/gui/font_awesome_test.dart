import 'dart:math';

import 'package:test/test.dart';
import 'package:uhabits_core/src/gui/color.dart';
import 'package:uhabits_core/src/gui/font_awesome.dart';
import 'package:uhabits_core/src/gui/image.dart';

/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/FontAwesome.kt,
/// uhabits-android/src/main/res/values/fontawesome.xml,
/// uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/Image.kt and
/// uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/ViewTestHelper.kt
/// (plus the Android comparator in
/// uhabits-android/src/androidTest/java/org/isoron/uhabits/BaseViewTest.kt).
///
/// Covers the feature ids `charts-canvas-theming.fontawesome-glyphs` and
/// `charts-canvas-theming.image-and-golden-diff`.

/// Records every `export(path)` call made by the images a test builds, in the
/// order the production code makes them. Mirrors what the Kotlin helper does
/// with real files under /tmp/failed.
class _ExportRecorder {
  final List<String> paths = <String>[];
  final List<Image> images = <Image>[];

  Future<void> call(Image image, String path) async {
    images.add(image);
    paths.add(path);
  }
}

const Color _black = Color(0.0, 0.0, 0.0, 1.0);
const Color _white = Color(1.0, 1.0, 1.0, 1.0);

RgbaImage _solid(
  int width,
  int height,
  Color color, {
  ImageExporter? exporter,
}) {
  final image = RgbaImage(width, height, exporter: exporter);
  for (var x = 0; x < width; x++) {
    for (var y = 0; y < height; y++) {
      image.setPixel(x, y, color);
    }
  }
  return image;
}

void main() {
  group('FontAwesome', () {
    test('core constants are exactly CHECK and TIMES', () {
      expect(FontAwesome.check.runes.toList(), [0xf00c],
          reason: 'charts-canvas-theming.fontawesome-glyphs#1');
      expect(FontAwesome.times.runes.toList(), [0xf00d],
          reason: 'charts-canvas-theming.fontawesome-glyphs#1');
      expect(FontAwesome.check, '\u{f00c}',
          reason: 'charts-canvas-theming.fontawesome-glyphs#1');
      expect(FontAwesome.times, '\u{f00d}',
          reason: 'charts-canvas-theming.fontawesome-glyphs#1');
      expect(FontAwesome.coreGlyphs, {'CHECK': '\u{f00c}', 'TIMES': '\u{f00d}'},
          reason: 'charts-canvas-theming.fontawesome-glyphs#1');
      expect(FontAwesome.coreGlyphs.length, 2,
          reason: 'charts-canvas-theming.fontawesome-glyphs#1');
    });

    test('android string resources add the rest of the glyph vocabulary', () {
      expect(FontAwesome.androidGlyphs, {
        'fa_check': '\u{f00c}',
        'fa_times': '\u{f00d}',
        'fa_skipped': '\u{f068}',
        'fa_question': '\u{f128}',
        'fa_star_half_o': '\u{f5c0}',
        'fa_arrow_circle_up': '\u{f0aa}',
        'fa_arrow_circle_down': '\u{f0ab}',
        'fa_bell_o': '\u{f0f3}',
        'fa_calendar': '\u{f073}',
        'fa_exclamation_circle': '\u{f06a}',
        'fa_umbrella_beach': '\u{f5ca}',
      }, reason: 'charts-canvas-theming.fontawesome-glyphs#2');

      // Named constants, so call sites read like the Kotlin/Android ones.
      expect(FontAwesome.skipped.runes.toList(), [0xf068],
          reason: 'charts-canvas-theming.fontawesome-glyphs#2');
      expect(FontAwesome.question.runes.toList(), [0xf128],
          reason: 'charts-canvas-theming.fontawesome-glyphs#2');
      expect(FontAwesome.starHalfO.runes.toList(), [0xf5c0],
          reason: 'charts-canvas-theming.fontawesome-glyphs#2');
      expect(FontAwesome.arrowCircleUp.runes.toList(), [0xf0aa],
          reason: 'charts-canvas-theming.fontawesome-glyphs#2');
      expect(FontAwesome.arrowCircleDown.runes.toList(), [0xf0ab],
          reason: 'charts-canvas-theming.fontawesome-glyphs#2');
      expect(FontAwesome.bellO.runes.toList(), [0xf0f3],
          reason: 'charts-canvas-theming.fontawesome-glyphs#2');
      expect(FontAwesome.calendar.runes.toList(), [0xf073],
          reason: 'charts-canvas-theming.fontawesome-glyphs#2');
      expect(FontAwesome.exclamationCircle.runes.toList(), [0xf06a],
          reason: 'charts-canvas-theming.fontawesome-glyphs#2');
      expect(FontAwesome.umbrellaBeach.runes.toList(), [0xf5ca],
          reason: 'charts-canvas-theming.fontawesome-glyphs#2');

      // Every glyph is a single code point: they are addressed by raw code
      // point, never by icon name.
      for (final entry in FontAwesome.androidGlyphs.entries) {
        expect(entry.value.runes.length, 1,
            reason: 'charts-canvas-theming.fontawesome-glyphs#2');
      }
    });

    test('FONT_AWESOME resolves to the bundled icon font file', () {
      expect(FontAssets.coreFontAwesome, 'fonts/FontAwesome.ttf',
          reason: 'charts-canvas-theming.fontawesome-glyphs#3');
      expect(FontAssets.androidFontAwesome, 'fontawesome-webfont.ttf',
          reason: 'charts-canvas-theming.fontawesome-glyphs#3');
      expect(FontAssets.fontAwesomeFamily, 'FontAwesome',
          reason: 'charts-canvas-theming.fontawesome-glyphs#3');
    });

    test('REGULAR and BOLD resolve to NotoSans in the core renderer', () {
      expect(FontAssets.coreRegular, 'fonts/NotoSans-Regular.ttf',
          reason: 'charts-canvas-theming.fontawesome-glyphs#4');
      expect(FontAssets.coreBold, 'fonts/NotoSans-Bold.ttf',
          reason: 'charts-canvas-theming.fontawesome-glyphs#4');
      expect(FontAssets.regularFamily, 'NotoSans',
          reason: 'charts-canvas-theming.fontawesome-glyphs#4');
      expect(FontAssets.coreRegular == FontAssets.coreBold, isFalse,
          reason: 'charts-canvas-theming.fontawesome-glyphs#4');
    });
  });

  group('Image', () {
    test('exposes width, height, getPixel, setPixel and export', () async {
      final recorder = _ExportRecorder();
      final image = RgbaImage(3, 2, exporter: recorder.call);
      expect(image.width, 3,
          reason: 'charts-canvas-theming.image-and-golden-diff#1');
      expect(image.height, 2,
          reason: 'charts-canvas-theming.image-and-golden-diff#1');

      image.setPixel(2, 1, const Color(1.0, 0.0, 0.0, 1.0));
      final pixel = image.getPixel(2, 1);
      expect(pixel.red, 1.0,
          reason: 'charts-canvas-theming.image-and-golden-diff#1');
      expect(pixel.green, 0.0,
          reason: 'charts-canvas-theming.image-and-golden-diff#1');
      expect(pixel.blue, 0.0,
          reason: 'charts-canvas-theming.image-and-golden-diff#1');
      expect(pixel.alpha, 1.0,
          reason: 'charts-canvas-theming.image-and-golden-diff#1');
      expect(image.getPixel(0, 0), _transparent,
          reason: 'charts-canvas-theming.image-and-golden-diff#1');

      await image.export('/tmp/failed/out.png');
      expect(recorder.paths, ['/tmp/failed/out.png'],
          reason: 'charts-canvas-theming.image-and-golden-diff#1');
    });

    test('diff rejects images whose dimensions do not match', () {
      final a = RgbaImage(4, 3);
      expect(
        () => a.diff(RgbaImage(5, 3)),
        throwsA(isA<Object>().having((Object e) => e.toString(), 'message',
            contains('Width must match: 4 !== 5'))),
        reason: 'charts-canvas-theming.image-and-golden-diff#2',
      );
      expect(
        () => a.diff(RgbaImage(4, 7)),
        throwsA(isA<Object>().having((Object e) => e.toString(), 'message',
            contains('Height must match: 3 !== 7'))),
        reason: 'charts-canvas-theming.image-and-golden-diff#2',
      );
    });

    test('diff writes the 5x5 min-window luminosity distance in place', () {
      // Identical images diff to pure black.
      final expected = _solid(7, 7, _black);
      final actual = _solid(7, 7, _black);
      expected.setPixel(3, 3, _white);
      actual.setPixel(3, 3, _white);
      expected.diff(actual);
      for (var x = 0; x < 7; x++) {
        for (var y = 0; y < 7; y++) {
          expect(expected.getPixel(x, y).luminosity, closeTo(0.0, 1e-9),
              reason: 'charts-canvas-theming.image-and-golden-diff#3');
        }
      }

      // The receiver is the one that gets mutated, and the diff pixel is grey.
      final receiver = _solid(7, 7, _black);
      receiver.setPixel(3, 3, _white);
      final other = _solid(7, 7, _black);
      receiver.diff(other);
      final diffPixel = receiver.getPixel(3, 3);
      expect(diffPixel.red, closeTo(1.0, 1e-9),
          reason: 'charts-canvas-theming.image-and-golden-diff#3');
      expect(diffPixel.green, closeTo(1.0, 1e-9),
          reason: 'charts-canvas-theming.image-and-golden-diff#3');
      expect(diffPixel.blue, closeTo(1.0, 1e-9),
          reason: 'charts-canvas-theming.image-and-golden-diff#3');
      expect(diffPixel.alpha, closeTo(1.0, 1e-9),
          reason: 'charts-canvas-theming.image-and-golden-diff#3');
      expect(other.getPixel(3, 3).luminosity, closeTo(0.0, 1e-9),
          reason: 'charts-canvas-theming.image-and-golden-diff#3');
    });

    test('diff tolerates a 2px shift but not a 3px one', () {
      for (final shift in [1, 2]) {
        final receiver = _solid(9, 9, _black)..setPixel(3, 3, _white);
        final other = _solid(9, 9, _black)..setPixel(3 + shift, 3, _white);
        receiver.diff(other);
        expect(receiver.averageLuminosity, closeTo(0.0, 1e-9),
            reason: 'charts-canvas-theming.image-and-golden-diff#3');
      }
      final receiver = _solid(9, 9, _black)..setPixel(3, 3, _white);
      final other = _solid(9, 9, _black)..setPixel(6, 3, _white);
      receiver.diff(other);
      expect(receiver.getPixel(3, 3).luminosity, closeTo(1.0, 1e-9),
          reason: 'charts-canvas-theming.image-and-golden-diff#3');
      // Only the receiver's white pixel finds no match; the pixel under the
      // other image's white dot still matches one of its black neighbours.
      expect(receiver.getPixel(6, 3).luminosity, closeTo(0.0, 1e-9),
          reason: 'charts-canvas-theming.image-and-golden-diff#3');
      expect(receiver.averageLuminosity, closeTo(1.0 / 81, 1e-9),
          reason: 'charts-canvas-theming.image-and-golden-diff#3');
    });

    test('averageLuminosity is the mean luminosity over every pixel', () {
      final image = _solid(4, 5, _black);
      expect(image.averageLuminosity, closeTo(0.0, 1e-9),
          reason: 'charts-canvas-theming.image-and-golden-diff#4');

      image.setPixel(0, 0, _white);
      image.setPixel(1, 0, _white);
      expect(image.averageLuminosity, closeTo(2.0 / 20, 1e-9),
          reason: 'charts-canvas-theming.image-and-golden-diff#4');

      final green = _solid(2, 2, const Color(0.0, 1.0, 0.0, 1.0));
      expect(green.averageLuminosity, closeTo(0.72, 1e-9),
          reason: 'charts-canvas-theming.image-and-golden-diff#4');
      expect(_solid(3, 3, _white).averageLuminosity, closeTo(1.0, 1e-9),
          reason: 'charts-canvas-theming.image-and-golden-diff#4');
    });

    test('assertRenders passes when the golden matches', () async {
      final recorder = _ExportRecorder();
      final actual = _solid(9, 9, _black, exporter: recorder.call)
        ..setPixel(3, 3, _white);
      await assertRenders(
        'views/CanvasTest.png',
        actual,
        loadResourceImage: (_) =>
            _solid(9, 9, _black, exporter: recorder.call)
              ..setPixel(4, 3, _white),
      );
      expect(recorder.paths, isEmpty,
          reason: 'charts-canvas-theming.image-and-golden-diff#5');
    });

    test('assertRenders fails and exports three files when images differ',
        () async {
      final recorder = _ExportRecorder();
      final actual = _solid(9, 9, _black, exporter: recorder.call);
      final expectedImage = _solid(9, 9, _black, exporter: recorder.call)
        ..setPixel(3, 3, _white);
      final diffImage = _solid(9, 9, _black, exporter: recorder.call)
        ..setPixel(3, 3, _white);
      final loaded = <Image>[expectedImage, diffImage];

      Object? thrown;
      try {
        await assertRenders(
          'views/habits/list/CheckmarkButtonView/render_unchecked.png',
          actual,
          loadResourceImage: (_) => loaded.removeAt(0),
        );
      } catch (e) {
        thrown = e;
      }

      expect(thrown, isNotNull,
          reason: 'charts-canvas-theming.image-and-golden-diff#5');
      expect(thrown.toString(), contains('Images differ (distance='),
          reason: 'charts-canvas-theming.image-and-golden-diff#5');
      final reported = double.parse(
        RegExp(r'distance=([-0-9.eE+]+)\)').firstMatch(thrown.toString())!.group(1)!,
      );
      // One of 81 pixels is fully white in the golden and has no match within
      // 2px in the actual image: distance = 100 * (1 / 81).
      expect(reported, closeTo(100.0 / 81, 1e-9),
          reason: 'charts-canvas-theming.image-and-golden-diff#5');
      expect(reported >= 1.0, isTrue,
          reason: 'charts-canvas-theming.image-and-golden-diff#5');
      expect(recorder.paths, [
        '/tmp/failed/views/habits/list/CheckmarkButtonView/'
            'render_unchecked.expected.png',
        '/tmp/failed/views/habits/list/CheckmarkButtonView/'
            'render_unchecked.png',
        '/tmp/failed/views/habits/list/CheckmarkButtonView/'
            'render_unchecked.diff.png',
      ], reason: 'charts-canvas-theming.image-and-golden-diff#5');
      expect(recorder.images, [expectedImage, actual, diffImage],
          reason: 'charts-canvas-theming.image-and-golden-diff#5');
      // The diff image, not the expected one, is what got mutated.
      expect(diffImage.averageLuminosity, closeTo(1.0 / 81, 1e-9),
          reason: 'charts-canvas-theming.image-and-golden-diff#5');

      // The cutoff is `distance >= 1.0`, not `> 1.0`.
      expect(goldenDistanceIsFailure(1.0), isTrue,
          reason: 'charts-canvas-theming.image-and-golden-diff#5');
      expect(goldenDistanceIsFailure(0.9999999), isFalse,
          reason: 'charts-canvas-theming.image-and-golden-diff#5');
      expect(goldenDistanceCutoff, 1.0,
          reason: 'charts-canvas-theming.image-and-golden-diff#5');
    });

    test('assertRenders reports a missing golden', () async {
      final recorder = _ExportRecorder();
      final actual = _solid(4, 4, _black, exporter: recorder.call);
      Object? thrown;
      try {
        await assertRenders(
          'views/CanvasTest.png',
          actual,
          loadResourceImage: (_) => null,
        );
      } catch (e) {
        thrown = e;
      }
      expect(
        thrown.toString(),
        contains('Expected image file is missing. '
            'Actual image: /tmp/failed/views/CanvasTest.png'),
        reason: 'charts-canvas-theming.image-and-golden-diff#6',
      );
      expect(recorder.paths, ['/tmp/failed/views/CanvasTest.png'],
          reason: 'charts-canvas-theming.image-and-golden-diff#6');
    });

    test('the android screenshot comparator samples 1 in 4 pixels', () {
      final comparator = AndroidScreenshotComparator(random: Random(42));
      expect(comparator.similarityCutoff, 0.00018,
          reason: 'charts-canvas-theming.image-and-golden-diff#8');
      expect(androidCanvasSimilarityCutoff, 0.0005,
          reason: 'charts-canvas-theming.image-and-golden-diff#8');
      expect(comparator.exceedsCutoff(0.00018), isFalse,
          reason: 'charts-canvas-theming.image-and-golden-diff#8');
      expect(comparator.exceedsCutoff(0.00019), isTrue,
          reason: 'charts-canvas-theming.image-and-golden-diff#8');

      // Mismatched dimensions score the maximum distance.
      expect(comparator.distance(RgbaImage(4, 4), RgbaImage(5, 4)), 1.0,
          reason: 'charts-canvas-theming.image-and-golden-diff#8');
      expect(comparator.distance(RgbaImage(4, 4), RgbaImage(4, 5)), 1.0,
          reason: 'charts-canvas-theming.image-and-golden-diff#8');

      // Identical images score 0 no matter which pixels are sampled.
      expect(comparator.distance(_solid(40, 40, _white), _solid(40, 40, _white)),
          0.0, reason: 'charts-canvas-theming.image-and-golden-diff#8');

      // Black against white: every sampled pixel contributes 255 on each of
      // r, g and b (alpha is equal), so a full sample would score
      // 765 / (255 * 16) = 0.1875 and a 1-in-4 sample a quarter of that.
      final d = comparator.distance(
        _solid(200, 200, _white),
        _solid(200, 200, _black),
      );
      expect(d, closeTo(0.1875 / 4, 0.005),
          reason: 'charts-canvas-theming.image-and-golden-diff#8');
      expect(comparator.exceedsCutoff(d), isTrue,
          reason: 'charts-canvas-theming.image-and-golden-diff#8');
    });
  });
}

const Color _transparent = Color(0.0, 0.0, 0.0, 0.0);
