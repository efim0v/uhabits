/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/{ListHabitsActivity,ListHabitsRootView,ListHabitsScreen}.kt
///
/// The three Kotlin classes collapse into one widget plus one [HabitListModel]:
///
///  * `ListHabitsActivity` is the lifecycle — `onResume` attaches the adapter
///    and refreshes it, `onPause` detaches and cancels. That is
///    [HabitListModel.attach] / [HabitListModel.detach], driven here by the
///    provider that owns the model.
///  * `ListHabitsRootView` is the layout: the konfetti overlay, a toolbar, the
///    date strip, the card list with the empty view over it, the task progress
///    bar and the hint box — see `list_habits_root_view.dart` for the last
///    four. Its `getCheckmarkCount()` is [_HabitListViewState._checkmarkCount]
///    and its `updateEmptyView()` is [_HabitListViewState._buildEmptyView].
///  * `ListHabitsScreen` is `ListHabitsBehavior.Screen`: the dialogs and
///    navigation the presenter asks for. Those need a `BuildContext`, so they
///    are installed on the model as handlers while this widget is mounted.
///
/// The Android toolbar carries the create-habit action; this screen also has a
/// floating action button for it.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// The core package does not re-export lib/src/time/date_utils.dart either; it
// is where `computeToday` lives.
// ignore: implementation_imports
import 'package:uhabits_core/src/time/date_utils.dart' as core;
// The core package does not re-export lib/src/ui/screens yet.
// ignore: implementation_imports
import 'package:uhabits_core/src/ui/screens/habits/list/hint_list.dart' as core;
// ignore: implementation_imports
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_selection_menu_behavior.dart'
    as core;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../platform/external_links.dart';
import '../../../platform/flutter_files.dart';
import '../../../state/app_scope.dart';
import '../../../state/habit_list_model.dart';
import '../../../state/intent_router.dart' as intents;
import '../../../state/settings_model.dart' show SettingsResult;
import '../../../state/theme_model.dart';
import '../../../state/widget_link.dart';
import '../../about/about_screen.dart';
import '../../common/dialogs/checkmark_dialog.dart';
import '../../common/dialogs/color_picker_dialog.dart';
import '../../common/dialogs/confirm_delete_dialog.dart';
import '../../common/dialogs/current_dialog.dart';
import '../../common/dialogs/number_dialog.dart';
import '../../common/screen_route_observer.dart';
import '../../intro/intro_screen.dart';
import '../../settings/data_actions.dart';
import '../../settings/settings_screen.dart';
import '../../theme/app_theme.dart' show coreThemeOf;
import '../edit/edit_habit_screen.dart';
import '../show/show_habit_screen.dart';
import 'habit_card.dart';
import 'list_habits_command_toasts.dart';
import 'list_habits_menu.dart';
import 'list_habits_root_view.dart';
import 'list_habits_selection_menu.dart';
import 'list_header.dart';

/// `resources.getStringArray(R.array.hints)`.
///
/// `R.array.hints` is a `<string-array>` of two `@string` references —
/// `@string/hint_drag` then `@string/hint_landscape` — so Android resolves
/// both through the device locale and every one of the 47 shipped translations
/// reaches the hint box. That is what this rebuilds: the same two entries, in
/// the same order, read off the ambient [L10n] rather than off
/// `core.listHabitsHints`, which is the English source array the core keeps as
/// data (`verify.hints-hardcoded-english#1`).
List<String> listHabitsHintsOf(L10n l10n) => <String>[
      l10n.hintDrag,
      l10n.hintLandscape,
    ];

/// The main screen. Owns the [HabitListModel] for as long as it is mounted.
class HabitListScreen extends StatelessWidget {
  const HabitListScreen({this.onOpenUrl, this.widgetLinks, super.key});

  /// The habit card list — a `ListView` or a `ReorderableListView`, depending
  /// on whether the adapter is sortable, so callers that only want "the list"
  /// address it by key.
  static const Key habitCardListKey = ValueKey<String>('habitCardList');

  /// `Activity.startActivitySafely(Intent(ACTION_VIEW, uri))`, which the
  /// 'Help & FAQ' menu item and the settings screen's Help and
  /// 'Rate this app' rows go through.
  ///
  /// Null is the app's own case: the screen then opens the link itself,
  /// through `platform/external_links.dart`. A test supplies its own so that
  /// no plugin is reached.
  final void Function(String url)? onOpenUrl;

  /// The app-level receiver for `uhabits://widget/...`.
  ///
  /// This screen is `ListHabitsActivity`, and upstream the ACTION_EDIT deep
  /// link is delivered straight to it: the system sets `Activity.intent`, and
  /// `parseIntents()` reads it at the end of the next `onResume`. A Flutter app
  /// has one activity for the whole process, so the link lands app-wide first;
  /// registering with the router while this screen is mounted is what puts it
  /// back where upstream had it. Null in every test that pumps the screen on
  /// its own, and on any host with no widget support.
  final WidgetLinkRouter? widgetLinks;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HabitListModel>(
      // `attach()` runs `behavior.onStartup()`, which on a first run asks for
      // the intro screen before `_HabitListView` below has installed a single
      // handler. `HabitListModel.onShowIntroScreen` is the one sink that keeps
      // such a request until the widget layer arrives, so the ordering here is
      // the ordering upstream has: the Screen is never missing.
      create: (context) => HabitListModel(context.read<AppScope>())..attach(),
      child: _HabitListView(onOpenUrl: onOpenUrl, widgetLinks: widgetLinks),
    );
  }
}

class _HabitListView extends StatefulWidget {
  const _HabitListView({this.onOpenUrl, this.widgetLinks});

  final void Function(String url)? onOpenUrl;

  final WidgetLinkRouter? widgetLinks;

  @override
  State<_HabitListView> createState() => _HabitListViewState();
}

class _HabitListViewState extends State<_HabitListView>
    with RestorationMixin, WidgetsBindingObserver
    implements RouteAware {
  /// `HabitCardListView.dataOffset`, fed by the header's scroll controller —
  /// `ListHabitsRootView.setupControllers`.
  ///
  /// `HabitCardListView.onSaveInstanceState` puts it in the saved instance
  /// state next to the header's own scroller state
  /// (`list-habits.header-scrolling#8`).
  final RestorableInt _dataOffsetState = RestorableInt(0);

  int get _dataOffset => _dataOffsetState.value;

  set _dataOffset(int value) => _dataOffsetState.value = value;

  @override
  String? get restorationId => 'listHabits';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_dataOffsetState, 'dataOffset');
  }

  late final HabitListModel _model;

  /// `ListHabitsScreen` as a `CommandRunner.Listener`: the per-command toast,
  /// registered while the screen is in the foreground
  /// (`commands.listener-list-habits-toasts#1`).
  late final ListHabitsCommandToasts _toasts;

  /// Whether another *screen* is on top of this one — the port's stand-in for
  /// "this activity has already been paused and stopped".
  ///
  /// Upstream the activity lifecycle carries this by construction: once
  /// `EditHabitActivity` or `ShowHabitActivity` is started, the list activity
  /// is stopped, and neither its `onPause` nor its `onResume` can run again
  /// until the screen on top is finished — a Home press from up there runs
  /// *that* activity's callbacks and none of the list's. A Flutter app has one
  /// activity for the whole process, so this widget stays mounted under the
  /// pushed route and the engine keeps sending it every lifecycle change; this
  /// flag is what stops it acting on them
  /// (`audit7.backgrounding-the-app-or-just-pulling#1`,
  /// `audit7.after-a-background-round-trip-the#1`).
  ///
  /// It is maintained by [didPushNext] / [didPopNext], which the observer only
  /// reports for `PageRoute`s: a dialog is a window over a *running* activity
  /// and pauses nothing, so an entry popup or a colour picker opened from the
  /// list leaves this false and its `onPause` still tears them down.
  bool _isCovered = false;

  /// `ListHabitsRootView.konfettiView`.
  final GlobalKey<ConfettiOverlayState> _confettiKey =
      GlobalKey<ConfettiOverlayState>();

  /// `ListHabitsRootView.hintView`, and the `HintList` it was built with.
  final GlobalKey<HintViewState> _hintKey = GlobalKey<HintViewState>();

  /// Built in [didChangeDependencies], not in [initState]: its hint array is
  /// `R.array.hints` resolved against the current locale, and reading a
  /// localization is an inherited-widget lookup, which is exactly what
  /// `didChangeDependencies` is for. Upstream this is the same moment —
  /// `ListHabitsRootView.init` asks the *activity's* resources, so the array is
  /// resolved after the configuration is attached, and a configuration change
  /// rebuilds the view with the new one.
  core.HintList? _hintList;

  /// `ListHabitsActivity.menu`.
  final GlobalKey<ListHabitsMenuState> _menuKey =
      GlobalKey<ListHabitsMenuState>();

  /// The habit list's own scroll position, shared by the list and the
  /// [Scrollbar] drawn over it.
  ///
  /// `HabitCardListView` is built with `R.attr.scrollableRecyclerViewStyle`,
  /// whose one declaration is `android:scrollbars="vertical"`
  /// (`audit.the-habit-list-has-no-vertical#1`). Flutter draws no scrollbar on
  /// Android or iOS by default, so the port asks for one — and a scrollbar the
  /// user can drag needs the same controller the list scrolls with, which is
  /// why this is held here rather than left to the ambient
  /// `PrimaryScrollController`: the list is rebuilt as a `ListView` or a
  /// `ReorderableListView` depending on the sort order, and the position has to
  /// survive that swap.
  final ScrollController _listScrollController = ScrollController();

  /// `component.themeSwitcher`. The app installs one above this screen; the
  /// widget tests pump the screen on its own, so a local one stands in.
  late final ThemeModel _themeSwitcher;

  /// The window position of the entry button the last gesture landed on, which
  /// is `HabitCardView.getAbsoluteButtonLocation(date)`; null until one does.
  Offset? _lastEntryPress;

  /// The animator duration scale `showConfetti` reads off Settings.Global. On
  /// Flutter it is the ambient "disable animations" accessibility flag, which
  /// is the same switch (`list-habits.confetti#2`).
  double get _animatorDurationScale =>
      MediaQuery.disableAnimationsOf(context) ? 0.0 : 1.0;

  @override
  void initState() {
    super.initState();
    _model = context.read<HabitListModel>();
    // ListHabitsScreen implements ListHabitsBehavior.Screen; here the model
    // holds the presenter and re-emits its callbacks to whoever is mounted.
    _model
      // `ListHabitsScreen.showHabitScreen(h)`: startActivity(
      // IntentFactory().startShowHabitActivity(context, h)).
      ..onShowHabitScreen = ((habit) => ShowHabitScreen.open(context, habit))
      // `ListHabitsScreen.showIntroScreen()`: startActivity(intentFactory
      // .startIntroActivity(activity)) — the first-run intro, which
      // `ListHabitsBehavior.onFirstRun()` asks for.
      ..onShowIntroScreen = _showIntroScreen
      ..onShowNumberPopup = _showNumberPopup
      ..onShowCheckmarkPopup = _showCheckmarkPopup
      ..onShowConfetti = _showConfetti;
    // `ListHabitsMenu` is constructed with the activity's ThemeSwitcher and
    // the four navigation callbacks of `ListHabitsMenuBehavior.Screen`.
    _themeSwitcher = _readThemeModel() ?? ThemeModel(_model.scope.preferences);
    _model
      ..nightModeGetter = (() => _themeSwitcher.isNightMode)
      ..nightModeToggle = _themeSwitcher.toggleNightMode
      // `ListHabitsScreen.applyTheme()` restarts the activity with a fade;
      // here the ThemeModel notifies and the app rebuilds itself.
      ..onApplyTheme = _themeSwitcher.apply
      ..onShowAboutScreen = _openAbout
      ..onShowFAQScreen = _openFAQ
      ..onShowSettingsScreen = _openSettings
      ..onShowSelectHabitTypeDialog = _createHabit
      // `ListHabitsSelectionMenu` as the controller's ActionMode.Callback, and
      // as `ListHabitsSelectionMenuBehavior.Screen`.
      ..onSelectionStarted = _refreshSelectionBar
      ..onSelectionChanged = _refreshSelectionBar
      ..onSelectionFinished = _refreshSelectionBar
      ..onShowColorPicker = _showColorPicker
      ..onShowDeleteConfirmationScreen = _showDeleteConfirmation
      ..onShowEditHabitsScreen = _showEditHabitsScreen;
    // `ListHabitsActivity.onResume` -> `screen.onAttached()`.
    _toasts = ListHabitsCommandToasts(
      commandRunner: _model.scope.commandRunner,
      strings: () => L10n.of(context),
      showMessage: (message) {
        if (mounted) showListHabitsMessage(context, message);
      },
    )..onAttached();
    // After the first frame, because acting on the intent means showing a
    // dialog and there is no route to show one on until then. `onResume` has
    // the same property upstream: the window exists before `parseIntents()`
    // runs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.widgetLinks?.attachListScreen(_onDeepLinkIntent);
    });
    // Upstream this screen *is* an activity, so the system runs `onPause` when
    // the app leaves the foreground and `onResume` when it comes back. A
    // Flutter app has one activity for the whole process: this widget stays
    // mounted across a background/foreground round trip, and the provider that
    // owns the model only attaches and detaches it on mount and unmount. The
    // observer is what gives the two callbacks their other half.
    WidgetsBinding.instance.addObserver(this);
  }

  /// `ListHabitsRootView.init`: the root builds the hint list from the
  /// `R.array.hints` string-array and hands it to its HintView.
  ///
  /// `R.array.hints` is two `@string` references, so `getStringArray` resolves
  /// both through the device locale and a French user reads a French hint
  /// (`verify.hints-hardcoded-english#1`). Here the array is
  /// [listHabitsHintsOf], off the ambient [L10n], and it is rebuilt whenever
  /// that changes — the locale is a dependency of this widget, which is why
  /// the list cannot be built in `initState`.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `ListHabitsActivity.onPause` also runs when another *activity* covers
    // this one, which in a one-activity Flutter app is another route pushed
    // over this screen. [screenRouteObserver] is where those two callbacks
    // come from (`audit5.the-habit-list-command-toast-listener#1`).
    subscribeToScreenRoutes(this, context);
    // `HintListFactory.create(resources.getStringArray(R.array.hints))`: the
    // factory closes over the application-scoped Preferences and takes only
    // the array.
    _hintList = core.HintListFactory(_model.scope.preferences)
        .create(listHabitsHintsOf(L10n.of(context)));
  }

  /// `ListHabitsActivity.onResume` / `onPause` for the transitions that are not
  /// a mount (`verify.list-not-refreshed-on-resume`).
  ///
  /// `onResume` re-runs `adapter.refresh()`, which recomputes the whole
  /// `HabitCardListCache` against the current `getToday()`, and
  /// `screen.onAttached()`, which puts the cache back on the command runner.
  /// Both are [HabitListModel.attach]. `onPause` is the mirror image, and it
  /// matters for the same reason it does upstream: a detached cache is one
  /// that cannot be left holding a half-finished refresh.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      // `midnightTimer.onPause(); screen.onDetached(); adapter.cancelRefresh()`
      // — the app-level half of `onPause` lives in main.dart, next to the
      // timer it pauses.
      //
      // `screen.onDetached()` is the toast listener: a command that finishes
      // while the app is in the background raises no snackbar, because the
      // screen that would show it is not in the foreground
      // (`audit5.the-habit-list-command-toast-listener#1`).
      //
      // `dismissCurrentDialog()` is the last statement of `onPause`: an entry
      // popup, the colour picker or the delete confirmation left open when the
      // user presses Home is torn down there and then, so returning to the app
      // shows a plain habit list. Tearing an entry popup down is also what
      // runs `CheckmarkDialog.onDismiss` / `NumberDialog.onDismiss`, which
      // commits notes typed but never saved
      // (`audit6.an-open-entry-popup-or-colour#1`,
      // `list-habits.startup-lifecycle#4`).
      //
      // Only when this screen is the one being paused, though. The statement
      // belongs to `ListHabitsActivity.onPause`, which cannot run while
      // `EditHabitActivity` is on top — that activity is already stopped — and
      // the editor dismisses nothing of its own, so its colour picker,
      // frequency picker, target-type list, radial time picker and weekday
      // picker all survive a Home press, an incoming call or a
      // notification-shade pull-down
      // (`audit7.backgrounding-the-app-or-just-pulling#1`).
      if (!_isCovered) dismissCurrentDialog();
      _toasts.onDetached();
      _model.detach();
      return;
    }
    // `DateUtils.getToday()` is a clock read on every call upstream, so the
    // refresh below sees the real day even when the process spent it in the
    // background. The port stamps the day into a process-global instead, and
    // its only writer — the midnight timer — was paused for exactly that
    // interval and, on resume, schedules the *next* boundary rather than
    // firing for one already crossed. Re-stamping here is what makes the
    // refresh recompute today rather than yesterday.
    core.setToday(
      core.computeToday(_model.scope.preferences.midnightDelayHours, 0),
    );
    _model.attach();
    // `screen.onAttached()`, the other half of the pair above — and, like the
    // dismissal, only when this screen is the one resuming. A background round
    // trip taken from the editor or the detail screen runs *that* activity's
    // `onResume`; nothing re-registers the list until the list activity itself
    // comes back, which is [didPopNext] here. Re-registering from under the
    // pushed route would put the list's toast over the screen the user is
    // actually looking at (`audit7.after-a-background-round-trip-the#1`,
    // `commands.listener-list-habits-toasts#1`, `#6`).
    if (!_isCovered) _toasts.onAttached();
  }

  // -----------------------------------------------------------------------
  // RouteAware: `onPause` / `onResume` for a screen pushed over this one
  // -----------------------------------------------------------------------

  /// `ListHabitsActivity.onPause` when `ShowHabitActivity`, `EditHabitActivity`
  /// or `SettingsActivity` is started: `screen.onDetached()` unregisters the
  /// command listener, so a command run from the screen on top produces no
  /// list toast — the detail screen shows its own message instead
  /// (`commands.listener-list-habits-toasts#1`, `#6`).
  ///
  /// The adapter is deliberately left attached: the cache under it belongs to
  /// the application, not to this screen, and the widgets, the notification
  /// tray and the screen on top all read it while this one is covered.
  ///
  /// It is also the moment the list stops hearing its own lifecycle: from here
  /// until [didPopNext] this widget stands in for a *stopped* activity, whose
  /// `onPause` and `onResume` the system no longer calls
  /// (`audit7.backgrounding-the-app-or-just-pulling#1`).
  @override
  void didPushNext() {
    _isCovered = true;
    _toasts.onDetached();
  }

  /// `ListHabitsActivity.onResume` when that screen is finished: the toast
  /// listener is registered again, so the first command run back on the list
  /// shows its snackbar.
  ///
  /// This is the *only* thing that re-registers it after a screen was pushed
  /// over the list, background round trip or no background round trip
  /// (`audit7.after-a-background-round-trip-the#1`).
  ///
  /// It is also the *only* moment the home-screen widgets hear about anything
  /// the covering screen wrote — see [_republishWidgets].
  @override
  void didPopNext() {
    _isCovered = false;
    _toasts.onAttached();
    _republishWidgets();
  }

  /// `appComponent.widgetUpdater.updateWidgets()`, the second statement of the
  /// task-runner block `ListHabitsActivity.onResume` ends with:
  ///
  /// ```kotlin
  /// taskRunner.run {
  ///     AutoBackup(this@ListHabitsActivity).run()
  ///     appComponent.widgetUpdater.updateWidgets()
  /// }
  /// ```
  ///
  /// Upstream `SettingsActivity`, `EditHabitActivity` and `ShowHabitActivity`
  /// are all separate activities, so finishing any of them resumes the list
  /// activity and runs that block. It is what carries a preference the
  /// settings screen wrote across the process boundary to the launcher:
  /// `SettingsFragment.onSharedPreferenceChanged` special-cases
  /// `pref_widget_opacity` and no other key (`settings.preferences
  /// .widget-opacity#4`), so `pref_first_weekday` — which
  /// `HistoryChartView.firstWeekday` and `FrequencyChartView.firstWeekday`
  /// render their grids from — reaches the widgets here or nowhere
  /// (`audit9.settings-return-does-not-republish-widgets#1`).
  ///
  /// A Flutter app has one activity for the whole process and Settings is a
  /// route pushed over this screen, so popping it fires no
  /// `AppLifecycleState` change and the copy of this block in `main.dart` —
  /// which is bound to a real background/foreground round trip — never runs.
  /// [didPopNext] is the port's "the list activity is resuming", which is why
  /// the republish lives here rather than in `_openSettings`: upstream the
  /// block is not conditional on *which* activity was on top.
  ///
  /// The `AutoBackup` half stays with the app-level resume. It rotates one
  /// copy of the database per day and refuses to write a second, so a route
  /// pop cannot make one due; the republish is the half that has an observer
  /// in another process waiting for it.
  ///
  /// `widgetSync` is null on a host with no home-screen widgets — and in every
  /// widget test — which is upstream's `widgetUpdater != null`.
  void _republishWidgets() {
    final Future<void>? republished = _model.scope.widgetSync?.updateWidgets();
    if (republished != null) unawaited(republished);
  }

  /// The route this screen sits on was itself pushed or popped; the mount and
  /// the unmount already cover both, exactly as `onCreate` / `onDestroy` do.
  @override
  void didPush() {}

  @override
  void didPop() {}

  /// `ListHabitsActivity.onNewIntent` -> `setIntent(intent)`, followed by the
  /// `parseIntents()` its next `onResume` would have run.
  ///
  /// Both halves are the model's already (`list-habits.startup-lifecycle#8`);
  /// this only delivers.
  void _onDeepLinkIntent(intents.Intent intent) {
    _model
      ..pendingIntent = intent
      ..parseIntents();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    screenRouteObserver.unsubscribe(this);
    _dataOffsetState.dispose();
    // `ListHabitsActivity.onPause` -> `screen.onDetached()`.
    _toasts.onDetached();
    _model
      ..onShowHabitScreen = null
      ..onShowIntroScreen = null
      ..onShowNumberPopup = null
      ..onShowCheckmarkPopup = null
      ..onShowConfetti = null
      ..nightModeGetter = null
      ..nightModeToggle = null
      ..onApplyTheme = null
      ..onShowAboutScreen = null
      ..onShowFAQScreen = null
      ..onShowSettingsScreen = null
      ..onShowSelectHabitTypeDialog = null
      ..onSelectionStarted = null
      ..onSelectionChanged = null
      ..onSelectionFinished = null
      ..onShowColorPicker = null
      ..onShowDeleteConfirmationScreen = null
      ..onShowEditHabitsScreen = null;
    widget.widgetLinks?.detachListScreen(_onDeepLinkIntent);
    _listScrollController.dispose();
    super.dispose();
  }

  /// `ListHabitsScreen.showIntroScreen()`:
  ///
  /// ```kotlin
  /// override fun showIntroScreen() {
  ///     val intent = intentFactory.startIntroActivity(activity)
  ///     activity.startActivity(intent)
  /// }
  /// ```
  ///
  /// `IntroActivity` is a separate activity started on top of the list, so the
  /// port pushes a route on top of this one rather than replacing it.
  ///
  /// The push waits for the end of the frame because `onStartup()` runs from
  /// [initState], where this screen's route is still being built and there is
  /// no navigator to push onto yet. `startActivity` waits for the same thing:
  /// the activity it is called from has not finished `onCreate`, and the
  /// transaction it queues is only carried out once it has.
  ///
  /// The navigator is looked up here rather than inside the callback: by the
  /// time a post-frame callback runs, this element may have been taken out of
  /// the tree, and an ancestor lookup from a deactivated element throws. The
  /// same reason `startActivity` on a finishing activity is dropped rather than
  /// crashing, so a navigator that is gone by then simply shows nothing.
  void _showIntroScreen() {
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !navigator.mounted) return;
      navigator.push<void>(
        MaterialPageRoute<void>(builder: (_) => const IntroScreen()),
      );
    });
  }

  ThemeModel? _readThemeModel() {
    try {
      return Provider.of<ThemeModel>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// `startSupportActionMode` / `invalidate` / `finish`: all three come down
  /// to redrawing the toolbar from the current selection.
  void _refreshSelectionBar() {
    if (mounted) setState(() {});
  }

  /// `ListHabitsSelectionMenuBehavior.Screen.showColorPicker`, which
  /// `ListHabitsScreen` shows with
  /// `picker.dismissCurrentAndShow(activity.supportFragmentManager, "picker")`.
  Future<void> _showColorPicker(
    core.PaletteColor defaultColor,
    core.OnColorPickedCallback callback,
  ) async {
    final picked = await dismissCurrentAndShow<core.PaletteColor>(
      context,
      () => showColorPickerDialog(context, selected: defaultColor),
    );
    // A dismissal runs no command (`list-habits.selection-menu-actions#15`),
    // and `onPause` is one of the ways it can be dismissed
    // (`audit6.an-open-entry-popup-or-colour#1`).
    if (picked == null) return;
    callback(picked);
  }

  /// `ListHabitsSelectionMenuBehavior.Screen.showDeleteConfirmationScreen`,
  /// shown with `dialog.dismissCurrentAndShow()`.
  Future<void> _showDeleteConfirmation(
    core.OnConfirmedCallback callback,
    int quantity,
  ) async {
    final confirmed = await dismissCurrentAndShow<bool>(
          context,
          () => showConfirmDeleteDialog(context, quantity: quantity),
        ) ??
        false;
    if (!confirmed) return;
    callback();
  }

  /// `ListHabitsSelectionMenuBehavior.Screen.showEditHabitsScreen`, which
  /// upstream edits the first selected habit.
  Future<void> _showEditHabitsScreen(List<core.Habit> selected) {
    if (selected.isEmpty) return Future<void>.value();
    return EditHabitScreen.open(context, selected.first);
  }

  /// `ListHabitsScreen.showConfetti(color, x, y)`.
  ///
  /// The guards and the party are [buildConfettiParty]; all that is left here
  /// is handing the burst to the KonfettiView.
  void _showConfetti(core.PaletteColor color, double x, double y) {
    final theme = _coreThemeOf(context);
    final party = buildConfettiParty(
      baseColor: theme.colorOf(color),
      position: Offset(x, y),
      preferences: _model.scope.preferences,
      animatorDurationScale: _animatorDurationScale,
    );
    if (party == null) return;
    _confettiKey.currentState?.start(party);
  }

  /// `HabitCardView.getAbsoluteButtonLocation(date)`, resolved into the
  /// konfetti view's own coordinates: the root already carried the left window
  /// inset away as padding, so this is the window position less that inset
  /// (`list-habits.confetti#5`).
  Offset _confettiOrigin() {
    final press = _lastEntryPress;
    final overlay = _confettiKey.currentContext?.findRenderObject();
    if (press == null || overlay is! RenderBox) return Offset.zero;
    return overlay.globalToLocal(press);
  }

  /// Port of `ListHabitsRootView.getCheckmarkCount()`. The label column takes a
  /// third of the width but never less than `R.dimen.habitNameWidth`; whatever
  /// is left is divided into 48dp buttons and clamped to 0..60.
  static int _checkmarkCount(double width) {
    const double nameWidth = 160.0;
    const double buttonWidth = 48.0;
    final labelWidth = math.max(width / 3.0, nameWidth);
    final buttonCount = ((width - labelWidth) / buttonWidth).truncate();
    return math.min(
      ListHeader.maxCheckmarkCount,
      math.max(0, buttonCount),
    );
  }

  /// `AndroidThemeSwitcher.currentTheme()`, which `ListHabitsRootView` and
  /// `HabitCardView.copyAttributesFrom` both read.
  ///
  /// It has to come from the shared [coreThemeOf] rather than from
  /// [Brightness]: `DarkTheme` and `PureBlackTheme` are both dark, so deriving
  /// the theme from the brightness alone can never return the pure-black one
  /// and the whole list body stays grey under a black toolbar.
  core.Theme _coreThemeOf(BuildContext context) => coreThemeOf(context);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final model = context.watch<HabitListModel>();
    final theme = _coreThemeOf(context);
    // `rootView.setupToolbar(..., color = PaletteColor(17))`: the list screen
    // is the one toolbar that is not tinted by a habit's colour.
    // `setupToolbar`: the habit palette colour, unless the theme says
    // otherwise — the dark themes paint the toolbar with colorPrimary instead
    // (list-habits.screen-layout#2).
    final toolbarColor = _toFlutterColor(
      theme.toolbarColorFor(theme.colorOf(const core.PaletteColor(17))),
    );

    // `rootView.applyRootViewInsets()`: the left and right window insets become
    // padding on the root, and the root paints itself black behind them
    // (`list-habits.screen-layout#7`). The top inset stays with the toolbar,
    // which Scaffold gives its AppBar for free, and the bottom one is consumed
    // by the card list (`#8`).
    final padding = MediaQuery.paddingOf(context);
    // The contextual action bar is an Android `ActionMode`, and the system
    // Back key destroys an active ActionMode before the activity ever sees
    // the press: `ListHabitsSelectionMenu.onDestroyActionMode` ->
    // `listController.onSelectionFinished()` -> `cancelSelection()`
    // (`list-habits.selection-mode#6`, "e.g. system back";
    // `audit3.the-android-system-back-button-does#1`). So while a selection is
    // live, Back cancels it and the user stays on the list.
    //
    // With nothing selected there is no ActionMode to swallow the press, and
    // `ListHabitsActivity` is the root activity — Back finishes it, which is
    // what letting the pop bubble out of the root route does.
    return PopScope<Object?>(
      canPop: model.isSelectionEmpty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || model.isSelectionEmpty) return;
        // The very same call the action bar's close button makes; it clears
        // the selection, resets the controller to NormalMode and asks the
        // screen to put the normal toolbar back.
        model.listController.onSelectionFinished();
      },
      child: ColoredBox(
        color: Colors.black,
        child: Padding(
          padding: EdgeInsets.only(left: padding.left, right: padding.right),
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            removeRight: true,
            child: Stack(
              children: <Widget>[
                _buildScaffold(context, l10n, model, theme, toolbarColor,
                    bottomInset: padding.bottom),
                // `addAtTop(konfettiView)` with `translationZ = 10f`: the
                // burst covers the whole root, toolbar included, and its
                // origin is the window position of the tapped button less the
                // left inset the root padding above already took out
                // (`list-habits.screen-layout#1`, `list-habits.confetti#5`).
                Positioned.fill(child: ConfettiOverlay(key: _confettiKey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    L10n l10n,
    HabitListModel model,
    core.Theme theme,
    Color toolbarColor, {
    required double bottomInset,
  }) {
    return Scaffold(
      backgroundColor: _toFlutterColor(theme.appBackgroundColor),
      // `res/menu/list_habits.xml`, inflated by `ListHabitsMenu.onCreate` —
      // or the contextual action bar, while a selection is active.
      appBar: model.isSelectionEmpty
          ? ListHabitsMenu(
              key: _menuKey,
              model: model,
              title: l10n.mainActivityTitle,
              backgroundColor: toolbarColor,
            )
          : ListHabitsSelectionMenu(
              model: model,
              backgroundColor: toolbarColor,
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final buttonCount = _checkmarkCount(constraints.maxWidth);
          final maxDataOffset =
              math.max(ListHeader.maxCheckmarkCount - buttonCount, 0);
          final dataOffset = _dataOffset.clamp(0, maxDataOffset);
          // `onSizeChanged` pushes the column count into the header and the
          // list; notifying from inside build is not allowed, so it lands
          // after the frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) model.buttonCount = buttonCount;
          });

          // `ListHabitsRootView.init`, in the order the RelativeLayout stacks
          // its children (`list-habits.screen-layout#1`): the konfetti view at
          // translationZ 10 above everything, the toolbar (Scaffold's AppBar,
          // just above), the header below it, the card list and the empty view
          // sharing the area below the header, the progress bar overlapping the
          // header's bottom edge by 6dp, and the hint pinned to the bottom.
          return Stack(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ListHeader(
                    restorationId: 'header',
                    buttonCount: buttonCount,
                    dataOffset: dataOffset,
                    // `HeaderView(context, prefs, midnightTimer)`: the strip
                    // subscribes to the preferences itself, exactly as the
                    // panel of buttons under it does, so both halves of the
                    // row flip on the same notification
                    // (`audit3.flipping-reverse-order-of-days-leaves#1`).
                    preferences: model.scope.preferences,
                    onDataOffsetChanged: (value) =>
                        setState(() => _dataOffset = value),
                    theme: theme,
                  ),
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        _buildList(
                          context,
                          model: model,
                          theme: theme,
                          buttonCount: buttonCount,
                          dataOffset: dataOffset,
                          bottomInset: bottomInset,
                        ),
                        // `addBelow(llEmpty, header, height = MATCH_PARENT)`.
                        _buildEmptyView(context, model: model, theme: theme),
                      ],
                    ),
                  ),
                ],
              ),
              // `addBelow(progressBar, header) { it.topMargin = dp(-6f) }`.
              Positioned(
                left: 0,
                right: 0,
                top: theme.checkmarkButtonSize - 6,
                child: TaskProgressBar(
                  runner: model.scope.taskRunner,
                  color: toolbarColor,
                ),
              ),
              // `addAtBottom(hintView)`.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: HintView(
                  key: _hintKey,
                  // Non-null from `didChangeDependencies` onwards, which runs
                  // before the first build.
                  hintList: _hintList!,
                  title: l10n.hintTitle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// `ListHabitsRootView.updateEmptyView()`.
  ///
  /// The three-way choice is recomputed on every build, where Android runs it
  /// only from `onModelChange()`. The two agree because nothing but the
  /// adapter's observable can change `itemCount` — except before the first
  /// notification, which is why both flags are latched on the model
  /// (`audit12.the-habit-list-flashes-the-empty-state#1`); until then this
  /// falls through to [EmptyListMode.hidden], the `visibility = View.GONE` an
  /// `EmptyListView` is constructed with.
  Widget _buildEmptyView(
    BuildContext context, {
    required HabitListModel model,
    required core.Theme theme,
  }) {
    final l10n = L10n.of(context);
    return EmptyListView(
      theme: theme,
      mode: model.showEmptyState
          ? EmptyListMode.empty
          : model.showDoneState
              ? EmptyListMode.done
              : EmptyListMode.hidden,
      emptyText: l10n.noHabitsFound,
      doneText: l10n.noHabitsLeftToDo,
    );
  }

  Widget _buildList(
    BuildContext context, {
    required HabitListModel model,
    required core.Theme theme,
    required int buttonCount,
    required int dataOffset,
    required double bottomInset,
  }) {
    // The Android list has no top padding, and its bottom padding is exactly
    // the systemBars inset: `applyBottomInset()` adds one ItemDecoration that
    // gives the LAST item `outRect.bottom = systemBarsInsets.bottom` and
    // nothing more (`list-habits.screen-layout#8`). Scrolling to the end puts
    // the last habit row flush against the navigation bar. The 88 that used to
    // be added here was clearance for a floating action button neither app has
    // (`audit4.habit-list-keeps-88dp-of-dead#1`).
    final padding = EdgeInsets.only(top: 0, bottom: bottomInset);
    Widget buildRow(
      BuildContext context,
      int index, {
      bool ownLongPress = true,
    }) =>
        _buildCard(
          model: model,
          theme: theme,
          index: index,
          buttonCount: buttonCount,
          dataOffset: dataOffset,
          ownLongPress: ownLongPress,
        );

    // `HabitCardListView.attachedToItemTouchHelper`: the helper is only wired
    // up while the adapter is sortable, i.e. while the primary order is
    // BY_POSITION (`list-habits.drag-reorder#1`).
    if (!model.isSortable) {
      return _withScrollbar(
        ListView.builder(
          key: HabitListScreen.habitCardListKey,
          controller: _listScrollController,
          padding: padding,
          itemCount: model.itemCount,
          itemBuilder: buildRow,
        ),
      );
    }
    return _withScrollbar(ReorderableListView.builder(
      key: HabitListScreen.habitCardListKey,
      scrollController: _listScrollController,
      padding: padding,
      itemCount: model.itemCount,
      // `isLongPressDragEnabled() == false`: the helper never starts a drag by
      // itself, the row does (`list-habits.drag-reorder#3`).
      buildDefaultDragHandles: false,
      // `getMovementFlags` allows UP or DOWN only; swipe is declared but
      // `isItemViewSwipeEnabled()` is false, so `onSwiped` never runs
      // (`list-habits.drag-reorder#3`, `#9`).
      onReorderStart: model.listController.startDrag,
      onReorder: (from, to) {
        // ReorderableListView reports the index the row lands at *after* it
        // has been lifted out, which is one further along than the adapter
        // position `onMove` hands the controller.
        model.listController.drop(from, to > from ? to - 1 : to);
      },
      // `HabitCardListView.onItemLongClick`: the long press goes to the touch
      // helper, whose `startDrag` runs the very same selection path
      // (`NormalMode.startDrag` -> `startSelection`), so the row does not need
      // a long-press handler of its own (`list-habits.drag-reorder#2`).
      itemBuilder: (context, index) => ReorderableDelayedDragStartListener(
        key: ValueKey<int>(model.cardAt(index)?.habit.id ?? index),
        index: index,
        child: buildRow(context, index, ownLongPress: false),
      ),
    ));
  }

  /// `HabitCardListView(context, null, R.attr.scrollableRecyclerViewStyle)`.
  ///
  /// The style that constructor names declares exactly one thing —
  /// `<item name="android:scrollbars">vertical</item>` — so the habit list is
  /// the app's one deliberate scrollbar and every other scrolling view,
  /// including this screen's own horizontal header, keeps none
  /// (`audit.the-habit-list-has-no-vertical#1`). Left at its defaults the
  /// [Scrollbar] is the platform's fading thumb, which is what
  /// `android:scrollbars` turns on: visible while the list moves, gone after.
  Widget _withScrollbar(Widget list) =>
      Scrollbar(controller: _listScrollController, child: list);

  Widget _buildCard({
    required HabitListModel model,
    required core.Theme theme,
    required int index,
    required int buttonCount,
    required int dataOffset,
    bool ownLongPress = true,
  }) {
    final data = model.cardAt(index);
    // `onBindViewHolder` returns early while no view is attached.
    if (data == null) return const SizedBox.shrink();
    final habit = data.habit;
    return HabitCard(
      key: ValueKey<int>(habit.id ?? index),
      habit: habit,
      score: data.score,
      values: data.checkmarks,
      notes: data.notes,
      theme: theme,
      preferences: model.scope.preferences,
      buttonCount: buttonCount,
      dataOffset: dataOffset,
      isSelected: data.selected,
      // `HabitCardView` passes `getAbsoluteButtonLocation(date)` into both
      // presenter calls; that is what places the confetti burst.
      onEntryPressed: (_, globalCenter) => _lastEntryPress = globalCenter,
      onToggle: (date, value, notes) {
        final origin = _confettiOrigin();
        model.onToggle(habit, date, value, notes, origin.dx, origin.dy);
      },
      onEdit: (date) {
        final origin = _confettiOrigin();
        model.onEdit(habit, date, origin.dx, origin.dy);
      },
      // `HabitCardListController.onItemClick` / `onItemLongClick`: the mode
      // decides whether a tap opens the habit or toggles its selection.
      onTap: () => model.listController.onItemClick(index),
      onLongPress:
          ownLongPress ? () => model.listController.onItemLongClick(index) : null,
    );
  }

  // -----------------------------------------------------------------------
  // Dialogs
  // -----------------------------------------------------------------------

  /// `ListHabitsMenuBehavior.onCreateHabit()` asks the screen for the habit
  /// type chooser, and each of its two cards starts `EditHabitActivity` with
  /// the type it stands for (`habit-type-dialog.select-type#1`, `#6`).
  Future<void> _createHabit() => EditHabitScreen.selectTypeAndOpen(context);

  /// `res/menu/list_habits.xml` -> `SettingsActivity`, started with
  /// `startActivityForResult(intent, REQUEST_SETTINGS)`.
  ///
  /// The settings screen does none of the work its database and troubleshooting
  /// rows stand for: each one calls `setResult(code); finish()`
  /// (`SettingsFragment.setResultOnPreferenceClick`) and the list activity acts
  /// on the code in `onActivityResult`. The Flutter screen pops with a
  /// [SettingsResult] instead, so awaiting the route is `onActivityResult`, and
  /// [DataActions.onSettingsResult] is `ListHabitsScreen.onSettingsResult`'s
  /// `when (resultCode)`.
  ///
  /// A screen dismissed with the back button answers null — `RESULT_CANCELED`,
  /// which `when` has no arm for — and nothing runs.
  Future<void> _openSettings() async {
    final scope = context.read<AppScope>();
    final result = await Navigator.of(context).push<SettingsResult>(
      MaterialPageRoute<SettingsResult>(
        builder: (_) => Provider<AppScope>.value(
          value: scope,
          child: SettingsScreen(
            storage: scope.preferencesStorage,
            onOpenUrl: _openUrl,
            onShowAbout: () => _openAbout(),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    final actions = await _dataActions(scope);
    if (actions == null) return;
    await actions.onSettingsResult(result);
  }

  /// The collaborators `ListHabitsScreen` is `@Inject`ed with to do the work
  /// behind those result codes — the export tasks, the importer, the bug
  /// reporter, the file picker and the share sheet.
  ///
  /// Built when a result actually arrives rather than at startup, because
  /// resolving the app directories is a platform call. A host that cannot
  /// answer it has no `getExternalFilesDirs` either, so there is nowhere to
  /// export to; the actions are simply unavailable, rather than taking the
  /// screen down with them.
  Future<DataActions?> _dataActions(AppScope scope) async {
    final AppDirectories directories;
    try {
      directories = await AppDirectories.resolve();
    } on Object catch (error, stackTrace) {
      scope.logging.getLogger('ListHabitsScreen').error(error, stackTrace);
      return null;
    }
    if (!mounted) return null;
    return DataActions.create(
      scope: scope,
      directories: directories,
      // `activity.showMessage(...)`: the snackbar belongs to the list screen,
      // which is what the settings screen has just closed back onto.
      showMessage: (message) {
        if (mounted) showDataActionMessage(context, message);
      },
    );
  }

  /// `ListHabitsScreen.showFAQScreen()`:
  /// `activity.showSendEmailScreen`'s sibling, `startActivitySafely(
  /// Intent(ACTION_VIEW, Uri.parse(getString(R.string.helpURL))))`.
  void _openFAQ() => _openUrl(SettingsScreen.helpUrl);

  /// `Activity.startActivitySafely(Intent(ACTION_VIEW, Uri.parse(url)))`.
  ///
  /// [HabitListScreen.onOpenUrl] replaces it when the caller supplies one;
  /// otherwise the link goes to the system.
  void _openUrl(String url) {
    final override = widget.onOpenUrl;
    if (override != null) {
      override(url);
      return;
    }
    // `startActivity` is fire and forget; nothing waits for the other app.
    unawaited(_openLink(Uri.parse(url)));
  }

  /// `startActivitySafely`'s `catch (e: ActivityNotFoundException)`: a link
  /// nothing can open raises "No app was found to support this action".
  ///
  /// Handed to the About screen as `onOpenLink`, which reports the same
  /// failure itself, so this only reports for the callers that cannot —
  /// the FAQ menu item and the settings screen's two link rows.
  Future<bool> _openLink(Uri uri) async {
    final handled = await openExternalUri(uri);
    if (!handled && mounted) {
      showListHabitsMessage(context, L10n.of(context).activityNotFound);
    }
    return handled;
  }

  /// `res/menu/list_habits.xml` -> `AboutActivity`.
  Future<void> _openAbout() {
    final scope = context.read<AppScope>();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Provider<AppScope>.value(
          value: scope,
          child: AboutScreen(
            preferences: scope.preferences,
            // `AboutScreen`'s six rows are each
            // `activity.startActivitySafely(intents.<link>(activity))`; the
            // screen shows the "no app found" message on a false answer, so it
            // is handed the opener bare.
            onOpenLink: openExternalUri,
          ),
        ),
      ),
    );
  }

  /// `ListHabitsScreen.showNumberPopup(value, notes, callback)`.
  ///
  /// The real `NumberDialog` port, not a stand-in: the value field, the Skip
  /// and question-mark shortcuts, the notes field and the dismissal rules all
  /// come from `ui/common/dialogs/number_dialog.dart`
  /// (`list-habits.entry-edit-popup-numeric#2` .. `#10`). A dismissal that did
  /// not touch the notes completes with null, which is the presenter's
  /// `onNumberPickerDismissed` — the no-op that runs no command.
  Future<void> _showNumberPopup(
    double value,
    String notes,
    NumberPickerCallback callback,
  ) async {
    final theme = _coreThemeOf(context);
    // `dialog.dismissCurrentAndShow(supportFragmentManager, "numberDialog")`:
    // the popup is the screen's current dialog, so `onPause` tears it down and
    // the notes typed into it are committed by that teardown
    // (`audit6.an-open-entry-popup-or-colour#1`).
    final result = await dismissCurrentAndShow<NumberDialogResult>(
      context,
      () => showNumberDialog(
        context,
        value: value,
        notes: notes,
        // NumberDialog tints only the buttons of the boolean row, which stays
        // hidden here; the colour is passed because the Android arguments
        // carry it (`number-dialog.popup#1`).
        color: theme.colorOf(const core.PaletteColor(0)),
        preferences: _model.scope.preferences,
      ),
    );
    if (result == null) {
      callback.onNumberPickerDismissed();
      return;
    }
    callback.onNumberPicked(result.value, result.notes);
  }

  /// `ListHabitsScreen.showCheckmarkPopup(value, notes, color, callback)`.
  ///
  /// The real `CheckmarkDialog` port: four glyph buttons over a notes field,
  /// with Skip and Unknown gated on the preferences
  /// (`list-habits.entry-edit-popup-boolean#2` .. `#7`).
  Future<void> _showCheckmarkPopup(
    int selectedValue,
    String notes,
    core.PaletteColor color,
    CheckMarkDialogCallback callback,
  ) async {
    final theme = _coreThemeOf(context);
    // `dialog.dismissCurrentAndShow(supportFragmentManager, "checkmarkDialog")`
    // — see [_showNumberPopup] (`audit6.an-open-entry-popup-or-colour#1`).
    final result = await dismissCurrentAndShow<CheckmarkDialogResult>(
      context,
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
}

/// Same rounding as `FlutterCanvas.setColor` and `core.Color.toInt`.
Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
