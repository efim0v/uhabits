/// Port of uhabits-android/.../activities/common/dialogs/ConfirmDeleteDialog.kt.
///
/// A plain alert built around a quantity, so one dialog addresses one habit or
/// many (`confirm-delete.dialog#1`): the habit-list selection menu passes the
/// number of selected habits and ShowHabitActivity always passes 1
/// (`confirm-delete.dialog#8`).
///
/// Not this file's business: `dismissCurrentAndShow`
/// (`confirm-delete.dialog#7`), which belongs to
/// `dialogs.single-current-dialog`, and the deletion itself — the caller runs
/// `DeleteHabitsCommand`.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Asks the user to confirm deleting [quantity] habits.
///
/// Completes with true only when the positive button is pressed. The negative
/// button does nothing at all (`confirm-delete.dialog#5`) and dismissing by
/// tapping outside or pressing back does not confirm
/// (`confirm-delete.dialog#6`); both complete with false.
Future<bool> showConfirmDeleteDialog(
  BuildContext context, {
  required int quantity,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => ConfirmDeleteDialog(quantity: quantity),
  );
  return confirmed ?? false;
}

/// The dialog itself, exposed for tests and for screens that manage their own
/// route.
class ConfirmDeleteDialog extends StatelessWidget {
  const ConfirmDeleteDialog({super.key, required this.quantity});

  /// 1 for "Delete habit?", anything else for "Delete habits?"
  /// (`confirm-delete.dialog#2`).
  final int quantity;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.deleteHabitsTitle(quantity)),
      content: Text(l10n.deleteHabitsMessage(quantity)),
      actions: <Widget>[
        // R.string.no, an empty listener upstream
        // (`confirm-delete.dialog#5`).
        TextButton(
          key: const ValueKey<String>('confirm_delete_no'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.no),
        ),
        // R.string.yes, which invokes OnConfirmedCallback.onConfirmed
        // (`confirm-delete.dialog#4`).
        TextButton(
          key: const ValueKey<String>('confirm_delete_yes'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.yes),
        ),
      ],
    );
  }
}
