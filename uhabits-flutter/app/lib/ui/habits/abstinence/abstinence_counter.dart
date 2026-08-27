/// «Дней без срыва» — число и карточка, которая его показывает.
library;

import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../computed/computed_card.dart';

// Своей `daysWithoutLapse` здесь нет и быть не должно. Она есть в ядре
// (`computed/days_without_lapse.dart`, Задача 16), считает по текущей серии, а
// не по последнему срыву, и потому переживает «срыв в будущем» и не требует
// второго запроса к журналу. Две функции с одним именем — в ядре и здесь —
// давали на одних данных разные числа, а этот файл и бочка ядра импортируются
// в один и тот же тест: `Error: 'daysWithoutLapse' is imported from both`.
// Отсюда наружу идёт только карточка.

class AbstinenceCounterCard extends StatelessWidget {
  const AbstinenceCounterCard({
    required this.theme,
    required this.days,
    required this.subtitle,
    required this.lapsedToday,
    required this.onToggleToday,
    super.key = cardKey,
  });

  final core.Theme theme;
  final int days;

  /// Строка под числом: «С 3 марта 2026» или «Последний срыв: 12 августа».
  final String subtitle;

  /// Сегодняшний день уже отмечен срывом.
  final bool lapsedToday;

  final VoidCallback onToggleToday;

  static const Key cardKey = Key('abstinence.counter');
  static const Key todayButtonKey = Key('abstinence.today');

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    return ComputedCard(
      theme: theme,
      title: l10n.abstinenceTitle,
      trailing: TextButton(
        key: todayButtonKey,
        onPressed: onToggleToday,
        child: Text(
          lapsedToday ? l10n.abstinenceUndoToday : l10n.abstinenceLapseToday,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '$days',
                style: TextStyle(
                  fontSize: 42,
                  height: 1,
                  fontWeight: FontWeight.w300,
                  color: toFlutterColor(theme.highContrastTextColor),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.abstinenceCleanDaysLabel(days),
                style: TextStyle(
                  fontSize: 15,
                  color: toFlutterColor(theme.mediumContrastTextColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: toFlutterColor(theme.mediumContrastTextColor),
            ),
          ),
        ],
      ),
    );
  }
}
