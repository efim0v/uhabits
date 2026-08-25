/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/HistoryCardView.kt
/// and res/layout/show_habit_history.xml.
///
/// The calendar card: a title, a 160dp core `HistoryChart` and a borderless
/// "Edit" button underneath. The chart is already ported, and this widget
/// forwards the edit button to `onClickEditButton`.
///
/// The chart deliberately gets no `OnDateClickedListener`. `setState` upstream
/// builds the `HistoryChart` without one, so it keeps the no-op default and
/// the card is read-only; `setListener(presenter)` wires only the Edit button,
/// and the presenter reaches a chart exactly once — in the history-editor
/// dialog the Edit button opens
/// (`audit3.the-calendar-card-on-the-habit#1`).
library;

// uhabits_core exports neither lib/src/ui/screens nor lib/src/ui/views yet.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/history_card.dart';
import 'package:uhabits_core/src/ui/views/history_chart.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../../l10n/app_localizations.dart';
import '../../../common/scrollable_chart.dart';
import '../../list/list_header.dart' show IntlLocalDateFormatter;
import 'score_card_view.dart';

export 'package:uhabits_core/src/ui/screens/habits/show/views/history_card.dart'
    show HistoryCardPresenter, HistoryCardScreen, HistoryCardState;

/// The Calendar card: a title, a scrollable 160dp `HistoryChart` and the Edit
/// button.
///
/// `show_habit_history.xml` gives `@+id/chart` as an `AndroidDataView`, so a
/// horizontal drag walks the calendar backwards through weeks
/// (`show-habit.chart-scrolling#1`,
/// `audit3.charts-on-the-habit-detail-screen#1`).
class HistoryCardView extends StatefulWidget {
  const HistoryCardView({
    required this.state,
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

  /// `binding.edit.setOnClickListener { presenter.onClickEditButton() }`.
  final VoidCallback? onClickEditButton;

  final core.LocalDateFormatter? dateFormatter;

  /// The column the calendar opens on, before anything is dragged.
  ///
  /// `setState` replaces the whole `HistoryChart`, which resets its own
  /// `dataOffset` to 0 (`show-habit.chart-scrolling#7`), so the screen always
  /// passes 0.
  final int dataOffset;

  @override
  State<HistoryCardView> createState() => _HistoryCardViewState();
}

class _HistoryCardViewState extends State<HistoryCardView> {
  /// `binding.chart`, the scroller the fresh chart is put back on.
  final ScrollableChartController _controller = ScrollableChartController();

  @override
  void didUpdateWidget(HistoryCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `setState` builds a brand-new HistoryChart, whose `dataOffset` starts at
    // 0: any refresh puts the calendar back on this week
    // (`show-habit.chart-scrolling#7`).
    //
    // Known deviation: upstream leaves the AndroidDataView scroller where it
    // was, so the *next* drag makes the calendar jump back to the column it had
    // been scrolled to before continuing. The port's host re-applies its
    // position to every fresh view it is handed (that is what
    // `show-habit.chart-scrolling#6` pins), so the two objects cannot disagree
    // here; resetting the scroller is what produces the visible half of #7.
    if (!identical(widget.state, oldWidget.state)) _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final state = widget.state;
    final chart = HistoryChart(
      today: state.today,
      paletteColor: state.color,
      theme: state.theme,
      dateFormatter:
          widget.dateFormatter ?? IntlLocalDateFormatter.of(context),
      series: state.series,
      defaultSquare: state.defaultSquare,
      notesIndicators: state.notesIndicators,
      intensities: state.intensities,
      firstWeekday: state.firstWeekday,
    )..dataOffset = widget.dataOffset;

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
            height: HistoryCardView.chartHeight,
            width: double.infinity,
            // `android:id="@+id/chart"` is an AndroidDataView, and the chart is
            // the view it scrolls (`show-habit.chart-scrolling#1`).
            child: ScrollableChart(
              view: chart,
              controller: _controller,
              initialDataOffset: widget.dataOffset,
              maxDataOffset: ScrollableChart.dataViewMaxDataOffset,
            ),
          ),
          // `style="?android:borderlessButtonStyle"`, `layout_gravity="center"`.
          TextButton(
            key: HistoryCardView.editButtonKey,
            onPressed: widget.onClickEditButton,
            child: Text(
              l10n.edit,
              style: const TextStyle(
                color: HistoryCardView.editButtonColor,
                fontSize: HistoryCardView.editButtonFontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
