/// What the Android build declares, and what became of the parts it cannot.
///
/// Upstream's `AndroidManifest.xml` names 21 components: 8 activities, an
/// activity-alias, 3 widget-configuration dialogs, 6 widget providers, a
/// service, 3 receivers and a `FileProvider`. A Flutter app has one activity
/// for the whole process, so most of that list does not become a manifest entry
/// here — it becomes a route, a dialog or a Dart object. Two things are worth
/// pinning anyway:
///
///  * the entries that *are* still native, because a widget provider or a boot
///    receiver that is not declared simply never runs, and nothing else in the
///    test suite would notice;
///  * the component *names*, because they are persisted. A home-screen shortcut
///    stores `org.isoron.uhabits/.MainActivity`; a placed widget stores its
///    provider's class name; an existing `PendingIntent` stores the action
///    string it was built with. Renaming any of them breaks an installed app on
///    update, and no compiler warns about it.
///
/// The widget providers and the three picker dialogs of rules 6 and 7 are
/// asserted in test/platform/android_widgets_test.dart, where the rest of the
/// widget registration lives; everything else is here.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/intent_router.dart';
import 'package:uhabits/state/widget_link.dart' show WidgetLink;
import 'package:uhabits/ui/about/about_screen.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits/ui/intro/intro_screen.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';

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

final String manifest =
    appSource('android/app/src/main/AndroidManifest.xml');

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

/// The `android:name` of every `<action>` inside [block].
List<String> actionsOf(String block) => xmlBlocks(block, 'action')
    .map((String a) => xmlAttributes(a)['android:name']!)
    .toList();

void main() {
  late String body;
  late List<String> activities;
  late List<String> receivers;

  setUp(() {
    body = withoutXmlComments(manifest);
    activities = xmlBlocks(body, 'activity');
    receivers = xmlBlocks(body, 'receiver');
  });

  /// The `<receiver>` blocks that are app-widget providers.
  List<String> widgetProviders() => receivers
      .where((String r) => xmlBlocks(r, 'meta-data').any((String m) =>
          xmlAttributes(m)['android:name'] == 'android.appwidget.provider'))
      .toList();

  /// Everything else — upstream's ReminderReceiver, WidgetReceiver and
  /// FireSettingReceiver sat in this bucket.
  List<String> plainReceivers() =>
      receivers.where((String r) => !widgetProviders().contains(r)).toList();

  // =======================================================================
  // platform-glue.manifest-components
  // =======================================================================

  group('platform-glue.manifest-components', () {
    test('#1 the application element', () {
      final Map<String, String> app =
          xmlAttributes(xmlBlocks(body, 'application').single);
      const String rule = 'platform-glue.manifest-components#1 — The '
          'application element declares android:name=".HabitsApplication", '
          'android:allowBackup="true", android:backupAgent=".HabitsBackupAgent"'
          ', android:icon="@mipmap/ic_launcher", '
          'android:label="@string/main_activity_title" ("Habits"), '
          'android:localeConfig="@xml/locales_config", '
          'android:supportsRtl="true", android:theme="@style/AppBaseTheme".';

      expect(app['android:name'], r'${applicationName}',
          reason: '$rule .HabitsApplication becomes the Flutter embedding\'s '
              'Application class: everything HabitsApplication.onCreate did is '
              'AppScope.boot(), which runs in Dart and cannot be an '
              'Application subclass.');
      expect(app['android:label'], '@string/main_activity_title',
          reason: '$rule The launcher label is "Habits", not the store name.');
      expect(app['android:icon'], '@mipmap/ic_launcher', reason: rule);
      expect(app['android:allowBackup'], 'true', reason: rule);
      expect(app['android:supportsRtl'], 'true',
          reason: '$rule Still needed with a Flutter UI: the widget '
              'RemoteViews layouts and the three picker dialogs are real '
              'Android views, and only this flag mirrors them.');

      // The theme moved to the activity, which is where the Flutter embedding
      // reads LaunchTheme and NormalTheme.
      expect(app.containsKey('android:theme'), isFalse, reason: rule);
      expect(
        xmlAttributes(activities.first)['android:theme'],
        '@style/LaunchTheme',
        reason: '$rule The window background before any Dart runs is the '
            "activity's theme here.",
      );

      // The one that is deliberately gone.
      expect(app.containsKey('android:backupAgent'), isFalse,
          reason: '$rule There is no BackupAgentHelper to name — see the '
              'ledger note on platform-glue.backup-agent. allowBackup on its '
              'own still gives Auto Backup.');

      // This assertion used to read `isFalse`, on the reading that
      // MaterialApp.supportedLocales replaced the attribute. It does not:
      // supportedLocales decides which translation the app picks once Android
      // has told it what the locale is, while this attribute is the only thing
      // that makes Android *offer* the choice — and
      // platform-glue.locale-config#10 records that there is deliberately no
      // in-app language row, so the system picker is the only way to change the
      // app's language at all. See
      // `audit4.android-localeconfig-is-dropped-so-the#1` and
      // app/test/platform/locale_config_test.dart, which owns the list.
      expect(app['android:localeConfig'], '@xml/locales_config',
          reason: '$rule The per-app locale list is declared, as upstream.');
    });

    test('#2 exactly one launcher entry, and it is still .MainActivity', () {
      final List<String> launchers = activities
          .where((String a) => actionsOf(a).contains('android.intent.action.MAIN'))
          .toList();
      const String rule = 'platform-glue.manifest-components#2 — There is '
          'exactly one launcher entry point, and it is an <activity-alias> '
          'named ".MainActivity" with targetActivity='
          '".activities.habits.list.ListHabitsActivity", exported=true, '
          'launchMode="singleTop", label="@string/main_activity_title", whose '
          'intent-filter is action android.intent.action.MAIN + category '
          'android.intent.category.LAUNCHER. ListHabitsActivity itself is '
          'declared separately (exported=true, launchMode="singleTop") with NO '
          'launcher intent-filter. The alias exists upstream so that the '
          'launcher component name survives the activity being moved; here '
          'there is only one activity, so it *is* .MainActivity — the same '
          'persisted component name, which is what an existing home-screen '
          'shortcut holds.';

      expect(launchers, hasLength(1), reason: rule);
      final Map<String, String> main = xmlAttributes(launchers.single);
      expect(main['android:name'], '.MainActivity', reason: rule);
      expect(main['android:exported'], 'true', reason: rule);
      expect(main['android:launchMode'], 'singleTop',
          reason: '$rule singleTop is what makes a second widget tap reuse the '
              'running instance instead of stacking a new one '
              '(platform-glue.deep-link-edit-entry#5).');
      expect(main['android:label'], '@string/main_activity_title',
          reason: rule);
      expect(
        xmlBlocks(launchers.single, 'category')
            .map((String c) => xmlAttributes(c)['android:name'])
            .toList(),
        contains('android.intent.category.LAUNCHER'),
        reason: rule,
      );
      expect(xmlBlocks(body, 'activity-alias'), isEmpty,
          reason: '$rule With one activity there is nothing to alias.');
      expect(body, isNot(contains('ListHabitsActivity')),
          reason: '$rule The habit list is a route, not an activity.');
    });

    test('#3 the eight activities became routes; four native ones remain', () {
      const String rule = 'platform-glue.manifest-components#3 — Exactly 8 '
          'activities are declared: EditHabitActivity, ListHabitsActivity, '
          'ShowHabitActivity, SettingsActivity, IntroActivity, AboutActivity, '
          'SnoozeDelayPickerActivity, and automation/EditSettingActivity. Plus '
          '3 widget-configuration dialog activities. Seven of the eight are '
          'Flutter routes here; the eighth (Tasker) was dropped by owner '
          'decision, as platform-glue.tasker-edit-setting-screen records. The '
          'manifest therefore declares four activities: the single Flutter one '
          'and the three pickers, which have to stay native because the '
          'launcher starts them for APPWIDGET_CONFIGURE before any Dart runs.';

      expect(
        activities.map((String a) => xmlAttributes(a)['android:name']).toList(),
        <String>[
          '.MainActivity',
          '.widgets.activities.HabitPickerDialog',
          '.widgets.activities.BooleanHabitPickerDialog',
          '.widgets.activities.NumericalHabitPickerDialog',
        ],
        reason: rule,
      );

      // The seven that became widgets. Naming the types here is what makes a
      // rename break this test rather than silently drop a screen.
      expect(
        <Type>[
          EditHabitScreen,
          HabitListScreen,
          ShowHabitScreen,
          SettingsScreen,
          IntroScreen,
          AboutScreen,
        ],
        everyElement(isNotNull),
        reason: '$rule Six of the seven are these.',
      );
      expect(
        appSource('lib/ui/common/dialogs/snooze_picker_dialog.dart'),
        contains('Future<SnoozeChoice?> showSnoozePickerDialog('),
        reason: '$rule And the seventh, SnoozeDelayPickerActivity, is a '
            'dialog — see #5.',
      );
      expect(Directory('${appDir.path}/lib/ui/automation').existsSync(), isFalse,
          reason: '$rule The Tasker edit screen has no counterpart at all.');
    });

    test('#4 Up from every pushed screen lands on the habit list', () {
      const String rule = 'platform-glue.manifest-components#4 — '
          'EditHabitActivity, ShowHabitActivity, SettingsActivity and '
          'AboutActivity each declare meta-data android.support.PARENT_ACTIVITY '
          '= ".activities.habits.list.ListHabitsActivity", i.e. their Up button '
          'returns to the habit list. A Navigator has no PARENT_ACTIVITY: the '
          'parent of a route is whatever it was pushed onto, so the four are '
          'pushed from the habit list and Back/Up pops straight back to it. '
          'The manifest consequently declares no such meta-data.';

      expect(body, isNot(contains('android.support.PARENT_ACTIVITY')),
          reason: rule);

      final String list = appSource('lib/ui/habits/list/habit_list_screen.dart');
      // Settings and About are pushed inline; Edit and Show through their own
      // `open`, which pushes too.
      expect(list, contains('Navigator.of(context).push'), reason: rule);
      expect(list, contains('SettingsScreen('), reason: rule);
      expect(list, contains('AboutScreen('), reason: rule);
      expect(list, contains('ShowHabitScreen.open(context, habit)'),
          reason: rule);
      expect(list, contains('EditHabitScreen.'), reason: rule);

      for (final String screen in <String>[
        'lib/ui/habits/edit/edit_habit_screen.dart',
        'lib/ui/habits/show/show_habit_screen.dart',
      ]) {
        expect(appSource(screen), contains('Navigator.of(context).push'),
            reason: '$rule $screen pushes rather than replaces, so the list '
                'stays underneath.');
      }
    });

    test('#5 the snooze picker is a dialog, not a translucent activity', () {
      const String rule = 'platform-glue.manifest-components#5 — '
          'SnoozeDelayPickerActivity is declared with '
          'android:excludeFromRecents="true", '
          'android:launchMode="singleInstance", android:taskAffinity="" and '
          'android:theme="@android:style/Theme.Translucent.NoTitleBar": it must '
          'appear as a transparent overlay outside the app task and never show '
          'in Recents. A showDialog route has all four properties by '
          'construction — it paints over whatever is behind it, it is not a '
          'task, and it cannot appear in Recents — so the port has the '
          'behaviour without the declaration. What is genuinely lost is the '
          'lock-screen case: upstream that activity could be raised over the '
          'keyguard from a notification action, and a dialog inside the app '
          'cannot be.';

      expect(body, isNot(contains('SnoozeDelayPicker')), reason: rule);
      expect(body, isNot(contains('excludeFromRecents')), reason: rule);
      expect(body, isNot(contains('singleInstance')), reason: rule);

      final String picker =
          appSource('lib/ui/common/dialogs/snooze_picker_dialog.dart');
      expect(picker, contains('showDialog<SnoozeChoice>('), reason: rule);
    });

    test('#8 StackWidgetService is declared, unexported and permission-gated',
        () {
      final List<String> services = xmlBlocks(body, 'service');
      const String rule = 'platform-glue.manifest-components#8 — One service '
          'is declared: .widgets.StackWidgetService with '
          'android:exported="false" and '
          'android:permission="android.permission.BIND_REMOTEVIEWS".';

      expect(services, hasLength(1), reason: rule);
      final Map<String, String> service = xmlAttributes(services.single);
      expect(service['android:name'], '.widgets.StackWidgetService',
          reason: rule);
      expect(service['android:exported'], 'false', reason: rule);
      expect(service['android:permission'],
          'android.permission.BIND_REMOTEVIEWS',
          reason: '$rule Only the system may bind a RemoteViewsService.');
    });

    test('#9 one non-widget receiver, exported, with a boot filter — and no '
        'android:permission="false" anywhere', () {
      final List<String> plain = plainReceivers();
      const String rule = 'platform-glue.manifest-components#9 — Three '
          'non-widget receivers are declared: .receivers.ReminderReceiver '
          '(exported=true, intent-filter android.intent.action.BOOT_COMPLETED), '
          '.receivers.WidgetReceiver (exported=true, android:permission="false" '
          '— a literal string, not a real permission, so the receiver is '
          'effectively unprotected), and .automation.FireSettingReceiver '
          '(exported=true, intent-filter '
          'com.twofortyfouram.locale.intent.action.FIRE_SETTING). Only the '
          'first has a counterpart: WidgetReceiver is replaced by deep links '
          'into the one activity (intents.widget-receiver-dispatch#12) and the '
          'Tasker receiver was dropped with the rest of the plugin.';

      expect(plain, hasLength(1), reason: rule);
      final Map<String, String> boot = xmlAttributes(plain.single);
      expect(
        boot['android:name'],
        'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver',
        reason: '$rule The reschedule-after-reboot pass is the plugin\'s here, '
            'because an alarm in this port *is* the finished notification.',
      );
      expect(boot['android:exported'], 'true',
          reason: '$rule A receiver the system broadcasts to must be '
              'exported.');
      expect(actionsOf(plain.single),
          contains('android.intent.action.BOOT_COMPLETED'), reason: rule);

      expect(body, isNot(contains('FireSettingReceiver')), reason: rule);
      expect(body, isNot(contains('android:permission="false"')),
          reason: '$rule The ledger calls that a latent bug worth NOT '
              'reproducing, and nothing here needs an unprotected receiver.');
    });

    test('#10 no FileProvider of our own on the org.isoron.uhabits authority',
        () {
      const String rule = 'platform-glue.manifest-components#10 — A '
          'FileProvider (androidx.core.content.FileProvider) is declared with '
          'android:authorities="org.isoron.uhabits", exported=false, '
          'grantUriPermissions=true and meta-data '
          'android.support.FILE_PROVIDER_PATHS = @xml/file_paths. The port '
          'shares files through share_plus, which merges in its own '
          'FileProvider on the authority '
          '"<applicationId>.flutter.share_provider"; declaring a second one on '
          'the bare application id would be a duplicate-authority install '
          'failure the moment both were present, and nothing in this port '
          'hands out a content:// uri of its own.';

      expect(xmlBlocks(body, 'provider'), isEmpty, reason: rule);
      expect(appSource('pubspec.yaml'), contains('share_plus:'), reason: rule);
    });

    test('#11 no Android Backup Service api key', () {
      final List<String> appMeta = xmlBlocks(
        xmlBlocks(body, 'application').single,
        'meta-data',
      );
      const String rule = 'platform-glue.manifest-components#11 — An '
          'application-level meta-data com.google.android.backup.api_key with '
          'value "AEdPqrEAAAAI6aeWncbnMNo8E5GWeZ44dlc5cQ7tCROwFhOtiw" is '
          'declared for Android Backup Service. That key identifies a '
          'registered key/value backup agent, and the port has no agent to '
          'register (#1: no android:backupAgent); android:allowBackup="true" '
          'alone selects Auto Backup, which needs no key.';

      expect(
        appMeta
            .map((String m) => xmlAttributes(m)['android:name'])
            .where((String? n) => n != null && n.contains('backup')),
        isEmpty,
        reason: rule,
      );
      expect(body, isNot(contains('AEdPqrEAAAAI6aeWncbnMNo8E5GWeZ44dlc5cQ7tCROwFhOtiw')),
          reason: rule);
    });
  });

  // =======================================================================
  // The exported intent filters, and what replaced them
  // =======================================================================

  group('intents.actions-and-extras', () {
    test('#15 the boot receiver is exported and answers BOOT_COMPLETED', () {
      final String boot = plainReceivers().single;
      const String rule = 'intents.actions-and-extras#15 — The manifest '
          'exports ReminderReceiver with an intent-filter for '
          'android.intent.action.BOOT_COMPLETED only. The port\'s boot '
          'receiver is the notification plugin\'s, and it answers three more '
          'actions than upstream did — MY_PACKAGE_REPLACED and the two '
          'QUICKBOOT_POWERON variants — because the alarms it re-arms are lost '
          'on an app update as well as on a reboot. BOOT_COMPLETED is still '
          'the one the rule is about, and it is still the only one declared '
          'anywhere in this manifest.';

      expect(xmlAttributes(boot)['android:exported'], 'true', reason: rule);
      expect(actionsOf(boot).first, 'android.intent.action.BOOT_COMPLETED',
          reason: '$rule and it is the first action of the filter');
      expect(
        actionsOf(boot).toSet(),
        <String>{
          'android.intent.action.BOOT_COMPLETED',
          'android.intent.action.MY_PACKAGE_REPLACED',
          'android.intent.action.QUICKBOOT_POWERON',
          'com.htc.intent.action.QUICKBOOT_POWERON',
        },
        reason: rule,
      );
      expect(
        receivers
            .where((String r) => actionsOf(r)
                .contains('android.intent.action.BOOT_COMPLETED'))
            .length,
        1,
        reason: '$rule Exactly one receiver claims the boot broadcast.',
      );
    });

    test('#16 the four WidgetReceiver filters became one deep-link contract',
        () {
      const String rule = 'intents.actions-and-extras#16 — The manifest '
          'exports WidgetReceiver with intent-filters for '
          'org.isoron.uhabits.ACTION_SET_NUMERICAL_VALUE, '
          'ACTION_TOGGLE_REPETITION, ACTION_ADD_REPETITION and '
          'ACTION_REMOVE_REPETITION, each with category DEFAULT and data scheme '
          '"content", host "org.isoron.uhabits". ACTION_SET_NUMERICAL_VALUE is '
          'declared in the manifest but has no matching branch in '
          'WidgetReceiver.onReceive (dead filter). None of the four is an '
          'exported filter here: a broadcast cannot run Dart, so every widget '
          'PendingIntent names MainActivity explicitly and carries its '
          'arguments in a uhabits://widget/... uri instead. The action strings '
          'survive as the receiver\'s contract, in declaration order.';

      expect(
        WidgetActions.exported,
        <String>[
          'org.isoron.uhabits.ACTION_SET_NUMERICAL_VALUE',
          'org.isoron.uhabits.ACTION_TOGGLE_REPETITION',
          'org.isoron.uhabits.ACTION_ADD_REPETITION',
          'org.isoron.uhabits.ACTION_REMOVE_REPETITION',
        ],
        reason: rule,
      );
      expect(WidgetActions.dispatched.contains(WidgetActions.setNumericalValue),
          isFalse,
          reason: '$rule The first of the four is the dead one.');
      expect(body, isNot(contains('org.isoron.uhabits.ACTION_')),
          reason: '$rule Nothing in this manifest advertises them to other '
              'apps.');

      final String intents = appSource(
          'android/app/src/main/kotlin/org/isoron/uhabits/widgets/'
          'WidgetIntents.kt');
      expect(intents, contains('const val SCHEME = "uhabits"'), reason: rule);
      expect(intents, contains('const val AUTHORITY = "widget"'), reason: rule);
      expect(intents, contains('MainActivity::class.java'),
          reason: '$rule The component is named, so no filter is needed.');
    });
  });

  group('intents.widget-receiver-dispatch', () {
    test('#12 nothing is exported in WidgetReceiver\'s place', () {
      const String rule = 'intents.widget-receiver-dispatch#12 — The receiver '
          'is exported and declares intent filters (category DEFAULT, scheme '
          "'content', host 'org.isoron.uhabits') for "
          'ACTION_SET_NUMERICAL_VALUE, ACTION_TOGGLE_REPETITION, '
          'ACTION_ADD_REPETITION and ACTION_REMOVE_REPETITION. The port has no '
          'WidgetReceiver component at all: the dispatch lives in Dart '
          '(WidgetIntentReceiver) and is reached only through PendingIntents '
          'this app built for its own MainActivity. That closes the hole '
          'android:permission="false" left open — no other app can drive it — '
          'at the cost of the widget having to foreground the app to act.';

      expect(body, isNot(contains('WidgetReceiver')), reason: rule);
      expect(
        plainReceivers()
            .where((String r) => xmlAttributes(r)['android:exported'] == 'true')
            .length,
        1,
        reason: '$rule The boot receiver is the only exported non-widget '
            'receiver left.',
      );
      // What answers those four actions now.
      expect(WidgetIntentReceiver.tag, 'WidgetReceiver',
          reason: '$rule The Dart object keeps the log tag, so a bug report '
              'from either build reads the same.');
    });
  });

  // =======================================================================
  // platform-glue.habit-content-uri
  // =======================================================================

  group('platform-glue.habit-content-uri', () {
    test('#3 the scheme/host pair the filters matched is still what a habit '
        'uri is', () {
      const String rule = 'platform-glue.habit-content-uri#3 — The manifest '
          'intent-filters for WidgetReceiver match data with '
          'android:scheme="content" and android:host="org.isoron.uhabits" (no '
          'path restriction) plus category android.intent.category.DEFAULT. '
          'The filters are gone with the receiver, but the uri they matched is '
          'not: it is still how every habit-carrying intent names its habit, '
          'and still what IntentParser resolves.';

      final Uri uri = habitUri(7);
      expect(uri.scheme, 'content', reason: rule);
      expect(uri.host, 'org.isoron.uhabits', reason: rule);
      expect('$uri', 'content://org.isoron.uhabits/habit/7', reason: rule);
      expect(parseContentUriId(uri), 7,
          reason: '$rule No path restriction: the id is simply the last '
              'segment.');
      // And the replacement contract is a different scheme and host, which is
      // what keeps the two from ever matching each other.
      expect(WidgetLink.scheme, 'uhabits', reason: rule);
      expect(WidgetLink.authority, 'widget', reason: rule);
    });

    test('#4 four actions, one per filter, and the port still knows all four',
        () {
      const String rule = 'platform-glue.habit-content-uri#4 — There are '
          'exactly 4 externally-matchable data intent-filters on '
          'WidgetReceiver, one per action: '
          'org.isoron.uhabits.ACTION_SET_NUMERICAL_VALUE, '
          'ACTION_TOGGLE_REPETITION, ACTION_ADD_REPETITION, '
          'ACTION_REMOVE_REPETITION. Externally matchable is exactly what the '
          'port dropped — see intents.widget-receiver-dispatch#12 — so what is '
          'checked here is that the four action strings, and only those four, '
          'are still the ones the app addresses itself with.';

      expect(WidgetActions.exported, hasLength(4), reason: rule);
      expect(WidgetActions.exported.toSet(), hasLength(4),
          reason: '$rule One filter per action, no repeats.');
      for (final String action in WidgetActions.exported) {
        expect(action, startsWith('org.isoron.uhabits.ACTION_'), reason: rule);
      }
      // The three live ones are a subset of what the receiver dispatches; the
      // fourth is not.
      expect(
        WidgetActions.exported
            .where(WidgetActions.dispatched.contains)
            .toList(),
        <String>[
          WidgetActions.toggleRepetition,
          WidgetActions.addRepetition,
          WidgetActions.removeRepetition,
        ],
        reason: rule,
      );
    });
  });
}
