/// The two halves of `platform-glue.rtl-layout` that the localization
/// inventory could not reach: the three-factor drag direction of
/// `HeaderView.updateScrollDirection`, and the fact that mirroring is partial
/// on purpose.
///
/// Rules 1, 2, 4 and 5 are asserted in test/l10n/localization_inventory_test
/// .dart, where the RTL locales themselves live. These two are about widget
/// geometry rather than about which translations ship, so they are here.
///
/// The other half of the same subject — a screen whose start/end attributes
/// must actually mirror when the layout does — is
/// `audit10.the-edit-habit-form-pins-its-floating#1` at the bottom.
library;

// The core package does not export the database plumbing the editor needs.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/list_header.dart';
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

  // =======================================================================
  // audit10.the-edit-habit-form-pins-its-floating#1
  // =======================================================================

  group('audit10.the-edit-habit-form-pins-its-floating', () {
    const String rule = 'audit10.the-edit-habit-form-pins-its-floating#1 — '
        '@style/FormLabel carries android:layout_marginStart="8dp" inside a '
        'bare vertical LinearLayout (@style/FormInnerBox), whose default '
        'gravity START resolves to the right edge under RTL, and the Save '
        'button carries android:layout_marginEnd="16dp"; the manifest declares '
        'android:supportsRtl="true" and four RTL locales ship, so in Arabic, '
        'Hebrew, Persian and Uyghur every form caption sits against the *right* '
        'border of its box and the Save button keeps its 16dp gap from the '
        'left screen edge.';

    late Directory tempDir;
    final List<AppScope> scopes = <AppScope>[];

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('uhabits_rtl_form');
    });

    tearDown(() {
      for (final AppScope scope in scopes) {
        scope.close();
      }
      scopes.clear();
      tempDir.deleteSync(recursive: true);
    });

    /// The create-habit form, rendered in [locale].
    Future<L10n> pumpEditor(WidgetTester tester, Locale locale) async {
      final AppScope scope = AppScope.open(
        AppDatabase.openAndMigrate('${tempDir.path}/${locale.languageCode}.db'),
      );
      scope.preferences.isFirstRun = false;
      scopes.add(scope);
      await tester.pumpWidget(
        MaterialApp(
          // A fresh key per locale, so the second pump builds a new navigator
          // instead of reusing the one still holding the first editor.
          key: ValueKey<String>(locale.languageCode),
          locale: locale,
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Provider<AppScope>.value(
            value: scope,
            child: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      EditHabitScreen.route(scope: scope),
                    ),
                    child: const Text('host'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('host'));
      await tester.pumpAndSettle();
      return L10n.of(tester.element(find.byType(EditHabitScreen)));
    }

    /// The gap between a caption and the border of the box it floats over, on
    /// whichever side the ambient direction calls the start.
    double captionInset(WidgetTester tester, String label, TextDirection d) {
      final Finder caption = find.text(label);
      final Rect box = tester.getRect(
        find.ancestor(of: caption, matching: find.byType(Stack)).first,
      );
      final Rect text = tester.getRect(caption);
      // The caption's own Container pads it by labelInset on both sides, and
      // that padding is symmetric — only the Positioned decides the side.
      final double padded = EditHabitMetrics.labelInset;
      return d == TextDirection.ltr
          ? text.left - padded - box.left
          : box.right - (text.right + padded);
    }

    testWidgets('#1 every caption floats over the start border, whichever '
        'side that is', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final L10n en = await pumpEditor(tester, const Locale('en'));
      final Map<String, double> ltr = <String, double>{
        for (final String label in <String>[
          en.name,
          en.question,
          en.frequency,
          en.reminder,
          en.notes,
        ])
          label: captionInset(tester, label, TextDirection.ltr),
      };
      for (final MapEntry<String, double> entry in ltr.entries) {
        expect(entry.value, EditHabitMetrics.labelInset,
            reason: '$rule (LTR, "${entry.key}")');
      }

      final L10n ar = await pumpEditor(tester, const Locale('ar'));
      expect(
        Directionality.of(tester.element(find.byType(EditHabitScreen))),
        TextDirection.rtl,
        reason: '$rule Arabic is one of the four RTL locales that ship.',
      );
      for (final String label in <String>[
        ar.name,
        ar.question,
        ar.frequency,
        ar.reminder,
        ar.notes,
      ]) {
        expect(captionInset(tester, label, TextDirection.rtl),
            EditHabitMetrics.labelInset,
            reason: '$rule (RTL, "$label") — layout_marginStart is 8dp from '
                'whichever border the layout calls the start, so the caption '
                'must not stay stranded on the far left, detached from the '
                'right-aligned text it names.');
      }
    });

    testWidgets('#1 the Save button keeps its 16dp gap from the near screen '
        'edge', (WidgetTester tester) async {
      await pumpEditor(tester, const Locale('en'));
      Rect bar = tester.getRect(find.byType(AppBar));
      Rect save = tester.getRect(find.byKey(EditHabitScreen.saveButtonKey));
      expect(bar.right - save.right, 16.0,
          reason: '$rule (LTR) android:layout_marginEnd="16dp"');

      await pumpEditor(tester, const Locale('ar'));
      bar = tester.getRect(find.byType(AppBar));
      save = tester.getRect(find.byKey(EditHabitScreen.saveButtonKey));
      expect(save.left - bar.left, 16.0,
          reason: '$rule (RTL) the same margin, measured from the edge the '
              'button now sits against — not a button flush against the '
              'screen with its 16dp migrated to the title side.');
    });
  });
}
