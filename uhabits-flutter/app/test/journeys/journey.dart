/// The integration harness — `verify.integration-harness`.
///
/// Every other widget test in this port builds its subject and hands it the
/// collaborators it needs. That is why three audit passes found 48 defects of
/// one single shape: a class that is implemented, tested, and never
/// constructed — or constructed without the callback that makes it act. A test
/// that supplies the callback itself can never see that hole.
///
/// The files next to this one do the opposite. They start where the
/// application starts:
///
/// ```dart
/// final scope = await AppScope.boot();   // main.dart, line 1
/// runApp(UhabitsApp(scope: scope));      // main.dart, line 2
/// ```
///
/// and then drive real user journeys by finding and tapping real widgets.
/// Nothing below the entry point is constructed by a journey, nothing is
/// injected, and no callback is supplied — so a journey fails when a
/// capability is *unreachable*, not when a class is wrong. This is the Flutter
/// counterpart of
/// uhabits-android/src/androidTest/java/org/isoron/uhabits/acceptance/, whose
/// tests are the same shape: `launchApp()`, then `clickText` / `clickMenu` /
/// `verifyDisplaysText`.
///
/// ## What a "device" is here
///
/// [TestDevice] is one simulated phone. It owns a temporary directory that
/// stands in for the app's private storage — the database, `preferences.json`,
/// the `Backups` and `CSV` folders all land inside it — and it answers every
/// plugin boundary the app talks to: path_provider, flutter_local_notifications,
/// home_widget, share_plus and url_launcher. That directory *outlives a
/// launch*, which is what makes [JourneySession.restart] a real restart: the
/// second `AppScope.boot()` opens the same files the first one wrote.
///
/// ## Why the plugins are mocked at the channel and not by substitution
///
/// Substituting an object is exactly the mistake this harness exists to catch:
/// if the test hands the app a fake notification presenter, then the app never
/// having built a real one goes unnoticed. Every plugin is therefore answered
/// at the *platform* boundary — the method channel, or the plugin's own
/// platform interface — and everything above it is the app's own code.
///
/// ## Three mechanical notes
///
///  * `AppScope.boot()` does real file I/O, and the binding's clock inside
///    `testWidgets` is fake. It therefore runs inside [WidgetTester.runAsync].
///    For the same reason `pumpEventQueue()` hangs here; [settleIo] is the
///    replacement — alternating real-time slices with pumps.
///  * `path_provider` and `url_launcher` are overridden through their platform
///    interfaces rather than their channels, because each is asked for more
///    than one thing and the interface is where those are told apart.
///  * `AndroidFlutterLocalNotificationsPlugin.registerWith()` has to be called
///    by hand: `flutter test` runs no plugin registrant, and without it the
///    plugin resolves to no platform implementation, so the channel and the
///    notification channel it creates would both be silently skipped.
library;

// The core's models and preferences are reached by their `src` path, exactly
// as lib/state/app_scope.dart reaches them. The two platform interfaces are
// transitive dependencies of path_provider and url_launcher, and exist so that
// a test can stand in for the plugin.
// ignore_for_file: implementation_imports, depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/main.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/reminder_link.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/habit_card.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits/ui/habits/list/list_habits_selection_menu.dart';
import 'package:uhabits/ui/intro/intro_screen.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';
import 'package:uhabits_core/src/time/date_utils.dart' as core_time;
import 'package:uhabits_core/uhabits_core.dart' show LocalDate, resetToday;
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

// ---------------------------------------------------------------------------
// The plugin boundaries
// ---------------------------------------------------------------------------

/// The channel `flutter_local_notifications` talks over, in both directions:
/// the app calls `initialize` / `zonedSchedule` / `show` / `cancel` down it,
/// and the platform calls `didReceiveNotificationResponse` back up it.
const String notificationsChannelName =
    'dexterous.com/flutter/local_notifications';

/// The channel the `home_widget` plugin uses.
const String homeWidgetChannelName = 'home_widget';

/// The `home_widget` event channel a launcher taps arrive on. The plugin
/// subscribes to it as soon as `WidgetLinkRouter.start()` runs, and an
/// unanswered `listen` surfaces as an uncaught `MissingPluginException`.
const String homeWidgetUpdatesChannelName = 'home_widget/updates';

/// The channel `share_plus` uses — the far side of `showSendFileScreen`'s
/// `ACTION_SEND`.
const String shareChannelName = 'dev.fluttercommunity.plus/share';

/// `ContextCompat.getExternalFilesDirs(context, null)` and
/// `activity.externalCacheDir`, pointed at the device's own directory.
class _DeviceDirectories extends PathProviderPlatform {
  _DeviceDirectories(this.device);

  final TestDevice device;

  @override
  Future<String?> getApplicationSupportPath() async => device.supportPath;

  @override
  Future<String?> getTemporaryPath() async => device.cachePath;

  @override
  Future<String?> getApplicationDocumentsPath() async => device.documentsPath;
}

/// `Activity.startActivitySafely(intent)`'s far side: whatever app the system
/// would have handed the ACTION_VIEW / mailto intent to.
class _DeviceUrlLauncher extends UrlLauncherPlatform {
  final List<String> launched = <String>[];

  /// False is `ActivityNotFoundException`: nothing on the device handles it.
  bool answer = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => answer;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return answer;
  }
}

/// The native half of `flutter_local_notifications`: the notification shade,
/// the alarm manager and the launch details, as far as Dart can see them.
class NotificationPlatform {
  final List<MethodCall> calls = <MethodCall>[];

  /// What `getNotificationAppLaunchDetails` answers — i.e. whether a
  /// notification is what started this process.
  Map<Object?, Object?> launchDetails = <Object?, Object?>{
    'notificationLaunchedApp': false,
  };

  /// What `getActiveNotifications` answers — i.e. what is really in the shade.
  List<Map<Object?, Object?>> active = <Map<Object?, Object?>>[];

  /// Whether the OS grants POST_NOTIFICATIONS and exact alarms.
  bool permissionsGranted = true;

  List<MethodCall> callsNamed(String method) =>
      calls.where((MethodCall call) => call.method == method).toList();

  MethodCall? lastCallNamed(String method) {
    final List<MethodCall> matching = callsNamed(method);
    return matching.isEmpty ? null : matching.last;
  }

  /// Every alarm `IntentScheduler.scheduleShowReminder` filed, as the plugin
  /// received it.
  List<MethodCall> get scheduledAlarms => callsNamed('zonedSchedule');

  /// The notification ids `cancel` was called with. The Android side of the
  /// plugin sends `{'id': …, 'tag': …}`.
  List<Object?> get cancelledIds => callsNamed('cancel')
      .map((MethodCall call) => call.arguments is Map
          ? (call.arguments as Map<Object?, Object?>)['id']
          : call.arguments)
      .toList();

  Future<Object?> _handle(MethodCall call) async {
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
        return permissionsGranted;
      default:
        return true;
    }
  }

  /// The message the platform sends when the user touches a notification.
  ///
  /// This is `FlutterLocalNotificationsPlugin`'s own inbound method call: it
  /// reaches Dart only if the app registered a response callback when it
  /// initialised the plugin, which is the whole point of delivering it here
  /// rather than calling a router directly.
  Future<void> deliverResponse({
    required int notificationId,
    required String payload,
    String? actionId,
  }) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      notificationsChannelName,
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

// ---------------------------------------------------------------------------
// The device
// ---------------------------------------------------------------------------

/// One simulated phone: a private directory that survives across launches,
/// plus the plugin boundaries the app reaches the operating system through.
///
/// Build it in `setUp` and [dispose] it in `tearDown`.
class TestDevice {
  TestDevice._(this.root);

  /// Creates the device and installs every plugin boundary.
  factory TestDevice.create([String name = 'uhabits_journey']) {
    final TestDevice device =
        TestDevice._(Directory.systemTemp.createTempSync(name));
    // IsolateNameServer is global to the process and `flutter test` runs test
    // files in one process, so two files that each boot an app would fight over
    // the single production port name and deliver one file's notification
    // responses into the other's isolate. Each device gets its own.
    reminderResponsePortName =
        '$defaultReminderResponsePortName/${device.root.path}';
    Directory(device.supportPath).createSync(recursive: true);
    Directory(device.cachePath).createSync(recursive: true);
    Directory(device.documentsPath).createSync(recursive: true);
    device._install();
    return device;
  }

  /// Restores the production port name. Called from [dispose].
  void _releasePortName() {
    reminderResponsePortName = defaultReminderResponsePortName;
  }

  /// The device's storage. Everything the app writes lands under here.
  final Directory root;

  /// `context.filesDir` — the database and `preferences.json`. It is also the
  /// only entry of `getExternalFilesDirs` off Android, which is where the
  /// exporter's `Backups` and `CSV` folders go.
  String get supportPath => '${root.path}/support';

  /// `context.externalCacheDir`.
  String get cachePath => '${root.path}/cache';

  /// `context.getFilesDir()`'s documents sibling. Nothing the app does writes
  /// here; it exists so that the platform interface answers every directory
  /// path_provider can be asked for, rather than only the two in use today.
  String get documentsPath => '${root.path}/documents';

  /// `<external files>/Backups`, where a full backup lands.
  Directory get backupsDir => Directory('$supportPath/Backups');

  /// `<external files>/CSV`, where the CSV archive lands.
  Directory get csvDir => Directory('$supportPath/CSV');

  /// The app's database file, once a launch has created it.
  File get databaseFile => File('$supportPath/uhabits.db');

  /// The app's settings file, once a launch has created it.
  File get preferencesFile => File('$supportPath/preferences.json');

  final NotificationPlatform notifications = NotificationPlatform();

  final _DeviceUrlLauncher _urls = _DeviceUrlLauncher();

  /// Every URL `startActivitySafely(ACTION_VIEW)` handed to another app.
  List<String> get launchedUrls => _urls.launched;

  /// Every `home_widget` call the widget publisher made.
  final List<MethodCall> homeWidgetCalls = <MethodCall>[];

  /// Every file handed to the share sheet by `showSendFileScreen`.
  final List<String> sharedFiles = <String>[];

  TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void _install() {
    // `getToday()` throws until a boot has stamped it; clearing it here is what
    // makes "the app stamps today before anything reads a habit" real rather
    // than inherited from whichever test ran before.
    resetToday();
    PathProviderPlatform.instance = _DeviceDirectories(this);
    UrlLauncherPlatform.instance = _urls;
    // What the Flutter engine's plugin registrant does on a real device; the
    // test host has no registrant, and without it the plugin resolves to no
    // platform implementation at all — so `createNotificationChannel` and
    // `requestNotificationsPermission` would silently do nothing.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    _messenger.setMockMethodCallHandler(
      const MethodChannel(notificationsChannelName),
      notifications._handle,
    );
    _messenger.setMockMethodCallHandler(
      const MethodChannel(homeWidgetChannelName),
      (MethodCall call) async {
        homeWidgetCalls.add(call);
        return null;
      },
    );
    // An EventChannel speaks the same protocol over the same messenger, so
    // answering `listen` and `cancel` here is what a launcher with a widget
    // host does.
    _messenger.setMockMethodCallHandler(
      const MethodChannel(homeWidgetUpdatesChannelName),
      (MethodCall call) async => null,
    );
    _messenger.setMockMethodCallHandler(
      const MethodChannel(shareChannelName),
      (MethodCall call) async {
        final Object? arguments = call.arguments;
        if (arguments is Map) {
          final Object? paths = arguments['paths'];
          if (paths is List) {
            sharedFiles.addAll(paths.whereType<String>());
          }
        }
        return 'dev.fluttercommunity.plus/share/unavailable';
      },
    );
  }

  void dispose() {
    for (final String channel in <String>[
      notificationsChannelName,
      homeWidgetChannelName,
      homeWidgetUpdatesChannelName,
      shareChannelName,
    ]) {
      _messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
    core_time.systemCurrentTimeMillis = core_time.defaultCurrentTimeMillis;
    core_time.DateUtils.setFixedLocalTime(null);
    _releasePortName();
    core_time.DateUtils.setFixedTimeZone(null);
    resetToday();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

// ---------------------------------------------------------------------------
// The session
// ---------------------------------------------------------------------------

/// The application, running on a [TestDevice].
///
/// [launch] is `main()`: `AppScope.boot()` followed by `runApp(UhabitsApp(scope:
/// scope))`, with nothing else supplied. [restart] is the user killing the app
/// and opening it again — a second boot over the same files.
class JourneySession {
  JourneySession(this.tester, this.device);

  final WidgetTester tester;

  final TestDevice device;

  AppScope? _scope;

  /// The scope the running app was built with.
  ///
  /// Journeys read it to check what reached the *database*, never to call a
  /// collaborator the user could not have reached.
  AppScope get scope {
    final AppScope? scope = _scope;
    if (scope == null) {
      throw StateError('The app has not been launched yet.');
    }
    return scope;
  }

  /// How many times the app has been started on this device.
  int get launchCount => _launchCount;

  int _launchCount = 0;

  /// `void main()`, verbatim.
  ///
  /// The boot runs inside [WidgetTester.runAsync] because it opens files, and
  /// the binding's clock inside `testWidgets` is fake: real I/O never completes
  /// on it.
  Future<AppScope> launch() async {
    if (_scope != null) {
      throw StateError('Already running; call restart() or quit() first.');
    }
    late final AppScope booted;
    await tester.runAsync(() async {
      booted = await AppScope.boot();
    });
    _scope = booted;
    _launchCount++;
    await tester.pumpWidget(UhabitsApp(scope: booted));
    await settleIo(tester);
    return booted;
  }

  /// The user swipes the app away and opens it again.
  ///
  /// The widget tree is torn down first, so `_ThemedApp.dispose()` runs — the
  /// midnight timer is stopped and the reminder router detached — exactly as
  /// `onDestroy` would.
  Future<AppScope> restart() async {
    await quit();
    return launch();
  }

  /// `onDestroy` + `onTerminate`.
  Future<void> quit() async {
    if (_scope == null) return;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    _scope!.close();
    _scope = null;
  }

  /// Closes the scope without touching the widget tree; for `tearDown`, where
  /// the tester is no longer usable.
  void dispose() {
    try {
      _scope?.close();
    } on Object {
      // Already closed, or closed over a database that has gone away.
    }
    _scope = null;
  }
}

// ---------------------------------------------------------------------------
// Time
// ---------------------------------------------------------------------------

/// Moves the app's clock to [utcMillis] — the instant an alarm is due.
///
/// `systemCurrentTimeMillis` is the core's own clock hook, and it is the one
/// `computeToday` reads, so a launch after this call stamps the day that
/// instant falls on. That is the only honest way to answer a reminder: a
/// reminder set today for 08:00 is due tomorrow whenever the suite runs after
/// breakfast, and `IntentParser` refuses a checkmark dated in the future
/// exactly as upstream does. Rather than pretend the alarm is due now, the
/// journey lets the day arrive and opens the app on it — which is what the
/// user's phone does.
///
/// Note this is deliberately *not* `DateUtils.setFixedLocalTime`: that hook
/// leaves `computeToday` alone (upstream behaviour), so it would move the
/// reminder without moving the day, and the notification plugin would refuse
/// the resulting alarm as being in the past.
///
/// [TestDevice.dispose] restores the real clock.
void travelTo(int utcMillis) {
  core_time.systemCurrentTimeMillis = () => utcMillis;
}

// ---------------------------------------------------------------------------
// Waiting
// ---------------------------------------------------------------------------

/// Lets the real file system and the real event loop catch up.
///
/// `File.copy`, the CSV writer, the zip archiver and the sqlite writes all
/// complete on the *real* event loop, which the tester's fake async does not
/// pump; and `pumpEventQueue()` hangs under the widget tester because the
/// binding's clock is fake. Alternating [WidgetTester.pump] with a real-time
/// slice inside [WidgetTester.runAsync] is the combination that advances both.
///
/// Plain pumps rather than `pumpAndSettle`, because the task progress bar
/// animates for as long as a task is running and would never settle.
Future<void> settleIo(WidgetTester tester, {int rounds = 12}) async {
  for (int i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Steps — the Flutter counterpart of acceptance/steps/*.kt
// ---------------------------------------------------------------------------

/// `CommonSteps.verifyDisplaysText`.
void verifyDisplaysText(String text, {String? reason}) =>
    expect(find.text(text), findsOneWidget, reason: reason);

/// `CommonSteps.verifyDoesNotDisplayText`.
void verifyDoesNotDisplayText(String text, {String? reason}) =>
    expect(find.text(text), findsNothing, reason: reason);

/// The strings the running app is showing, resolved from the tree rather than
/// hard-coded, so a journey reads the same words the user does.
///
/// Read below the navigator, because `MaterialApp` installs its
/// `Localizations` under itself.
L10n stringsOf(WidgetTester tester) =>
    L10n.of(tester.element(find.byType(Navigator).first));

/// `IntroActivity`'s Skip button, on the first launch only.
Future<void> skipIntro(WidgetTester tester) async {
  expect(find.byType(IntroScreen), findsOneWidget,
      reason: 'the intro is what a first launch opens');
  await tester.tap(find.byKey(IntroScreen.skipButtonKey));
  await tester.pumpAndSettle();
}

/// The habit-list toolbar's overflow button.
Future<void> openOverflowMenu(WidgetTester tester) async {
  await tester
      .tap(find.byKey(const ValueKey<String>('listHabits.overflowMenu')));
  await tester.pumpAndSettle();
}

/// `ListHabitsSteps.clickMenu(item)` — one item of `res/menu/list_habits.xml`.
Future<void> tapListMenuItem(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ListHabitsMenuItems.keyOf(id)));
  await tester.pumpAndSettle();
}

/// One item of the contextual action bar, `res/menu/list_habits_selection.xml`.
Future<void> tapSelectionMenuItem(WidgetTester tester, String id) async {
  final Finder item = find.byKey(ListHabitsSelectionMenuItems.keyOf(id));
  if (item.evaluate().isEmpty) {
    // The three-dot menu of the contextual bar, for an item that did not fit.
    await tester
        .tap(find.byKey(const ValueKey<String>('listHabitsSelection.overflowMenu')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(ListHabitsSelectionMenuItems.keyOf(id)));
  await tester.pumpAndSettle();
}

/// `CommonSteps.longClickText(name)` on a habit row: enters selection mode.
Future<void> longPressHabit(WidgetTester tester, String name) async {
  habitRow(name);
  await tester.longPress(find.text(name));
  await tester.pumpAndSettle();
}

/// `CommonSteps.clickText(name)` on a habit row: opens `ShowHabitActivity`.
Future<void> tapHabit(WidgetTester tester, String name) async {
  habitRow(name);
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

/// The `HabitCardView` whose label reads [name].
Finder habitRow(String name) {
  final Finder row = find.ancestor(
    of: find.text(name),
    matching: find.byType(HabitCard),
  );
  expect(row, findsOneWidget, reason: 'the list has to show a row for "$name"');
  return row;
}

/// `ListHabitsSteps.longPressCheckmarks` for one day of one habit.
///
/// With `pref_short_toggle` off — the shipped default — a long press is what
/// toggles a check-mark and a tap opens the notes editor, which is exactly
/// what the Android acceptance tests do.
Future<void> toggleCheckmark(
  WidgetTester tester,
  String habit,
  LocalDate date,
) async {
  final Finder cell = find.descendant(
    of: habitRow(habit),
    matching: find.byKey(entryButtonKey(date)),
  );
  expect(cell, findsOneWidget,
      reason: 'the row for "$habit" has to have a cell for $date');
  await tester.longPress(cell);
  await settleIo(tester);
}

/// The key `EntryPanel` gives the cell standing for [date].
Key entryButtonKey(LocalDate date) =>
    ValueKey<String>('entryButton:${date.daysSince2000}');

/// The whole "add habit" flow: the toolbar's + button, the type chooser, the
/// editor form, Save.
///
/// This is `HabitsTest.shouldCreateHabit` — `clickMenu(ADD)`,
/// `clickText("Yes or No")`, `typeName`, `typeQuestion`, `clickSave`.
Future<void> createHabit(
  WidgetTester tester, {
  required String name,
  String question = '',
  String notes = '',
  bool measurable = false,
  String target = '10',
  String unit = 'steps',
}) async {
  await tapListMenuItem(tester, ListHabitsMenuItems.createHabit);
  await tester.tap(find.byKey(measurable
      ? EditHabitScreen.measurableTypeCardKey
      : EditHabitScreen.yesNoTypeCardKey));
  await tester.pumpAndSettle();
  await fillHabitForm(
    tester,
    name: name,
    question: question,
    notes: notes,
    // `edit-habit.validation#9`: a measurable habit with a blank target is
    // rejected, so the form has to be filled in the way the user would.
    target: measurable ? target : null,
    unit: measurable ? unit : null,
  );
  await saveHabit(tester);
}

/// `EditHabitSteps.typeName` / `typeQuestion` / `typeDescription`.
Future<void> fillHabitForm(
  WidgetTester tester, {
  String? name,
  String? question,
  String? notes,
  String? target,
  String? unit,
}) async {
  if (name != null) {
    await tester.enterText(find.byKey(EditHabitScreen.nameFieldKey), name);
  }
  if (question != null) {
    await tester.enterText(
        find.byKey(EditHabitScreen.questionFieldKey), question);
  }
  if (notes != null) {
    await tester.enterText(find.byKey(EditHabitScreen.notesFieldKey), notes);
  }
  if (unit != null) {
    await tester.enterText(find.byKey(EditHabitScreen.unitFieldKey), unit);
  }
  if (target != null) {
    await tester.enterText(find.byKey(EditHabitScreen.targetFieldKey), target);
  }
  await tester.pumpAndSettle();
}

/// `EditHabitSteps.clickSave`.
Future<void> saveHabit(WidgetTester tester) async {
  await tester.tap(find.byKey(EditHabitScreen.saveButtonKey));
  await settleIo(tester);
}

/// The overflow menu's Settings item, and the assertion that it arrived.
Future<void> openSettings(WidgetTester tester) async {
  // The settings screen is one long scroll view; a tall surface keeps every
  // row hit-testable without scrolling between assertions.
  await tester.binding.setSurfaceSize(const Size(1000, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpAndSettle();
  await openOverflowMenu(tester);
  await tapListMenuItem(tester, ListHabitsMenuItems.settings);
  expect(find.byType(SettingsScreen), findsOneWidget,
      reason: 'res/menu/list_habits.xml -> SettingsActivity');
}

/// Taps one `<Preference>` row by its `android:key`.
Future<void> tapSettingsRow(WidgetTester tester, String key) async {
  final Finder row = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await settleIo(tester);
}

/// `CommonSteps.pressBack()` — the Android system Back button.
///
/// Delivered as the platform delivers it: a `popRoute` call on
/// `flutter/navigation`. Calling `Navigator.pop` instead would prove only that
/// `Navigator` works; what a journey needs to know is whether the app answers
/// the *system* gesture.
Future<void> pressBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (ByteData? _) {},
  );
  await tester.pumpAndSettle();
}
