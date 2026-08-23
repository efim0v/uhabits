/// The Android half of the home-screen widgets, asserted from the source set
/// that ships it.
///
/// ## Why a test reads files instead of running code
///
/// `app/android/app/src/main/` is a real Android application: six
/// `AppWidgetProvider` receivers, their `appwidget-provider` declarations, the
/// `RemoteViews` layouts they push and the Kotlin views that rasterise into
/// them. None of it can execute here — an `AppWidgetProvider` runs in the
/// launcher's process, and `flutter test` has neither a launcher nor a JVM.
/// Upstream asserted these rules with instrumentation (`CheckmarkWidgetTest`
/// and friends, whose `testIsInstalled` looks the provider up in
/// `AppWidgetManager.installedProviders`); this project has no Android test
/// harness, and standing one up is a separate slice.
///
/// What is left is still worth pinning, and it is not nothing: the great
/// majority of the `widgets.*` rules describe **declarations** — an attribute
/// in `widget_checkmark_info.xml`, a corner radius in a drawable, a default
/// size, a palette entry, the order two `RemoteViews` are built in. Those are
/// facts about files in this repository, and a test that parses the file and
/// compares the value catches the same regressions the instrumentation would:
/// a widget that silently stops being resizable, a palette that drifts from the
/// core's, a provider dropped from the manifest.
///
/// So every assertion below extracts a *value* and compares it. Nothing here
/// asserts that a file merely mentions something — that would pass for a source
/// comment and prove nothing.
///
/// ## What this file deliberately does not claim
///
/// - The six `widget_preview_*` bitmaps (rule 5 of `widgets.registration`) and
///   the `StackWidgetService` with everything behind it (rule 7 of the same
///   feature, plus the two `widgets.stack` features) are not reproduced by the
///   port; see the comments in the manifest and in `HabitPickerDialog`. Their
///   rule ids are deliberately not written out anywhere in this file, so the
///   coverage tool keeps reporting them as the open work they are.
/// - Anything that only exists while Android is running it — the measure
///   passes, the background thread, the `PendingIntent` the launcher holds — is
///   out of reach and stays uncited.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Reading the source set
// ---------------------------------------------------------------------------

/// The `android/app/src/main` directory of the Flutter app.
///
/// Found by walking up from the test's working directory rather than assuming
/// one, so the file works whether `flutter test` is invoked from `app/` or from
/// the repository root.
final Directory androidMain = _findAndroidMain();

Directory _findAndroidMain() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    final Directory candidate =
        Directory('${dir.path}/android/app/src/main');
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

String androidSource(String relative) =>
    File('${androidMain.path}/$relative').readAsStringSync();

String widgetKotlin(String name) =>
    androidSource('kotlin/org/isoron/uhabits/widgets/$name');

String widgetViewKotlin(String name) =>
    androidSource('kotlin/org/isoron/uhabits/widgets/views/$name');

/// Everything between `<tag` and the matching `>` or `</tag>`, for every
/// occurrence of [tag].
///
/// The XML in this source set is hand-written and shallow — no same-tag
/// nesting except `<item>` inside a layer-list, which is handled by taking the
/// outermost block — so a scan is enough and pulling in an XML parser would buy
/// nothing.
List<String> xmlBlocks(String xml, String tag) {
  final List<String> blocks = <String>[];
  final RegExp open = RegExp('<$tag(?=[\\s/>])');
  int from = 0;
  while (true) {
    final RegExpMatch? match = open.firstMatch(xml.substring(from));
    if (match == null) break;
    final int start = from + match.start;
    final int selfClose = xml.indexOf('/>', start);
    final int gt = xml.indexOf('>', start);
    final int close = xml.indexOf('</$tag>', start);
    if (selfClose >= 0 && selfClose + 1 == gt) {
      blocks.add(xml.substring(start, gt + 1));
      from = gt + 1;
    } else if (close >= 0) {
      blocks.add(xml.substring(start, close + tag.length + 3));
      from = close + tag.length + 3;
    } else {
      blocks.add(xml.substring(start, gt + 1));
      from = gt + 1;
    }
  }
  return blocks;
}

/// The attributes of the first tag in [block].
Map<String, String> xmlAttributes(String block) {
  final int end = block.indexOf('>');
  final String head = end < 0 ? block : block.substring(0, end);
  return <String, String>{
    for (final RegExpMatch m
        in RegExp(r'([\w:.-]+)\s*=\s*"([^"]*)"').allMatches(head))
      m.group(1)!: m.group(2)!,
  };
}

/// The attributes of the single element named [tag] in [xml].
Map<String, String> xmlRoot(String xml, String tag) =>
    xmlAttributes(xmlBlocks(xml, tag).single);

/// The one capture of [pattern] in [source], or a failure naming what was
/// looked for. Used to pin a value in a Kotlin file: if the declaration moves
/// or changes shape the test fails rather than quietly passing.
String capture(String source, RegExp pattern) {
  final RegExpMatch? match = pattern.firstMatch(source);
  if (match == null) {
    throw StateError('no match for ${pattern.pattern}');
  }
  return match.group(1)!;
}

/// Every capture of [pattern], in source order.
List<String> captureAll(String source, RegExp pattern) =>
    pattern.allMatches(source).map((RegExpMatch m) => m.group(1)!).toList();

/// A multi-line Kotlin argument list, one argument per entry.
///
/// Splitting on commas would cut `max(1, view.measuredWidth)` in half; the
/// sources here put one argument per line, so lines are the right unit.
List<String> argLines(String captured) => captured
    .split('\n')
    .map((String line) => line.trim().replaceAll(RegExp(r',$'), ''))
    .where((String line) => line.isNotEmpty)
    .toList();

void main() {
  // =======================================================================
  // widgets.registration — the six providers and their declarations
  // =======================================================================

  group('widgets.registration', () {
    late String manifest;
    late List<String> receivers;

    setUp(() {
      manifest = androidSource('AndroidManifest.xml');
      receivers = xmlBlocks(manifest, 'receiver');
    });

    /// The six `appwidget-provider` files, keyed by the provider that names
    /// them, so a rule about "the Frequency widget" is read from the file the
    /// Frequency receiver actually points at.
    Map<String, Map<String, String>> providerInfo() {
      final Map<String, Map<String, String>> result =
          <String, Map<String, String>>{};
      for (final String receiver in receivers) {
        final String name = xmlAttributes(receiver)['android:name']!;
        final String resource =
            xmlAttributes(xmlBlocks(receiver, 'meta-data').single)[
                'android:resource']!;
        final String file = resource.replaceFirst('@xml/', '');
        result[name.split('.').last] =
            xmlRoot(androidSource('res/xml/$file.xml'), 'appwidget-provider');
      }
      return result;
    }

    test('exactly six providers are declared, with the upstream launcher '
        'labels', () {
      final Map<String, String> labels = <String, String>{
        for (final String receiver in receivers)
          xmlAttributes(receiver)['android:name']!.split('.').last:
              xmlAttributes(receiver)['android:label']!,
      };

      expect(
        labels,
        <String, String>{
          'CheckmarkWidgetProvider': 'Checkmark',
          'HistoryWidgetProvider': 'History',
          'ScoreWidgetProvider': 'Score',
          'StreakWidgetProvider': 'Streaks',
          'FrequencyWidgetProvider': 'Frequency',
          'TargetWidgetProvider': 'Target',
        },
        reason: 'widgets.registration#1 — Exactly six app-widget providers '
            'exist and are user-installable: CheckmarkWidgetProvider (launcher '
            "label 'Checkmark'), HistoryWidgetProvider ('History'), "
            "ScoreWidgetProvider ('Score'), StreakWidgetProvider ('Streaks'), "
            "FrequencyWidgetProvider ('Frequency'), TargetWidgetProvider "
            "('Target').",
      );

      // Each name resolves to a Kotlin class in this source set, so "declared"
      // and "installable" are the same statement.
      for (final String provider in labels.keys) {
        expect(
          File('${androidMain.path}/kotlin/org/isoron/uhabits/widgets/'
                  '$provider.kt')
              .existsSync(),
          isTrue,
          reason: 'widgets.registration#1: $provider is declared in the '
              'manifest, so its class has to exist',
        );
      }
    });

    test('the Checkmark widget is 50x50dp on widget_wrapper and declares no '
        'minimum resize', () {
      final Map<String, String> info = providerInfo()['CheckmarkWidgetProvider']!;

      expect(info['android:minWidth'], '50dp',
          reason: 'widgets.registration#2 — The Checkmark widget declares '
              'minWidth=50dp and minHeight=50dp and uses layout widget_wrapper '
              'as its initial layout; it declares no '
              'minResizeWidth/minResizeHeight.');
      expect(info['android:minHeight'], '50dp',
          reason: 'widgets.registration#2');
      expect(info['android:initialLayout'], '@layout/widget_wrapper',
          reason: 'widgets.registration#2');
      expect(info.containsKey('android:minResizeWidth'), isFalse,
          reason: 'widgets.registration#2: no minResizeWidth');
      expect(info.containsKey('android:minResizeHeight'), isFalse,
          reason: 'widgets.registration#2: no minResizeHeight');
    });

    test('the five graph widgets are 100dp in every dimension on '
        'widget_graph', () {
      final Map<String, Map<String, String>> info = providerInfo();

      for (final String provider in <String>[
        'FrequencyWidgetProvider',
        'HistoryWidgetProvider',
        'ScoreWidgetProvider',
        'StreakWidgetProvider',
        'TargetWidgetProvider',
      ]) {
        expect(
          <String, String?>{
            'minWidth': info[provider]!['android:minWidth'],
            'minHeight': info[provider]!['android:minHeight'],
            'minResizeWidth': info[provider]!['android:minResizeWidth'],
            'minResizeHeight': info[provider]!['android:minResizeHeight'],
            'initialLayout': info[provider]!['android:initialLayout'],
          },
          <String, String>{
            'minWidth': '100dp',
            'minHeight': '100dp',
            'minResizeWidth': '100dp',
            'minResizeHeight': '100dp',
            'initialLayout': '@layout/widget_graph',
          },
          reason: 'widgets.registration#3 — The Frequency, History, Score, '
              'Streak and Target widgets each declare minWidth=100dp, '
              'minHeight=100dp, minResizeWidth=100dp, minResizeHeight=100dp, '
              'and use layout widget_graph as their initial layout. ($provider)',
        );
      }
    });

    test('all six declare the same resize mode, update period and category',
        () {
      final Map<String, Map<String, String>> info = providerInfo();
      expect(info, hasLength(6));

      for (final MapEntry<String, Map<String, String>> entry in info.entries) {
        expect(
          <String, String?>{
            'resizeMode': entry.value['android:resizeMode'],
            'updatePeriodMillis': entry.value['android:updatePeriodMillis'],
            'widgetCategory': entry.value['android:widgetCategory'],
          },
          <String, String>{
            'resizeMode': 'vertical|horizontal',
            'updatePeriodMillis': '3600000',
            'widgetCategory': 'home_screen',
          },
          reason: "widgets.registration#4 — All six widgets declare "
              "resizeMode='vertical|horizontal', updatePeriodMillis=3600000 "
              "(1 hour), and widgetCategory='home_screen'. (${entry.key})",
        );
      }
    });

    test('the configure activity is the picker each widget type needs', () {
      final Map<String, Map<String, String>> info = providerInfo();
      const String base = 'org.isoron.uhabits.widgets.activities';

      expect(
        <String, String?>{
          for (final MapEntry<String, Map<String, String>> e in info.entries)
            e.key: e.value['android:configure'],
        },
        <String, String>{
          'CheckmarkWidgetProvider': '$base.HabitPickerDialog',
          'FrequencyWidgetProvider': '$base.HabitPickerDialog',
          'HistoryWidgetProvider': '$base.HabitPickerDialog',
          'ScoreWidgetProvider': '$base.HabitPickerDialog',
          'StreakWidgetProvider': '$base.BooleanHabitPickerDialog',
          'TargetWidgetProvider': '$base.NumericalHabitPickerDialog',
        },
        reason: 'widgets.registration#6 — The configure activity is '
            'HabitPickerDialog for Checkmark, Frequency, History and Score; '
            'BooleanHabitPickerDialog for Streaks; NumericalHabitPickerDialog '
            'for Target.',
      );
    });

    test('every receiver is exported and filters only APPWIDGET_UPDATE', () {
      for (final String receiver in receivers) {
        final String name = xmlAttributes(receiver)['android:name']!;

        expect(xmlAttributes(receiver)['android:exported'], 'true',
            reason: 'widgets.registration#8 — Each provider receiver is '
                'exported and registers only the intent filter '
                'android.appwidget.action.APPWIDGET_UPDATE. ($name)');

        final List<String> actions = xmlBlocks(receiver, 'action')
            .map((String a) => xmlAttributes(a)['android:name']!)
            .toList();
        expect(actions, <String>['android.appwidget.action.APPWIDGET_UPDATE'],
            reason: 'widgets.registration#8: only that one filter ($name)');
      }
    });

    test('the update period is also what redraws a widget between rollovers',
        () {
      final Map<String, Map<String, String>> info = providerInfo();
      for (final Map<String, String> declaration in info.values) {
        expect(declaration['android:updatePeriodMillis'], '3600000',
            reason: 'widgets.day-rollover#5 — Independently of the alarm, each '
                'appwidget-provider declares updatePeriodMillis = 3600000, so '
                'the system also refreshes every widget roughly once an hour.');
      }
    });
  });

  // =======================================================================
  // platform-glue.manifest-components / permissions
  // =======================================================================

  group('platform-glue.manifest-components', () {
    late String manifest;

    setUp(() => manifest = androidSource('AndroidManifest.xml'));

    test('the three widget picker dialogs are exported and answer '
        'APPWIDGET_CONFIGURE', () {
      final Map<String, String> activities = <String, String>{
        for (final String activity in xmlBlocks(manifest, 'activity'))
          xmlAttributes(activity)['android:name']!: activity,
      };

      for (final String name in <String>[
        '.widgets.activities.HabitPickerDialog',
        '.widgets.activities.BooleanHabitPickerDialog',
        '.widgets.activities.NumericalHabitPickerDialog',
      ]) {
        expect(activities.containsKey(name), isTrue,
            reason: 'platform-glue.manifest-components#6 — The 3 widget picker '
                'dialogs (.widgets.activities.HabitPickerDialog, '
                '.BooleanHabitPickerDialog, .NumericalHabitPickerDialog) are '
                'exported=true, use theme Theme.AppCompat.Light.Dialog.Alert, '
                'and each declares an intent-filter for action '
                'android.appwidget.action.APPWIDGET_CONFIGURE. The port swaps '
                'the AppCompat dialog theme for the platform '
                'Theme.DeviceDefault.Dialog.Alert, because a Flutter app does '
                'not depend on AppCompat; everything else holds.');
        expect(xmlAttributes(activities[name]!)['android:exported'], 'true',
            reason: 'platform-glue.manifest-components#6: $name is exported');
        expect(
          xmlBlocks(activities[name]!, 'action')
              .map((String a) => xmlAttributes(a)['android:name'])
              .toList(),
          <String>['android.appwidget.action.APPWIDGET_CONFIGURE'],
          reason: 'platform-glue.manifest-components#6: $name filters '
              'APPWIDGET_CONFIGURE',
        );
        expect(
          xmlAttributes(activities[name]!)['android:theme'],
          endsWith('Dialog.Alert'),
          reason: 'platform-glue.manifest-components#6: a dialog-alert theme',
        );
      }
    });

    test('exactly six provider receivers carry an appwidget.provider '
        'meta-data', () {
      final List<String> receivers = xmlBlocks(manifest, 'receiver');
      expect(receivers, hasLength(6),
          reason: 'platform-glue.manifest-components#7 — Exactly 6 AppWidget '
              'provider receivers are declared, all exported=true with an '
              'APPWIDGET_UPDATE intent-filter and an android.appwidget.provider '
              'meta-data resource: CheckmarkWidgetProvider, '
              'HistoryWidgetProvider, ScoreWidgetProvider, '
              'StreakWidgetProvider, FrequencyWidgetProvider, '
              'TargetWidgetProvider. The labels are literals rather than '
              '@string resources because the port has no strings.xml.');

      for (final String receiver in receivers) {
        final Map<String, String> meta =
            xmlAttributes(xmlBlocks(receiver, 'meta-data').single);
        expect(meta['android:name'], 'android.appwidget.provider',
            reason: 'platform-glue.manifest-components#7: the meta-data name');
        expect(meta['android:resource'], startsWith('@xml/widget_'),
            reason: 'platform-glue.manifest-components#7: pointing at the '
                'appwidget-provider resource');
      }
    });

    test('the application id is still org.isoron.uhabits', () {
      // android/app/src/main -> android/app
      final String gradle =
          File('${androidMain.parent.parent.path}/build.gradle.kts')
              .readAsStringSync();

      expect(capture(gradle, RegExp(r'namespace\s*=\s*"([^"]+)"')),
          'org.isoron.uhabits',
          reason: 'platform-glue.manifest-components#12 — The applicationId / '
              'namespace is "org.isoron.uhabits". The versionCode, versionName '
              'and sdk levels come from the Flutter tool rather than from this '
              'file, so only the identity half of the rule is reproduced — but '
              'it is the half that matters: it is what content:// URIs, the '
              'App Group and every existing home-screen placement are keyed on.');
      expect(capture(gradle, RegExp(r'applicationId\s*=\s*"([^"]+)"')),
          'org.isoron.uhabits',
          reason: 'platform-glue.manifest-components#12');
    });
  });

  group('platform-glue.permissions', () {
    test('the five permissions are declared, in upstream\'s order', () {
      final String manifest = androidSource('AndroidManifest.xml');
      final List<String> declared = xmlBlocks(manifest, 'uses-permission')
          .map((String p) => xmlAttributes(p)['android:name']!)
          .toList();

      expect(
        declared,
        <String>[
          'android.permission.POST_NOTIFICATIONS',
          'android.permission.RECEIVE_BOOT_COMPLETED',
          'android.permission.SCHEDULE_EXACT_ALARM',
          'android.permission.USE_EXACT_ALARM',
          'android.permission.VIBRATE',
        ],
        reason: 'platform-glue.permissions#1 — Exactly 5 <uses-permission> '
            'entries are declared, in this order: '
            'android.permission.POST_NOTIFICATIONS, '
            'android.permission.RECEIVE_BOOT_COMPLETED, '
            'android.permission.SCHEDULE_EXACT_ALARM, '
            'android.permission.USE_EXACT_ALARM, android.permission.VIBRATE. '
            'The two exact-alarm ones are load-bearing and were missing: '
            'FlutterAlarmScheduler asks canScheduleExactAlarms() before it '
            'sets anything, so without them API 31+ schedules no reminder at '
            'all. See the slice notes.',
      );
    });

    test('no storage permission is declared', () {
      final String manifest = androidSource('AndroidManifest.xml');
      final List<String> declared = xmlBlocks(manifest, 'uses-permission')
          .map((String p) => xmlAttributes(p)['android:name']!)
          .toList();

      expect(
        declared.where((String p) => p.contains('EXTERNAL_STORAGE')),
        isEmpty,
        reason: 'platform-glue.permissions#2 — No storage permissions '
            '(READ/WRITE_EXTERNAL_STORAGE) are declared; all file output goes '
            'through app-private external dirs or SAF/DocumentFile tree URIs. '
            'The port reaches storage through path_provider, file_picker and '
            'share_plus, which need none either.',
      );
    });
  });

  // =======================================================================
  // widgets.dimensions
  // =======================================================================

  group('widgets.dimensions', () {
    test('WidgetDimensions is a four-field value object in pixels', () {
      final String source = widgetKotlin('WidgetDimensions.kt');
      final List<String> fields = captureAll(
        source,
        RegExp(r'val (\w+): Int'),
      );

      expect(
        fields,
        <String>[
          'portraitWidth',
          'portraitHeight',
          'landscapeWidth',
          'landscapeHeight',
        ],
        reason: 'widgets.dimensions#1 — WidgetDimensions is a 4-field value '
            'object: portraitWidth, portraitHeight, landscapeWidth, '
            'landscapeHeight (all in pixels).',
      );
    });

    test('getDimensionsFromOptions maps the four option ints through dp and '
        'crosses them', () {
      final String source = widgetKotlin('BaseWidgetProvider.kt');
      final String body = source.substring(
        source.indexOf('fun getDimensionsFromOptions'),
        source.indexOf('private fun getWidgetFromId'),
      );

      // Every one of the four options is read, and each goes through dpToPixels.
      for (final String option in <String>[
        'OPTION_APPWIDGET_MAX_WIDTH',
        'OPTION_APPWIDGET_MAX_HEIGHT',
        'OPTION_APPWIDGET_MIN_WIDTH',
        'OPTION_APPWIDGET_MIN_HEIGHT',
      ]) {
        expect(
          body,
          contains('AppWidgetManager.$option'),
          reason: 'widgets.dimensions#2 — getDimensionsFromOptions reads the '
              'four AppWidgetManager option ints OPTION_APPWIDGET_MAX_WIDTH, '
              'OPTION_APPWIDGET_MAX_HEIGHT, OPTION_APPWIDGET_MIN_WIDTH, '
              'OPTION_APPWIDGET_MIN_HEIGHT (which are in dp), converts each to '
              'pixels via dpToPixels, and returns WidgetDimensions(portraitWidth '
              '= minWidth, portraitHeight = maxHeight, landscapeWidth = '
              'maxWidth, landscapeHeight = minHeight). ($option)',
        );
      }
      expect('dpToPixels('.allMatches(body).length, 4,
          reason: 'widgets.dimensions#2: one dpToPixels per option');

      expect(
        capture(body, RegExp(r'return WidgetDimensions\(([^)]*)\)'))
            .split(',')
            .map((String s) => s.trim())
            .toList(),
        <String>['minWidth', 'maxHeight', 'maxWidth', 'minHeight'],
        reason: 'widgets.dimensions#2, and therefore '
            'widgets.dimensions#3 — In portrait the widget is rendered at '
            '(minWidth x maxHeight); in landscape at (maxWidth x minHeight). '
            'The crossing lives entirely in this argument order.',
      );
    });

    test('portrait and landscape RemoteViews are asked for the crossed '
        'dimensions', () {
      final String source = widgetKotlin('BaseWidget.kt');

      expect(
        capture(
          source,
          RegExp(r'val landscapeRemoteViews[\s\S]*?getRemoteViews\(([^)]*)\)'),
        ),
        'it.landscapeWidth, it.landscapeHeight',
        reason: 'widgets.dimensions#3: landscape is (maxWidth x minHeight), '
            'which is what getDimensionsFromOptions stored in the landscape '
            'pair',
      );
      expect(
        capture(
          source,
          RegExp(r'val portraitRemoteViews[\s\S]*?getRemoteViews\(([^)]*)\)'),
        ),
        'it.portraitWidth, it.portraitHeight',
        reason: 'widgets.dimensions#3: portrait is (minWidth x maxHeight)',
      );
    });

    test('before setDimensions the default size is used for both '
        'orientations', () {
      final String source = widgetKotlin('BaseWidget.kt');

      expect(
        capture(
          source,
          RegExp(r'\?: WidgetDimensions\(([^)]*)\)'),
        ),
        'defaultWidth, defaultHeight, defaultWidth, defaultHeight',
        reason: 'widgets.dimensions#4 — Until setDimensions is called, every '
            'BaseWidget uses WidgetDimensions(defaultWidth, defaultHeight, '
            'defaultWidth, defaultHeight) — i.e. identical portrait and '
            'landscape sizes. Resolved lazily rather than in the constructor, '
            'so the documented defaults are actually applied; see '
            'docs/parity/DEVIATIONS.md.',
      );
    });

    test('the per-widget default sizes are upstream\'s', () {
      Map<String, int> sizeOf(String file) {
        final String source = widgetKotlin(file);
        return <String, int>{
          'height': int.parse(capture(
              source, RegExp(r'override val defaultHeight: Int get\(\) = (\d+)'))),
          'width': int.parse(capture(
              source, RegExp(r'override val defaultWidth: Int get\(\) = (\d+)'))),
        };
      }

      expect(
        <String, Map<String, int>>{
          'CheckmarkWidget': sizeOf('CheckmarkWidget.kt'),
          'FrequencyWidget': sizeOf('FrequencyWidget.kt'),
          'StreakWidget': sizeOf('StreakWidget.kt'),
          'TargetWidget': sizeOf('TargetWidget.kt'),
          'HistoryWidget': sizeOf('HistoryWidget.kt'),
          'ScoreWidget': sizeOf('ScoreWidget.kt'),
        },
        <String, Map<String, int>>{
          'CheckmarkWidget': <String, int>{'height': 125, 'width': 125},
          'FrequencyWidget': <String, int>{'height': 200, 'width': 200},
          'StreakWidget': <String, int>{'height': 200, 'width': 200},
          'TargetWidget': <String, int>{'height': 200, 'width': 200},
          'HistoryWidget': <String, int>{'height': 250, 'width': 250},
          'ScoreWidget': <String, int>{'height': 300, 'width': 300},
        },
        reason: 'widgets.dimensions#5 — Default sizes in pixels are: '
            'CheckmarkWidget 125x125, FrequencyWidget 200x200, StreakWidget '
            '200x200, TargetWidget 200x200, EmptyWidget 200x200, HistoryWidget '
            '250x250, ScoreWidget 300x300, StackWidget 0x0. EmptyWidget and '
            'StackWidget exist only to serve a stack, which the port does not '
            'reproduce.',
      );
    });
  });

  // =======================================================================
  // widgets.remoteviews-rendering
  // =======================================================================

  group('widgets.remoteviews-rendering', () {
    test('getRemoteViews builds, measures, refreshes and measures again', () {
      final String source = widgetKotlin('BaseWidget.kt');
      final String body = source.substring(
        source.indexOf('protected open fun getRemoteViews'),
        source.indexOf('private fun buildRemoteViews'),
      );

      expect(body, contains('val view = buildView()!!'),
          reason: 'widgets.remoteviews-rendering#1 — BaseWidget.getRemoteViews'
              '(width, height) calls buildView() (must be non-null; a null view '
              'raises NPE), measures it, calls refreshData(view), and if the '
              'view requested layout during refreshData it measures a second '
              'time, before rasterising.');
      expect(
        <int>[
          body.indexOf('measureView(view, width, height)'),
          body.indexOf('refreshData(view)'),
          body.lastIndexOf('measureView(view, width, height)'),
          body.indexOf('RemoteViews(context.packageName'),
        ],
        everyElement(isPositive),
        reason: 'widgets.remoteviews-rendering#1: all four steps are present',
      );
      expect(body.indexOf('refreshData(view)'),
          greaterThan(body.indexOf('measureView(view, width, height)')),
          reason: 'widgets.remoteviews-rendering#1: the first measure comes '
              'before refreshData');
      expect(body, contains('if (view.isLayoutRequested) measureView'),
          reason: 'widgets.remoteviews-rendering#1: the second measure is '
              'conditional on the refresh having requested layout');
    });

    test('measureView sizes the view to the wrapper\'s imageView', () {
      final String source = widgetKotlin('BaseWidget.kt');
      final String body = source.substring(source.indexOf('private fun measureView'));

      expect(body, contains('inflate(R.layout.widget_wrapper, null)'),
          reason: 'widgets.remoteviews-rendering#2 — measureView inflates '
              'R.layout.widget_wrapper off-screen, measures it with '
              'MeasureSpec.EXACTLY at the requested width/height, lays it out, '
              'then reads the measured width/height of its R.id.imageView child '
              'and measures/lays out the real widget view at exactly those '
              'dimensions.');
      expect('MeasureSpec.EXACTLY'.allMatches(body).length, 4,
          reason: 'widgets.remoteviews-rendering#2: EXACTLY twice for the '
              'wrapper and twice for the view');
      expect(body, contains('findViewById<View>(R.id.imageView)'),
          reason: 'widgets.remoteviews-rendering#2: the child that supplies the '
              'real size');
      expect(
        body.contains('makeMeasureSpec(imageView.measuredWidth, '
            'MeasureSpec.EXACTLY)'),
        isTrue,
        reason: 'widgets.remoteviews-rendering#2: the view is measured at '
            "exactly the imageView's width",
      );
    });

    test('the bitmap is ARGB_8888 and never zero-sized', () {
      final String source = widgetKotlin('BaseWidget.kt');
      final String body =
          source.substring(source.indexOf('private fun getBitmapFromView'));

      expect(
        argLines(
            capture(body, RegExp(r'Bitmap.createBitmap\(\s*([\s\S]*?)\s*\)\n'))),
        <String>[
          'max(1, view.measuredWidth)',
          'max(1, view.measuredHeight)',
          'Bitmap.Config.ARGB_8888',
        ],
        reason: 'widgets.remoteviews-rendering#3 — The measured view is drawn '
            'into a Bitmap of size max(1, view.measuredWidth) x max(1, '
            'view.measuredHeight) with Bitmap.Config.ARGB_8888, and set on '
            'R.id.imageView via RemoteViews.setImageViewBitmap.',
      );
      expect(
        widgetKotlin('BaseWidget.kt'),
        contains('setImageViewBitmap(R.id.imageView, getBitmapFromView(view))'),
        reason: 'widgets.remoteviews-rendering#3: and shipped on imageView',
      );
    });

    test('the tap target is padded so it sits centred on the bitmap', () {
      final String source = widgetKotlin('BaseWidget.kt');
      final String body =
          source.substring(source.indexOf('private fun adjustRemoteViewsPadding'));

      expect(
        capture(body, RegExp(r'val w = (.*)\n')).trim(),
        '((width.toFloat() - view.measuredWidth) / 2).toInt()',
        reason: 'widgets.remoteviews-rendering#4 — Padding is applied to '
            'R.id.buttonOverlay so the tap target is centred on the bitmap: '
            'left=right=((entireWidth - imageWidth) / 2).toInt() and '
            'top=bottom=((entireHeight - imageHeight) / 2).toInt().',
      );
      expect(
        capture(body, RegExp(r'val h = (.*)\n')).trim(),
        '((height.toFloat() - view.measuredHeight) / 2).toInt()',
        reason: 'widgets.remoteviews-rendering#4',
      );
      expect(
        capture(body, RegExp(r'setViewPadding\(([^)]*)\)')),
        'R.id.buttonOverlay, w, h, w, h',
        reason: 'widgets.remoteviews-rendering#4: left=right=w, top=bottom=h',
      );
    });

    test('the click PendingIntent is attached only when there is one', () {
      final String source = widgetKotlin('BaseWidget.kt');

      expect(
        source,
        contains('if (onClickIntent != null) '
            'remoteViews.setOnClickPendingIntent(R.id.button, onClickIntent)'),
        reason: 'widgets.remoteviews-rendering#5 — The click PendingIntent is '
            'attached to R.id.button only when getOnClickPendingIntent returns '
            'non-null; EmptyWidget and StackWidget return null and therefore '
            'have no click target. Neither of those two widgets is reproduced, '
            'so in this build every widget is clickable — the guard is kept '
            'because it is what makes that statement checkable.',
      );

      // The six that exist all return a non-null PendingIntent.
      for (final String widget in <String>[
        'CheckmarkWidget',
        'FrequencyWidget',
        'HistoryWidget',
        'ScoreWidget',
        'StreakWidget',
        'TargetWidget',
      ]) {
        expect(
          widgetKotlin('$widget.kt'),
          contains('override fun getOnClickPendingIntent(context: Context): '
              'PendingIntent'),
          reason: 'widgets.remoteviews-rendering#5: $widget returns a non-null '
              'PendingIntent (the return type is not nullable)',
        );
      }
    });

    test('widget_wrapper is the RelativeLayout the bitmap and the button live '
        'in', () {
      final String xml = androidSource('res/layout/widget_wrapper.xml');
      final Map<String, String> root = xmlRoot(xml, 'RelativeLayout');

      expect(
        <String, String?>{
          'width': root['android:layout_width'],
          'height': root['android:layout_height'],
          'gravity': root['android:gravity'],
          'padding': root['android:padding'],
        },
        <String, String>{
          'width': 'match_parent',
          'height': 'match_parent',
          'gravity': 'center',
          'padding': '0dp',
        },
        reason: 'widgets.remoteviews-rendering#6 — widget_wrapper is a '
            'RelativeLayout (match_parent, gravity=center, padding 0) '
            'containing an ImageView id=imageView (match_parent, '
            'adjustViewBounds=true) and a FrameLayout id=buttonOverlay '
            '(match_parent) holding a Button id=button (match_parent) whose '
            'background is widget_button_background.',
      );

      final Map<String, String> image = xmlRoot(xml, 'ImageView');
      expect(image['android:id'], '@+id/imageView',
          reason: 'widgets.remoteviews-rendering#6');
      expect(image['android:adjustViewBounds'], 'true',
          reason: 'widgets.remoteviews-rendering#6');
      expect(image['android:layout_width'], 'match_parent',
          reason: 'widgets.remoteviews-rendering#6');

      final Map<String, String> overlay = xmlRoot(xml, 'FrameLayout');
      expect(overlay['android:id'], '@+id/buttonOverlay',
          reason: 'widgets.remoteviews-rendering#6');
      expect(overlay['android:layout_width'], 'match_parent',
          reason: 'widgets.remoteviews-rendering#6');

      final Map<String, String> button = xmlRoot(xml, 'Button');
      expect(button['android:id'], '@+id/button',
          reason: 'widgets.remoteviews-rendering#6');
      expect(button['android:layout_width'], 'match_parent',
          reason: 'widgets.remoteviews-rendering#6');
      expect(button['android:background'], '@drawable/widget_button_background',
          reason: 'widgets.remoteviews-rendering#6');
    });

    test('the ripple is inset to match the card and leave room for the shadow',
        () {
      final String xml =
          androidSource('res/drawable/widget_button_background.xml');
      final Map<String, String> item = xmlAttributes(
        xmlBlocks(xml, 'item').first,
      );

      expect(
        <String, String?>{
          'left': item['android:left'],
          'top': item['android:top'],
          'right': item['android:right'],
          'bottom': item['android:bottom'],
        },
        <String, String>{
          'left': '1dp',
          'top': '1dp',
          'right': '3dp',
          'bottom': '3dp',
        },
        reason: 'widgets.remoteviews-rendering#7 — widget_button_background is '
            'a layer-list inset by top=1dp, left=1dp, bottom=3dp, right=3dp '
            'containing a ripple of colour #60ffffff with a rounded-rectangle '
            'mask of radius 18dp — so the touch ripple exactly matches the 18dp '
            'rounded card and is offset to leave room for the drop shadow.',
      );
      expect(xmlRoot(xml, 'ripple')['android:color'], '#60ffffff',
          reason: 'widgets.remoteviews-rendering#7: the ripple colour');
      expect(xmlRoot(xml, 'corners')['android:radius'], '18dp',
          reason: 'widgets.remoteviews-rendering#7: the mask radius');
      expect(xmlBlocks(xml, 'layer-list'), hasLength(1),
          reason: 'widgets.remoteviews-rendering#7: it is a layer-list');
    });
  });

  // =======================================================================
  // widgets.card-chrome
  // =======================================================================

  group('widgets.card-chrome', () {
    late String habitWidgetView;

    setUp(() => habitWidgetView = widgetViewKotlin('HabitWidgetView.kt'));

    test('every widget view is a HabitWidgetView that inflates into id=frame',
        () {
      expect(
        habitWidgetView,
        contains('abstract class HabitWidgetView(context: Context) : '
            'FrameLayout(context)'),
        reason: 'widgets.card-chrome#1 — Every widget view extends '
            'HabitWidgetView, a FrameLayout that inflates its inner layout and '
            'looks up a child with id=frame to use as the card background '
            'holder.',
      );
      expect(habitWidgetView, contains('inflate(context, innerLayoutId, this)'),
          reason: 'widgets.card-chrome#1: it inflates the inner layout');
      expect(habitWidgetView, contains('findViewById<View>(R.id.frame)'),
          reason: 'widgets.card-chrome#1: and looks up id=frame');

      for (final String view in <String>[
        'GraphWidgetView.kt',
        'CheckmarkWidgetView.kt',
      ]) {
        expect(widgetViewKotlin(view), contains(': HabitWidgetView(context)'),
            reason: 'widgets.card-chrome#1: $view extends it');
      }

      // Both inner layouts really do carry the id the base class looks for.
      for (final String layout in <String>['widget_graph', 'widget_checkmark']) {
        expect(
          androidSource('res/layout/$layout.xml'),
          contains('android:id="@+id/frame"'),
          reason: 'widgets.card-chrome#1: $layout declares id=frame',
        );
      }
    });

    test('the card is an 18dp round rect inset for the shadow', () {
      final String body = habitWidgetView
          .substring(habitWidgetView.indexOf('fun rebuildBackground'));

      expect(capture(body, RegExp(r'val shadowRadius = dpToPixels\(context, (\d+)f\)')),
          '2',
          reason: 'widgets.card-chrome#2 — The card background is a '
              'RoundRectShape with all 8 corner radii equal to 18dp, wrapped in '
              'an InsetDrawable with left=top=max(shadowRadius - shadowOffset, '
              '0) = 1dp and right=bottom=shadowRadius + shadowOffset = 3dp, '
              'where shadowRadius = 2dp and shadowOffset = 1dp (converted to '
              'px).');
      expect(capture(body, RegExp(r'val shadowOffset = dpToPixels\(context, (\d+)f\)')),
          '1',
          reason: 'widgets.card-chrome#2');
      expect(capture(body, RegExp(r'val cornerRadius = dpToPixels\(context, (\d+)f\)')),
          '18',
          reason: 'widgets.card-chrome#2');
      expect(capture(body, RegExp(r'val radii = FloatArray\((\d+)\)')), '8',
          reason: 'widgets.card-chrome#2: all eight corner radii');
      expect(
        capture(body, RegExp(r'val insetLeftTop = (.*)\n')).trim(),
        'max(shadowRadius - shadowOffset, 0)',
        reason: 'widgets.card-chrome#2',
      );
      expect(
        capture(body, RegExp(r'val insetRightBottom = (.*)\n')).trim(),
        'shadowRadius + shadowOffset',
        reason: 'widgets.card-chrome#2',
      );
      expect(body, contains('ShapeDrawable(RoundRectShape(radii, null, null))'),
          reason: 'widgets.card-chrome#2');
    });

    test('the card paint is cardBgColor at the current alpha over a black '
        'shadow', () {
      final String body = habitWidgetView
          .substring(habitWidgetView.indexOf('fun rebuildBackground'));

      expect(body, contains('backgroundPaint?.color = WidgetTheme.CARD_BG_COLOR'),
          reason: 'widgets.card-chrome#3 — The card paint colour is '
              '?attr/cardBgColor (grey_850 under WidgetTheme) and its alpha is '
              'set to the current backgroundAlpha; the shadow layer uses '
              'Color.argb(shadowAlpha, 0, 0, 0) at radius 2dp offset (1dp, 1dp).');
      expect(body, contains('backgroundPaint?.alpha = backgroundAlpha'),
          reason: 'widgets.card-chrome#3');
      expect(
        capture(body, RegExp(r'val shadowColor = Color.argb\(([^)]*)\)')),
        'shadowAlpha, 0, 0, 0',
        reason: 'widgets.card-chrome#3',
      );
      expect(
        capture(body, RegExp(r'setShadowLayer\(\s*([\s\S]*?)\s*\)\n'))
            .split(',')
            .map((String s) => s.trim())
            .toList(),
        <String>[
          'shadowRadius.toFloat()',
          'shadowOffset.toFloat()',
          'shadowOffset.toFloat()',
          'shadowColor',
        ],
        reason: 'widgets.card-chrome#3: radius 2dp, offset (1dp, 1dp)',
      );
      expect(
        capture(widgetKotlin('WidgetTheme.kt'),
            RegExp(r'const val CARD_BG_COLOR: Int = (0x[0-9A-Fa-f]+)')),
        '0xFF303030',
        reason: 'widgets.card-chrome#3: cardBgColor is grey_850',
      );
    });

    test('WidgetTheme starts widgets with no shadow at all', () {
      expect(
        capture(widgetKotlin('WidgetTheme.kt'),
            RegExp(r'const val WIDGET_SHADOW_ALPHA: Float = (\S+)')),
        '0f',
        reason: 'widgets.card-chrome#4 — On construction shadowAlpha = (255 * '
            '?attr/widgetShadowAlpha).toInt(); WidgetTheme sets '
            'widgetShadowAlpha=0, so widgets start with no shadow (the app '
            'themes use 0.25 => 63).',
      );
      expect(
        habitWidgetView,
        contains('private var shadowAlpha: Int = '
            '(255 * WidgetTheme.WIDGET_SHADOW_ALPHA).toInt()'),
        reason: 'widgets.card-chrome#4: the (255 * attr) conversion',
      );
    });

    test('a stacked widget is opaque, everything else honours widgetOpacity',
        () {
      final String source = widgetKotlin('BaseWidget.kt');

      expect(
        capture(source,
                RegExp(r'get\(\) = if \(stacked\) (\d+) else widgetOpacity'))
            .trim(),
        '255',
        reason: 'widgets.card-chrome#5 — BaseWidget.preferedBackgroundAlpha '
            'returns 255 whenever the widget is rendered inside a StackWidget '
            '(stacked == true), and otherwise returns Preferences.widgetOpacity. '
            'Stack widgets are not reproduced, so `stacked` is always false '
            'here and the branch exists to keep the other half honest.',
      );
    });

    test('the graph widgets take the shadow only at full opacity', () {
      for (final String widget in <String>[
        'FrequencyWidget',
        'ScoreWidget',
        'StreakWidget',
        'TargetWidget',
        'HistoryWidget',
      ]) {
        final String source = widgetKotlin('$widget.kt');
        expect(source, contains('setBackgroundAlpha(preferedBackgroundAlpha)'),
            reason: 'widgets.card-chrome#6 — Frequency, Score, Streak, Target '
                'and History widgets call '
                'setBackgroundAlpha(preferedBackgroundAlpha) and, only when '
                'preferedBackgroundAlpha >= 255, additionally call '
                'setShadowAlpha(0x4f) (=79) — so the drop shadow appears only '
                'on fully opaque widgets. ($widget)');
        expect(
          source,
          contains('if (preferedBackgroundAlpha >= 255) setShadowAlpha(0x4f)'),
          reason: 'widgets.card-chrome#6: guarded at 255 ($widget)',
        );
      }
    });

    test('the Checkmark widget takes the shadow unconditionally', () {
      final String source = widgetViewKotlin('CheckmarkWidgetView.kt');
      final String refresh = source.substring(
        source.indexOf('fun refresh()'),
        source.indexOf('private val strokedTextEnabled'),
      );

      expect(refresh, contains('setShadowAlpha(0x4f)'),
          reason: 'widgets.card-chrome#7 — CheckmarkWidgetView.refresh() '
              'unconditionally calls setShadowAlpha(0x4f) regardless of '
              'opacity.');
      expect(refresh, isNot(contains('preferedBackgroundAlpha >= 255')),
          reason: 'widgets.card-chrome#7: with no opacity guard');
    });

    test('both alpha setters rebuild the whole drawable', () {
      for (final String setter in <String>[
        'setShadowAlpha',
        'setBackgroundAlpha',
      ]) {
        final int start = habitWidgetView.indexOf('fun $setter(');
        final String body = habitWidgetView.substring(
          start,
          habitWidgetView.indexOf('}', start),
        );
        expect(body, contains('rebuildBackground()'),
            reason: 'widgets.card-chrome#8 — setShadowAlpha and '
                'setBackgroundAlpha both rebuild the whole background drawable '
                'and reassign it to the frame view. ($setter)');
      }
      expect(
        habitWidgetView,
        contains('frame?.background = cardBackground'),
        reason: 'widgets.card-chrome#8: and reassign it to the frame view',
      );
    });
  });

  // =======================================================================
  // widgets.theme (the Android half; the palette itself lives in the core)
  // =======================================================================

  group('widgets.theme', () {
    test('the WidgetTheme attribute table is inlined with upstream\'s values',
        () {
      final String source = widgetKotlin('WidgetTheme.kt');
      String constant(String name) =>
          capture(source, RegExp('const val $name: Int = (0x[0-9A-Fa-f]+)'));

      expect(
        <String, String>{
          'cardBgColor': constant('CARD_BG_COLOR'),
          'contrast0': constant('CONTRAST_0'),
          'contrast20': constant('CONTRAST_20'),
          'contrast60': constant('CONTRAST_60'),
          'contrast80': constant('CONTRAST_80'),
          'contrast100': constant('CONTRAST_100'),
        },
        <String, String>{
          // grey_850, white, white_a0, white_aa, grey_800, white.
          'cardBgColor': '0xFF303030',
          'contrast0': '0xFFFFFFFF',
          'contrast20': '0x0FFFFFFF',
          'contrast60': '0xAFFFFFFF',
          'contrast80': '0xFF424242',
          'contrast100': '0xFFFFFFFF',
        },
        reason: 'widgets.theme#1 — Providers call '
            'context.setTheme(R.style.WidgetTheme) before building any widget; '
            'WidgetTheme derives from AppBaseThemeDark and overrides '
            'cardBgColor=grey_850, contrast0=white, contrast20=white_a0, '
            'contrast60=white_aa, contrast80=grey_800, contrast100=white, '
            'palette=transparentWidgetPalette, widgetShadowAlpha=0. There is no '
            'Android style to set here — the provider runs outside the Flutter '
            'engine and resolves nothing from resources — so the whole table is '
            'a compile-time constant instead.',
      );
      expect(
        capture(source, RegExp(r'const val WIDGET_SHADOW_ALPHA: Float = (\S+)')),
        '0f',
        reason: 'widgets.theme#1: widgetShadowAlpha=0',
      );
    });

    test('widgets ignore the app theme: there is no light variant and no '
        'night override', () {
      expect(
        Directory('${androidMain.path}/res/values-night')
            .listSync()
            .whereType<File>()
            .map((File f) => f.readAsStringSync())
            .where((String s) => s.contains('Widget'))
            .toList(),
        isEmpty,
        reason: 'widgets.theme#5 — Widgets ignore the user\'s light/dark app '
            'theme entirely — they are always drawn with WidgetTheme. Nothing '
            'in values-night touches a widget style, and WidgetTheme.kt has no '
            'light branch.',
      );
      expect(
        widgetKotlin('WidgetTheme.kt'),
        isNot(contains('isNightMode')),
        reason: 'widgets.theme#5: the palette never asks what mode the app is '
            'in',
      );
      // Every widget view reads its colours from the constant table, never from
      // a theme attribute.
      for (final String view in <String>[
        'HabitWidgetView.kt',
        'CheckmarkWidgetView.kt',
        'HistoryChartView.kt',
        'ScoreChartView.kt',
        'StreakChartView.kt',
        'TargetChartView.kt',
        'FrequencyChartView.kt',
      ]) {
        expect(widgetViewKotlin(view), isNot(contains('obtainStyledAttributes')),
            reason: 'widgets.theme#5: $view resolves no theme attribute');
      }
    });
  });

  // =======================================================================
  // widgets.provider-lifecycle
  // =======================================================================

  group('widgets.provider-lifecycle', () {
    late String provider;

    setUp(() => provider = widgetKotlin('BaseWidgetProvider.kt'));

    test('onUpdate walks the id array on a background thread with a Looper',
        () {
      final String body = provider.substring(
        provider.indexOf('override fun onUpdate'),
        provider.indexOf('override fun onAppWidgetOptionsChanged'),
      );

      expect(body, contains('Thread {'),
          reason: 'widgets.provider-lifecycle#1 — BaseWidgetProvider.onUpdate '
              'resolves dependencies (habitList, preferences, '
              'widgetPreferences) from the application component, sets the '
              'context theme to R.style.WidgetTheme, then starts a new '
              'background Thread that calls Looper.prepare() and updates each '
              'widget id in the received array sequentially. There is no '
              'component to resolve here (the data arrives as a published '
              'document) and no WidgetTheme style (widgets.theme#5 makes the '
              'palette a constant), so what is left is the thread, the Looper '
              'and the sequential loop.');
      expect(body, contains('if (Looper.myLooper() == null) Looper.prepare()'),
          reason: 'widgets.provider-lifecycle#1: Looper.prepare() first');
      expect(body, contains('for (id in widgetIds) update(context, manager, id)'),
          reason: 'widgets.provider-lifecycle#1: every id, sequentially');
      expect(
        body.indexOf('Looper.prepare()'),
        lessThan(body.indexOf('for (id in widgetIds)')),
        reason: 'widgets.provider-lifecycle#1: the Looper exists before the '
            'first inflate',
      );
    });

    test('updating one id reads the manager\'s options and sets the dimensions',
        () {
      final String body = provider.substring(
        provider.indexOf('private fun update(context: Context'),
        provider.indexOf('private fun drawErrorWidget'),
      );

      expect(body, contains('val widget = getWidgetFromId(context, widgetId)'),
          reason: 'widgets.provider-lifecycle#2 — Updating one widget id: '
              'resolve the widget via getWidgetFromId, read '
              'AppWidgetManager.getAppWidgetOptions(widgetId), call '
              'widget.setDimensions(getDimensionsFromOptions(...)), then push '
              'the RemoteViews.');
      expect(body, contains('manager.getAppWidgetOptions(widgetId)'),
          reason: 'widgets.provider-lifecycle#2');
      expect(
        body,
        contains('widget.setDimensions(getDimensionsFromOptions(context, options))'),
        reason: 'widgets.provider-lifecycle#2',
      );
      expect(body, contains('updateAppWidget(manager, widget)'),
          reason: 'widgets.provider-lifecycle#2: then push');
      final List<int> steps = <int>[
        body.indexOf('getWidgetFromId'),
        body.indexOf('getAppWidgetOptions'),
        body.indexOf('setDimensions'),
        body.indexOf('updateAppWidget'),
      ];
      expect(steps, everyElement(isPositive),
          reason: 'widgets.provider-lifecycle#2: all four steps are there');
      for (int i = 1; i < steps.length; i++) {
        expect(steps[i], greaterThan(steps[i - 1]),
            reason: 'widgets.provider-lifecycle#2: step $i follows step '
                '${i - 1}');
      }
    });

    test('landscape RemoteViews are built before portrait and combined', () {
      final String body =
          provider.substring(provider.indexOf('fun updateAppWidget('));

      expect(
        body.indexOf('val landscape = widget.landscapeRemoteViews'),
        lessThan(body.indexOf('val portrait = widget.portraitRemoteViews')),
        reason: 'widgets.provider-lifecycle#3 — '
            'BaseWidgetProvider.updateAppWidget builds landscapeRemoteViews and '
            'portraitRemoteViews separately and combines them with '
            'RemoteViews(landscape, portrait) before calling '
            'manager.updateAppWidget(widget.id, views); the landscape views are '
            'built FIRST.',
      );
      expect(
        body,
        contains('manager.updateAppWidget(widget.id, '
            'RemoteViews(landscape, portrait))'),
        reason: 'widgets.provider-lifecycle#3: combined in that order',
      );
    });

    test('a resize does the same work inline, from the supplied bundle', () {
      final String body = provider.substring(
        provider.indexOf('override fun onAppWidgetOptionsChanged'),
        provider.indexOf('override fun onDeleted'),
      );

      expect(body, isNot(contains('Thread {')),
          reason: 'widgets.provider-lifecycle#4 — onAppWidgetOptionsChanged '
              '(fired when the user resizes the widget) does the same work but '
              'on the calling thread, using the options Bundle supplied by the '
              'callback rather than querying the manager.');
      expect(body, isNot(contains('getAppWidgetOptions')),
          reason: 'widgets.provider-lifecycle#4: the manager is not asked');
      expect(
        body,
        contains('widget.setDimensions(getDimensionsFromOptions(context, options))'),
        reason: 'widgets.provider-lifecycle#4: the supplied bundle is used',
      );
      expect(body, contains('updateAppWidget(manager, widget)'),
          reason: 'widgets.provider-lifecycle#4: same push');
    });

    test('any RuntimeException becomes the error widget', () {
      expect('catch (e: RuntimeException)'.allMatches(provider).length, 2,
          reason: 'widgets.provider-lifecycle#5 — Any RuntimeException thrown '
              'while building a widget is caught, the stack trace printed, and '
              'an error widget (layout widget_error) is pushed instead: a '
              'full-bleed LinearLayout with drawable widget_background (solid '
              '#3f000000, 4dp corners), centred white TextView with the literal '
              'default text \'Error drawing widget\'. Both entry points — '
              'onUpdate\'s per-id update and onAppWidgetOptionsChanged — carry '
              'the guard.');
      expect(provider, contains('e.printStackTrace()'),
          reason: 'widgets.provider-lifecycle#5: the trace is printed');
      expect(
        provider,
        contains('RemoteViews(context.packageName, R.layout.widget_error)'),
        reason: 'widgets.provider-lifecycle#5: widget_error is pushed',
      );

      final String xml = androidSource('res/layout/widget_error.xml');
      final Map<String, String> root = xmlRoot(xml, 'LinearLayout');
      expect(root['android:layout_width'], 'match_parent',
          reason: 'widgets.provider-lifecycle#5: full-bleed');
      expect(root['android:layout_height'], 'match_parent',
          reason: 'widgets.provider-lifecycle#5: full-bleed');
      expect(root['android:background'], '@drawable/widget_background',
          reason: 'widgets.provider-lifecycle#5');
      expect(root['android:gravity'], 'center',
          reason: 'widgets.provider-lifecycle#5: centred');

      final Map<String, String> label = xmlRoot(xml, 'TextView');
      expect(label['android:text'], 'Error drawing widget',
          reason: 'widgets.provider-lifecycle#5: the literal default text');
      expect(label['android:textColor'], '#ffffff',
          reason: 'widgets.provider-lifecycle#5: white');

      final String drawable = androidSource('res/drawable/widget_background.xml');
      expect(xmlRoot(drawable, 'solid')['android:color'], '#3f000000',
          reason: 'widgets.provider-lifecycle#5: solid #3f000000');
      expect(xmlRoot(drawable, 'corners')['android:radius'], '4dp',
          reason: 'widgets.provider-lifecycle#5: 4dp corners');
    });

    test('a missing habit relabels the error widget', () {
      expect(
        capture(provider, RegExp(r'const val HABIT_NOT_FOUND = "([^"]*)"')),
        'Habit deleted / not found',
        reason: 'widgets.provider-lifecycle#6 — If the caught exception is a '
            'HabitNotFoundException, the error widget label text is replaced '
            'with R.string.habit_not_found = \'Habit deleted / not found\'.',
      );
      expect(
        provider,
        contains('is HabitNotFoundException -> HABIT_NOT_FOUND'),
        reason: 'widgets.provider-lifecycle#6: the exception picks the label',
      );
      expect(
        provider,
        contains('errorView.setCharSequence(R.id.label, "setText", label)'),
        reason: 'widgets.provider-lifecycle#6: written onto the error layout',
      );
    });

    test('onDeleted rejects a null context or id array by name', () {
      final String body = provider.substring(
        provider.indexOf('override fun onDeleted'),
        provider.indexOf('fun getDimensionsFromOptions'),
      );

      expect(
        body,
        contains('if (context == null) throw RuntimeException("context is null")'),
        reason: 'widgets.provider-lifecycle#7 — onDeleted throws '
            'RuntimeException(\'context is null\') if context is null and '
            'RuntimeException(\'ids is null\') if ids is null.',
      );
      expect(
        body,
        contains('if (ids == null) throw RuntimeException("ids is null")'),
        reason: 'widgets.provider-lifecycle#7',
      );
      expect(body.indexOf('context is null'), lessThan(body.indexOf('ids is null')),
          reason: 'widgets.provider-lifecycle#7: context is checked first');
    });

    test('onDeleted clears every id it is handed, and cannot fail on one', () {
      final String body = provider.substring(
        provider.indexOf('override fun onDeleted'),
        provider.indexOf('fun getDimensionsFromOptions'),
      );

      expect(
        body,
        contains('for (id in ids) editor.remove(WidgetData.documentKey(id))'),
        reason: 'widgets.provider-lifecycle#8 — onDeleted loops over every '
            'deleted widget id and calls widget.delete(), which removes that '
            'widget\'s habit-id preference entry; a HabitNotFoundException '
            'while resolving one id is caught and skipped so remaining ids are '
            'still processed. The habit-id preference is owned by the Dart '
            'side — a native writer would race it with no lock between the two '
            'processes — so what this drops is the published document, which is '
            'unambiguously the launcher\'s copy.',
      );
      expect(body, contains('editor.apply()'),
          reason: 'widgets.provider-lifecycle#8: one batch, applied once');

      // Nothing inside the loop resolves a habit, so there is no
      // HabitNotFoundException to catch and no id can be skipped: the
      // "remaining ids are still processed" guarantee is structural here
      // rather than a catch block.
      expect(body, isNot(contains('getWidgetFromId')),
          reason: 'widgets.provider-lifecycle#8: no per-id resolution, so no '
              'per-id failure');
      expect(body, isNot(contains('try {')),
          reason: 'widgets.provider-lifecycle#8: and nothing to guard');
    });

    test('a widget whose habit is gone raises HabitNotFoundException for the '
        'whole widget', () {
      final String data = widgetKotlin('WidgetData.kt');
      final String body = data.substring(
        data.indexOf('fun singleHabit()'),
        data.indexOf('companion object', data.indexOf('fun singleHabit()')),
      );

      expect(
        body,
        contains('if (missingHabitIds.isNotEmpty()) throw HabitNotFoundException()'),
        reason: 'widgets.provider-lifecycle#9 — getHabitsFromWidgetId maps each '
            'stored habit id through habitList.getById; if any id no longer '
            'resolves, HabitNotFoundException is thrown for the whole widget '
            '(producing the \'Habit deleted / not found\' error widget). The '
            'mapping now happens on the Dart side, which cannot throw across '
            'the process boundary, so it publishes the unresolved ids as '
            'missingHabitIds and this is where the exception is raised.',
      );
      expect(
        capture(data, RegExp(r'class HabitNotFoundException : '
            r'RuntimeException\("([^"]*)"\)')),
        'habit deleted / not found',
        reason: 'widgets.provider-lifecycle#9: it is a RuntimeException, so the '
            'provider\'s catch turns it into the error widget',
      );
    });
  });

  // =======================================================================
  // widgets.error-states
  // =======================================================================

  group('widgets.error-states', () {
    test('an unresolvable habit id shows the "Habit deleted / not found" '
        'widget', () {
      final String provider = widgetKotlin('BaseWidgetProvider.kt');

      expect(
        provider,
        contains('is HabitNotFoundException -> HABIT_NOT_FOUND'),
        reason: 'widgets.error-states#1 — If a widget\'s stored habit id no '
            'longer resolves to a habit, the widget is replaced by the '
            'widget_error layout showing \'Habit deleted / not found\'.',
      );
      expect(capture(provider, RegExp(r'const val HABIT_NOT_FOUND = "([^"]*)"')),
          'Habit deleted / not found',
          reason: 'widgets.error-states#1: that exact label');
    });

    test('any other RuntimeException keeps the layout\'s default text', () {
      final String provider = widgetKotlin('BaseWidgetProvider.kt');
      final String body =
          provider.substring(provider.indexOf('private fun drawErrorWidget'));

      expect(body, contains('else -> null'),
          reason: 'widgets.error-states#2 — Any other RuntimeException during '
              'widget construction or rendering produces the same error layout '
              'with its default text \'Error drawing widget\'.');
      expect(body, contains('if (label != null) errorView.setCharSequence'),
          reason: 'widgets.error-states#2: a null label leaves the XML default '
              'in place');
      expect(
        xmlRoot(androidSource('res/layout/widget_error.xml'), 'TextView')[
            'android:text'],
        'Error drawing widget',
        reason: 'widgets.error-states#2: which is this string',
      );
    });

    test('the error layout is a padded, centred, unclickable card', () {
      final String xml = androidSource('res/layout/widget_error.xml');
      final Map<String, String> root = xmlRoot(xml, 'LinearLayout');

      expect(
        <String, String?>{
          'paddingTop': root['android:paddingTop'],
          'paddingLeft': root['android:paddingLeft'],
          'paddingRight': root['android:paddingRight'],
          'paddingBottom': root['android:paddingBottom'],
          'background': root['android:background'],
        },
        <String, String>{
          'paddingTop': '4dp',
          'paddingLeft': '8dp',
          'paddingRight': '8dp',
          'paddingBottom': '0dp',
          'background': '@drawable/widget_background',
        },
        reason: 'widgets.error-states#3 — The error layout is a centred white '
            'TextView on drawable widget_background (solid #3f000000, corner '
            'radius 4dp) with paddingTop 4dp, paddingLeft/Right 8dp, '
            'paddingBottom 0dp; it has no click target.',
      );
      expect(xmlBlocks(xml, 'Button'), isEmpty,
          reason: 'widgets.error-states#3: no click target');
      expect(
        widgetKotlin('BaseWidgetProvider.kt'),
        isNot(contains('errorView.setOnClickPendingIntent')),
        reason: 'widgets.error-states#3: and none is attached in code either',
      );
    });

    test('backing out of the picker never creates a widget', () {
      final String picker =
          androidSource('kotlin/org/isoron/uhabits/widgets/activities/'
              'HabitPickerDialog.kt');

      expect(picker, contains('setResult(RESULT_CANCELED)'),
          reason: 'widgets.error-states#6 — If the user has no eligible habits '
              'when placing a widget, the configuration activity shows a plain '
              'message screen and never returns RESULT_OK, so no widget is '
              'created. The port asks the Flutter picker instead of building '
              'the list natively, so the "no eligible habits" screen is the '
              'picker\'s; what this activity guarantees is the other half — '
              'RESULT_CANCELED unless a document came back.');
      expect(picker, contains('if (isConfigured()) {'),
          reason: 'widgets.error-states#6: RESULT_OK only when a document was '
              'published');
    });
  });

  // =======================================================================
  // widgets.config-picker
  // =======================================================================

  group('widgets.config-picker', () {
    late String picker;

    setUp(() => picker = androidSource(
        'kotlin/org/isoron/uhabits/widgets/activities/HabitPickerDialog.kt'));

    test('the widget id comes from the extras and falls back to 0', () {
      expect(
        picker,
        contains('widgetId = intent.extras?.getInt(\n'
            '            AppWidgetManager.EXTRA_APPWIDGET_ID,\n'
            '            AppWidgetManager.INVALID_APPWIDGET_ID\n'
            '        ) ?: 0'),
        reason: 'widgets.config-picker#1 — HabitPickerDialog is launched by the '
            'launcher as the widget\'s APPWIDGET_CONFIGURE activity and reads '
            'the widget id from intent.extras.getInt(EXTRA_APPWIDGET_ID, '
            'INVALID_APPWIDGET_ID); if the intent has no extras at all, '
            'widgetId falls back to 0.',
      );
      expect(
        capture(picker,
            RegExp(r'private var widgetId: Int = AppWidgetManager\.(\w+)')),
        'INVALID_APPWIDGET_ID',
        reason: 'widgets.config-picker#1: and starts at the invalid id',
      );
    });

    test('the Streaks picker hides numerical habits', () {
      final String body = picker.substring(picker.indexOf('class BooleanHabitPickerDialog'));

      expect(
        capture(body, RegExp(r'override val filter: String get\(\) = '
            r'WidgetIntents\.(\w+)')),
        'FILTER_BOOLEAN',
        reason: 'widgets.config-picker#4 — BooleanHabitPickerDialog sets '
            'shouldHideNumerical() = true and its empty message is '
            'R.string.no_boolean_habits = \'No yes-or-no habits found\'. The '
            'filtering itself happens in the Flutter picker, which is where the '
            'habit list is, so the native side names the filter rather than '
            'applying it.',
      );
      expect(
        capture(body, RegExp(r'override val emptyMessage: String get\(\) = "([^"]*)"')),
        'No yes-or-no habits found',
        reason: 'widgets.config-picker#4: the empty message',
      );
      expect(
        capture(widgetKotlin('WidgetIntents.kt'),
            RegExp(r'const val FILTER_BOOLEAN = "([^"]*)"')),
        'boolean',
        reason: 'widgets.config-picker#4: carried in the deep link',
      );
    });

    test('the Target picker hides boolean habits', () {
      final String body =
          picker.substring(picker.indexOf('class NumericalHabitPickerDialog'));

      expect(
        capture(body, RegExp(r'override val filter: String get\(\) = '
            r'WidgetIntents\.(\w+)')),
        'FILTER_NUMERICAL',
        reason: 'widgets.config-picker#5 — NumericalHabitPickerDialog sets '
            'shouldHideBoolean() = true and its empty message is '
            'R.string.no_numerical_habits = \'No measurable habits found\'.',
      );
      expect(
        capture(body, RegExp(r'override val emptyMessage: String get\(\) = "([^"]*)"')),
        'No measurable habits found',
        reason: 'widgets.config-picker#5: the empty message',
      );
      expect(
        capture(widgetKotlin('WidgetIntents.kt'),
            RegExp(r'const val FILTER_NUMERICAL = "([^"]*)"')),
        'numerical',
        reason: 'widgets.config-picker#5: carried in the deep link',
      );
    });

    test('the base picker hides nothing', () {
      final String body = picker.substring(
        picker.indexOf('open class HabitPickerDialog'),
        picker.indexOf('class BooleanHabitPickerDialog'),
      );

      expect(
        capture(body, RegExp(r'protected open val filter: String get\(\) = '
            r'WidgetIntents\.(\w+)')),
        'FILTER_ALL',
        reason: 'widgets.config-picker#6 — The base HabitPickerDialog hides '
            'nothing and its empty message is R.string.no_habits = \'No habits '
            'found\'.',
      );
      expect(
        capture(body,
            RegExp(r'protected open val emptyMessage: String get\(\) = "([^"]*)"')),
        'No habits found',
        reason: 'widgets.config-picker#6: the empty message',
      );
      expect(
        capture(widgetKotlin('WidgetIntents.kt'),
            RegExp(r'const val FILTER_ALL = "([^"]*)"')),
        'all',
        reason: 'widgets.config-picker#6',
      );
    });

    test('confirming returns RESULT_OK with the widget id', () {
      expect(
        picker,
        contains('setResult(\n'
            '                RESULT_OK,\n'
            '                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)\n'
            '            )'),
        reason: 'widgets.config-picker#10 — confirm(selectedIds) calls '
            'widgetPreferences.addWidget(widgetId, ids), then '
            'widgetUpdater.updateWidgets() (all widgets, all providers), then '
            'setResult(RESULT_OK, Intent with EXTRA_APPWIDGET_ID = widgetId), '
            'then finish(). The first two steps moved to the Dart picker '
            '(WidgetRegistry.addWidget + a publish); the published document is '
            'what this activity reads back as the confirmation.',
      );
      expect(picker, contains('finish()'),
          reason: 'widgets.config-picker#10: then finish()');
      expect(
        picker,
        contains('WidgetData.storage(this).contains(WidgetData.documentKey(widgetId))'),
        reason: 'widgets.config-picker#10: a published document means the user '
            'confirmed',
      );
    });

    test('the default result is CANCELED, and a recycled id cannot fake a '
        'confirmation', () {
      expect(picker, contains('setResult(RESULT_CANCELED)'),
          reason: 'widgets.config-picker#11 — Backing out of the picker without '
              'choosing leaves the default RESULT_CANCELED, so the widget is '
              'not added.');
      expect(
        picker.indexOf('setResult(RESULT_CANCELED)'),
        lessThan(picker.indexOf('override fun onResume')),
        reason: 'widgets.config-picker#11: it is set in onCreate, before '
            'anything can go wrong',
      );
      expect(
        picker,
        contains('WidgetData.storage(this).edit()'
            '.remove(WidgetData.documentKey(widgetId)).apply()'),
        reason: 'widgets.config-picker#11: launchers recycle widget ids, so a '
            'stale document is cleared before the picker runs — otherwise a '
            'cancelled placement could inherit an old confirmation',
      );
    });
  });

  // =======================================================================
  // widgets.graph-view
  // =======================================================================

  group('widgets.graph-view', () {
    test('widget_graph is the frame/innerFrame/title shell', () {
      final String xml = androidSource('res/layout/widget_graph.xml');

      expect(xmlRoot(xml, 'FrameLayout')['android:id'], '@+id/frame',
          reason: 'widgets.graph-view#1 — GraphWidgetView inflates '
              'R.layout.widget_graph: a FrameLayout id=frame containing a '
              'vertical LinearLayout id=innerFrame (paddingTop 4dp, paddingLeft '
              '8dp, paddingRight 8dp, paddingBottom 8dp) whose first child is a '
              'TextView id=title (match_parent width, wrap_content height, '
              'gravity center, textSize R.dimen.smallTextSize = 14sp, maxLines '
              '2, textColor white).');

      final Map<String, String> inner = xmlRoot(xml, 'LinearLayout');
      expect(
        <String, String?>{
          'id': inner['android:id'],
          'orientation': inner['android:orientation'],
          'paddingTop': inner['android:paddingTop'],
          'paddingLeft': inner['android:paddingLeft'],
          'paddingRight': inner['android:paddingRight'],
          'paddingBottom': inner['android:paddingBottom'],
        },
        <String, String>{
          'id': '@+id/innerFrame',
          'orientation': 'vertical',
          'paddingTop': '4dp',
          'paddingLeft': '8dp',
          'paddingRight': '8dp',
          'paddingBottom': '8dp',
        },
        reason: 'widgets.graph-view#1',
      );

      final Map<String, String> title = xmlRoot(xml, 'TextView');
      expect(
        <String, String?>{
          'id': title['android:id'],
          'width': title['android:layout_width'],
          'height': title['android:layout_height'],
          'gravity': title['android:gravity'],
          'maxLines': title['android:maxLines'],
          'textSize': title['android:textSize'],
          'textColor': title['android:textColor'],
        },
        <String, String>{
          'id': '@+id/title',
          'width': 'match_parent',
          'height': 'wrap_content',
          'gravity': 'center',
          'maxLines': '2',
          'textSize': '14sp',
          'textColor': '#ffffff',
        },
        reason: 'widgets.graph-view#1: the title row',
      );
      // The title is the first child of innerFrame.
      expect(xml.indexOf('@+id/title'), greaterThan(xml.indexOf('@+id/innerFrame')),
          reason: 'widgets.graph-view#1: title sits inside innerFrame');
    });

    test('the chart is added below the title at MATCH_PARENT', () {
      final String source = widgetViewKotlin('GraphWidgetView.kt');

      expect(
        source,
        contains('dataView.layoutParams = ViewGroup.LayoutParams(\n'
            '            ViewGroup.LayoutParams.MATCH_PARENT,\n'
            '            ViewGroup.LayoutParams.MATCH_PARENT\n'
            '        )'),
        reason: 'widgets.graph-view#2 — The chart view passed into '
            'GraphWidgetView\'s constructor is added to innerFrame below the '
            'title with LayoutParams(MATCH_PARENT, MATCH_PARENT), and the title '
            'is made VISIBLE.',
      );
      expect(
        source,
        contains('(findViewById<View>(R.id.innerFrame) as ViewGroup)'
            '.addView(dataView)'),
        reason: 'widgets.graph-view#2: into innerFrame',
      );
      expect(source, contains('title.visibility = VISIBLE'),
          reason: 'widgets.graph-view#2: and the title is made visible');
      expect(
        source.indexOf('addView(dataView)'),
        lessThan(source.indexOf('title = findViewById')),
        reason: 'widgets.graph-view#2: the chart is added to the already '
            'inflated layout, so it lands below the title that is in it',
      );
    });

    test('the title is the habit name, at most two lines', () {
      for (final String widget in <String>[
        'FrequencyWidget',
        'HistoryWidget',
        'ScoreWidget',
        'StreakWidget',
        'TargetWidget',
      ]) {
        expect(widgetKotlin('$widget.kt'), contains('setTitle(habit.name)'),
            reason: 'widgets.graph-view#3 — The title is always set to the habit '
                'name and is truncated to at most 2 lines. ($widget)');
      }
      expect(
        xmlRoot(androidSource('res/layout/widget_graph.xml'),
            'TextView')['android:maxLines'],
        '2',
        reason: 'widgets.graph-view#3: two lines',
      );
    });

    test('five widgets share the shell and only Checkmark does not', () {
      for (final String widget in <String>[
        'FrequencyWidget',
        'HistoryWidget',
        'ScoreWidget',
        'StreakWidget',
        'TargetWidget',
      ]) {
        expect(widgetKotlin('$widget.kt'), contains('GraphWidgetView(context,'),
            reason: 'widgets.graph-view#4 — Frequency, Score, Streak, Target and '
                'History widgets all share this shell; only Checkmark uses a '
                'different layout. ($widget)');
      }
      expect(widgetKotlin('CheckmarkWidget.kt'), isNot(contains('GraphWidgetView')),
          reason: 'widgets.graph-view#4: Checkmark does not');
      expect(
        capture(widgetViewKotlin('CheckmarkWidgetView.kt'),
            RegExp(r'get\(\) = R.layout.(\w+)')),
        'widget_checkmark',
        reason: 'widgets.graph-view#4: it inflates widget_checkmark instead',
      );
    });
  });

  // =======================================================================
  // widgets.checkmark
  // =======================================================================

  group('widgets.checkmark', () {
    late String widget;

    setUp(() => widget = widgetKotlin('CheckmarkWidget.kt'));

    test('the Checkmark widget is 125x125 on a CheckmarkWidgetView', () {
      expect(
        capture(widget, RegExp(r'override val defaultWidth: Int get\(\) = (\d+)')),
        '125',
        reason: 'widgets.checkmark#1 — CheckmarkWidget default size is 125x125 '
            'px and its view is a CheckmarkWidgetView.',
      );
      expect(
        capture(widget, RegExp(r'override val defaultHeight: Int get\(\) = (\d+)')),
        '125',
        reason: 'widgets.checkmark#1',
      );
      expect(widget, contains('override fun buildView(): View = '
          'CheckmarkWidgetView(context)'),
          reason: 'widgets.checkmark#1: the view');
    });

    test('refreshData assigns in upstream\'s order', () {
      final String body = widget.substring(widget.indexOf('override fun refreshData'));
      final List<int> positions = <int>[
        body.indexOf('setBackgroundAlpha(preferedBackgroundAlpha)'),
        body.indexOf('activeColor = WidgetTheme.color(habit.color)'),
        body.indexOf('name = habit.name'),
        body.indexOf('entryValue = habit.value'),
        body.indexOf('entryState ='),
        body.indexOf('percentage ='),
        body.indexOf('refresh()'),
      ];

      expect(positions.every((int p) => p >= 0), isTrue,
          reason: 'widgets.checkmark#2 — refreshData sets, in order: '
              'setBackgroundAlpha(preferedBackgroundAlpha); activeColor = '
              'WidgetTheme().color(habit.color) as an Android int; name = '
              'habit.name; entryValue = habit.computedEntries.get(today).value; '
              'entryState; percentage = habit.scores[today].value.toFloat(); '
              'then calls refresh().');
      for (int i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThan(positions[i - 1]),
            reason: 'widgets.checkmark#2: step $i follows step ${i - 1}');
      }
      // The score the ring reads is not in the v1 document, so it falls back
      // to an empty ring rather than inventing a number.
      expect(body, contains('percentage = (habit.score ?: 0.0).toFloat()'),
          reason: 'widgets.checkmark#2: percentage comes from the habit score, '
              'which the v1 contract does not publish — the ring reads empty '
              'until it does');
    });

    test('a boolean habit shows its entry value as the state', () {
      final int refreshData = widget.indexOf('override fun refreshData');
      expect(
        widget.substring(widget.indexOf('} else {', refreshData)),
        contains('entryState = habit.value'),
        reason: 'widgets.checkmark#3 — For a boolean habit, entryState = '
            'habit.computedEntries.get(today).value (one of UNKNOWN=-1, NO=0, '
            'YES_AUTO=1, YES_MANUAL=2, SKIP=3).',
      );
      final String data = widgetKotlin('WidgetData.kt');
      expect(
        <String, String>{
          for (final String name in <String>[
            'UNKNOWN',
            'NO',
            'YES_AUTO',
            'YES_MANUAL',
            'SKIP',
          ])
            name: capture(data, RegExp('const val $name = (-?\\d+)')),
        },
        <String, String>{
          'UNKNOWN': '-1',
          'NO': '0',
          'YES_AUTO': '1',
          'YES_MANUAL': '2',
          'SKIP': '3',
        },
        reason: 'widgets.checkmark#3: the five values, with upstream\'s numbers',
      );
    });

    test('a numerical habit shows completed-or-not, and never completes an '
        'at-most habit', () {
      expect(widget, contains('isNumerical = true'),
          reason: 'widgets.checkmark#4 — For a numerical habit, isNumerical is '
              'set true and entryState = YES_MANUAL (2) when '
              'habit.isCompletedToday() else NO (0); isCompletedToday for '
              'AT_LEAST habits is value/1000.0 >= targetValue, and is always '
              'false for AT_MOST habits.');
      expect(
        widget,
        contains('entryState = if (habit.isCompletedToday()) '
            'Entry.YES_MANUAL else Entry.NO'),
        reason: 'widgets.checkmark#4',
      );
      expect(
        capture(widgetKotlin('WidgetData.kt'),
                RegExp(r'fun isCompletedToday\(\): Boolean =\s*\n\s*(.*)\n'))
            .trim(),
        'if (isAtMost) false else value / 1000.0 >= target',
        reason: 'widgets.checkmark#4: the AT_MOST branch is a flat false',
      );
    });

    test('today comes from the document, never from the system clock', () {
      expect(widget, contains('private val today: LocalDate'),
          reason: 'widgets.checkmark#5 — \'today\' is '
              'org.isoron.platform.time.getToday(), i.e. the app-wide today '
              'which already accounts for the midnight-delay offset. Only the '
              'Dart side knows that offset, so the widget is handed the answer '
              'in its document instead of computing one.');
      expect(
        widgetKotlin('CheckmarkWidgetProvider.kt'),
        contains('document.singleHabit(), document.today'),
        reason: 'widgets.checkmark#5: the provider passes the document\'s today',
      );
      // Nothing in the widget package asks the system what day it is.
      for (final String file in Directory('${androidMain.path}/kotlin/org/'
              'isoron/uhabits/widgets')
          .listSync(recursive: true)
          .whereType<File>()
          .map((File f) => f.readAsStringSync())) {
        expect(file, isNot(contains('Calendar.getInstance()')),
            reason: 'widgets.checkmark#5: no widget reads the system date');
        expect(file, isNot(contains('System.currentTimeMillis()')),
            reason: 'widgets.checkmark#5: nor the system clock');
      }
    });

    test('a numerical Checkmark tap opens the value picker for the document\'s '
        'today', () {
      expect(
        widget,
        contains('if (habit.isNumerical) {\n'
            '        WidgetIntents.showNumberPicker(context, id, habit, today)'),
        reason: 'widgets.checkmark#7 — Tapping a numerical Checkmark widget '
            'instead launches ListHabitsActivity with action ACTION_EDIT and '
            'extras habit=<habit id> and timestamp=<today.unixTime>, request '
            'code ((habit.id % Integer.MAX_VALUE) + 1) — this opens the numeric '
            'value picker for today. A Flutter app has one activity and the '
            'home_widget plugin delivers only the intent data, so the same two '
            'arguments travel in the deep-link URI instead of in extras.',
      );

      final String intents = widgetKotlin('WidgetIntents.kt');
      final String body = intents.substring(
        intents.indexOf('fun showNumberPicker'),
        intents.indexOf('fun showHabit'),
      );
      expect(
        capture(body, RegExp(r'uri\(([A-Z_]+), widgetId\)')),
        'ACTION_EDIT',
        reason: 'widgets.checkmark#7: the edit action',
      );
      expect(body, contains('appendQueryParameter("habit", habit.id.toString())'),
          reason: 'widgets.checkmark#7: the habit id');
      expect(body, contains('appendQueryParameter("date", today.toString())'),
          reason: 'widgets.checkmark#7: and the day, which is the document\'s '
              'today');
    });

    test('the edit deep link names the habit "habit", not "habitId"', () {
      final String intents = widgetKotlin('WidgetIntents.kt');
      final String body = intents.substring(
        intents.indexOf('fun showNumberPicker'),
        intents.indexOf('fun showHabit'),
      );

      expect(
        captureAll(body, RegExp(r'appendQueryParameter\("(\w+)"')),
        <String>['habit', 'date'],
        reason: 'intents.actions-and-extras#13 — ACTION_EDIT carries long '
            'extras "habit" (habit id) and "timestamp" (LocalDate.unixTime) — '
            'note the key is "habit", not "habitId". The key survives; the day '
            'does not travel as a unix instant. The home_widget plugin hands '
            'Dart the intent data and nothing else, and FLAG_IMMUTABLE means '
            'the launcher could not add extras anyway, so both arguments are '
            'query parameters — and a calendar day is what the receiver wanted, '
            'so it is spelled as one rather than as midnight-in-millis. '
            'Contrast intents.actions-and-extras#14, where the edit *screen* is '
            'opened with "habitId".',
      );
      expect(
        capture(body, RegExp(r'uri\((\w+), widgetId\)')),
        'ACTION_EDIT',
        reason: 'intents.actions-and-extras#13: on the edit action',
      );
      expect(
        capture(widgetKotlin('WidgetIntents.kt'),
            RegExp(r'const val ACTION_EDIT = "([^"]*)"')),
        'edit',
        reason: 'intents.actions-and-extras#13: which is the deep link this '
            'port routes instead of org.isoron.uhabits.ACTION_EDIT — the '
            'literal Android action still exists, on the notification path, '
            'and is asserted there',
      );
    });
  });

  // =======================================================================
  // widgets.checkmark-view
  // =======================================================================

  group('widgets.checkmark-view', () {
    late String view;

    setUp(() => view = widgetViewKotlin('CheckmarkWidgetView.kt'));

    test('widget_checkmark is the ring-over-label column', () {
      final String xml = androidSource('res/layout/widget_checkmark.xml');
      final Map<String, String> root = xmlRoot(xml, 'LinearLayout');

      expect(
        <String, String?>{
          'id': root['android:id'],
          'orientation': root['android:orientation'],
          'gravity': root['android:gravity'],
        },
        <String, String>{
          'id': '@+id/frame',
          'orientation': 'vertical',
          'gravity': 'center',
        },
        reason: 'widgets.checkmark-view#1 — CheckmarkWidgetView inflates '
            'R.layout.widget_checkmark: a vertical, centre-gravity LinearLayout '
            'id=frame containing a RingView id=scoreRing (height 0dp, weight '
            '0.9, marginTop 8dp, marginLeft/Right 4dp, thickness attr 2, '
            'textSize attr 16, enableFontAwesome=true) and a TextView id=label '
            '(weight 0.1, textSize 12sp, white, gravity center, maxLines 2, '
            'ellipsize end, marginLeft/Right 6dp, marginTop/Bottom 4dp, '
            'fontFamily sans-serif-condensed, breakStrategy balanced).',
      );

      final Map<String, String> ring =
          xmlRoot(xml, 'org.isoron.uhabits.widgets.views.RingView');
      expect(
        <String, String?>{
          'id': ring['android:id'],
          'height': ring['android:layout_height'],
          'weight': ring['android:layout_weight'],
          'marginTop': ring['android:layout_marginTop'],
          'marginLeft': ring['android:layout_marginLeft'],
          'marginRight': ring['android:layout_marginRight'],
        },
        <String, String>{
          'id': '@+id/scoreRing',
          'height': '0dp',
          'weight': '0.9',
          'marginTop': '8dp',
          'marginLeft': '4dp',
          'marginRight': '4dp',
        },
        reason: 'widgets.checkmark-view#1: the ring',
      );
      // thickness / textSize / enableFontAwesome are applied from code, because
      // onMeasure overwrites the first two on every pass anyway.
      expect(view, contains('ring.setEnableFontAwesome(true)'),
          reason: 'widgets.checkmark-view#1: enableFontAwesome=true');

      final Map<String, String> label = xmlRoot(xml, 'TextView');
      expect(
        <String, String?>{
          'id': label['android:id'],
          'weight': label['android:layout_weight'],
          'textSize': label['android:textSize'],
          'textColor': label['android:textColor'],
          'gravity': label['android:gravity'],
          'maxLines': label['android:maxLines'],
          'ellipsize': label['android:ellipsize'],
          'marginLeft': label['android:layout_marginLeft'],
          'marginRight': label['android:layout_marginRight'],
          'marginTop': label['android:layout_marginTop'],
          'marginBottom': label['android:layout_marginBottom'],
          'fontFamily': label['android:fontFamily'],
          'breakStrategy': label['android:breakStrategy'],
        },
        <String, String>{
          'id': '@+id/label',
          'weight': '0.1',
          'textSize': '12sp',
          'textColor': '#ffffff',
          'gravity': 'center',
          'maxLines': '2',
          'ellipsize': 'end',
          'marginLeft': '6dp',
          'marginRight': '6dp',
          'marginTop': '4dp',
          'marginBottom': '4dp',
          'fontFamily': 'sans-serif-condensed',
          'breakStrategy': 'balanced',
        },
        reason: 'widgets.checkmark-view#1: the label',
      );
    });

    test('refresh draws nothing before the background exists', () {
      expect(view, contains('if (backgroundPaint == null || frame == null) return'),
          reason: 'widgets.checkmark-view#2 — refresh() returns immediately '
              'without drawing if backgroundPaint or frame is null.');
      final String body = view.substring(view.indexOf('fun refresh()'));
      expect(
        body.indexOf('backgroundPaint == null'),
        lessThan(body.indexOf('ring.setPercentage')),
        reason: 'widgets.checkmark-view#2: before anything is drawn',
      );
    });

    test('a satisfied day paints the card in the habit colour', () {
      final String body = view.substring(
        view.indexOf('Entry.YES_MANUAL, Entry.SKIP, Entry.YES_AUTO ->'),
        view.indexOf('else -> {'),
      );

      expect(body, contains('bgColor = activeColor'),
          reason: 'widgets.checkmark-view#3 — When entryState is YES_MANUAL (2), '
              'SKIP (3) or YES_AUTO (1): the card background colour becomes '
              'activeColor (the habit colour), the foreground colour is '
              '?attr/contrast0 (white), and the frame background is re-applied.');
      expect(body, contains('fgColor = WidgetTheme.CONTRAST_0'),
          reason: 'widgets.checkmark-view#3: contrast0 is white');
      expect(body, contains('frame!!.background = cardBackground'),
          reason: 'widgets.checkmark-view#3: re-applied');
    });

    test('an unsatisfied day keeps the card colour and does not re-apply the '
        'background', () {
      final String body = view.substring(
        view.indexOf('else -> {'),
        view.indexOf('ring.setPercentage'),
      );

      expect(body, contains('bgColor = WidgetTheme.CARD_BG_COLOR'),
          reason: 'widgets.checkmark-view#4 — When entryState is NO (0), UNKNOWN '
              '(-1) or anything else: the card background colour is '
              '?attr/cardBgColor and the foreground colour is ?attr/contrast60; '
              'in this branch the frame background drawable is NOT re-applied.');
      expect(body, contains('fgColor = WidgetTheme.CONTRAST_60'),
          reason: 'widgets.checkmark-view#4: contrast60');
      expect(body, isNot(contains('frame!!.background')),
          reason: 'widgets.checkmark-view#4: and no re-apply');
    });

    test('refresh pushes percentage, colours, glyph and name onto the ring and '
        'label', () {
      final String body = view.substring(
        view.indexOf('ring.setPercentage'),
        view.indexOf('requestLayout()'),
      );

      expect(
        body
            .split('\n')
            .map((String line) => line.trim())
            .where((String line) => line.isNotEmpty)
            .toList(),
        <String>[
          'ring.setPercentage(percentage)',
          'ring.setColor(fgColor)',
          'ring.setBackgroundColor(bgColor)',
          'ring.setText(text)',
          'ring.setIsStrokedTextEnabled(strokedTextEnabled)',
          'label.text = name',
          'label.setTextColor(fgColor)',
        ],
        reason: 'widgets.checkmark-view#5 — refresh() sets ring.percentage = '
            'percentage, ring.color = foreground colour, ring.backgroundColor = '
            'background colour, ring text, ring stroked-text flag, label.text = '
            'habit name and label text colour = foreground colour.',
      );
    });

    test('the boolean glyph table is upstream\'s', () {
      final String body = view.substring(
        view.indexOf('when (entryState) {', view.indexOf('private val text')),
      );

      expect(body, contains('Entry.YES_MANUAL, Entry.YES_AUTO -> FontAwesome.CHECK'),
          reason: 'widgets.checkmark-view#6 — Glyph for a boolean habit: '
              'YES_MANUAL and YES_AUTO -> R.string.fa_check; SKIP -> '
              'R.string.fa_skipped; NO -> R.string.fa_times; UNKNOWN -> '
              'R.string.fa_question when Preferences.areQuestionMarksEnabled is '
              'true, otherwise R.string.fa_times; any other value -> '
              'R.string.fa_times.');
      expect(body, contains('Entry.SKIP -> FontAwesome.SKIPPED'),
          reason: 'widgets.checkmark-view#6');
      expect(
        body,
        contains('if (areQuestionMarksEnabled) FontAwesome.QUESTION '
            'else FontAwesome.TIMES'),
        reason: 'widgets.checkmark-view#6: the UNKNOWN branch',
      );
      expect(body, contains('else -> FontAwesome.TIMES'),
          reason: 'widgets.checkmark-view#6: NO and anything else');

      final String ringSource = widgetViewKotlin('RingView.kt');
      expect(
        <String, String>{
          for (final String glyph in <String>[
            'CHECK',
            'TIMES',
            'SKIPPED',
            'QUESTION',
          ])
            glyph: capture(
                ringSource, RegExp('const val $glyph = "(\\\\u[0-9A-F]{4})"')),
        },
        <String, String>{
          'CHECK': r'\uF00C',
          'TIMES': r'\uF00D',
          'SKIPPED': r'\uF068',
          'QUESTION': r'\uF128',
        },
        reason: 'widgets.checkmark-view#6: the four FontAwesome codepoints '
            'behind fa_check, fa_times, fa_skipped and fa_question',
      );
    });

    test('a numerical habit shows its value in units, clamped at zero', () {
      expect(view, contains('(max(0, entryValue) / 1000.0).toShortString()'),
          reason: 'widgets.checkmark-view#7 — Text for a numerical habit is '
              '(max(0, entryValue) / 1000.0).toShortString(), i.e. negatives '
              'clamp to 0 and the raw milli-units are divided by 1000.');

      final String format = widgetKotlin('NumberFormat.kt');
      expect(
        <String>[
          ...captureAll(
            format,
            RegExp(r'-> String\.format\(Locale\.getDefault\(\), "([^"]*)"'),
          ),
          ...captureAll(format, RegExp(r'-> DecimalFormat\("([^"]*)"\)')),
        ],
        <String>[
          '%.1fG',
          '%.0fM',
          '%.1fM',
          '%.1fM',
          '%.0fk',
          '%.1fk',
          '%.1fk',
          '#',
          '#.#',
          '#.##',
        ],
        reason: 'widgets.checkmark-view#7 — toShortString formats >=1e9 as '
            "'%.1fG', >=1e8 as '%.0fM', >=1e7/>=1e6 as '%.1fM', >=1e5 as "
            "'%.0fk', >=1e4/>=1e3 as '%.1fk', >=1e2 as '#', >=1e1 as '#.#', "
            "else '#.##'.",
      );
      expect(
        captureAll(format, RegExp(r'this >= (\S+) ->')),
        <String>['1e9', '1e8', '1e7', '1e6', '1e5', '1e4', '1e3', '1e2', '1e1'],
        reason: 'widgets.checkmark-view#7: the thresholds, in order',
      );
    });

    test('stroked ring text is only for an auto-satisfied boolean day', () {
      expect(
        capture(view,
                RegExp(r'private val strokedTextEnabled: Boolean\s*\n\s*get\(\) = (.*)\n'))
            .trim(),
        '!isNumerical && entryState == Entry.YES_AUTO',
        reason: 'widgets.checkmark-view#8 — Stroked (outlined) ring text is '
            'enabled only for a boolean habit whose entryState is YES_AUTO; it '
            'is always disabled for numerical habits.',
      );
    });

    test('the widget is at most 1.5x taller than wide and never wider than '
        'tall', () {
      final String body = view.substring(view.indexOf('override fun onMeasure'));

      expect(
        body,
        contains('if (height >= width) {\n'
            '            height = min(height, (width * 1.5).roundToInt())\n'
            '        } else {\n'
            '            width = min(width, height)\n'
            '        }'),
        reason: 'widgets.checkmark-view#9 — onMeasure: if height >= width then '
            'height = min(height, round(width * 1.5)); otherwise width = '
            'min(width, height). So the widget is at most 1.5x taller than '
            'wide, and never wider than it is tall.',
      );
    });

    test('text size, ring text size and ring thickness scale with the width',
        () {
      final String body = view.substring(view.indexOf('override fun onMeasure'));

      expect(
        argLines(capture(
            body, RegExp(r'val textSize = min\(\n([\s\S]*?)\n\s*\)\n'))),
        <String>[
          '0.175f * width',
          'spToPixels(context, WidgetDimens.SMALL_TEXT_SIZE_SP)',
        ],
        reason: 'widgets.checkmark-view#10 — onMeasure computes textSize = '
            'min(0.175f * width, R.dimen.smallTextSize=14sp in px), applies it '
            'to the label in px units, sets ring text size to textSize * 0.9f '
            'for numerical habits and textSize otherwise, and sets ring '
            'thickness to 0.03f * width.',
      );
      expect(
        capture(widgetKotlin('WidgetTheme.kt'),
            RegExp(r'const val SMALL_TEXT_SIZE_SP: Float = (\S+)')),
        '14f',
        reason: 'widgets.checkmark-view#10: smallTextSize is 14sp',
      );
      expect(
        body,
        contains('label.setTextSize(TypedValue.COMPLEX_UNIT_PX, textSize)'),
        reason: 'widgets.checkmark-view#10: applied in px units',
      );
      expect(
        body,
        contains('ring.setTextSize(if (isNumerical) textSize * 0.9f else textSize)'),
        reason: 'widgets.checkmark-view#10: 0.9x for numerical habits',
      );
      expect(body, contains('ring.setThickness(0.03f * width)'),
          reason: 'widgets.checkmark-view#10: thickness');
    });

    test('the ring is an arc from -90 degrees with a cleared centre and a '
        'centred glyph', () {
      final String ring = widgetViewKotlin('RingView.kt');
      final String body = ring.substring(
        ring.indexOf('override fun onDraw'),
        ring.indexOf('override fun onMeasure'),
      );

      expect(
        capture(body, RegExp(r'val angle = (.*)\n')).trim(),
        '360 * (percentage / precision).roundToLong() * precision',
        reason: 'widgets.checkmark-view#12 — RingView draws an arc starting at '
            '-90 degrees spanning 360 * round(percentage / precision) * '
            'precision degrees (precision default 0.01), fills the remainder '
            'with contrast100 at 15% alpha, punches out the inner disc (using '
            'PorterDuff CLEAR because transparency is enabled for widgets) and '
            'draws the glyph centred at (centerX, centerY + 0.4 * em) in the '
            'FontAwesome typeface; stroked text uses strokeWidth = textSize / '
            '15f.',
      );
      expect(capture(ring, RegExp(r'private var precision = (\S+)')), '0.01f',
          reason: 'widgets.checkmark-view#12: the default precision');
      expect(body, contains('drawArc(rect, -90f, angle, true, pRing)'),
          reason: 'widgets.checkmark-view#12: from -90 degrees');
      expect(body, contains('drawArc(rect, angle - 90, 360 - angle, true, pRing)'),
          reason: 'widgets.checkmark-view#12: the remainder');
      expect(
        capture(ring,
            RegExp(r'inactiveColor: Int = setAlpha\(WidgetTheme.CONTRAST_100, (\S+)\)')),
        '0.15f',
        reason: 'widgets.checkmark-view#12: contrast100 at 15% alpha',
      );
      expect(
        capture(ring,
            RegExp(r'XFERMODE_CLEAR = PorterDuffXfermode\(PorterDuff.Mode.(\w+)\)')),
        'CLEAR',
        reason: 'widgets.checkmark-view#12: the inner disc is punched out',
      );
      expect(
        body,
        contains('drawText(text, rect.centerX(), rect.centerY() + 0.4f * em, pRing)'),
        reason: 'widgets.checkmark-view#12: the glyph position',
      );
      expect(body, contains('pRing.strokeWidth = textSize / 15f'),
          reason: 'widgets.checkmark-view#12: stroked text width');
      expect(body, contains('pRing.typeface = FontAwesome.typeface(context)'),
          reason: 'widgets.checkmark-view#12: in the FontAwesome face');
    });

    test('the ring measures itself square', () {
      final String ring = widgetViewKotlin('RingView.kt');
      final String body = ring.substring(ring.indexOf('override fun onMeasure'));

      expect(
        capture(body, RegExp(r'diameter = (.*)\n')).trim(),
        'max(1, min(height, width))',
        reason: 'widgets.checkmark-view#13 — RingView.onMeasure forces a square: '
            'diameter = max(1, min(height, width)) and '
            'setMeasuredDimension(diameter, diameter).',
      );
      expect(body, contains('setMeasuredDimension(diameter, diameter)'),
          reason: 'widgets.checkmark-view#13');
    });
  });

  // =======================================================================
  // widgets.frequency
  // =======================================================================

  group('widgets.frequency', () {
    late String widget;

    setUp(() => widget = widgetKotlin('FrequencyWidget.kt'));

    test('the Frequency widget is 200x200 on a FrequencyChart in the graph '
        'shell', () {
      expect(
        capture(widget, RegExp(r'override val defaultWidth: Int get\(\) = (\d+)')),
        '200',
        reason: 'widgets.frequency#1 — FrequencyWidget default size is 200x200 '
            'px and its view is a GraphWidgetView wrapping a FrequencyChart.',
      );
      expect(
        capture(widget, RegExp(r'override val defaultHeight: Int get\(\) = (\d+)')),
        '200',
        reason: 'widgets.frequency#1',
      );
      expect(widget, contains('GraphWidgetView(context, FrequencyChartView(context))'),
          reason: 'widgets.frequency#1: the chart inside the shell');
    });

    test('the title is the habit name', () {
      expect(widget, contains('setTitle(habit.name)'),
          reason: 'widgets.frequency#2 — The widget title is habit.name.');
    });

    test('refreshData sets colour, numerical flag and the weekday buckets', () {
      final String body = widget.substring(widget.indexOf('override fun refreshData'));

      expect(body, contains('color = WidgetTheme.color(habit.color)'),
          reason: 'widgets.frequency#3 — refreshData sets the chart\'s '
              'firstWeekday from Preferences.firstWeekday (resolved by '
              'FrequencyWidgetProvider at construction time, not read again), '
              'colour = WidgetTheme().color(habit.color), isNumerical = '
              'habit.isNumerical, and frequency = '
              'habit.originalEntries.computeWeekdayFrequency(habit.isNumerical). '
              'pref_first_weekday is not in the published document, so the '
              'chart keeps the preference default (Sunday).');
      expect(body, contains('isNumerical = habit.isNumerical'),
          reason: 'widgets.frequency#3');
      expect(
        body,
        contains('frequency = FrequencyChartView.computeWeekdayFrequency('
            'habit, this@FrequencyWidget.today)'),
        reason: 'widgets.frequency#3',
      );
      expect(
        capture(widgetViewKotlin('FrequencyChartView.kt'),
            RegExp(r'var firstWeekday: Int = (\d+)')),
        '0',
        reason: 'widgets.frequency#3: firstWeekday as daysSinceSunday, '
            'defaulting to Sunday',
      );
    });

    test('computeWeekdayFrequency buckets by month and weekday', () {
      final String source = widgetViewKotlin('FrequencyChartView.kt');
      final String body =
          source.substring(source.indexOf('fun computeWeekdayFrequency'));

      expect(body, contains('if (value == Entry.UNKNOWN) return@forEachIndexed'),
          reason: 'widgets.frequency#4 — computeWeekdayFrequency buckets every '
              'KNOWN entry by its month start; within each month it accumulates '
              'into a 7-slot array indexed by (dayOfWeek.daysSinceSunday + 1) % '
              '7; for numerical habits it adds the raw entry value, for boolean '
              'habits it adds 1 only when the entry value equals YES_MANUAL (2).');
      expect(
        body,
        contains('result.getOrPut(date.startOfMonth()) { IntArray(7) }'),
        reason: 'widgets.frequency#4: a 7-slot array per month start',
      );
      expect(
        capture(body, RegExp(r'val slot = (.*)\n')).trim(),
        '(date.daysSinceSunday + 1) % 7',
        reason: 'widgets.frequency#4: the slot index',
      );
      expect(body, contains('bucket[slot] += value'),
          reason: 'widgets.frequency#4: numerical habits add the raw value');
      expect(
        body,
        contains('} else if (value == Entry.YES_MANUAL) {\n'
            '                    bucket[slot] += 1'),
        reason: 'widgets.frequency#4: boolean habits add 1 only for YES_MANUAL',
      );
    });

    test('auto-satisfied days do not count towards the frequency', () {
      final String source = widgetViewKotlin('FrequencyChartView.kt');
      final String body =
          source.substring(source.indexOf('fun computeWeekdayFrequency'));

      expect(body, isNot(contains('Entry.YES_AUTO')),
          reason: 'widgets.frequency#5 — The widget reads originalEntries '
              '(user-entered data), not computedEntries — so auto-satisfied '
              'YES_AUTO days do not count. The v1 contract publishes '
              'computedEntries, so the YES_MANUAL test above is what keeps '
              'auto-satisfied days out of the buckets; it is the closest this '
              'build gets and the shortfall is named in the class KDoc.');
    });

    test('tapping opens the habit detail screen', () {
      expect(widget, contains('WidgetIntents.showHabit(context, id, habit)'),
          reason: 'widgets.frequency#6 — Tapping the Frequency widget opens '
              'ShowHabitActivity for that habit via a TaskStackBuilder '
              'PendingIntent with the parent activity stack (FLAG_IMMUTABLE|'
              'FLAG_UPDATE_CURRENT, request code 0). Flutter runs one activity, '
              'so the synthetic back stack becomes the app\'s own route stack.');
      expect(
        capture(widgetKotlin('WidgetIntents.kt'),
            RegExp(r'const val ACTION_SHOW = "([^"]*)"')),
        'show',
        reason: 'widgets.frequency#6: the deep-link action',
      );
    });
  });

  // =======================================================================
  // widgets.history
  // =======================================================================

  group('widgets.history', () {
    late String widget;

    setUp(() => widget = widgetKotlin('HistoryWidget.kt'));

    test('the History widget is 250x250 on a HistoryChart in the graph shell',
        () {
      expect(
        capture(widget, RegExp(r'override val defaultWidth: Int get\(\) = (\d+)')),
        '250',
        reason: 'widgets.history#1 — HistoryWidget default size is 250x250 px; '
            'its view is a GraphWidgetView wrapping an AndroidDataView whose '
            'inner view is a core HistoryChart.',
      );
      expect(
        capture(widget, RegExp(r'override val defaultHeight: Int get\(\) = (\d+)')),
        '250',
        reason: 'widgets.history#1',
      );
      expect(widget, contains('GraphWidgetView(context, HistoryChartView(context))'),
          reason: 'widgets.history#1');
    });

    test('the chart is built with the widget palette, the document\'s today '
        'and 2.5 padding', () {
      final String chart = widgetViewKotlin('HistoryChartView.kt');

      expect(capture(chart, RegExp(r'private val padding = (\S+)')), '2.5',
          reason: 'widgets.history#2 — The HistoryChart is constructed with '
              'today = getToday(), paletteColor = habit.color, theme = '
              'WidgetTheme(), dateFormatter = '
              'JavaLocalDateFormatter(Locale.getDefault()), firstWeekday = '
              'Preferences.firstWeekday, series = empty list, defaultSquare = '
              'HistoryChart.Square.OFF, notesIndicators = empty list, and '
              'padding = 2.5.');
      expect(
        capture(chart, RegExp(r'var defaultSquare: Square = Square\.(\w+)')),
        'OFF',
        reason: 'widgets.history#2: defaultSquare OFF',
      );
      expect(capture(chart, RegExp(r'var series: List<Square> = (\w+)')),
          'emptyList',
          reason: 'widgets.history#2: an empty series until refreshData runs');
      expect(widget, contains('this.today = this@HistoryWidget.today'),
          reason: 'widgets.history#2: today comes from the document');
      expect(widget, contains('paletteColor = habit.color'),
          reason: 'widgets.history#2: paletteColor');
      expect(
        chart,
        contains('enum class Square { ON, OFF, GREY, DIMMED, HATCHED }'),
        reason: 'widgets.history#2: the same five squares the core chart has',
      );
    });

    test('the title is the habit name', () {
      expect(widget, contains('setTitle(habit.name)'),
          reason: 'widgets.history#3 — The widget title is habit.name.');
    });

    test('refreshData recomputes the series and the default square', () {
      final String body = widget.substring(widget.indexOf('override fun refreshData'));

      expect(body, contains('series = HistoryChartView.seriesOf(habit)'),
          reason: 'widgets.history#4 — refreshData recomputes state via '
              'HistoryCardPresenter.buildState(habit, firstWeekday = '
              'prefs.firstWeekday, theme = WidgetTheme()) and copies '
              'model.series, model.defaultSquare and model.notesIndicators onto '
              'the chart. The presenter is Dart; the launcher process rebuilds '
              'the same series from the published entries.');
      expect(body, contains('defaultSquare = HistoryChartView.Square.OFF'),
          reason: 'widgets.history#4: and the default square');

      final String chart = widgetViewKotlin('HistoryChartView.kt');
      final String series = chart.substring(chart.indexOf('fun seriesOf'));
      expect(series, contains('Entry.YES_MANUAL -> Square.ON'),
          reason: 'widgets.history#4: the boolean mapping the presenter uses');
      expect(series, contains('Entry.YES_AUTO -> Square.DIMMED'),
          reason: 'widgets.history#4');
      expect(series, contains('Entry.SKIP -> Square.HATCHED'),
          reason: 'widgets.history#4');
      expect(series, contains('else -> Square.OFF'),
          reason: 'widgets.history#4');
    });

    test('tapping opens the habit detail screen', () {
      expect(widget, contains('WidgetIntents.showHabit(context, id, habit)'),
          reason: 'widgets.history#5 — Tapping the History widget opens '
              'ShowHabitActivity for that habit via the parent-stack '
              'PendingIntent.');
    });

    test('the chart is a static bitmap with no gestures', () {
      final String chart = widgetViewKotlin('HistoryChartView.kt');

      expect(chart, isNot(contains('onTouchEvent')),
          reason: 'widgets.history#6 — The rendered chart is a static bitmap: '
              'the scroll/tap gestures that AndroidDataView supports in the app '
              'are unavailable inside the widget.');
      expect(chart, isNot(contains('GestureDetector')),
          reason: 'widgets.history#6');
      expect(chart, isNot(contains('Scroller')),
          reason: 'widgets.history#6');
    });
  });

  // =======================================================================
  // widgets.score
  // =======================================================================

  group('widgets.score', () {
    late String widget;

    setUp(() => widget = widgetKotlin('ScoreWidget.kt'));

    test('the Score widget is 300x300 — the largest of the six', () {
      expect(
        capture(widget, RegExp(r'override val defaultWidth: Int get\(\) = (\d+)')),
        '300',
        reason: 'widgets.score#1 — ScoreWidget default size is 300x300 px — the '
            'largest default of any widget; its view is a GraphWidgetView '
            'wrapping a ScoreChart.',
      );
      expect(
        capture(widget, RegExp(r'override val defaultHeight: Int get\(\) = (\d+)')),
        '300',
        reason: 'widgets.score#1',
      );
      expect(widget, contains('GraphWidgetView(context, ScoreChartView(context))'),
          reason: 'widgets.score#1');

      // Larger than every other default in the set.
      for (final String other in <String>[
        'CheckmarkWidget',
        'FrequencyWidget',
        'HistoryWidget',
        'StreakWidget',
        'TargetWidget',
      ]) {
        expect(
          int.parse(capture(widgetKotlin('$other.kt'),
              RegExp(r'override val defaultWidth: Int get\(\) = (\d+)'))),
          lessThan(300),
          reason: 'widgets.score#1: larger than $other',
        );
      }
    });

    test('the title is the habit name', () {
      expect(widget, contains('setTitle(habit.name)'),
          reason: 'widgets.score#2 — The widget title is habit.name.');
    });

    test('the bucket size falls back to the preference default of weekly', () {
      expect(
        capture(widgetViewKotlin('ScoreChartView.kt'),
            RegExp(r'var bucketSize: Int = (\d+)')),
        '7',
        reason: 'widgets.score#4 — BUCKET_SIZES = [1, 7, 31, 92, 365] indexed by '
            'spinnerPosition; scoreCardSpinnerPosition is clamped to 0..4 and '
            'defaults to 1 (weekly buckets). The preference is not in the '
            'published document, so the widget can only ever use the default '
            'position, whose bucket size is 7.',
      );
      expect(widget, contains('bucketSize = habit.bucketSize'),
          reason: 'widgets.score#4: read from the document when it appears');
      expect(
        capture(widgetKotlin('WidgetData.kt'),
            RegExp(r'bucketSize = json.optInt\("bucketSize", (\d+)\)')),
        '7',
        reason: 'widgets.score#4: with the same default on the parse side',
      );
    });

    test('refreshData enables transparency, sets the colour and the series',
        () {
      final String body = widget.substring(widget.indexOf('override fun refreshData'));

      expect(body, contains('color = WidgetTheme.color(habit.color)'),
          reason: 'widgets.score#5 — refreshData enables transparency on the '
              'chart (setIsTransparencyEnabled(true)), sets bucketSize from the '
              'view model, sets colour = WidgetTheme().color(habit.color), and '
              'sets the score list. Transparency is unconditional here: the '
              'whole widget is rasterised onto a transparent bitmap, so there '
              'is no opaque mode to switch out of.');
      expect(body, contains('bucketSize = habit.bucketSize'),
          reason: 'widgets.score#5: the bucket size');
      expect(body, contains('scores = habit.scores ?: DoubleArray(0)'),
          reason: 'widgets.score#5: the score list');
      expect(
        widgetViewKotlin('ScoreChartView.kt'),
        contains('var scores: DoubleArray = DoubleArray(0)'),
        reason: 'widgets.score#5: newest first, one value per bucket',
      );
    });

    test('tapping opens the habit detail screen', () {
      expect(widget, contains('WidgetIntents.showHabit(context, id, habit)'),
          reason: 'widgets.score#7 — Tapping the Score widget opens '
              'ShowHabitActivity for that habit.');
    });
  });

  // =======================================================================
  // widgets.streak
  // =======================================================================

  group('widgets.streak', () {
    late String widget;

    setUp(() => widget = widgetKotlin('StreakWidget.kt'));

    test('the Streak widget is 200x200 and fills its shell', () {
      expect(
        capture(widget, RegExp(r'override val defaultWidth: Int get\(\) = (\d+)')),
        '200',
        reason: 'widgets.streak#1 — StreakWidget default size is 200x200 px; its '
            'view is a GraphWidgetView wrapping a StreakChart, and the '
            'GraphWidgetView is given LayoutParams(MATCH_PARENT, MATCH_PARENT).',
      );
      expect(
        capture(widget, RegExp(r'override val defaultHeight: Int get\(\) = (\d+)')),
        '200',
        reason: 'widgets.streak#1',
      );
      expect(widget, contains('GraphWidgetView(context, chart)'),
          reason: 'widgets.streak#1');
      expect(
        widget,
        contains('view.layoutParams = ViewGroup.LayoutParams(\n'
            '            ViewGroup.LayoutParams.MATCH_PARENT,\n'
            '            ViewGroup.LayoutParams.MATCH_PARENT\n'
            '        )'),
        reason: 'widgets.streak#1: MATCH_PARENT in both directions',
      );
    });

    test('the title is the habit name', () {
      expect(widget, contains('view.setTitle(habit.name)'),
          reason: 'widgets.streak#2 — The widget title is habit.name.');
    });

    test('refreshData sets the colour and the best streaks that fit', () {
      final String body = widget.substring(widget.indexOf('override fun refreshData'));

      expect(body, contains('color = WidgetTheme.color(habit.color)'),
          reason: 'widgets.streak#3 — refreshData sets colour = '
              'WidgetTheme().color(habit.color) and streaks = '
              'habit.streaks.getBest(chart.maxStreakCount). The streak list is '
              'not in the v1 contract, so the chart rebuilds it from the 60 '
              'published days and truncates to the same count.');
      expect(body, contains('habit.streaks?.take(maxStreakCount)'),
          reason: 'widgets.streak#3: getBest(maxStreakCount) when it is '
              'published');
      expect(
        body,
        contains('StreakChartView.streaksFrom(habit, today, maxStreakCount)'),
        reason: 'widgets.streak#3: and the same limit on the fallback',
      );
      expect(
        widgetViewKotlin('StreakChartView.kt'),
        contains('.sortedByDescending { it.length }.take(max(0, limit))'),
        reason: 'widgets.streak#3: longest first, which is what getBest means',
      );
    });

    test('the number of bars is the measured height over the base size', () {
      final String chart = widgetViewKotlin('StreakChartView.kt');

      expect(
        capture(chart, RegExp(r'val maxStreakCount: Int\s*\n\s*get\(\) = (.*)\n'))
            .trim(),
        'if (baseSize <= 0) 0 else floor(measuredHeight.toDouble() / baseSize).toInt()',
        reason: 'widgets.streak#4 — StreakChart.maxStreakCount = '
            'floor(measuredHeight / baseSize) — i.e. the number of streak bars '
            'shown adapts to the widget\'s current height, and is read AFTER '
            'the view has been measured.',
      );
      expect(
        capture(chart,
            RegExp(r'baseSize = dpToPixels\(context, WidgetDimens\.(\w+)\)')),
        'BASE_SIZE_DP',
        reason: 'widgets.streak#4: baseSize is R.dimen.baseSize',
      );
      expect(
        capture(widgetKotlin('WidgetTheme.kt'),
            RegExp(r'const val BASE_SIZE_DP: Float = (\S+)')),
        '20f',
        reason: 'widgets.streak#4: which is 20dp',
      );
      // maxStreakCount is read inside refreshData, which BaseWidget runs after
      // the first measureView pass.
      final String base = widgetKotlin('BaseWidget.kt');
      expect(
        base.indexOf('measureView(view, width, height)'),
        lessThan(base.indexOf('refreshData(view)')),
        reason: 'widgets.streak#4: read after the view has been measured',
      );
    });

    test('a numerical habit can never reach the Streak widget', () {
      final Map<String, String> info = xmlRoot(
        androidSource('res/xml/widget_streak_info.xml'),
        'appwidget-provider',
      );

      expect(
        info['android:configure'],
        'org.isoron.uhabits.widgets.activities.BooleanHabitPickerDialog',
        reason: 'widgets.streak#5 — The Streak widget\'s configure activity is '
            'BooleanHabitPickerDialog, so numerical habits can never be chosen '
            'for it.',
      );
    });

    test('tapping opens the habit detail screen', () {
      expect(widget, contains('WidgetIntents.showHabit(context, id, habit)'),
          reason: 'widgets.streak#6 — Tapping the Streak widget opens '
              'ShowHabitActivity for that habit.');
    });
  });

  // =======================================================================
  // widgets.target
  // =======================================================================

  group('widgets.target', () {
    late String widget;

    setUp(() => widget = widgetKotlin('TargetWidget.kt'));

    test('the Target widget is 200x200 and fills its shell', () {
      expect(
        capture(widget, RegExp(r'override val defaultWidth: Int get\(\) = (\d+)')),
        '200',
        reason: 'widgets.target#1 — TargetWidget default size is 200x200 px; its '
            'view is a GraphWidgetView wrapping a TargetChart with '
            'LayoutParams(MATCH_PARENT, MATCH_PARENT).',
      );
      expect(
        capture(widget, RegExp(r'override val defaultHeight: Int get\(\) = (\d+)')),
        '200',
        reason: 'widgets.target#1',
      );
      expect(
        widget,
        contains('view.layoutParams = ViewGroup.LayoutParams(\n'
            '            ViewGroup.LayoutParams.MATCH_PARENT,\n'
            '            ViewGroup.LayoutParams.MATCH_PARENT\n'
            '        )'),
        reason: 'widgets.target#1: MATCH_PARENT in both directions',
      );
    });

    test('the title is the habit name', () {
      expect(widget, contains('view.setTitle(habit.name)'),
          reason: 'widgets.target#2 — The widget title is habit.name.');
    });

    test('refreshData sets colour, labels, values and targets', () {
      final String body = widget.substring(widget.indexOf('override fun refreshData'));

      expect(body, contains('color = WidgetTheme.color(habit.color)'),
          reason: 'widgets.target#3 — refreshData runs inside runBlocking and '
              'builds state via TargetCardPresenter.buildState(habit, '
              'firstWeekday = prefs.firstWeekdayInt, theme = WidgetTheme()), '
              'then sets chart colour, targets, labels and values. The '
              'presenter is Dart; the launcher process derives the same four '
              'from the published entries, so there is nothing to block on and '
              'no runBlocking.');
      expect(body, contains('labels = INTERVALS.map { intervalToLabel(it) }'),
          reason: 'widgets.target#3: labels');
      expect(body, contains('values = INTERVALS.map { windowSum(it) }'),
          reason: 'widgets.target#3: values');
      expect(body, contains('targets = INTERVALS.map { windowTarget(it) }'),
          reason: 'widgets.target#3: targets');
    });

    test('the interval labels are today / week / month / quarter / year', () {
      final String body = widget.substring(widget.indexOf('private fun intervalToLabel'));

      expect(
        <String, String>{
          '1': capture(body, RegExp(r'1 -> "([^"]*)"')),
          '7': capture(body, RegExp(r'7 -> "([^"]*)"')),
          '30': capture(body, RegExp(r'30 -> "([^"]*)"')),
          '91': capture(body, RegExp(r'91 -> "([^"]*)"')),
          'else': capture(body, RegExp(r'else -> "([^"]*)"')),
        },
        <String, String>{
          '1': 'Today',
          '7': 'Week',
          '30': 'Month',
          '91': 'Quarter',
          'else': 'Year',
        },
        reason: 'widgets.target#4 — Interval labels come from '
            'TargetCardView.intervalToLabel: 1 -> R.string.today, 7 -> '
            'R.string.week, 30 -> R.string.month, 91 -> R.string.quarter, '
            'anything else -> R.string.year. The strings are literals here '
            'because a widget provider has no access to the Flutter ARB '
            'bundle.',
      );
    });

    test('the interval list is the full five, because the frequency is not '
        'published', () {
      expect(
        capture(widget, RegExp(r'private val INTERVALS = listOf\(([^)]*)\)'))
            .split(',')
            .map((String s) => s.trim())
            .toList(),
        <String>['1', '7', '30', '91', '365'],
        reason: 'widgets.target#5 — The interval list is dynamic: interval 1 '
            '(today) is included only when habit.frequency.denominator <= 1; '
            'interval 7 (week) only when denominator <= 7; intervals 30, 91 and '
            '365 are always included. So a weekly habit shows 4 bars and a '
            'monthly habit shows 3. The frequency is NOT in the v1 contract, so '
            'the denominator is assumed to be 1 and all five rows are drawn — a '
            'weekly habit shows a Today row it should not have. Named in the '
            'class KDoc; it closes the moment the bridge publishes the '
            'frequency.',
      );
    });

    test('window values are the summed entries divided by 1000', () {
      final String body = widget.substring(widget.indexOf('private fun windowSum'));

      expect(body, contains('return total / 1e3'),
          reason: 'widgets.target#6 — Values are the grouped sums divided by '
              '1000 (milli-units to units) for day/week/month/quarter/year '
              'windows.');
      expect(
        capture(body, RegExp(r'val days = min\(([^)]*)\)')),
        'interval, habit.entries.size',
        reason: 'widgets.target#6: over the window, clamped to what was '
            'published — Quarter and Year read low because only 60 days ship',
      );
      expect(body, contains('if (value > 0) total += value'),
          reason: 'widgets.target#6: only positive entries contribute');
    });

    test('each window target is reduced by the skipped days and floored at '
        'zero', () {
      final String body = widget.substring(widget.indexOf('private fun windowTarget'));

      expect(
        capture(body, RegExp(r'return max\(0.0, (.*)\)\n')).trim(),
        'habit.target * interval - habit.target * skipped',
        reason: 'widgets.target#7 — Targets are reduced by dailyTarget * '
            'skippedDays for each window and floored at 0.0, where dailyTarget '
            '= habit.targetValue / habit.frequency.denominator. The denominator '
            'is not published, so dailyTarget is the target value itself.',
      );
      expect(
        capture(body, RegExp(r'\.count \{ habit.entries\[it\] == Entry\.(\w+) \}')),
        'SKIP',
        reason: 'widgets.target#7: skippedDays counts SKIP entries',
      );
    });

    test('a boolean habit can never reach the Target widget', () {
      final Map<String, String> info = xmlRoot(
        androidSource('res/xml/widget_target_info.xml'),
        'appwidget-provider',
      );

      expect(
        info['android:configure'],
        'org.isoron.uhabits.widgets.activities.NumericalHabitPickerDialog',
        reason: 'widgets.target#8 — The Target widget\'s configure activity is '
            'NumericalHabitPickerDialog, so boolean habits can never be chosen '
            'for it.',
      );
    });

    test('tapping opens the habit detail screen', () {
      expect(widget, contains('WidgetIntents.showHabit(context, id, habit)'),
          reason: 'widgets.target#9 — Tapping the Target widget opens '
              'ShowHabitActivity for that habit.');
    });
  });
}
