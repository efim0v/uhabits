/// `settings.preferences.widget-opacity#4`: the one settings key whose change
/// repaints the home screen.
///
/// `SettingsFragment` registers itself as an `OnSharedPreferenceChangeListener`
/// and special-cases exactly one key — every other row is read by whoever needs
/// it, the next time it needs it. The port has no listener registry over the
/// settings file, so the special case lives where the write does:
/// `SettingsModel.widgetOpacity`'s setter.
///
/// The rest of the feature is asserted elsewhere: the key, its type and its
/// entries in test/ui/settings/settings_screen_test.dart (`#1`, `#2`, `#3`),
/// and `#5`..`#8` — the alpha the native widget paints its card with, and the
/// shadow only a fully opaque one gets — in test/platform/widget_opacity_test
/// .dart. The republish this file pins is what carries the new value across:
/// the preference travels to the launcher's process inside the widget
/// document, so a write with no republish would leave the home screen showing
/// the old alpha until the next command.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/settings_model.dart';
import 'package:uhabits/state/widget_sync.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// The `home_widget` plugin, counting publishes.
class CountingWidgetPlatform implements HomeWidgetPlatform {
  int publishes = 0;

  @override
  Future<void> saveWidgetData(String id, String? value) async {}

  @override
  Future<void> setAppGroupId(String groupId) async {}

  @override
  Future<void> updateWidget({
    required String name,
    required String qualifiedAndroidName,
    required String iOSName,
  }) async {
    if (name == HomeWidgetBridge.providerNames.first) publishes++;
  }
}

class SilentTray implements SystemTray {
  @override
  void log(String msg) {}

  @override
  void removeNotification(int notificationId) {}

  @override
  void showNotification(
    Habit habit,
    int notificationId,
    LocalDate date,
    int reminderTime,
  ) {}
}

class SilentScheduler implements SystemScheduler {
  @override
  void log(String componentName, String msg) {}

  @override
  SchedulerResult scheduleShowReminder(
    int reminderTime,
    Habit habit,
    int timestamp,
  ) =>
      SchedulerResult.ok;

  @override
  SchedulerResult? scheduleWidgetUpdate(int updateTime) => SchedulerResult.ok;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final List<AppScope> scopes = <AppScope>[];
  int databaseIndex = 0;

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_widget_opacity');
  });

  tearDown(() async {
    await pumpEventQueue();
    for (final AppScope scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  /// A scope whose platform services are the three fakes above, started
  /// through the very sequence `HabitsApplication.onCreate` uses.
  ({AppScope scope, CountingWidgetPlatform widgets}) boot({
    required bool withWidgetSupport,
  }) {
    final AppScope scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits${databaseIndex++}.db'),
      preferencesStorage: MemoryStorage(),
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    scopes.add(scope);
    final CountingWidgetPlatform platform = CountingWidgetPlatform();
    if (withWidgetSupport) {
      scope.startServices(
        tray: NotificationTray(
          scope.taskRunner,
          scope.commandRunner,
          scope.preferences,
          SilentTray(),
        ),
        scheduler: ReminderScheduler(
          scope.commandRunner,
          scope.habitList,
          SilentScheduler(),
          WidgetPreferences(scope.preferencesStorage),
        ),
        sync: WidgetSync(
          bridge: HomeWidgetBridge(
            habitList: scope.habitList,
            registry: WidgetRegistry(scope.preferencesStorage),
            platform: platform,
          ),
          commandRunner: scope.commandRunner,
          taskRunner: scope.taskRunner,
          midnightTimer: scope.midnightTimer,
          preferences: scope.preferences,
        ),
      );
    }
    return (scope: scope, widgets: platform);
  }

  const String rule =
      'settings.preferences.widget-opacity#4 — '
      'SettingsFragment.onSharedPreferenceChanged calls '
      'widgetUpdater.updateWidgets() when and only when the changed key equals '
      '"pref_widget_opacity" (and the widget updater is non-null).';

  test('#4 writing pref_widget_opacity republishes the widget data', () async {
    final result = boot(withWidgetSupport: true);
    final SettingsModel model = SettingsModel(result.scope);
    addTearDown(model.dispose);

    await result.scope.widgetSync!.settle();
    final int before = result.widgets.publishes;

    model.widgetOpacity = 153;
    await result.scope.widgetSync!.settle();

    expect(result.scope.preferences.widgetOpacity, 153,
        reason: '$rule The value really was written.');
    expect(result.widgets.publishes, before + 1,
        reason: '$rule …and the widgets were told about it.');
  });

  test('#4 no other settings row republishes anything', () async {
    final result = boot(withWidgetSupport: true);
    final SettingsModel model = SettingsModel(result.scope);
    addTearDown(model.dispose);

    await result.scope.widgetSync!.settle();
    final int before = result.widgets.publishes;

    // Every other writable row of the Interface, Reminder and Development
    // categories.
    model
      ..isShortToggleEnabled = true
      ..isMidnightDelayEnabled = true
      ..isSkipEnabled = true
      ..areQuestionMarksEnabled = true
      ..isCheckmarkSequenceReversed = true
      ..isPureBlackEnabled = true
      ..isConfettiAnimationDisabled = true
      ..areNotificationsSticky = true
      ..isDeveloper = true
      ..theme = SettingsModel.themeDark;

    await result.scope.widgetSync!.settle();
    expect(result.widgets.publishes, before,
        reason: '$rule "when and only when": nine other writes, no publish. '
            'A listener that refreshed on every key would repaint the home '
            'screen on each toggle.');
  });

  test('#4 with no widget updater the write still succeeds', () async {
    // `widgetUpdater != null` — a host with no home-screen widgets, and every
    // widget test, which is the common case.
    final result = boot(withWidgetSupport: false);
    expect(result.scope.widgetSync, isNull, reason: rule);

    final SettingsModel model = SettingsModel(result.scope);
    addTearDown(model.dispose);

    expect(() => model.widgetOpacity = 51, returnsNormally, reason: rule);
    expect(result.scope.preferences.widgetOpacity, 51,
        reason: '$rule The preference is written either way; only the refresh '
            'is conditional.');
    expect(result.widgets.publishes, 0, reason: rule);
  });
}
