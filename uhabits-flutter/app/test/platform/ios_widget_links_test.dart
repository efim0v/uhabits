/// `audit4.ios-home-screen-widgets-have-no`: what happens when a finger lands
/// on an iOS home-screen widget.
///
/// On Android every widget is wrapped in a `PendingIntent`
/// (`BaseWidget.getOnClickPendingIntent`): a boolean Checkmark toggles today's
/// entry, a numerical one opens the value picker, and each of the five graph
/// widgets opens the habit's detail screen. The port funnels all three into one
/// deep link per action — `app/android/.../widgets/WidgetIntents.kt` — and
/// `WidgetLinkRouter` acts on them.
///
/// The iOS extension declared none of it: no `widgetURL`, no `Link`, no
/// `Button(intent:)`, and `ios/Runner/Info.plist` registered no `uhabits` URL
/// scheme, so even a hand-typed link could not have reached the app. The whole
/// toggle/edit/show branch of `WidgetLinkRouter` was unreachable on iOS, and a
/// widget was a picture with no behaviour behind it.
///
/// ## What is asserted
///
/// Three things that only agree by construction:
///
///  1. the scheme, the authority and the three action names the Swift builds
///     are the ones `WidgetLink.parse` accepts — read out of both sides and
///     compared, never typed twice;
///  2. a URL of that shape, assembled here exactly as the Swift assembles it,
///     survives `WidgetLink.parse` with the habit and the day the widget meant;
///  3. every one of the six widgets attaches the action its Android
///     counterpart attaches, and `Info.plist` registers the scheme that makes
///     any of them deliverable.
///
/// The URL also has to carry the `homeWidget` query item: the `home_widget`
/// plugin's iOS half (`SwiftHomeWidgetPlugin.isWidgetUrl`) hands Dart only the
/// URLs that have one, so a link without it opens the app and is then dropped
/// on the floor.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/widget_link.dart';

// ---------------------------------------------------------------------------
// Locating the source set
// ---------------------------------------------------------------------------

final Directory appDir = _findApp();
final Directory widgetDir = Directory('${appDir.path}/ios/HabitsWidget');

Directory _findApp() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String prefix in <String>['', '/app']) {
      final Directory candidate = Directory('${dir.path}$prefix');
      if (File('${candidate.path}/ios/HabitsWidget/WidgetData.swift')
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

String swift(String name) => File('${widgetDir.path}/$name').readAsStringSync();

String get infoPlist =>
    File('${appDir.path}/ios/Runner/Info.plist').readAsStringSync();

/// The value of a `static let <name> = "…"` in the widget source set.
String swiftConstant(String source, String name) {
  final RegExpMatch? match =
      RegExp('static let $name = "([^"]*)"').firstMatch(source);
  if (match == null) fail('no `static let $name = "…"` in the Swift source');
  return match.group(1)!;
}

/// The body of one SwiftUI view struct, from its header to the next top-level
/// declaration — so an assertion about one widget cannot be satisfied by the
/// contents of the next one.
String declaration(String source, String header) {
  final int start = source.indexOf(header);
  if (start < 0) fail('$header is not declared');
  final int next = source.indexOf(
    RegExp(r'^(struct|extension|enum|protocol|private struct|final class|class) ',
        multiLine: true),
    start + header.length,
  );
  return source.substring(start, next < 0 ? source.length : next);
}

const String rule =
    'audit4.ios-home-screen-widgets-have-no#1 — In the Kotlin app: Tapping a '
    'boolean Checkmark widget toggles today\'s entry in place; tapping a '
    'numerical one opens the value picker; tapping any of the five graph '
    'widgets (History, Score, Streaks, Frequency, Target) opens '
    'ShowHabitActivity for that habit with the list beneath it.';

/// The five widgets whose tap opens the habit screen, and their files.
const List<String> graphWidgets = <String>[
  'HistoryWidget',
  'ScoreWidget',
  'StreakWidget',
  'FrequencyWidget',
  'TargetWidget',
];

void main() {
  group('audit4.ios-home-screen-widgets-have-no', () {
    test('#1 the app registers the scheme the widgets link into', () {
      // CFBundleURLTypes is an array of dicts, so read the schemes directly.
      final List<String> declared = RegExp(
        r'<key>CFBundleURLSchemes</key>\s*<array>([\s\S]*?)</array>',
      )
          .allMatches(infoPlist)
          .expand((RegExpMatch m) => RegExp(r'<string>([^<]*)</string>')
              .allMatches(m.group(1)!)
              .map((RegExpMatch s) => s.group(1)!))
          .toList();

      expect(declared, contains(WidgetLink.scheme),
          reason: '$rule iOS delivers a URL to an app only if the app claims '
              'its scheme in CFBundleURLTypes. Without the claim every '
              'widgetURL is inert: the tap does nothing at all, and the '
              'toggle/edit/show branch of WidgetLinkRouter can never run.');
      expect(infoPlist, contains('CFBundleURLName'),
          reason: '$rule A URL type declares the role it fills; Apple asks for '
              'a name alongside the schemes.');
    });

    test('#1 the Swift link builder speaks the scheme WidgetLink parses', () {
      final String source = swift('WidgetData.swift');

      expect(swiftConstant(source, 'scheme'), WidgetLink.scheme, reason: rule);
      expect(swiftConstant(source, 'authority'), WidgetLink.authority,
          reason: rule);
      expect(swiftConstant(source, 'actionToggle'), WidgetLink.actionToggle,
          reason: '$rule The three actions are the ones WidgetIntents.kt '
              'already builds and WidgetLinkRouter already routes; iOS reuses '
              'them rather than inventing a second vocabulary.');
      expect(swiftConstant(source, 'actionEdit'), WidgetLink.actionEdit,
          reason: rule);
      expect(swiftConstant(source, 'actionShow'), WidgetLink.actionShow,
          reason: rule);
    });

    test('#1 the URL the Swift assembles is one the router acts on', () {
      final String source = swift('WidgetData.swift');
      final String marker = swiftConstant(source, 'pluginMarker');

      expect(marker, 'homeWidget',
          reason: '$rule `SwiftHomeWidgetPlugin.isWidgetUrl` forwards to Dart '
              'only the URLs carrying a query item with this name; a link '
              'without it brings the app to the front and is then discarded, '
              'which looks exactly like the tap doing nothing.');

      // Assembled here the way the Swift assembles it, and parsed by the very
      // class the app routes with.
      final WidgetLink? toggle = WidgetLink.parse(Uri.parse(
          '${WidgetLink.scheme}://${WidgetLink.authority}/'
          '${WidgetLink.actionToggle}?habit=7&$marker=true'));
      expect(toggle, isNotNull, reason: rule);
      expect(toggle!.action, WidgetLink.actionToggle, reason: rule);
      expect(toggle.habitId, 7,
          reason: '$rule The tap addresses one habit, by id.');
      expect(toggle.widgetId, 0,
          reason: '$rule iOS has no widget id — a WidgetKit widget is '
              'configured by an App Intent, not by an id the launcher hands '
              'out — and widgets.config-picker#1 already says a link with no '
              'id means 0.');

      final WidgetLink edit = WidgetLink.parse(Uri.parse(
          '${WidgetLink.scheme}://${WidgetLink.authority}/'
          '${WidgetLink.actionEdit}?habit=7&date=2015-01-26&$marker=true'))!;
      expect(edit.date, '2015-01-26',
          reason: '$rule widgets.checkmark#8 — the value picker opens on the '
              "document's today, which is the app-wide today including the "
              'midnight delay; a widget must not compute that itself.');

      final WidgetLink show = WidgetLink.parse(Uri.parse(
          '${WidgetLink.scheme}://${WidgetLink.authority}/'
          '${WidgetLink.actionShow}?habit=7&$marker=true'))!;
      expect(show.action, WidgetLink.actionShow, reason: rule);
    });

    test('#1 the builder carries habit, day and marker into every URL', () {
      final String source = swift('WidgetData.swift');
      final String links = declaration(source, 'enum WidgetLink');

      expect(links, contains('URLQueryItem(name: "habit"'),
          reason: '$rule Every action names the habit it addresses.');
      expect(links, contains('URLQueryItem(name: "date"'),
          reason: '$rule …and the edit action names the day, which is the '
              "published today, not the widget's own idea of it.");
      expect(links, contains('pluginMarker'),
          reason: '$rule …and every one of them carries the marker the plugin '
              'filters on.');
    });

    test('#1 a boolean Checkmark toggles and a numerical one opens the picker',
        () {
      final String view = declaration(
          swift('CheckmarkWidget.swift'), 'struct CheckmarkWidgetView');

      expect(view, contains('.widgetURL('),
          reason: '$rule The Checkmark widget had no tap target at all: no '
              'widgetURL, no Link, no Button(intent:).');
      expect(view, contains('WidgetLink.toggle('),
          reason: '$rule widgets.checkmark#6 — a boolean Checkmark tap is the '
              "toggle of today's entry.");
      expect(view, contains('WidgetLink.edit('),
          reason: '$rule widgets.checkmark#7 — a numerical one opens the value '
              'picker instead.');
      expect(view, contains('habit.isNumerical'),
          reason: '$rule …and which of the two it is depends on the habit '
              'type, exactly as CheckmarkWidget.refreshData branches upstream.');
      expect(view, contains('entry.todayText'),
          reason: '$rule The picker opens on the published today.');
    });

    test('#1 each of the five graph widgets opens its habit', () {
      for (final String struct in graphWidgets) {
        final String view =
            declaration(swift('$struct.swift'), 'struct ${struct}View');
        expect(view, contains('WidgetLink.show('),
            reason: '$rule widgets.history#5, widgets.score#7, '
                'widgets.streak#6, widgets.frequency#6, widgets.target#9 — all '
                'five open ShowHabitActivity for the habit they draw. '
                '$struct does not.');
        expect(view, contains('.widgetURL('),
            reason: '$rule …and the whole card is the tap target, the way '
                'BaseWidget sets the click intent on the whole RemoteViews '
                'tree.');
      }
    });
  });
}
