/// Длительность воздержания словами: три старшие ненулевые единицы.
///
/// «14 дней 6 часов 12 минут» читается, «1 год 2 месяца 14 дней 6 часов
/// 12 минут» — уже нет (`computed.since#5`). Годы и месяцы считаются
/// календарно от начального мгновения, а не усреднением: месяцы разной
/// длины, и «тридцать дней в месяце» соврало бы на недели (`computed.since#6`).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_duration.dart';

void main() {
  final L10n ru = lookupL10n(const Locale('ru'));

  /// Начало отсчёта во всех тестах, кроме календарного.
  final DateTime start = DateTime(2026, 8, 1, 9, 0);

  /// [formatAbstinenceDuration] с русской локалью, от [start] на [held] вперёд.
  String after(Duration held) =>
      formatAbstinenceDuration(ru, start, start.add(held));

  test('three most significant units, and no more', () {
    expect(after(const Duration(days: 14, hours: 6, minutes: 12)),
        '14 дней 6 часов 12 минут',
        reason: 'computed.since#5 — три старшие единицы читаются, пять — нет');
  });

  test('a unit that is zero is skipped, not printed', () {
    expect(after(const Duration(hours: 6, minutes: 12)), '6 часов 12 минут',
        reason: 'computed.since#5 — «0 дней 6 часов» есть шум');
  });

  test('the first minutes are still an answer', () {
    expect(after(const Duration(minutes: 3)), '3 минуты',
        reason: 'computed.since#5 — счётчик отвечает с первой минуты, а не с '
            'первого дня');
    expect(after(Duration.zero), '0 минут',
        reason: 'computed.since#5 — и в самое первое мгновение тоже');
  });

  test('years and months come from the calendar, not from averages', () {
    // С 12 августа 2024 по 30 августа 2026: два года и восемнадцать дней.
    // Месяцев ровно ноль, и они обязаны пропасть, а не занять место в тройке.
    expect(
      formatAbstinenceDuration(
          ru, DateTime(2024, 8, 12), DateTime(2026, 8, 30)),
      '2 года 18 дней',
      reason: 'computed.since#6 — месяцы разной длины, и «тридцать дней в '
          'месяце» соврало бы на две недели за год',
    );
  });

  test('a month is a month even when it is twenty-eight days', () {
    // С 31 января по 1 марта невисокосного года: месяц и один день.
    expect(
      formatAbstinenceDuration(ru, DateTime(2026, 1, 31), DateTime(2026, 3, 1)),
      '1 месяц 1 день',
      reason: 'computed.since#6 — февраль короче тридцати дней, и календарный '
          'перенос это знает',
    );
  });

  test('a leap February is twenty-nine days long', () {
    // Зажим считает последний день месяца, а не берёт его константой.
    // С двадцатью восемью тот же отрезок дал бы «1 месяц 1 день».
    expect(
      formatAbstinenceDuration(
          ru, DateTime(2024, 1, 31), DateTime(2024, 2, 29)),
      '1 месяц',
      reason: 'computed.since#6 — тридцать первое января плюс месяц есть '
          'двадцать девятое февраля, когда февраль високосный',
    );
  });

  test('five units are offered and three are shown', () {
    // Год, два месяца, четырнадцать дней, шесть часов и двенадцать минут —
    // все пять ненулевые. Печатаются три старших.
    expect(
      formatAbstinenceDuration(ru, DateTime(2025, 1, 15, 10, 0),
          DateTime(2026, 3, 29, 16, 12)),
      '1 год 2 месяца 14 дней',
      reason: 'computed.since#5 — три старшие ненулевые единицы, и четвёртая '
          'не печатается, сколько бы их ни было',
    );
  });
}
