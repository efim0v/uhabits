/// Journey: a phone that has never run Loop opens it for the first time.
///
/// `verify.integration-harness#3`, journey 1 — "first run through the intro to
/// an empty list".
///
/// Upstream this is `BaseUserInterfaceTest.launchApp()` on a freshly installed
/// app: `HabitsApplication.onCreate` opens the database, `ListHabitsActivity`
/// starts, `ListHabitsBehavior.onStartup()` sees `isFirstRun` and starts
/// `IntroActivity` on top of it. Skip finishes the intro and the empty list is
/// what is left.
///
/// Nothing here builds a screen, a scope or a preference store: the whole
/// journey is `AppScope.boot()` + `UhabitsApp`, then taps. That is what makes
/// it able to fail for `verify.intro-never-shown` — an intro that is finished,
/// tested and never opened.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/intro/intro_screen.dart';

import 'journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  setUp(() {
    device = TestDevice.create('uhabits_journey_first_run');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

  testWidgets('a first launch opens the intro over the habit list',
      (WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();

    expect(find.byType(IntroScreen), findsOneWidget,
        reason: 'verify.integration-harness#3: the first journey is "first run '
            'through the intro to an empty list". onStartup() -> onFirstRun() '
            '-> screen.showIntroScreen() has to end at a visible IntroScreen, '
            'the way startActivity(IntroActivity) does.');

    final L10n l10n = stringsOf(tester);
    verifyDisplaysText(l10n.introTitle1,
        reason: 'the first slide is what the user sees');

    // `skipOffstage: false` because that is what "on top of" looks like in a
    // Navigator: the route below an opaque one keeps its state and goes
    // offstage rather than being torn down — `ListHabitsActivity` is stopped,
    // not finished.
    expect(find.byType(HabitListScreen, skipOffstage: false), findsOneWidget,
        reason: 'startActivity() puts IntroActivity ON TOP of '
            'ListHabitsActivity — the list is still there underneath.');
  });

  testWidgets('Skip lands the user on an empty habit list',
      (WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);

    final L10n l10n = stringsOf(tester);
    expect(find.byType(IntroScreen), findsNothing,
        reason: 'onSkipPressed is finish(): the intro closes and the list is '
            'what is left');
    verifyDisplaysText(l10n.mainActivityTitle,
        reason: 'the toolbar title of ListHabitsActivity');
    verifyDisplaysText(l10n.noHabitsFound,
        reason: 'list-habits.empty-state: a brand-new install has no habits, '
            'so EmptyListView is what the list shows');
  });

  testWidgets('the launch created the database and the settings file',
      (WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();

    expect(device.databaseFile.existsSync(), isTrue,
        reason: 'HabitsApplication.onCreate opens (and therefore creates) the '
            'habit database in the app-private directory. A journey that '
            'never touched the disk would prove nothing about the app the '
            'user runs.');
    expect(device.preferencesFile.existsSync(), isTrue,
        reason: 'settings.preferences.android-storage-bridge: the settings '
            'store is opened at startup and seeded with the XML defaults. '
            'Without it every preference would reset on the next launch.');
    expect(app.scope.databasePath, device.databaseFile.path,
        reason: 'the scope has to be pointed at that same file — the '
            'auto-backup and the export both read databasePath');
  });

  testWidgets('a second launch goes straight to the list',
      (WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);

    await app.restart();

    expect(app.launchCount, 2);
    expect(find.byType(IntroScreen), findsNothing,
        reason: 'onFirstRun() cleared isFirstRun on the first launch, and that '
            'write has to have survived the restart — which it only can if '
            'the preferences reached the file the second boot reads back');
    expect(find.byType(HabitListScreen), findsOneWidget);
    verifyDisplaysText(stringsOf(tester).noHabitsFound);
  });
}
