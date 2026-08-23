/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt —
/// `Context.startActivitySafely(intent)` — for the one intent the app fires
/// with it more than anywhere else:
///
/// ```kotlin
/// fun Context.startActivitySafely(intent: Intent) {
///     try {
///         startActivity(intent)
///     } catch (e: ActivityNotFoundException) {
///         showMessage(R.string.activity_not_found)
///     }
/// }
/// ```
///
/// `Intent(ACTION_VIEW, uri)` — and the `ACTION_SENDTO` `mailto:` that goes
/// with it — has no Flutter equivalent other than url_launcher, and a plugin
/// cannot run in a widget test. That is why every screen that opens a link
/// takes a callback instead of calling the plugin itself:
/// `AboutScreen.onOpenLink`, `SettingsScreen.onOpenUrl`,
/// `HabitListScreen.onOpenUrl` and [UrlOpener] behind the bug report. This is
/// the single implementation all four are given; the seams stay open so that a
/// test can still stand in for the system.
///
/// Android has exactly one failure mode here, `ActivityNotFoundException`.
/// url_launcher has two — a false answer and a thrown `PlatformException` — so
/// both are folded into the same false, and the *caller* is what shows
/// "No app was found to support this action", exactly as `startActivitySafely`
/// does.
library;

import 'package:url_launcher/url_launcher.dart';

/// Hands [uri] to the system, and answers whether anything took it.
///
/// `LaunchMode.externalApplication` is `Intent.ACTION_VIEW`: the link always
/// leaves the app, and never opens in an in-app web view — Android has no such
/// fallback and neither does this.
Future<bool> openExternalUri(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    // `catch (e: ActivityNotFoundException)`, widened to whatever a plugin on
    // a host with no launcher at all throws.
    return false;
  }
}

/// [openExternalUri] for the callers that hold the URL as a string — the FAQ
/// and Play Store rows, and the `mailto:` a bug report goes to.
Future<bool> openExternalUrl(String url) => openExternalUri(Uri.parse(url));
