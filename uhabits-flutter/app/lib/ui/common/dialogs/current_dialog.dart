/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/utils/DialogUtils.kt.
///
/// ```kotlin
/// var currentDialog: WeakReference<Dialog> = WeakReference(null)
/// var currentDialogFragment: WeakReference<DialogFragment> = WeakReference(null)
///
/// fun dismissCurrentDialog() { … }
/// fun Dialog.dismissCurrentAndShow() { dismissCurrentDialog(); currentDialog = WeakReference(this); show() }
/// ```
///
/// One slot for the whole process, holding at most one dialog at a time. Every
/// picker that opens through [dismissCurrentAndShow] closes whatever was in the
/// slot first, and a screen going to the background calls
/// [dismissCurrentDialog] so nothing leaks across a lifecycle change
/// (`platform-glue.transient-ui-helpers#3`, `#4`, `#5`).
///
/// Two dialogs are deliberately *outside* it, and both stay outside here: the
/// history editor keeps its own slot so it can sit under an entry popup
/// (`history-editor.dialog#10`), and the numerical frequency picker is shown
/// with a bare `builder.show()`
/// (`edit-habit.numerical-frequency-picker#5`).
///
/// The Android references are weak because a `Dialog` outlives nothing; a
/// closure is used instead, because what has to be remembered here is *how to
/// pop* a route rather than the route itself.
library;

import 'package:flutter/widgets.dart';

/// `currentDialog` / `currentDialogFragment`, collapsed into one slot: Flutter
/// has no `Dialog`/`DialogFragment` split to keep them apart.
VoidCallback? _currentDialog;

/// True while a dialog is tracked. For tests and for assertions; upstream reads
/// `currentDialog.get() != null` the same way.
bool get hasCurrentDialog => _currentDialog != null;

/// `fun dismissCurrentDialog()`: dismiss whichever dialog is still reachable
/// and clear the slot.
void dismissCurrentDialog() {
  final dismiss = _currentDialog;
  _currentDialog = null;
  dismiss?.call();
}

/// `fun Dialog.dismissCurrentAndShow()` and the `DialogFragment` overload.
///
/// Dismiss the tracked dialog, register this one as current, then show it. The
/// slot is cleared again when the dialog closes for any reason, which is what
/// the weak reference achieves upstream: a dismissed dialog is collectable and
/// `currentDialog.get()` starts returning null.
Future<T?> dismissCurrentAndShow<T>(
  BuildContext context,
  Future<T?> Function() show,
) {
  dismissCurrentDialog();
  // `showDialog` pushes onto the root navigator, so that is the one to pop.
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  late final VoidCallback token;
  token = () {
    // A navigator that is gone is the weak reference that has been collected:
    // `currentDialog.get()` returns null and `dismissCurrentDialog()` is a
    // no-op, rather than reaching into a torn-down tree.
    if (navigator.mounted && navigator.canPop()) navigator.pop();
  };
  _currentDialog = token;
  final Future<T?> future = show();
  future.whenComplete(() {
    if (identical(_currentDialog, token)) _currentDialog = null;
  });
  return future;
}

/// Clears the slot without dismissing anything.
///
/// Not upstream — a `WeakReference` needs no such thing — but a Dart test
/// process is not torn down between cases, so the slot has to be resettable or
/// one test's dialog would be popped by the next one's picker.
@visibleForTesting
void resetCurrentDialog() {
  _currentDialog = null;
}
