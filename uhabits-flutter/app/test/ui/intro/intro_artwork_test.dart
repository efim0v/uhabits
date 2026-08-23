/// `audit3.the-loop-logo-and-the-two#1`: the About screen and the intro slides
/// show the artwork the app actually ships.
///
/// Upstream those three images are `res/drawable/intro_icon_1.png`,
/// `intro_icon_2.png` and `intro_icon_4.png`: the Loop logo at 100x100 on the
/// About screen's first card, and the illustrations of a habit card and of a
/// score graph on intro slides 2 and 3. The port drew approximations of all
/// three with `CustomPainter` and shipped no image at all.
///
/// So the assertions below are byte-for-byte: whatever the running widget puts
/// on screen has to be the same PNG upstream puts there, read from
/// `uhabits-android/src/main/res/drawable/` at test time. An approximation
/// cannot pass, and neither can a re-encoded or re-scaled copy.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/l10n/app_localizations_en.dart';
import 'package:uhabits/ui/about/about_screen.dart';
import 'package:uhabits/ui/intro/intro_screen.dart';

const String rule = 'audit3.the-loop-logo-and-the-two#1 — In the Kotlin app: '
    'The About screen\'s first card shows the real Loop app artwork at '
    '100x100, and intro slides 2 and 3 show the shipped illustrations of a '
    'habit card and of a score graph.';

/// The repository root: the directory that holds docs/parity/FEATURES.md, the
/// same anchor packages/uhabits_core/test/gui/screenshot_baselines_test.dart
/// uses.
Directory get _repoRoot {
  Directory dir = Directory.current;
  while (true) {
    if (File('${dir.path}/docs/parity/FEATURES.md').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Repository root not found from ${Directory.current}');
    }
    dir = parent;
  }
}

Uint8List drawable(String name) => File(
      '${_repoRoot.path}/uhabits-android/src/main/res/drawable/$name',
    ).readAsBytesSync();

/// The bytes the single [Image] inside [of] is painting.
Uint8List paintedBytes(WidgetTester tester, Finder of) {
  final Image image = tester.widget<Image>(
    find.descendant(of: of, matching: find.byType(Image)),
  );
  final ImageProvider provider = image.image;
  if (provider is MemoryImage) return provider.bytes;
  fail('$rule The image is a ${provider.runtimeType}, which cannot be the '
      'shipped drawable.');
}

bool sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  final L10nEn l10n = L10nEn();

  /// The slide whose title is [title] — found the way a reader finds it, by
  /// the words on the screen.
  Finder slide(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(Column)).first;

  Finder slideIcon(String title) =>
      find.descendant(of: slide(title), matching: find.byType(Image));

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: home,
    ));
    await tester.pumpAndSettle();
  }

  group('audit3.the-loop-logo-and-the-two', () {
    testWidgets('#1 the About screen shows the real Loop artwork at 100x100',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pump(tester, const AboutScreen());

      final Finder icon = find.byKey(AboutScreen.appIconKey);
      expect(icon, findsOneWidget, reason: rule);
      expect(tester.getSize(icon), const Size(100, 100), reason: rule);
      expect(sameBytes(paintedBytes(tester, icon), drawable('intro_icon_1.png')),
          isTrue,
          reason: '$rule about.xml points at @drawable/intro_icon_1, so the '
              'card shows that file and not a drawing of it.');
    });

    testWidgets('#1 intro slide 1 shows the same logo drawable',
        (tester) async {
      await pump(tester, const IntroScreen());

      expect(
        sameBytes(
          paintedBytes(tester, find.byType(IntroIcon1).first),
          drawable('intro_icon_1.png'),
        ),
        isTrue,
        reason: rule,
      );
    });

    testWidgets('#1 slides 2 and 3 show the shipped illustrations',
        (tester) async {
      await pump(tester, const IntroScreen());

      // The user walks the pager; the slides are what they walk to.
      await tester.tap(find.byKey(IntroScreen.nextButtonKey));
      await tester.pumpAndSettle();
      expect(
        sameBytes(
          paintedBytes(tester, slide(l10n.introTitle2)),
          drawable('intro_icon_2.png'),
        ),
        isTrue,
        reason: '$rule Slide 2 is the illustration of a habit card.',
      );

      await tester.tap(find.byKey(IntroScreen.nextButtonKey));
      await tester.pumpAndSettle();
      expect(
        sameBytes(
          paintedBytes(tester, slide(l10n.introTitle4)),
          drawable('intro_icon_4.png'),
        ),
        isTrue,
        reason: '$rule Slide 3 is the illustration of a score graph.',
      );
    });

    testWidgets('#1 the three drawables keep their own aspect ratios',
        (tester) async {
      // 484x484, 967x224 and 695x585 upstream: a card illustration is wide and
      // a score graph is nearly square, so neither may be squeezed into the
      // logo's box.
      await pump(tester, const IntroScreen());
      final Size logo = tester.getSize(find.byType(IntroIcon1).first);
      expect(logo.width / logo.height, closeTo(1.0, 0.01), reason: rule);

      await tester.tap(find.byKey(IntroScreen.nextButtonKey));
      await tester.pumpAndSettle();
      final Size card = tester.getSize(slideIcon(l10n.introTitle2));
      expect(card.width / card.height, closeTo(967 / 224, 0.02),
          reason: rule);

      await tester.tap(find.byKey(IntroScreen.nextButtonKey));
      await tester.pumpAndSettle();
      final Size graph = tester.getSize(slideIcon(l10n.introTitle4));
      expect(graph.width / graph.height, closeTo(695 / 585, 0.02),
          reason: rule);
    });
  });
}
