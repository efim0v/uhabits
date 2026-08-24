/// The app's one transient message.
///
/// Port of the single helper every user-visible message in the Android app
/// goes through, `ViewExtensions.kt:105-119`:
///
/// ```kotlin
/// fun View.showMessage(msg: String) {
///     try {
///         val snackbar = Snackbar.make(this, msg, Snackbar.LENGTH_SHORT)
///         val tv = snackbar.view.findViewById<TextView>(R.id.snackbar_text)
///         tv?.setTextColor(Color.WHITE)
///         snackbar.show()
///     } catch (e: IllegalArgumentException) {
///         return
///     }
/// }
///
/// fun Activity.showMessage(msg: String) {
///     this.findViewById<View>(android.R.id.content).showMessage(msg)
/// }
/// ```
///
/// `ListHabitsScreen.onCommandFinished` ("Habit created" / "Habit archived" /
/// "Habits deleted" / "Habit changed"), `ListHabitsScreen.showMessage` (the
/// import/export/repair/bug-report results), `ShowHabitActivity.Screen.
/// showMessage` (HABIT_ARCHIVED, HABIT_UNARCHIVED, COULD_NOT_EXPORT),
/// `AboutScreen.onPressDeveloperCountdown` ("You are now a developer") and
/// `startActivitySafely` ("No app was found to support this action") all call
/// it, so every message in the app has one lifetime, one colour and one queue
/// discipline. The port had copied it out five times and decided each of those
/// three independently — four call sites kept Flutter's 4000 ms default and one
/// chose 2000 ms where `Snackbar.LENGTH_SHORT` is 1500 ms, three hid the
/// current snackbar, one removed it and one did neither
/// (`audit24.one-show-message-helper-one-lifetime#1`).
library;

import 'package:flutter/material.dart';

/// `Snackbar.LENGTH_SHORT`.
///
/// `LENGTH_SHORT` is the sentinel -1, which `SnackbarManager` turns into
/// `SHORT_DURATION_MS` = 1500 ms. Flutter's own default is
/// `SnackBar._snackBarDisplayDuration`, 4000 ms, and `SnackBarThemeData`
/// carries no duration field — so the value cannot be pinned in `appThemeData`
/// the way the background and the text colour are, and has to live here.
const Duration snackbarLengthShort = Duration(milliseconds: 1500);

/// `Activity.showMessage(msg)`.
///
/// [ScaffoldMessenger.maybeOf] is the `catch (e: IllegalArgumentException)`
/// branch: a screen with no host to attach the snackbar to drops the message
/// in silence rather than throwing.
///
/// `hideCurrentSnackBar()` is Android's queue discipline. `SnackbarManager`
/// *replaces* a showing snackbar when a new one is requested — it never queues
/// two behind one another — so two messages in a row cost one lifetime, not
/// two.
///
/// The white text is `tv?.setTextColor(Color.WHITE)`, applied unconditionally
/// and with no branch on the theme. `appThemeData`'s `snackBarTheme` says the
/// same thing for the dark slab behind it
/// (`feedback.toasts-must-be-dark-with-white-text#1`); it is restated on the
/// `Text` because upstream restates it on the `TextView`.
void showMessage(BuildContext context, String message) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        duration: snackbarLengthShort,
      ),
    );
}
