/// Domain: Verification audit — what a reminder notification actually does.
///
/// Everything below is driven the way the platform drives it: the app's own
/// startup runs (`AppScope.startPlatformServices`, which is what
/// `AppScope.boot` calls before `runApp`), the real
/// `flutter_local_notifications` plugin is behind a mocked method channel, and
/// a user's tap arrives as the exact `didReceiveNotificationResponse` method
/// call the Android and Darwin sides send. Nothing here constructs a
/// `ReminderIntentReceiver`, a `ReminderController` or a
/// `LocalNotificationsPresenter`: a test that builds the object under test
/// proves the class works and says nothing about whether the app ever builds
/// it, which is the whole subject of these four findings.
///
/// Covered:
///
///  * `verify.notifications-never-initialised` — the plugin is initialised at
///    startup, with the small icon, the iOS categories and both response
///    callbacks;
///  * `verify.notification-actions-unrouted` — the body tap and the four
///    buttons reach the ported receivers;
///  * `verify.sticky-dismiss-unrouted` — a reminder that left the shade
///    reaches `ReminderController.onDismiss`;
///  * `verify.snooze-picker-uncalled` — "Later" opens the snooze picker and
///    the choice reaches `ReminderController.onSnoozeDelayPicked`;
///  * `audit10.platform-services-start-on-every-device-language` — the whole
///    startup survives a device language the app does not translate.
library;

// The core's preferences and models are reached by their `src` path, exactly
// as lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/main.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/flutter_notification_tray.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/reminder_link.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/common/dialogs/snooze_picker_dialog.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// The channel `flutter_local_notifications` talks over, in both directions:
/// the app calls `initialize`/`show`/`cancel` down it, and the platform calls
/// `didReceiveNotificationResponse` back up it.
const String notificationsChannel = 'dexterous.com/flutter/local_notifications';

/// The channel the `home_widget` plugin uses. Mocked only so that the widget
/// publisher `startPlatformServices` also builds does not fail the test with a
/// `MissingPluginException` from a background task.
const String homeWidgetChannel = 'home_widget';

/// A stand-in for the native side of the notification plugin.
class _PluginHost {
  final List<MethodCall> calls = <MethodCall>[];

  /// What `getNotificationAppLaunchDetails` answers — i.e. whether a
  /// notification is what started this process.
  Map<Object?, Object?> launchDetails = <Object?, Object?>{
    'notificationLaunchedApp': false,
  };

  /// What `getActiveNotifications` answers — i.e. what is really in the shade.
  List<Map<Object?, Object?>> active = <Map<Object?, Object?>>[];

  void install() {
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel(notificationsChannel),
      (MethodCall call) async {
        calls.add(call);
        switch (call.method) {
          case 'getNotificationAppLaunchDetails':
            return launchDetails;
          case 'getActiveNotifications':
            return active;
          case 'areNotificationsEnabled':
          case 'requestNotificationsPermission':
          case 'canScheduleExactNotifications':
          case 'requestExactAlarmsPermission':
          case 'initialize':
            return true;
          default:
            return null;
        }
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel(homeWidgetChannel),
      (MethodCall call) async => null,
    );
  }

  void remove() {
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel(notificationsChannel), null);
    messenger.setMockMethodCallHandler(
        const MethodChannel(homeWidgetChannel), null);
  }

  List<MethodCall> callsNamed(String method) =>
      calls.where((MethodCall call) => call.method == method).toList();

  /// The notification ids `cancel` was called with. The Android side of the
  /// plugin sends `{'id': …, 'tag': …}`.
  List<Object?> get cancelledIds => callsNamed('cancel')
      .map((MethodCall call) => call.arguments is Map
          ? (call.arguments as Map<Object?, Object?>)['id']
          : call.arguments)
      .toList();

  MethodCall? lastCallNamed(String method) {
    final List<MethodCall> matching = callsNamed(method);
    return matching.isEmpty ? null : matching.last;
  }

  /// The message the platform sends when the user touches a notification.
  ///
  /// This is `FlutterLocalNotificationsPlugin`'s own inbound method call, so
  /// it only reaches Dart if the app has registered a response callback with
  /// `initialize` — which is exactly what `verify.notifications-never-
  /// initialised#2(c)` says it never does.
  Future<void> deliverResponse({
    required int notificationId,
    required String payload,
    String? actionId,
  }) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      notificationsChannel,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('didReceiveNotificationResponse', <String, Object?>{
          'notificationId': notificationId,
          'actionId': actionId,
          'input': null,
          'payload': payload,
          'notificationResponseType': actionId == null ? 0 : 1,
        }),
      ),
      (ByteData? _) {},
    );
  }
}

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _PluginHost plugin;
  final List<AppScope> scopes = <AppScope>[];
  int nextDatabase = 0;

  setUp(() {
    // What the Flutter engine's plugin registrant does on a real device; the
    // test host has no registrant, and without it the plugin resolves to no
    // platform implementation at all.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    plugin = _PluginHost()..install();
    tempDir = Directory.systemTemp.createTempSync('uhabits_reminder_response');
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    plugin.remove();
    for (final AppScope scope in scopes) {
      try {
        scope.close();
      } on Object {
        // Already closed.
      }
    }
    scopes.clear();
    DateUtils.setFixedLocalTime(null);
    DateUtils.setFixedTimeZone(null);
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final AppScope scope = AppScope.open(
      // No databasePath: the auto-backup the habit list runs on resume needs
      // one, and a backup is not what any of this is about.
      AppDatabase.openAndMigrate('${tempDir.path}/habits${nextDatabase++}.db'),
    );
    // `BaseUserInterfaceTest.setUp`: `prefs.isFirstRun = false`. A scope over an
    // empty preference store IS a first run, and a first run now opens the intro
    // on top of the habit list (`verify.intro-never-shown`) — which is
    // test/ui/intro/intro_wiring_test.dart's subject, not this file's.
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  Habit addHabit(
    AppScope scope, {
    String name = 'Meditate',
    HabitType type = HabitType.yesNo,
  }) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = name
      ..question = 'Did you meditate today?'
      ..type = type
      ..frequency = Frequency.daily
      ..reminder = Reminder(8, 30, WeekdayList.everyDay);
    if (type == HabitType.numerical) {
      habit
        ..targetValue = 200
        ..unit = 'steps';
    }
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  /// The payload the app itself puts on every reminder — `ReminderPayload`
  /// is what `ReminderNotificationBuilder.build` encodes — so what comes back
  /// up the channel is what went down it.
  String payloadFor(Habit habit, {LocalDate? date}) => ReminderPayload(
        habitId: habit.id!,
        timestamp: (date ?? getToday()).unixTime,
        reminderTime: DateUtils.applyTimezone(DateUtils.getLocalTime()),
      ).encode();

  // -----------------------------------------------------------------------
  // verify.notifications-never-initialised
  // -----------------------------------------------------------------------

  group('verify.notifications-never-initialised — the plugin at startup', () {
    test('#2 startup initialises the plugin with the ic_notification drawable',
        () async {
      final AppScope scope = openScope();
      addHabit(scope);

      await scope.startPlatformServices();

      final MethodCall? initialize = plugin.lastCallNamed('initialize');
      expect(initialize, isNotNull,
          reason: 'verify.notifications-never-initialised#2: '
              'LocalNotificationsPresenter.initialize is the only code that '
              'calls plugin.initialize, and nothing calls it — not main(), not '
              "AppScope.boot(), not startPlatformServices(). Until it runs the "
              "plugin's defaultIcon is never written and, per "
              'verify.notifications-never-initialised#1, every scheduled '
              'reminder throws inside the plugin at fire time instead of '
              'appearing in the shade.');
      final Map<Object?, Object?> arguments =
          initialize!.arguments as Map<Object?, Object?>;
      expect(arguments['defaultIcon'],
          LocalNotificationsPresenter.androidSmallIcon,
          reason: 'verify.notifications-never-initialised#1: '
              'AndroidNotificationTray always calls '
              'setSmallIcon(R.drawable.ic_notification). The plugin takes the '
              'drawable by name at initialisation, so the name has to reach '
              'plugin.initialize — asserting the constant equals '
              "'ic_notification' asserts nothing about the running app.");
    });

    test('#2 both response callbacks are registered with it', () async {
      final AppScope scope = openScope();
      addHabit(scope);

      await scope.startPlatformServices();

      final Map<Object?, Object?> arguments = (plugin
          .lastCallNamed('initialize')
          ?.arguments as Map<Object?, Object?>?) ?? <Object?, Object?>{};
      expect(arguments['callback_handle'], isNotNull,
          reason: 'verify.notifications-never-initialised#2(c): neither '
              'onDidReceiveNotificationResponse nor '
              'onDidReceiveBackgroundNotificationResponse is registered, so '
              'nothing the user does to a notification reaches Dart. The '
              'background one is registered by handing initialize a '
              "top-level entry point, which is what puts a 'callback_handle' "
              'in the arguments; on Android a "Yes"/"No" button is delivered '
              'to no other callback at all.');
      expect(arguments['dispatcher_handle'], isNotNull,
          reason: 'verify.notifications-never-initialised#2(c): the plugin '
              'needs the dispatcher handle beside it to start the background '
              'isolate.');
    });

    test('#2 the iOS categories are declared at initialisation', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      IOSFlutterLocalNotificationsPlugin.registerWith();
      final AppScope scope = openScope();
      addHabit(scope);

      await scope.startPlatformServices();

      final Map<Object?, Object?> arguments = (plugin
          .lastCallNamed('initialize')
          ?.arguments as Map<Object?, Object?>?) ?? <Object?, Object?>{};
      final List<Object?> categories =
          (arguments['notificationCategories'] as List<Object?>?) ??
              <Object?>[];
      expect(
        categories
            .map((Object? c) => (c! as Map<Object?, Object?>)['identifier'])
            .toList(),
        <String>[ReminderCategories.yesNo, ReminderCategories.numerical],
        reason: 'verify.notifications-never-initialised#2(b): the Darwin '
            'notificationCategories list built by _darwinCategories() is '
            'never registered, so on iOS/macOS a reminder shows with no '
            'Yes/No/Enter/Later buttons — iOS takes the buttons only at '
            'initialisation, never from the notification itself.',
      );
    });
  });

  // -----------------------------------------------------------------------
  // verify.notification-actions-unrouted
  // -----------------------------------------------------------------------

  group('verify.notification-actions-unrouted — what the buttons reach', () {
    test('#1 "Yes" writes YES_MANUAL for the day the reminder named', () async {
      final AppScope scope = openScope();
      final Habit habit = addHabit(scope);
      await scope.startPlatformServices();
      final LocalDate day = getToday();

      await plugin.deliverResponse(
        notificationId: reminderNotificationId(habit),
        actionId: ReminderActions.addRepetition,
        payload: payloadFor(habit, date: day),
      );
      await scope.taskRunner.awaitAll();
      await pumpEventQueue();

      expect(habit.originalEntries.get(day).value, Entry.yesManual,
          reason: "verify.notification-actions-unrouted#1: 'Yes' writes "
              'YES_MANUAL through WidgetBehavior.onAddRepetition. '
              '#2: ReminderResponse decodes the action and nothing is '
              'listening — main.dart never registers a response callback with '
              'the plugin, so the button is a dead end.');
    });

    test('#1 "No" writes NO for that day', () async {
      final AppScope scope = openScope();
      final Habit habit = addHabit(scope);
      await scope.startPlatformServices();
      final LocalDate day = getToday();

      await plugin.deliverResponse(
        notificationId: reminderNotificationId(habit),
        actionId: ReminderActions.removeRepetition,
        payload: payloadFor(habit, date: day),
      );
      await scope.taskRunner.awaitAll();
      await pumpEventQueue();

      expect(habit.originalEntries.get(day).value, Entry.no,
          reason: "verify.notification-actions-unrouted#1: 'No' writes NO. "
              '#2: nothing routes it today.');
    });

    test('#2 a response that is not ours changes nothing', () async {
      final AppScope scope = openScope();
      final Habit habit = addHabit(scope);
      await scope.startPlatformServices();

      await plugin.deliverResponse(
        notificationId: 0,
        actionId: ReminderActions.addRepetition,
        payload: 'not-a-uhabits-payload',
      );
      await scope.taskRunner.awaitAll();
      await pumpEventQueue();

      expect(habit.originalEntries.get(getToday()).value, Entry.unknown,
          reason: 'verify.notification-actions-unrouted#2: ReminderResponse'
              '.decode returns null for a payload this app did not write, the '
              'way ReminderReceiver returns early on an intent whose data '
              'resolves to no habit — routing must keep that gate.');
    });

    test('#2 a background action reaches the running app', () async {
      final AppScope scope = openScope();
      final Habit habit = addHabit(scope);
      await scope.startPlatformServices();
      final LocalDate day = getToday();

      // On Android an action button that shows no user interface is delivered
      // to a background isolate, and to nothing else: the plugin looks the
      // registered entry point up by callback handle and calls it there. This
      // is that call.
      reminderBackgroundResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: reminderNotificationId(habit),
          actionId: ReminderActions.addRepetition,
          payload: payloadFor(habit, date: day),
        ),
      );
      await pumpEventQueue();
      await scope.taskRunner.awaitAll();
      await pumpEventQueue();

      expect(habit.originalEntries.get(day).value, Entry.yesManual,
          reason: 'verify.notifications-never-initialised#2(c): '
              'onDidReceiveBackgroundNotificationResponse is the only '
              'callback an Android "Yes" reaches. Registering it is what puts '
              "a 'callback_handle' in the initialize arguments, and the entry "
              'point it names has to reach the app that is running.');
    });

    testWidgets('#1 a tap on the body opens that habit', (tester) async {
      final AppScope scope = openScope();
      final Habit habit = addHabit(scope);
      await scope.startPlatformServices();
      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();

      await plugin.deliverResponse(
        notificationId: reminderNotificationId(habit),
        payload: payloadFor(habit),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ShowHabitScreen), findsOneWidget,
          reason: 'verify.notification-actions-unrouted#1: tapping the '
              'notification body opens ShowHabitActivity on top of the habit '
              'list. #2: the content intent reaches nothing today.');
    });

    testWidgets('#1 "Enter" opens the numeric value dialog for that day',
        (tester) async {
      final AppScope scope = openScope();
      final Habit habit = addHabit(scope, type: HabitType.numerical);
      await scope.startPlatformServices();
      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();

      final LocalDate day = getToday().minus(2);
      await plugin.deliverResponse(
        notificationId: reminderNotificationId(habit),
        actionId: ReminderActions.edit,
        payload: payloadFor(habit, date: day),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NumberDialog), findsOneWidget,
          reason: "verify.notification-actions-unrouted#1: 'Enter' opens the "
              'numeric value dialog for that habit and day. #2: the port '
              'decodes the action and then drops it.');

      await tester.enterText(
          find.byKey(const ValueKey<String>('number_value')), '7');
      await tester.tap(find.byKey(const ValueKey<String>('number_save_button')));
      await tester.pumpAndSettle();

      expect(habit.computedEntries.get(day).value, 7000,
          reason: 'verify.notification-actions-unrouted#1: for the day the '
              'notification named, not for today');
    });

    testWidgets('#2 a notification that launched the app is acted on',
        (tester) async {
      final AppScope scope = openScope();
      final Habit habit = addHabit(scope);
      // A cold start: the process exists because the user tapped the
      // notification, so the response is waiting in the launch details rather
      // than arriving on the callback.
      plugin.launchDetails = <Object?, Object?>{
        'notificationLaunchedApp': true,
        'notificationResponse': <Object?, Object?>{
          'notificationId': reminderNotificationId(habit),
          'actionId': null,
          'input': null,
          'payload': payloadFor(habit),
          'notificationResponseType': 0,
        },
      };

      await scope.startPlatformServices();
      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();

      expect(plugin.callsNamed('getNotificationAppLaunchDetails'), isNotEmpty,
          reason: 'verify.notification-actions-unrouted#2: the response that '
              'launched the app is never delivered to '
              'onDidReceiveNotificationResponse — the plugin hands it over '
              'through getNotificationAppLaunchDetails instead, so an app '
              'that never asks loses every tap made while it was dead.');
      expect(find.byType(ShowHabitScreen), findsOneWidget,
          reason: 'verify.notification-actions-unrouted#1: and the tap still '
              'has to open the habit, exactly as it does when the app was '
              'already running.');
    });
  });

  // -----------------------------------------------------------------------
  // verify.sticky-dismiss-unrouted
  // -----------------------------------------------------------------------

  group('verify.sticky-dismiss-unrouted — the swipe', () {
    /// Puts one reminder in the shade, through the app's own tray.
    Future<void> showReminder(
      WidgetTester tester,
      AppScope scope,
      Habit habit,
    ) async {
      scope.notificationTray!.show(
        habit,
        getToday(),
        DateUtils.applyTimezone(DateUtils.getLocalTime()),
      );
      // Inside testWidgets the clock is fake, so the tray's task runner only
      // advances when the tester pumps.
      await tester.pumpAndSettle();
      expect(plugin.callsNamed('show'), hasLength(1),
          reason: 'the reminder has to be on screen before it can be swiped '
              'away');
      plugin.active = <Map<Object?, Object?>>[
        <Object?, Object?>{'id': reminderNotificationId(habit)},
      ];
    }

    testWidgets('#1 with sticky notifications on, a swiped reminder comes back',
        (tester) async {
      final AppScope scope = openScope();
      scope.preferences.setNotificationsSticky(true);
      final Habit habit = addHabit(scope);
      await scope.startPlatformServices();
      await showReminder(tester, scope, habit);

      // The user swipes it away: Android 14 lets even an ongoing notification
      // go, and the shade no longer lists it.
      plugin.active = <Map<Object?, Object?>>[];

      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();

      expect(plugin.callsNamed('show'), hasLength(2),
          reason: 'verify.sticky-dismiss-unrouted#1: every reminder carries a '
              'delete intent, and with pref_sticky_notifications on '
              'ReminderController.onDismiss calls notificationTray.reshow('
              'habit) — the documented workaround that keeps sticky reminders '
              'non-dismissible on Android 14+. #2: the plugin has no '
              'delete-intent callback, so the port has to notice the swipe '
              'some other way; today it never notices at all and the reminder '
              'stays gone.');
    });

    testWidgets('#1 with sticky off, the registry stops claiming it is shown',
        (tester) async {
      final AppScope scope = openScope();
      scope.preferences.setNotificationsSticky(false);
      final Habit habit = addHabit(scope);
      await scope.startPlatformServices();
      await showReminder(tester, scope, habit);

      plugin.active = <Map<Object?, Object?>>[];

      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();

      expect(plugin.callsNamed('show'), hasLength(1),
          reason: 'verify.sticky-dismiss-unrouted#1: with the preference off '
              'onDismiss cancels rather than re-shows');
      expect(
        plugin.cancelledIds,
        contains(reminderNotificationId(habit)),
        reason: 'verify.sticky-dismiss-unrouted#1: …it calls notificationTray'
            ".cancel(habit) so the core's `active` registry stays in step. "
            '#2: today the registry keeps an entry for a notification that is '
            'no longer in the shade.',
      );
    });
  });

  // -----------------------------------------------------------------------
  // verify.snooze-picker-uncalled
  // -----------------------------------------------------------------------

  group('verify.snooze-picker-uncalled — "Later"', () {
    testWidgets('#1 opens the snooze delay picker', (tester) async {
      final AppScope scope = openScope();
      final Habit habit = addHabit(scope);
      await scope.startPlatformServices();
      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();

      await plugin.deliverResponse(
        notificationId: reminderNotificationId(habit),
        actionId: ReminderActions.snoozeReminder,
        payload: payloadFor(habit),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SnoozePickerDialog), findsOneWidget,
          reason: "verify.snooze-picker-uncalled#1: tapping 'Later' starts "
              'SnoozeDelayPickerActivity. #2: showSnoozePickerDialog is '
              'referenced exactly once in lib — its own definition — and '
              'ReminderIntentReceiver, the object that would call it through '
              'its onSnoozePressed callback, is never constructed, so the '
              'picker is unreachable by any user.');
    });

    testWidgets('#1 and the chosen delay snoozes the habit', (tester) async {
      final AppScope scope = openScope();
      final Habit habit = addHabit(scope);
      await scope.startPlatformServices();
      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();

      await plugin.deliverResponse(
        notificationId: reminderNotificationId(habit),
        actionId: ReminderActions.snoozeReminder,
        payload: payloadFor(habit),
      );
      await tester.pumpAndSettle();
      final int before = DateUtils.applyTimezone(DateUtils.getLocalTime());
      await tester.tap(find.byKey(const ValueKey<String>('snooze_item_0')));
      await tester.pumpAndSettle();

      final int snoozedUntil =
          WidgetPreferences(scope.preferencesStorage).getSnoozeTime(habit.id!);
      expect(snoozedUntil, greaterThanOrEqualTo(before + 15 * 60 * 1000),
          reason: 'verify.snooze-picker-uncalled#1: the choice calls '
              'reminderScheduler.snoozeReminder — 15 minutes is the first of '
              'the eight delays. #2: nothing passes onSnoozePressed, so '
              "'Later' leads nowhere.");
      expect(
        plugin.cancelledIds,
        contains(reminderNotificationId(habit)),
        reason: 'verify.snooze-picker-uncalled#1: …and cancels the '
            'notification, which is ReminderController.onSnoozeDelayPicked '
            'running snooze-first, cancel-second.',
      );
    });
  });

  // -----------------------------------------------------------------------
  // audit10.platform-services-start-on-every-device-language
  // -----------------------------------------------------------------------

  group('audit10.platform-services-start-on-every-device-language', () {
    const String rule =
        'audit10.platform-services-start-on-every-device-language#1 — '
        'HabitsApplication.onCreate starts the widget updater, the reminder '
        'scheduler and the notification tray unconditionally, and the '
        'notification copy comes from context.getString at fire time, which '
        'never fails: Android falls back to res/values/ for any language it '
        'ships no translation for. Nothing about the device language can stop '
        'those three singletons from being built.';

    /// The device language, driven through the binding rather than
    /// `PlatformDispatcher.instance`, which no test can drive.
    void setDeviceLanguage(Locale locale) {
      binding.platformDispatcher.localesTestValue = <Locale>[locale];
      addTearDown(binding.platformDispatcher.clearLocalesTestValue);
    }

    test('#1 an untranslated device language leaves the tray, the scheduler '
        'and the widget publisher standing', () async {
      setDeviceLanguage(const Locale('th', 'TH'));
      final AppScope scope = openScope();
      addHabit(scope);

      await scope.startPlatformServices();

      expect(scope.notificationTray, isNotNull,
          reason: '$rule A Thai phone has to get the same reminders an '
              'English one gets.');
      expect(scope.reminderScheduler, isNotNull,
          reason: '$rule Without it no alarm is ever armed, and '
              'ListHabitsActivity.onResume skips scheduleAll for the whole '
              'session.');
      expect(scope.widgetSync, isNotNull,
          reason: '$rule Without it every home-screen widget stays blank and '
              'lib/main.dart cannot even build the deep links that configure '
              'one.');
      expect(scope.reminderResponses, isNotNull,
          reason: '$rule …and nothing the user does to a notification would '
              'reach Dart.');
    });

    testWidgets('#1 and the reminder it posts carries the default English '
        'copy', (WidgetTester tester) async {
      setDeviceLanguage(const Locale('th', 'TH'));
      final AppScope scope = openScope();
      final Habit habit = addHabit(scope);
      // R.string.default_reminder_question is what a habit with no question
      // shows, and it is resolved from the app's strings, not from the habit.
      habit.question = '';
      await scope.startPlatformServices();

      scope.notificationTray!.show(
        habit,
        getToday(),
        DateUtils.applyTimezone(DateUtils.getLocalTime()),
      );
      await tester.pumpAndSettle();

      final MethodCall? show = plugin.lastCallNamed('show');
      expect(show, isNotNull,
          reason: '$rule The notification is posted at all.');
      expect((show!.arguments as Map<Object?, Object?>)['body'],
          'Have you completed this habit today?',
          reason: '$rule getString falls back to values/, so the Thai user '
              'reads the English question — not nothing.');
    });
  });
}
