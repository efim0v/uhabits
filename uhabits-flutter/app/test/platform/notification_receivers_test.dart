/// The three `flutter_local_notifications` broadcast receivers the app has to
/// declare itself.
///
/// Since version 16 the plugin's own `android/src/main/AndroidManifest.xml`
/// declares nothing but two `<uses-permission>` lines — `VIBRATE` and
/// `POST_NOTIFICATIONS`. Its README says so in as many words ("Previously the
/// plugin would specify all the permissions required all of the features that
/// the plugin support in its own AndroidManifest.xml file so that developers
/// wouldn't need to do this in their own app's AndroidManifest.xml file. Since
/// version 16 onwards, the plugin will now only specify the bare minimum") and
/// then lists, per feature, what the *app* must add between its `<application>`
/// tags. Its own example app declares all three.
///
/// Nothing about a missing receiver is observable from Dart. `zonedSchedule`
/// returns normally, `AlarmManager` accepts the alarm, and at the scheduled
/// instant the system tries to deliver a broadcast to a component that does not
/// exist — so the notification is silently dropped. The same is true of an
/// action button: the plugin builds a `PendingIntent.getBroadcast` addressed to
/// `ActionBroadcastReceiver`, and the tap goes nowhere. Both defects survive
/// every unit test, every widget test and a successful build, which is why they
/// are asserted here against the manifest itself.
///
/// **Which manifest.** A manifest declaration cannot be exercised by a Flutter
/// test, so this file reads the source manifest, and — when a build has
/// produced one more recently than the source was last edited — the *merged*
/// manifest that the APK actually ships, which is the only artifact that proves
/// no library merge is quietly supplying (or removing) a component.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Reading the sources
// ---------------------------------------------------------------------------

/// `app/`, found by walking up from wherever the test runner started.
final Directory appDir = _findAppDir();

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

String appSource(String relative) =>
    File('${appDir.path}/$relative').readAsStringSync();

final File sourceManifestFile =
    File('${appDir.path}/android/app/src/main/AndroidManifest.xml');

/// Every merged `AndroidManifest.xml` the app module's own Gradle build has
/// left behind that is at least as new as the source manifest.
///
/// This is the manifest the APK ships — the one the manifest merger produced
/// out of the app's own file plus every linked library's, which is the only
/// artifact that proves no plugin is quietly supplying, renaming or removing a
/// component. Only the `app` module counts: each plugin has its own
/// `build/<plugin>/intermediates/...` tree, and `flutter_local_notifications`'
/// contribution to the merge is exactly two `<uses-permission>` lines.
///
/// A stale one is ignored rather than trusted: it describes a build that no
/// longer matches the sources, and failing on it would only say "you have not
/// rebuilt", which is not what this file is about. When no build has run at all
/// the source manifest stands alone.
List<File> mergedManifests() {
  final Directory intermediates =
      Directory('${appDir.path}/build/app/intermediates');
  if (!intermediates.existsSync()) return const <File>[];
  final DateTime sourceStamp = sourceManifestFile.lastModifiedSync();
  return intermediates
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((File f) =>
          f.path.endsWith('/AndroidManifest.xml') &&
          f.path.contains('merged_manifest') &&
          // outputDebugAppLinkSettings writes a stub with no <application>.
          !f.path.contains('AppLinkSettings') &&
          !f.lastModifiedSync().isBefore(sourceStamp))
      .toList();
}

/// XML comments stripped, so a rule about what the manifest *declares* cannot
/// be satisfied by prose that merely names the thing.
String withoutXmlComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

/// Every `<tag ...>` block of [xml], self-closing or not, with its children.
List<String> xmlBlocks(String xml, String tag) {
  final RegExp pattern = RegExp(
    '<$tag\\b[^>]*?/>|<$tag\\b[\\s\\S]*?</$tag>',
    multiLine: true,
  );
  return pattern.allMatches(xml).map((RegExpMatch m) => m.group(0)!).toList();
}

/// The `name="value"` attributes on the opening tag of [block].
Map<String, String> xmlAttributes(String block) {
  final int end = block.indexOf('>');
  final String head = end == -1 ? block : block.substring(0, end);
  return <String, String>{
    for (final RegExpMatch m
        in RegExp(r'([\w:]+)\s*=\s*"([^"]*)"').allMatches(head))
      m.group(1)!: m.group(2)!,
  };
}

/// The `<receiver>` declared as [className], or null.
String? receiverNamed(String manifestXml, String className) {
  for (final String block in xmlBlocks(withoutXmlComments(manifestXml), 'receiver')) {
    if (xmlAttributes(block)['android:name'] == className) return block;
  }
  return null;
}

const String pluginPackage = 'com.dexterous.flutterlocalnotifications';
const String scheduledReceiver = '$pluginPackage.ScheduledNotificationReceiver';
const String bootReceiver = '$pluginPackage.ScheduledNotificationBootReceiver';
const String actionReceiver = '$pluginPackage.ActionBroadcastReceiver';

/// The app's own boot receiver — see the
/// `audit12.boot-redelivers-an-elapsed-reminder` group.
const String appBootReceiver = 'org.isoron.uhabits.ReminderBootReceiver';

/// Runs [check] over the source manifest and over every fresh merged manifest,
/// naming which one failed.
void forEachManifest(void Function(String xml, String label) check) {
  check(sourceManifestFile.readAsStringSync(), 'the source manifest');
  for (final File merged in mergedManifests()) {
    check(merged.readAsStringSync(), 'the merged manifest ${merged.path}');
  }
}

void main() {
  // =======================================================================
  // audit5.android-reminders-never-fire-flutter-local
  // =======================================================================

  group('audit5.android-reminders-never-fire-flutter-local', () {
    const String rule =
        'audit5.android-reminders-never-fire-flutter-local#1 — In the Kotlin '
        'app: AlarmManager fires an explicit broadcast PendingIntent at '
        '.receivers.ReminderReceiver, which is declared in the manifest; '
        'ReminderController.onShowReminder posts the notification. Every habit '
        'reminder appears at its scheduled time.';

    test('#1 ScheduledNotificationReceiver is declared', () {
      forEachManifest((String xml, String label) {
        final String? receiver = receiverNamed(xml, scheduledReceiver);
        expect(receiver, isNotNull,
            reason: '$rule The port\'s equivalent of that manifest-declared '
                'ReminderReceiver is the plugin\'s '
                'ScheduledNotificationReceiver: it is the component '
                'AlarmManager broadcasts to at the scheduled instant, and the '
                'only thing that turns an armed alarm into a posted '
                'notification. flutter_local_notifications declares no '
                'receivers of its own since v16, so if the app does not '
                'declare it, the broadcast is delivered to nothing and no '
                'reminder is ever shown. Missing from $label.');
        expect(xmlAttributes(receiver!)['android:exported'], 'false',
            reason: '$rule The alarm is an explicit PendingIntent this app '
                'built for itself, so — unlike upstream\'s ReminderReceiver, '
                'which also answered BOOT_COMPLETED — nothing outside the app '
                'needs to reach it. In $label.');
      });
    });

    test('#1 it has no intent-filter, and does not steal the boot broadcast',
        () {
      forEachManifest((String xml, String label) {
        final String receiver = receiverNamed(xml, scheduledReceiver)!;
        expect(xmlBlocks(receiver, 'intent-filter'), isEmpty,
            reason: '$rule AlarmManager addresses the receiver by component '
                'name, so it declares no filter — the boot filter belongs to '
                'ScheduledNotificationBootReceiver alone. In $label.');
      });
    });

    test('#1 a boot receiver is still declared beside it', () {
      forEachManifest((String xml, String label) {
        expect(receiverNamed(xml, appBootReceiver), isNotNull,
            reason: '$rule Re-arming after a reboot and delivering at the '
                'scheduled instant are two different components; declaring '
                'only the boot one — which is what this manifest did — '
                're-arms alarms that can never be delivered. The boot one is '
                'the app\'s own ReminderBootReceiver, which filters the '
                'elapsed alarms out of the plugin\'s cache and then delegates '
                'to ScheduledNotificationBootReceiver by name '
                '(audit12.boot-redelivers-an-elapsed-reminder#1). In $label.');
      });
    });

    test('#1 the caller really does hand the alarm to the plugin', () {
      final String scheduler = appSource('lib/platform/flutter_alarm_scheduler.dart');
      expect(scheduler, contains('plugin.zonedSchedule('),
          reason: '$rule FlutterAlarmScheduler.scheduleExact is the port\'s '
              'IntentScheduler.scheduleShowReminder, and zonedSchedule is what '
              'sets the AlarmManager alarm whose broadcast the receiver above '
              'answers.');
      expect(scheduler, contains('AndroidScheduleMode.exactAllowWhileIdle'),
          reason: '$rule setExactAndAllowWhileIdle(RTC_WAKEUP, ...), as '
              'upstream.');
    });
  });

  // =======================================================================
  // audit5.reminder-yes-no-buttons-are-dead
  // =======================================================================

  group('audit5.reminder-yes-no-buttons-are-dead', () {
    const String rule = 'audit5.reminder-yes-no-buttons-are-dead#1 — In the '
        'Kotlin app: \'Yes\' and \'No\' are broadcast PendingIntents to '
        'WidgetReceiver, declared in the manifest; '
        'WidgetBehavior.onAddRepetition / onRemoveRepetition writes the entry '
        'and cancels the notification, whether or not the app process is '
        'alive.';

    test('#1 ActionBroadcastReceiver is declared', () {
      forEachManifest((String xml, String label) {
        final String? receiver = receiverNamed(xml, actionReceiver);
        expect(receiver, isNotNull,
            reason: '$rule An AndroidNotificationAction with '
                'showsUserInterface: false is posted as a '
                'PendingIntent.getBroadcast addressed to the plugin\'s '
                'ActionBroadcastReceiver — the port\'s stand-in for the '
                'manifest-declared WidgetReceiver. The plugin does not declare '
                'it (README: "To use notification actions, specify <receiver '
                'android:exported=\\"false\\" '
                'android:name=\\"com.dexterous.flutterlocalnotifications.'
                'ActionBroadcastReceiver\\" /> between the <application> '
                'tags"), so without this declaration tapping Yes or No does '
                'nothing at all — not even with the app in the foreground, '
                'because the tap never leaves the system. Missing from $label.');
        expect(xmlAttributes(receiver!)['android:exported'], 'false',
            reason: '$rule Only this app\'s own notification may drive it. '
                'That is also what closes the hole upstream left open with '
                'android:permission="false" on WidgetReceiver '
                '(intents.widget-receiver-dispatch#12). In $label.');
      });
    });

    test('#1 Yes and No are the actions that need it', () {
      final String tray = appSource('lib/platform/flutter_notification_tray.dart');
      expect(
        tray,
        contains('showsUserInterface: action.id == ReminderActions.edit ||'),
        reason: '$rule Only "Enter" and "Later" open UI; "Yes" and "No" are '
            'built with showsUserInterface: false, which is precisely the '
            'branch that makes the plugin route them through '
            'ActionBroadcastReceiver instead of through the activity.',
      );
      expect(tray, contains('onDidReceiveBackgroundNotificationResponse:'),
          reason: '$rule And the background entry point the receiver spins up '
              'an isolate for is registered, so the entry is written whether '
              'or not the app process was alive.');
    });
  });

  // =======================================================================
  // audit12.boot-redelivers-an-elapsed-reminder
  // =======================================================================

  group('audit12.boot-redelivers-an-elapsed-reminder', () {
    const String rule =
        'audit12.boot-redelivers-an-elapsed-reminder#1 — In the Kotlin app: '
        'Android discards every AlarmManager alarm across a reboot, and '
        "ReminderReceiver's BOOT_COMPLETED branch calls "
        'ReminderController.onBootCompleted() = reminderScheduler.'
        'scheduleAll(), which recomputes each alarm with DateUtils.'
        'getUpcomingTimeInMillis(hour, minute) — an instant that is in the '
        'future by construction — and IntentScheduler.schedule refuses '
        'anything with timestamp < now ("Ignoring attempt to schedule intent '
        'in the past"). A reminder whose instant passed while the phone was '
        'off is therefore never shown at all.';

    test("#1 the app's own receiver is what claims the boot broadcast", () {
      forEachManifest((String xml, String label) {
        // Only this app's own components and the notification plugin's: a
        // merged manifest also carries androidx.work's RescheduleReceiver,
        // which re-arms WorkManager's jobs and has nothing to do with alarms.
        final List<String> claimants = xmlBlocks(withoutXmlComments(xml), 'receiver')
            .where((String r) =>
                r.contains('android.intent.action.BOOT_COMPLETED'))
            .map((String r) => xmlAttributes(r)['android:name']!)
            .where((String n) =>
                n.startsWith(pluginPackage) || n.startsWith('org.isoron.uhabits'))
            .toList();
        expect(receiverNamed(xml, bootReceiver), isNull,
            reason: '$rule The plugin\'s own boot receiver is reached by '
                'name from ReminderBootReceiver and must not be declared: a '
                'declaration would hand it the boot broadcast directly, '
                'unfiltered, beside the app\'s. In $label.');
        expect(claimants, <String>[appBootReceiver],
            reason: '$rule The plugin\'s own '
                'ScheduledNotificationBootReceiver hands the whole cache '
                'straight back to AlarmManager: rescheduleNotifications() '
                'loops over every entry still stored (an entry leaves the '
                'cache only when it fires) and re-arms it with its ORIGINAL '
                'epochMilli through setupAlarm — no past-time filter exists '
                'anywhere on that path, and AlarmManager delivers an alarm '
                'whose time has passed immediately. The port therefore has to '
                'own the boot broadcast itself and drop the elapsed entries '
                'before delegating. In $label.');
        expect(xmlAttributes(receiverNamed(xml, appBootReceiver)!)['android:exported'],
            'true',
            reason: '$rule A receiver the system broadcasts to must be '
                'exported. In $label.');
      });
    });

    test('#1 and it drops the entries whose instant has already passed', () {
      final String source = appSource(
          'android/app/src/main/kotlin/org/isoron/uhabits/'
          'ReminderBootReceiver.kt');

      expect(source, contains('ScheduledNotificationBootReceiver()'),
          reason: '$rule Re-arming the alarms that have NOT elapsed is still '
              "the plugin's own pass; the app receiver filters the cache and "
              'then delegates to it, so a reboot still restores every '
              'reminder that is still due.');
      expect(source, contains('fireTime < now'),
          reason: '$rule The refusal is IntentScheduler.schedule\'s, '
              'strictly less-than: an alarm due exactly now is still armed. '
              'FlutterAlarmScheduler._schedule already spells the same rule, '
              'but it runs in Dart and no Dart runs at boot.');
      expect(source, contains('System.currentTimeMillis()'),
          reason: '$rule Compared against the wall clock the alarm was '
              'expressed in.');

      // The cache the filter reads has to be the one the plugin writes:
      // getSharedPreferences("scheduled_notifications").getString(
      // "scheduled_notifications", null).
      expect(
        RegExp(r'"scheduled_notifications"').allMatches(source).length,
        greaterThanOrEqualTo(1),
        reason: '$rule flutter_local_notifications stores the pending alarms '
            'as one JSON array under the SharedPreferences file and key '
            '"scheduled_notifications"; that is the only place a boot '
            'receiver can see what is about to be re-armed.',
      );
    });
  });

  // =======================================================================
  // Everything the app relies on the plugin for is declared exactly once
  // =======================================================================

  test('every plugin component the app relies on is declared, once each', () {
    const String rule =
        'audit5.android-reminders-never-fire-flutter-local#1 + '
        'audit5.reminder-yes-no-buttons-are-dead#1 — the plugin ships an '
        'AndroidManifest.xml with no <application> element at all, so every '
        'component it needs is the app\'s to declare. Its own example app '
        'declares ActionBroadcastReceiver, ScheduledNotificationReceiver and '
        'ScheduledNotificationBootReceiver; this app schedules notifications, '
        'restores them after a reboot and uses notification actions, so it '
        'needs all three roles. Two of them are the plugin\'s classes named in '
        'the manifest; the boot one is the app\'s own ReminderBootReceiver, '
        'which reaches the plugin\'s by name after filtering the elapsed '
        'alarms out of its cache '
        '(audit12.boot-redelivers-an-elapsed-reminder#1) — a class called '
        'directly needs no declaration, and declaring it would give the '
        'unfiltered pass the boot broadcast back.';

    forEachManifest((String xml, String label) {
      final List<String> declared = xmlBlocks(withoutXmlComments(xml), 'receiver')
          .map((String r) => xmlAttributes(r)['android:name']!)
          .where((String n) =>
              n.startsWith(pluginPackage) || n == appBootReceiver)
          .toList();
      expect(
        declared..sort(),
        <String>[actionReceiver, appBootReceiver, scheduledReceiver]..sort(),
        reason: '$rule In $label.',
      );
    });
  });
}
