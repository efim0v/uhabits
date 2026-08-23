/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/ScoreCardView.kt,
/// the chart it hosts
/// (uhabits-android/.../activities/common/views/ScoreChart.kt) and
/// res/layout/show_habit_score.xml.
///
/// This file also carries the three things every chart card of the show-habit
/// screen shares — the `@style/Card` chrome, the bucket spinner and the small
/// pieces of arithmetic that translate an Android `Paint` into the core
/// [core.Canvas]. The slice may only create the six `*_card_view.dart` files
/// listed for it, so they live with the score card (the archetypal chart card:
/// title, spinner, chart) and the other five import them from here.
library;

// uhabits_core exports neither lib/src/ui/screens nor lib/src/ui/views yet.
// ignore_for_file: implementation_imports

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/score_card.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../../l10n/app_localizations.dart';
import '../../../../platform/flutter_canvas.dart' show TransparencyCanvas;
import '../../../core_view.dart';
import '../../list/list_header.dart' show IntlLocalDateFormatter;

export 'package:uhabits_core/src/ui/screens/habits/show/views/score_card.dart'
    show ScoreCardPresenter, ScoreCardScreen, ScoreCardState;

// ---------------------------------------------------------------------------
// Shared card chrome
// ---------------------------------------------------------------------------

/// The core [core.Color] carries normalised channels; `dart:ui` wants bytes.
/// Same rounding as [core.Color.toInt] and as `FlutterCanvas.setColor`.
Color toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );

/// `android.graphics.Paint.fontSpacing` divided by the text size, for the
/// platform default typeface.
///
/// The four legacy charts of this slice (score, frequency, streak, target) lay
/// their footers out in multiples of `em = paint.fontSpacing`, a metric the
/// core [core.Canvas] does not expose. Roboto reports ascent -0.927 em and
/// descent 0.244 em, so a line box is about 1.171 text sizes tall.
const double chartFontSpacing = 1.171;

/// Converts an Android text baseline into the y the core [core.Canvas] wants.
///
/// `android.graphics.Canvas.drawText` anchors text on its baseline;
/// [core.Canvas.drawText] anchors it on its visual centre. The two differ by
/// `-(ascent + descent) / 2`, i.e. about 0.34 text sizes — which is also what
/// `TargetChart` computes by hand as `yTextAdjust`. Every baseline expression
/// copied from the Kotlin is therefore kept verbatim and passed through here,
/// so the arithmetic stays comparable to the original while the glyphs land
/// where Android puts them.
double chartTextCenter(double baselineY, double fontSize) =>
    baselineY - 0.34 * fontSize;

/// The `@style/Card` chrome of show_habit.xml, plus the `@style/CardHeader`
/// title row.
///
/// Android applies the style to the card *view* from the parent layout
/// (`style="@style/Card"` on each `…CardView` element), so it is part of what
/// the card looks like on screen rather than of the screen's own layout: the
/// widgets in this slice carry it, and the screen only stacks them.
class ChartCard extends StatelessWidget {
  const ChartCard({
    required this.theme,
    required this.title,
    required this.titleColor,
    required this.child,
    this.spinner,
    this.padding = cardPadding,
    super.key,
  });

  /// `@style/CardCommon`: paddingLeft/Top 16dp, paddingRight 4dp,
  /// paddingBottom 16dp.
  static const EdgeInsets cardPadding =
      EdgeInsets.only(left: 16, top: 16, right: 4, bottom: 16);

  /// `@style/Card`: marginLeft/Right 3dp, and marginBottom 1dp (CardCommon's
  /// 3dp is overridden).
  static const EdgeInsets cardMargin =
      EdgeInsets.only(left: 3, right: 3, bottom: 1);

  /// `@style/Card`: `android:elevation` 1dp.
  static const double elevation = 1.0;

  /// `@style/CardHeader`: `@dimen/regularTextSize`, 16sp.
  static const double titleFontSize = 16.0;

  /// `@style/CardHeader`: `layout_marginBottom` 12dp.
  static const double titleMarginBottom = 12.0;

  final core.Theme theme;

  final String title;

  /// `binding.title.setTextColor(theme.color(state.color).toInt())` — every
  /// card tints its title with the habit colour.
  final core.Color titleColor;

  /// The `AppCompatSpinner` pinned to the top-right corner, when the card has
  /// one.
  final Widget? spinner;

  final Widget child;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: cardMargin,
      child: Material(
        color: toFlutterColor(theme.cardBackgroundColor),
        elevation: elevation,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: titleMarginBottom),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          color: toFlutterColor(titleColor),
                        ),
                      ),
                    ),
                    ?spinner,
                  ],
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// The `AppCompatSpinner` of show_habit_score.xml / show_habit_bar.xml.
///
/// `@style/SmallSpinner` is `?attr/contrast60` text at `@dimen/smallTextSize`
/// (14sp); the ported [core.Theme] spells contrast60
/// [core.Theme.mediumContrastTextColor].
///
/// One upstream behaviour is deliberately *not* reproduced: an Android
/// `Spinner` fires `onItemSelected` when `setSelection` is called from
/// `setState`, so the presenter re-persists and re-refreshes on every state
/// push (`show-habit.score-card#7`). A Flutter [DropdownButton] only reports a
/// user choice, so [onChanged] fires once per tap.
class BucketSpinner extends StatelessWidget {
  const BucketSpinner({
    required this.labels,
    required this.value,
    required this.theme,
    this.onChanged,
    super.key,
  });

  /// `@dimen/smallTextSize`.
  static const double fontSize = 14.0;

  final List<String> labels;

  final int value;

  final core.Theme theme;

  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final color = toFlutterColor(theme.mediumContrastTextColor);
    return DropdownButton<int>(
      value: value.clamp(0, labels.length - 1),
      isDense: true,
      underline: const SizedBox.shrink(),
      icon: Icon(Icons.arrow_drop_down, size: 18, color: color),
      style: TextStyle(fontSize: fontSize, color: color),
      items: <DropdownMenuItem<int>>[
        for (var i = 0; i < labels.length; i++)
          DropdownMenuItem<int>(value: i, child: Text(labels[i])),
      ],
      onChanged: onChanged == null
          ? null
          : (int? position) {
              if (position != null) onChanged!(position);
            },
    );
  }
}

/// `R.array.strengthIntervalNames`: Day, Week, Month, Quarter, Year.
List<String> bucketLabels(L10n l10n) => <String>[
      l10n.day,
      l10n.week,
      l10n.month,
      l10n.quarter,
      l10n.year,
    ];

/// `R.array.strengthIntervalNamesWithoutDay`.
List<String> bucketLabelsWithoutDay(L10n l10n) => <String>[
      l10n.week,
      l10n.month,
      l10n.quarter,
      l10n.year,
    ];

// ---------------------------------------------------------------------------
// ScoreChart
// ---------------------------------------------------------------------------

/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/ScoreChart.kt.
///
/// A line of ring markers over a five-row percentage grid, with a one- or
/// two-line date footer. Android draws it with `android.graphics.Paint` onto a
/// `View`; this rewrite speaks the core [core.Canvas] so [CoreView] can host
/// it, which forces three substitutions and nothing else:
///
///  * `paint.fontSpacing` becomes [chartFontSpacing] times the text size, and
///    every baseline goes through [chartTextCenter];
///  * `canvas.drawOval` of a square rect becomes [core.Canvas.fillCircle] of
///    the inscribed circle, which is the same shape;
///  * the transparency path (an offscreen ARGB_8888 bitmap so that the marker
///    hole can be punched with `PorterDuff.CLEAR`) becomes a `saveLayer` on the
///    Flutter canvas, reached through the [TransparencyCanvas] capability. It is
///    off by default — the show-habit card draws over an opaque `cardBgColor`
///    and wants the hole *overpainted* — and a canvas that cannot offer the
///    capability falls back to the same opaque path
///    (`charts-canvas-theming.score-chart#16`).
///
/// Everything else — the integer truncations, the shared `maxDayWidth` /
/// `maxMonthWidth` getters that both measure month names, the marker drawn one
/// column late — is kept as it is upstream.
class ScoreChartView extends core.View {
  ScoreChartView({
    this.scores,
    required this.color,
    required this.theme,
    required this.dateFormatter,
    required this.bucketSize,
    this.dataOffset = 0,
    this.isTransparencyEnabled = false,
  });

  /// Newest bucket first, as [ScoreCardState.scores] delivers it.
  ///
  /// Kotlin: `private var scores: List<Score>? = null`, filled in by
  /// `setScores`. Null is the state the view is in between construction and
  /// the first `setState`, and [draw] returns immediately in it
  /// (`charts-canvas-theming.score-chart#6`).
  final List<core.Score>? scores;

  final core.Color color;

  final core.Theme theme;

  final core.LocalDateFormatter dateFormatter;

  /// One of [ScoreCardPresenter.bucketSizes]; only the footer reads it.
  final int bucketSize;

  /// Columns scrolled into the past. Horizontal scrolling itself is not wired
  /// up yet (`show-habit.chart-scrolling`), so the host always passes 0.
  final int dataOffset;

  /// `setIsTransparencyEnabled(enabled)`.
  ///
  /// False on the show-habit card, which sits on an opaque card; true is the
  /// widget case, where the marker has to punch a real hole so the wallpaper
  /// shows through it (`charts-canvas-theming.score-chart#16`).
  final bool isTransparencyEnabled;

  /// Whether [draw] will really take the transparent path on [canvas].
  ///
  /// `isTransparencyEnabled` alone is not enough: the offscreen layer and the
  /// two blend modes are a capability of the backend, and a canvas without it
  /// draws the opaque marker rather than a wrong one.
  bool usesTransparencyOn(core.Canvas canvas) =>
      isTransparencyEnabled && canvas is TransparencyCanvas;

  @override
  void draw(core.Canvas canvas) {
    // `if (scores == null) return` — the first statement of onDraw, and the
    // reason a freshly inflated ScoreChart paints nothing at all
    // (`charts-canvas-theming.score-chart#6`).
    final scores = this.scores;
    if (scores == null) return;
    // `if (isTransparencyEnabled) { if (internalDrawingCache == null)
    // reallocateCache(); activeCanvas = cacheCanvas;
    // internalDrawingCache!!.eraseColor(Color.TRANSPARENT) }`: everything below
    // is drawn onto a transparent buffer of the view's size, which is then
    // blitted onto the real canvas (`charts-canvas-theming.score-chart#16`).
    final transparent = usesTransparencyOn(canvas);
    if (transparent) (canvas as TransparencyCanvas).beginTransparencyLayer();
    _drawChart(canvas, scores, transparent: transparent);
    // `if (activeCanvas !== canvas) canvas.drawBitmap(internalDrawingCache, …)`.
    if (transparent) (canvas as TransparencyCanvas).endTransparencyLayer();
  }

  void _drawChart(
    core.Canvas canvas,
    List<core.Score> scores, {
    required bool transparent,
  }) {
    final width = canvas.getWidth();
    var height = canvas.getHeight();
    // onSizeChanged: `if (height < 9) height = 200`.
    if (height < 9) height = 200.0;
    if (width <= 0) return;

    // `pText.textSize = min(height * 0.06f, tinyTextSize)`; the ported Theme
    // spells Android's 10sp tinyTextSize `smallTextSize`.
    final textSize = math.min(height * 0.06, theme.smallTextSize);
    canvas.setFontSize(textSize);
    final em = textSize * chartFontSpacing;
    final footerHeight = (3 * em).toInt();
    final paddingTop = em.toInt();
    final baseSize = (height - footerHeight - paddingTop) ~/ 8;
    if (baseSize <= 0) return;

    // Both getters measure month names — `maxDayWidth` never looks at a day
    // number. Kept as two statements so the Kotlin lines up.
    final maxMonthWidth = _maxMonthWidth(canvas);
    var columnWidth = baseSize.toDouble();
    columnWidth = math.max(columnWidth, maxMonthWidth * 1.5);
    columnWidth = math.max(columnWidth, maxMonthWidth * 1.2);
    final nColumns = (width / columnWidth).toInt();
    if (nColumns <= 0) return;
    columnWidth = width / nColumns;
    final columnHeight = 8 * baseSize;

    _drawGrid(canvas, nColumns * columnWidth, paddingTop, columnHeight, em,
        textSize, math.min(1.0, baseSize * 0.05));

    var lastPrintedMonth = '';
    var lastPrintedYear = '';
    var skipYear = 0;
    double? prevCx;
    double? prevCy;

    for (var k = 0; k < nColumns; k++) {
      final offset = nColumns - k - 1 + dataOffset;
      if (offset < 0 || offset >= scores.length) continue;
      final score = scores[offset].value;
      final date = scores[offset].date;

      // Kotlin does this in Ints, `baseSize / 2` included.
      final markerHeight = (columnHeight * score).toInt();
      final left = k * columnWidth + (columnWidth - baseSize) / 2;
      final top = (paddingTop + columnHeight - markerHeight - baseSize ~/ 2)
          .toDouble();
      final cx = left + baseSize / 2.0;
      final cy = top + baseSize / 2.0;

      if (prevCx != null) {
        canvas.setColor(color);
        canvas.setStrokeWidth(baseSize * 0.1);
        canvas.drawLine(prevCx, prevCy!, cx, cy);
        // The marker of a column is drawn while the next one is processed, so
        // a column skipped for want of data leaves the previous marker
        // unpainted until some later column has data.
        _drawMarker(canvas, prevCx, prevCy, baseSize,
            transparent: transparent);
      }
      if (k == nColumns - 1) {
        _drawMarker(canvas, cx, cy, baseSize, transparent: transparent);
      }
      prevCx = cx;
      prevCy = cy;

      // drawFooter, against the full-height column rect.
      final bottom = (paddingTop + columnHeight).toDouble();
      final centerX = k * columnWidth + columnWidth / 2;
      final yearText = date.year.toString();
      final monthText = dateFormatter.shortMonthName(date);
      final dayText = date.day.toString();
      var shouldPrintYear = true;
      if (yearText == lastPrintedYear) shouldPrintYear = false;
      if (bucketSize >= 365 && date.year % 2 != 0) shouldPrintYear = false;
      if (skipYear > 0) {
        skipYear--;
        shouldPrintYear = false;
      }
      canvas.setColor(theme.mediumContrastTextColor);
      canvas.setTextAlign(core.TextAlign.center);
      if (shouldPrintYear) {
        lastPrintedYear = yearText;
        lastPrintedMonth = '';
        canvas.drawText(
          yearText,
          centerX,
          chartTextCenter(bottom + em * 2.2, textSize),
        );
        skipYear = 1;
      }
      if (bucketSize < 365) {
        final String text;
        if (monthText != lastPrintedMonth) {
          lastPrintedMonth = monthText;
          text = monthText;
        } else {
          text = dayText;
        }
        canvas.drawText(
          text,
          centerX,
          chartTextCenter(bottom + em * 1.2, textSize),
        );
      }
    }
  }

  /// `drawGrid`: five labelled rows, plus a closing line under the last one.
  void _drawGrid(
    core.Canvas canvas,
    double right,
    int paddingTop,
    int columnHeight,
    double em,
    double textSize,
    double strokeWidth,
  ) {
    const nRows = 5;
    final rowHeight = columnHeight / nRows;
    var top = paddingTop.toDouble();
    canvas.setTextAlign(core.TextAlign.left);
    for (var i = 0; i < nRows; i++) {
      canvas.setColor(theme.mediumContrastTextColor);
      canvas.drawText(
        '${100 - i * 100 ~/ nRows}%',
        0.5 * em,
        chartTextCenter(top + 1.0 * em, textSize),
      );
      canvas.setColor(theme.lowContrastTextColor);
      canvas.setStrokeWidth(strokeWidth);
      canvas.drawLine(0.0, top, right, top);
      top += rowHeight;
    }
    canvas.setColor(theme.lowContrastTextColor);
    canvas.setStrokeWidth(strokeWidth);
    canvas.drawLine(0.0, top, right, top);
  }

  /// `drawMarker`: the baseSize square inset by 0.225 and filled with the card
  /// background, then inset by a further 0.1 and filled with the habit colour.
  /// `drawMarker`: two concentric ovals, the outer one the card background and
  /// the inner one the habit colour, so the marker reads as a ring with a hole
  /// (`charts-canvas-theming.score-chart#11`).
  ///
  /// With transparency on, `setModeOrColor` replaces both colours with an
  /// xfermode: CLEAR for the hole and SRC for the ring, so the hole is a real
  /// one and the ring's own alpha is written rather than composited.
  void _drawMarker(
    core.Canvas canvas,
    double cx,
    double cy,
    int baseSize, {
    bool transparent = false,
  }) {
    final outer = baseSize / 2.0 - baseSize * 0.225;
    if (transparent) {
      final layer = canvas as TransparencyCanvas;
      layer.clearCircle(cx, cy, outer);
      canvas.setColor(color);
      layer.srcCircle(cx, cy, outer - baseSize * 0.1);
      return;
    }
    canvas.setColor(theme.cardBackgroundColor);
    canvas.fillCircle(cx, cy, outer);
    canvas.setColor(color);
    canvas.fillCircle(cx, cy, outer - baseSize * 0.1);
  }

  double _maxMonthWidth(core.Canvas canvas) {
    var maxWidth = 0.0;
    for (var i = 1; i <= 12; i++) {
      final name = dateFormatter.shortMonthName(core.LocalDate.ymd(2020, i, 1));
      maxWidth = math.max(maxWidth, canvas.measureText(name));
    }
    return maxWidth;
  }

  /// ```kotlin
  /// fun populateWithRandomData() {
  ///     val random = Random()
  ///     val newScores = LinkedList<Score>()
  ///     var previous = 0.5
  ///     val today = getToday()
  ///     for (i in 1..99) {
  ///         val step = 0.1
  ///         var current = previous + random.nextDouble() * step * 2 - step
  ///         current = max(0.0, min(1.0, current))
  ///         newScores.add(Score(today.minus(i), current))
  ///         previous = current
  ///     }
  ///     scores = newScores
  /// }
  /// ```
  ///
  /// Ninety-nine scores walking backwards from today — the first is
  /// *yesterday*, because the loop starts at 1 — as a random walk of step 0.1
  /// clamped to 0..1 and starting at 0.5
  /// (`charts-canvas-theming.score-chart#18`). The clamp feeds back into the
  /// walk: `previous` is the clamped value, not the raw one.
  ///
  /// Returned rather than installed, because the Dart view takes its scores in
  /// the constructor; the generator is a seam so a test can pin the walk.
  static List<core.Score> populateWithRandomData({math.Random? random}) {
    final rand = random ?? math.Random();
    final newScores = <core.Score>[];
    var previous = 0.5;
    final today = core.getToday();
    for (var i = 1; i <= 99; i++) {
      const step = 0.1;
      var current = previous + rand.nextDouble() * step * 2 - step;
      current = math.max(0.0, math.min(1.0, current));
      newScores.add(core.Score(today.minus(i), current));
      previous = current;
    }
    return newScores;
  }
}

// ---------------------------------------------------------------------------
// ScoreCardView
// ---------------------------------------------------------------------------

/// The Score card: a title, the day/week/month/quarter/year spinner and a
/// 220dp [ScoreChartView].
///
/// `ScoreCardView.setState` + `setListener` collapse into the constructor: the
/// widget renders [state] and reports a spinner choice through
/// [onSpinnerPosition], which the screen hands to
/// `ScoreCardPresenter.onSpinnerPosition`.
class ScoreCardView extends StatelessWidget {
  const ScoreCardView({
    required this.state,
    this.onSpinnerPosition,
    this.dateFormatter,
    this.dataOffset = 0,
    super.key,
  });

  /// show_habit_score.xml: `android:layout_height="220dp"`.
  static const double chartHeight = 220.0;

  static const Key spinnerKey = Key('showHabitScoreSpinner');

  final ScoreCardState state;

  final ValueChanged<int>? onSpinnerPosition;

  /// Defaults to an [IntlLocalDateFormatter] for the ambient locale, the
  /// counterpart of `JavaLocalDateFormatter(Locale.getDefault())`.
  final core.LocalDateFormatter? dateFormatter;

  final int dataOffset;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final color = state.theme.colorOf(state.color);
    return ChartCard(
      theme: state.theme,
      title: l10n.score,
      titleColor: color,
      spinner: BucketSpinner(
        key: spinnerKey,
        labels: bucketLabels(l10n),
        value: state.spinnerPosition,
        theme: state.theme,
        onChanged: onSpinnerPosition,
      ),
      child: SizedBox(
        height: chartHeight,
        child: CoreView(
          view: ScoreChartView(
            scores: state.scores,
            color: color,
            theme: state.theme,
            dateFormatter: dateFormatter ?? IntlLocalDateFormatter.of(context),
            bucketSize: state.bucketSize,
            dataOffset: dataOffset,
          ),
        ),
      ),
    );
  }
}
