/// Wiring tests for the two preferences whose change never reaches the object
/// that has to repaint because of it.
///
/// Both are the same defect the audits keep finding: the value is written, the
/// class that would react is implemented and tested, and nothing connects the
/// two. So both are driven the way a user drives them — the overflow menu, the
/// Settings row, the Back button — on top of `UhabitsApp`, the widget
/// `main()` runs. A test that pushes the value into `ThemeModel` or into
/// `ListHeader` itself proves those classes work and says nothing about
/// whether any user can get there.
///
///  * `audit3.toggling-use-pure-black-background-in` — `ListHabitsActivity`
///    captures `pureBlack = prefs.isPureBlackEnabled` in `onCreate` and
///    restarts itself with a fade from `onResume` when the flag changed while
///    the theme is dark, so the whole app comes back in `PureBlackTheme`. In
///    the port the repaint is in place (docs/parity/DEVIATIONS.md), which
///    makes `ThemeModel` — the object `MaterialApp.theme` is built from — the
///    thing that has to hear about the write.
///  * `audit3.flipping-reverse-order-of-days-leaves` — `HeaderView` is a
///    `Preferences.Listener` in its own right: `onCheckmarkSequenceChanged()`
///    calls `updateScrollDirection()` and `postInvalidate()`, so the date
///    strip flips in the same beat as `ButtonPanelView`'s buttons.
library;

// The core layers are reached by their `src` path, exactly as
// lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'dart:io';

// The core drawing vocabulary wins over Flutter's: Canvas, Color and TextAlign
// below are the ones the ported views speak.
import 'package:flutter/material.dart' hide Canvas, Color, Image, TextAlign, Theme;
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/main.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits/ui/habits/list/list_header.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';
import 'package:uhabits/ui/theme/app_theme.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final List<AppScope> scopes = <AppScope>[];
  int databaseIndex = 0;

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_pref_repaint');
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
      AppDatabase.openAndMigrate('${tempDir.path}/habits${databaseIndex++}.db'),
      preferencesStorage: MemoryStorage(),
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    // `BaseUserInterfaceTest.setUp`: `prefs.isFirstRun = false`, so the first
    // run does not open the intro on top of the habit list.
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  /// The app as `main()` runs it, with one habit to look at.
  Future<AppScope> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final AppScope scope = openScope();
    final Habit habit = scope.modelFactory.buildHabit()..name = 'Meditate';
    scope.habitList.add(habit);
    habit.recompute();
    await tester.pumpWidget(UhabitsApp(scope: scope));
    await tester.pumpAndSettle();
    return scope;
  }

  /// Toolbar -> overflow -> Settings, and the row the user came for.
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('listHabits.overflowMenu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ListHabitsMenuItems.keyOf(ListHabitsMenuItems.settings)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget,
        reason: 'res/menu/list_habits.xml -> SettingsActivity');
  }

  Future<void> tapSettingsSwitch(WidgetTester tester, String key) async {
    final Finder row = find.descendant(
      of: find.byKey(ValueKey<String>(key)),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  /// `finish()`: back out of Settings, onto the list.
  Future<void> leaveSettings(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
  }

  /// The core theme the whole widget tree is being painted with — what
  /// `AndroidThemeSwitcher.currentTheme` answers, read back off the running
  /// app rather than off a model the test built.
  Theme paintedTheme(WidgetTester tester) {
    final ThemeData data =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    return data.extension<CoreThemeExtension>()!.theme;
  }

  group('audit3.toggling-use-pure-black-background-in', () {
    testWidgets(
        '#1 flipping "Use pure black background" repaints the app in dark mode',
        (WidgetTester tester) async {
      // `settings.theme.pure-black#6` only applies in night mode, so the device
      // is put in dark mode the way the OS puts it there.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final AppScope scope = await launch(tester);
      expect(paintedTheme(tester), isA<DarkTheme>(),
          reason: 'the precondition: pref_theme is automatic and the system is '
              'dark, so the app starts on DarkTheme');
      expect(paintedTheme(tester), isNot(isA<PureBlackTheme>()));

      await openSettings(tester);
      await tapSettingsSwitch(tester, 'pref_pure_black');
      await leaveSettings(tester);

      expect(scope.preferences.isPureBlackEnabled, isTrue,
          reason: 'settings.theme.pure-black#2: the row writes the preference');
      expect(paintedTheme(tester), isA<PureBlackTheme>(),
          reason: 'audit3.toggling-use-pure-black-background-in#1: with the '
              'theme set to Dark, flipping the switch restarts the list '
              'activity with a fade and the whole app — list, detail screen, '
              'editor, toolbars — comes back painted in PureBlackTheme. The '
              'port repaints in place instead of restarting, so ThemeModel — '
              'the object MaterialApp.theme is built from — is what has to '
              'hear about the write; SettingsModel writing Preferences and '
              'notifying only the settings screen leaves every other screen '
              'grey for the rest of the process.');
      expect(
        tester
            .widget<Scaffold>(find.byType(Scaffold).first)
            .backgroundColor
            ?.toARGB32(),
        0xFF000000,
        reason: 'audit3.toggling-use-pure-black-background-in#1: and the list '
            'the user comes back to is the black one',
      );
    });
  });

  group('audit3.flipping-reverse-order-of-days-leaves', () {
    testWidgets(
        '#1 flipping "Reverse order of days" moves the date header with the '
        'buttons it labels', (WidgetTester tester) async {
      final AppScope scope = await launch(tester);
      final LocalDate today = getToday();

      // Where today's column is, on both halves of the row, before the flip.
      // The two are not pixel-identical: the card list keeps a few pixels for
      // its scrollbar that the full-width strip above it does not, so what is
      // asserted is that the label sits over its own button rather than over
      // the neighbouring one — the columns are 48 wide.
      final double buttonBefore = _buttonCentreX(tester, today);
      final double labelBefore = _labelCentreX(tester, today);
      final double gap = labelBefore - buttonBefore;
      expect(gap.abs(), lessThan(ListHeader.columnWidth / 2),
          reason: 'the precondition: with the preference off the strip and the '
              'buttons agree — today is leftmost in both '
              '(`list-habits.header-dates#3`)');

      await openSettings(tester);
      await tapSettingsSwitch(tester, 'pref_checkmark_reverse_order');
      await leaveSettings(tester);

      expect(scope.preferences.isCheckmarkSequenceReversed, isTrue,
          reason: 'settings.preferences.checkmark-reverse-order: the row '
              'writes the preference and fires onCheckmarkSequenceChanged');
      final double buttonAfter = _buttonCentreX(tester, today);
      expect(buttonAfter, isNot(closeTo(buttonBefore, ListHeader.columnWidth)),
          reason: 'ButtonPanelView re-inflates its buttons in reverse order, '
              'so today has moved to the other end of the strip');
      expect(_labelCentreX(tester, today) - buttonAfter, closeTo(gap, 0.5),
          reason: 'audit3.flipping-reverse-order-of-days-leaves#1: both halves '
              'of the row react to the same notification — ButtonPanelView '
              're-inflates its buttons and HeaderView recomputes its scroll '
              'direction and repaints, so labels and buttons always agree. '
              'ListHeader is handed isCheckmarkSequenceReversed as a '
              'constructor argument and registers no listener, so the label '
              'over a button stops being that button\'s date until something '
              'unrelated rebuilds the screen.');
    });
  });
}

/// The window x of the entry button standing for [date], read off the running
/// list row.
double _buttonCentreX(WidgetTester tester, LocalDate date) =>
    tester.getCenter(find.byKey(EntryPanel.buttonKey(date))).dx;

/// The window x of the day number [date] is drawn with in the date strip.
///
/// The strip is a core `View` on a `CoreView`, so it is replayed onto a
/// recording canvas the size of the header — the same technique
/// test/ui/habits/list/list_header_test.dart uses to read a golden back.
double _labelCentreX(WidgetTester tester, LocalDate date) {
  final Finder header = find.byType(ListHeader);
  final Size size = tester.getSize(header);
  final _RecordingCanvas canvas =
      _RecordingCanvas(width: size.width, height: size.height);
  tester
      .widget<CoreView>(
        find.descendant(of: header, matching: find.byType(CoreView)),
      )
      .view
      .draw(canvas);
  return tester.getTopLeft(header).dx + canvas.xOf(date.day.toString());
}

/// A [Canvas] that logs where each string was drawn.
class _RecordingCanvas extends Canvas {
  _RecordingCanvas({required this.width, required this.height});

  final double width;
  final double height;

  /// Every `drawText` call, in the order it was made.
  final List<(String, double)> texts = <(String, double)>[];

  double xOf(String text) =>
      texts.firstWhere((entry) => entry.$1 == text).$2;

  @override
  double getWidth() => width;

  @override
  double getHeight() => height;

  @override
  void drawText(String text, double x, double y) => texts.add((text, x));

  /// The advance width of "m", which `HeaderView.Drawer` uses to stack its two
  /// lines. Any constant will do here: this test reads x, not y.
  @override
  double measureText(String text) => 6.0 * text.length;

  @override
  void setColor(Color color) {}

  @override
  void setFont(Font font) {}

  @override
  void setFontSize(double size) {}

  @override
  void setStrokeWidth(double size) {}

  @override
  void setTextAlign(TextAlign align) {}

  @override
  void drawLine(double x1, double y1, double x2, double y2) {}

  @override
  void drawRect(double x, double y, double width, double height) {}

  @override
  void fillRect(double x, double y, double width, double height) {}

  @override
  void fillRoundRect(
    double x,
    double y,
    double width,
    double height,
    double cornerRadius,
  ) {}

  @override
  void fillArc(
    double centerX,
    double centerY,
    double radius,
    double startAngle,
    double swipeAngle,
  ) {}

  @override
  void fillCircle(double centerX, double centerY, double radius) {}

  @override
  Image toImage() => throw UnimplementedError();
}
