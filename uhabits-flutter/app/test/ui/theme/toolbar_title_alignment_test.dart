/// Toolbar titles are start-aligned on every screen, on every platform.
///
/// Every screen upstream uses `res/layout/toolbar.xml`, a plain
/// `androidx.appcompat.widget.Toolbar`, and `setupToolbar` sets
/// `toolbar.title = title` (ViewExtensions.kt:185). An AppCompat toolbar title
/// always sits at the start, next to the up arrow.
///
/// Flutter decides per platform instead: with no `centerTitle`,
/// `AppBar._getEffectiveCenterTitle` falls through to the platform default,
/// which on iOS and macOS is `actions == null || actions.length < 2`. Settings
/// and About pass no actions and the habit editor passes exactly one, so those
/// three titles centre themselves there — while the list and the habit detail,
/// which have two or more actions, stay on the left. The app ends up
/// inconsistent with the original and with itself
/// (`feedback.toolbar-titles-centre-themselves-on-ios#1`).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/theme/app_theme.dart';
import 'package:uhabits_core/uhabits_core.dart' show LightTheme;

const String rule =
    'feedback.toolbar-titles-centre-themselves-on-ios#1 — an AppCompat toolbar '
    'title is start-aligned on every screen, so the port must not let the '
    'platform default decide it per screen.';

void main() {
  test('the app bar theme pins the alignment instead of inheriting it', () {
    expect(appThemeData(LightTheme()).appBarTheme.centerTitle, isFalse,
        reason: '$rule Left unset, the answer depends on the platform and on '
            'how many actions the individual bar happens to have.');
  });

  for (final platform in TargetPlatform.values) {
    for (final actionCount in <int>[0, 1, 2]) {
      testWidgets('$platform, $actionCount actions: the title stays at the '
          'start', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(MaterialApp(
          theme: appThemeData(LightTheme()),
          home: Scaffold(
            appBar: AppBar(
              leading: const BackButton(),
              title: const Text('Settings'),
              actions: <Widget>[
                for (var i = 0; i < actionCount; i++)
                  IconButton(icon: const Icon(Icons.add), onPressed: () {}),
              ],
            ),
          ),
        ));

        // The binding checks that no foundation debug variable is still set
        // once the body returns, so this cannot wait for tearDown.
        debugDefaultTargetPlatformOverride = null;

        final Rect title = tester.getRect(find.text('Settings'));
        final double screenCentre = tester.getSize(find.byType(AppBar)).width / 2;
        expect(title.left, lessThan(screenCentre / 2),
            reason: '$rule A centred title starts near the middle; a '
                'start-aligned one starts just past the up arrow.');
      });
    }
  }
}
