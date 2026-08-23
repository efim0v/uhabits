/// The four decorations `ListHabitsRootView` stacks around the habit list.
///
/// Port of
/// uhabits-android/.../habits/list/ListHabitsRootView.kt and of the three
/// views it owns that are not the list itself:
///
///  * uhabits-android/.../habits/list/views/EmptyListView.kt
///  * uhabits-android/.../habits/list/views/HintView.kt
///  * uhabits-android/.../common/views/TaskProgressBar.kt
///
/// plus the KonfettiView burst that `ListHabitsScreen.showConfetti` fires
/// ([ConfettiOverlay]).
///
/// Each one is a widget of its own because each one has its own lifecycle:
/// the progress bar subscribes to the task runner, the hint pops itself off
/// the [core.HintList] when it is attached, and the confetti overlay is driven
/// imperatively by the presenter.
library;

// The core package does not re-export lib/src/preferences or lib/src/tasks.
// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/src/tasks/task_runner.dart' as core;
import 'package:uhabits_core/src/ui/screens/habits/list/hint_list.dart' as core;
import 'package:uhabits_core/uhabits_core.dart' as core;

/// `res/color/material_colors.xml`, `indigo_500`.
const Color indigo500 = Color(0xFF3F51B5);

// ---------------------------------------------------------------------------
// EmptyListView
// ---------------------------------------------------------------------------

/// Which of `EmptyListView`'s three states the view is in.
///
/// The Kotlin view is one `LinearLayout` whose two `TextView`s are rewritten by
/// `showEmpty()` / `showDone()` and whose visibility is flipped by those two
/// and by `hide()`. `visibility = GONE` runs in the constructor, so [hidden] is
/// the state the view starts in (`list-habits.empty-state#6`).
enum EmptyListMode { hidden, empty, done }

/// Port of uhabits-android/.../habits/list/views/EmptyListView.kt.
///
/// A vertically centred column: the FontAwesome glyph over the message, both in
/// `?attr/contrast60`, separated by 20dp of padding
/// (`list-habits.empty-state#5`).
class EmptyListView extends StatelessWidget {
  const EmptyListView({
    required this.theme,
    this.mode = EmptyListMode.hidden,
    this.emptyText = '',
    this.doneText = '',
    super.key,
  });

  final core.Theme theme;

  /// `iconTextView.textSize = sp(40.0f)` — 80, not 40
  /// (`audit4.empty-list-star-beach-icon-is#1`).
  ///
  /// `sp()` is `InterfaceUtils.spToPixels`, which already returns *pixels*
  /// (`40 * scaledDensity`); the result is then handed to the one-argument
  /// `TextView.textSize` setter, which is `setTextSize(COMPLEX_UNIT_SP, …)` and
  /// scales it a second time. The glyph the Android user sees is therefore
  /// `40 * density * fontScale²` dp — 80dp on the density-2 device the checked
  /// in baseline was captured on (androidTest/assets/views/habits/list/
  /// EmptyListView/empty.png, where the half-star spans ~85dp of a 200dp view),
  /// twice the 40 this port used to draw.
  ///
  /// 80 is the density-2 rendering, which is the one the baseline pins. The
  /// remaining `fontScale` factor arrives on its own: a Flutter [Text] applies
  /// the ambient `textScaler`, exactly as the SP setter does.
  static const double iconTextSize = 80.0;

  /// Defaults to [EmptyListMode.hidden]: `visibility = GONE` in the `init`
  /// block, before any of `showEmpty` / `showDone` / `hide` has run.
  final EmptyListMode mode;

  /// `R.string.no_habits_found`.
  final String emptyText;

  /// `R.string.no_habits_left_to_do`.
  final String doneText;

  /// `R.string.fa_star_half_o` / `R.string.fa_umbrella_beach`.
  String get icon => mode == EmptyListMode.done
      ? core.FontAwesome.umbrellaBeach
      : core.FontAwesome.starHalfO;

  String get text => mode == EmptyListMode.done ? doneText : emptyText;

  @override
  Widget build(BuildContext context) {
    // GONE, not INVISIBLE: the view takes no space and draws nothing.
    if (mode == EmptyListMode.hidden) return const SizedBox.shrink();
    final color = _toFlutterColor(theme.mediumContrastTextColor);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            icon,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: iconTextSize,
              fontFamily: core.FontAssets.fontAwesomeFamily,
            ),
          ),
          // `setPadding(0, dp(20f), 0, 0)`
          const SizedBox(height: 20),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HintView
// ---------------------------------------------------------------------------

/// Port of uhabits-android/.../habits/list/views/HintView.kt.
///
/// The indigo box that pops one startup hint off [core.HintList] when it is
/// attached, fades in over 500 ms, and fades itself back out when tapped.
class HintView extends StatefulWidget {
  const HintView({
    required this.hintList,
    required this.title,
    super.key,
  });

  /// `HintListFactory.create(resources.getStringArray(R.array.hints))`.
  final core.HintList hintList;

  /// `R.string.hint_title` — "Did you know?".
  final String title;

  /// `animate().alpha(...).duration = 500`, both ways.
  static const Duration fadeDuration = Duration(milliseconds: 500);

  /// `setPadding(dp(16), dp(16), dp(4), dp(16))`.
  static const EdgeInsets boxPadding =
      EdgeInsets.only(left: 16, top: 16, right: 4, bottom: 16);

  /// `hintContent.setPadding(0, dp(5f), 0, 0)`.
  static const double contentTopPadding = 5;

  @override
  HintViewState createState() => HintViewState();
}

class HintViewState extends State<HintView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// `hintContent.text`, or null while the view is GONE.
  String? content;

  /// `visibility == VISIBLE`.
  bool get isVisible => content != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: HintView.fadeDuration,
    );
    // `onAttachedToWindow { showNext() }`.
    showNext();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// `HintView.showNext()`.
  void showNext() {
    if (!widget.hintList.shouldShow()) return;
    final hint = widget.hintList.pop();
    if (hint == null) return;
    setState(() => content = hint);
    // `alpha = 0f; visibility = VISIBLE; animate().alpha(1f).duration = 500`.
    _controller.forward(from: 0.0);
  }

  /// `HintView.dismiss()`: fade to zero and become GONE at the end of the
  /// animation (`list-habits.hints#7`).
  void dismiss() {
    if (!isVisible) return;
    _controller.reverse(from: _controller.value).whenComplete(() {
      if (mounted) setState(() => content = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hint = content;
    if (hint == null) return const SizedBox.shrink();
    return FadeTransition(
      opacity: _controller,
      child: GestureDetector(
        // `isClickable = true` plus `setOnClickListener { dismiss() }`.
        behavior: HitTestBehavior.opaque,
        onTap: dismiss,
        child: Container(
          width: double.infinity,
          color: indigo500,
          padding: HintView.boxPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.only(top: HintView.contentTopPadding),
                child: Text(
                  hint,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TaskProgressBar
// ---------------------------------------------------------------------------

/// Port of uhabits-android/.../common/views/TaskProgressBar.kt.
///
/// An indeterminate horizontal bar that is GONE while nothing is running.
/// Every visibility update is deferred by 500 ms — including the one
/// `onAttachedToWindow` triggers (`list-habits.screen-layout#6`).
class TaskProgressBar extends StatefulWidget {
  const TaskProgressBar({required this.runner, this.color, super.key});

  final core.TaskRunner runner;

  final Color? color;

  /// `postDelayed(callback, 500)`.
  static const Duration updateDelay = Duration(milliseconds: 500);

  @override
  TaskProgressBarState createState() => TaskProgressBarState();
}

class TaskProgressBarState extends State<TaskProgressBar>
    implements core.TaskRunnerListener {
  /// `visibility`, starting at GONE.
  bool visible = false;

  /// Every `postDelayed` callback still in flight. Android leaves them on the
  /// view's handler; a disposed widget has to drop them itself.
  final List<Timer> _pending = <Timer>[];

  @override
  void initState() {
    super.initState();
    // `onAttachedToWindow`: subscribe, then run one deferred update.
    widget.runner.addListener(this);
    update();
  }

  @override
  void dispose() {
    // `onDetachedFromWindow`.
    widget.runner.removeListener(this);
    for (final timer in _pending) {
      timer.cancel();
    }
    _pending.clear();
    super.dispose();
  }

  @override
  void onTaskStarted(core.Task task) => update();

  @override
  void onTaskFinished(core.Task task) => update();

  void update() {
    late final Timer timer;
    timer = Timer(TaskProgressBar.updateDelay, () {
      _pending.remove(timer);
      if (!mounted) return;
      final newVisibility = widget.runner.activeTaskCount != 0;
      if (visible != newVisibility) setState(() => visible = newVisibility);
    });
    _pending.add(timer);
  }

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return LinearProgressIndicator(color: widget.color);
  }
}

// ---------------------------------------------------------------------------
// Confetti
// ---------------------------------------------------------------------------

/// Port of `nl.dionsegijn.konfetti.core.Party`, narrowed to the fields
/// `ListHabitsScreen.showConfetti` actually sets
/// (`list-habits.confetti#3`, `#4`).
@immutable
class ConfettiParty {
  const ConfettiParty({
    required this.colors,
    required this.position,
    this.speed = 0.0,
    this.maxSpeed = 16.0,
    this.damping = 0.9,
    this.spread = 360,
    this.angle = 0,
    this.emitterDuration = const Duration(milliseconds: 25),
    this.maxParticles = 25,
    this.timeToLive = 0,
  });

  /// `Party.colors`, as packed ARGB ints — the same representation
  /// [core.ColorUtils] works in.
  final List<int> colors;

  /// `Position.Absolute(x, y)`.
  final Offset position;

  final double speed;
  final double maxSpeed;
  final double damping;
  final int spread;
  final int angle;

  /// `Emitter(duration = 25, MILLISECONDS)`.
  final Duration emitterDuration;

  /// `.max(25)`.
  final int maxParticles;

  final int timeToLive;
}

/// `ListHabitsScreen.showConfetti(color, x, y)`, minus the KonfettiView call.
///
/// Returns the party to fire, or null when one of the two early returns takes
/// over: the (0, 0) origin an ACTION_EDIT intent produces
/// (`list-habits.confetti#1`), the disable-animations preference, and a system
/// animator duration scale of exactly zero (`#2`).
ConfettiParty? buildConfettiParty({
  required core.Color baseColor,
  required Offset position,
  required core.Preferences preferences,
  required double animatorDurationScale,
}) {
  if (position.dx == 0.0 && position.dy == 0.0) return null;
  if (preferences.isConfettiAnimationDisabled) return null;
  if (animatorDurationScale == 0.0) return null;
  final base = baseColor.toInt();
  return ConfettiParty(
    colors: <int>[
      core.ColorUtils.changeHue(base, 180.0),
      core.ColorUtils.changeHue(base, 20.0),
      core.ColorUtils.changeHue(base, -20.0),
      base,
    ],
    position: position,
  );
}

/// The `KonfettiView` that sits at `translationZ = 10` on top of everything
/// else (`list-habits.screen-layout#1`).
///
/// Drives one burst per [start] call: [ConfettiParty.maxParticles] particles
/// leave [ConfettiParty.position] at a random speed in
/// `[speed, maxSpeed]`, spread over [ConfettiParty.spread] degrees around
/// [ConfettiParty.angle], and lose [ConfettiParty.damping] of their velocity
/// every frame.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  @override
  ConfettiOverlayState createState() => ConfettiOverlayState();
}

class ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final math.Random _random = math.Random(0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  /// Every burst this overlay has been asked to fire, newest last. Cleared
  /// when the animation finishes.
  final List<ConfettiParty> parties = <ConfettiParty>[];

  List<_Particle> _particles = <_Particle>[];

  /// `konfettiView.start(party)`.
  void start(ConfettiParty party) {
    parties.add(party);
    _particles = <_Particle>[
      for (var i = 0; i < party.maxParticles; i++) _spawn(party),
    ];
    _controller.forward(from: 0.0);
  }

  _Particle _spawn(ConfettiParty party) {
    final speed =
        party.speed + _random.nextDouble() * (party.maxSpeed - party.speed);
    final degrees =
        party.angle + (_random.nextDouble() - 0.5) * party.spread;
    final radians = degrees * math.pi / 180.0;
    return _Particle(
      origin: party.position,
      velocity: Offset(math.cos(radians), math.sin(radians)) * speed,
      damping: party.damping,
      color: Color(party.colors[_random.nextInt(party.colors.length)]),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(_particles, _controller),
        size: Size.infinite,
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.origin,
    required this.velocity,
    required this.damping,
    required this.color,
  });

  final Offset origin;
  final Offset velocity;
  final double damping;
  final Color color;

  /// The sum of a geometric series: after `n` frames of `v *= damping` the
  /// particle has travelled `v * (1 - damping^n) / (1 - damping)`.
  Offset positionAt(double frames) {
    final travelled = (1 - math.pow(damping, frames)) / (1 - damping);
    return origin + velocity * travelled.toDouble();
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.progress) : super(repaint: progress);

  final List<_Particle> particles;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress.value <= 0.0 || progress.value >= 1.0) return;
    final frames = progress.value * 90;
    for (final particle in particles) {
      canvas.drawCircle(
        particle.positionAt(frames),
        3.0,
        Paint()
          ..color = particle.color.withValues(alpha: 1.0 - progress.value),
      );
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.particles != particles;
}

/// The core [core.Color] carries normalised channels; `dart:ui` wants bytes.
Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
