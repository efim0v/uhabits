/// The two halves of `platform-glue.rtl-layout` that the localization
/// inventory could not reach: the three-factor drag direction of
/// `HeaderView.updateScrollDirection`, and the fact that mirroring is partial
/// on purpose.
///
/// Rules 1, 2, 4 and 5 are asserted in test/l10n/localization_inventory_test
/// .dart, where the RTL locales themselves live. These two are about widget
/// geometry rather than about which translations ship, so they are here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/list_header.dart';
// ignore: implementation_imports
import 'package:uhabits_core/src/time/local_date.dart';

void main() {
  setUp(() => setToday(LocalDate.ymd(2015, 1, 25)));
  tearDown(resetToday);

  // =======================================================================
  // platform-glue.rtl-layout#3
  // =======================================================================

  group('platform-glue.rtl-layout', () {
    /// One [ListHeader] under [textDirection], reporting the data offsets it
    /// scrolls to.
    Future<List<int>> pumpHeader(
      WidgetTester tester, {
      required TextDirection textDirection,
      required bool reversed,
    }) async {
      final List<int> reported = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Directionality(
            textDirection: textDirection,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 600,
                child: ListHeader(
                  // A fresh key per pump, so the second pump in a test builds
                  // a new State instead of reusing the scroll position the
                  // first drag left behind.
                  key: UniqueKey(),
                  buttonCount: 5,
                  isCheckmarkSequenceReversed: reversed,
                  onDataOffsetChanged: reported.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return reported;
    }

    /// One horizontal drag of [dx] logical pixels. The first move pays the
    /// touch slop, which the recogniser swallows.
    Future<void> dragBy(WidgetTester tester, double dx) async {
      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.byType(ListHeader)));
      await gesture.moveBy(Offset(dx.isNegative ? -20 : 20, 0));
      await gesture.moveBy(Offset(dx, 0));
      await gesture.up();
      await tester.pump();
    }

    const String rule3 = 'platform-glue.rtl-layout#3 — '
        'HeaderView.updateScrollDirection(): direction starts at -1, is '
        'multiplied by -1 when Preferences.isCheckmarkSequenceReversed is '
        'true, and multiplied by -1 again when isRTL() is true. So in an RTL '
        'locale the swipe direction that pages back to older days is inverted, '
        'and enabling "reverse order of days" in an RTL locale cancels the '
        'inversion back to the LTR direction.';

    testWidgets('#3 factor one: -1, so a leftward drag pages into the past',
        (WidgetTester tester) async {
      List<int> reported = await pumpHeader(
        tester,
        textDirection: TextDirection.ltr,
        reversed: false,
      );
      await dragBy(tester, -60);
      expect(reported, <int>[1],
          reason: '$rule3 LTR, not reversed: dragging left moves back a '
              'column.');

      reported = await pumpHeader(
        tester,
        textDirection: TextDirection.ltr,
        reversed: false,
      );
      await dragBy(tester, 60);
      expect(reported, isEmpty,
          reason: '$rule3 And the other way runs into the "today" edge.');
    });

    testWidgets('#3 factor two: the reversed preference flips it',
        (WidgetTester tester) async {
      List<int> reported = await pumpHeader(
        tester,
        textDirection: TextDirection.ltr,
        reversed: true,
      );
      await dragBy(tester, -60);
      expect(reported, isEmpty, reason: rule3);

      reported = await pumpHeader(
        tester,
        textDirection: TextDirection.ltr,
        reversed: true,
      );
      await dragBy(tester, 60);
      expect(reported, <int>[1],
          reason: '$rule3 Reversed: the same drag now pages the other way.');
    });

    testWidgets('#3 factor three: an RTL layout inverts it again',
        (WidgetTester tester) async {
      List<int> reported = await pumpHeader(
        tester,
        textDirection: TextDirection.rtl,
        reversed: false,
      );
      await dragBy(tester, -60);
      expect(reported, isEmpty,
          reason: '$rule3 RTL alone: the leftward drag that paged back in an '
              'LTR layout no longer does.');

      reported = await pumpHeader(
        tester,
        textDirection: TextDirection.rtl,
        reversed: false,
      );
      await dragBy(tester, 60);
      expect(reported, <int>[1], reason: '$rule3 It is the rightward one.');
    });

    testWidgets('#3 the two flips cancel: RTL plus reversed is the LTR '
        'direction again', (WidgetTester tester) async {
      List<int> reported = await pumpHeader(
        tester,
        textDirection: TextDirection.rtl,
        reversed: true,
      );
      await dragBy(tester, -60);
      expect(reported, <int>[1],
          reason: '$rule3 Which is the whole point of composing the three '
              'factors instead of branching on them.');

      reported = await pumpHeader(
        tester,
        textDirection: TextDirection.rtl,
        reversed: true,
      );
      await dragBy(tester, 60);
      expect(reported, isEmpty, reason: rule3);
    });

    // =====================================================================
    // platform-glue.rtl-layout#6
    // =====================================================================

    testWidgets('#6 a non-directional margin does not flip, and that is what '
        'the colour button uses', (WidgetTester tester) async {
      const String rule = 'platform-glue.rtl-layout#6 — Mirroring is only '
          'partial by design: several layouts use '
          'android:layout_marginLeft/marginRight (e.g. the colour button in '
          'activity_edit_habit.xml) while others use marginStart/marginEnd '
          '(e.g. style FormLabel), so some paddings do not flip in RTL. '
          'Flutter draws the same distinction between EdgeInsets and '
          'EdgeInsetsDirectional, and the port carries the same split: the '
          'colour button\'s margin is the non-directional one, exactly as '
          'upstream\'s marginLeft/marginRight, so it stays put while the row '
          'around it mirrors.';

      // The rule's own example, straight from the screen that draws it.
      expect(EditHabitMetrics.colorButtonMargin, isA<EdgeInsets>(),
          reason: rule);
      expect(EditHabitMetrics.colorButtonMargin,
          isNot(isA<EdgeInsetsDirectional>()), reason: rule);
      expect(EditHabitMetrics.colorButtonMargin.left, 16,
          reason: '$rule android:layout_marginLeft="16dp"');
      expect(EditHabitMetrics.colorButtonMargin.right, 16,
          reason: '$rule android:layout_marginRight="16dp"');

      /// Where a 200-wide box lands inside a 400-wide parent, under [d].
      Future<Rect> boxUnder(TextDirection d, EdgeInsetsGeometry padding) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: d,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                height: 100,
                child: Padding(
                  padding: padding,
                  child: const SizedBox.expand(child: Placeholder()),
                ),
              ),
            ),
          ),
        );
        return tester.getRect(find.byType(Placeholder));
      }

      // Non-directional: identical geometry in both directions.
      final Rect ltrFixed =
          await boxUnder(TextDirection.ltr, EditHabitMetrics.colorButtonMargin);
      final Rect rtlFixed =
          await boxUnder(TextDirection.rtl, EditHabitMetrics.colorButtonMargin);
      expect(rtlFixed, ltrFixed,
          reason: '$rule The margin itself does not mirror.');

      // Directional, for contrast: the same numbers swap sides.
      const EdgeInsetsDirectional directional =
          EdgeInsetsDirectional.only(start: 40);
      final Rect ltrFlipped = await boxUnder(TextDirection.ltr, directional);
      final Rect rtlFlipped = await boxUnder(TextDirection.rtl, directional);
      expect(ltrFlipped.left, 40, reason: rule);
      expect(rtlFlipped.right, 400 - 40,
          reason: '$rule EdgeInsetsDirectional is marginStart/marginEnd, and '
              'it does mirror — which is what makes the other choice a '
              'choice.');
    });
  });
}
