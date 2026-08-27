/// Панель дней привычки-воздержания: что рисуется и куда уходит жест.
///
/// Здесь только панель — без базы и без экрана. Что тап действительно пишет
/// срыв, проверяет `abstinence_cell_test.dart`.
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
  final List<({core.LocalDate date, bool lapsed})> lapses =
      <({core.LocalDate date, bool lapsed})>[];
  final List<core.LocalDate> edits = <core.LocalDate>[];

  /// Ответ двери записи: `true` — «записал», `false` — «ничего не записано».
  /// В этих двух случаях панель обязана вести себя по-разному.
  late bool writeSucceeds;

  setUp(() {
    core.setToday(core.LocalDate.ymd(2020, 1, 15));
    preferences = core.Preferences(core.MemoryStorage());
    lapses.clear();
    edits.clear();
    writeSucceeds = true;
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
            onLapse: (core.LocalDate date, bool lapsed) async {
              lapses.add((date: date, lapsed: lapsed));
              return writeSucceeds;
            },
            onEdit: edits.add,
          ),
        ),
      );

  AbstinenceButtonView viewAt(WidgetTester tester, core.LocalDate date) =>
      tester.widget<EntryButton>(find.byKey(EntryPanel.buttonKey(date))).view
          as AbstinenceButtonView;

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

  testWidgets('computed.abstinence-cell#5 тап сообщает о срыве, повторный — '
      'об отмене', (tester) async {
    final core.LocalDate today = core.getToday();
    await tester.pumpWidget(panel(
      values: <int>[core.Entry.unknown],
      definition: commitment(from: today.daysSince2000 - 30),
    ));

    await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
    await tester.pump();

    expect(lapses.single.lapsed, isTrue, reason: 'computed.abstinence-cell#5');
    expect(lapses.single.date, today, reason: 'computed.abstinence-cell#5');
    // Оптимистичная перерисовка: ячейка обязана показать крест до того, как
    // придут пересчитанные значения — иначе тап выглядит как ничего.
    expect(viewAt(tester, today).cell, AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#5');

    await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
    await tester.pump();

    expect(lapses.last.lapsed, isFalse, reason: 'computed.abstinence-cell#5');
    expect(viewAt(tester, today).cell, AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#5');
  });

  testWidgets('computed.abstinence-cell#3 день до обязательства не нажимается',
      (tester) async {
    final core.LocalDate today = core.getToday();
    // Обещание дано вчера: позавчерашняя ячейка вне обязательства.
    await tester.pumpWidget(panel(
      values: <int>[core.Entry.unknown, core.Entry.unknown, core.Entry.unknown],
      definition: commitment(from: today.daysSince2000 - 1),
    ));

    final core.LocalDate before = today.minus(2);
    expect(viewAt(tester, before).cell, AbstinenceCell.beforeCommitment,
        reason: 'computed.abstinence-cell#3');

    await tester.tap(find.byKey(EntryPanel.buttonKey(before)));
    await tester.pump();

    expect(lapses, isEmpty, reason: 'computed.abstinence-cell#3');
    expect(edits, isEmpty, reason: 'computed.abstinence-cell#3');
  });

  testWidgets('computed.abstinence-cell#4 пропуск тапом в срыв не переводится',
      (tester) async {
    final core.LocalDate today = core.getToday();
    await tester.pumpWidget(panel(
      values: <int>[core.Entry.skip],
      definition: commitment(from: today.daysSince2000 - 30),
    ));

    await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
    await tester.pump();

    expect(lapses, isEmpty,
        reason: 'computed.abstinence-cell#4 — DayWriter всё равно не перепишет '
            'пропуск, и ячейка не должна врать, что перепишет');
    expect(viewAt(tester, today).cell, AbstinenceCell.skipped,
        reason: 'computed.abstinence-cell#4');
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

  testWidgets('computed.abstinence-cell#5 не записанный срыв ячейку не '
      'перекрашивает', (tester) async {
    // Оптимистичная краска есть обещание, а не факт. Дверь записи отвечает,
    // записала ли она что-нибудь; ответ «нет» — это и передумавший человек, и
    // отказ охраны, и в обоих случаях крест на ячейке был бы враньём до
    // ближайшей перерисовки списка, которой в этом случае не будет.
    final core.LocalDate today = core.getToday();
    writeSucceeds = false;
    await tester.pumpWidget(panel(
      values: <int>[core.Entry.unknown],
      definition: commitment(from: today.daysSince2000 - 30),
    ));

    await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
    await tester.pumpAndSettle();

    expect(lapses.single.lapsed, isTrue,
        reason: 'computed.abstinence-cell#5 — спросили дверь');
    expect(viewAt(tester, today).cell, AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#5 — и вернулись к галочке, потому '
            'что дверь ничего не записала');
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
