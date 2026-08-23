/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/NotesCard.kt.
///
/// The smallest card on the screen: one string, copied straight off the habit.
/// The only decision the Android `NotesCardView` makes is whether to show
/// itself, which is ported as [isVisible]; unlike the overview/target pair in
/// `ShowHabitView`, this one toggles both ways, so a description added after
/// the card was hidden brings it back.
library;

import '../../../../../models/habit.dart';

/// Kotlin: `data class NotesCardState(val description: String)`.
class NotesCardState {
  const NotesCardState({required this.description});

  final String description;

  /// `if (state.description.isEmpty()) visibility = GONE else visibility =
  /// VISIBLE`. Note `isEmpty`, not `isBlank`: a description of one space still
  /// shows the card.
  bool get isVisible => description.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is NotesCardState && other.description == description;

  @override
  int get hashCode => description.hashCode;

  @override
  String toString() => 'NotesCardState(description=$description)';
}

class NotesCardPresenter {
  NotesCardPresenter._();

  static NotesCardState buildState({required Habit habit}) =>
      NotesCardState(description: habit.description);
}
