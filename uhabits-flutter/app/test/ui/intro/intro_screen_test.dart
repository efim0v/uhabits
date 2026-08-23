// The preferences layer is reached by its `src` path, exactly like AppScope
// does; the core barrel only re-exports models, database, time and drawing.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/about/about_screen.dart';
import 'package:uhabits/ui/intro/intro_screen.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';

/// Widget tests for the two screens `IntroActivity` and `AboutActivity` become.
///
/// Both live in one file because the slice owns a single test file; the groups
/// below are named after the ledger features they cover:
/// `settings.intro.slides`, `settings.about.screen` and
/// `settings.about.developer-countdown`.
void main() {
  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  Widget wrap(Widget child, {Preferences? preferences}) {
    final app = MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: child,
    );
    if (preferences == null) return app;
    return Provider<Preferences>.value(value: preferences, child: app);
  }

  L10n l10nOf(WidgetTester tester, Type screen) =>
      L10n.of(tester.element(find.byType(screen)));

  // -----------------------------------------------------------------------
  // settings.intro.slides
  // -----------------------------------------------------------------------

  group('settings.intro.slides', () {
    testWidgets('#2 #3 #4 #5 #8 exactly three slides, in order', (tester) async {
      await tester.pumpWidget(wrap(const IntroScreen()));
      final context = tester.element(find.byType(IntroScreen));
      final l10n = L10n.of(context);
      final slides = IntroScreen.slidesOf(context);

      expect(slides.length, 3, reason: 'settings.intro.slides#2');

      expect(slides[0].title, l10n.introTitle1,
          reason: 'settings.intro.slides#3');
      expect(slides[0].title, 'Welcome', reason: 'settings.intro.slides#3');
      expect(slides[0].description, l10n.introDescription1,
          reason: 'settings.intro.slides#3');
      expect(
        slides[0].description,
        'Loop Habit Tracker helps you create and maintain good habits.',
        reason: 'settings.intro.slides#3',
      );
      expect(slides[0].backgroundColor, const Color(0xFF194673),
          reason: 'settings.intro.slides#3');

      expect(slides[1].title, l10n.introTitle2,
          reason: 'settings.intro.slides#4');
      expect(slides[1].title, 'Create some new habits',
          reason: 'settings.intro.slides#4');
      expect(slides[1].description, l10n.introDescription2,
          reason: 'settings.intro.slides#4');
      expect(slides[1].backgroundColor, const Color(0xFFFFA726),
          reason: 'settings.intro.slides#4');

      expect(slides[2].title, l10n.introTitle4,
          reason: 'settings.intro.slides#5');
      expect(slides[2].title, 'Track your progress',
          reason: 'settings.intro.slides#5');
      expect(slides[2].description, l10n.introDescription4,
          reason: 'settings.intro.slides#5');
      expect(slides[2].backgroundColor, const Color(0xFF9575CD),
          reason: 'settings.intro.slides#5');

      // There is no intro_title_3 / intro_icon_3 in the resources: the third
      // slide deliberately reads the _4 ones, which is why L10n has no
      // introTitle3 to bind at all.
      expect(slides[2].title, isNot(equals(slides[1].title)),
          reason: 'settings.intro.slides#8');
    });

    testWidgets('#1 the status bar is hidden for the whole intro',
        (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(wrap(const IntroScreen()));
      await tester.pumpAndSettle();

      final modes = calls
          .where((call) => call.method == 'SystemChrome.setEnabledSystemUIMode')
          .map((call) => call.arguments)
          .toList();
      expect(modes, contains('SystemUiMode.immersive'),
          reason: 'settings.intro.slides#1');

      // ...and only for the intro: leaving restores the normal chrome.
      calls.clear();
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      await tester.pumpAndSettle();
      final restored = calls
          .where((call) => call.method == 'SystemChrome.setEnabledSystemUIMode')
          .map((call) => call.arguments)
          .toList();
      expect(restored, isNot(contains('SystemUiMode.immersive')),
          reason: 'settings.intro.slides#1');
      expect(restored, isNotEmpty, reason: 'settings.intro.slides#1');
    });

    testWidgets('#2 #3 the pager opens on the first slide and swipes forward',
        (tester) async {
      await tester.pumpWidget(wrap(const IntroScreen()));
      final l10n = l10nOf(tester, IntroScreen);

      expect(find.text(l10n.introTitle1), findsOneWidget,
          reason: 'settings.intro.slides#3');
      expect(find.text(l10n.introDescription1), findsOneWidget,
          reason: 'settings.intro.slides#3');
      expect(find.text(l10n.introTitle2), findsNothing,
          reason: 'settings.intro.slides#2');

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text(l10n.introTitle2), findsOneWidget,
          reason: 'settings.intro.slides#4');

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text(l10n.introTitle4), findsOneWidget,
          reason: 'settings.intro.slides#5');

      // Exactly three: the last slide cannot be swiped past.
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text(l10n.introTitle4), findsOneWidget,
          reason: 'settings.intro.slides#2');
    });

    testWidgets('#2 the indicator carries one dot per slide', (tester) async {
      await tester.pumpWidget(wrap(const IntroScreen()));

      expect(find.byType(IntroPageDot), findsNWidgets(3),
          reason: 'settings.intro.slides#2');
      var dots = tester.widgetList<IntroPageDot>(find.byType(IntroPageDot));
      expect(dots.map((dot) => dot.isCurrent), <bool>[true, false, false],
          reason: 'settings.intro.slides#2');

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      dots = tester.widgetList<IntroPageDot>(find.byType(IntroPageDot));
      expect(dots.map((dot) => dot.isCurrent), <bool>[false, true, false],
          reason: 'settings.intro.slides#2');
    });

    test('#3 #4 #5 the background is a crossfade between slide colours', () {
      const colors = <Color>[
        Color(0xFF194673),
        Color(0xFFFFA726),
        Color(0xFF9575CD),
      ];

      expect(introBackgroundColorAt(colors, 0), colors[0],
          reason: 'settings.intro.slides#3');
      expect(introBackgroundColorAt(colors, 1), colors[1],
          reason: 'settings.intro.slides#4');
      expect(introBackgroundColorAt(colors, 2), colors[2],
          reason: 'settings.intro.slides#5');
      expect(introBackgroundColorAt(colors, 0.5),
          Color.lerp(colors[0], colors[1], 0.5),
          reason: 'settings.intro.slides#3');
      expect(introBackgroundColorAt(colors, 1.25),
          Color.lerp(colors[1], colors[2], 0.25),
          reason: 'settings.intro.slides#4');
      // Overscroll on either end clamps instead of throwing.
      expect(introBackgroundColorAt(colors, -0.4), colors[0],
          reason: 'settings.intro.slides#3');
      expect(introBackgroundColorAt(colors, 2.6), colors[2],
          reason: 'settings.intro.slides#5');
    });

    testWidgets('#3 #4 the painted background follows the pager',
        (tester) async {
      await tester.pumpWidget(wrap(const IntroScreen()));

      Color background() => tester
          .widget<ColoredBox>(find.byKey(IntroScreen.backgroundKey))
          .color;

      expect(background(), const Color(0xFF194673),
          reason: 'settings.intro.slides#3');

      // Held halfway between slide one and slide two the colour is neither.
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(PageView)));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-360, 0));
      await tester.pump();
      final mid = background();
      expect(mid, isNot(equals(const Color(0xFF194673))),
          reason: 'settings.intro.slides#3');
      expect(mid, isNot(equals(const Color(0xFFFFA726))),
          reason: 'settings.intro.slides#4');
      expect(mid.r, greaterThan(const Color(0xFF194673).r),
          reason: 'settings.intro.slides#4');
      expect(mid.r, lessThan(const Color(0xFFFFA726).r),
          reason: 'settings.intro.slides#4');
      await gesture.up();
      await tester.pumpAndSettle();

      expect(background(), const Color(0xFFFFA726),
          reason: 'settings.intro.slides#4');
    });

    testWidgets('#6 Skip finishes without writing a preference',
        (tester) async {
      final storage = _RecordingStorage();
      final preferences = Preferences(storage);
      var finished = 0;

      await tester.pumpWidget(
        wrap(
          IntroScreen(onFinished: () => finished++),
          preferences: preferences,
        ),
      );

      expect(find.byKey(IntroScreen.skipButtonKey), findsOneWidget,
          reason: 'settings.intro.slides#6');
      await tester.tap(find.byKey(IntroScreen.skipButtonKey));
      await tester.pumpAndSettle();

      expect(finished, 1, reason: 'settings.intro.slides#6');
      expect(storage.writes, isEmpty, reason: 'settings.intro.slides#6');
    });

    testWidgets('#6 Done finishes exactly the same way', (tester) async {
      final storage = _RecordingStorage();
      final preferences = Preferences(storage);
      var finished = 0;

      await tester.pumpWidget(
        wrap(
          IntroScreen(onFinished: () => finished++),
          preferences: preferences,
        ),
      );

      // Done only exists on the last slide; Skip only before it.
      expect(find.byKey(IntroScreen.doneButtonKey), findsNothing,
          reason: 'settings.intro.slides#6');
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(IntroScreen.doneButtonKey), findsOneWidget,
          reason: 'settings.intro.slides#6');
      expect(find.byKey(IntroScreen.skipButtonKey), findsNothing,
          reason: 'settings.intro.slides#6');

      await tester.tap(find.byKey(IntroScreen.doneButtonKey));
      await tester.pumpAndSettle();

      expect(finished, 1, reason: 'settings.intro.slides#6');
      expect(storage.writes, isEmpty, reason: 'settings.intro.slides#6');
    });
  });

  // -----------------------------------------------------------------------
  // settings.about.screen
  // -----------------------------------------------------------------------

  group('settings.about.screen', () {
    final launched = <Uri>[];

    setUp(launched.clear);

    Future<void> pumpAbout(
      WidgetTester tester, {
      Preferences? preferences,
      bool handleLinks = true,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrap(
          AboutScreen(
            preferences: preferences ?? Preferences(MemoryStorage()),
            onOpenLink: handleLinks
                ? (uri) async {
                    launched.add(uri);
                    return true;
                  }
                : (uri) async {
                    launched.add(uri);
                    return false;
                  },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('#1 the toolbar is titled About and tinted PaletteColor(11)',
        (tester) async {
      await pumpAbout(tester);
      final l10n = l10nOf(tester, AboutScreen);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(l10n.about)),
        findsOneWidget,
        reason: 'settings.about.screen#1',
      );
      expect(l10n.about, 'About', reason: 'settings.about.screen#1');
      // Theme.color(11) — the same value the core palette returns.
      expect(appBar.backgroundColor, const Color(0xFF1976D2),
          reason: 'settings.about.screen#1');
    });

    testWidgets('#2 the first card shows the icon, the name and the version',
        (tester) async {
      await pumpAbout(tester);
      final l10n = l10nOf(tester, AboutScreen);

      final icon = find.byKey(AboutScreen.appIconKey);
      expect(icon, findsOneWidget, reason: 'settings.about.screen#2');
      expect(tester.getSize(icon), const Size(100, 100),
          reason: 'settings.about.screen#2');

      final name = find.text(l10n.appName);
      expect(name, findsOneWidget, reason: 'settings.about.screen#2');
      expect(l10n.appName, 'Loop Habit Tracker',
          reason: 'settings.about.screen#2');
      final nameStyle = tester.widget<Text>(name).style!;
      expect(nameStyle.fontWeight, FontWeight.bold,
          reason: 'settings.about.screen#2');
      expect(nameStyle.fontSize, 16, reason: 'settings.about.screen#2');
      expect(nameStyle.color, AboutScreen.aboutScreenColorLight,
          reason: 'settings.about.screen#2');

      expect(find.text(l10n.versionN(AboutScreen.appVersionName)), findsOneWidget,
          reason: 'settings.about.screen#2');
      expect(find.text('Version 2.3.1'), findsOneWidget,
          reason: 'settings.about.screen#2');
    });

    testWidgets('#3 the Links card holds exactly five rows, in order',
        (tester) async {
      await pumpAbout(tester);
      final l10n = l10nOf(tester, AboutScreen);

      expect(find.text(l10n.links), findsOneWidget,
          reason: 'settings.about.screen#3');

      final labels = <String>[
        l10n.prefRateThisApp,
        l10n.prefSendFeedback,
        l10n.helpTranslate,
        l10n.prefViewSourceCode,
        l10n.prefViewPrivacy,
      ];
      expect(labels, <String>[
        'Rate this app on Google Play',
        'Send feedback to developer',
        'Help translate this app',
        'View source code at GitHub',
        'View privacy policy',
      ], reason: 'settings.about.screen#3');

      final tops = <double>[];
      for (final label in labels) {
        expect(find.text(label), findsOneWidget,
            reason: 'settings.about.screen#3');
        tops.add(tester.getTopLeft(find.text(label)).dy);
      }
      expect(tops, orderedEquals(<double>[...tops]..sort()),
          reason: 'settings.about.screen#3');
      expect(tops.first, greaterThan(tester.getTopLeft(find.text(l10n.links)).dy),
          reason: 'settings.about.screen#3');

      // Five, and no sixth: the contributors row belongs to the next card.
      expect(
        find.descendant(
          of: find.byKey(AboutScreen.linksCardKey),
          matching: find.byType(InkWell),
        ),
        findsNWidgets(5),
        reason: 'settings.about.screen#3',
      );
    });

    testWidgets('#4 every link opens the documented target', (tester) async {
      await pumpAbout(tester);
      final l10n = l10nOf(tester, AboutScreen);

      final expected = <String, String>{
        l10n.prefRateThisApp: 'market://details?id=org.isoron.uhabits',
        l10n.prefSendFeedback:
            'mailto:dev@loophabits.org?subject=Feedback%20about%20Loop%20Habit%20Tracker',
        l10n.helpTranslate: 'http://translate.loophabits.org/',
        l10n.prefViewSourceCode: 'https://github.com/iSoron/uhabits',
        l10n.prefViewPrivacy: 'http://loophabits.org/privacy',
      };

      for (final entry in expected.entries) {
        launched.clear();
        await tester.ensureVisible(find.text(entry.key));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(launched.map((uri) => uri.toString()), <String>[entry.value],
            reason: 'settings.about.screen#4');
      }
    });

    testWidgets('#5 a link nothing can open falls back to a snackbar',
        (tester) async {
      await pumpAbout(tester, handleLinks: false);
      final l10n = l10nOf(tester, AboutScreen);

      await tester.tap(find.text(l10n.prefRateThisApp));
      await tester.pump();

      expect(find.text(l10n.activityNotFound), findsOneWidget,
          reason: 'settings.about.screen#5');
      expect(l10n.activityNotFound,
          'No app was found to support this action',
          reason: 'settings.about.screen#5');
    });

    testWidgets('#6 the Developers card lists 15 names in order',
        (tester) async {
      await pumpAbout(tester);
      final l10n = l10nOf(tester, AboutScreen);

      expect(find.text(l10n.developers), findsOneWidget,
          reason: 'settings.about.screen#6');
      expect(AboutScreen.developers, <String>[
        'Álinson S. Xavier (@iSoron)',
        'Quentin Hibon (@hiqua)',
        'Oleg Ivashchenko (@olegivo)',
        'Kristian Tashkov (@KristianTashkov)',
        'Jakub Kalinowski (@kalina559)',
        'Rechee Jozil (@recheej)',
        'Sebastian Gallese (@sgallese)',
        'Luboš Luňák (@llunak)',
        'Bindu (@vbh)',
        'Victor Yu (@vyu1)',
        'Christoph Hennemann (@chennemann)',
        'Денис (@sciamano)',
        'Joseph Tran (@JotraN)',
        'Nikhil (@regularcoder)',
        'JanetQC',
      ], reason: 'settings.about.screen#6');

      final tops = <double>[];
      for (final name in AboutScreen.developers) {
        expect(find.text(name), findsOneWidget,
            reason: 'settings.about.screen#6');
        tops.add(tester.getTopLeft(find.text(name)).dy);
      }
      expect(tops, orderedEquals(<double>[...tops]..sort()),
          reason: 'settings.about.screen#6');
    });

    testWidgets('#7 the Developers card ends with View all contributors…',
        (tester) async {
      await pumpAbout(tester);
      final l10n = l10nOf(tester, AboutScreen);

      final row = find.text(l10n.viewAllContributors);
      expect(row, findsOneWidget, reason: 'settings.about.screen#7');
      expect(l10n.viewAllContributors, 'View all contributors…',
          reason: 'settings.about.screen#7');
      expect(
        tester.getTopLeft(row).dy,
        greaterThan(tester.getTopLeft(find.text(AboutScreen.developers.last)).dy),
        reason: 'settings.about.screen#7',
      );

      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        launched.map((uri) => uri.toString()),
        <String>['https://github.com/iSoron/uhabits/graphs/contributors'],
        reason: 'settings.about.screen#7',
      );
    });

    testWidgets('#8 the Translators card groups names by language',
        (tester) async {
      await pumpAbout(tester);
      final l10n = l10nOf(tester, AboutScreen);

      expect(find.text(l10n.translators), findsOneWidget,
          reason: 'settings.about.screen#8');
      expect(AboutScreen.translators.length, 44,
          reason: 'settings.about.screen#8');
      expect(
        AboutScreen.translators.fold<int>(0, (sum, g) => sum + g.names.length),
        172,
        reason: 'settings.about.screen#8',
      );
      expect(AboutScreen.translators.first.language, 'Bahasa Indonesia',
          reason: 'settings.about.screen#8');
      expect(AboutScreen.translators.first.names.first, 'Angga Rifandi',
          reason: 'settings.about.screen#8');

      // The heading sits above the names it groups, and neither is clickable.
      final heading = find.text('Bahasa Indonesia');
      expect(heading, findsOneWidget, reason: 'settings.about.screen#8');
      expect(
        tester.getTopLeft(find.text('Angga Rifandi')).dy,
        greaterThan(tester.getTopLeft(heading).dy),
        reason: 'settings.about.screen#8',
      );
      expect(
        find.descendant(
          of: find.byKey(AboutScreen.translatorsCardKey),
          matching: find.byType(InkWell),
        ),
        findsNothing,
        reason: 'settings.about.screen#8',
      );
    });
  });

  // -----------------------------------------------------------------------
  // settings.about.developer-countdown
  // -----------------------------------------------------------------------

  group('settings.about.developer-countdown', () {
    Future<Preferences> pumpAbout(
      WidgetTester tester, {
      Preferences? preferences,
    }) async {
      final prefs = preferences ?? Preferences(MemoryStorage());
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrap(AboutScreen(preferences: prefs, onOpenLink: (_) async => true)),
      );
      await tester.pumpAndSettle();
      return prefs;
    }

    Future<void> tapVersion(WidgetTester tester, int times) async {
      for (var i = 0; i < times; i++) {
        await tester.tap(find.byKey(AboutScreen.versionKey));
        await tester.pump();
      }
    }

    testWidgets('#1 #2 #3 the fifth tap on the version makes you a developer',
        (tester) async {
      final prefs = await pumpAbout(tester);
      final l10n = l10nOf(tester, AboutScreen);

      expect(prefs.isDeveloper, isFalse,
          reason: 'settings.about.developer-countdown#1');

      // Four taps: the counter runs 4, 3, 2, 1 and nothing happens.
      await tapVersion(tester, 4);
      expect(prefs.isDeveloper, isFalse,
          reason: 'settings.about.developer-countdown#2');
      expect(find.text(l10n.youAreNowADeveloper), findsNothing,
          reason: 'settings.about.developer-countdown#2');

      await tapVersion(tester, 1);
      expect(prefs.isDeveloper, isTrue,
          reason: 'settings.about.developer-countdown#3');
      expect(find.text(l10n.youAreNowADeveloper), findsOneWidget,
          reason: 'settings.about.developer-countdown#3');
      expect(l10n.youAreNowADeveloper, 'You are now a developer',
          reason: 'settings.about.developer-countdown#3');
    });

    testWidgets('#4 further taps drive the counter negative and do nothing',
        (tester) async {
      final prefs = await pumpAbout(tester);
      final l10n = l10nOf(tester, AboutScreen);

      await tapVersion(tester, 5);
      expect(prefs.isDeveloper, isTrue,
          reason: 'settings.about.developer-countdown#3');

      // Clear the first snackbar, then prove no second one is raised and no
      // second write happens.
      ScaffoldMessenger.of(tester.element(find.byType(AboutScreen)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(find.text(l10n.youAreNowADeveloper), findsNothing,
          reason: 'settings.about.developer-countdown#4');
      prefs.isDeveloper = false;

      await tapVersion(tester, 4);
      expect(prefs.isDeveloper, isFalse,
          reason: 'settings.about.developer-countdown#4');
      expect(find.text(l10n.youAreNowADeveloper), findsNothing,
          reason: 'settings.about.developer-countdown#4');
    });

    testWidgets('#5 the counter is not persisted across visits',
        (tester) async {
      final prefs = await pumpAbout(tester);

      await tapVersion(tester, 3);
      expect(prefs.isDeveloper, isFalse,
          reason: 'settings.about.developer-countdown#5');

      // Leave the screen and come back with the same preferences.
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      await tester.pumpAndSettle();
      await pumpAbout(tester, preferences: prefs);

      await tapVersion(tester, 4);
      expect(prefs.isDeveloper, isFalse,
          reason: 'settings.about.developer-countdown#5');
      await tapVersion(tester, 1);
      expect(prefs.isDeveloper, isTrue,
          reason: 'settings.about.developer-countdown#5');
    });

    testWidgets('#6 the About screen offers no way back out of developer mode',
        (tester) async {
      final prefs = await pumpAbout(tester);

      await tapVersion(tester, 5);
      expect(prefs.isDeveloper, isTrue,
          reason: 'settings.about.developer-countdown#6');

      expect(find.byType(Switch), findsNothing,
          reason: 'settings.about.developer-countdown#6');
      expect(find.byType(SwitchListTile), findsNothing,
          reason: 'settings.about.developer-countdown#6');

      await tapVersion(tester, 10);
      expect(prefs.isDeveloper, isTrue,
          reason: 'settings.about.developer-countdown#6');
    });
  });
}

/// A [MemoryStorage] that remembers every mutation made through it.
class _RecordingStorage extends MemoryStorage {
  final List<String> writes = <String>[];

  @override
  void putBoolean(String key, bool value) {
    writes.add(key);
    super.putBoolean(key, value);
  }

  @override
  void putInt(String key, int value) {
    writes.add(key);
    super.putInt(key, value);
  }

  @override
  void putLong(String key, int value) {
    writes.add(key);
    super.putLong(key, value);
  }

  @override
  void putString(String key, String value) {
    writes.add(key);
    super.putString(key, value);
  }

  @override
  void remove(String key) {
    writes.add(key);
    super.remove(key);
  }

  @override
  void clear() {
    writes.add('*');
    super.clear();
  }
}
