/// Journey: the user turns on "Show question marks for missing data", places a
/// Checkmark widget, and the widget is told about it.
///
/// `audit5.checkmark-home-screen-widget-never-draws` — the Interface preference
/// whose own summary is "Differentiate days without data from actual lapses"
/// reached the habit list, the detail screen and the entry dialogs, and stopped
/// at the process boundary: `buildIndexDocument` published
/// `areQuestionMarksEnabled` for the iOS habit catalogue, but the per-widget
/// document a placed widget actually reads never carried it. Both native
/// renderers therefore fell back to the preference's own default and drew "✗"
/// on a day the user had never answered — the exact thing the preference exists
/// to stop.
///
/// ## Why this is a journey
///
/// The defect is not "the encoder forgot a field": it is that nothing in the
/// shipped app ever handed that field across. A bridge unit test that builds a
/// [HomeWidgetBridge] with a preferences object of its own can be made to pass
/// while the running app still publishes nothing — which is exactly how this
/// survived four audits. So this starts at `AppScope.boot()`, flips the row in
/// Settings the way a finger does, places a widget through the
/// `uhabits://widget/configure` deep link that is the port of
/// `HabitPickerDialog`, and reads the JSON that crossed the `home_widget`
/// method channel.
library;

// The core's models and time helpers are reached by their `src` path, exactly
// as lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits/ui/common/dialogs/widget_picker_dialog.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import 'journey.dart';

const String rule1 =
    'audit5.checkmark-home-screen-widget-never-draws#1 — In the Kotlin app: '
    '`CheckmarkWidgetView` holds a live `Preferences` (resolved in `init()` '
    'from the application component) and reads it every time it redraws. For a '
    'boolean habit whose today entry is UNKNOWN (-1), the glyph is '
    '`R.string.fa_question` when `preferences.areQuestionMarksEnabled` is true '
    'and `R.string.fa_times` otherwise. So a user who turns on the Interface '
    'preference "Show question marks for missing data" — whose own summary is '
    '"Differentiate days without data from actual lapses" — sees "?" on the '
    'home-screen Checkmark widget for a day with no data, and "✗" only for a '
    'day they explicitly marked as a lapse.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  setUp(() {
    device = TestDevice.create('uhabits_journey_widget_question_marks');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

  /// The most recent `HomeWidget.saveWidgetData(key, …)` payload, decoded.
  Map<String, Object?>? published(String key) {
    for (final MethodCall call in device.homeWidgetCalls.reversed) {
      if (call.method != 'saveWidgetData') continue;
      final Map<Object?, Object?> arguments =
          call.arguments as Map<Object?, Object?>;
      if (arguments['id'] != key) continue;
      final Object? data = arguments['data'];
      if (data == null) return null;
      return jsonDecode(data as String) as Map<String, Object?>;
    }
    return null;
  }

  /// The document a placed widget reads.
  Map<String, Object?> widgetDocument(int widgetId) {
    final Map<String, Object?>? document =
        published(HomeWidgetBridge.documentKey(widgetId));
    expect(document, isNotNull,
        reason: 'the app has to have published a document for widget '
            '$widgetId; without one the launcher draws the "open Loop Habit '
            'Tracker to set up this widget" card');
    return document!;
  }

  /// A `uhabits://widget/...` deep link, delivered the way the launcher
  /// delivers it.
  Future<void> deliverWidgetLink(WidgetTester tester, String uri) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      homeWidgetUpdatesChannelName,
      const StandardMethodCodec().encodeSuccessEnvelope(uri),
      (ByteData? _) {},
    );
    await settleIo(tester);
  }

  /// The user drops a widget on the home screen and picks a habit for it.
  Future<void> placeWidget(
    WidgetTester tester, {
    required int widgetId,
    required String habit,
  }) async {
    await deliverWidgetLink(
      tester,
      'uhabits://widget/configure?widgetId=$widgetId&filter=all',
    );
    expect(find.byType(WidgetPickerDialog), findsOneWidget,
        reason: 'the configure link has to open the habit picker');
    await tester.tap(find.descendant(
      of: find.byType(WidgetPickerDialog),
      matching: find.text(habit),
    ));
    await settleIo(tester);
  }

  // =======================================================================
  // The preference has to reach the widget that draws it
  // =======================================================================

  testWidgets('a Checkmark widget placed after the preference is turned on is '
      'told about it', (WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(tester, name: 'Meditate');

    // The row the user taps, and the only way any user can get there.
    await openSettings(tester);
    await tapSettingsRow(tester, 'pref_unknown_enabled');
    await pressBack(tester);
    await settleIo(tester);

    await placeWidget(tester, widgetId: 1, habit: 'Meditate');

    expect(app.scope.preferences.areQuestionMarksEnabled, isTrue,
        reason: 'the precondition: the Settings row has to have written the '
            'preference, or the assertion below would be vacuous');

    final Map<String, Object?> document = widgetDocument(1);
    expect(
      document['areQuestionMarksEnabled'],
      isTrue,
      reason: '$rule1 The widget runs outside the Flutter engine and cannot '
          'read Preferences; the per-widget document is the only thing it has, '
          'so a flag that is not in it is a flag the renderer can never honour.',
    );

    // …and the habit it is bound to really is on an unanswered day, which is
    // the only state the flag changes.
    final Map<String, Object?> habit =
        (document['habits']! as List<Object?>).single! as Map<String, Object?>;
    expect(habit['value'], Entry.unknown,
        reason: '$rule1 the glyph only differs for a today entry of UNKNOWN '
            '(-1): a day with data draws its own mark either way');
  });

  testWidgets('and a widget already on the home screen learns about it when '
      'the user turns it on', (WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(tester, name: 'Meditate');
    await placeWidget(tester, widgetId: 1, habit: 'Meditate');

    expect(
      widgetDocument(1)['areQuestionMarksEnabled'],
      isFalse,
      reason: '$rule1 With the preference off the widget draws '
          '`R.string.fa_times`, and the document has to say so explicitly — a '
          'missing key is indistinguishable from "this build does not publish '
          'it".',
    );

    await openSettings(tester);
    await tapSettingsRow(tester, 'pref_unknown_enabled');
    await pressBack(tester);
    await settleIo(tester);
    // Any command republishes every widget; the preference is read at publish
    // time, on a day that is not today so the entry for today stays UNKNOWN.
    await toggleCheckmark(tester, 'Meditate', getToday().minus(3));

    expect(
      widgetDocument(1)['areQuestionMarksEnabled'],
      isTrue,
      reason: '$rule1 Upstream the view holds a live `Preferences` and reads it '
          'on every redraw, so turning the row on changes what the home screen '
          'shows. Here the equivalent is that the value is read at publish '
          'time rather than captured when the widget was placed.',
    );
    expect(
      (widgetDocument(1)['habits']! as List<Object?>).single!
          as Map<String, Object?>,
      containsPair('value', Entry.unknown),
      reason: '$rule1 today is still the day with no data',
    );
  });

  testWidgets('the iOS habit catalogue and the bound document agree',
      (WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(tester, name: 'Meditate');
    await openSettings(tester);
    await tapSettingsRow(tester, 'pref_unknown_enabled');
    await pressBack(tester);
    await settleIo(tester);
    await placeWidget(tester, widgetId: 1, habit: 'Meditate');

    expect(
      widgetDocument(1)['areQuestionMarksEnabled'],
      published(HomeWidgetBridge.indexKey)!['areQuestionMarksEnabled'],
      reason: '$rule1 The index already carried the flag for the iOS habit '
          'catalogue while the per-widget document did not, so the same widget '
          'drew "?" when it was resolved out of the catalogue and "✗" when it '
          'was resolved out of its own document. One preference, one answer.',
    );
  });
}
