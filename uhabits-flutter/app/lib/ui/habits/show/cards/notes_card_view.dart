/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/NotesCardView.kt
/// and res/layout/show_habit_notes.xml (baselines:
/// androidTest/assets/views/habits/show/NotesCard/render.png and
/// render-empty-description.png).
///
/// The smallest card on the screen: one `TextView` with the habit's
/// description, drawn verbatim in `?attr/contrast100`
/// (`show-habit.notes-card#3` — no markdown, no links, no linkification).
///
/// The card's own visibility (`show-habit.notes-card#2`) is not decided here:
/// it is [NotesCardState.isVisible] in the core, and the screen consults the
/// core's `ShowHabitCardVisibility` before it builds this widget at all —
/// exactly as `ShowHabitView` never even asks a GONE child to draw.
library;

// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/notes_card.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

class NotesCardView extends StatelessWidget {
  const NotesCardView({
    required this.state,
    required this.theme,
    super.key,
  });

  final NotesCardState state;

  /// The card state carries no theme of its own — `NotesCardState` is a single
  /// string — so the colour token comes from the screen's theme.
  final core.Theme theme;

  /// `android:textColor="?attr/contrast100"`, which is the core theme's
  /// [core.Theme.highContrastTextColor].
  static const double notesFontSize = 14.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // `android:layout_width="match_parent"` on habitNotes.
      width: double.infinity,
      child: Text(
        state.description,
        style: TextStyle(
          color: _toFlutterColor(theme.highContrastTextColor),
          fontSize: notesFontSize,
        ),
      ),
    );
  }
}

/// Same rounding as `FlutterCanvas.setColor` and `core.Color.toInt`.
Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
