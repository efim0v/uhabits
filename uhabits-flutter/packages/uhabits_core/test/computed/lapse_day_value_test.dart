import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/lapse_day_value.dart';
import 'package:uhabits_core/src/models/entry.dart';

void main() {
  test('a lapse day is the amount times one thousand', () {
    expect(lapseDayValue(1), 1000, reason: 'computed.lapse-score#2');
    expect(lapseDayValue(45), 45000, reason: 'computed.lapse-score#2');
    expect(lapseDayValue(4500), 4500000, reason: 'computed.lapse-score#2');
  });

  test('the smallest lapse still clears the sentinels', () {
    // 1, 2 и 3 значат yesAuto, yesManual и skip. Минимальный срыв есть 1 и
    // даёт 1000 — попасть на сигнальное значение нечем.
    expect(lapseDayValue(1)!, greaterThan(Entry.skip),
        reason: 'computed.lapse-score#2');
  });

  test('a day without a lapse is nothing at all, not a zero', () {
    // Записанный ноль замораживает день навсегда; отсутствующий день даёт
    // max(0, -1) = 0 и потому полный успех.
    expect(lapseDayValue(0), isNull, reason: 'computed.lapse-score#2');
    expect(lapseDayValue(-3), isNull, reason: 'computed.lapse-score#2');
  });
}
