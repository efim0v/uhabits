/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/{ShowHabitActivity,ShowHabitView}.kt
/// and res/layout/show_habit.xml.
///
/// The three Kotlin pieces collapse into one widget plus one [ShowHabitModel]:
///
///  * `ShowHabitActivity` is the lifecycle and the `Screen` implementation.
///    Its `onResume` / `onPause` pair is [ShowHabitModel.attach] /
///    [ShowHabitModel.detach], driven by the provider that owns the model, and
///    its `Screen.refresh()` is [ShowHabitModel.refresh]. The half of `Screen`
///    that needs a navigator — the two entry popups, the history editor, the
///    delete confirmation, the editor and `finish()` — is implemented here, as
///    [ShowHabitScreenDelegate];
///  * `ShowHabitView` is `setState`: it pushes one slice of the state into
///    each card and hides the two that do not apply to the habit's type. Both
///    halves are the core's — [ShowHabitPresenter.buildState] and
///    `ShowHabitCardVisibility` — so what is left here is the column;
///  * show_habit.xml is the column itself: a fixed toolbar over a scrolling
///    list of nine cards (`show-habit.screen-scaffold#12`).
///
/// `AndroidThemeSwitcher.currentTheme` is the shared `coreThemeOf` of
/// ui/theme/app_theme.dart, so the cards see whichever of LightTheme,
/// DarkTheme and PureBlackTheme the app was built from
/// (`show-habit.screen-scaffold#11`).
///
/// The overflow menu is [ShowHabitMenu], a straight port of ShowHabitMenu.kt
/// and res/menu/show_habit.xml; this file only draws it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

// The presenter callbacks and the chart listener are still reached by their
// `src` path.
// ignore_for_file: implementation_imports
import 'package:uhabits_core/src/io/files.dart' show UserFile;
// The core package does not re-export lib/src/time/date_utils.dart; it is where
// `computeToday` lives.
import 'package:uhabits_core/src/time/date_utils.dart' as core;
import 'package:uhabits_core/src/ui/intent_parser.dart' show parseContentUriId;
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_behavior.dart'
    show CheckMarkDialogCallback, NumberPickerCallback;
import 'package:uhabits_core/src/ui/views/history_chart.dart'
    show OnDateClickedListener;

import '../../../l10n/app_localizations.dart';
import '../../../platform/flutter_files.dart'
    show AppDirectories, FileSharer, HabitsDirFinder, PlatformFileSharer;
import '../../../state/app_scope.dart';
import '../../../state/show_habit_model.dart';
import '../../common/dialogs/checkmark_dialog.dart';
import '../../common/dialogs/confirm_delete_dialog.dart';
// Prefixed: the file's `showHistoryEditorDialog` function and this screen's
// `Screen.showHistoryEditorDialog` override have the same name.
import '../../common/dialogs/history_editor_dialog.dart' as editor;
import '../../common/dialogs/number_dialog.dart';
import '../../common/show_message.dart' as messages;
import '../../common/window_insets.dart';
import '../../theme/app_theme.dart' show coreThemeOf;
import '../edit/edit_habit_screen.dart';
import 'cards/bar_card_view.dart';
import '../sleep/sleep_section.dart';
import 'cards/frequency_card_view.dart';
import 'cards/history_card_view.dart';
import 'cards/notes_card_view.dart';
import 'cards/overview_card_view.dart';
import 'cards/score_card_view.dart';
import 'cards/streak_card_view.dart';
import 'cards/subtitle_card_view.dart';
import 'cards/target_card_view.dart';
import 'show_habit_menu.dart';

export 'show_habit_menu.dart' show ShowHabitMenu, ShowHabitMenuItem;

/// The habit detail screen. Owns the [ShowHabitModel] for as long as it is
/// mounted.
class ShowHabitScreen extends StatelessWidget {
  const ShowHabitScreen({
    required this.habit,
    this.system,
    this.fileSharer = const PlatformFileSharer(),
    super.key,
  });

  /// The habit `ShowHabitActivity` would have resolved from the intent's
  /// `content://org.isoron.uhabits/habit/<id>` URI. The Flutter list hands the
  /// model over directly instead — see [habitFromUri] for the resolution step.
  final core.Habit habit;

  /// `HabitsDirFinder(AndroidDirFinder(this))`, the CSV export's output
  /// directory. [route] supplies the real one; left null the model falls back
  /// to a `getCSVOutputDir()` that throws, which is what a screen built
  /// directly in a test gets.
  final ShowHabitMenuPresenterSystem? system;

  /// The `ACTION_SEND` half of `Activity.showSendFileScreen(filename)`, behind
  /// a seam because share_plus is a plugin and a plugin cannot run in a widget
  /// test — the same seam `DataActions` takes for the list screen's export.
  final FileSharer fileSharer;

  /// `type = "application/zip"` in `showSendFileScreen`.
  static const String shareMimeType = 'application/zip';

  /// `habit = habitList.getById(ContentUris.parseId(intent.data!!))!!` —
  /// the first three statements of `onCreate` (`show-habit.screen-scaffold#1`).
  ///
  /// The `!!` is upstream's and is kept: an id that is not in the list throws
  /// here rather than opening a "habit not found" screen, because there is no
  /// such screen (`show-habit.screen-scaffold#2`).
  static core.Habit habitFromUri(core.HabitList habitList, Uri uri) =>
      habitList.getById(parseContentUriId(uri))!;

  /// The route `IntentFactory.startShowHabitActivity` builds.
  ///
  /// The scope has to be captured by the caller: `MaterialApp.home` provides
  /// it *below* the navigator, so a pushed route sits outside it.
  ///
  /// [system] is `onCreate`'s `system = HabitsDirFinder(AndroidDirFinder(this))`
  /// — the Export item's output directory. It defaults to the real one, which
  /// starts resolving as the route is built.
  static Route<void> route({
    required AppScope scope,
    required core.Habit habit,
    ShowHabitMenuPresenterSystem? system,
  }) {
    final resolvedSystem = system ?? ShowHabitCSVOutputDir();
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: habit.uriString),
      builder: (context) => Provider<AppScope>.value(
        value: scope,
        child: ShowHabitScreen(habit: habit, system: resolvedSystem),
      ),
    );
  }

  /// `ListHabitsScreen.showHabitScreen(habit)`.
  static Future<void> open(BuildContext context, core.Habit habit) {
    return Navigator.of(context).push(
      route(scope: context.read<AppScope>(), habit: habit),
    );
  }

  /// The key of one card in the column, so a test can ask where it is.
  static Key cardKey(ShowHabitCard card) => ValueKey<ShowHabitCard>(card);

  /// The toolbar's Edit action — `R.id.action_edit_habit`.
  static const Key editActionKey = Key('showHabit.actionEditHabit');

  /// The overflow button itself — the three dots the five `showAsAction=never`
  /// items live behind.
  static const Key overflowMenuKey = Key('showHabit.overflowMenu');

  /// One overflow entry, by item.
  static Key menuItemKey(ShowHabitMenuItem item) =>
      ValueKey<ShowHabitMenuItem>(item);

  @override
  Widget build(BuildContext context) {
    // Both are read here rather than inside the state: a provider's factory
    // and `initState` may not depend on an inherited widget, and `Theme.of`
    // is one.
    return _ShowHabitView(
      scope: context.read<AppScope>(),
      habit: habit,
      theme: coreThemeOf(context),
      system: system,
      fileSharer: fileSharer,
    );
  }
}

/// `HabitsDirFinder(AndroidDirFinder(this))` — the `system` argument
/// `ShowHabitActivity.onCreate` hands its menu presenter, whose one job is to
/// name the directory `ExportCSVTask` writes the archive into.
///
/// Android builds it from the Context, synchronously. path_provider only
/// answers asynchronously, so the resolution starts when the route is built —
/// well before the overflow menu can be opened and its Export item tapped —
/// and the finder is installed underneath as soon as it lands.
class ShowHabitCSVOutputDir implements ShowHabitMenuPresenterSystem {
  ShowHabitCSVOutputDir({Future<AppDirectories> Function()? resolve})
      : _resolve = resolve ?? AppDirectories.resolve {
    ready = _install();
  }

  final Future<AppDirectories> Function() _resolve;

  /// Completes once [getCSVOutputDir] can answer — or once it is settled that
  /// it never will. Exposed so that a test can wait for the resolution the
  /// screen kicks off instead of racing it.
  late final Future<void> ready;

  HabitsDirFinder? _dirFinder;

  Object? _failure;

  Future<void> _install() async {
    try {
      _dirFinder = HabitsDirFinder.of(await _resolve());
    } on Object catch (error) {
      // A Context always knows its directories; a host without path_provider
      // does not. Remembered rather than thrown, so that a screen on such a
      // host still opens and only Export fails — which is also what Android
      // does when no external files directory is writable.
      _failure = error;
    }
  }

  @override
  UserFile getCSVOutputDir() {
    final dirFinder = _dirFinder;
    if (dirFinder != null) return dirFinder.getCSVOutputDir();
    throw StateError(
      'No CSV output directory: ${_failure ?? 'the app directories are still '
          'being resolved'}',
    );
  }
}

class _ShowHabitView extends StatefulWidget {
  const _ShowHabitView({
    required this.scope,
    required this.habit,
    required this.theme,
    required this.system,
    required this.fileSharer,
  });

  final AppScope scope;

  final core.Habit habit;

  final core.Theme theme;

  final ShowHabitMenuPresenterSystem? system;

  final FileSharer fileSharer;

  @override
  State<_ShowHabitView> createState() => _ShowHabitViewState();
}

class _ShowHabitViewState extends State<_ShowHabitView>
    with WidgetsBindingObserver
    implements ShowHabitScreenDelegate {
  late final ShowHabitModel _model;

  /// `DialogUtils`' process-wide `currentDialog`, narrowed to this screen.
  ///
  /// `dialogs.single-current-dialog` is superseded by route stacking, so the
  /// slot is a plain closure that pops whatever tracked dialog is on top
  /// rather than a `WeakReference<Dialog>`. The dialogs routed through it are
  /// the ones `dismissCurrentAndShow` covers on this screen: the check-mark
  /// popup, the number popup and the delete confirmation.
  VoidCallback? _currentDialog;

  /// The inflated options menu (`show-habit.menu#1`).
  ///
  /// `ShowHabitActivity.onCreateOptionsMenu` runs once, when the action bar
  /// asks for its menu, and the activity overrides neither
  /// `onPrepareOptionsMenu` nor ever calls `invalidateOptionsMenu` — so the
  /// answers `presenter.canArchive()` / `canUnarchive()` gave at inflation
  /// stick for the rest of the visit. Recomputing them in `build` instead made
  /// the item flip as soon as the archive command finished, which is a
  /// different screen from the one upstream shows
  /// (`show-habit.archive-unarchive#4`,
  /// `audit7.the-show-habit-overflow-menu-re#1`).
  ///
  /// `late final` is the inflation: the initializer runs on the first build,
  /// once, and never again for the life of this state.
  late final List<ShowHabitMenuItem> _menuItems =
      _model.menu.onCreateOptionsMenu();

  @override
  void initState() {
    super.initState();
    // `onCreate`: build the presenters, then wire the view to them. Nothing
    // is listening to the model yet — the provider below only starts when
    // this state first builds — so `attach()`'s refresh is free to notify.
    _model = ShowHabitModel(
      scope: widget.scope,
      habit: widget.habit,
      theme: widget.theme,
      system: widget.system,
    );
    // `ShowHabitActivity` *is* the Screen; here the widget supplies the half
    // of it that needs a navigator.
    _model.delegate = this;
    _model.reattachHistoryEditor = _reattachHistoryEditor;
    // `onResume`.
    _model.attach();
    // Upstream this screen *is* an activity, so the system runs `onPause` when
    // the app leaves the foreground and `onResume` when it comes back. A
    // Flutter app has one activity for the whole process: this widget stays
    // mounted across a background/foreground round trip, and `attach()` /
    // `detach()` above are driven only by the mount and the unmount. The
    // observer is what gives the two callbacks their other half
    // (`audit5.the-habit-detail-screen-never-refreshes#1`).
    WidgetsBinding.instance.addObserver(this);
  }

  /// `ShowHabitActivity.onResume` / `onPause` for the transitions that are not
  /// a mount.
  ///
  /// `onResume` is `commandRunner.addListener(this)`, the
  /// `findFragmentByTag("historyEditor")` re-attach and `screen.refresh()`,
  /// which re-runs `ShowHabitPresenter.buildState(...)` against a freshly read
  /// `getToday()` — all three are [ShowHabitModel.attach]. `onPause` is
  /// `dismissCurrentDialog()` followed by `removeListener(this)`
  /// (`show-habit.screen-scaffold#4`, `#6`, `#7`).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      // `onPause`: an open number or check-mark popup is gone when the user
      // comes back.
      _dismissCurrentDialog();
      _model.detach();
      return;
    }
    // `DateUtils.getToday()` is a clock read on every call upstream, so the
    // refresh below sees the real day even when the process spent it in the
    // background. The port stamps the day into a process-global instead, and
    // its only writer — the midnight timer — was paused for exactly that
    // interval and, on resume, schedules the *next* boundary rather than
    // firing for one already crossed. Re-stamping here is what makes the
    // refresh recompute today rather than yesterday, and it is the same
    // statement `ListHabitsActivity.onResume` runs.
    core.setToday(
      core.computeToday(widget.scope.preferences.midnightDelayHours, 0),
    );
    _model.attach();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // `onPause`: dismiss whatever dialog is open, then unregister
    // (`show-habit.screen-scaffold#6`).
    _dismissCurrentDialog();
    _model.reattachHistoryEditor = null;
    if (identical(_model.delegate, this)) _model.delegate = null;
    _model.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ShowHabitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `AndroidThemeSwitcher.apply()` restarts the activity when the theme
    // changes; here the model rebuilds its state instead
    // (`show-habit.screen-scaffold#11`).
    //
    // didUpdateWidget runs inside the build phase, and the model's setter
    // refreshes and notifies — which would mark the provider below dirty
    // mid-build and throw — so the switch is deferred by one frame.
    final theme = widget.theme;
    if (theme.runtimeType == _model.theme.runtimeType) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _model.theme = theme;
    });
  }

  // -----------------------------------------------------------------------
  // The current-dialog slot
  // -----------------------------------------------------------------------

  /// `Dialog.dismissCurrentAndShow()`: dismiss the tracked dialog, register
  /// this one as current, then show it.
  Future<T?> _dismissCurrentAndShow<T>(Future<T?> Function() show) {
    _dismissCurrentDialog();
    // `showDialog` pushes onto the root navigator, so that is the one the
    // slot has to pop from.
    final navigator = Navigator.of(context, rootNavigator: true);
    late final VoidCallback token;
    token = () {
      if (navigator.canPop()) navigator.pop();
    };
    _currentDialog = token;
    final future = show();
    future.whenComplete(() {
      if (identical(_currentDialog, token)) _currentDialog = null;
    });
    return future;
  }

  /// `dismissCurrentDialog()`.
  void _dismissCurrentDialog() {
    final dismiss = _currentDialog;
    _currentDialog = null;
    dismiss?.call();
  }

  // -----------------------------------------------------------------------
  // ShowHabitActivity.Screen, the half that needs a navigator
  // -----------------------------------------------------------------------

  /// `supportFragmentManager.findFragmentByTag("historyEditor")?.let {
  ///     (it as HistoryEditorDialog).setOnDateClickedListener(
  ///         presenter.historyCardPresenter)
  /// }` — `onResume`'s middle statement (`show-habit.screen-scaffold#7`,
  /// `history-editor.dialog#13`).
  void _reattachHistoryEditor(OnDateClickedListener listener) {
    editor.HistoryEditorDialog.current?.setOnDateClickedListener(listener);
  }

  @override
  void showHistoryEditorDialog(OnDateClickedListener listener) {
    // Deliberately NOT through `_dismissCurrentAndShow`: the editor keeps its
    // own slot so that it can stay open under the entry popups
    // (`history-editor.dialog#10`, `#16`).
    editor.showHistoryEditorDialog(
      context,
      habitId: _model.habit.id!,
      habitList: _model.scope.habitList,
      commandRunner: _model.scope.commandRunner,
      preferences: _model.scope.preferences,
      listener: listener,
    );
  }

  /// `window.decorView.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)`
  /// — a short vibration, which is what `HapticFeedback.lightImpact` maps to
  /// on Android (`show-habit.history-interaction#3`, `#13`,
  /// `history-editor.dialog#12`).
  ///
  /// Not `Feedback.forTap`: that is a `SystemSound.play(click)` on Android and
  /// nothing at all on iOS, so the one tactile confirmation the calendar
  /// editor gives would be a click sound on one platform and silence on the
  /// other (`audit8.tapping-a-day-in-the-history#1`).
  @override
  void showFeedback() {
    HapticFeedback.lightImpact();
  }

  /// The day the history editor last reported.
  ///
  /// The presenter's `showNumberPopup` carries a value but not a date, and a
  /// sleep habit needs the date to know which night is being edited.
  ///
  /// Read from the chart rather than by substituting the listener: parity rule
  /// `history-editor.dialog#17` requires the dialog's listener to be the very
  /// same object as the card's presenter, and a wrapper — however transparent
  /// — is a different object.
  core.LocalDate? get _lastClickedDate =>
      editor.HistoryEditorDialog.current?.chart?.lastClickedDate;

  @override
  Future<void> showNumberPopup(
    double value,
    String notes,
    NumberPickerCallback callback,
  ) async {
    // A sleep habit's value is a night, not a number. The popup would take a
    // percentage the next recompute overwrites.
    final core.SleepGoal? sleepGoal =
        widget.scope.sleepRepository.goalFor(widget.habit.id!);
    final core.LocalDate? date = _lastClickedDate;
    if (sleepGoal != null && date != null) {
      callback.onNumberPickerDismissed();
      await enterNightByHand(
        context,
        scope: widget.scope,
        habit: widget.habit,
        goal: sleepGoal,
        day: date.daysSince2000,
        theme: coreThemeOf(context),
      );
      return;
    }

    final theme = coreThemeOf(context);
    final result = await _dismissCurrentAndShow<NumberDialogResult>(
      () => showNumberDialog(
        context,
        value: value,
        notes: notes,
        color: theme.colorOf(_model.habit.color),
        preferences: _model.scope.preferences,
      ),
    );
    if (result == null) {
      callback.onNumberPickerDismissed();
      return;
    }
    callback.onNumberPicked(result.value, result.notes);
  }

  @override
  Future<void> showCheckmarkPopup(
    int selectedValue,
    String notes,
    core.PaletteColor color,
    CheckMarkDialogCallback callback,
  ) async {
    final theme = coreThemeOf(context);
    final result = await _dismissCurrentAndShow<CheckmarkDialogResult>(
      () => showCheckmarkDialog(
        context,
        value: selectedValue,
        notes: notes,
        color: theme.colorOf(color),
        preferences: _model.scope.preferences,
      ),
    );
    if (result == null) {
      callback.onNotesDismissed();
      return;
    }
    callback.onNotesSaved(result.value, result.notes);
  }

  @override
  void showEditHabitScreen(core.Habit habit) {
    EditHabitScreen.open(context, habit);
  }

  /// `showMessage(resources.getQuantityString(...))`, which is
  /// `ViewExtensions.showMessage`: a short white-on-dark Snackbar at the
  /// bottom of the screen (`show-habit.archive-unarchive#3`).
  ///
  /// The Kotlin helper wraps the `Snackbar.make` in a try/catch that swallows
  /// `IllegalArgumentException` — thrown when no suitable parent view can be
  /// found — and shows nothing at all in that case; `ScaffoldMessenger.of`
  /// throws its own assertion when there is no messenger above this widget, so
  /// the same guard is spelled with `maybeOf` (`show-habit.archive-unarchive#5`).
  @override
  void showMessage(ShowHabitMenuPresenterMessage? m) {
    final l10n = L10n.of(context);
    final String text;
    switch (m) {
      case ShowHabitMenuPresenterMessage.couldNotExport:
        text = l10n.couldNotExport;
      case ShowHabitMenuPresenterMessage.habitArchived:
        text = l10n.toastHabitsArchived(1);
      case ShowHabitMenuPresenterMessage.habitUnarchived:
        text = l10n.toastHabitsUnarchived(1);
      case null:
        // Kotlin's `else -> {}`.
        return;
    }
    messages.showMessage(context, text);
  }

  /// `Activity.showSendFileScreen(archiveFilename)`, the second half of
  /// `onExportCSV()`:
  ///
  /// ```kotlin
  /// val uri = Uri.parse(archiveFilename)
  /// val fileUri = if (uri.scheme == "content") uri
  ///               else FileProvider.getUriForFile(this, "org.isoron.uhabits",
  ///                        if (uri.scheme == "file") File(uri.path!!)
  ///                        else File(archiveFilename))
  /// startActivitySafely(Intent().apply {
  ///     action = ACTION_SEND
  ///     type = "application/zip"
  ///     putExtra(EXTRA_STREAM, fileUri)
  ///     flags = FLAG_GRANT_READ_URI_PERMISSION
  /// })
  /// ```
  ///
  /// share_plus wraps the file in a `FileProvider` URI and grants read
  /// permission on it by itself, so what is left here is the scheme handling
  /// and `startActivitySafely`'s catch (`show-habit.export-csv#4`,
  /// `io.share-file-screen#1`).
  @override
  Future<void> showSendFileScreen(String filename) async {
    final uri = Uri.tryParse(filename);
    final String target;
    if (uri != null && uri.scheme == 'content') {
      target = filename;
    } else if (uri != null && uri.scheme == 'file') {
      target = uri.path;
    } else {
      target = filename;
    }
    try {
      await widget.fileSharer.shareFile(
        target,
        mimeType: ShowHabitScreen.shareMimeType,
      );
    } on Object {
      // `startActivitySafely` catches ActivityNotFoundException and shows
      // R.string.activity_not_found through the same `showMessage` helper
      // every other message on this screen goes through.
      if (!mounted) return;
      messages.showMessage(context, L10n.of(context).activityNotFound);
    }
  }

  /// `ConfirmDeleteDialog(this, callback, 1).dismissCurrentAndShow()`
  /// (`show-habit.delete#4`, `show-habit.delete#5`).
  @override
  Future<void> showDeleteConfirmationScreen(void Function() callback) async {
    final confirmed = await _dismissCurrentAndShow<bool>(
      () => showConfirmDeleteDialog(context, quantity: 1),
    );
    // `OnConfirmedCallback` has no cancel half: "No" simply never calls back.
    if (confirmed ?? false) callback();
  }

  /// `finish()`.
  @override
  void close() {
    Navigator.of(context).pop();
  }

  // -----------------------------------------------------------------------
  // The view
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ShowHabitModel>.value(
      value: _model,
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final model = context.watch<ShowHabitModel>();
    final state = model.state;
    final theme = state.theme;
    final l10n = L10n.of(context);

    // `onCreateOptionsMenu` is called once per menu build — and the options
    // menu of this activity is built exactly once. See [_menuItems].
    final items = _menuItems;

    return Scaffold(
      // `@style/CardList` and the ScrollView both take ?windowBackgroundColor.
      backgroundColor: _toFlutterColor(theme.appBackgroundColor),
      appBar: AppBar(
        // `show-habit.screen-scaffold#8`: the title is habit.name, verbatim.
        title: Text(state.title),
        // `show-habit.screen-scaffold#9`. The Android dark themes set
        // useHabitColorAsPrimary=false and fall back to ?colorPrimary, a value
        // the ported core Theme does not carry, so the habit colour is used in
        // both themes here.
        // The habit's colour tints the toolbar only while the theme says so;
        // the dark themes use colorPrimary (show-habit.screen-scaffold#9).
        backgroundColor:
            _toFlutterColor(theme.toolbarColorFor(theme.colorOf(state.color))),
        // `@style/Toolbar` applies ThemeOverlay.AppCompat.Dark.ActionBar.
        foregroundColor: Colors.white,
        // `toolbar.elevation = dpToPixels(context, 2f)`
        elevation: 2,
        actions: <Widget>[
          // `app:showAsAction="ifRoom"` — only Edit is ever promoted out of
          // the overflow (`show-habit.menu#2`).
          for (final item in items)
            if (item.isActionButton)
              IconButton(
                key: item == ShowHabitMenuItem.edit
                    ? ShowHabitScreen.editActionKey
                    : ShowHabitScreen.menuItemKey(item),
                tooltip: item.title(l10n),
                icon: const Icon(Icons.edit),
                onPressed: () => model.menu.onOptionsItemSelected(item),
              ),
          // …and everything else lives behind the three dots.
          PopupMenuButton<ShowHabitMenuItem>(
            key: ShowHabitScreen.overflowMenuKey,
            onSelected: model.menu.onOptionsItemSelected,
            itemBuilder: (context) => <PopupMenuEntry<ShowHabitMenuItem>>[
              for (final item in items)
                if (!item.isActionButton)
                  PopupMenuItem<ShowHabitMenuItem>(
                    key: ShowHabitScreen.menuItemKey(item),
                    value: item,
                    child: Text(item.title(l10n)),
                  ),
            ],
          ),
        ],
      ),
      // `ShowHabitView.setState()`'s last statement is
      // `binding.linearLayout.applyBottomInset()`
      // (`audit4.habit-detail-screen-never-applies-the#1`). The LinearLayout is
      // the ScrollView's *child* — and both declare
      // `android:clipToPadding="false"` — so the inset travels with the cards
      // rather than shrinking the viewport: the last card scrolls under the
      // navigation bar and then clear of it, instead of never reaching it.
      // That is why [BottomInset] is inside the scroll view here and outside it
      // on the About screen, whose layout applies the same helper to the view
      // that scrolls.
      body: _wrapWithRefresh(
        context,
        SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: BottomInset(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
            // `show-habit.card-order-and-visibility#1`: the column follows
            // ShowHabitCard's declaration order, and #2/#3/#4 decide which of
            // them survive.
            children: <Widget>[
              // Above the ported column rather than inside it: that column
              // follows `ShowHabitCard`'s declaration order, a parity rule
              // closed by tests, and adding entries to the enum would make
              // those tests assert something the ledger does not say.
                ..._buildSleepCards(context, model),
                ..._buildCards(context, model),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pull to refresh, for a sleep habit only.
  ///
  /// Sleep arrives from outside the app, on the platform's schedule; every
  /// other habit's data is only ever written here, so there is nothing for the
  /// gesture to fetch and the ported screen must not grow one
  /// (`show-habit.screen-scaffold#1`).
  Widget _wrapWithRefresh(BuildContext context, Widget child) {
    final int? id = widget.habit.id;
    if (id == null || widget.scope.sleepRepository.goalFor(id) == null) {
      return child;
    }
    return RefreshIndicator(
      onRefresh: () async {
        await widget.scope.syncSleepHabits();
        if (mounted) setState(() {});
      },
      child: child,
    );
  }

  /// The blocks a sleep habit gets, and no other habit does.
  ///
  /// Empty for every habit without a sleep goal, which is the same test that
  /// decides everywhere else what a sleep habit is.
  List<Widget> _buildSleepCards(BuildContext context, ShowHabitModel model) {
    final AppScope scope = widget.scope;
    final int? id = widget.habit.id;
    if (id == null) return const <Widget>[];
    final core.SleepGoal? goal = scope.sleepRepository.goalFor(id);
    if (goal == null) return const <Widget>[];

    return buildSleepSection(
      context,
      scope: scope,
      habit: widget.habit,
      goal: goal,
      theme: model.state.theme,
    );
  }

  /// `ShowHabitView.setState` walking show_habit.xml top to bottom.
  List<Widget> _buildCards(BuildContext context, ShowHabitModel model) {
    final widgets = <Widget>[];
    for (final card in model.cards) {
      if (!model.isVisible(card)) continue;
      widgets.add(_buildCard(context, model: model, card: card));
    }
    return widgets;
  }

  Widget _buildCard(
    BuildContext context, {
    required ShowHabitModel model,
    required ShowHabitCard card,
  }) {
    final state = model.state;
    final key = ShowHabitScreen.cardKey(card);
    switch (card) {
      case ShowHabitCard.subtitle:
        return _SubtitleCard(
          key: key,
          theme: state.theme,
          child: SubtitleCardView(state: state.subtitle),
        );
      case ShowHabitCard.notes:
        return _Card(
          key: key,
          theme: state.theme,
          child: NotesCardView(state: state.notes, theme: state.theme),
        );
      case ShowHabitCard.overview:
        return _Card(
          key: key,
          theme: state.theme,
          // `<OverviewCardView style="@style/Card"
          // android:paddingTop="12dp"/>`, the same inline override the target
          // card carries (`audit8.the-overview-card-ignores-its-own#1`).
          padding: _Card.defaultPadding.copyWith(top: 12),
          child: OverviewCardView(state: state.overview),
        );
      // The six chart cards bring their own `@style/Card` chrome with them.
      case ShowHabitCard.target:
        return TargetCardView(key: key, state: state.target);
      case ShowHabitCard.score:
        return ScoreCardView(
          key: key,
          state: state.scores,
          onSpinnerPosition: model.presenter.scoreCardPresenter.onSpinnerPosition,
        );
      case ShowHabitCard.bar:
        return BarCardView(
          key: key,
          state: state.bar,
          onNumericalSpinnerPosition:
              model.presenter.barCardPresenter.onNumericalSpinnerPosition,
          onBoolSpinnerPosition:
              model.presenter.barCardPresenter.onBoolSpinnerPosition,
        );
      case ShowHabitCard.history:
        return HistoryCardView(
          key: key,
          state: state.history,
          // `setListener(presenter)` wires the Edit button and nothing else:
          // the card's own chart is read-only, and the presenter reaches a
          // chart only inside the history-editor dialog this button opens
          // (`audit3.the-calendar-card-on-the-habit#1`).
          onClickEditButton: model.presenter.historyCardPresenter.onClickEditButton,
        );
      case ShowHabitCard.streak:
        return StreakCardView(key: key, state: state.streaks);
      case ShowHabitCard.frequency:
        return FrequencyCardView(key: key, state: state.frequency);
    }
  }
}

/// `@style/Card`, from res/values/styles.xml, on top of `@style/CardCommon`:
/// full width, 16dp/4dp horizontal padding, 16dp vertical padding, 3dp side
/// margins, a 1dp bottom margin, 1dp of elevation and the ?cardBgColor
/// background (`show-habit.card-order-and-visibility#5`).
class _Card extends StatelessWidget {
  const _Card({
    required this.theme,
    required this.child,
    this.padding = defaultPadding,
    super.key,
  });

  final core.Theme theme;
  final Widget child;

  /// The inline `android:padding*` override the card's element in
  /// show_habit.xml carries, or [defaultPadding] when it carries none.
  final EdgeInsets padding;

  static const EdgeInsets defaultPadding = EdgeInsets.fromLTRB(16, 16, 4, 16);
  static const EdgeInsets margin = EdgeInsets.fromLTRB(3, 0, 3, 1);
  static const double elevation = 1.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        elevation: elevation,
        color: _toFlutterColor(theme.cardBackgroundColor),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// `@style/ShowHabit.Subtitle`, from res/values/styles_show_habit.xml: the one
/// card that is not a `@style/Card` — ?headerBackgroundColor, 2dp of
/// elevation, no margins and a 60dp start padding
/// (`show-habit.card-order-and-visibility#6`).
class _SubtitleCard extends StatelessWidget {
  const _SubtitleCard({required this.theme, required this.child, super.key});

  final core.Theme theme;
  final Widget child;

  static const EdgeInsetsDirectional padding =
      EdgeInsetsDirectional.fromSTEB(60, 15, 10, 10);
  static const double elevation = 2.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: elevation,
      // `?headerBackgroundColor` is the Android theme ATTRIBUTE, which
      // `AppBaseThemeDark.PureBlack` declares as `@color/black`; the Themes.kt
      // token of the same name is inherited unchanged from DarkTheme and stays
      // grey_900 (`audit12.the-date-strip-and-subtitle-card-read#1`).
      color: _toFlutterColor(theme.attrHeaderBackgroundColor),
      child: Padding(padding: padding, child: child),
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
