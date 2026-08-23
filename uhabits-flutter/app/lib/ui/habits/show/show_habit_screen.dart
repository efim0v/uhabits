/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/{ShowHabitActivity,ShowHabitView}.kt
/// and res/layout/show_habit.xml.
///
/// The three Kotlin pieces collapse into one widget plus one [ShowHabitModel]:
///
///  * `ShowHabitActivity` is the lifecycle and the `Screen` implementation.
///    Its `onResume` / `onPause` pair is [ShowHabitModel.attach] /
///    [ShowHabitModel.detach], driven by the provider that owns the model, and
///    its `Screen.refresh()` is [ShowHabitModel.refresh];
///  * `ShowHabitView` is `setState`: it pushes one slice of the state into
///    each card and hides the two that do not apply to the habit's type. Both
///    halves are the core's — [ShowHabitPresenter.buildState] and
///    `ShowHabitCardVisibility` — so what is left here is the column;
///  * show_habit.xml is the column itself: a fixed toolbar over a scrolling
///    list of nine cards (`show-habit.screen-scaffold#12`).
///
/// Five of the nine cards — score, bar, history, streak and frequency — have
/// no state object in `uhabits_core` yet. They keep their place in
/// [ShowHabitCard] and are simply skipped here until their slices land, so
/// adding one is a single branch in [_ShowHabitViewState._buildCard].
///
/// Not ported here: the overflow menu (`ShowHabitMenu.kt`), whose presenter
/// already exists in the core as `ShowHabitMenuPresenter` but whose Edit item
/// needs an edit screen that does not.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../state/app_scope.dart';
import '../../../state/show_habit_model.dart';
import '../edit/edit_habit_screen.dart';
import 'cards/notes_card_view.dart';
import 'cards/overview_card_view.dart';
import 'cards/subtitle_card_view.dart';

/// The habit detail screen. Owns the [ShowHabitModel] for as long as it is
/// mounted.
class ShowHabitScreen extends StatelessWidget {
  const ShowHabitScreen({required this.habit, super.key});

  /// The habit `ShowHabitActivity` would have resolved from the intent's
  /// `content://org.isoron.uhabits/habit/<id>` URI. The Flutter list hands the
  /// model over directly instead — see [ShowHabitModel.habit].
  final core.Habit habit;

  /// The route `IntentFactory.startShowHabitActivity` builds.
  ///
  /// The scope has to be captured by the caller: `MaterialApp.home` provides
  /// it *below* the navigator, so a pushed route sits outside it.
  static Route<void> route({
    required AppScope scope,
    required core.Habit habit,
  }) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: habit.uriString),
      builder: (context) => Provider<AppScope>.value(
        value: scope,
        child: ShowHabitScreen(habit: habit),
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

  @override
  Widget build(BuildContext context) {
    // Read outside `create`: a provider's factory may not depend on an
    // inherited widget, and `Theme.of` is one.
    final theme = coreThemeOf(context);
    return ChangeNotifierProvider<ShowHabitModel>(
      create: (context) => ShowHabitModel(
        scope: context.read<AppScope>(),
        habit: habit,
        theme: theme,
      )..attach(),
      child: const _ShowHabitView(),
    );
  }
}

/// `AndroidThemeSwitcher.currentTheme`, as far as this port goes: the Flutter
/// brightness stands in for `pref_theme` plus the system dark mode, and
/// `PureBlackTheme` waits for the preferences slice
/// (`show-habit.screen-scaffold#11`).
core.Theme coreThemeOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? core.DarkTheme()
        : core.LightTheme();

class _ShowHabitView extends StatefulWidget {
  const _ShowHabitView();

  @override
  State<_ShowHabitView> createState() => _ShowHabitViewState();
}

class _ShowHabitViewState extends State<_ShowHabitView> {
  late final ShowHabitModel _model;

  @override
  void initState() {
    super.initState();
    _model = context.read<ShowHabitModel>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `AndroidThemeSwitcher.apply()` restarts the activity when the theme
    // changes; here the model rebuilds its state instead.
    _model.theme = coreThemeOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ShowHabitModel>();
    final state = model.state;
    final theme = state.theme;

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
        backgroundColor: _toFlutterColor(theme.colorOf(state.color)),
        // `@style/Toolbar` applies ThemeOverlay.AppCompat.Dark.ActionBar.
        foregroundColor: Colors.white,
        // `toolbar.elevation = dpToPixels(context, 2f)`
        elevation: 2,
        actions: <Widget>[
          // `ShowHabitMenu`'s Edit item — `ShowHabitMenuPresenter.onEditHabit`
          // asks the screen for the editor and changes nothing itself. The
          // rest of the overflow menu belongs to its own slice.
          IconButton(
            key: ShowHabitScreen.editActionKey,
            tooltip: L10n.of(context).edit,
            icon: const Icon(Icons.edit),
            onPressed: () => EditHabitScreen.open(context, model.habit),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          // `show-habit.card-order-and-visibility#1`: the column follows
          // ShowHabitCard's declaration order, and #2/#3/#4 decide which of
          // them survive.
          children: _buildCards(context, model),
        ),
      ),
    );
  }

  /// `ShowHabitView.setState` walking show_habit.xml top to bottom.
  List<Widget> _buildCards(BuildContext context, ShowHabitModel model) {
    final widgets = <Widget>[];
    for (final card in model.cards) {
      if (!model.isVisible(card)) continue;
      final widget = _buildCard(context, model: model, card: card);
      if (widget != null) widgets.add(widget);
    }
    return widgets;
  }

  /// Null for a card whose state object has not been ported yet.
  Widget? _buildCard(
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
          child: OverviewCardView(state: state.overview),
        );
      case ShowHabitCard.target:
      case ShowHabitCard.score:
      case ShowHabitCard.bar:
      case ShowHabitCard.history:
      case ShowHabitCard.streak:
      case ShowHabitCard.frequency:
        return null;
    }
  }
}

/// `@style/Card`, from res/values/styles.xml, on top of `@style/CardCommon`:
/// full width, 16dp/4dp horizontal padding, 16dp vertical padding, 3dp side
/// margins, a 1dp bottom margin, 1dp of elevation and the ?cardBgColor
/// background (`show-habit.card-order-and-visibility#5`).
class _Card extends StatelessWidget {
  const _Card({required this.theme, required this.child, super.key});

  final core.Theme theme;
  final Widget child;

  static const EdgeInsets padding = EdgeInsets.fromLTRB(16, 16, 4, 16);
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
      color: _toFlutterColor(theme.headerBackgroundColor),
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
