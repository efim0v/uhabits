/// `audit8.reminder-notification-action-buttons-are-built`.
///
/// `AndroidNotificationTray.buildNotification()` gives every reminder button an
/// icon:
///
/// ```kotlin
/// val addRepetitionAction = Action(R.drawable.ic_action_check,  getString(R.string.yes),    …)
/// val removeRepetitionAction = Action(R.drawable.ic_action_cancel, getString(R.string.no),  …)
/// val enterAction = Action(R.drawable.ic_action_check,  getString(R.string.enter),          …)
/// val snoozeAction = Action(R.drawable.ic_action_snooze, getString(R.string.snooze),        …)
/// ```
///
/// Those icons are the first argument of `NotificationCompat.Action`, which has
/// no icon-less overload, and they are what the `WearableExtender` in the same
/// method exists to feed: Wear OS, Android Auto and Android 6 and below draw
/// the action as its icon. `notifications.actions#1`–`#3` name all three, and
/// the port built its buttons with none.
library;

// The core package does not export lib/src/preferences yet.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/flutter_notification_tray.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/time/local_date.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const NotificationStrings strings = NotificationStrings(
    yes: 'Yes',
    no: 'No',
    enter: 'Enter',
    snooze: 'Later',
    defaultReminderQuestion: 'Have you completed this habit today?',
    channelName: 'Reminder',
  );

  ReminderNotificationBuilder builder() => ReminderNotificationBuilder(
        preferences: Preferences(MemoryStorage()),
        strings: () => strings,
      );

  Habit habitOf(HabitType type) {
    final habit = MemoryModelFactory().buildHabit()
      ..name = 'Meditate'
      ..type = type
      ..id = 10;
    return habit;
  }

  NotificationSpec specOf(HabitType type) => builder().build(
        habitOf(type),
        10,
        LocalDate.ymd(2015, 1, 26),
        0,
      );

  /// The action's icon as the plugin will serialise it: the drawable resource
  /// name, or null when the button carries no icon at all.
  String? androidIconOf(NotificationSpec spec, String actionId) {
    final presenter = LocalNotificationsPresenter(
      plugin: FlutterLocalNotificationsPlugin(),
      builder: builder(),
    );
    final action = presenter
        .detailsFor(spec)
        .android!
        .actions!
        .firstWhere((a) => a.id == actionId);
    final icon = action.icon;
    if (icon == null) return null;
    expect(
      icon,
      isA<DrawableResourceAndroidBitmap>(),
      reason: 'audit8.reminder-notification-action-buttons-are-built#1 — an '
          'action icon is R.drawable.<name>, which the plugin takes as a '
          'drawable resource rather than a bitmap file or an asset',
    );
    return icon.data as String;
  }

  group('audit8.reminder-notification-action-buttons-are-built', () {
    test('#1 "Yes" and "No" carry ic_action_check and ic_action_cancel', () {
      final spec = specOf(HabitType.yesNo);
      final icons = {
        for (final action in spec.actions) action.id: action.icon,
      };

      expect(
        icons[ReminderActions.addRepetition],
        'ic_action_check',
        reason: 'audit8.reminder-notification-action-buttons-are-built#1 — '
            'Action(R.drawable.ic_action_check, getString(R.string.yes), …): a '
            'check for "Yes" (notifications.actions#2)',
      );
      expect(
        icons[ReminderActions.removeRepetition],
        'ic_action_cancel',
        reason: 'audit8.reminder-notification-action-buttons-are-built#1 — '
            'Action(R.drawable.ic_action_cancel, getString(R.string.no), …): a '
            'cross for "No" (notifications.actions#2)',
      );
    });

    test('#1 "Enter" carries the same check icon as "Yes"', () {
      final spec = specOf(HabitType.numerical);
      final enter =
          spec.actions.firstWhere((a) => a.id == ReminderActions.edit);

      expect(
        enter.icon,
        'ic_action_check',
        reason: 'audit8.reminder-notification-action-buttons-are-built#1 — '
            'Action(R.drawable.ic_action_check, getString(R.string.enter), …): '
            'a check for "Enter" too (notifications.actions#1)',
      );
    });

    test('#1 "Later" carries the clock icon', () {
      final spec = specOf(HabitType.yesNo);
      final snooze = spec.actions
          .firstWhere((a) => a.id == ReminderActions.snoozeReminder);

      expect(
        snooze.icon,
        'ic_action_snooze',
        reason: 'audit8.reminder-notification-action-buttons-are-built#1 — '
            'Action(R.drawable.ic_action_snooze, getString(R.string.snooze), '
            '…): a clock for "Later" (notifications.actions#3)',
      );
    });

    test('#1 every button on every habit kind names an icon', () {
      for (final type in <HabitType>[HabitType.yesNo, HabitType.numerical]) {
        for (final action in specOf(type).actions) {
          expect(
            action.icon,
            isNotEmpty,
            reason: 'audit8.reminder-notification-action-buttons-are-built#1 — '
                'NotificationCompat.Action has no icon-less constructor, so '
                'no reminder button upstream can be built without one',
          );
        }
      }
    });

    test('#1 the icons reach the plugin as drawable resources', () {
      final yesNo = specOf(HabitType.yesNo);
      expect(
        androidIconOf(yesNo, ReminderActions.addRepetition),
        'ic_action_check',
        reason: 'audit8.reminder-notification-action-buttons-are-built#1 — an '
            'icon named on the spec but dropped in detailsFor never reaches '
            'the platform, which is the defect this rule describes',
      );
      expect(
        androidIconOf(yesNo, ReminderActions.removeRepetition),
        'ic_action_cancel',
        reason: 'audit8.reminder-notification-action-buttons-are-built#1',
      );
      expect(
        androidIconOf(yesNo, ReminderActions.snoozeReminder),
        'ic_action_snooze',
        reason: 'audit8.reminder-notification-action-buttons-are-built#1',
      );
      expect(
        androidIconOf(specOf(HabitType.numerical), ReminderActions.edit),
        'ic_action_check',
        reason: 'audit8.reminder-notification-action-buttons-are-built#1',
      );
    });

    test('#1 the three drawables exist in the app resources', () {
      for (final name in <String>[
        'ic_action_check',
        'ic_action_cancel',
        'ic_action_snooze',
      ]) {
        final file = File('${_androidMain().path}/res/drawable/$name.xml');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'audit8.reminder-notification-action-buttons-are-built#1 — '
              'the plugin resolves an action icon by name out of the app\'s '
              'own resources, so a name Android cannot resolve is a button '
              'drawn without an icon, exactly as before the fix',
        );
        final drawable = file.readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
        expect(
          drawable,
          contains('<vector'),
          reason: 'audit8.reminder-notification-action-buttons-are-built#1 — '
              'all three are the vector drawables of the Android build',
        );
        expect(
          drawable,
          contains('android:fillColor="@android:color/white"'),
          reason: 'audit8.reminder-notification-action-buttons-are-built#1 — '
              'an action icon is drawn as a silhouette, which is why the '
              'upstream assets are pure white',
        );
      }
    });
  });
}

/// `android/app/src/main`, found by walking up from the working directory so
/// this file works whether `flutter test` runs from `app/` or from the
/// repository root — the same walk test/platform/reminders_platform_test.dart
/// makes.
Directory _androidMain() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    final Directory candidate = Directory('${dir.path}/android/app/src/main');
    if (File('${candidate.path}/AndroidManifest.xml').existsSync()) {
      return candidate;
    }
    final Directory app = Directory('${dir.path}/app/android/app/src/main');
    if (File('${app.path}/AndroidManifest.xml').existsSync()) return app;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError(
    'android/app/src/main not found from ${Directory.current.path}',
  );
}
