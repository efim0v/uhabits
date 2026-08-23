/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/SubtitleCard.kt.
///
/// [SubtitleCardState] is a pure state object: `buildState` copies eight fields
/// off the habit and hands them to the view. Everything the Android
/// `SubtitleCardView` then *decides* — which frequency sentence to print, how
/// to render the reminder, which FontAwesome glyph the target arrow is, which
/// labels are visible — is pure logic with no Android in it, so it is ported
/// here as getters on the state rather than being left to the widget layer.
/// The three Kotlin sources for that half are `SubtitleCardView.setState`,
/// `formatFrequency` (EditHabitActivity.kt) and `formatTime`
/// (utils/DateExtensions.kt).
///
/// What is deliberately NOT here: text sizes, ems, ellipsizing, the FontAwesome
/// typeface binding and the layout itself. Those are Android view attributes.
library;

import '../../../../../gui/color.dart';
import '../../../../../gui/font_awesome.dart';
import '../../../../../gui/theme.dart';
import '../../../../../io/printf.dart';
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

  /// `binding.frequencyLabel.text = formatFrequency(num, den, resources)`.
  String get frequencyText =>
      formatFrequency(frequency.numerator, frequency.denominator);

  /// `binding.reminderLabel.text`: the reminder time, or the string resource
  /// `reminder_off` when the habit has no reminder.
  ///
  /// [use24HourFormat] stands in for `DateFormat.getTimeFormat(context)`,
  /// which follows the system 12h/24h setting; the widget layer supplies it.
  String reminderText({required bool use24HourFormat}) {
    final r = reminder;
    if (r == null) return reminderOffText;
    return formatTime(r.hour, r.minute, use24HourFormat: use24HourFormat);
  }

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

  /// Port of `fun formatFrequency(freqNum: Int, freqDen: Int, resources:
  /// Resources)` from
  /// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt,
  /// with the English string resources inlined.
  ///
  /// The branches are tried in exactly this order, which is why 1/30 is
  /// "Every month" rather than "Every 30 days" and why 7/7 — normalised to 1/1
  /// by [Frequency] — is "Every day".
  static String formatFrequency(int freqNum, int freqDen) {
    if (freqNum == 1 && (freqDen == 30 || freqDen == 31)) return 'Every month';
    if (freqDen == 30 || freqDen == 31) {
      return format('%d times per month', freqNum);
    }
    if (freqNum == 1 && freqDen == 1) return 'Every day';
    if (freqNum == 1 && freqDen == 7) return 'Every week';
    if (freqNum == 1 && freqDen > 1) return format('Every %d days', freqDen);
    if (freqDen == 7) return format('%d times per week', freqNum);
    // "%d times in %d days" — two positional integers, which the ported
    // `format` helper (one argument only) cannot express, so it is spelled out.
    return '$freqNum times in $freqDen days';
  }

  /// Port of `fun formatTime(context: Context, hours: Int, minutes: Int)` from
  /// uhabits-android/src/main/java/org/isoron/uhabits/utils/DateExtensions.kt.
  ///
  /// Kotlin builds a `Date` out of `(hours * 60 + minutes)` minutes since the
  /// Unix epoch and formats it in UTC, so the value wraps modulo a day: hour
  /// 25 prints as 01:00 and a negative hour walks backwards into the previous
  /// day. That wrapping is reproduced here.
  ///
  /// The pattern itself comes from the platform (`DateFormat.getTimeFormat`),
  /// which is locale dependent; this port renders the two en-US patterns
  /// ("HH:mm" and "h:mm a") and leaves anything more locale-specific to the
  /// widget layer.
  static String formatTime(
    int hour,
    int minute, {
    required bool use24HourFormat,
  }) {
    const minutesPerDay = 24 * 60;
    // Dart's `%` returns a non-negative result for a positive divisor, which
    // is exactly the calendar wrap-around Java's Date gives here.
    final wrapped = (hour * 60 + minute) % minutesPerDay;
    final h = wrapped ~/ 60;
    final m = wrapped % 60;
    final minuteText = m.toString().padLeft(2, '0');
    if (use24HourFormat) {
      return '${h.toString().padLeft(2, '0')}:$minuteText';
    }
    final suffix = h < 12 ? 'AM' : 'PM';
    var h12 = h % 12;
    if (h12 == 0) h12 = 12;
    return '$h12:$minuteText $suffix';
  }

  /// `resources.getString(R.string.reminder_off)`.
  static const String reminderOffText = 'Off';

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
