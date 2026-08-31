import '../../../l10n/app_localizations.dart';

/// Сколько единиц времени показывает счётчик.
///
/// Три: «14 дней 6 часов 12 минут» читается, «1 год 2 месяца 14 дней 6 часов
/// 12 минут» — уже нет (`computed.since#5`).
const int _unitsShown = 3;

/// Длительность воздержания словами, тремя старшими ненулевыми единицами.
///
/// Берёт два мгновения, а не длительность: годы и месяцы считаются
/// календарно, и без даты начала их не посчитать. Месяцы разной длины, и
/// усреднение соврало бы на две недели за год (`computed.since#6`).
///
/// Оба мгновения обязаны быть в одной зоне: вызывающий строит их из
/// `abstinenceSinceMillis` и текущего времени, оба местные.
///
/// Нулевые единицы пропускаются целиком, а не занимают место: «2 года
/// 18 дней», а не «2 года 0 месяцев 18 дней». Ноль ничего не сообщает, но
/// вытесняет из тройки то, что сообщает.
/// [from], сдвинутое на [totalMonths] месяцев вперёд, с зажимом дня.
///
/// Зажим обязателен. `DateTime(2026, 2, 31)` Dart нормализует в третье марта,
/// и без зажима у всякого, кто сорвался тридцать первого числа, счётчик
/// уезжал бы на несколько дней в короткие месяцы. Тридцать первое января плюс
/// месяц — это двадцать восьмое февраля, а не третье марта.
DateTime _shiftMonths(DateTime from, int totalMonths) {
  final int raw = from.month - 1 + totalMonths;
  final int year = from.year + (raw ~/ 12);
  final int month = raw % 12 + 1;
  // Нулевой день следующего месяца есть последний день этого.
  final int lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(
    year,
    month,
    from.day < lastDay ? from.day : lastDay,
    from.hour,
    from.minute,
    from.second,
  );
}

String formatAbstinenceDuration(L10n l10n, DateTime from, DateTime to) {
  if (!to.isAfter(from)) return l10n.abstinenceDurationMinutes(0);

  // Сколько целых месяцев уместилось: берём оценку сверху и убавляем, пока
  // перенос обгоняет настоящее. Цикл делает один-два шага.
  int totalMonths = (to.year - from.year) * 12 + (to.month - from.month) + 1;
  while (totalMonths > 0 && _shiftMonths(from, totalMonths).isAfter(to)) {
    totalMonths -= 1;
  }

  final int years = totalMonths ~/ 12;
  final int months = totalMonths % 12;
  final Duration rest = to.difference(_shiftMonths(from, totalMonths));

  final List<String> parts = <String>[];
  void add(int value, String Function(int) word) {
    if (value > 0 && parts.length < _unitsShown) parts.add(word(value));
  }

  add(years, l10n.abstinenceDurationYears);
  add(months, l10n.abstinenceDurationMonths);
  add(rest.inDays, l10n.abstinenceDurationDays);
  add(rest.inHours.remainder(24), l10n.abstinenceDurationHours);
  add(rest.inMinutes.remainder(60), l10n.abstinenceDurationMinutes);

  // Первая минута воздержания — тоже ответ, и он не должен быть пустым.
  if (parts.isEmpty) return l10n.abstinenceDurationMinutes(0);
  return parts.join(' ');
}
