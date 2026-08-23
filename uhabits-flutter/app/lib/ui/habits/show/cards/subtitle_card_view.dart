/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/SubtitleCardView.kt
/// and res/layout/show_habit_subtitle.xml (baseline:
/// androidTest/assets/views/habits/show/SubtitleCard/render.png).
///
/// A question label over a single row of icon/label pairs: target, frequency,
/// reminder. Every string and every visibility decision already lives on the
/// core [SubtitleCardState] — `frequencyText`, `reminderText`,
/// `targetText`, `targetIconGlyph`, `isQuestionVisible`, `isTargetVisible` —
/// so this widget only lays them out and paints them.
///
/// What the Kotlin view *does* keep to itself, and is reproduced here, is the
/// order in which visibility is assigned: the question label is set VISIBLE
/// and then GONE again when the question is empty
/// (`show-habit.subtitle-card#2`), and the target pair is set VISIBLE and then
/// GONE again for boolean habits (`show-habit.subtitle-card#6`). The end state
/// is the same either way, which is why this is a plain conditional.
library;

// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/subtitle_card.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

class SubtitleCardView extends StatelessWidget {
  const SubtitleCardView({
    required this.state,
    this.use24HourFormat,
    super.key,
  });

  final SubtitleCardState state;

  /// Stands in for `DateFormat.getTimeFormat(context)`, which follows the
  /// system 12h/24h setting. Defaults to
  /// `MediaQuery.alwaysUse24HourFormat`, Flutter's window into the same
  /// platform setting.
  final bool? use24HourFormat;

  /// `@dimen/regularTextSize`, 16sp — the question label.
  static const double questionFontSize = 16.0;

  /// `@dimen/smallTextSize`, 14sp — every label in the row below it.
  static const double smallFontSize = 14.0;

  /// `android:textSize="16sp"` on `targetIcon` only; the other two icons take
  /// smallTextSize.
  static const double targetIconFontSize = 16.0;

  /// `android:maxEms="7"` on `targetText`. Flutter has no ems constraint, so
  /// the width is capped at 7 times the font size — Android's em is the width
  /// of the font's "M", which is close enough to the point size that the
  /// ellipsis lands in the same place.
  static const double targetMaxEms = 7.0;

  @override
  Widget build(BuildContext context) {
    final use24 =
        use24HourFormat ?? MediaQuery.of(context).alwaysUse24HourFormat;
    final captionColor = _toFlutterColor(state.theme.mediumContrastTextColor);
    final captionStyle = TextStyle(
      color: captionColor,
      fontSize: smallFontSize,
    );
    final iconStyle = captionStyle.copyWith(
      fontFamily: core.FontAssets.fontAwesomeFamily,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (state.isQuestionVisible)
          Padding(
            // `android:layout_marginBottom="8dp"`
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              state.question,
              key: questionKey,
              style: TextStyle(
                // setState overrides the XML's contrast60 with the habit
                // colour.
                color: _toFlutterColor(state.questionColor),
                fontSize: questionFontSize,
              ),
            ),
          ),
        Padding(
          // `android:layout_marginBottom="2dp"`
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (state.isTargetVisible) ...<Widget>[
                Text(
                  state.targetIconGlyph,
                  key: targetIconKey,
                  style: iconStyle.copyWith(fontSize: targetIconFontSize),
                ),
                // `android:layout_marginStart="4dp"`
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: targetMaxEms * smallFontSize,
                  ),
                  child: Text(
                    state.targetText,
                    key: targetTextKey,
                    style: captionStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // `android:layout_marginEnd="16dp"`
                const SizedBox(width: 16),
              ],
              Text(
                SubtitleCardState.frequencyIconGlyph,
                key: frequencyIconKey,
                style: iconStyle,
              ),
              const SizedBox(width: 4),
              Text(
                state.frequencyText,
                key: frequencyLabelKey,
                style: captionStyle,
              ),
              const SizedBox(width: 16),
              Text(
                SubtitleCardState.reminderIconGlyph,
                key: reminderIconKey,
                style: iconStyle,
              ),
              const SizedBox(width: 4),
              Padding(
                // `android:paddingTop="1dp"` on reminderLabel.
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  state.reminderText(use24HourFormat: use24),
                  key: reminderLabelKey,
                  style: captionStyle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The ids of show_habit_subtitle.xml, so a test can name a label without
  /// matching on its text.
  static const Key questionKey = Key('subtitleCard.questionLabel');
  static const Key targetIconKey = Key('subtitleCard.targetIcon');
  static const Key targetTextKey = Key('subtitleCard.targetText');
  static const Key frequencyIconKey = Key('subtitleCard.frequencyIcon');
  static const Key frequencyLabelKey = Key('subtitleCard.frequencyLabel');
  static const Key reminderIconKey = Key('subtitleCard.reminderIcon');
  static const Key reminderLabelKey = Key('subtitleCard.reminderLabel');
}

/// Same rounding as `FlutterCanvas.setColor` and `core.Color.toInt`.
Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
