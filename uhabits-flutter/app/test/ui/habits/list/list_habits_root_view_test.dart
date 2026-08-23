/// Widget tests for the four decorations `ListHabitsRootView` stacks around
/// the habit list: the empty view, the startup hint, the task progress bar and
/// the confetti burst.
///
/// Each of the Kotlin views is imperative — `showEmpty()` / `showDone()` /
/// `hide()`, `showNext()` / `dismiss()`, `update()`, `konfettiView.start()` —
/// and each carries state the screen does not own, so they are exercised here
/// on their own rather than through the screen.
library;

// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/list/list_habits_root_view.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart' as core;
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/src/tasks/task_runner.dart' as core;
import 'package:uhabits_core/src/ui/screens/habits/list/hint_list.dart' as core;
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  late core.LocalDate today;
  late core.Preferences preferences;
  late core.Theme theme;

  setUp(() {
    today = core.LocalDate.ymd(2020, 1, 15);
    core.setToday(today);
    preferences = core.Preferences(core.MemoryStorage());
    theme = core.LightTheme();
  });

  tearDown(core.resetToday);

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topLeft, child: child))),
      );

  // -------------------------------------------------------------------------
  // EmptyListView
  // -------------------------------------------------------------------------
  group('list-habits.empty-state', () {
    testWidgets('#6 the view starts hidden', (tester) async {
      // `init { visibility = View.GONE }`: a freshly built EmptyListView draws
      // nothing at all until showEmpty() or showDone() runs.
      await pump(tester, EmptyListView(theme: theme));

      expect(EmptyListView(theme: theme).mode, EmptyListMode.hidden,
          reason: 'list-habits.empty-state#6');
      expect(tester.getSize(find.byType(EmptyListView)), Size.zero,
          reason: 'list-habits.empty-state#6');
      expect(find.byType(Text), findsNothing,
          reason: 'list-habits.empty-state#6 — GONE, so neither the glyph nor '
              'the message is in the tree');
    });

    testWidgets('#6 hide() puts it back into the state it started in',
        (tester) async {
      await pump(
        tester,
        EmptyListView(
          theme: theme,
          mode: EmptyListMode.empty,
          emptyText: 'You have no active habits',
        ),
      );
      expect(find.text('You have no active habits'), findsOneWidget,
          reason: 'list-habits.empty-state#2');

      await pump(tester, EmptyListView(theme: theme));
      expect(find.text('You have no active habits'), findsNothing,
          reason: 'list-habits.empty-state#6');
      expect(tester.getSize(find.byType(EmptyListView)), Size.zero,
          reason: 'list-habits.empty-state#6');
    });
  });

  // -------------------------------------------------------------------------
  // HintView
  // -------------------------------------------------------------------------
  group('list-habits.hints', () {
    core.HintList hintList([List<String>? hints]) =>
        core.HintList(preferences, hints ?? core.listHabitsHints);

    Future<void> pumpHint(WidgetTester tester, core.HintList list) => pump(
          tester,
          SizedBox(
            width: 400,
            child: HintView(hintList: list, title: 'Did you know?'),
          ),
        );

    HintViewState stateOf(WidgetTester tester) =>
        tester.state<HintViewState>(find.byType(HintView));

    /// The route transition also uses a FadeTransition, so the hint's own one
    /// has to be looked up inside it.
    double opacityOf(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find.descendant(
            of: find.byType(HintView),
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity
        .value;

    testWidgets('#6 nothing is shown when shouldShow() is false',
        (tester) async {
      // `lastHintDate` is null until the first run seeds it.
      expect(preferences.lastHintDate, isNull,
          reason: 'list-habits.hints#6');
      await pumpHint(tester, hintList());

      expect(stateOf(tester).isVisible, isFalse,
          reason: 'list-habits.hints#6 — showNext() returns before touching '
              'the list when shouldShow() is false');
      expect(find.text('Did you know?'), findsNothing,
          reason: 'list-habits.hints#6');
      // …and the hint list was not advanced.
      expect(preferences.lastHintNumber, -1, reason: 'list-habits.hints#6');
    });

    testWidgets('#6 nothing is shown when pop() returns null', (tester) async {
      preferences.updateLastHint(1, today.minus(1));
      // Two hints, both already shown: pop() runs off the end.
      await pumpHint(tester, hintList());

      expect(stateOf(tester).isVisible, isFalse,
          reason: 'list-habits.hints#6 — pop() returned null');
      expect(find.text('Did you know?'), findsNothing,
          reason: 'list-habits.hints#6');
    });

    testWidgets('#6 a due hint fades in over 500 ms', (tester) async {
      preferences.updateLastHint(-1, today.minus(1));
      await pumpHint(tester, hintList());

      expect(stateOf(tester).isVisible, isTrue,
          reason: 'list-habits.hints#6');
      expect(stateOf(tester).content, core.listHabitsHints[0],
          reason: 'list-habits.hints#6 — the content text is set from pop()');
      expect(find.text(core.listHabitsHints[0]), findsOneWidget,
          reason: 'list-habits.hints#6');

      // `alpha = 0f` before the animation starts…
      expect(opacityOf(tester), 0.0, reason: 'list-habits.hints#6');
      await tester.pump(const Duration(milliseconds: 250));
      final half = opacityOf(tester);
      expect(half, greaterThan(0.0), reason: 'list-habits.hints#6');
      expect(half, lessThan(1.0), reason: 'list-habits.hints#6');
      // …and fully opaque at 500 ms.
      await tester.pump(const Duration(milliseconds: 250));
      expect(opacityOf(tester), 1.0,
          reason: 'list-habits.hints#6 — animate().alpha(1f).duration = 500');
      expect(HintView.fadeDuration, const Duration(milliseconds: 500),
          reason: 'list-habits.hints#6');
    });

    testWidgets('#7 tapping fades it out and makes it GONE at the end',
        (tester) async {
      preferences.updateLastHint(-1, today.minus(1));
      await pumpHint(tester, hintList());
      await tester.pumpAndSettle();
      expect(stateOf(tester).isVisible, isTrue, reason: 'list-habits.hints#7');

      await tester.tap(find.text(core.listHabitsHints[0]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Still on screen while the fade runs…
      expect(stateOf(tester).isVisible, isTrue, reason: 'list-habits.hints#7');
      final half = opacityOf(tester);
      expect(half, lessThan(1.0), reason: 'list-habits.hints#7');
      expect(half, greaterThan(0.0), reason: 'list-habits.hints#7');

      await tester.pumpAndSettle();
      // …GONE once the animation ends.
      expect(stateOf(tester).isVisible, isFalse,
          reason: 'list-habits.hints#7 — DismissAnimator.onAnimationEnd sets '
              'visibility = GONE');
      expect(find.text(core.listHabitsHints[0]), findsNothing,
          reason: 'list-habits.hints#7');
      expect(tester.getSize(find.byType(HintView)).height, 0.0,
          reason: 'list-habits.hints#7');
    });

    testWidgets('#8 an indigo bottom box: bold white title over the white body',
        (tester) async {
      preferences.updateLastHint(-1, today.minus(1));
      await pumpHint(tester, hintList());
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(HintView),
          matching: find.byType(Container),
        ),
      );
      expect(container.color, indigo500, reason: 'list-habits.hints#8');
      expect(indigo500, const Color(0xFF3F51B5),
          reason: 'list-habits.hints#8 — R.color.indigo_500');
      // `setPadding(dp(16), dp(16), dp(4), dp(16))`.
      expect(container.padding,
          const EdgeInsets.only(left: 16, top: 16, right: 4, bottom: 16),
          reason: 'list-habits.hints#8');

      final title = tester.widget<Text>(find.text('Did you know?'));
      expect(title.style?.color, Colors.white, reason: 'list-habits.hints#8');
      expect(title.style?.fontWeight, FontWeight.bold,
          reason: 'list-habits.hints#8');

      final body = tester.widget<Text>(find.text(core.listHabitsHints[0]));
      expect(body.style?.color, Colors.white, reason: 'list-habits.hints#8');
      expect(body.style?.fontWeight, isNot(FontWeight.bold),
          reason: 'list-habits.hints#8');

      // 5dp between the title and the body.
      final titleRect = tester.getRect(find.text('Did you know?'));
      final bodyRect = tester.getRect(find.text(core.listHabitsHints[0]));
      expect(bodyRect.top - titleRect.bottom, HintView.contentTopPadding,
          reason: 'list-habits.hints#8');
      expect(HintView.contentTopPadding, 5.0, reason: 'list-habits.hints#8');
      // The box is a vertical stack, left-aligned.
      expect(titleRect.left, bodyRect.left, reason: 'list-habits.hints#8');
    });
  });

  // -------------------------------------------------------------------------
  // TaskProgressBar
  // -------------------------------------------------------------------------
  group('list-habits.screen-layout', () {
    testWidgets('#6 GONE while nothing is running, VISIBLE otherwise, always '
        'after 500 ms', (tester) async {
      final runner = core.CoroutineTaskRunner(
        mainDispatcher: const core.AsyncDispatcher(),
        ioDispatcher: const core.AsyncDispatcher(),
      );
      await pump(tester, SizedBox(width: 400, child: TaskProgressBar(runner: runner)));

      expect(tester.state<TaskProgressBarState>(find.byType(TaskProgressBar)).visible,
          isFalse,
          reason: 'list-habits.screen-layout#6 — init { visibility = GONE }');
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.state<TaskProgressBarState>(find.byType(TaskProgressBar)).visible,
          isFalse,
          reason: 'list-habits.screen-layout#6 — activeTaskCount == 0');
      expect(find.byType(LinearProgressIndicator), findsNothing,
          reason: 'list-habits.screen-layout#6');

      final task = _BlockingTask();
      runner.execute(task);
      await tester.pump();
      // The update is posted with a 500 ms delay, so nothing has changed yet.
      await tester.pump(const Duration(milliseconds: 499));
      expect(tester.state<TaskProgressBarState>(find.byType(TaskProgressBar)).visible,
          isFalse,
          reason: 'list-habits.screen-layout#6 — postDelayed(callback, 500)');

      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.state<TaskProgressBarState>(find.byType(TaskProgressBar)).visible,
          isTrue,
          reason: 'list-habits.screen-layout#6');
      expect(find.byType(LinearProgressIndicator), findsOneWidget,
          reason: 'list-habits.screen-layout#6 — an indeterminate horizontal '
              'progress bar');

      task.finish();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.state<TaskProgressBarState>(find.byType(TaskProgressBar)).visible,
          isFalse,
          reason: 'list-habits.screen-layout#6 — back to GONE once the task '
              'runner is idle again');
      expect(TaskProgressBar.updateDelay, const Duration(milliseconds: 500),
          reason: 'list-habits.screen-layout#6');
      await tester.pumpAndSettle();
    });
  });

  // -------------------------------------------------------------------------
  // showConfetti
  // -------------------------------------------------------------------------
  group('list-habits.confetti', () {
    ConfettiParty? build({
      Offset position = const Offset(120, 240),
      core.PaletteColor color = const core.PaletteColor(0),
      double animatorDurationScale = 1.0,
    }) =>
        buildConfettiParty(
          baseColor: core.LightTheme().colorOf(color),
          position: position,
          preferences: preferences,
          animatorDurationScale: animatorDurationScale,
        );

    test('#1 the (0, 0) origin fires nothing', () {
      expect(build(position: Offset.zero), isNull,
          reason: 'list-habits.confetti#1');
      // Only *both* coordinates being zero short-circuits.
      expect(build(position: const Offset(0, 5)), isNotNull,
          reason: 'list-habits.confetti#1');
      expect(build(position: const Offset(5, 0)), isNotNull,
          reason: 'list-habits.confetti#1');
    });

    test('#2 the disable-animations preference and a zero animator scale both '
        'suppress it', () {
      expect(preferences.isConfettiAnimationDisabled, isFalse,
          reason: 'list-habits.confetti#2 — pref_disable_animation defaults '
              'to false');
      expect(build(), isNotNull, reason: 'list-habits.confetti#2');

      preferences.isConfettiAnimationDisabled = true;
      expect(build(), isNull, reason: 'list-habits.confetti#2');

      preferences.isConfettiAnimationDisabled = false;
      expect(build(animatorDurationScale: 0.0), isNull,
          reason: 'list-habits.confetti#2 — ANIMATOR_DURATION_SCALE == 0');
      // Only exactly zero: a slowed-down animator still fires.
      expect(build(animatorDurationScale: 0.5), isNotNull,
          reason: 'list-habits.confetti#2');
    });

    test('#3 the burst parameters', () {
      final party = build()!;
      expect(party.speed, 0.0, reason: 'list-habits.confetti#3');
      expect(party.maxSpeed, 16.0, reason: 'list-habits.confetti#3');
      expect(party.damping, 0.9, reason: 'list-habits.confetti#3');
      expect(party.spread, 360, reason: 'list-habits.confetti#3');
      expect(party.angle, 0, reason: 'list-habits.confetti#3');
      expect(party.position, const Offset(120, 240),
          reason: 'list-habits.confetti#3 — Position.Absolute(x, y)');
      expect(party.emitterDuration, const Duration(milliseconds: 25),
          reason: 'list-habits.confetti#3');
      expect(party.maxParticles, 25, reason: 'list-habits.confetti#3');
      expect(party.timeToLive, 0, reason: 'list-habits.confetti#3');
    });

    test('#4 four colours derived from the habit theme colour', () {
      final base = core.LightTheme().colorOf(const core.PaletteColor(0)).toInt();
      final party = build()!;

      expect(party.colors, hasLength(4), reason: 'list-habits.confetti#4');
      expect(party.colors[0], core.ColorUtils.changeHue(base, 180.0),
          reason: 'list-habits.confetti#4');
      expect(party.colors[1], core.ColorUtils.changeHue(base, 20.0),
          reason: 'list-habits.confetti#4');
      expect(party.colors[2], core.ColorUtils.changeHue(base, -20.0),
          reason: 'list-habits.confetti#4');
      expect(party.colors[3], base,
          reason: 'list-habits.confetti#4 — the base colour itself is last');
      // A different habit colour gives a different palette.
      expect(build(color: const core.PaletteColor(11))!.colors,
          isNot(party.colors),
          reason: 'list-habits.confetti#4');
    });

    testWidgets('#3 the overlay fires exactly one burst per start() call',
        (tester) async {
      await pump(tester, const SizedBox(width: 400, height: 400, child: ConfettiOverlay()));
      final state =
          tester.state<ConfettiOverlayState>(find.byType(ConfettiOverlay));

      expect(state.parties, isEmpty, reason: 'list-habits.confetti#3');
      state.start(build()!);
      await tester.pump();
      expect(state.parties, hasLength(1), reason: 'list-habits.confetti#3');
      expect(state.parties.single.position, const Offset(120, 240),
          reason: 'list-habits.confetti#3');
      await tester.pumpAndSettle();
    });
  });
}

/// A task that never finishes on its own, so `activeTaskCount` stays at one.
class _BlockingTask implements core.Task {
  final Completer<void> _completer = Completer<void>();

  void finish() => _completer.complete();

  @override
  Future<void> doInBackground() => _completer.future;

  @override
  void cancel() {}

  @override
  bool isCanceled() => false;

  @override
  void onAttached(core.TaskRunner runner) {}

  @override
  void onPostExecute() {}

  @override
  void onPreExecute() {}

  @override
  void onProgressUpdate(int currentPosition) {}
}
