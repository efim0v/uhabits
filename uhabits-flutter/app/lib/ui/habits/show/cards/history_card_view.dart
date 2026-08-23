/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/HistoryCardView.kt
/// and res/layout/show_habit_history.xml.
///
/// The calendar card: a title, a 160dp core `HistoryChart` and a borderless
/// "Edit" button underneath. The chart is already ported, and
/// `HistoryCardPresenter` is itself the chart's `OnDateClickedListener`, so
/// this widget hands the presenter straight to the chart and forwards the edit
/// button to `onClickEditButton`.
library;

// uhabits_core exports neither lib/src/ui/screens nor lib/src/ui/views yet.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/history_card.dart';
import 'package:uhabits_core/src/ui/views/history_chart.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../../l10n/app_localizations.dart';
import '../../../core_view.dart';
import '../../list/list_header.dart' show IntlLocalDateFormatter;
import 'score_card_view.dart';

export 'package:uhabits_core/src/ui/screens/habits/show/views/history_card.dart'
    show HistoryCardPresenter, HistoryCardScreen, HistoryCardState;

class HistoryCardView extends StatelessWidget {
  const HistoryCardView({
    required this.state,
    this.listener,
    this.onClickEditButton,
    this.dateFormatter,
    this.dataOffset = 0,
    super.key,
  });

  /// show_habit_history.xml: `android:layout_height="160dp"`.
  static const double chartHeight = 160.0;

  /// `android:textColor="@color/grey_400"` on the edit button.
  static const Color editButtonColor = Color(0xFFBDBDBD);

  /// `android:textSize="@dimen/smallTextSize"`, 14sp.
  static const double editButtonFontSize = 14.0;

  static const Key editButtonKey = Key('showHabitHistoryEdit');

  final HistoryCardState state;

  /// `HistoryCardPresenter` implements `OnDateClickedListener`; pass it here
  /// and a tap on a calendar cell lands in the presenter with the date the
  /// chart hit-tested.
  final OnDateClickedListener? listener;

  /// `binding.edit.setOnClickListener { presenter.onClickEditButton() }`.
  final VoidCallback? onClickEditButton;

  final core.LocalDateFormatter? dateFormatter;

  /// `setState` replaces the whole `HistoryChart`, which resets its own
  /// `dataOffset` to 0 (`show-habit.chart-scrolling#7`).
  final int dataOffset;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final chart = HistoryChart(
      today: state.today,
      paletteColor: state.color,
      theme: state.theme,
      dateFormatter: dateFormatter ?? IntlLocalDateFormatter.of(context),
      series: state.series,
      defaultSquare: state.defaultSquare,
      notesIndicators: state.notesIndicators,
      firstWeekday: state.firstWeekday,
    )..dataOffset = dataOffset;
    if (listener != null) chart.onDateClickedListener = listener!;

    return ChartCard(
      theme: state.theme,
      title: l10n.calendar,
      titleColor: state.theme.colorOf(state.color),
      // `android:paddingBottom="0dp"` on the history card only.
      padding: ChartCard.cardPadding.copyWith(bottom: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: chartHeight,
            width: double.infinity,
            child: CoreView(view: chart),
          ),
          // `style="?android:borderlessButtonStyle"`, `layout_gravity="center"`.
          TextButton(
            key: editButtonKey,
            onPressed: onClickEditButton,
            child: Text(
              l10n.edit,
              style: const TextStyle(
                color: editButtonColor,
                fontSize: editButtonFontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
