/// Ячейка списка привычки-воздержания.
///
/// Вид — чистая функция от состояния дня, поэтому проверяется через геттеры,
/// как `entry_button_views_test.dart` проверяет цвет глифа: холст ничего к
/// решению не добавляет.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_button_view.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  final core.Theme theme = core.LightTheme();
  final core.Color habitColor = theme.colorOf(const core.PaletteColor(7));

  /// Обязательство с допуском — то самое, по которому судит и оценка.
  core.HabitDefinition commitment({double allowance = 0.0, int from = 10}) =>
      core.HabitDefinition(
        kind: core.ComputedKind.abstinence,
        committedFrom: from,
        payload: core.abstinencePayload(
          allowance: allowance,
          unit: allowance == 0.0
              ? core.abstinenceUnitCount
              : core.abstinenceUnitMinutes,
        ),
      );

  AbstinenceButtonView view(AbstinenceCell cell) =>
      AbstinenceButtonView(cell: cell, color: habitColor, theme: theme);

  test('computed.abstinence-cell#1 день без записи выглядит удачным', () {
    // Сегодня, вчера, день за пределами прочитанного окна: везде тишина.
    for (final int stored in <int>[core.Entry.unknown, -1, 0]) {
      expect(
        abstinenceCellOf(
          definition: commitment(),
          storedValue: stored,
          day: 100,
        ),
        AbstinenceCell.clean,
        reason:
            'computed.abstinence-cell#1 — молчание есть успех, '
            'stored=$stored',
      );
    }
    expect(
      view(AbstinenceCell.clean).glyph,
      core.FontAwesome.check,
      reason: 'computed.abstinence-cell#1',
    );
    expect(
      view(AbstinenceCell.clean).glyphColor,
      habitColor,
      reason: 'computed.abstinence-cell#1',
    );
    expect(
      view(AbstinenceCell.clean).isHollow,
      isTrue,
      reason:
          'computed.abstinence-cell#1 — полая галочка: день зачло '
          'приложение, а не человек',
    );
  });

  test('computed.abstinence-cell#2 крестом рисуется превышение допуска', () {
    // Допуск ноль — умолчание: любая записанная величина есть срыв. Значение
    // дня несёт величину × 1000.
    for (final int stored in <int>[1000, 30000]) {
      expect(
        abstinenceCellOf(
          definition: commitment(),
          storedValue: stored,
          day: 100,
        ),
        AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#2 — stored=$stored при допуске 0',
      );
    }

    // Допуск 30: тридцать минут обещание держат, тридцать одна — нет. Ровно
    // та граница, по которой судит оценка (`computed.lapse-score#5`), и
    // прежний `stored > Entry.skip` назвал бы срывом все три.
    final core.HabitDefinition lenient = commitment(allowance: 30.0);
    expect(
      abstinenceCellOf(definition: lenient, storedValue: 29000, day: 100),
      AbstinenceCell.clean,
      reason: 'computed.abstinence-cell#2',
    );
    expect(
      abstinenceCellOf(definition: lenient, storedValue: 30000, day: 100),
      AbstinenceCell.clean,
      reason:
          'computed.abstinence-cell#2 — «не более допуска» обещание '
          'держит',
    );
    expect(
      abstinenceCellOf(definition: lenient, storedValue: 31000, day: 100),
      AbstinenceCell.lapse,
      reason: 'computed.abstinence-cell#2',
    );

    expect(
      view(AbstinenceCell.lapse).glyph,
      core.FontAwesome.times,
      reason: 'computed.abstinence-cell#2',
    );
    expect(
      view(AbstinenceCell.lapse).isHollow,
      isFalse,
      reason: 'computed.abstinence-cell#2',
    );
  });

  test('computed.abstinence-cell#2 судья тот же, что у оценки', () {
    // `isAbstinenceLapseDay` не второй предикат, а первый, переведённый со
    // шкалы дня: значение дня есть величина × 1000, а `isAbstinenceLapse`
    // берёт величину. Расхождение здесь означало бы, что ячейка и балл
    // считают срывы по-разному.
    final core.HabitDefinition lenient = commitment(allowance: 30.0);
    for (final int amount in <int>[1, 20, 29, 30, 31, 45]) {
      expect(
        isAbstinenceLapseDay(lenient, amount * 1000),
        core.isAbstinenceLapse(lenient, amount),
        reason:
            'computed.abstinence-cell#2 — интерфейс и оценка судят одним '
            'сравнением (`computed.lapse-score#5`), amount=$amount',
      );
    }
  });

  test('computed.abstinence-cell#3 до дня обязательства ячейка пуста', () {
    expect(
      abstinenceCellOf(
        definition: commitment(),
        storedValue: core.Entry.unknown,
        day: 9,
      ),
      AbstinenceCell.beforeCommitment,
      reason: 'computed.abstinence-cell#3',
    );
    expect(
      abstinenceCellOf(
        definition: commitment(),
        storedValue: core.Entry.unknown,
        day: 10,
      ),
      AbstinenceCell.clean,
      reason: 'computed.abstinence-cell#3 — сам день обещания уже считается',
    );
    expect(
      view(AbstinenceCell.beforeCommitment).glyph,
      isNull,
      reason: 'computed.abstinence-cell#3 — рисовать нечего',
    );
  });

  test('computed.abstinence-cell#4 пропуск остаётся пропуском', () {
    expect(
      abstinenceCellOf(
        definition: commitment(),
        storedValue: core.Entry.skip,
        day: 100,
      ),
      AbstinenceCell.skipped,
      reason: 'computed.abstinence-cell#4',
    );
    expect(
      view(AbstinenceCell.skipped).glyph,
      core.FontAwesome.skipped,
      reason: 'computed.abstinence-cell#4',
    );
    // Ступеньки 1, 2 и 3 занял бы человек; вычисленному значению туда нельзя,
    // и сюда они попасть не могут — но если попадут, это не срыв. Делить их на
    // тысячу нельзя: при допуске ноль `yesAuto` дал бы 0.001 и стал бы
    // «срывом» — отметка человека, прочитанная как замер.
    //
    // `skip` в этом ряду не для симметрии. Выше он отсеян ветвью
    // `abstinenceCellOf`, и та ветвь закрывает его собой: убери охрану пропуска
    // из `isAbstinenceLapseDay`, и ячейка списка не заметит. Заметят зовущие
    // предикат напрямую — Overview берёт `lapsedToday` именно им
    // (`abstinence_overview.dart`), и без этой охраны пропуск при допуске ноль
    // дал бы 0.003 > 0, кнопка предложила бы «Отменить срыв» там, где срыва не
    // было, а тап по ней снимал бы отметку человека.
    for (final int stored in <int>[
      core.Entry.yesAuto,
      core.Entry.yesManual,
      core.Entry.skip,
    ]) {
      expect(
        isAbstinenceLapseDay(commitment(), stored),
        isFalse,
        reason: 'computed.abstinence-cell#4 — stored=$stored',
      );
    }
  });
}
