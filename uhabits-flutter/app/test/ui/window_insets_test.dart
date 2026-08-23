/// Edge-to-edge insets: which edge each surface pads, by how much, and what
/// the padded strip is filled with.
///
/// Upstream this is three `OnApplyWindowInsetsListener`s in
/// `utils/ViewExtensions.kt`, installed on a handful of specific views. Flutter
/// reports the same numbers through `MediaQuery`, so the arithmetic is
/// asserted directly on [MediaQueryData] and the placement is asserted by
/// pumping the widgets that carry it.
///
/// Two of the three listeners became widgets in `lib/ui/common/window_insets
/// .dart`; the third — `applyToolbarInsets` — did not, because `AppBar`
/// already does exactly what it did. That is asserted here rather than
/// assumed: if the framework ever stopped padding the toolbar's own `Material`
/// by the status-bar height, the toolbar colour would stop reaching behind the
/// status bar and rule 6 would break silently.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/common/window_insets.dart';

void main() {
  /// A window with a status bar, a navigation bar and a landscape notch on the
  /// left, and no keyboard.
  const MediaQueryData landscapeNotch = MediaQueryData(
    size: Size(800, 600),
    viewPadding: EdgeInsets.only(left: 44, top: 24, right: 12, bottom: 48),
    padding: EdgeInsets.only(left: 44, top: 24, right: 12, bottom: 48),
  );

  /// The same window with the keyboard up: `viewInsets.bottom` is the keyboard,
  /// and `padding.bottom` has collapsed to zero because the navigation bar is
  /// behind it.
  const MediaQueryData keyboardUp = MediaQueryData(
    size: Size(800, 600),
    viewPadding: EdgeInsets.only(left: 44, top: 24, right: 12, bottom: 48),
    padding: EdgeInsets.only(left: 44, top: 24, right: 12),
    viewInsets: EdgeInsets.only(bottom: 300),
  );

  /// Pumps [child] under [media], with nothing else in the way.
  Future<void> pumpUnder(
    WidgetTester tester,
    MediaQueryData media,
    Widget child,
  ) =>
      tester.pumpWidget(
        MediaQuery(
          data: media,
          child: Directionality(textDirection: TextDirection.ltr, child: child),
        ),
      );

  group('platform-glue.window-insets', () {
    testWidgets('#1 the root pads the sides only, and fills them with black',
        (WidgetTester tester) async {
      const String rule = 'platform-glue.window-insets#1 — '
          'applyRootViewInsets() installs an OnApplyWindowInsetsListener that '
          'pads the view left/right by max(systemBars.left, '
          'displayCutout.left) and max(systemBars.right, displayCutout.right), '
          'leaves top and bottom at 0, and sets the view background to a solid '
          'ColorDrawable(Color.BLACK). MediaQueryData.viewPadding is that '
          'maximum already: Flutter folds the system bars and the display '
          'cutout into one number per edge.';

      expect(
        rootViewInsetsOf(landscapeNotch),
        const EdgeInsets.only(left: 44, right: 12),
        reason: '$rule Left and right, and nothing else.',
      );
      expect(rootViewInsetsOf(landscapeNotch).top, 0, reason: rule);
      expect(rootViewInsetsOf(landscapeNotch).bottom, 0, reason: rule);

      await pumpUnder(
        tester,
        landscapeNotch,
        const RootViewInsets(child: SizedBox.expand()),
      );

      final Rect content = tester.getRect(find.byType(SizedBox));
      expect(content.left, 44, reason: '$rule The content starts after the '
          'notch.');
      expect(content.right, 800 - 12, reason: rule);
      expect(content.top, 0,
          reason: '$rule The top is the toolbar\'s to pad, not the root\'s.');
      expect(content.bottom, 600,
          reason: '$rule And the bottom belongs to whatever scrolls.');

      // The strips themselves: the ColorDrawable behind the padding.
      final ColoredBox box = tester.widget<ColoredBox>(find.byType(ColoredBox));
      expect(box.color, const Color(0xFF000000),
          reason: '$rule ColorDrawable(Color.BLACK).');
      expect(tester.getRect(find.byType(ColoredBox)),
          const Rect.fromLTRB(0, 0, 800, 600),
          reason: '$rule It spans the whole window, so the padded strips are '
              'what it shows through.');
    });

    testWidgets('#2 the bottom inset is the larger of the navigation bar and '
        'the keyboard', (WidgetTester tester) async {
      const String rule = 'platform-glue.window-insets#2 — applyBottomInset() '
          'pads only the bottom, by max(systemBars.bottom, ime.bottom) — so '
          'the view lifts above the on-screen keyboard.';

      expect(bottomInsetOf(landscapeNotch), 48,
          reason: '$rule No keyboard: the navigation bar wins.');
      expect(bottomInsetOf(keyboardUp), 300,
          reason: '$rule Keyboard up: the ime wins. Note that '
              'MediaQueryData.padding.bottom is 0 in this state, which is why '
              'viewPadding is the one read.');

      await pumpUnder(
        tester,
        landscapeNotch,
        const BottomInset(child: SizedBox.expand()),
      );
      Rect content = tester.getRect(find.byType(SizedBox));
      expect(content.bottom, 600 - 48, reason: rule);
      expect(content.top, 0, reason: '$rule Only the bottom.');
      expect(content.left, 0, reason: '$rule Only the bottom.');
      expect(content.right, 800, reason: '$rule Only the bottom.');

      await pumpUnder(
        tester,
        keyboardUp,
        const BottomInset(child: SizedBox.expand()),
      );
      content = tester.getRect(find.byType(SizedBox));
      expect(content.bottom, 600 - 300, reason: rule);
    });

    testWidgets('#3 the toolbar pads only the top, and by the status bar',
        (WidgetTester tester) async {
      const String rule = 'platform-glue.window-insets#3 — '
          'applyToolbarInsets() pads only the top, by max(systemBars.top, '
          'displayCutout.top). Nothing in this port installs a listener for '
          'it: AppBar is `primary: true` by default, which pads the toolbar\'s '
          'own Material by exactly MediaQuery.padding.top. What is checked '
          'here is that the two numbers agree — toolbarInsetOf is the same 24 '
          'the AppBar grows by — because a disagreement would only show up on '
          'a real notched device.';

      expect(toolbarInsetOf(landscapeNotch), 24, reason: rule);

      await pumpUnder(
        tester,
        landscapeNotch,
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Habits')),
            body: const SizedBox.expand(),
          ),
        ),
      );

      final Rect bar = tester.getRect(find.byType(AppBar));
      expect(bar.top, 0,
          reason: '$rule The toolbar starts at the very top of the window…');
      expect(bar.height, kToolbarHeight + 24,
          reason: '$rule …and is taller than a toolbar by exactly the status '
              'bar, which is the padding applyToolbarInsets added.');
      expect(bar.left, 0, reason: '$rule Only the top: setPadding(0, top, 0, '
          '0).');
      expect(bar.right, 800, reason: rule);
    });

    testWidgets('#4 the insets are not consumed: a child still sees all of '
        'them', (WidgetTester tester) async {
      const String rule = 'platform-glue.window-insets#4 — All three listeners '
          'return the original insets unconsumed, so child views still receive '
          'them. The two widgets here get that by construction: they add '
          'Padding and leave the ambient MediaQuery untouched, so a descendant '
          'reads exactly the viewPadding and viewInsets its ancestor read.';

      late MediaQueryData seen;
      Widget probe() => Builder(builder: (BuildContext context) {
            seen = MediaQuery.of(context);
            return const SizedBox.expand();
          });

      await pumpUnder(
        tester,
        keyboardUp,
        RootViewInsets(child: BottomInset(child: probe())),
      );

      expect(seen.viewPadding, keyboardUp.viewPadding, reason: rule);
      expect(seen.viewInsets, keyboardUp.viewInsets, reason: rule);
      expect(seen.padding, keyboardUp.padding, reason: rule);
      // Which is exactly what makes nesting them work: the inner widget can
      // still compute its own inset from the untouched numbers.
      expect(bottomInsetOf(seen), 300, reason: rule);
    });

    testWidgets('#5 the root inset is applied once, above the navigator',
        (WidgetTester tester) async {
      const String rule = 'platform-glue.window-insets#5 — '
          'applyRootViewInsets is called on the root view of '
          'ListHabitsActivity, ShowHabitActivity, EditSettingActivity (Tasker) '
          'and AboutView; applyToolbarInsets is applied inside '
          'View.setupToolbar; applyBottomInset is applied to the settings '
          'RecyclerView and the About screen\'s inner layout. Three of those '
          'four root views are one root here — MaterialApp.builder, above the '
          'navigator, so every route gets it — and the fourth, the Tasker edit '
          'screen, does not exist (platform-glue.tasker-edit-setting-screen is '
          'dispositioned as dropped).';

      // The app root: a route pushed on top is inside the padding too, which
      // is the whole point of installing it above the navigator.
      await pumpUnder(
        tester,
        landscapeNotch,
        MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              RootViewInsets(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );
      expect(tester.getRect(find.byType(Scaffold)).left, 44, reason: rule);
      expect(tester.getRect(find.byType(Scaffold)).right, 800 - 12,
          reason: rule);
    });

    testWidgets('#6 the toolbar colour is the status bar colour, and the '
        'elevation is 2', (WidgetTester tester) async {
      const String rule = 'platform-glue.window-insets#6 — setupToolbar sets '
          'the Activity window statusBarColor to the same color as the toolbar '
          'background; the toolbar color is StyledResources.getColor('
          'R.attr.colorPrimary) unless R.attr.useHabitColorAsPrimary is true, '
          'in which case it is theme.color(paletteColor).toInt(). Toolbar '
          'elevation is fixed at dpToPixels(2f). There is no window '
          'statusBarColor to set here: the AppBar\'s own Material extends '
          'behind the status bar (#3), so painting the toolbar paints the '
          'status bar, and the two can never disagree.';

      const Color toolbar = Color(0xFF33B5E5);
      await pumpUnder(
        tester,
        landscapeNotch,
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Habits'),
              backgroundColor: toolbar,
              elevation: 2,
            ),
            body: const SizedBox.expand(),
          ),
        ),
      );

      final Material material = tester.widget<Material>(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(Material),
        ).first,
      );
      expect(material.color, toolbar, reason: rule);
      expect(material.elevation, 2.0,
          reason: '$rule dpToPixels(2f) is 2 logical pixels in Flutter, which '
              'is the same unit.');
      // The painted Material really does cover the status-bar strip.
      expect(tester.getRect(find.byType(AppBar)).top, 0, reason: rule);
      expect(tester.getRect(find.byType(AppBar)).height,
          kToolbarHeight + toolbarInsetOf(landscapeNotch),
          reason: '$rule Which is what makes it the status bar colour too.');
    });
  });
}
