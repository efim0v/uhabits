/// `charts-canvas-theming.chart-host-contracts`, the widget half.
///
/// Two of this feature's rules describe the show-habit cards and the history
/// editor, and are asserted where those live — `#2` and `#5` in
/// app/test/ui/habits/show/chart_cards_test.dart, `#3` in
/// app/test/ui/common/dialogs/history_editor_dialog_test.dart. The three left
/// are about the *widget* host: what the history widget builds its chart with,
/// the frame `GraphWidgetView` wraps a chart in, and the opacity list that
/// frame is painted at.
///
/// All three live in `app/android/app/src/main`, a real Android source set that
/// cannot execute here, so — exactly as app/test/platform/android_widgets_test.
/// dart does and for the same reasons — each case extracts a *value* from the
/// file that declares it and compares it. Nothing below passes merely because a
/// file mentions something.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/settings_model.dart';

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

/// The one capture of [pattern] in [source], or a failure naming what was
/// looked for.
String capture(String source, RegExp pattern) {
  final RegExpMatch? match = pattern.firstMatch(source);
  if (match == null) throw StateError('no match for ${pattern.pattern}');
  return match.group(1)!;
}

/// The attributes of the first element named [tag] in [xml].
Map<String, String> xmlElement(String xml, String tag) {
  final RegExpMatch? open = RegExp('<$tag(?=[\\s/>])').firstMatch(xml);
  if (open == null) throw StateError('no <$tag> in the layout');
  final int gt = xml.indexOf('>', open.start);
  final String head = xml.substring(open.start, gt);
  return <String, String>{
    for (final RegExpMatch m
        in RegExp(r'([\w:.-]+)\s*=\s*"([^"]*)"').allMatches(head))
      m.group(1)!: m.group(2)!,
  };
}

void main() {
  group('charts-canvas-theming.chart-host-contracts', () {
    test('#4 the history widget: padding 2.5, WidgetTheme, 250x250', () {
      const rule = 'charts-canvas-theming.chart-host-contracts#4';

      final String chart = widgetViewKotlin('HistoryChartView.kt');
      expect(capture(chart, RegExp(r'val padding = ([\d.]+)')), '2.5',
          reason: '$rule — the history chart is built with padding = 2.5, '
              'where the history *editor* uses 10.0');

      // `theme = WidgetTheme()`: the widget renders against the widget palette
      // and its transparent card background, never the app theme.
      expect(chart.contains('WidgetTheme.CARD_BACKGROUND_COLOR'), isTrue,
          reason: '$rule — and against WidgetTheme()');
      expect(RegExp(r'WidgetTheme\.[A-Z_]').allMatches(chart).length,
          greaterThan(3),
          reason: '$rule — every colour it draws with comes from WidgetTheme');
      expect(chart.contains('LightTheme'), isFalse, reason: rule);

      final String widget = widgetKotlin('HistoryWidget.kt');
      expect(capture(widget, RegExp(r'defaultWidth: Int get\(\) = (\d+)')),
          '250',
          reason: '$rule — its default widget size is 250x250');
      expect(capture(widget, RegExp(r'defaultHeight: Int get\(\) = (\d+)')),
          '250',
          reason: rule);
      expect(widget.contains('GraphWidgetView(context, HistoryChartView'),
          isTrue,
          reason: '$rule — built into the shared graph frame');
    });

    test('#6 GraphWidgetView: 4dp top, 8dp elsewhere, two centred white lines',
        () {
      const rule = 'charts-canvas-theming.chart-host-contracts#6';

      final String layout = androidSource('res/layout/widget_graph.xml');
      final Map<String, String> inner = xmlElement(layout, 'LinearLayout');
      expect(inner['android:id'], '@+id/innerFrame', reason: rule);
      expect(inner['android:paddingTop'], '4dp',
          reason: '$rule — 4dp top padding');
      expect(inner['android:paddingLeft'], '8dp',
          reason: '$rule — and 8dp on the other three sides');
      expect(inner['android:paddingRight'], '8dp', reason: rule);
      expect(inner['android:paddingBottom'], '8dp', reason: rule);

      final Map<String, String> title = xmlElement(layout, 'TextView');
      expect(title['android:id'], '@+id/title', reason: rule);
      expect(title['android:gravity'], 'center',
          reason: '$rule — a centred title');
      expect(title['android:maxLines'], '2', reason: '$rule — of two lines');
      expect(title['android:textColor'], '#ffffff',
          reason: '$rule — in white');
      expect(title['android:textSize'], '14sp',
          reason: '$rule — at smallTextSize, R.dimen.smallTextSize being 14sp');

      // "wraps any chart View": the frame takes the chart as a constructor
      // argument and fills itself with it.
      final String view = widgetViewKotlin('GraphWidgetView.kt');
      expect(
        view.contains('class GraphWidgetView(context: Context, val dataView: View)'),
        isTrue,
        reason: '$rule — any View, not a particular chart',
      );
      expect(view.contains('R.layout.widget_graph'), isTrue, reason: rule);
      expect(
        RegExp(r'ViewGroup\.LayoutParams\.MATCH_PARENT')
            .allMatches(view)
            .length,
        2,
        reason: '$rule — the chart fills the frame under the title',
      );
      expect(view.contains('title.visibility = VISIBLE'), isTrue,
          reason: '$rule — and the title is shown');
    });

    test('#7 the opacity list, and the shadow the opaque end turns on', () {
      const rule = 'charts-canvas-theming.chart-host-contracts#7';

      expect(SettingsModel.widgetOpacityValues,
          <String>['255', '204', '153', '102', '51', '0'],
          reason: '$rule — the fixed list of six alpha values');
      expect(SettingsModel.widgetOpacityLabels,
          <String>['100%', '80%', '60%', '40%', '20%', '0%'],
          reason: '$rule — labelled 100%, 80%, 60%, 40%, 20%, 0%');
      expect(SettingsModel.widgetOpacityValues.length,
          SettingsModel.widgetOpacityLabels.length,
          reason: '$rule — the two arrays are read positionally');

      // `if (preferedBackgroundAlpha >= 255) widgetView.setShadowAlpha(0x4f)`,
      // in each of the five graph widgets.
      for (final String name in <String>[
        'HistoryWidget.kt',
        'ScoreWidget.kt',
        'StreakWidget.kt',
        'FrequencyWidget.kt',
        'TargetWidget.kt',
      ]) {
        final String source = widgetKotlin(name);
        expect(
          capture(
            source,
            RegExp(r'if \(preferedBackgroundAlpha >= (\d+)\) setShadowAlpha'
                r'\((0x[0-9a-fA-F]+)\)'),
          ),
          '255',
          reason: '$rule — $name gates on the fully opaque end of the list',
        );
        expect(
          RegExp(r'setShadowAlpha\((0x[0-9a-fA-F]+)\)')
              .firstMatch(source)!
              .group(1),
          '0x4f',
          reason: '$rule — and sets the shadow alpha to 0x4F',
        );
      }

      // The gate is `>=`, so only the first entry of the list turns the shadow
      // on; 204 and below leave it at whatever the frame was built with.
      expect(int.parse(SettingsModel.widgetOpacityValues.first), 255,
          reason: '$rule — 255 is the only value that satisfies it');
      for (final String value in SettingsModel.widgetOpacityValues.skip(1)) {
        expect(int.parse(value), lessThan(255), reason: rule);
      }
    });
  });
}
