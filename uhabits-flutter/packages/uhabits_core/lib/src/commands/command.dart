/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/Command.kt
///
/// The Kotlin declaration is, in full:
///
/// ```kotlin
/// interface Command {
///     fun run()
/// }
/// ```
///
/// That is the whole contract. Despite the name, this fork has no undo and no
/// redo: there is no `undo()`, no `redo()`, no id, no name, no description and
/// no `isUndoable` flag, so a command cannot be reverted programmatically. The
/// only way to reverse an action is for the user to issue the inverse one.
///
/// `run()` is synchronous and returns nothing; it reports failure by throwing.
/// Commands hold direct references to the mutable model objects they change and
/// mutate them in place rather than returning new state, and they are never
/// serialized, persisted, or stored in any history list.
///
/// Kotlin declares this as a plain `interface` (not a `fun interface`), so it
/// is implemented, never extended and never SAM-converted.
abstract interface class Command {
  /// Applies this command's mutation.
  void run();
}
