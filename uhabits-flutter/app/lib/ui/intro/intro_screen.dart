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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import 'intro_artwork.dart';

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

/// `@drawable/intro_icon_1` — the Loop artwork, shipped verbatim
/// (`audit3.the-loop-logo-and-the-two#1`).
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
      child: Image.memory(
        introIcon1Png,
        width: size,
        height: size,
        fit: BoxFit.contain,
        // The drawable is a 484x484 bitmap; Android's ImageView filters it
        // down to 100dp on the About screen and up on the intro slide.
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

/// `@drawable/intro_icon_2` — the shipped illustration of a habit card, a
/// 967x224 bitmap (`audit3.the-loop-logo-and-the-two#1`).
class _IntroIcon2 extends StatelessWidget {
  const _IntroIcon2();

  /// The bitmap is 967x224. Android's ImageView takes its size from the
  /// bitmap; here both sides are stated so that the slide does not reflow
  /// while the image decodes.
  static const double width = 280.0;
  static const double height = width * 224 / 967;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      introIcon2Png,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// `@drawable/intro_icon_4` — the shipped illustration of a score graph, a
/// 695x585 bitmap (`audit3.the-loop-logo-and-the-two#1`).
class _IntroIcon4 extends StatelessWidget {
  const _IntroIcon4();

  /// The bitmap is 695x585.
  static const double width = 200.0;
  static const double height = width * 585 / 695;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      introIcon4Png,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
