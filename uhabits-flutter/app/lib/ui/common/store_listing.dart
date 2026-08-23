/// Where the "Rate this app" rows in Settings and About point.
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

/// The app's own id, which both forms of the link are built from.
const String applicationId = 'org.isoron.uhabits';

/// `@string/playStoreURL`, resolved for the platform the app is running on.
///
/// On Android the constant is used verbatim: the Play Store app claims the
/// `market:` scheme, and `startActivitySafely` opens the listing with it.
///
/// Nothing on iOS or macOS claims `market:`. There `launchUrl` fails, and both
/// callers report that failure as "No app was found to support this action" —
/// so the row is permanently dead rather than occasionally unlucky. The same
/// listing over https opens in a browser, which every platform has
/// (`feedback.rate-app-row-is-dead-outside-android#1`). This port has no App
/// Store listing of its own to point at instead.
String get storeListingUrl => switch (defaultTargetPlatform) {
      TargetPlatform.android => 'market://details?id=$applicationId',
      _ => 'https://play.google.com/store/apps/details?id=$applicationId',
    };
