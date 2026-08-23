/// `widgets.checkmark#6` and `#8` — what a tap on the Checkmark widget reaches.
///
/// The widget itself (its size, its view, the order `refreshData` fills it in)
/// is asserted in app/test/platform/android_widgets_test.dart; the value cycle a
/// repeated tap walks is `widgets.checkmark#9`, in
/// app/test/platform/home_widget_bridge_test.dart. What is left is the tap
/// *path*, and it has two halves.
///
/// The boolean half is the one the port changed. Upstream the tap is a
/// broadcast `PendingIntent` (request code 2, `FLAG_IMMUTABLE|FLAG_UPDATE_
/// CURRENT`) to `WidgetReceiver`, carrying `ACTION_TOGGLE_REPETITION`, the
/// habit's content uri as data and *no* `timestamp` extra, so the receiver
/// defaults to today. A `BroadcastReceiver` in the launcher's process cannot run
/// Dart, so `app/android/.../widgets/WidgetIntents.kt` sends the same three
/// facts — this habit, a toggle, no day — as a deep link into `MainActivity`,
/// and `WidgetLinkRouter` rebuilds the intent and hands it to the ported
/// `WidgetReceiver`. The delivery differs and is recorded as a deviation; the
/// action, the addressing and the default-to-today are asserted below, on both
/// sides of the boundary.
///
/// The numerical half needed no change: upstream it was already an activity
/// intent to `ListHabitsActivity`, and `parseIntents()` is what acts on it.
library;

// The core's models and platform seams are reached by their `src` path,
// exactly as lib/state does.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart' hide DateUtils, Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/home_widget_bridge.dart' show WidgetRegistry;
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/habit_list_model.dart' show HabitListModel;
import 'package:uhabits/state/intent_router.dart';
import 'package:uhabits/state/widget_link.dart';
import 'package:uhabits/state/widget_sync.dart' show WidgetBehavior;
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';

/// The `android/app/src/main` directory of the Flutter app.
final Directory androidMain = _findAndroidMain();

Directory _findAndroidMain() {
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
  throw StateError('android/app/src/main not found');
}

String widgetKotlin(String name) =>
    File('${androidMain.path}/kotlin/org/isoron/uhabits/widgets/$name')
        .readAsStringSync();

/// Everything between `fun <name>(` and the next line that starts a new
/// top-level declaration — enough to pin what one factory builds.
String kotlinFunction(String source, String name) {
  final int start = source.indexOf('fun $name(');
  expect(start, isNonNegative, reason: 'no fun $name( in the source');
  final int next = source.indexOf(RegExp(r'\n    (/\*\*|fun |private fun )'),
      start + 1);
  return source.substring(start, next < 0 ? source.length : next);
}

void main() {
  late Directory tempDir;
  final List<AppScope> scopes = <AppScope>[];

  setUp(() {
    // A fixed today, so "the day the tap targets" is a value the test can name
    // rather than whatever the machine clock says.
    setToday(LocalDate.ymd(2015, 1, 26));
    tempDir = Directory.systemTemp.createTempSync('uhabits_checkmark_tap');
  });

  tearDown(() {
    for (final AppScope scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final AppScope scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scopes.add(scope);
    return scope;
  }

  Habit addDbHabit(AppScope scope, {HabitType type = HabitType.yesNo}) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Meditate'
      ..type = type;
    if (type == HabitType.numerical) {
      habit
        ..targetValue = 200
        ..unit = 'steps';
    }
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  WidgetIntentReceiver receiverFor(AppScope scope) => WidgetIntentReceiver(
        parser: IntentParser(scope.habitList),
        controller: WidgetBehavior(
          habitList: scope.habitList,
          commandRunner: scope.commandRunner,
          notificationTray: NotificationTray(
            scope.taskRunner,
            scope.commandRunner,
            scope.preferences,
            _SilentTray(),
          ),
          preferences: scope.preferences,
        ),
        preferences: scope.preferences,
        updateWidgets: () async {},
        scheduleStartDayWidgetUpdate: () {},
        logging: StandardLogging(),
      );

  WidgetLinkRouter routerFor(AppScope scope) => WidgetLinkRouter(
        habitList: scope.habitList,
        registry: WidgetRegistry(scope.preferencesStorage),
        publish: () async {},
        navigator: GlobalKey<NavigatorState>(),
        launches: const _NoLaunches(),
        receiver: receiverFor(scope),
      );

  Widget wrap(AppScope scope, WidgetLinkRouter router) => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: HabitListScreen(widgetLinks: router),
        ),
      );

  group('widgets.checkmark#6 — the boolean tap', () {
    const String rule = 'widgets.checkmark#6';

    test('the boolean branch of getOnClickPendingIntent, and what it addresses',
        () {
      final String widget = widgetKotlin('CheckmarkWidget.kt');
      // `if (habit.isNumerical) showNumberPicker(...) else toggleCheckmark(...)`
      expect(
        widget.contains('WidgetIntents.toggleCheckmark(context, id, habit)'),
        isTrue,
        reason: '$rule — a boolean Checkmark widget answers a tap with the '
            'toggle intent',
      );

      final String intents = kotlinFunction(
        widgetKotlin('WidgetIntents.kt'),
        'toggleCheckmark',
      );
      expect(intents.contains('ACTION_TOGGLE'), isTrue,
          reason: '$rule — carrying ACTION_TOGGLE_REPETITION');
      expect(intents.contains('"habit", habit.id.toString()'), isTrue,
          reason: '$rule — addressed to one habit, the way the upstream data '
              'uri addresses it');
      expect(intents.contains('"date"'), isFalse,
          reason: '$rule — and NO day: the intent carries no timestamp, so '
              'whatever receives it defaults to today');
    });

    test('the link becomes the broadcast, addressed to the habit and to today',
        () {
      const int habitId = 42;
      final LocalDate today = getToday();

      final Intent intent = widgetLinkIntent(
        WidgetLink.parse(
          Uri.parse('uhabits://widget/toggle?habit=$habitId&widgetId=3'),
        )!,
        today: today,
      )!;

      expect(intent.action, WidgetActions.toggleRepetition,
          reason: '$rule — action ACTION_TOGGLE_REPETITION');
      expect(intent.data, habitUri(habitId),
          reason: '$rule — data = habit.uriString');
      expect(intent.extras['timestamp'], today.unixTime,
          reason: '$rule — the link named no day, so the day is today — which '
              "is what upstream's missing 'timestamp' extra produces");
    });

    testWidgets('a tap toggles today, and only today', (tester) async {
      final AppScope scope = openScope();
      final Habit habit = addDbHabit(scope);
      final WidgetLinkRouter router = routerFor(scope);
      await tester.pumpWidget(wrap(scope, router));
      await tester.pumpAndSettle();

      final LocalDate today = getToday();
      expect(habit.computedEntries.get(today).value, Entry.unknown,
          reason: '$rule — nothing is entered yet');

      await router.handle(
        Uri.parse('uhabits://widget/toggle?habit=${habit.id}&widgetId=3'),
      );
      await tester.pumpAndSettle();

      expect(habit.originalEntries.get(today).value, Entry.yesManual,
          reason: '$rule — the tap runs onToggleRepetition for today');
      expect(habit.originalEntries.get(today.minus(1)).value, Entry.unknown,
          reason: '$rule — and for no other day: the intent carries no '
              'timestamp of its own');

      // The tap is a toggle, not a set: the second one moves the value on.
      await router.handle(
        Uri.parse('uhabits://widget/toggle?habit=${habit.id}&widgetId=3'),
      );
      await tester.pumpAndSettle();
      expect(habit.originalEntries.get(today).value, isNot(Entry.yesManual),
          reason: '$rule — a second tap advances the value again');
    });
  });

  group('widgets.checkmark#8 — the numerical tap', () {
    const String rule = 'widgets.checkmark#8';

    test('the numerical branch builds the ACTION_EDIT activity intent', () {
      final String widget = widgetKotlin('CheckmarkWidget.kt');
      expect(
        widget.contains(
            'WidgetIntents.showNumberPicker(context, id, habit, today)'),
        isTrue,
        reason: '$rule — a numerical Checkmark widget opens the value picker '
            'instead of toggling',
      );

      const int habitId = 42;
      final LocalDate day = LocalDate.ymd(2015, 1, 25);

      final Intent intent = widgetLinkIntent(
        WidgetLink.parse(Uri.parse('uhabits://widget/edit?habit=$habitId'
            '&widgetId=3&date=2015-01-25'))!,
        today: getToday(),
      )!;

      expect(intent.action, actionEdit,
          reason: '$rule — ListHabitsActivity.ACTION_EDIT');
      expect(intent.extras['habit'], habitId,
          reason: "$rule — with both 'habit'…");
      expect(intent.extras['timestamp'], day.unixTime,
          reason: "$rule — …and 'timestamp' extras");
    });

    testWidgets('parseIntents resolves the habit and opens that day\'s popup',
        (tester) async {
      final AppScope scope = openScope();
      final Habit habit = addDbHabit(scope, type: HabitType.numerical);
      final WidgetLinkRouter router = routerFor(scope);
      await tester.pumpWidget(wrap(scope, router));
      await tester.pumpAndSettle();

      final LocalDate day = getToday().minus(3);
      await router.handle(Uri.parse('uhabits://widget/edit?habit=${habit.id}'
          '&widgetId=3&date=${day.year}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}'));
      await tester.pumpAndSettle();

      expect(find.byType(NumberDialog), findsOneWidget,
          reason: '$rule — parseIntents resolves the habit and calls '
              'listHabitsBehavior.onEdit(habit, date, 0f, 0f)');

      await tester.enterText(
          find.byKey(const ValueKey<String>('number_value')), '7');
      await tester.tap(find.byKey(const ValueKey<String>('number_save_button')));
      await tester.pumpAndSettle();

      expect(habit.computedEntries.get(day).value, 7000,
          reason: '$rule — for the day the intent named');

      final HabitListModel model = Provider.of<HabitListModel>(
        tester.element(find.byType(Scaffold)),
        listen: false,
      );
      expect(model.pendingIntent, isNull,
          reason: '$rule — the intent is then cleared so it fires only once');

      model
        ..detach()
        ..attach();
      await tester.pumpAndSettle();
      expect(find.byType(NumberDialog), findsNothing,
          reason: '$rule — a second resume handles nothing');
    });
  });
}

class _NoLaunches implements WidgetLaunchSource {
  const _NoLaunches();

  @override
  Future<Uri?> initialLaunchUri() async => null;

  @override
  Stream<Uri?> get launchUris => const Stream<Uri?>.empty();
}

/// A tray backend that posts nothing: `WidgetBehavior` cancels a notification
/// on every write, and there is no platform here to cancel one on.
class _SilentTray implements SystemTray {
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
