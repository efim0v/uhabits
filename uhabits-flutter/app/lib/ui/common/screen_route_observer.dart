/// The port's stand-in for "another activity is on top of this one".
///
/// Upstream every screen is an Activity, so the framework runs `onPause` the
/// moment another activity covers it and `onResume` when it comes back:
/// `ListHabitsActivity.onPause` unregisters the command listener that shows the
/// list's toasts, and `ShowHabitActivity.onPause` dismisses the open dialog.
/// A Flutter app has one activity for the whole process, so the widget that
/// draws a covered screen stays mounted and hears nothing.
///
/// [screenRouteObserver] is the missing half. It is handed to the app's
/// `MaterialApp.navigatorObservers`, and a screen that needs the Android pair
/// implements `RouteAware`, subscribes to it with its own route and gets
/// `didPushNext()` where Android runs `onPause` and `didPopNext()` where it
/// runs `onResume`.
///
/// The type argument matters: `RouteObserver<R>` only notifies when the route
/// pushed on top is itself an `R`, and dialogs are `PopupRoute`s rather than
/// `PageRoute`s. So a dialog — which on Android is a window over a *running*
/// activity and never pauses it — leaves the screen underneath attached, while
/// a whole screen pushed over it does not.
library;

import 'package:flutter/widgets.dart';

/// The single observer the app installs. One instance for the process, like the
/// activity lifecycle it stands in for.
final RouteObserver<PageRoute<dynamic>> screenRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// Subscribes [subscriber] to [screenRouteObserver] for the route [context]
/// sits on, if that route is one the observer reports on.
///
/// Call it from `didChangeDependencies`, which is the first place a route can
/// be looked up and which runs again if the screen is moved to another one.
/// A screen built directly in a test — with no navigator, or under a
/// `MaterialApp` that does not install the observer — simply never gets the
/// callbacks, exactly as before.
void subscribeToScreenRoutes(RouteAware subscriber, BuildContext context) {
  final route = ModalRoute.of(context);
  if (route is! PageRoute<dynamic>) return;
  screenRouteObserver.subscribe(subscriber, route);
}
