/// The Dart end of the deep links a home-screen widget sends.
///
/// ## What this replaces
///
/// Upstream, a widget tap is an Android `PendingIntent` that lands somewhere
/// inside the same process: `WidgetReceiver` for a toggle, `ListHabitsActivity`
/// for the numeric value picker, `ShowHabitActivity` for the five graph
/// widgets, `HabitPickerDialog` for configuration. None of those can reach Dart
/// from the launcher's process, so `app/android/.../widgets/WidgetIntents.kt`
/// funnels all four into one deep link into `MainActivity`:
///
/// ```
/// uhabits://widget/toggle?habit=<id>&widgetId=<n>
/// uhabits://widget/edit?habit=<id>&widgetId=<n>&date=<yyyy-MM-dd>
/// uhabits://widget/show?habit=<id>&widgetId=<n>
/// uhabits://widget/configure?widgetId=<n>&filter=<all|boolean|numerical>
/// ```
///
/// The `home_widget` plugin delivers those URIs to Dart, and [WidgetLinkRouter]
/// is what receives them.
///
/// ## What it routes today
///
/// Only `configure`, and deliberately: it is the one action with nowhere else
/// to go. A widget the user has just placed has no habit bound to it, the
/// native `HabitPickerDialog` has no habit catalogue to offer, and until
/// something answers this link the widget can never leave its "open Loop Habit
/// Tracker to set up this widget" state. See
/// `app/lib/ui/common/dialogs/widget_picker_dialog.dart`.
///
/// `toggle`, `edit` and `show` are parsed and then dropped. Routing them means
/// reaching into the habit list screen — `ListHabitsBehavior.onToggle`,
/// `onEdit` and the detail route — which is a different slice of the port;
/// `widgets.checkmark#6` and `#8` stay unmet until it lands, exactly as they
/// were before this file existed.
library;

import 'dart:async';

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../platform/home_widget_bridge.dart';
import '../ui/common/dialogs/widget_picker_dialog.dart';

/// One parsed `uhabits://widget/...` link.
@immutable
class WidgetLink {
  const WidgetLink({
    required this.action,
    required this.widgetId,
    this.habitId,
    this.date,
    this.filter,
  });

  /// `WidgetIntents.SCHEME`.
  static const String scheme = 'uhabits';

  /// `WidgetIntents.AUTHORITY`.
  static const String authority = 'widget';

  /// `WidgetIntents.ACTION_TOGGLE`.
  static const String actionToggle = 'toggle';

  /// `WidgetIntents.ACTION_EDIT`.
  static const String actionEdit = 'edit';

  /// `WidgetIntents.ACTION_SHOW`.
  static const String actionShow = 'show';

  /// `WidgetIntents.ACTION_CONFIGURE`.
  static const String actionConfigure = 'configure';

  final String action;

  /// `AppWidgetManager.EXTRA_APPWIDGET_ID`. `widgets.config-picker#1`: an
  /// intent that carries no id at all falls back to 0.
  final int widgetId;

  /// The `habit` query parameter — the habit id, not the row position. Absent
  /// on `configure`.
  final int? habitId;

  /// The `date` query parameter, an ISO-8601 calendar date. Only `edit` carries
  /// one, and it is the document's today, never a date the widget computed.
  final String? date;

  /// The `filter` query parameter. Only `configure` carries one.
  final WidgetPickerFilter? filter;

  /// Parses [uri], or returns null when it is not one of ours.
  ///
  /// Nothing is trusted: the URI arrives from another process, and a launcher
  /// that hands over a malformed one must not take the app down with it.
  static WidgetLink? parse(Uri? uri) {
    if (uri == null) return null;
    if (uri.scheme != scheme || uri.host != authority) return null;
    final List<String> segments = uri.pathSegments
        .where((String s) => s.isNotEmpty)
        .toList();
    if (segments.length != 1) return null;
    final Map<String, String> query = uri.queryParameters;
    return WidgetLink(
      action: segments.single,
      widgetId: int.tryParse(query['widgetId'] ?? '') ?? 0,
      habitId: int.tryParse(query['habit'] ?? ''),
      date: query['date'],
      filter: WidgetPickerFilter.fromName(query['filter']),
    );
  }
}

/// Where launch URIs come from.
///
/// A seam rather than a direct call to `HomeWidget`, for the reason
/// [HomeWidgetPlatform] is one: a plugin cannot run in a widget test, and a
/// host with no widget support at all is a normal condition.
abstract interface class WidgetLaunchSource {
  /// `HomeWidget.initiallyLaunchedFromHomeWidget()`: the URI that started the
  /// app, if a widget did.
  Future<Uri?> initialLaunchUri();

  /// `HomeWidget.widgetClicked`: the URIs that arrive while it is running.
  Stream<Uri?> get launchUris;
}

/// [WidgetLaunchSource] over the `home_widget` plugin.
class HomeWidgetLaunches implements WidgetLaunchSource {
  const HomeWidgetLaunches();

  @override
  Future<Uri?> initialLaunchUri() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } on MissingPluginException {
      // No widget host here, so nothing ever launched us.
      return null;
    }
  }

  @override
  Stream<Uri?> get launchUris {
    try {
      // A platform with no widget host closes or errors the channel; either
      // way the app must keep running.
      return HomeWidget.widgetClicked.handleError((Object _) {});
    } on MissingPluginException {
      return const Stream<Uri?>.empty();
    }
  }
}

/// Receives widget deep links and acts on them.
///
/// Port of the widget half of `ListHabitsActivity.parseIntents` plus the
/// Flutter half of `HabitPickerDialog`.
class WidgetLinkRouter {
  WidgetLinkRouter({
    required this.habitList,
    required this.registry,
    required this.publish,
    required this.navigator,
    required this.launches,
  });

  /// The catalogue the picker lists. The reason the picker is on this side of
  /// the process boundary at all.
  final Iterable<core.Habit> habitList;

  /// Where a confirmed choice is written: `widgetPreferences.addWidget`
  /// (`widgets.config-picker#10`).
  final WidgetRegistry registry;

  /// `widgetUpdater.updateWidgets()` — every widget, every provider
  /// (`widgets.config-picker#10`).
  final Future<void> Function() publish;

  /// The app's navigator, because a link arrives outside any build.
  final GlobalKey<NavigatorState> navigator;

  final WidgetLaunchSource launches;

  StreamSubscription<Uri?>? _subscription;

  /// The widget ids whose picker is on screen.
  ///
  /// `ListHabitsActivity.parseIntents` clears the intent once it has acted on
  /// it, so a resumed activity does not run it twice; here the same URI arrives
  /// twice for a different reason — the plugin reports the launch both through
  /// `initiallyLaunchedFromHomeWidget()` and on the click stream — and this is
  /// what makes the second delivery a no-op. Keyed by widget id rather than by
  /// URI so that a launcher which recycles an id can still configure it again
  /// later.
  final Set<int> _configuring = <int>{};

  /// Subscribes to the click stream and handles whatever launched the app.
  ///
  /// The returned future completes once the initial URI has been *read*, not
  /// once it has been acted on: acting on a `configure` link means showing a
  /// dialog and waiting for the user, which no caller wants to await.
  Future<void> start() async {
    _subscription ??= launches.launchUris.listen(handle);
    unawaited(handle(await launches.initialLaunchUri()));
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Acts on one link. Unknown actions and malformed URIs are ignored.
  Future<void> handle(Uri? uri) async {
    final WidgetLink? link = WidgetLink.parse(uri);
    if (link == null) return;
    if (link.action == WidgetLink.actionConfigure) await _configure(link);
    // toggle / edit / show: see the library comment.
  }

  /// The Flutter half of `HabitPickerDialog.onCreate` and `confirm()`.
  Future<void> _configure(WidgetLink link) async {
    if (_configuring.contains(link.widgetId)) return;
    final BuildContext? context = navigator.currentContext;
    if (context == null) return;

    _configuring.add(link.widgetId);
    try {
      final core.Habit? habit = await showWidgetPickerDialog(
        context,
        habits: habitList,
        filter: link.filter ?? WidgetPickerFilter.all,
      );
      // `widgets.config-picker#11`: backing out writes nothing, and the native
      // activity reads that as RESULT_CANCELED.
      if (habit == null) return;

      // `widgets.config-picker#10`, in order: bind the habit to the widget id,
      // then refresh every widget. Publishing is also what tells the native
      // activity the user confirmed — it looks for the document this writes.
      registry.addWidget(link.widgetId, <int>[habit.id!]);
      await publish();
    } finally {
      _configuring.remove(link.widgetId);
    }
  }
}
