/// `time.midnight-listeners#2` — the weekday header is redrawn for the new day
/// when the rollover fires.
///
/// Upstream this is `HeaderView.atMidnight() { post { invalidate() } }`: the
/// view is its own `MidnightListener` and marks itself dirty. The Flutter
/// header is a stateless child that is handed the day it must draw
/// (`ListHeader.today`), so what "invalidate" means here is a rebuild with the
/// day the timer has just stamped — and that is what is asserted below.
library;

// The core drawing vocabulary wins over Flutter's, as it does in
// test/ui/habits/list/list_header_test.dart.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart'
    hide Canvas, Color, DateUtils, Image, TextAlign;
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/habits/list/list_header.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/utils/midnight_timer.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// Records the schedule instead of running it.
class _RecordingExecutor implements ScheduledExecutorService {
  final List<void Function()> commands = <void Function()>[];

  @override
  void scheduleAtFixedRate(
    void Function() command,
    int initialDelay,
    int period,
  ) =>
      commands.add(command);

  @override
  List<void Function()> shutdownNow() {
    final pending = List<void Function()>.of(commands);
    commands.clear();
    return pending;
  }

  void tick() {
    for (final command in List<void Function()>.of(commands)) {
      command();
    }
  }
}

/// A [Canvas] that only remembers the text it was asked to draw.
class _TextCanvas implements Canvas {
  final List<String> texts = <String>[];

  @override
  void drawText(String text, double x, double y) => texts.add(text);

  @override
  double getHeight() => 48.0;

  @override
  double getWidth() => 600.0;

  @override
  void setColor(Color color) {}

  @override
  void drawLine(double x1, double y1, double x2, double y2) {}

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
  void drawRect(double x, double y, double width, double height) {}

  @override
  void setFont(Font font) {}

  @override
  void setFontSize(double size) {}

  @override
  void setStrokeWidth(double size) {}

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
  void setTextAlign(TextAlign align) {}

  @override
  Image toImage() => throw UnimplementedError();

  @override
  double measureText(String text) => text.length * 6.0;

  @override
  void fill() {}

  @override
  void drawTestImage() {}
}

void main() {
  // Sunday, 25 January 2015 — the day the Android header goldens were taken.
  final day1 = LocalDate.ymd(2015, 1, 25);
  final day2 = LocalDate.ymd(2015, 1, 26);

  setUp(() {
    setToday(day1);
    DateUtils.setFixedTimeZone(gmt);
    DateUtils.setFixedLocalTime(day1.unixTime + 20 * 3600000);
    systemCurrentTimeMillis = () => day1.unixTime + 20 * 3600000;
    getDefaultTimeZone = () => const FixedTimeZone(0);
  });

  tearDown(() {
    DateUtils.setFixedLocalTime(null);
    DateUtils.setFixedTimeZone(null);
    systemCurrentTimeMillis = defaultCurrentTimeMillis;
    getDefaultTimeZone = systemDefaultTimeZone;
    resetToday();
  });

  testWidgets('#2 the rollover repaints the weekday strip for the new day',
      (tester) async {
    final log = StringBuffer();
    final timer = MidnightTimer(
      StandardLogging(out: log, err: log),
      Preferences(MemoryStorage()),
    );
    final executor = _RecordingExecutor();
    timer.onResume(1000, executor);

    late StateSetter markDirty;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: StatefulBuilder(
              builder: (context, setState) {
                markDirty = setState;
                return ListHeader(
                  buttonCount: 5,
                  dataOffset: 0,
                  isCheckmarkSequenceReversed: false,
                  // The screen hands the header the current day; upstream the
                  // view reads it for itself inside onDraw.
                  today: getToday(),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // `HeaderView.atMidnight() { post { invalidate() } }`.
    timer.addListener(MidnightListener.of(() => markDirty(() {})));

    List<String> labels() {
      final canvas = _TextCanvas();
      tester.widget<CoreView>(find.byType(CoreView)).view.draw(canvas);
      return canvas.texts;
    }

    expect(
      labels(),
      <String>['WED', '21', 'THU', '22', 'FRI', '23', 'SAT', '24', 'SUN', '25'],
      reason: 'time.midnight-listeners#2 — before the rollover the strip ends '
          'on the day the header was given',
    );

    // The clock crosses midnight and the schedule fires.
    systemCurrentTimeMillis = () => day2.unixTime + 1000;
    executor.tick();
    await tester.pump();

    expect(getToday(), day2,
        reason: 'time.midnight-listeners#2 — the timer stamps the new day '
            'before it notifies');
    expect(
      labels(),
      <String>['THU', '22', 'FRI', '23', 'SAT', '24', 'SUN', '25', 'MON', '26'],
      reason: 'time.midnight-listeners#2 — atMidnight() invalidates the view, '
          'so the weekday header is redrawn for the new day',
    );
  });
}
