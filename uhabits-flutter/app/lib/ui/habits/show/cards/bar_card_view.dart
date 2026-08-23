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
import '../../../core_view.dart';
import '../../list/list_header.dart' show IntlLocalDateFormatter;
import 'score_card_view.dart';

export 'package:uhabits_core/src/ui/screens/habits/show/views/bar_card.dart'
    show BarCardPresenter, BarCardScreen, BarCardState;

/// The Bar card: a title, one of two bucket spinners and a 220dp [BarChart].
///
/// Android inflates both spinners and hides the one the habit type does not
/// use; only the visible one is built here, and the state carries both
/// positions either way.
class BarCardView extends StatelessWidget {
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

  /// `binding.chart.resetDataOffset()` runs on every `setState`, so the real
  /// screen always passes 0 here (`show-habit.bar-card#7`).
  final int dataOffset;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final color = state.theme.colorOf(state.color);

    final chart = BarChart(
      state.theme,
      dateFormatter ?? IntlLocalDateFormatter.of(context),
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
      ..dataOffset = dataOffset;

    return ChartCard(
      theme: state.theme,
      // R.string.history — the card is not titled "Bar".
      title: l10n.history,
      titleColor: color,
      spinner: state.isNumerical
          ? BucketSpinner(
              key: numericalSpinnerKey,
              labels: bucketLabels(l10n),
              value: state.numericalSpinnerPosition,
              theme: state.theme,
              onChanged: onNumericalSpinnerPosition,
            )
          : BucketSpinner(
              key: boolSpinnerKey,
              labels: bucketLabelsWithoutDay(l10n),
              value: state.boolSpinnerPosition,
              theme: state.theme,
              onChanged: onBoolSpinnerPosition,
            ),
      child: SizedBox(
        height: chartHeight,
        child: CoreView(view: chart),
      ),
    );
  }
}
