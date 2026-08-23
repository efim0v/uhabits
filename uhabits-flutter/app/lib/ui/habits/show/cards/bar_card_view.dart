/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/BarCardView.kt
/// and res/layout/show_habit_bar.xml.
///
/// Despite the class name the card is titled "History": one bar per bucket,
/// summing the computed entries in that bucket. The chart itself is the
/// already-ported core `BarChart`, so this file only wires the state into it
/// and picks which of the two spinners is on screen.
library;

// uhabits_core exports neither lib/src/ui/screens nor lib/src/ui/views yet.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/bar_card.dart';
import 'package:uhabits_core/src/ui/views/bar_chart.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../../l10n/app_localizations.dart';
import '../../../common/scrollable_chart.dart';
import '../../list/list_header.dart' show IntlLocalDateFormatter;
import 'score_card_view.dart';

export 'package:uhabits_core/src/ui/screens/habits/show/views/bar_card.dart'
    show BarCardPresenter, BarCardScreen, BarCardState;

/// The Bar card: a title, one of two bucket spinners and a 220dp [BarChart]
/// inside its scroller.
///
/// Android inflates both spinners and hides the one the habit type does not
/// use; only the visible one is built here, and the state carries both
/// positions either way.
///
/// `show_habit_bar.xml` gives `@+id/chart` as an `AndroidDataView`, so the
/// chart is scrollable: a horizontal drag walks it backwards through buckets
/// (`show-habit.chart-scrolling#1`,
/// `audit3.charts-on-the-habit-detail-screen#1`). Every `setState` calls
/// `binding.chart.resetDataOffset()`, which is why the card is a
/// [StatefulWidget] — the scroller position outlives a rebuild, and the arrival
/// of a new [BarCardState] is what puts it back at the newest bucket
/// (`show-habit.chart-scrolling#4`).
class BarCardView extends StatefulWidget {
  const BarCardView({
    required this.state,
    this.onNumericalSpinnerPosition,
    this.onBoolSpinnerPosition,
    this.dateFormatter,
    this.dataOffset = 0,
    super.key,
  });

  /// show_habit_bar.xml: `android:layout_height="220dp"`.
  static const double chartHeight = 220.0;

  /// `@+id/numericalSpinner`, the one with a Day option.
  static const Key numericalSpinnerKey = Key('showHabitBarNumericalSpinner');

  /// `@+id/boolSpinner`, the one without.
  static const Key boolSpinnerKey = Key('showHabitBarBoolSpinner');

  final BarCardState state;

  final ValueChanged<int>? onNumericalSpinnerPosition;

  final ValueChanged<int>? onBoolSpinnerPosition;

  final core.LocalDateFormatter? dateFormatter;

  /// The bucket the chart opens on, before anything is dragged.
  ///
  /// `binding.chart.resetDataOffset()` runs on every `setState`, so the real
  /// screen always passes 0 here (`show-habit.bar-card#7`); a non-zero value is
  /// a caller that already knows which bucket to open on.
  final int dataOffset;

  @override
  State<BarCardView> createState() => _BarCardViewState();
}

class _BarCardViewState extends State<BarCardView> {
  /// `binding.chart`, the scroller the card resets.
  final ScrollableChartController _controller = ScrollableChartController();

  @override
  void didUpdateWidget(BarCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `setState(state)` — the state object, not the Flutter method — ends with
    // `binding.chart.resetDataOffset()`, so any refresh at all jumps back to
    // the most recent bucket (`show-habit.chart-scrolling#4`).
    if (!identical(widget.state, oldWidget.state)) _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final state = widget.state;
    final color = state.theme.colorOf(state.color);

    final chart = BarChart(
      state.theme,
      widget.dateFormatter ?? IntlLocalDateFormatter.of(context),
    )
      // `series = mutableListOf(state.entries.map { it.value / 1000.0 })`.
      // BarChart dereferences `maxOrNull()!!` on every series, so an empty
      // entry list throws — upstream does too, and the presenter never
      // produces one: getByInterval always yields at least today.
      ..series = <List<double>>[
        <double>[
          for (final entry in state.entries) entry.value / 1000.0,
        ],
      ]
      ..colors = <core.Color>[state.theme.color(state.color.paletteIndex)]
      ..axis = <core.LocalDate>[
        for (final entry in state.entries) entry.date,
      ]
      ..dataOffset = widget.dataOffset;

    return ChartCard(
      theme: state.theme,
      // R.string.history — the card is not titled "Bar".
      title: l10n.history,
      titleColor: color,
      spinner: state.isNumerical
          ? BucketSpinner(
              key: BarCardView.numericalSpinnerKey,
              labels: bucketLabels(l10n),
              value: state.numericalSpinnerPosition,
              theme: state.theme,
              onChanged: widget.onNumericalSpinnerPosition,
            )
          : BucketSpinner(
              key: BarCardView.boolSpinnerKey,
              labels: bucketLabelsWithoutDay(l10n),
              value: state.boolSpinnerPosition,
              theme: state.theme,
              onChanged: widget.onBoolSpinnerPosition,
            ),
      child: SizedBox(
        height: BarCardView.chartHeight,
        // `android:id="@+id/chart"` is an AndroidDataView: the chart is the
        // scroller's view, and the offset is written back into it
        // (`show-habit.chart-scrolling#1`).
        child: ScrollableChart(
          view: chart,
          controller: _controller,
          initialDataOffset: widget.dataOffset,
          maxDataOffset: ScrollableChart.dataViewMaxDataOffset,
        ),
      ),
    );
  }
}
