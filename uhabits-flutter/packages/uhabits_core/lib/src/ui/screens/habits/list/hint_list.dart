/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/HintList.kt
/// and .../list/HintListFactory.kt.
///
/// The hint *strings* live in Android resources
/// (uhabits-android/src/main/res/values/strings.xml, string-array `hints`) and
/// are injected by `ListHabitsRootView`. They are data, not view code, so the
/// English source array is reproduced here as [listHabitsHints]; a localized
/// build hands [HintListFactory.create] the translated array instead.
library;

import '../../../../preferences/preferences.dart';
import '../../../../time/local_date.dart';

/// The `hints` string-array of the list screen: `@string/hint_drag` followed by
/// `@string/hint_landscape`.
const List<String> listHabitsHints = <String>[
  'To rearrange the entries, press-and-hold on the name of the habit, then '
      'drag it to the correct place.',
  'You can see more days by putting your phone in landscape mode.',
];

/// Provides a list of hints to be shown at the application startup, and takes
/// care of deciding when a new hint should be shown.
///
/// Kotlin declares the class and both methods `open` so tests can stub them;
/// Dart classes and methods are open by default.
class HintList {
  HintList(this._prefs, this._hints);

  final Preferences _prefs;

  /// Kotlin takes an `Array<String>`; the only operations are `size` and
  /// indexing, so a [List] is the faithful Dart counterpart.
  final List<String> _hints;

  /// Returns a new hint to be shown to the user.
  ///
  /// The hint returned is marked as read on the list, and will not be returned
  /// again. In case all hints have already been read, and there is nothing
  /// left, returns null.
  ///
  /// `lastHintNumber` reads the key `last_hint_number`, which defaults to -1,
  /// so the first ever call returns `hints[0]` and records number 0. Once
  /// `next` runs past the end nothing is persisted — the preference stays at
  /// the last shown number and every later call returns null.
  String? pop() {
    final next = _prefs.lastHintNumber + 1;
    if (next >= _hints.length) return null;
    _prefs.updateLastHint(next, getToday());
    return _hints[next];
  }

  /// Returns whether it is time to show a new hint or not.
  ///
  /// False when `lastHintDate` is null (never set: `last_hint_timestamp` is
  /// negative) and false when it is today; true only for a strictly earlier
  /// date. Note that the *first run* seeds the preference with
  /// `updateLastHint(-1, today)`, which is what stops a hint from appearing on
  /// the very first day.
  bool shouldShow() {
    final today = getToday();
    final lastHintDate = _prefs.lastHintDate;
    return lastHintDate != null && lastHintDate < today;
  }
}

/// Port of `HintListFactory`, the `@Inject`ed factory that closes over the
/// application-scoped [Preferences] and takes only the hint array.
class HintListFactory {
  HintListFactory(this.preferences);

  final Preferences preferences;

  HintList create(List<String> hints) => HintList(preferences, hints);
}
