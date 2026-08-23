/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/intro/IntroActivity.kt
///
/// `IntroActivity` extends `AppIntro2`, a third-party library that supplies the
/// pager, the dot indicator, the Skip/Next/Done chrome and the colour crossfade
/// behind them; only the three `addSlide(...)` calls and the two `finish()`
/// overrides are the app's own code. There is no AppIntro for Flutter, so all
/// of that chrome is reimplemented here:
///
///  * a horizontal [PageView] over [IntroScreen.slidesOf],
///  * a background whose colour is [introBackgroundColorAt] of the pager's
///    fractional page, i.e. a crossfade between the two slides being dragged
///    between,
///  * one [IntroPageDot] per slide,
///  * Skip on every slide but the last, Done on the last, and both call
///    [IntroScreen.onFinished] — `onSkipPressed` and `onDonePressed` are the
///    same `finish()` upstream, and neither writes a preference.
///
/// `showStatusBar(false)` becomes `SystemUiMode.immersive` while the screen is
/// mounted, restored to `edgeToEdge` on the way out.
///
/// The three drawables (`intro_icon_1`, `intro_icon_2`, `intro_icon_4` — there
/// is deliberately no `_3`) are PNG assets in the Android resources. The
/// Flutter app has no asset pipeline for them yet, so each is drawn here from
/// widgets and painters: [IntroIcon1] is the app logo, and the About screen
/// reuses it exactly as `about.xml` reuses `@drawable/intro_icon_1`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// One page of the intro: `AppIntroFragment.newInstance(title, description,
/// image, backgroundColor)`.
@immutable
class IntroSlide {
  const IntroSlide({
    required this.title,
    required this.description,
    required this.backgroundColor,
    required this.icon,
  });

  final String title;
  final String description;
  final Color backgroundColor;
  final Widget icon;
}

/// The colour behind the pager when it sits at [page], a fractional page
/// offset: `AppIntro2`'s `ColorTransitionListener` lerps between the two
/// slides being dragged between. Overscroll at either end clamps.
Color introBackgroundColorAt(List<Color> colors, double page) {
  assert(colors.isNotEmpty);
  final clamped = page.clamp(0.0, (colors.length - 1).toDouble()).toDouble();
  final lower = clamped.floor();
  final upper = clamped.ceil();
  if (lower == upper) return colors[lower];
  return Color.lerp(colors[lower], colors[upper], clamped - lower)!;
}

/// One dot of the page indicator.
class IntroPageDot extends StatelessWidget {
  const IntroPageDot({required this.isCurrent, super.key});

  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.4),
      ),
    );
  }
}

/// The first-run intro. Shown once, from the habit list's startup sequence.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, this.onFinished});

  /// `onDonePressed` / `onSkipPressed`, which both call `finish()`. Defaults to
  /// popping this route.
  final VoidCallback? onFinished;

  static const Key backgroundKey = Key('introBackground');
  static const Key skipButtonKey = Key('introSkipButton');
  static const Key nextButtonKey = Key('introNextButton');
  static const Key doneButtonKey = Key('introDoneButton');

  /// The three slides, in the order `IntroActivity.onCreate` adds them.
  ///
  /// Slide three reads the `_4` strings on purpose: there is no `intro_title_3`
  /// in the Android resources, and L10n has no `introTitle3` either.
  static List<IntroSlide> slidesOf(BuildContext context) {
    final l10n = L10n.of(context);
    return <IntroSlide>[
      IntroSlide(
        title: l10n.introTitle1,
        description: l10n.introDescription1,
        backgroundColor: const Color(0xFF194673),
        icon: const IntroIcon1(size: 160),
      ),
      IntroSlide(
        title: l10n.introTitle2,
        description: l10n.introDescription2,
        backgroundColor: const Color(0xFFFFA726),
        icon: const _IntroIcon2(),
      ),
      IntroSlide(
        title: l10n.introTitle4,
        description: l10n.introDescription4,
        backgroundColor: const Color(0xFF9575CD),
        icon: const _IntroIcon4(),
      ),
    ];
  }

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // `showStatusBar(false)`.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    super.dispose();
  }

  /// The pager's fractional position, valid before it has been laid out.
  double get _page {
    if (!_controller.hasClients) return _currentPage.toDouble();
    final position = _controller.position;
    if (!position.hasPixels || !position.hasContentDimensions) {
      return _currentPage.toDouble();
    }
    return _controller.page ?? _currentPage.toDouble();
  }

  void _finish() {
    final onFinished = widget.onFinished;
    if (onFinished != null) {
      onFinished();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = IntroScreen.slidesOf(context);
    final colors = <Color>[for (final slide in slides) slide.backgroundColor];
    final isLast = _currentPage == slides.length - 1;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ColoredBox(
        key: IntroScreen.backgroundKey,
        color: introBackgroundColorAt(colors, _page),
        child: child,
      ),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: <Widget>[
                    for (final slide in slides) _IntroSlideView(slide: slide),
                  ],
                ),
              ),
              _IntroBottomBar(
                slideCount: slides.length,
                currentPage: _currentPage,
                onSkip: isLast ? null : _finish,
                onNext: isLast ? null : _next,
                onDone: isLast ? _finish : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `AppIntroFragment`'s layout: the image, the title and the description,
/// centred and stacked.
class _IntroSlideView extends StatelessWidget {
  const _IntroSlideView({required this.slide});

  final IntroSlide slide;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          slide.icon,
          const SizedBox(height: 32),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

/// Skip on the left, the dots in the middle, Next — or Done on the last slide —
/// on the right.
class _IntroBottomBar extends StatelessWidget {
  const _IntroBottomBar({
    required this.slideCount,
    required this.currentPage,
    required this.onSkip,
    required this.onNext,
    required this.onDone,
  });

  final int slideCount;
  final int currentPage;
  final VoidCallback? onSkip;
  final VoidCallback? onNext;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return SizedBox(
      height: 64,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: onSkip == null
                  ? null
                  // No ARB key describes AppIntro's SKIP button; `skipDay`
                  // ("Skip") is the closest existing string.
                  : TextButton(
                      key: IntroScreen.skipButtonKey,
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: Text(l10n.skipDay),
                    ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (var i = 0; i < slideCount; i++)
                  IntroPageDot(isCurrent: i == currentPage),
              ],
            ),
          ),
          SizedBox(
            width: 96,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: onDone != null
                  ? TextButton(
                      key: IntroScreen.doneButtonKey,
                      onPressed: onDone,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: Text(l10n.doneLabel),
                    )
                  : IconButton(
                      key: IntroScreen.nextButtonKey,
                      onPressed: onNext,
                      color: Colors.white,
                      icon: const Icon(Icons.arrow_forward),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The drawables
// ---------------------------------------------------------------------------

/// `@drawable/intro_icon_1` — the app logo: a white loop arrow on a blue disc.
///
/// Also the About screen's icon, which is why it is public: `about.xml` points
/// at this very drawable.
class IntroIcon1 extends StatelessWidget {
  const IntroIcon1({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LoopLogoPainter()),
    );
  }
}

class _LoopLogoPainter extends CustomPainter {
  /// The blue of the launcher icon.
  static const Color discColor = Color(0xFF1E88E5);

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      side / 2,
      Paint()..color = discColor,
    );

    final radius = side * 0.27;
    final stroke = side * 0.115;
    final arc = Rect.fromCircle(center: center, radius: radius);
    // An almost-closed ring, open at the top left, where the arrow head goes.
    canvas.drawArc(
      arc,
      -math.pi / 2 + 0.55,
      math.pi * 2 - 1.1,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt,
    );

    // The arrow head: a right-angled flag pointing back into the ring.
    final head = Path()
      ..moveTo(center.dx - radius * 0.05, center.dy - radius * 1.55)
      ..lineTo(center.dx + radius * 0.22, center.dy - radius * 1.55)
      ..lineTo(center.dx + radius * 0.22, center.dy - radius * 0.4)
      ..lineTo(center.dx - radius * 0.85, center.dy - radius * 1.0)
      ..close();
    canvas.drawPath(
      head,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_LoopLogoPainter oldDelegate) => false;
}

/// `@drawable/intro_icon_2` — a habit card with a week of checkmarks.
class _IntroIcon2 extends StatelessWidget {
  const _IntroIcon2();

  @override
  Widget build(BuildContext context) {
    const List<bool> checked = <bool>[true, true, false, true, false, false, true];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const IntroIcon1(size: 22),
          const SizedBox(width: 8),
          const Text(
            'Meditate',
            style: TextStyle(color: Color(0xFF0277BD), fontSize: 18),
          ),
          const SizedBox(width: 12),
          for (final isChecked in checked)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Icon(
                isChecked ? Icons.check : Icons.close,
                size: 18,
                color: isChecked
                    ? const Color(0xFF0277BD)
                    : const Color(0xFFE0E0E0),
              ),
            ),
        ],
      ),
    );
  }
}

/// `@drawable/intro_icon_4` — a score chart on a white card.
class _IntroIcon4 extends StatelessWidget {
  const _IntroIcon4();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 160,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: CustomPaint(painter: _ScoreChartPainter()),
    );
  }
}

class _ScoreChartPainter extends CustomPainter {
  static const Color lineColor = Color(0xFFF9C300);
  static const List<double> points = <double>[
    0.05,
    0.55,
    0.35,
    0.70,
    0.90,
    0.70,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = size.height * (i + 0.5) / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    Offset at(int index) => Offset(
          size.width * (index + 0.5) / points.length,
          size.height * (1 - points[index]),
        );

    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.05
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(at(i), at(i + 1), line);
    }

    final radius = size.shortestSide * 0.07;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(at(i), radius, Paint()..color = Colors.white);
      canvas.drawCircle(
        at(i),
        radius,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.035,
      );
    }
  }

  @override
  bool shouldRepaint(_ScoreChartPainter oldDelegate) => false;
}
