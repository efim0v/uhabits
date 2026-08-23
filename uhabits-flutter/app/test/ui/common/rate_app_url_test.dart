/// The "Rate this app" rows must point somewhere the platform can actually go.
///
/// `@string/playStoreURL` is `market://details?id=org.isoron.uhabits`, and on
/// Android that is right: the Play Store app claims the `market:` scheme and
/// `startActivitySafely` opens the listing. No iOS or macOS app claims it, so
/// `UIApplication.open` fails, `openExternalUri` returns false, and the row's
/// caller shows "No app was found to support this action" — every time, for
/// good. `feedback.rate-app-row-is-dead-outside-android#1`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/about/about_screen.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';

const String rule =
    'feedback.rate-app-row-is-dead-outside-android#1 — the Rate this app rows '
    'in Settings and About must open the store listing on every platform the '
    'app ships on, not only where the market: scheme resolves.';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android keeps the market: deep link', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(SettingsScreen.rateAppUrl, 'market://details?id=org.isoron.uhabits',
        reason: '$rule On Android this is @string/playStoreURL verbatim.');
    expect(AboutLinks.rateApp.toString(),
        'market://details?id=org.isoron.uhabits',
        reason: rule);
  });

  for (final platform in <TargetPlatform>[
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    test('$platform gets a scheme it can open', () {
      debugDefaultTargetPlatformOverride = platform;

      for (final url in <String>[
        SettingsScreen.rateAppUrl,
        AboutLinks.rateApp.toString(),
      ]) {
        expect(url, isNot(startsWith('market:')),
            reason: '$rule Nothing on $platform claims the market: scheme, so '
                'the row can only ever fail.');
        expect(Uri.parse(url).scheme, 'https',
            reason: '$rule A browser is always there to take an https link.');
        expect(url, contains('org.isoron.uhabits'),
            reason: '$rule And it has to be this app, not a search page.');
      }
    });
  }
}
