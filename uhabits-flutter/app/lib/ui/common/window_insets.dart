/// Edge-to-edge window insets.
///
/// Port of the three `OnApplyWindowInsetsListener`s in
/// `uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt`:
/// `applyRootViewInsets`, `applyBottomInset` and `applyToolbarInsets`.
///
/// ## Where the numbers come from
///
/// Kotlin asks the `WindowInsetsCompat` for two inset sets and takes the
/// larger edge of each:
///
/// ```kotlin
/// val systemBarsInsets = insets.getInsets(WindowInsetsCompat.Type.systemBars())
/// val displayCutoutInsets = insets.getInsets(WindowInsetsCompat.Type.displayCutout())
/// val left = maxOf(systemBarsInsets.left, displayCutoutInsets.left)
/// ```
///
/// Flutter has already taken that maximum: `MediaQueryData.viewPadding` is the
/// window's system-UI intrusion on every edge — status bar, navigation bar and
/// display cutout together — and it is reported whether or not the keyboard is
/// up. (`MediaQueryData.padding` is the same number with `viewInsets`
/// subtracted, which is the wrong one for [bottomInsetOf]: it is zero at the
/// bottom exactly when the keyboard is covering that edge.)
///
/// The keyboard is `MediaQueryData.viewInsets`, which is
/// `WindowInsetsCompat.Type.ime()`.
///
/// ## "Unconsumed"
///
/// All three Kotlin listeners return the insets they were handed rather than
/// `CONSUMED`, so a child view still sees the full window insets and can pad
/// itself too (`platform-glue.window-insets#4`). The widgets here have the same
/// property for the same reason, and get it by construction: they add
/// [Padding] and leave the ambient `MediaQuery` alone, so every descendant
/// still reads the same `viewPadding` and `viewInsets`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// `applyRootViewInsets`: the horizontal edges only.
///
/// `view.setPadding(left, 0, right, 0)` — the top and bottom are deliberately
/// zero, because the toolbar takes the top ([toolbarInsetOf]) and the
/// individual scrolling surfaces take the bottom ([bottomInsetOf]).
EdgeInsets rootViewInsetsOf(MediaQueryData media) => EdgeInsets.only(
      left: media.viewPadding.left,
      right: media.viewPadding.right,
    );

/// `applyBottomInset`: `maxOf(systemBarsInsets.bottom, imeInsets.bottom)`.
///
/// The max is what lifts a view above the on-screen keyboard while still
/// clearing the navigation bar when there is no keyboard.
double bottomInsetOf(MediaQueryData media) =>
    math.max(media.viewPadding.bottom, media.viewInsets.bottom);

/// `applyToolbarInsets`: `maxOf(systemBarsInsets.top, displayCutoutInsets.top)`.
///
/// Nothing in this port calls it directly — `AppBar`'s `primary: true` already
/// pads the toolbar's own `Material` by exactly this amount, which is what
/// makes the toolbar colour reach behind the status bar
/// (`platform-glue.window-insets#6`). It is here because it is the number that
/// has to agree with the framework's, and a test that says so is cheaper than
/// discovering the disagreement on a notched phone.
double toolbarInsetOf(MediaQueryData media) => media.viewPadding.top;

/// Port of `View.applyRootViewInsets()`.
///
/// Upstream this is installed on the root view of `ListHabitsActivity`,
/// `ShowHabitActivity`, `EditSettingActivity` and `AboutView` — every activity
/// that fills the window. A Flutter app has one such root, so this is applied
/// once, above the navigator, and covers all of them
/// (`platform-glue.window-insets#5`).
///
/// The black background is upstream's `ColorDrawable(Color.BLACK)` and is only
/// ever visible in the padded strips themselves: the screen's own background
/// paints over everything inside them. In landscape on a notched phone those
/// strips are the cutout and the navigation bar, and black is what makes them
/// read as part of the device rather than as a broken layout.
class RootViewInsets extends StatelessWidget {
  const RootViewInsets({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF000000),
      child: Padding(
        padding: rootViewInsetsOf(MediaQuery.of(context)),
        // The strips are now behind this widget, so nothing below it may pad
        // by them again. Upstream cannot double up: the listener is installed
        // once per activity, `SettingsFragment` adds only `applyBottomInset()`
        // to its list, and `EditHabitActivity`'s second call replaces the
        // first on the same view — one listener slot per view. Here a screen
        // that wraps its body in a bare `SafeArea` would read the same
        // untouched padding and indent its content twice as far as its own
        // toolbar (`audit23.the-root-inset-must-be-consumed-once#1`).
        //
        // Only the horizontal edges are consumed: the top belongs to the
        // toolbar and the bottom to `BottomInset`, which is the port of
        // `applyBottomInset()` and is applied per screen
        // (`platform-glue.window-insets#5`).
        //
        // `MediaQuery.removePadding` is the wrong tool: it also subtracts from
        // `viewPadding`, and that is the field carrying the Android meaning —
        // the raw intrusion, whatever anyone has consumed, which `BottomInset`
        // and the toolbar still compute from. Only `padding` is reduced.
        child: Builder(
          builder: (context) {
            final MediaQueryData data = MediaQuery.of(context);
            return MediaQuery(
              data: data.copyWith(
                padding: data.padding.copyWith(left: 0, right: 0),
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// Port of `View.applyBottomInset()`.
///
/// Applied to the settings list and to the About screen's inner layout
/// (`platform-glue.window-insets#5`).
class BottomInset extends StatelessWidget {
  const BottomInset({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInsetOf(MediaQuery.of(context))),
      child: child,
    );
  }
}
