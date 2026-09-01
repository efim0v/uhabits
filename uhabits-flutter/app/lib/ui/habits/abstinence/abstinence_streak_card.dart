/// «Лучшие серии» воздержания: та же портированная карточка, но в полосе
/// вместо одного числа суток стоит точная длительность серии.
library;

// `date_utils.dart` не отдаёт свой крюк через барель ядра — тем же путём его
// читает `abstinence_overview.dart`.
// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/time/date_utils.dart'
    show systemCurrentTimeMillis;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../state/app_scope.dart';
import '../show/cards/streak_card_view.dart';
import 'abstinence_button_view.dart' show isAbstinenceLapseDay;
import 'abstinence_duration.dart';

/// Обёртка вокруг [StreakCardView], которая знает про журнал срывов и про
/// часы.
///
/// Портированная карточка о них не знает и знать не должна: она рисует то,
/// что ей дали. Длительность каждой серии считает ядро
/// (`abstinenceStreakMillis`), словами её называет `formatStreakDuration`, а
/// эта обёртка соединяет их и следит за временем.
class AbstinenceStreakCard extends StatefulWidget {
  const AbstinenceStreakCard({
    required this.habit,
    required this.definition,
    required this.scope,
    required this.state,
    super.key,
  });

  final core.Habit habit;

  /// Обещание, по которому судится день. Приезжает готовым, как и у
  /// `AbstinenceOverviewCard`: экран его уже прочитал, а два источника одного
  /// факта расходятся.
  final core.HabitDefinition definition;

  final AppScope scope;
  final StreakCardState state;

  @override
  State<AbstinenceStreakCard> createState() => _AbstinenceStreakCardState();
}

class _AbstinenceStreakCardState extends State<AbstinenceStreakCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  @override
  void dispose() {
    // Как у счётчика: не отменённый таймер пережил бы карточку и будил бы
    // дерево, которого больше нет.
    _tick?.cancel();
    super.dispose();
  }

  /// Планирует следующую перерисовку ровно на границу минуты.
  ///
  /// Идти надписи идущей серии разрешает `computed.since#8`; выравнивание —
  /// то же, каким идёт счётчик воздержания (`computed.since#5`).
  ///
  /// Планируется всегда, а не только когда серия идёт. Ответ на «идёт ли
  /// хоть одна» меняется в полночь, то есть ровно на одной из этих границ, и
  /// карточка, решившая молчать при открытии экрана, промолчала бы и тогда,
  /// когда молчать уже нельзя.
  void _scheduleTick() {
    final int msIntoMinute = systemCurrentTimeMillis() % 60000;
    _tick = Timer(Duration(milliseconds: 60000 - msIntoMinute), () {
      if (!mounted) return;
      setState(() {});
      _scheduleTick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    return StreakCardView(
      state: widget.state,
      durations: <String>[
        for (final core.Streak streak in widget.state.bestStreaks)
          formatStreakDuration(
            l10n,
            core.abstinenceStreakMillis(
              widget.habit,
              widget.scope.lapses,
              streak,
              // Судья один на все поверхности воздержания: тот же, что красит
              // ячейку списка, клетку календаря и подпись под счётчиком
              // (`computed.abstinence-cell#2`). Ядру он нужен, чтобы узнать,
              // оборвал ли серию срыв (`computed.since#10`), и второго такого
              // сравнения заводить негде.
              isLapseValue: (int value) =>
                  isAbstinenceLapseDay(widget.definition, value),
            ),
          ),
      ],
    );
  }
}
