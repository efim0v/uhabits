// See app_scope.dart: the presenters and the command layer are not re-exported
// from uhabits_core.dart yet.
// ignore_for_file: implementation_imports

import 'package:flutter/foundation.dart';
import 'package:uhabits_core/src/commands/create_habit_command.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/ui/intent_parser.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_adapter.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_controller.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_behavior.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_menu_behavior.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_selection_menu_behavior.dart';
import 'package:uhabits_core/uhabits_core.dart';

import 'app_scope.dart';

export 'package:uhabits_core/src/ui/intent_parser.dart' show Intent;
export 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_adapter.dart'
    show HabitCardData;
export 'package:uhabits_core/src/ui/screens/habits/list/list_habits_behavior.dart'
    show
        CheckMarkDialogCallback,
        ListHabitsBehaviorMessage,
        NumberPickerCallback;

/// The screen-facing half of the habit list.
///
/// Everything it does is delegation: the data comes from the core
/// [HabitCardListAdapter] (`HabitCardListAdapter.kt`) and every gesture is
/// forwarded to the core [ListHabitsBehavior] presenter, which turns it into a
/// command. The only thing this class adds is the [ChangeNotifier] that a
/// Flutter list needs — it stands in for `notifyItemChanged` and friends, which
/// is exactly the role `HabitCardListView` plays in the Android app.
///
/// The presenter calls back into `ListHabitsBehavior.Screen`. Those calls need
/// a `BuildContext` (dialogs, navigation), so the model implements the
/// interface and re-emits each call through a nullable handler that the widget
/// installs while it is mounted.
class HabitListModel extends ChangeNotifier
    implements
        HabitCardListAdapterListener,
        ListHabitsBehaviorScreen,
        ListHabitsMenuBehaviorScreen,
        ListHabitsMenuThemeSwitcher,
        HabitCardListSelectionMenu,
        ListHabitsSelectionMenuBehaviorScreen {
  HabitListModel(this.scope) {
    // `ListHabitsMenu.behavior`. Its init block seeds showArchived /
    // showCompleted from the preferences and installs the first filter
    // (`list-habits.filters#1`).
    _menuBehavior = ListHabitsMenuBehavior(
      this,
      scope.adapter,
      scope.preferences,
      this,
    );
    _behavior = ListHabitsBehavior(
      scope.habitList,
      const _UnsupportedDirFinder(),
      scope.taskRunner,
      this,
      scope.commandRunner,
      scope.preferences,
      const _UnsupportedBugReporter(),
      exportCsvTaskFactory: _unsupportedExportCsvTask,
    );
    // `ListHabitsSelectionMenu.behavior`.
    _selectionMenuBehavior = ListHabitsSelectionMenuBehavior(
      scope.habitList,
      this,
      scope.adapter,
      scope.commandRunner,
    );
    // `HabitCardListView.controller`. The menu and the controller point at each
    // other, which is why Kotlin injects the menu lazily.
    _listController = HabitCardListController(
      scope.adapter,
      _behavior,
      () => this,
    );
    _observableListener = ModelObservableListener(notifyListeners);
  }

  final AppScope scope;

  late final ListHabitsBehavior _behavior;

  late final ListHabitsMenuBehavior _menuBehavior;

  /// `ListHabitsMenu.behavior` — the presenter behind the toolbar menu.
  ListHabitsMenuBehavior get menu => _menuBehavior;

  late final ListHabitsSelectionMenuBehavior _selectionMenuBehavior;

  /// `ListHabitsSelectionMenu.behavior`.
  ListHabitsSelectionMenuBehavior get selectionMenu => _selectionMenuBehavior;

  late final HabitCardListController _listController;

  /// `HabitCardListView.controller`: the two-state machine over the selection.
  HabitCardListController get listController => _listController;

  /// `ListHabitsActivity.ACTION_EDIT`, the action a reminder's "enter"
  /// notification fires.
  static const String actionEdit = 'org.isoron.uhabits.ACTION_EDIT';

  /// `ListHabitsActivity.intent`, as last set by `onNewIntent`.
  ///
  /// The delivery is the platform's — on Android an `Intent`, here whatever the
  /// notification layer hands over — but what is done with it, and the fact
  /// that it is done exactly once, is this class's
  /// (`list-habits.startup-lifecycle#8`).
  Intent? pendingIntent;

  /// `ListHabitsSelectionMenu.notificationTray`, used only by the developer
  /// "notify" item. Null when the platform services were never started, which
  /// is what every widget test sees.
  NotificationTray? notificationTray;

  /// `ListHabitsActivity.parseIntents()`, the last statement of `onResume`.
  ///
  /// An ACTION_EDIT intent carries the habit id and the day it targets, and
  /// opens that entry's popup at (0, 0) — coordinates that make
  /// `showConfetti` return immediately (`list-habits.confetti#1`). The intent
  /// is dropped afterwards, so a resume that follows handles nothing.
  void parseIntents() {
    final intent = pendingIntent;
    if (intent == null) return;
    if (intent.action == actionEdit) {
      // `intent.extras?.getLong(...)`: null only when the intent carries no
      // extras at all. A *missing* key inside a present bundle reads as 0,
      // and `habitList.getById(0)!!` then throws — upstream behaviour.
      if (intent.extras.isNotEmpty) {
        final habitId = intent.getLongExtra('habit', 0);
        final timestampMillis = intent.getLongExtra('timestamp', 0);
        final habit = scope.habitList.getById(habitId)!;
        final date = LocalDate.fromUnixTime(timestampMillis);
        _behavior.onEdit(habit, date, 0, 0);
      }
    }
    pendingIntent = null;
  }

  late final ModelObservableListener _observableListener;

  bool _attached = false;

  bool _didStartup = false;

  int _buttonCount = 0;

  // ---------------------------------------------------------------------
  // ListHabitsBehavior.Screen handlers, installed by the widget layer
  // ---------------------------------------------------------------------

  void Function(Habit habit)? onShowHabitScreen;
  void Function()? onShowIntroScreen;
  void Function(ListHabitsBehaviorMessage message)? onShowMessage;
  void Function(double value, String notes, NumberPickerCallback callback)?
      onShowNumberPopup;
  void Function(
    int selectedValue,
    String notes,
    PaletteColor color,
    CheckMarkDialogCallback callback,
  )? onShowCheckmarkPopup;
  void Function(PaletteColor color, double x, double y)? onShowConfetti;

  // ---------------------------------------------------------------------
  // ListHabitsMenuBehavior.Screen handlers, installed by the widget layer
  // ---------------------------------------------------------------------

  void Function()? onApplyTheme;
  void Function()? onShowAboutScreen;
  void Function()? onShowFAQScreen;
  void Function()? onShowSettingsScreen;
  void Function()? onShowSelectHabitTypeDialog;

  /// The `ThemeSwitcher` slice the menu needs. Installed by the widget layer,
  /// which is where the app's [ThemeModel] lives.
  bool Function()? nightModeGetter;
  void Function()? nightModeToggle;

  // ---------------------------------------------------------------------
  // ListHabitsSelectionMenu handlers, installed by the widget layer
  // ---------------------------------------------------------------------

  /// `activity.startSupportActionMode(this)`.
  void Function()? onSelectionStarted;

  /// `activeActionMode?.invalidate()`.
  void Function()? onSelectionChanged;

  /// `activeActionMode?.finish()`.
  void Function()? onSelectionFinished;

  void Function(PaletteColor defaultColor, OnColorPickedCallback callback)?
      onShowColorPicker;
  void Function(OnConfirmedCallback callback, int quantity)?
      onShowDeleteConfirmationScreen;
  void Function(List<Habit> selected)? onShowEditHabitsScreen;

  // ---------------------------------------------------------------------
  // Lifecycle. Port of ListHabitsActivity.onResume / onPause.
  // ---------------------------------------------------------------------

  void attach() {
    if (_attached) return;
    _attached = true;
    scope.adapter.setListener(this);
    scope.adapter.observable.addListener(_observableListener);
    scope.adapter.onAttached();
    if (!_didStartup) {
      _didStartup = true;
      // ListHabitsActivity.onCreate: increments the launch count and, on a
      // first run, seeds the hints and asks for the intro screen.
      _behavior.onStartup();
    }
    refresh();
    // `ListHabitsActivity.onResume` ends with `parseIntents()`.
    parseIntents();
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    scope.adapter.cancelRefresh();
    scope.adapter.onDetached();
    scope.adapter.observable.removeListener(_observableListener);
    scope.adapter.setListener(null);
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------

  int get itemCount => scope.adapter.itemCount;

  /// The five values `onBindViewHolder` pushes into a card. Null while the
  /// adapter has no listener attached.
  HabitCardData? cardAt(int position) => scope.adapter.bindCardView(position);

  /// Reads the *unfiltered* list, so it stays false when a filter happens to
  /// hide everything.
  bool get hasNoHabit => scope.adapter.hasNoHabit();

  /// `EmptyListView.showEmpty()`: nothing to show and nothing to hide.
  bool get showEmptyState => itemCount == 0 && hasNoHabit;

  /// `EmptyListView.showDone()`: habits exist, but the filter hides them all.
  bool get showDoneState => itemCount == 0 && !hasNoHabit;

  /// How many checkmark columns fit on screen. Port of
  /// `ListHabitsRootView.getCheckmarkCount()`, which the widget layer feeds
  /// from its own width.
  int get buttonCount => _buttonCount;

  set buttonCount(int value) {
    if (_buttonCount == value) return;
    _buttonCount = value;
    notifyListeners();
  }

  List<Habit> get selected => scope.adapter.selected;

  bool get isSelectionEmpty => scope.adapter.isSelectionEmpty;

  /// `HabitCardListAdapter.isSortable`: true only while the primary order is
  /// BY_POSITION (`list-habits.drag-reorder#1`).
  bool get isSortable => scope.adapter.isSortable;

  void toggleSelection(int position) => scope.adapter.toggleSelection(position);

  void clearSelection() => scope.adapter.clearSelection();

  void refresh() => scope.adapter.refresh();

  // ---------------------------------------------------------------------
  // Gestures, forwarded to the presenter
  // ---------------------------------------------------------------------

  void onClickHabit(Habit habit) => _behavior.onClickHabit(habit);

  void onToggle(
    Habit habit,
    LocalDate date,
    int value,
    String notes, [
    double x = 0,
    double y = 0,
  ]) {
    _behavior.onToggle(habit, date, value, notes, x, y);
  }

  void onEdit(Habit habit, LocalDate date, [double x = 0, double y = 0]) {
    _behavior.onEdit(habit, date, x, y);
  }

  void onReorderHabit(Habit from, Habit to) =>
      _behavior.onReorderHabit(from, to);

  /// Runs a [CreateHabitCommand] with [template] as the model.
  ///
  /// The template never enters the list: `CreateHabitCommand.run` builds a
  /// fresh habit from the factory and copies the template's fields into it.
  void createHabit(Habit template) {
    scope.commandRunner.run(
      CreateHabitCommand(scope.modelFactory, scope.habitList, template),
    );
  }

  /// Convenience for the create dialog: a template carrying just a name and a
  /// colour, on top of whatever `ModelFactory.buildHabit()` defaults to.
  Habit buildHabitTemplate({required String name, PaletteColor? color}) {
    final habit = scope.modelFactory.buildHabit();
    habit.name = name;
    habit.color = color ??
        PaletteColor(
          scope.preferences.getDefaultHabitColor(habit.color.paletteIndex),
        );
    return habit;
  }

  // ---------------------------------------------------------------------
  // HabitCardListAdapter.Listener — the RecyclerView notifications
  // ---------------------------------------------------------------------

  @override
  void onItemChanged(int position) => notifyListeners();

  @override
  void onItemInserted(int position) => notifyListeners();

  @override
  void onItemMoved(int oldPosition, int newPosition) => notifyListeners();

  @override
  void onItemRemoved(int position) => notifyListeners();

  @override
  void onDataSetChanged() => notifyListeners();

  // ---------------------------------------------------------------------
  // ListHabitsBehavior.Screen
  // ---------------------------------------------------------------------

  @override
  void showHabitScreen(Habit h) => onShowHabitScreen?.call(h);

  @override
  void showIntroScreen() => onShowIntroScreen?.call();

  @override
  void showMessage(ListHabitsBehaviorMessage m) => onShowMessage?.call(m);

  @override
  void showNumberPopup(
    double value,
    String notes,
    NumberPickerCallback callback,
  ) {
    final handler = onShowNumberPopup;
    if (handler == null) {
      callback.onNumberPickerDismissed();
      return;
    }
    handler(value, notes, callback);
  }

  @override
  void showCheckmarkPopup(
    int selectedValue,
    String notes,
    PaletteColor color,
    CheckMarkDialogCallback callback,
  ) {
    final handler = onShowCheckmarkPopup;
    if (handler == null) {
      callback.onNotesDismissed();
      return;
    }
    handler(selectedValue, notes, color, callback);
  }

  @override
  void showConfetti(PaletteColor color, double x, double y) =>
      onShowConfetti?.call(color, x, y);

  /// CSV export and the bug reporter belong to the menu slice; the presenter
  /// takes them in its constructor, so they are stubbed rather than omitted.
  @override
  void showSendBugReportToDeveloperScreen(String log) =>
      throw UnsupportedError('The bug report screen is not ported yet');

  @override
  void showSendFileScreen(String filename) =>
      throw UnsupportedError('The send file screen is not ported yet');

  // ---------------------------------------------------------------------
  // ListHabitsMenuBehavior.Screen and the ThemeSwitcher slice
  // ---------------------------------------------------------------------

  @override
  void applyTheme() => onApplyTheme?.call();

  @override
  void showAboutScreen() => onShowAboutScreen?.call();

  @override
  void showFAQScreen() => onShowFAQScreen?.call();

  @override
  void showSettingsScreen() => onShowSettingsScreen?.call();

  @override
  void showSelectHabitTypeDialog() => onShowSelectHabitTypeDialog?.call();

  @override
  bool get isNightMode => nightModeGetter?.call() ?? false;

  @override
  void toggleNightMode() => nightModeToggle?.call();

  // ---------------------------------------------------------------------
  // HabitCardListSelectionMenu and ListHabitsSelectionMenuBehavior.Screen
  // ---------------------------------------------------------------------

  @override
  void onSelectionStart() => onSelectionStarted?.call();

  @override
  void onSelectionChange() => onSelectionChanged?.call();

  @override
  void onSelectionFinish() => onSelectionFinished?.call();

  @override
  void showColorPicker(
    PaletteColor defaultColor,
    OnColorPickedCallback callback,
  ) =>
      onShowColorPicker?.call(defaultColor, callback);

  @override
  void showDeleteConfirmationScreen(
    OnConfirmedCallback callback,
    int quantity,
  ) =>
      onShowDeleteConfirmationScreen?.call(callback, quantity);

  @override
  void showEditHabitsScreen(List<Habit> selected) =>
      onShowEditHabitsScreen?.call(selected);

  /// `R.id.action_notify`, the developer-only item: show today's notification
  /// for every selected habit, with reminder time 0, and leave the selection
  /// alone (`list-habits.selection-menu-actions#9`).
  void onNotifyHabits() {
    final tray = notificationTray ?? scope.notificationTray;
    if (tray == null) return;
    final today = getToday();
    for (final habit in scope.adapter.selected) {
      tray.show(habit, today, 0);
    }
  }
}

class _UnsupportedDirFinder implements ListHabitsBehaviorDirFinder {
  const _UnsupportedDirFinder();

  @override
  UserFile getCSVOutputDir() =>
      throw UnsupportedError('CSV export is not ported yet');
}

class _UnsupportedBugReporter implements ListHabitsBehaviorBugReporter {
  const _UnsupportedBugReporter();

  @override
  void dumpBugReportToFile() =>
      throw UnsupportedError('The bug reporter is not ported yet');

  @override
  String getBugReport() =>
      throw UnsupportedError('The bug reporter is not ported yet');
}

Task _unsupportedExportCsvTask(
  HabitList habitList,
  List<Habit> selectedHabits,
  UserFile outputDir,
  ExportCsvListener listener,
) {
  throw UnsupportedError('CSV export is not ported yet');
}
