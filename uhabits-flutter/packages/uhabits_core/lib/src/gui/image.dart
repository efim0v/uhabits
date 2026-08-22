import 'dart:math';
import 'dart:typed_data';

import 'color.dart';

/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/Image.kt,
/// of the golden-image helper in
/// uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/ViewTestHelper.kt
/// and of the screenshot comparator in
/// uhabits-android/src/androidTest/java/org/isoron/uhabits/BaseViewTest.kt.
///
/// Everything here is pure Dart operating on raw pixel data: no image codec and
/// no `dart:ui`. Decoding a PNG baseline and encoding a failure dump are the
/// host's job — see [ImageExporter] and [GoldenImageLoader].

/// Compatibility alias for [Color].
///
/// The golden-diff port declared its own colour type while `color.dart` was
/// still being written; the canonical value type (with blending, contrast and
/// the companion constants) now lives next door and is what [Image] speaks.
typedef PixelColor = Color;

/// Writes [image] to [path]. The Kotlin `Image.export` is a suspend function
/// backed by ImageIO on the JVM and by `TODO("Not yet implemented")` on
/// Android; here it is supplied by the host so that the core stays codec-free.
typedef ImageExporter = Future<void> Function(Image image, String path);

/// Loads the baseline image stored at the given resource path, or returns null
/// when there is no such file. Mirrors
/// `fileOpener.openResourceFile(path).takeIf { it.exists() }?.toImage()`.
typedef GoldenImageLoader = Image? Function(String path);

abstract class Image {
  int get width;

  int get height;

  Color getPixel(int x, int y);

  void setPixel(int x, int y, Color color);

  Future<void> export(String path);

  /// Replaces every pixel of *this* image with the distance between it and the
  /// closest-matching pixel of [other] within a 5x5 window, so that the
  /// comparison tolerates up to 2px of sub-pixel shift.
  ///
  /// The receiver is mutated; [other] is left alone. Each pixel is read before
  /// it is overwritten, so the result does not depend on the traversal order.
  void diff(Image other) {
    if (width != other.width) {
      throw StateError('Width must match: $width !== ${other.width}');
    }
    if (height != other.height) {
      throw StateError('Height must match: $height !== ${other.height}');
    }

    for (var x = 0; x < width; x++) {
      for (var y = 0; y < height; y++) {
        final p1 = getPixel(x, y);
        var l = 1.0;
        for (var dx = -2; dx <= 2; dx++) {
          if (x + dx < 0 || x + dx >= width) continue;
          for (var dy = -2; dy <= 2; dy++) {
            if (y + dy < 0 || y + dy >= height) continue;
            final p2 = other.getPixel(x + dx, y + dy);
            l = min(l, (p1.luminosity - p2.luminosity).abs());
          }
        }
        setPixel(x, y, Color(l, l, l, 1.0));
      }
    }
  }

  double get averageLuminosity {
    var luminosity = 0.0;
    for (var x = 0; x < width; x++) {
      for (var y = 0; y < height; y++) {
        luminosity += getPixel(x, y).luminosity;
      }
    }
    return luminosity / (width * height);
  }
}

/// An [Image] backed by a raw RGBA8888 byte buffer, row-major, 4 bytes per
/// pixel — the layout both a decoded PNG and a Flutter `Image.toByteData`
/// hand over.
class RgbaImage extends Image {
  RgbaImage(
    this.width,
    this.height, {
    Uint8List? pixels,
    this.exporter,
  }) : pixels = pixels ?? Uint8List(width * height * 4) {
    if (this.pixels.length != width * height * 4) {
      throw ArgumentError('Expected ${width * height * 4} bytes for a '
          '${width}x$height RGBA image, got ${this.pixels.length}');
    }
  }

  @override
  final int width;

  @override
  final int height;

  final Uint8List pixels;

  final ImageExporter? exporter;

  @override
  Color getPixel(int x, int y) {
    final i = _offsetOf(x, y);
    return Color(
      pixels[i] / 255.0,
      pixels[i + 1] / 255.0,
      pixels[i + 2] / 255.0,
      pixels[i + 3] / 255.0,
    );
  }

  @override
  void setPixel(int x, int y, Color color) {
    final i = _offsetOf(x, y);
    pixels[i] = _toByte(color.red);
    pixels[i + 1] = _toByte(color.green);
    pixels[i + 2] = _toByte(color.blue);
    pixels[i + 3] = _toByte(color.alpha);
  }

  @override
  Future<void> export(String path) async {
    final exporter = this.exporter;
    if (exporter == null) {
      // Same posture as AndroidImage.export, which is TODO("Not yet
      // implemented"): the core cannot encode a PNG on its own.
      throw UnimplementedError(
          'export requires an ImageExporter supplied by the host');
    }
    await exporter(this, path);
  }

  int _offsetOf(int x, int y) {
    if (x < 0 || x >= width) {
      throw RangeError.range(x, 0, width - 1, 'x');
    }
    if (y < 0 || y >= height) {
      throw RangeError.range(y, 0, height - 1, 'y');
    }
    return (y * width + x) * 4;
  }

  /// Channels are stored as bytes, so they are rounded (as `AndroidImage`
  /// does) and clamped into the representable range.
  static int _toByte(double channel) {
    final value = (255 * channel).round();
    if (value < 0) return 0;
    if (value > 255) return 255;
    return value;
  }
}

/// A golden comparison that failed. The Kotlin helper calls `kotlin.test.fail`;
/// the core cannot depend on a test framework, so it throws this instead and
/// the caller turns it into a test failure.
class GoldenComparisonFailure implements Exception {
  GoldenComparisonFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// `distance >= 1.0` fails, as in ViewTestHelper.
const double goldenDistanceCutoff = 1.0;

bool goldenDistanceIsFailure(double distance) =>
    distance >= goldenDistanceCutoff;

/// The distance between a baseline and a freshly rendered image: the average
/// luminosity of the 5x5-tolerant diff, scaled by 100.
double goldenDistance(Image expectedImage, Image actualImage) {
  expectedImage.diff(actualImage);
  return expectedImage.averageLuminosity * 100;
}

/// Port of `assertRenders(path, canvas)`.
///
/// The Kotlin version takes a `Canvas` and starts with `canvas.toImage()`;
/// rendering belongs to the backend, so this port takes the rendered image
/// directly. Everything after that — loading the baseline twice, diffing the
/// second copy against the actual image, the 1.0 cutoff, the failure message
/// and the three /tmp/failed dumps — is reproduced as is.
Future<void> assertRenders(
  String path,
  Image actualImage, {
  required GoldenImageLoader loadResourceImage,
}) async {
  final failedActualPath = '/tmp/failed/$path';
  final failedExpectedPath =
      failedActualPath.replaceAll('.png', '.expected.png');
  final failedDiffPath = failedActualPath.replaceAll('.png', '.diff.png');

  final expectedImage = loadResourceImage(path);
  final diffImage = expectedImage == null ? null : loadResourceImage(path);
  if (expectedImage == null || diffImage == null) {
    await actualImage.export(failedActualPath);
    throw GoldenComparisonFailure(
        'Expected image file is missing. Actual image: $failedActualPath');
  }

  final distance = goldenDistance(diffImage, actualImage);
  if (goldenDistanceIsFailure(distance)) {
    await expectedImage.export(failedExpectedPath);
    await actualImage.export(failedActualPath);
    await diffImage.export(failedDiffPath);
    throw GoldenComparisonFailure('Images differ (distance=$distance)');
  }
}

/// `BaseViewTest.similarityCutoff`.
const double defaultSimilarityCutoff = 0.00018;

/// The looser cutoff `AndroidCanvasTest` raises it to. Several other Android
/// view tests raise it too (0.00025 and 0.00035).
const double androidCanvasSimilarityCutoff = 0.0005;

/// Port of the screenshot comparator in `BaseViewTest`.
///
/// A completely different metric from [goldenDistance]: it samples roughly one
/// pixel in four at random and sums the absolute per-channel ARGB differences,
/// with no tolerance for sub-pixel shifts. Kept because the Android golden
/// baselines under `uhabits-android/src/androidTest/assets/views/` were
/// accepted under it.
class AndroidScreenshotComparator {
  AndroidScreenshotComparator({
    Random? random,
    this.similarityCutoff = defaultSimilarityCutoff,
  }) : random = random ?? Random();

  final Random random;

  double similarityCutoff;

  /// The comparison is strict: a distance equal to the cutoff still passes.
  bool exceedsCutoff(double distance) => distance > similarityCutoff;

  double distance(Image b1, Image b2) {
    if (b1.width != b2.width) return 1.0;
    if (b1.height != b2.height) return 1.0;
    var distance = 0.0;
    for (var x = 0; x < b1.width; x++) {
      for (var y = 0; y < b1.height; y++) {
        if (random.nextInt(4) != 0) continue;
        final argb1 = _colorToArgb(b1.getPixel(x, y));
        final argb2 = _colorToArgb(b2.getPixel(x, y));
        distance += (argb1[0] - argb2[0]).abs().toDouble();
        distance += (argb1[1] - argb2[1]).abs().toDouble();
        distance += (argb1[2] - argb2[2]).abs().toDouble();
        distance += (argb1[3] - argb2[3]).abs().toDouble();
      }
    }
    distance /= 255.0 * 16 * b1.width * b1.height;
    return distance;
  }

  static List<int> _colorToArgb(Color color) {
    final c1 = color.toInt();
    return <int>[
      (c1 >> 24) & 0xff, // alpha
      (c1 >> 16) & 0xff, // red
      (c1 >> 8) & 0xff, // green
      c1 & 0xff, // blue
    ];
  }
}
