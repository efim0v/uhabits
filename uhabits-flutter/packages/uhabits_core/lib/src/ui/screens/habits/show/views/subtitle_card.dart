/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/SubtitleCard.kt.
///
/// [SubtitleCardState] is a pure state object: `buildState` copies eight fields
/// off the habit and hands them to the view. What the Android
/// `SubtitleCardView` then *decides* with no Android in it — which FontAwesome
/// glyph the target arrow is, which labels are visible, how the reminder's
/// hour and minute wrap round the clock — is ported here as members on the
/// state rather than being left to the widget layer.
///
/// What is deliberately NOT here: anything that reads `Resources` or the
/// device locale. `SubtitleCardView.setState` builds its two remaining strings
/// from `formatFrequency(num, den, resources)` (EditHabitActivity.kt),
/// `resources.getString(R.string.reminder_off)` and `formatTime(context, hour,
/// minute)` (utils/DateExtensions.kt), all three of which are translated or
/// locale-formatted; inlining their English resource values here printed them
/// in English in all 47 languages
/// (`audit15.subtitle-card-frequency-and-off-are-hard-coded#1`,
/// `audit15.subtitle-card-reminder-time-ignores-the-device-locale#1`). They
/// live in app/lib/ui/habits/show/cards/subtitle_card_view.dart now. Neither
/// are text sizes, ems, ellipsizing, the FontAwesome typeface binding or the
/// layout itself: those are Android view attributes.
library;

import '../../../../../gui/color.dart';
import '../../../../../gui/font_awesome.dart';
import '../../../../../gui/theme.dart';
import '../../../../../models/frequency.dart';
import '../../../../../models/habit.dart';
import '../../../../../models/habit_type.dart';
import '../../../../../models/palette_color.dart';
import '../../../../../models/reminder.dart';
import '../../../../views/number_button.dart';

/// Kotlin: `data class SubtitleCardState`. The last three fields carry the
/// same defaults as the Kotlin declaration, which is what a boolean habit's
/// state is built with in practice.
class SubtitleCardState {
  SubtitleCardState({
    required this.color,
    required this.frequency,
    required this.isNumerical,
    required this.question,
    required this.reminder,
    this.targetValue = 0.0,
    this.targetType = NumericalHabitType.atLeast,
    this.unit = '',
    required this.theme,
  });

  final PaletteColor color;

  final Frequency frequency;

  final bool isNumerical;

  final String question;

  final Reminder? reminder;

  final double targetValue;

  final NumericalHabitType targetType;

  final String unit;

  final Theme theme;

  // -------------------------------------------------------------------------
  // SubtitleCardView.setState
  // -------------------------------------------------------------------------

  /// `binding.questionLabel.setTextColor(state.theme.color(state.color))`.
  Color get questionColor => theme.colorOf(color);

  /// The label is set VISIBLE and then set GONE again when the question is
  /// empty, so the end state is simply "visible iff there is a question".
  bool get isQuestionVisible => question.isNotEmpty;

  /// `"${state.targetValue.toShortString()} ${state.unit}"`, using the
  /// *Android* toShortString (the one built on DecimalFormat). The space is
  /// unconditional, so a habit with no unit gets a trailing space.
  String get targetText => '${targetValue.toShortStringAndroid()} $unit';

  /// The target icon and the target text are both GONE for boolean habits.
  bool get isTargetVisible => isNumerical;

  /// `fa_arrow_circle_up` for AT_LEAST, `fa_arrow_circle_down` otherwise.
  String get targetIconGlyph => targetIconGlyphFor(targetType);

  // -------------------------------------------------------------------------
  // Static helpers
  // -------------------------------------------------------------------------

  /// The clock arithmetic of `fun formatTime(context: Context, hours: Int,
  /// minutes: Int)` from
  /// uhabits-android/src/main/java/org/isoron/uhabits/utils/DateExtensions.kt.
  ///
  /// Kotlin builds a `Date` out of `(hours * 60 + minutes)` minutes since the
  /// Unix epoch and formats it with the formatter's zone forced to UTC, so the
  /// value wraps modulo a day: hour 25 prints as 01:00 and a negative hour
  /// walks backwards into the previous day. That wrapping is reproduced here,
  /// and it is the whole of what this function can say: the *pattern* comes
  /// from `DateFormat.getTimeFormat(context)`, which is built from the device
  /// locale and belongs to the widget layer
  /// (`audit15.subtitle-card-reminder-time-ignores-the-device-locale#1`, and
  /// `formatDeviceTime` in app/lib/platform/device_time_format.dart).
  static int minuteOfDay(int hour, int minute) {
    const minutesPerDay = 24 * 60;
    // Dart's `%` returns a non-negative result for a positive divisor, which
    // is exactly the calendar wrap-around Java's Date gives here.
    return (hour * 60 + minute) % minutesPerDay;
  }

  /// `binding.frequencyIcon`, `fa_calendar`.
  static const String frequencyIconGlyph = FontAwesome.calendar;

  /// `binding.reminderIcon`, `fa_bell_o`.
  static const String reminderIconGlyph = FontAwesome.bellO;

  /// Kotlin uses `when (state.targetType) { AT_LEAST -> up; else -> down }`,
  /// so anything that is not AT_LEAST gets the down arrow.
  static String targetIconGlyphFor(NumericalHabitType targetType) =>
      targetType == NumericalHabitType.atLeast
          ? FontAwesome.arrowCircleUp
          : FontAwesome.arrowCircleDown;

  @override
  bool operator ==(Object other) =>
      other is SubtitleCardState &&
      other.color == color &&
      other.frequency == frequency &&
      other.isNumerical == isNumerical &&
      other.question == question &&
      other.reminder == reminder &&
      other.targetValue == targetValue &&
      other.targetType == targetType &&
      other.unit == unit &&
      other.theme == theme;

  @override
  int get hashCode => Object.hash(color, frequency, isNumerical, question,
      reminder, targetValue, targetType, unit, theme);

  @override
  String toString() => 'SubtitleCardState(color=$color, frequency=$frequency, '
      'isNumerical=$isNumerical, question=$question, reminder=$reminder, '
      'targetValue=$targetValue, targetType=$targetType, unit=$unit, '
      'theme=$theme)';
}

/// Kotlin: `class SubtitleCardPresenter { companion object { fun buildState … }
/// }`. There is no instance state at all — the class exists only to namespace
/// the builder.
class SubtitleCardPresenter {
  SubtitleCardPresenter._();

  static SubtitleCardState buildState({
    required Habit habit,
    required Theme theme,
  }) =>
      SubtitleCardState(
        color: habit.color,
        frequency: habit.frequency,
        isNumerical: habit.isNumerical,
        question: habit.question,
        reminder: habit.reminder,
        targetValue: habit.targetValue,
        targetType: habit.targetType,
        unit: habit.unit,
        theme: theme,
      );
}
