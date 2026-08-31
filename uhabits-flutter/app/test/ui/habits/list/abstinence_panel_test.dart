/// Панель дней привычки-воздержания: что рисуется, и что список — только для
/// просмотра этого вида.
///
/// Здесь только панель — без базы и без экрана. Что тап по-прежнему пишет
/// срыв с кнопки карточки и с клетки календаря, проверяют
/// `abstinence_allowance_test.dart` и `abstinence_overview_test.dart`.
library;

// ignore_for_file: implementation_imports

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_button_view.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart' as core;
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  final core.Theme theme = core.LightTheme();

  late core.Preferences preferences;
  final List<core.LocalDate> edits = <core.LocalDate>[];
  final List<core.LocalDate> presses = <core.LocalDate>[];

  setUp(() {
    core.setToday(core.LocalDate.ymd(2020, 1, 15));
    preferences = core.Preferences(core.MemoryStorage());
    edits.clear();
    presses.clear();
  });

  tearDown(core.resetToday);

  /// Обязательство с допуском — то же, чем кормит панель список.
  ///
  /// Панели едет определение целиком, а не один день обещания: срывом день
  /// называет `isAbstinenceLapse(definition, величина)`, и допуск он берёт
  /// отсюда.
  core.HabitDefinition commitment({
    required int from,
    double allowance = 0.0,
  }) =>
      core.HabitDefinition(
        kind: core.ComputedKind.abstinence,
        committedFrom: from,
        payload: core.abstinencePayload(allowance: allowance),
      );

  Widget panel({
    required List<int> values,
    required core.HabitDefinition definition,
  }) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: EntryPanel(
            values: values,
            color: theme.colorOf(const core.PaletteColor(7)),
            theme: theme,
            preferences: preferences,
            isNumerical: true,
            abstinenceDefinition: definition,
            onEdit: edits.add,
            onPressed: (core.LocalDate date, Offset _) => presses.add(date),
          ),
        ),
      );

  AbstinenceButtonView viewAt(WidgetTester tester, core.LocalDate date) =>
      tester.widget<EntryButton>(find.byKey(EntryPanel.buttonKey(date))).view
          as AbstinenceButtonView;

  /// `EntryButton.onTap`/`onLongPress` напрямую: `#9` закрывает жест на
  /// уровне самого виджета, а не на уровне того, что он делает с ним дальше.
  EntryButton buttonAt(WidgetTester tester, core.LocalDate date) =>
      tester.widget<EntryButton>(find.byKey(EntryPanel.buttonKey(date)));

  testWidgets('computed.abstinence-cell#1 воздержание не рисует числовую '
      'панель', (tester) async {
    final core.LocalDate today = core.getToday();
    await tester.pumpWidget(panel(
      values: <int>[core.Entry.unknown],
      definition: commitment(from: today.daysSince2000 - 30),
    ));

    expect(viewAt(tester, today).cell, AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#1 — числовая ячейка написала бы «0»');
  });

  testWidgets(
      'computed.abstinence-cell#9 список — только для просмотра: тап не '
      'заведён вовсе', (tester) async {
    final core.LocalDate today = core.getToday();
    await tester.pumpWidget(panel(
      values: <int>[31000],
      definition: commitment(
        from: today.daysSince2000 - 30,
        allowance: 30.0,
      ),
    ));

    // Ячейка рисует срыв, как и раньше (`computed.abstinence-cell#2`) — но
    // виджет-кнопка ниже её вообще не берёт колбэков жеста: закрыт не тап, а
    // сам вход в него.
    expect(viewAt(tester, today).cell, AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#2 — рисунок не меняется');
    expect(buttonAt(tester, today).onTap, isNull,
        reason: 'computed.abstinence-cell#9');

    // Тап бьёт мимо: `Actions`/`Focus` не заведены на отсутствующий `onTap`,
    // но `tester.tap` находит сам `CoreView`, и синтетическому событию всё
    // равно не на чем сработать.
    await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
    await tester.pump();

    expect(viewAt(tester, today).cell, AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#9 — тап ничего не изменил');
    expect(edits, isEmpty, reason: 'computed.abstinence-cell#9');
    expect(presses, isEmpty,
        reason: 'computed.abstinence-cell#9 — даже отметка нажатой точки не '
            'сообщается: жеста нет, а не «есть, но без последствий»');
  });

  testWidgets(
      'computed.abstinence-cell#9 долгое нажатие тоже не заведено',
      (tester) async {
    final core.LocalDate today = core.getToday();
    await tester.pumpWidget(panel(
      values: <int>[31000],
      definition: commitment(
        from: today.daysSince2000 - 30,
        allowance: 30.0,
      ),
    ));

    expect(buttonAt(tester, today).onLongPress, isNull,
        reason: 'computed.abstinence-cell#9');

    // Долгое нажатие у числовой ячейки открывает окно ввода — здесь та же
    // дверь заперта и на этом жесте, не только на тапе
    // (`computed.abstinence-cell#6`).
    await tester.longPress(find.byKey(EntryPanel.buttonKey(today)));
    await tester.pump();

    expect(viewAt(tester, today).cell, AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#9 — долгое нажатие ничего не '
            'изменило');
    expect(edits, isEmpty, reason: 'computed.abstinence-cell#9');
    expect(presses, isEmpty, reason: 'computed.abstinence-cell#9');
  });

  testWidgets(
      'computed.abstinence-cell#3 день до обязательства пуст и, как и весь '
      'список, не нажимается', (tester) async {
    final core.LocalDate today = core.getToday();
    // Обещание дано вчера: позавчерашняя ячейка вне обязательства.
    await tester.pumpWidget(panel(
      values: <int>[core.Entry.unknown, core.Entry.unknown, core.Entry.unknown],
      definition: commitment(from: today.daysSince2000 - 1),
    ));

    final core.LocalDate before = today.minus(2);
    expect(viewAt(tester, before).cell, AbstinenceCell.beforeCommitment,
        reason: 'computed.abstinence-cell#3');
    expect(buttonAt(tester, before).onTap, isNull,
        reason: 'computed.abstinence-cell#9 — не по особому запрету дня до '
            'обещания, а как и любой другой день в этом списке');

    await tester.tap(find.byKey(EntryPanel.buttonKey(before)));
    await tester.pump();
    await tester.longPress(find.byKey(EntryPanel.buttonKey(before)));
    await tester.pump();

    expect(edits, isEmpty, reason: 'computed.abstinence-cell#9');
    expect(presses, isEmpty, reason: 'computed.abstinence-cell#9');
  });

  testWidgets(
      'computed.abstinence-cell#4 пропуск остаётся пропуском и, как и весь '
      'список, не нажимается', (tester) async {
    final core.LocalDate today = core.getToday();
    await tester.pumpWidget(panel(
      values: <int>[core.Entry.skip],
      definition: commitment(from: today.daysSince2000 - 30),
    ));

    expect(viewAt(tester, today).cell, AbstinenceCell.skipped,
        reason: 'computed.abstinence-cell#4');
    expect(buttonAt(tester, today).onTap, isNull,
        reason: 'computed.abstinence-cell#9 — не по особому запрету пропуска, '
            'а как и любой другой день в этом списке');

    await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
    await tester.pump();

    expect(viewAt(tester, today).cell, AbstinenceCell.skipped,
        reason: 'computed.abstinence-cell#9');
    expect(presses, isEmpty, reason: 'computed.abstinence-cell#9');
  });

  testWidgets('computed.abstinence-cell#7 без дня обязательства панель '
      'остаётся числовой', (tester) async {
    final core.LocalDate today = core.getToday();
    // Обе стороны в одном тесте. Проверка одного лишь `isNot(...)` зелена и
    // тогда, когда блока воздержания в `_buildButton` нет вовсе: она не
    // отличает «признак не сработал» от «кода нет».
    await tester.pumpWidget(panel(
      values: <int>[core.Entry.unknown],
      definition: commitment(from: today.daysSince2000 - 30),
    ));
    expect(viewAt(tester, today).cell, AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#7 — с признаком ячейка воздержания '
            'есть');

    // Тот же виджет, но признака нет: панель обязана вернуться к числу.
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: EntryPanel(
          values: <int>[core.Entry.unknown],
          color: theme.colorOf(const core.PaletteColor(7)),
          theme: theme,
          preferences: preferences,
          isNumerical: true,
          onEdit: edits.add,
        ),
      ),
    ));

    expect(
        tester
            .widget<EntryButton>(find.byKey(EntryPanel.buttonKey(today)))
            .view,
        isNot(isA<AbstinenceButtonView>()),
        reason: 'computed.abstinence-cell#7');
  });

  testWidgets('computed.abstinence-cell#2 панель судит допуском, а не «есть '
      'запись»', (tester) async {
    // Двадцать минут при допуске тридцать: запись в дне есть, срыва нет.
    // Прежний `stored > Entry.skip` нарисовал бы здесь крест, а счётчик дней
    // без срыва при этом не сбросился бы — интерфейс спорил бы сам с собой.
    final core.LocalDate today = core.getToday();
    await tester.pumpWidget(panel(
      values: <int>[20000],
      definition: commitment(
        from: today.daysSince2000 - 30,
        allowance: 30.0,
      ),
    ));

    expect(viewAt(tester, today).cell, AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#2 — «не более 30» обещание держит');

    await tester.pumpWidget(panel(
      values: <int>[31000],
      definition: commitment(
        from: today.daysSince2000 - 30,
        allowance: 30.0,
      ),
    ));

    expect(viewAt(tester, today).cell, AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#2');
  });
}
