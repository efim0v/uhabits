/// Port of the *list* half of
/// `uhabits-android/.../widgets/activities/HabitPickerDialog.kt`.
///
/// ## Why half of an activity lives here
///
/// Upstream that class is one thing: an `APPWIDGET_CONFIGURE` activity that
/// reads `component.habitList`, filters it, shows the names in a `ListView` and
/// writes the choice into `WidgetPreferences`. The port has to cut it in two,
/// because the two halves now run in different processes and different
/// languages. The activity still exists — the launcher will only start an
/// `Activity`, and only an `Activity` can `setResult` — and it stays native; but
/// there is no habit catalogue in the launcher's process to list, so the list
/// itself is here, in the app, where the [core.HabitList] already is.
///
/// The native `HabitPickerDialog` therefore captures the widget id, launches
/// `uhabits://widget/configure?widgetId=<n>&filter=<all|boolean|numerical>` and
/// waits; `WidgetLinkRouter` picks that up and shows this dialog; and the
/// activity reads the outcome back out of shared storage. See
/// `app/android/.../widgets/activities/HabitPickerDialog.kt` for that side.
///
/// What is reproduced here, rule by rule:
///
///  * `widgets.config-picker#3` — [widgetPickerCandidates]: habitList in its
///    natural order, minus the archived, minus whatever the filter hides.
///  * `widgets.config-picker#7` — the empty state: a 250x150 centred message at
///    16sp, and no confirmation, so the launcher cancels the placement.
///  * `widgets.config-picker#8` — the list: habit names, nothing else.
///  * `widgets.config-picker#9` — one tap confirms; there is no Save button and
///    no multi-select.
///  * `widgets.config-picker#2` — `AndroidThemeSwitcher.applyDialog()` paints
///    the picker grey_900 in night mode; see [WidgetPickerMetrics].
library;

import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';

/// Which habits a picker may offer.
///
/// The three values are `HabitPickerDialog` and its two subclasses:
/// `shouldHideNumerical()` and `shouldHideBoolean()` are both false in the base
/// class, the first is true in `BooleanHabitPickerDialog` (the Streaks widget)
/// and the second in `NumericalHabitPickerDialog` (the Target widget) —
/// `widgets.config-picker#4`, `#5`, `#6`.
///
/// The names are `WidgetIntents.FILTER_ALL`, `FILTER_BOOLEAN` and
/// `FILTER_NUMERICAL`, which is how the choice travels in the deep link.
enum WidgetPickerFilter {
  all,
  boolean,
  numerical;

  /// The filter named by `WidgetIntents.FILTER_*`, or null for anything else.
  static WidgetPickerFilter? fromName(String? name) {
    for (final WidgetPickerFilter filter in WidgetPickerFilter.values) {
      if (filter.name == name) return filter;
    }
    return null;
  }

  /// `shouldHideNumerical()`.
  bool get hidesNumerical => this == WidgetPickerFilter.boolean;

  /// `shouldHideBoolean()`.
  bool get hidesBoolean => this == WidgetPickerFilter.numerical;

  /// `getEmptyMessage()`: R.string.no_habits, no_boolean_habits or
  /// no_numerical_habits.
  String emptyMessage(L10n l10n) {
    switch (this) {
      case WidgetPickerFilter.all:
        return l10n.noHabits;
      case WidgetPickerFilter.boolean:
        return l10n.noBooleanHabits;
      case WidgetPickerFilter.numerical:
        return l10n.noNumericalHabits;
    }
  }
}

/// `widgets.config-picker#3`, the loop verbatim:
///
/// ```kotlin
/// for (h in habitList) {
///     if (h.isArchived) continue
///     if (h.isNumerical and shouldHideNumerical()) continue
///     if (!h.isNumerical and shouldHideBoolean()) continue
///     habitIds.add(h.id!!)
///     habitNames.add(h.name)
/// }
/// ```
///
/// A habit with no id is dropped rather than crashing: upstream's `h.id!!`
/// would throw, and a habit the picker cannot name in the result is no use to
/// anybody. Every habit that reaches a picker has been saved, so this is
/// unreachable in practice.
List<core.Habit> widgetPickerCandidates(
  Iterable<core.Habit> habits,
  WidgetPickerFilter filter,
) {
  final List<core.Habit> candidates = <core.Habit>[];
  for (final core.Habit habit in habits) {
    if (habit.isArchived) continue;
    if (habit.isNumerical && filter.hidesNumerical) continue;
    if (!habit.isNumerical && filter.hidesBoolean) continue;
    if (habit.id == null) continue;
    candidates.add(habit);
  }
  return candidates;
}

/// The measurements `widget_empty_activity.xml` and
/// `AndroidThemeSwitcher.applyDialog()` fix.
abstract final class WidgetPickerMetrics {
  /// `R.color.grey_900`, which `applyDialog()` paints the window decor with in
  /// night mode (`widgets.config-picker#2`).
  static const Color nightBackgroundColor = Color(0xFF212121);

  /// The `layout_width` / `layout_height` of the empty message
  /// (`widgets.config-picker#7`).
  static const Size emptyMessageSize = Size(250, 150);

  /// `R.dimen.regularTextSize` (`widgets.config-picker#7`).
  static const double regularTextSize = 16;
}

/// Shows the picker and completes with the chosen habit, or null when the user
/// backs out (`widgets.config-picker#11`).
Future<core.Habit?> showWidgetPickerDialog(
  BuildContext context, {
  required Iterable<core.Habit> habits,
  WidgetPickerFilter filter = WidgetPickerFilter.all,
}) {
  return showDialog<core.Habit>(
    context: context,
    builder: (BuildContext context) =>
        WidgetPickerDialog(habits: habits, filter: filter),
  );
}

/// The picker itself, exposed for tests and for screens that own their route.
class WidgetPickerDialog extends StatelessWidget {
  const WidgetPickerDialog({
    super.key,
    required this.habits,
    this.filter = WidgetPickerFilter.all,
  });

  /// The whole habit list, unfiltered: `widgets.config-picker#3` is the
  /// picker's own job, not its caller's.
  final Iterable<core.Habit> habits;

  final WidgetPickerFilter filter;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final List<core.Habit> candidates = widgetPickerCandidates(habits, filter);

    // `widgets.config-picker#2`. `applyDialog()` branches on `isNightMode`
    // alone, so `DarkTheme` and `PureBlackTheme` are both painted grey_900.
    final bool isNightMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isNightMode
          ? WidgetPickerMetrics.nightBackgroundColor
          : null,
      // `widget_configure_activity` is a wrap_content LinearLayout, so the
      // dialog is as tall as its content and no taller.
      child: candidates.isEmpty
          ? _emptyMessage(l10n)
          : _habitList(context, candidates),
    );
  }

  /// `widgets.config-picker#7`: `R.layout.widget_empty_activity`, a 250dp x
  /// 150dp centred TextView at `R.dimen.regularTextSize`. Nothing here can
  /// confirm, so the activity finishes on RESULT_CANCELED and the launcher
  /// drops the placement.
  Widget _emptyMessage(L10n l10n) {
    // Material's Dialog imposes a 280dp minimum width, which would stretch a
    // bare SizedBox past the 250dp the layout fixes. The Align absorbs that
    // minimum and hands the box loose constraints, so it keeps its own size and
    // sits centred in whatever the dialog ends up being.
    return Align(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox(
        key: const ValueKey<String>('widget_picker_message'),
        width: WidgetPickerMetrics.emptyMessageSize.width,
        height: WidgetPickerMetrics.emptyMessageSize.height,
        child: Center(
          child: Text(
            filter.emptyMessage(l10n),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: WidgetPickerMetrics.regularTextSize,
            ),
          ),
        ),
      ),
    );
  }

  /// `widgets.config-picker#8` and `#9`: the names, one per row, and a tap that
  /// confirms that one habit on the spot.
  Widget _habitList(BuildContext context, List<core.Habit> candidates) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: candidates.length,
      itemBuilder: (BuildContext context, int index) {
        final core.Habit habit = candidates[index];
        return ListTile(
          key: ValueKey<String>('widget_picker_habit_${habit.id}'),
          title: Text(habit.name),
          onTap: () => Navigator.of(context).pop(habit),
        );
      },
    );
  }
}
