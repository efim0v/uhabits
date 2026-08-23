/// The golden-image asset inventory: which baselines exist, how big they are,
/// which of them a test still looks at, and the conventions they were captured
/// under.
///
/// `charts-canvas-theming.screenshot-baselines` is a rule set about *files*
/// rather than about code, and the files are in this repository, so every rule
/// below is checked against them directly: the PNG headers give the sizes, the
/// Kotlin test sources give the coverage, and the ported harness in
/// `lib/src/gui/image.dart` gives the failure-artifact paths.
///
/// The one clause with no counterpart in this port is named where it comes up:
/// there is no Android instrumentation harness here, so nothing writes bitmaps
/// into an on-device `test-screenshots` directory.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:uhabits_core/src/gui/color.dart';
import 'package:uhabits_core/src/gui/image.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// The repository root, found by walking up from wherever the test runner was
/// started.
Directory get _repoRoot {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/docs/parity/FEATURES.md').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Repository root not found from ${Directory.current}');
    }
    dir = parent;
  }
}

/// Width and height out of a PNG's IHDR chunk, which is always the first one.
({int width, int height}) _pngSize(File file) {
  final Uint8List bytes = file.readAsBytesSync();
  const signature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) {
      throw StateError('${file.path} is not a PNG');
    }
  }
  final data = ByteData.sublistView(bytes);
  return (width: data.getUint32(16), height: data.getUint32(20));
}

void main() {
  final root = _repoRoot;
  final core = Directory('${root.path}/uhabits-core/assets/test/views');
  final android =
      Directory('${root.path}/uhabits-android/src/androidTest/assets/views');

  void expectSize(Directory base, String path, int width, int height,
      {required String reason}) {
    final file = File('${base.path}/$path');
    expect(file.existsSync(), isTrue, reason: '$reason (missing $path)');
    final size = _pngSize(file);
    expect(<int>[size.width, size.height], <int>[width, height],
        reason: '$reason ($path)');
  }

  group('charts-canvas-theming.screenshot-baselines', () {
    test('#1 the core baselines, all rendered at pixelScale 2.0', () {
      expect(core.existsSync(), isTrue,
          reason: 'charts-canvas-theming.screenshot-baselines#1 — core '
              'baselines live under uhabits-core/assets/test/views/');

      // Every entry is twice the logical size the Kotlin test renders at, which
      // is what pixelScale 2.0 means.
      const expected = <String, List<int>>{
        'CanvasTest.png': <int>[1000, 800],
        'BarChart/base.png': <int>[600, 400],
        'BarChart/offset.png': <int>[600, 400],
        'BarChart/themeDark.png': <int>[600, 400],
        'BarChart/themeWidget.png': <int>[600, 400],
        'HistoryChart/base.png': <int>[800, 400],
        'HistoryChart/scroll.png': <int>[800, 400],
        'HistoryChart/themeDark.png': <int>[800, 400],
        'HistoryChart/themeWidget.png': <int>[800, 400],
        'HistoryChart/weekday.png': <int>[800, 400],
        'HistoryChart/small.png': <int>[400, 400],
        'CheckmarkButton/explicit.png': <int>[96, 96],
        'CheckmarkButton/implicit.png': <int>[96, 96],
        'CheckmarkButton/unchecked.png': <int>[96, 96],
        'NumberButton/render_above.png': <int>[96, 96],
        'NumberButton/render_below.png': <int>[96, 96],
        'NumberButton/render_zero.png': <int>[96, 96],
        'HabitListHeader/light.png': <int>[1200, 96],
        'Ring/draw1.png': <int>[120, 120],
      };
      for (final entry in expected.entries) {
        expectSize(core, entry.key, entry.value[0], entry.value[1],
            reason: 'charts-canvas-theming.screenshot-baselines#1');
      }

      // And nothing else: the inventory is the whole directory.
      final actual = core
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .map((f) => f.path.substring(core.path.length + 1))
          .toList()
        ..sort();
      expect(actual, expected.keys.toList()..sort(),
          reason: 'charts-canvas-theming.screenshot-baselines#1 — the listed '
              'files are the complete core inventory');

      // The chart baselines are exactly 2x their documented logical size.
      expect(_pngSize(File('${core.path}/BarChart/base.png')).width, 300 * 2,
          reason: 'charts-canvas-theming.screenshot-baselines#1 — BarChart '
              'renders at 300x200 logical');
      expect(_pngSize(File('${core.path}/HistoryChart/base.png')).width,
          400 * 2,
          reason: 'charts-canvas-theming.screenshot-baselines#1 — HistoryChart '
              'renders at 400x200 logical');
    });

    test('#2 only BarChart, HistoryChart and CanvasTest have live core tests',
        () {
      final tests = Directory('${root.path}/uhabits-core/src/commonTest');
      expect(tests.existsSync(), isTrue,
          reason: 'charts-canvas-theming.screenshot-baselines#2');

      // Which baseline directory each commonTest still renders against. Every
      // one of them names it either through the `val base = "views/X"`
      // constant the chart tests share, or as a literal "views/X.png".
      final referenced = <String>{};
      for (final file in tests.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.kt')) continue;
        final source = file.readAsStringSync();
        if (!source.contains('assertRenders(')) continue;
        for (final match
            in RegExp(r'val base = "views/([A-Za-z]+)"').allMatches(source)) {
          referenced.add(match.group(1)!);
        }
        for (final match
            in RegExp(r'"views/([A-Za-z]+)\.png"').allMatches(source)) {
          referenced.add(match.group(1)!);
        }
      }

      expect(referenced, <String>{'BarChart', 'HistoryChart', 'CanvasTest'},
          reason: 'charts-canvas-theming.screenshot-baselines#2 — those three '
              'are the only ones a commonTest still renders against');

      for (final orphan in <String>[
        'CheckmarkButton',
        'NumberButton',
        'HabitListHeader',
        'Ring',
      ]) {
        expect(Directory('${core.path}/$orphan').existsSync(), isTrue,
            reason: 'charts-canvas-theming.screenshot-baselines#2 — $orphan '
                'still ships a baseline');
        expect(referenced.contains(orphan), isFalse,
            reason: 'charts-canvas-theming.screenshot-baselines#2 — but no '
                'test looks at it, so it is orphaned');
      }
    });

    test('#3 the Android instrumentation baselines, captured at density 2', () {
      expect(android.existsSync(), isTrue,
          reason: 'charts-canvas-theming.screenshot-baselines#3');

      const expected = <String, List<int>>{
        'CanvasTest.png': <int>[1000, 800],
        'common/FrequencyChart/render.png': <int>[600, 200],
        'common/FrequencyChart/renderDataOffset.png': <int>[600, 200],
        'common/FrequencyChart/renderTransparent.png': <int>[600, 200],
        'common/FrequencyChart/renderDifferentSize.png': <int>[400, 400],
        'common/RingView/render.png': <int>[200, 200],
        'common/RingView/renderDifferentParams.png': <int>[400, 400],
        'common/ScoreChart/render.png': <int>[600, 400],
        'common/ScoreChart/renderDataOffset.png': <int>[600, 400],
        'common/ScoreChart/renderMonthly.png': <int>[600, 400],
        'common/ScoreChart/renderTransparent.png': <int>[600, 400],
        'common/ScoreChart/renderYearly.png': <int>[600, 400],
        'common/ScoreChart/renderDifferentSize.png': <int>[400, 400],
        'common/StreakChart/render.png': <int>[600, 200],
        'common/StreakChart/renderTransparent.png': <int>[600, 200],
        'common/StreakChart/renderSmallSize.png': <int>[200, 200],
      };
      for (final entry in expected.entries) {
        expectSize(android, entry.key, entry.value[0], entry.value[1],
            reason: 'charts-canvas-theming.screenshot-baselines#3');
      }

      // dp * 2 = px: the 300x200dp ScoreChart test view is a 600x400 file, and
      // the 200x200dp different-size case a 400x400 one.
      expect(_pngSize(File('${android.path}/common/ScoreChart/render.png')),
          (width: 300 * 2, height: 200 * 2),
          reason: 'charts-canvas-theming.screenshot-baselines#3 — density 2');
      expect(
          _pngSize(
              File('${android.path}/common/RingView/renderDifferentParams.png')),
          (width: 200 * 2, height: 200 * 2),
          reason: 'charts-canvas-theming.screenshot-baselines#3');
    });

    test('#4 the list cells, the show-habit cards and the widgets', () {
      const expected = <String, List<int>>{
        // List cells.
        'habits/list/CheckmarkButtonView/render_explicit_check.png': <int>[
          96,
          96
        ],
        'habits/list/CheckmarkButtonView/render_implicit_check.png': <int>[
          96,
          96
        ],
        'habits/list/CheckmarkButtonView/render_unchecked.png': <int>[96, 96],
        'habits/list/NumberButtonView/render_above.png': <int>[96, 96],
        'habits/list/NumberButtonView/render_below.png': <int>[96, 96],
        'habits/list/NumberButtonView/render_zero.png': <int>[96, 96],
        'habits/list/NumberButtonView/render_unitless.png': <int>[96, 96],
        'habits/list/NumberButtonView/render_at_most_above.png': <int>[96, 96],
        'habits/list/NumberButtonView/render_at_most_below.png': <int>[96, 96],
        'habits/list/NumberButtonView/render_at_most_between.png': <int>[
          96,
          96
        ],
        'habits/list/CheckmarkPanelView/render.png': <int>[384, 96],
        'habits/list/NumberPanelView/render.png': <int>[384, 96],
        'habits/list/HeaderView/render.png': <int>[1200, 96],
        'habits/list/HeaderView/render_reverse.png': <int>[1200, 96],
        'habits/list/HabitCardView/render.png': <int>[800, 100],
        'habits/list/HabitCardView/render_changed.png': <int>[800, 100],
        'habits/list/HabitCardView/render_numerical.png': <int>[800, 100],
        'habits/list/HabitCardView/render_selected.png': <int>[800, 100],
        // Show-habit cards.
        'habits/show/FrequencyCard/render.png': <int>[800, 600],
        'habits/show/HistoryCard/render.png': <int>[800, 600],
        'habits/show/ScoreCard/render.png': <int>[800, 600],
        'habits/show/StreakCard/render.png': <int>[800, 600],
        'habits/show/OverviewCard/render.png': <int>[800, 300],
        // Widgets.
        'widgets/FrequencyWidget/render.png': <int>[400, 400],
        'widgets/HistoryWidget/render.png': <int>[400, 400],
        'widgets/ScoreWidget/render.png': <int>[400, 400],
        'widgets/StreakWidget/render.png': <int>[400, 400],
        'widgets/TargetWidget/render.png': <int>[400, 400],
        'widgets/CheckmarkWidget/render.png': <int>[150, 200],
        'widgets/CheckmarkWidgetView/checked.png': <int>[200, 250],
        'widgets/CheckmarkWidgetView/large_size.png': <int>[600, 600],
      };
      for (final entry in expected.entries) {
        expectSize(android, entry.key, entry.value[0], entry.value[1],
            reason: 'charts-canvas-theming.screenshot-baselines#4');
      }
    });

    test('#5 the Android fixtures use the fixed PaletteUtils colours', () {
      // The CSV palette, not the theme-resolved one, so a screenshot is
      // independent of which theme was in effect when it was captured.
      expect(const PaletteColor(0).toFixedAndroidColor(), 0xFFD32F2F,
          reason: 'charts-canvas-theming.screenshot-baselines#5 — index 0 is '
              '#D32F2F');
      expect(const PaletteColor(5).toFixedAndroidColor(), 0xFFAFB42B,
          reason: 'charts-canvas-theming.screenshot-baselines#5 — index 5 is '
              '#AFB42B');
      expect(const PaletteColor(0).toCsvColor(), '#D32F2F',
          reason: 'charts-canvas-theming.screenshot-baselines#5 — the fixed '
              'palette is the CSV palette');
      expect(const PaletteColor(5).toCsvColor(), '#AFB42B',
          reason: 'charts-canvas-theming.screenshot-baselines#5');

      // Theme-resolved colours are a different table, which is exactly why the
      // fixtures do not use them.
      expect(const PaletteColor(5).toFixedAndroidColor() & 0xFFFFFF,
          isNot(0xD32F2F),
          reason: 'charts-canvas-theming.screenshot-baselines#5');
    });

    test('#6 Locale.US and a fixed today of 2015-01-25', () {
      final today = LocalDate.ymd(2015, 1, 25);
      expect(today.dayOfWeek, DayOfWeek.sunday,
          reason: 'charts-canvas-theming.screenshot-baselines#6 — the fixed '
              'today the goldens were captured on is a Sunday');

      setToday(today);
      addTearDown(resetToday);
      expect(getToday(), today,
          reason: 'charts-canvas-theming.screenshot-baselines#6 — every core '
              'view reads getToday(), so the goldens pin it');

      // `createTestDateFormatter()` is `JavaLocalDateFormatter(Locale.US)`, and
      // its short forms are the three-letter English abbreviations baked into
      // the baselines.
      final formatter = _UsLocaleFormatter();
      expect(formatter.shortMonthName(today), 'Jan',
          reason: 'charts-canvas-theming.screenshot-baselines#6 — English '
              'three-letter month');
      expect(formatter.shortWeekdayName(today), 'Sun',
          reason: 'charts-canvas-theming.screenshot-baselines#6 — English '
              'three-letter weekday');
      for (var month = 1; month <= 12; month++) {
        expect(formatter.shortMonthName(LocalDate.ymd(2015, month, 1)),
            hasLength(3),
            reason: 'charts-canvas-theming.screenshot-baselines#6 — every '
                'short month name is three letters');
      }
      for (final weekday in DayOfWeek.values) {
        expect(formatter.shortWeekdayNameOf(weekday), hasLength(3),
            reason: 'charts-canvas-theming.screenshot-baselines#6 — and every '
                'short weekday name');
      }
    });

    test('#7 a failed comparison dumps the actual, expected and diff images '
        'under /tmp/failed', () async {
      // The ported `assertRenders` keeps the three paths verbatim. A missing
      // baseline takes the first branch: only the actual image is written, and
      // the message names it.
      final missing = <String>[];
      await expectLater(
        () => assertRenders(
          'views/Nowhere/render.png',
          _CapturingImage(missing),
          loadResourceImage: (_) => null,
        ),
        throwsA(isA<GoldenComparisonFailure>()),
        reason: 'charts-canvas-theming.screenshot-baselines#7',
      );
      expect(missing, <String>['/tmp/failed/views/Nowhere/render.png'],
          reason: 'charts-canvas-theming.screenshot-baselines#7 — the actual '
              'image goes to /tmp/failed/<path>');

      // A baseline that differs takes the second branch and writes all three.
      final written = <String>[];
      await expectLater(
        () => assertRenders(
          'views/BarChart/base.png',
          _CapturingImage(written, luminosity: 1.0),
          loadResourceImage: (_) => _CapturingImage(written, luminosity: 1.0),
        ),
        throwsA(isA<GoldenComparisonFailure>()),
        reason: 'charts-canvas-theming.screenshot-baselines#7',
      );
      expect(
        written.toSet(),
        <String>{
          '/tmp/failed/views/BarChart/base.png',
          '/tmp/failed/views/BarChart/base.expected.png',
          '/tmp/failed/views/BarChart/base.diff.png',
        },
        reason: 'charts-canvas-theming.screenshot-baselines#7 — <path>, '
            '<path>.expected.png and <path>.diff.png',
      );

      // The other half of the rule — the Android harness dumping bitmaps into
      // an external "test-screenshots" directory — has no counterpart: this
      // port has no Android instrumentation harness to dump from.
    });
  });
}

/// `JavaLocalDateFormatter(Locale.US)`, reduced to the two short forms the
/// baselines contain.
class _UsLocaleFormatter implements LocalDateFormatter {
  static const List<String> _shortMonths = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> _longMonths = <String>[
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const List<String> _shortWeekdays = <String>[
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', //
  ];

  static const List<String> _longWeekdays = <String>[
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', //
    'Thursday', 'Friday', 'Saturday',
  ];

  @override
  String shortWeekdayNameOf(DayOfWeek weekday) =>
      _shortWeekdays[weekday.daysSinceSunday];

  @override
  String shortWeekdayName(LocalDate date) => shortWeekdayNameOf(date.dayOfWeek);

  @override
  String shortMonthName(LocalDate date) => _shortMonths[date.month - 1];

  @override
  String longWeekdayNameOf(DayOfWeek weekday) =>
      _longWeekdays[weekday.daysSinceSunday];

  @override
  String longMonthName(LocalDate date) => _longMonths[date.month - 1];
}

/// An [Image] that records where it was exported to instead of writing a file.
class _CapturingImage extends Image {
  _CapturingImage(this.exports, {this.luminosity = 0.0});

  final List<String> exports;

  final double luminosity;

  @override
  int get width => 1;

  @override
  int get height => 1;

  @override
  double get averageLuminosity => luminosity;

  @override
  void diff(Image other) {}

  @override
  Future<void> export(String path) async => exports.add(path);

  @override
  Color getPixel(int x, int y) => const Color(0, 0, 0, 0);

  @override
  void setPixel(int x, int y, Color color) {}
}
