// See app_scope.dart: the presenters and the command layer are not re-exported
// from uhabits_core.dart yet.
// ignore_for_file: implementation_imports

import 'package:flutter/foundation.dart';
import 'package:uhabits_core/src/commands/create_habit_command.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
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
    _observableListener = ModelObservableListener(_onModelChange);
    _preferencesListener = _ListHabitsPreferencesListener(
      onQuestionMarksChanged: _onQuestionMarksChanged,
    );
  }

  final AppScope scope;

  late final ListHabitsBehavior _behavior;

  late final ListHabitsMenuBehavior _menuBehavior;

  /// `ListHabitsMenu.behavior` — the presenter behind the toolbar menu.
  ListHabitsMenuBehavior get menu => _menuBehavior;

  /// `ListHabitsMenu.isSearchActive` — whether the toolbar is currently showing
  /// the `SearchView` instead of the `actionItems` group.
  ///
  /// It is held here, and not in `ListHabitsMenuState`, because the Kotlin
  /// class that owns it is `@ActivityScope`: one `ListHabitsMenu` for the whole
  /// activity, whose options menu the contextual action bar overlays without
  /// destroying. `ListHabitsSelectionMenu` inflates its items into the
  /// `ActionMode`'s own `Menu` and `onDestroyActionMode` invalidates nothing,
  /// so a long press, a colour change or a Back out of the contextual bar
  /// leaves the search bar expanded and still holding `behavior.searchQuery`.
  ///
  /// The port has no action mode: the screen swaps the whole `AppBar` widget
  /// for `ListHabitsSelectionMenu` while a selection is active, which disposes
  /// the toolbar's `State`. A flag living there would reset to false, and the
  /// user would come back to an ordinary-looking toolbar over a list still
  /// filtered by an invisible query — the very state the two-stage X button of
  /// `audit7.the-search-bar-s-x-button#1` exists to prevent
  /// (`audit9.search-bar-survives-selection-mode#1`).
  ///
  /// Not a notifying property: `invalidateOptionsMenu()` is what redraws the
  /// menu upstream, and the toolbar's `setState` is its port.
  bool isSearchActive = false;

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
        // A sleep habit answers "Enter" with its night, not with a number.
        // No parity rule covers it: the original has no such habit.
        if (scope.sleepRepository.goalFor(habitId) != null) {
          onEnterSleepNight?.call(habit, date);
        } else {
          _behavior.onEdit(habit, date, 0, 0);
        }
      }
    }
    pendingIntent = null;
  }

  late final ModelObservableListener _observableListener;

  /// Whether the adapter's `ModelObservable` has fired at least once.
  ///
  /// `ListHabitsRootView.onModelChange()` is the *only* call site of
  /// `updateEmptyView()`, and it is the `ModelObservable.Listener` callback on
  /// `listAdapter.observable`, which `HabitCardListAdapter` notifies only from
  /// `onItemInserted`/`onItemChanged`/`onItemMoved`/`onItemRemoved`/
  /// `onRefreshFinished`/`clearSelection` — i.e. once the first
  /// `HabitCardListCache` refresh has reported. Until then `EmptyListView` is
  /// still at the `visibility = View.GONE` its constructor gave it and the
  /// Android user sees a blank area under the header
  /// (`audit12.the-habit-list-flashes-the-empty-state#1`).
  ///
  /// It is a one-way latch on purpose: a later detach/re-attach leaves the
  /// Android view at whatever the previous `onModelChange` decided, and
  /// `refreshAllHabits` never clears the cache's data.
  bool _hasModelChanged = false;

  /// `ListHabitsRootView.onModelChange()`.
  void _onModelChange() {
    _hasModelChanged = true;
    notifyListeners();
  }

  /// `ListHabitsActivity` as a `Preferences.Listener` — `prefs.addListener(
  /// this)` in `onCreate`.
  late final _ListHabitsPreferencesListener _preferencesListener;

  /// ```kotlin
  /// override fun onQuestionMarksChanged() {
  ///     invalidateOptionsMenu()
  ///     menu.behavior.onPreferencesChanged()
  /// }
  /// ```
  ///
  /// The filter the menu applies is chosen from `areQuestionMarksEnabled`
  /// every time it is rebuilt — `isEnteredAllowed` when they are on,
  /// `isCompletedAllowed` when they are off — and the preference is written
  /// from a different screen. Without this relay the list keeps whichever
  /// matcher it was built with until the process restarts
  /// (`verify.question-marks-filter`).
  void _onQuestionMarksChanged() {
    // `invalidateOptionsMenu()`: the toolbar redraws from the new preference
    // (the "Hide completed" item is titled "Hide entered" while question marks
    // are on).
    notifyListeners();
    _menuBehavior.onPreferencesChanged();
  }

  bool _attached = false;

  bool _didStartup = false;

  int _buttonCount = 0;

  // ---------------------------------------------------------------------
  // ListHabitsBehavior.Screen handlers, installed by the widget layer
  // ---------------------------------------------------------------------

  void Function(Habit habit)? onShowHabitScreen;

  /// `ListHabitsScreen.showIntroScreen()`, the one handler that can be asked
  /// for before it is installed.
  ///
  /// `ListHabitsActivity.onCreate` assigns `screen = component
  /// .listHabitsScreen` and only then calls `behavior.onStartup()`, so the
  /// presenter upstream always has a Screen to reach. Here the model is built
  /// by the widget layer — [attach] runs `onStartup()` from the provider's
  /// `create`, a moment before the widget that owns this field has it in hand —
  /// and a first run asks for the intro inside that window. Assigning the
  /// handler therefore delivers a request that has been waiting, which is what
  /// upstream's ordering gives for free (`verify.intro-never-shown#1`, `#2`).
  ///
  /// Exactly one request can be waiting: `onFirstRun()` clears `isFirstRun`
  /// before it asks, so there is never a second one.
  void Function()? get onShowIntroScreen => _onShowIntroScreen;

  set onShowIntroScreen(void Function()? handler) {
    _onShowIntroScreen = handler;
    if (handler == null || !_introScreenPending) return;
    _introScreenPending = false;
    handler();
  }

  void Function()? _onShowIntroScreen;

  bool _introScreenPending = false;

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

  /// Opens a night for a sleep habit, for the day a reminder pointed at.
  ///
  /// A sleep habit's value is computed from a night rather than typed in, so
  /// the numeric popup an ACTION_EDIT normally raises would take a percentage
  /// the next recompute overwrites. Set by the screen, which is what can show
  /// a sheet.
  void Function(Habit habit, LocalDate date)? onEnterSleepNight;

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
    // `prefs.addListener(this)`. Upstream this happens in `onCreate` and is
    // never undone; here it is bracketed with the rest of the screen's
    // subscriptions, which is the same window plus a tidy unsubscribe.
    scope.preferences.addListener(_preferencesListener);
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
    scope.preferences.removeListener(_preferencesListener);
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

  /// Определение привычки-воздержания, или null для любой другой.
  ///
  /// Читается из базы, но не на каждый кадр: строка списка перестраивается на
  /// каждой прокрутке, а определение меняется только вместе с моделью — и
  /// [notifyListeners] и есть тот момент, когда старый ответ перестаёт быть
  /// верным.
  ///
  /// `kind` спрашивается наравне с днём: у сна `committed_from` есть null, и
  /// «непустой день» без проверки вида был бы признаком, который однажды
  /// поймает не того. Признак считается здесь, один раз, и ниже едет уже
  /// готовый ответ — определение целиком, потому что срывом день называет
  /// `isAbstinenceLapse(definition, величина)`, и допуск он берёт оттуда.
  HabitDefinition? abstinenceDefinitionOf(Habit habit) {
    final int? id = habit.id;
    if (id == null) return null;
    return _abstinenceDefinitions.putIfAbsent(id, () {
      final HabitDefinition? definition = scope.definitions.forHabit(id);
      if (definition == null) return null;
      if (definition.kind != ComputedKind.abstinence) return null;
      if (definition.committedFrom == null) return null;
      return definition;
    });
  }

  final Map<int, HabitDefinition?> _abstinenceDefinitions =
      <int, HabitDefinition?>{};

  @override
  void notifyListeners() {
    _abstinenceDefinitions.clear();
    super.notifyListeners();
  }

  /// Reads the *unfiltered* list, so it stays false when a filter happens to
  /// hide everything.
  bool get hasNoHabit => scope.adapter.hasNoHabit();

  /// `EmptyListView.showEmpty()`: nothing to show and nothing to hide.
  ///
  /// Gated on [_hasModelChanged] because `updateEmptyView()` runs off
  /// `onModelChange()` and nothing else: before the adapter's first
  /// notification the view is simply GONE upstream, whichever branch the cache
  /// is about to land on (`audit12.the-habit-list-flashes-the-empty-state#1`).
  bool get showEmptyState => _hasModelChanged && itemCount == 0 && hasNoHabit;

  /// `EmptyListView.showDone()`: habits exist, but the filter hides them all.
  ///
  /// Same gate as [showEmptyState], and the branch that made the gate
  /// necessary: `hasNoHabit` reads the unfiltered SQLite-backed list, so it is
  /// already false on the frame before the first refresh lands, and an
  /// ungated screen greeted every cold start with "You're all done for today!"
  bool get showDoneState => _hasModelChanged && itemCount == 0 && !hasNoHabit;

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
  void showIntroScreen() {
    final handler = _onShowIntroScreen;
    // Held rather than dropped: the widget layer installs its handlers a moment
    // after `create` has already run `onStartup()`, and this is the one call
    // that arrives inside that window. See [onShowIntroScreen].
    if (handler == null) {
      _introScreenPending = true;
      return;
    }
    handler();
  }

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

/// The `Preferences.Listener` half of `ListHabitsActivity`.
///
/// Kotlin's listener is an interface with default methods and the activity
/// implements it directly. The Dart port of it is a concrete class with empty
/// bodies, so a [ChangeNotifier] cannot also be one: the model relays through
/// this instead, exactly as `SettingsModel` does
/// (lib/state/settings_model.dart).
class _ListHabitsPreferencesListener extends PreferencesListener {
  _ListHabitsPreferencesListener({
    required void Function() onQuestionMarksChanged,
  }) : _onQuestionMarksChanged = onQuestionMarksChanged;

  final void Function() _onQuestionMarksChanged;

  @override
  void onQuestionMarksChanged() => _onQuestionMarksChanged();
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
