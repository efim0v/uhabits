/// `audit5.checkmark-widget-always-draws-for-an`: the glyph a Checkmark
/// home-screen widget draws on a day the user never answered.
///
/// Upstream `CheckmarkWidgetView` holds the app's live `Preferences` and its
/// `text` getter reads it on every redraw, so an `UNKNOWN` entry is `?` when
/// the user has turned question marks on and `✗` when they have not. The port
/// kept the branch — `if (areQuestionMarksEnabled) FontAwesome.QUESTION else
/// FontAwesome.TIMES` — and then never assigned the flag: `var
/// areQuestionMarksEnabled = false` on the view, nothing in
/// `CheckmarkWidget.refreshData`, nothing in the document. The branch was dead
/// code and every unanswered day was drawn as a lapse.
///
/// The Swift half had the same hole, spelled out in a comment: "that preference
/// is not part of the published contract, so the widget always takes the
/// `fa_times` branch".
///
/// ## Why this test asserts source text
///
/// Both renderers run outside the Flutter engine — an `AppWidgetProvider` in
/// the launcher's process, a WidgetKit extension in its own — so neither is
/// reachable from a Flutter harness: there is no way to instantiate a
/// `CheckmarkWidgetView` or a `CheckmarkWidgetView: View` from Dart and read
/// back the glyph it drew. What a Dart test can do is hold the two sides of the
/// contract together: that the flag is parsed out of the document the app
/// publishes, that it reaches the view before the view is drawn, and that the
/// branch reading it is the one upstream has. The half that *is* reachable —
/// the app publishing the flag at all — is
/// test/journeys/widget_question_marks_journey_test.dart, which drives the
/// running app.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Locating the source sets
// ---------------------------------------------------------------------------

final Directory appDir = _findApp();
final Directory widgetKotlinDir = Directory(
    '${appDir.path}/android/app/src/main/kotlin/org/isoron/uhabits/widgets');
final Directory iosWidgetDir = Directory('${appDir.path}/ios/HabitsWidget');

Directory _findApp() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String prefix in <String>['', '/app']) {
      final Directory candidate = Directory('${dir.path}$prefix');
      if (File('${candidate.path}/ios/HabitsWidget/CheckmarkWidget.swift')
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

String widgetKotlin(String name) =>
    File('${widgetKotlinDir.path}/$name').readAsStringSync();

String widgetViewKotlin(String name) =>
    File('${widgetKotlinDir.path}/views/$name').readAsStringSync();

String swift(String name) =>
    File('${iosWidgetDir.path}/$name').readAsStringSync();

/// [source] with its comments stripped, so an assertion about what the code
/// does cannot be satisfied — or defeated — by prose that merely names the
/// thing. Same helper, same reason, as android_widgets_test.dart.
String withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// [source] with every run of whitespace collapsed to one space, so an
/// assertion is about the code and not about where the formatter chose to
/// wrap it.
String squashed(String source) => source
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll('( ', '(')
    .replaceAll(' )', ')');

const String rule1 =
    'audit5.checkmark-widget-always-draws-for-an#1 — In the Kotlin app: The '
    'widget view holds the app\'s `Preferences` and, for a boolean habit whose '
    'entry for today is `UNKNOWN`, draws `fa_question` (?) when the user has '
    'turned on question marks in Settings, and `fa_times` (✗) otherwise. An '
    'unanswered day is therefore visually distinct from a day the user '
    'explicitly answered "No".';

void main() {
  group('audit5.checkmark-widget-always-draws-for-an', () {
    // -------------------------------------------------------------------
    // Android: document -> widget -> view
    // -------------------------------------------------------------------

    test('#1 the document carries the preference', () {
      final String data = squashed(withoutComments(widgetKotlin('WidgetData.kt')));

      expect(data, contains('val areQuestionMarksEnabled: Boolean'),
          reason: '$rule1 The launcher process cannot read `Preferences`; the '
              'per-widget document is the only channel, so `WidgetDocument` '
              'has to carry the flag.');
      expect(
        data,
        contains('areQuestionMarksEnabled = json.optBoolean('
            '"areQuestionMarksEnabled", DEFAULT_QUESTION_MARKS_ENABLED)'),
        reason: '$rule1 Read defensively, like every other preference on this '
            'document: a widget outlives an app update for as long as it sits '
            'on the home screen, and a document written before the field '
            'existed has to keep drawing the preference\'s own default.',
      );
      expect(data, contains('const val DEFAULT_QUESTION_MARKS_ENABLED = false'),
          reason: '$rule1 …and that default is the preference\'s own: '
              'question marks off, so an unanswered day is a cross.');
    });

    test('#1 refreshData hands the flag to the view', () {
      final String widget = withoutComments(widgetKotlin('CheckmarkWidget.kt'));
      final String body =
          widget.substring(widget.indexOf('override fun refreshData'));

      expect(
          body,
          contains('areQuestionMarksEnabled = '
              'this@CheckmarkWidget.areQuestionMarksEnabled'),
          reason: '$rule1 Upstream the view reads a live `Preferences` on every '
              'redraw. Here the value crosses a process boundary, so the widget '
              'has to push it into the view before `refresh()` — a flag that is '
              'set after the draw is a flag that changes nothing. The qualifier '
              'is load-bearing: inside `apply` the bare name on the right would '
              'resolve to the view\'s own property and the statement would be a '
              'self-assignment.');
      expect(
        body.indexOf('areQuestionMarksEnabled ='),
        lessThan(body.indexOf('refresh()')),
        reason: '$rule1 …and before `refresh()`, which is what reads it.',
      );
      expect(
        widget,
        contains('private val areQuestionMarksEnabled: Boolean'),
        reason: '$rule1 The widget takes it as construction data, the way it '
            'takes `today`: the provider reads it off the document once and '
            'every page of a stack gets the same one.',
      );
    });

    test('#1 both places that build a Checkmark widget pass it', () {
      expect(
        withoutComments(widgetKotlin('CheckmarkWidgetProvider.kt')),
        contains('document.areQuestionMarksEnabled'),
        reason: '$rule1 The ordinary one-habit widget.',
      );
      expect(
        withoutComments(widgetKotlin('StackWidgetService.kt')),
        contains('StackWidgetType.CHECKMARK -> CheckmarkWidget('),
        reason: '$rule1 …and a page of a Checkmark stack, which draws the same '
            'view and must not disagree with the standalone widget.',
      );
      expect(
        RegExp(r'StackWidgetType\.CHECKMARK -> CheckmarkWidget\([^)]*'
                r'areQuestionMarksEnabled')
            .hasMatch(withoutComments(widgetKotlin('StackWidgetService.kt'))),
        isTrue,
        reason: '$rule1 A stack page built without the flag is the same defect '
            'one layer down.',
      );
    });

    test('#1 the view still branches on it, and no longer defaults it away',
        () {
      final String view =
          withoutComments(widgetViewKotlin('CheckmarkWidgetView.kt'));

      expect(
        view,
        contains('if (areQuestionMarksEnabled) FontAwesome.QUESTION '
            'else FontAwesome.TIMES'),
        reason: '$rule1 The UNKNOWN branch itself, unchanged.',
      );
      expect(
        view,
        isNot(contains('var areQuestionMarksEnabled = false')),
        reason: '$rule1 A `var` initialised to false and assigned by nobody is '
            'what made the branch above dead code. It has to be settable data '
            'the widget pushes in, not a constant wearing a `var`.',
      );
      expect(view, contains('var areQuestionMarksEnabled: Boolean = false'),
          reason: '$rule1 Still false until it is set — a view inflated by the '
              'layout editor has no document behind it — but now set.');
    });

    // -------------------------------------------------------------------
    // iOS: the same preference, the same glyph
    // -------------------------------------------------------------------

    test('#1 the WidgetKit card draws the question mark too', () {
      final String source = squashed(swift('CheckmarkWidget.swift'));
      final String body = source.substring(source.indexOf('static func glyph'));

      expect(
        body,
        contains('case EntryValue.unknown:'),
        reason: '$rule1 UNKNOWN had been folded into the `default:` arm '
            'together with NO, which is precisely the distinction the '
            'preference exists to draw.',
      );
      expect(
        body,
        contains('areQuestionMarksEnabled ? .symbol("questionmark") '
            ': .symbol("xmark")'),
        reason: '$rule1 `fa_question` (f128) is replaced one for one by the SF '
            'Symbol `questionmark`, as the other three glyphs already are.',
      );
      expect(
        source,
        contains('CheckmarkState.glyph(habit, areQuestionMarksEnabled:'),
        reason: '$rule1 …and the caller has to supply it, or the branch is '
            'unreachable on this platform as well.',
      );
    });

    test('#1 the extension reads the preference the app published', () {
      final String store = squashed(swift('WidgetData.swift'));
      final String timeline = squashed(swift('HabitTimeline.swift'));

      expect(
        store,
        contains('func areQuestionMarksEnabled() -> Bool'),
        reason: '$rule1 `WidgetIndex` already decoded the flag for '
            '`stageToggle`; the drawing side needs the same accessor rather '
            'than a second copy of the default.',
      );
      expect(
        timeline,
        contains('let areQuestionMarksEnabled: Bool'),
        reason: '$rule1 The timeline entry is what the view is handed, so the '
            'flag rides on it next to `today` — both are app state the '
            'extension cannot compute.',
      );
      expect(
        timeline,
        contains('areQuestionMarksEnabled: store.areQuestionMarksEnabled()'),
        reason: '$rule1 …read at entry time, so a timeline rebuilt after the '
            'user flips the row in Settings draws the new glyph.',
      );
    });
  });
}
