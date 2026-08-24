/// `settings.preferences.widget-opacity#5`..`#8`: what the opacity preference
/// actually does to a home-screen widget.
///
/// The other four rules live elsewhere — the key, the row and its six entries
/// in test/ui/settings/settings_screen_test.dart (`#1`..`#3`), and the
/// republish-on-change in test/ui/settings/widget_opacity_refresh_test.dart
/// (`#4`). What is left is the render, and the render is native: upstream
/// `BaseWidget.preferedBackgroundAlpha` read `prefs.widgetOpacity` straight out
/// of the application component because the widget provider and the app were
/// one program. Here they are two processes, so the preference travels in the
/// published document, and the two halves are asserted the way each one can be:
///
///  * the Dart half — that `HomeWidgetBridge` puts `Preferences.widgetOpacity`
///    into every widget document — by running it;
///  * the Kotlin half — `BaseWidget`, `BaseWidgetProvider`, the six widget
///    classes and `HabitWidgetView` — by reading values out of the source set
///    that ships them, exactly as test/platform/android_widgets_test.dart does
///    and for the same reason: an `AppWidgetProvider` runs in the launcher's
///    process and `flutter test` has neither a launcher nor a JVM.
///
/// Every assertion below extracts a value and compares it. Nothing asserts that
/// a file merely mentions something.
library;

// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/time/local_date.dart'
    show LocalDate, resetToday, setToday;

// ---------------------------------------------------------------------------
// Reading the Android source set
// ---------------------------------------------------------------------------

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
  throw StateError(
    'android/app/src/main not found from ${Directory.current.path}',
  );
}

String widgetKotlin(String name) =>
    File('${androidMain.path}/kotlin/org/isoron/uhabits/widgets/$name')
        .readAsStringSync();

/// Strips `//` line comments and `/* */` blocks so an assertion cannot be
/// satisfied by prose. Every match below is made against this, never against
/// the raw text.
String withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .map((String line) {
      final int slash = line.indexOf('//');
      return slash < 0 ? line : line.substring(0, slash);
    })
    .join('\n');

/// The body of a single-expression Kotlin getter, e.g.
/// `get() = if (stacked) 255 else widgetOpacity`.
String? getterBody(String source, String property) {
  final RegExp declaration = RegExp(
    'val\\s+$property\\s*:[^\\n]*\\n\\s*get\\(\\)\\s*=\\s*([^\\n]*)',
  );
  return declaration.firstMatch(source)?.group(1)?.trim();
}

/// One `<widget>.refreshData` body, i.e. everything between `refreshData(` and
/// the next top-level `override`/`private`/end of file. Good enough to tell
/// which widget classes carry the shadow line, which is all it is used for.
String refreshDataBody(String source) {
  final int start = source.indexOf('fun refreshData(');
  if (start < 0) throw StateError('no refreshData in this widget');
  final int next = source.indexOf('\n    override fun ', start + 1);
  final int privateNext = source.indexOf('\n    private fun ', start + 1);
  int end = source.length;
  for (final int candidate in <int>[next, privateNext]) {
    if (candidate > 0 && candidate < end) end = candidate;
  }
  return source.substring(start, end);
}

// ---------------------------------------------------------------------------
// The Dart half
// ---------------------------------------------------------------------------

class _SilentPlatform implements HomeWidgetPlatform {
  final Map<String, String?> saved = <String, String?>{};

  @override
  Future<void> saveWidgetData(String id, String? value) async {
    saved[id] = value;
  }

  @override
  Future<void> setAppGroupId(String groupId) async {}

  @override
  Future<void> updateWidget({
    required String name,
    required String qualifiedAndroidName,
    required String iOSName,
  }) async {}
}

void main() {
  // The bridge stamps every document with getToday(), which needs a clock.
  setUp(() => setToday(LocalDate.ymd(2015, 1, 26)));
  tearDown(resetToday);

  // -------------------------------------------------------------------------
  // #5 — where the number comes from
  // -------------------------------------------------------------------------

  group('settings.preferences.widget-opacity#5', () {
    const String rule =
        'settings.preferences.widget-opacity#5 — BaseWidget.'
        'preferedBackgroundAlpha returns 255 when the widget is rendered '
        'inside a stack widget and prefs.widgetOpacity otherwise.';

    ({HomeWidgetBridge bridge, _SilentPlatform platform}) buildBridge(
      MemoryStorage storage,
    ) {
      final MemoryHabitList habitList = MemoryHabitList();
      final MemoryModelFactory factory = MemoryModelFactory();
      final habit = factory.buildHabit()..name = 'Meditate';
      habitList.add(habit);
      habit.recompute();
      final WidgetRegistry registry = WidgetRegistry(storage);
      registry.addWidget(7, <int>[habit.id!]);
      final _SilentPlatform platform = _SilentPlatform();
      return (
        bridge: HomeWidgetBridge(
          habitList: habitList,
          registry: registry,
          platform: platform,
          preferences: Preferences(storage),
        ),
        platform: platform,
      );
    }

    test('the preference is what crosses to the launcher\'s process', () async {
      final MemoryStorage storage = MemoryStorage();
      final built = buildBridge(storage);

      // The default first: `android:defaultValue="255"`.
      expect(built.bridge.widgetOpacity, 255,
          reason: '$rule Unset, the preference is 255.');
      expect(HomeWidgetBridge.defaultWidgetOpacity, 255, reason: rule);

      await built.bridge.publish();
      Map<String, Object?> documentFor(int widgetId) =>
          jsonDecode(built.platform.saved[HomeWidgetBridge.documentKey(widgetId)]!)
              as Map<String, Object?>;
      expect(documentFor(7)['widgetOpacity'], 255, reason: rule);

      // …and every other entry of the list preference, verbatim.
      for (final int alpha in <int>[204, 153, 102, 51, 0]) {
        Preferences(storage).widgetOpacity = alpha;
        expect(built.bridge.widgetOpacity, alpha,
            reason: '$rule prefs.widgetOpacity, not a constant.');
        await built.bridge.publish();
        expect(documentFor(7)['widgetOpacity'], alpha,
            reason: '$rule …and that is what the widget document carries.');
      }
    });

    test('a bridge with no preferences publishes the default', () async {
      // The hosts that publish habit data and nothing else — every widget test
      // — must still produce a document a widget can render.
      final MemoryStorage storage = MemoryStorage();
      final MemoryHabitList habitList = MemoryHabitList();
      final WidgetRegistry registry = WidgetRegistry(storage);
      registry.addWidget(1, <int>[]);
      final _SilentPlatform platform = _SilentPlatform();
      final HomeWidgetBridge bridge = HomeWidgetBridge(
        habitList: habitList,
        registry: registry,
        platform: platform,
      );

      expect(bridge.widgetOpacity, 255, reason: rule);
      await bridge.publish();
      final Map<String, Object?> document = jsonDecode(
        platform.saved[HomeWidgetBridge.documentKey(1)]!,
      ) as Map<String, Object?>;
      expect(document['widgetOpacity'], 255, reason: rule);
    });

    test('the launcher side reads it and hands it to the widget', () {
      final String data = withoutComments(widgetKotlin('WidgetData.kt'));
      expect(
        data.contains(
          'widgetOpacity = json.optInt("widgetOpacity", DEFAULT_WIDGET_OPACITY)',
        ),
        isTrue,
        reason: '$rule The document field is parsed…',
      );
      expect(
        RegExp(r'const val DEFAULT_WIDGET_OPACITY\s*=\s*(\d+)')
            .firstMatch(data)
            ?.group(1),
        '255',
        reason: '$rule …with the preference\'s own default when a document '
            'written before the field existed carries no key.',
      );

      final String provider =
          withoutComments(widgetKotlin('BaseWidgetProvider.kt'));
      expect(
        provider.contains('setWidgetOpacity(document.widgetOpacity)'),
        isTrue,
        reason: '$rule Every widget the provider builds is given the '
            'document\'s value before it is drawn.',
      );
    });

    test('preferedBackgroundAlpha is the branch upstream wrote', () {
      final String base = withoutComments(widgetKotlin('BaseWidget.kt'));
      expect(
        getterBody(base, 'preferedBackgroundAlpha'),
        'if (stacked) 255 else widgetOpacity',
        reason: rule,
      );
      expect(
        RegExp(r'private var widgetOpacity: Int = (\S+)')
            .firstMatch(base)
            ?.group(1),
        'WidgetDocument.DEFAULT_WIDGET_OPACITY',
        reason: '$rule Until the document says otherwise, the preference\'s '
            'default stands.',
      );
    });
  });

  // -------------------------------------------------------------------------
  // #6 — what the number touches
  // -------------------------------------------------------------------------

  group('audit16.widget-opacity-never-reaches-ios', () {
    const String iosRule =
        'audit16.widget-opacity-never-reaches-ios#1 — the preference dims the '
        "widget's card on every platform the app ships on. On iOS the card is "
        'the extension\'s `containerBackground`, and the extension reads only '
        'the index document, so the alpha has to be published there and used '
        'there.';

    test('the index carries the opacity', () {
      final MemoryStorage storage = MemoryStorage();
      Preferences(storage).widgetOpacity = 102;
      final MemoryHabitList habitList = MemoryHabitList();
      final habit = MemoryModelFactory().buildHabit()..name = 'Meditate';
      habitList.add(habit);
      habit.recompute();
      final HomeWidgetBridge bridge = HomeWidgetBridge(
        habitList: habitList,
        registry: WidgetRegistry(storage),
        platform: _SilentPlatform(),
        preferences: Preferences(storage),
      );

      expect(bridge.buildIndexDocument()['widgetOpacity'], 102,
          reason: '$iosRule An iOS widget has no widget id, so the per-widget '
              'document it never opens is the wrong place for it.');
    });

    test('the extension declares and applies it', () {
      final String swift =
          File('ios/HabitsWidget/WidgetData.swift').readAsStringSync();
      expect(swift, contains(RegExp(r'let widgetOpacity\s*:')),
          reason: '$iosRule WidgetIndex has to decode the field…');
      expect(swift, contains('func widgetOpacity('),
          reason: '$iosRule …and WidgetStore has to expose it to the views.');

      final String card =
          File('ios/HabitsWidget/WidgetCard.swift').readAsStringSync();
      expect(card, contains('opacity'),
          reason: '$iosRule …which the card chrome applies, the way '
              'HabitWidgetView.rebuildBackground applies backgroundAlpha.');
    });
  });

  group('settings.preferences.widget-opacity#6', () {
    const String rule =
        'settings.preferences.widget-opacity#6 — The opacity is applied as the '
        'alpha of the widget card\'s background paint only; text, rings and '
        'charts are not made transparent.';

    test('the alpha reaches exactly one paint', () {
      final String view =
          withoutComments(widgetKotlin('views/HabitWidgetView.kt'));

      // Every use of the stored alpha in the card view, in order: the field,
      // the setter's parameter, the assignment into the field, and the one
      // place it is spent.
      final List<String> uses = RegExp(r'^.*\bbackgroundAlpha\b.*$',
              multiLine: true)
          .allMatches(view)
          .map((RegExpMatch m) => m.group(0)!.trim())
          .toList();
      expect(
        uses,
        <String>[
          'private var backgroundAlpha: Int = 0',
          'fun setBackgroundAlpha(backgroundAlpha: Int) {',
          'this.backgroundAlpha = backgroundAlpha',
          'backgroundPaint?.alpha = backgroundAlpha',
        ],
        reason: '$rule The only thing it is ever assigned to is the card '
            'background paint.',
      );

      // …and that paint is the card's, built in rebuildBackground from the
      // RoundRectShape drawable the frame's background is set to.
      expect(view.contains('backgroundPaint = innerDrawable.paint'), isTrue,
          reason: '$rule "the widget card\'s background paint".');
      expect(view.contains('frame?.background = cardBackground'), isTrue,
          reason: rule);
    });

    test('no other widget view touches it', () {
      // If a chart or a ring view were dimmed too, it would have to reach the
      // alpha somehow. None of them can: nothing outside HabitWidgetView names
      // it.
      final Directory views = Directory(
        '${androidMain.path}/kotlin/org/isoron/uhabits/widgets/views',
      );
      final List<String> offenders = <String>[];
      for (final FileSystemEntity entity in views.listSync()) {
        if (entity is! File || !entity.path.endsWith('.kt')) continue;
        if (entity.path.endsWith('HabitWidgetView.kt')) continue;
        final String source = withoutComments(entity.readAsStringSync());
        if (source.contains('backgroundAlpha')) {
          offenders.add(entity.uri.pathSegments.last);
        }
      }
      expect(offenders, isEmpty,
          reason: '$rule The ring, the history grid, the bar chart and the '
              'labels are drawn with their own paints, which never see it.');
    });
  });

  // -------------------------------------------------------------------------
  // #7 — the widgets that ignore it
  // -------------------------------------------------------------------------

  group('settings.preferences.widget-opacity#7', () {
    const String rule =
        'settings.preferences.widget-opacity#7 — Widgets rendered inside a '
        'StackWidget ignore this preference and always use alpha 255.';

    test('every page of a stack is built stacked', () {
      final String service =
          withoutComments(widgetKotlin('StackWidgetService.kt'));
      final Iterable<RegExpMatch> branches =
          RegExp(r'StackWidgetType\.(\w+) -> (\w+)\(([^)]*)\)')
              .allMatches(service);
      final Map<String, String> stackedArgument = <String, String>{
        for (final RegExpMatch m in branches)
          m.group(1)!: m.group(3)!.split(',').last.trim(),
      };

      expect(
        stackedArgument,
        <String, String>{
          'CHECKMARK': 'true',
          'FREQUENCY': 'true',
          'SCORE': 'true',
          'HISTORY': 'true',
          'STREAKS': 'true',
          'TARGET': 'true',
        },
        reason: '$rule All six page types are constructed with stacked = true, '
            'and `if (stacked) 255` is what that buys.',
      );

      expect(service.contains('setWidgetOpacity'), isFalse,
          reason: '$rule The service never even hands a page the preference — '
              'the branch would discard it anyway.');
    });

    test('the default of the six widget classes is not stacked', () {
      // A widget the launcher hosts directly takes the preference; only the
      // pages of a stack opt out, and they do it explicitly.
      for (final String name in <String>[
        'CheckmarkWidget.kt',
        'HistoryWidget.kt',
        'ScoreWidget.kt',
        'StreakWidget.kt',
        'FrequencyWidget.kt',
        'TargetWidget.kt',
      ]) {
        final String source = withoutComments(widgetKotlin(name));
        expect(
          RegExp(r'stacked: Boolean = (\w+)').firstMatch(source)?.group(1),
          'false',
          reason: '$rule $name',
        );
      }
      final String stack = withoutComments(widgetKotlin('StackWidget.kt'));
      expect(
        RegExp(r'stacked: Boolean = (\w+)').firstMatch(stack)?.group(1),
        'true',
        reason: '$rule The StackWidget itself is stacked too.',
      );
    });
  });

  // -------------------------------------------------------------------------
  // #8 — the shadow that only full opacity gets
  // -------------------------------------------------------------------------

  group('settings.preferences.widget-opacity#8', () {
    const String rule =
        'settings.preferences.widget-opacity#8 — At alpha 255 the widget '
        'additionally gains a drop shadow (shadow alpha 0x4f); below 255 the '
        'graph widgets have no shadow.';

    test('the five graph widgets gate the shadow on full opacity', () {
      for (final String name in <String>[
        'HistoryWidget.kt',
        'ScoreWidget.kt',
        'StreakWidget.kt',
        'FrequencyWidget.kt',
        'TargetWidget.kt',
      ]) {
        final String body =
            withoutComments(refreshDataBody(widgetKotlin(name)));
        expect(
          body.contains('setBackgroundAlpha(preferedBackgroundAlpha)'),
          isTrue,
          reason: '$rule $name paints its card at the preference…',
        );
        expect(
          body.contains(
            'if (preferedBackgroundAlpha >= 255) setShadowAlpha(0x4f)',
          ),
          isTrue,
          reason: '$rule …and asks for the 0x4f shadow only when that is 255. '
              '($name)',
        );
      }
    });

    test('the checkmark widget is not one of them', () {
      // `widgets.card-chrome#7`: CheckmarkWidgetView calls setShadowAlpha(0x4f)
      // unconditionally from refresh(), which is exactly why the rule says
      // "the graph widgets".
      final String widget = withoutComments(widgetKotlin('CheckmarkWidget.kt'));
      expect(widget.contains('setShadowAlpha'), isFalse,
          reason: '$rule The Checkmark widget has no opacity-gated shadow…');
      final String view =
          withoutComments(widgetKotlin('views/CheckmarkWidgetView.kt'));
      expect(view.contains('setShadowAlpha(0x4f)'), isTrue,
          reason: '$rule …because its view sets one unconditionally, so it '
              'keeps its shadow at every alpha.');
      expect(view.contains('preferedBackgroundAlpha'), isFalse,
          reason: '$rule and the call is not gated on the alpha.');
    });

    test('the shadow the theme starts from is nothing at all', () {
      // Without the >= 255 branch the card has WidgetTheme's shadow alpha,
      // which is 0 — i.e. no shadow, which is what "have no shadow" means.
      final String view =
          withoutComments(widgetKotlin('views/HabitWidgetView.kt'));
      expect(
        view.contains(
          'private var shadowAlpha: Int = (255 * WidgetTheme.WIDGET_SHADOW_ALPHA).toInt()',
        ),
        isTrue,
        reason: rule,
      );
      final String theme = withoutComments(widgetKotlin('WidgetTheme.kt'));
      expect(
        RegExp(r'WIDGET_SHADOW_ALPHA[^=\n]*=\s*([0-9.ef]+)')
            .firstMatch(theme)
            ?.group(1),
        anyOf(<String>['0.0', '0f', '0.0f', '0']),
        reason: '$rule 255 * 0 = 0: a widget that does not ask for the 0x4f '
            'shadow has none.',
      );
    });
  });
}
