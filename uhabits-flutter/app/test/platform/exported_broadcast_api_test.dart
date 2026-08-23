/// The exported broadcast API, and why the port does not have one.
///
/// Upstream `WidgetReceiver` is declared `android:exported="true"` with
/// `android:permission="false"` and four intent-filters, so any other app on
/// the device — Tasker, MacroDroid, `adb shell am broadcast`, a third-party
/// launcher shortcut — can send `org.isoron.uhabits.ACTION_ADD_REPETITION` and
/// have an entry written with no UI shown and no permission held.
///
/// `audit7.the-exported-broadcast-api-other-apps` asks for that capability to
/// be reinstated, or for its loss to be recorded. **Its premise — "the loss is
/// not recorded" — is wrong, and the capability is deliberately not
/// reinstated.** The loss is already recorded in three places, and this file is
/// the fourth:
///
///  1. `docs/parity/FEATURES.md` lists `intents.widget-receiver-dispatch` among
///     the android-only features, with the note "Background broadcast delivery
///     while the app is dead has no Flutter equivalent; needs a native receiver
///     or WorkManager/AlarmManager bridge".
///  2. The same file's `platform-glue.manifest-components` note says of the
///     attribute in question: `android:permission="false"` on WidgetReceiver
///     "looks like a latent bug worth NOT reproducing" — an owner decision, in
///     the ledger, against porting it.
///  3. `test/platform/manifest_components_test.dart` pins
///     `intents.widget-receiver-dispatch#12` with exactly that reading: the
///     port has no WidgetReceiver component, "which closes the hole
///     android:permission="false" left open — no other app can drive it — at
///     the cost of the widget having to foreground the app to act".
///
/// The one named consumer of the API is dispositioned too: all four
/// `platform-glue.tasker-*` features are marked superseded, dropped by owner
/// decision, and `platform-glue.tasker-parse-intent`'s disposition spells out
/// that "with the edit screen and the fire receiver gone, nothing produces a
/// setting bundle" — so there is no Tasker plugin left in this port for an
/// exported receiver to serve.
///
/// What follows is therefore not a fix. It is the assertion that the decision
/// still holds in the tree: the action strings survive as the app's own
/// contract, and nothing in the Flutter manifest offers them to anyone else.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/intent_router.dart';
import 'package:uhabits/state/widget_link.dart' show WidgetLink;

/// `app/`, found by walking up from wherever the test runner started.
Directory _findAppDir() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String suffix in <String>['.', 'app']) {
      final Directory candidate = Directory('${dir.path}/$suffix');
      if (File('${candidate.path}/android/app/src/main/AndroidManifest.xml')
          .existsSync()) {
        return candidate;
      }
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('app/ not found from ${Directory.current.path}');
}

final Directory _appDir = _findAppDir();

/// The Flutter build's manifest, XML comments stripped so that prose naming a
/// component cannot stand in for declaring it.
final String _manifest =
    File('${_appDir.path}/android/app/src/main/AndroidManifest.xml')
        .readAsStringSync()
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

void main() {
  const String rule =
      'audit7.the-exported-broadcast-api-other-apps#1 — WidgetReceiver is '
      'exported with android:permission="false", i.e. deliberately reachable '
      'by any other app. Tasker, MacroDroid, `adb shell am broadcast`, or a '
      'third-party launcher shortcut can send '
      'org.isoron.uhabits.ACTION_ADD_REPETITION / ACTION_REMOVE_REPETITION / '
      'ACTION_TOGGLE_REPETITION with data = '
      'content://org.isoron.uhabits/habit/<id> and an optional `timestamp` '
      'extra; WidgetBehavior writes the entry through CreateRepetitionCommand '
      'with no UI shown, whether or not the app is running.';

  const String disposition =
      'NOT REPRODUCED, and the loss is recorded — see the library comment at '
      'the top of this file. FEATURES.md marks '
      'intents.widget-receiver-dispatch android-only ("background broadcast '
      'delivery while the app is dead has no Flutter equivalent"), calls '
      'android:permission="false" on WidgetReceiver a "latent bug worth NOT '
      'reproducing" under platform-glue.manifest-components, and supersedes '
      'all four platform-glue.tasker-* features as dropped by owner decision, '
      'which removes the API\'s only named consumer.';

  group('audit7.the-exported-broadcast-api-other-apps', () {
    test('#1 the Flutter manifest offers no uhabits action to any other app',
        () {
      expect(
        _manifest,
        isNot(contains('org.isoron.uhabits.ACTION_')),
        reason: '$rule $disposition No intent-filter in this manifest names '
            'one of the four actions, so no external broadcast can match.',
      );
      // And the entry point that does exist is the app's own deep link, on a
      // scheme and host that the upstream filters never matched.
      expect(WidgetLink.scheme, 'uhabits', reason: '$rule $disposition');
      expect(WidgetLink.authority, 'widget', reason: '$rule $disposition');
      expect(WidgetLink.scheme, isNot('content'),
          reason: '$rule $disposition The filters matched scheme "content", '
              'host "org.isoron.uhabits"; the replacement contract shares '
              'neither, which is what keeps an outside intent from resolving.');
    });

    test('#1 the action strings survive as the app\'s own contract', () {
      // Dropping the export is not the same as dropping the vocabulary: an
      // existing PendingIntent, a stored shortcut or a bug report still names
      // these strings, so they stay, in manifest declaration order.
      expect(
        WidgetActions.exported,
        <String>[
          'org.isoron.uhabits.ACTION_SET_NUMERICAL_VALUE',
          'org.isoron.uhabits.ACTION_TOGGLE_REPETITION',
          'org.isoron.uhabits.ACTION_ADD_REPETITION',
          'org.isoron.uhabits.ACTION_REMOVE_REPETITION',
        ],
        reason: '$rule $disposition',
      );
      // The three the audit names are the three the Dart receiver really
      // dispatches; the fourth was a dead filter upstream and stays dead here.
      expect(
        WidgetActions.exported
            .where(WidgetActions.dispatched.contains)
            .toList(),
        <String>[
          WidgetActions.toggleRepetition,
          WidgetActions.addRepetition,
          WidgetActions.removeRepetition,
        ],
        reason: '$rule $disposition',
      );
      expect(
        WidgetActions.dispatched,
        isNot(contains(WidgetActions.setNumericalValue)),
        reason: '$rule $disposition ACTION_SET_NUMERICAL_VALUE had a filter '
            'and no branch upstream, so it wrote nothing there either.',
      );
    });

    test('#1 no receiver in this build is exported with a uhabits filter', () {
      final Iterable<RegExpMatch> receivers = RegExp(
        r'<receiver\b[^>]*?/>|<receiver\b[\s\S]*?</receiver>',
      ).allMatches(_manifest);
      expect(receivers, isNotEmpty,
          reason: '$rule $disposition The manifest does declare receivers — '
              'this check would be vacuous otherwise.');
      for (final RegExpMatch match in receivers) {
        final String block = match.group(0)!;
        expect(block, isNot(contains('org.isoron.uhabits.ACTION_')),
            reason: '$rule $disposition');
        expect(block, isNot(contains('android:permission="false"')),
            reason: '$rule $disposition — the attribute the audit is about is '
                'in no receiver here.');
      }
    });
  });
}
