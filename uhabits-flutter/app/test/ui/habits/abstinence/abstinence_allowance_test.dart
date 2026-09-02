/// Допуск больше нуля: жест спрашивает величину, и трое отвечают одинаково.
///
/// «Не более 30 минут» без числа не выражается. Молчаливый `amount = 1` при
/// допуске 30 записал бы день, который обещание держит, а покрасил бы его как
/// срыв — и тогда ячейка говорила бы «сорвался», счётчик «сорок дней без
/// срыва», а балл не шелохнулся бы. Здесь эти трое спрошены об одном дне.
///
/// Пишет кнопка карточки — список этого вида только для просмотра
/// (`computed.abstinence-cell#9`), и тап по нему величину больше не
/// спрашивает. Дверь и диалог те же, что были бы у тапа: кнопка зовёт
/// `toggleLapseDay` ровно так же, как раньше звала ячейка списка
/// (`computed.abstinence-cell#5`).
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/common/dialogs/current_dialog.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_button_view.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_gestures.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_overview.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/src/time/date_utils.dart'
    show systemCurrentTimeMillis;
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  late AppScope scope;
  late Habit habit;

  /// «Не более [allowance] минут в день», обещание дано [daysAgo] дней
  /// назад (по умолчанию сорок).
  ///
  /// Допуск пишется в двух местах одним движением, потому что судьи два лица
  /// одного числа: `payload` читает интерфейс, `targetValue` — оценка
  /// (`computed.allowance#1`).
  void commit({required double allowance, String? unit, int daysAgo = 40}) {
    habit.targetValue = allowance;
    scope.habitList.update(<Habit>[habit]);
    scope.definitions.save(
      habit.id!,
      HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: getToday().daysSince2000 - daysAgo,
        payload: abstinencePayload(
          allowance: allowance,
          // Единицу человек пишет сам, своим словом: в форме это свободное
          // поле, а `count` есть признак «оставили пустым».
          unit: unit ??
              (allowance == 0.0
                  ? abstinenceUnitCount
                  : abstinenceUnitMinutes),
        ),
      ),
    );
    attachDefinition(habit, scope.definitions);
    habit.recompute();
  }

  setUp(() {
    resetToday();
    // Слот текущего диалога живёт в процессе, а процесс между тестами
    // не пересоздаётся: иначе попап одного теста попал бы под
    // `dismissCurrentAndShow` следующего.
    resetCurrentDialog();
    tempDir = Directory.systemTemp.createTempSync('uhabits_allowance');
    scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scope.preferences.isFirstRun = false;

    habit = scope.modelFactory.buildHabit()
      ..name = 'Screen time'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 30
      ..unit = 'minutes';
    scope.habitList.add(habit);
    commit(allowance: 30.0);
  });

  tearDown(() {
    resetCurrentDialog();
    scope.close();
    tempDir.deleteSync(recursive: true);
  });

  Widget list() => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        locale: const Locale('ru'),
        home: Provider<AppScope>.value(
          value: scope,
          child: const HabitListScreen(),
        ),
      );

  Widget screen() => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        locale: const Locale('ru'),
        home: Provider<AppScope>.value(
          value: scope,
          child: ShowHabitScreen(
            key: ValueKey<String?>(habit.uuid),
            habit: habit,
          ),
        ),
      );

  AbstinenceCell cellToday(WidgetTester tester) => (tester
          .widget<EntryButton>(find.byKey(EntryPanel.buttonKey(getToday())))
          .view as AbstinenceButtonView)
      .cell;

  /// Ставит список текущим деревом, чтобы прочесть его ячейку —
  /// `cellToday` — самим списком он больше не пишет
  /// (`computed.abstinence-cell#9`).
  Future<void> readList(WidgetTester tester) async {
    await tester.pumpWidget(list());
    await tester.pumpAndSettle();
  }

  /// Жест «сорвался», записывающий срыв за сегодня: кнопка карточки на
  /// экране самой привычки, а не тап по ячейке списка — тот теперь только
  /// рисует (`computed.abstinence-cell#9`).
  Future<void> tapToday(WidgetTester tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AbstinenceOverviewCard.todayButtonKey));
    await tester.pumpAndSettle();
  }

  Future<void> answer(WidgetTester tester, String amount) async {
    expect(find.byType(NumberDialog), findsOneWidget,
        reason: 'computed.abstinence-cell#8 — при допуске больше нуля тап '
            'спрашивает величину');
    await tester.enterText(
        find.byKey(const ValueKey<String>('number_value')), amount);
    await tester.tap(find.byKey(const ValueKey<String>('number_save_button')));
    await tester.pumpAndSettle();
  }

  // Локальным геттером это не выразить: `get` внутри тела функции
  // Dart не принимает.
  int todayDay() => getToday().daysSince2000;

  /// Что стоит в поле величины, когда вопрос только открылся.
  String amountField(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const ValueKey<String>('number_value')))
      .controller!
      .text;

  testWidgets('computed.abstinence-cell#8 двадцать минут при допуске тридцать '
      'обещание держат, и трое согласны', (tester) async {
    // Двадцать, не сорок: `since` считает разрыв календарно
    // (`computed.since#6`), и сорок настоящих суток от полуночи
    // обязательства до настоящего момента теста пересекли бы границу месяца
    // — остаток дней после месяца гуляет вместе с датой прогона, и точную
    // проверку текста он бы не пережил. Восемь остальных тестов файла зовут
    // `commit` без этого параметра и его не замечают.
    commit(allowance: 30.0, daysAgo: 20);
    await tapToday(tester);
    await answer(tester, '20');

    // Журнал записал двадцать, а не «единицу»: величина есть факт дня.
    expect(scope.lapses.forDay(habit.id!, todayDay()), 20,
        reason: 'computed.abstinence-cell#8');

    // Первый из троих — кнопка карточки, которой и записан срыв: `tapToday`
    // уже оставил её на экране.
    expect(find.text('Отметить срыв'), findsOneWidget,
        reason: 'computed.abstinence-screen#5 — предлагать «Отменить срыв» '
            'там, где срыва не было, значит спорить с ячейкой');
    // Второй — счётчик, адресован напрямую по своему ключу, а не всему
    // дереву: `find.textContaining` по всему экрану поймал бы и чужое
    // «раз в месяц» на карточке «Частота», окажись оно там однажды.
    expect(
      tester.widget<Text>(find.byKey(AbstinenceOverviewCard.counterKey)).data,
      contains('20 дней'),
      reason: 'computed.streak#4 — двадцать минут серию не рвут: счётчик '
          'по-прежнему считает от дня обязательства, а не от сегодня',
    );

    // Третий — ячейка списка. Список этого вида только для просмотра
    // (`computed.abstinence-cell#9`) и срыв не писал, но кэш у него общий с
    // теми двумя, и согласие троих от этого не страдает.
    await readList(tester);
    expect(cellToday(tester), AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#2 — «не более 30» обещание держит');
  });

  testWidgets('computed.abstinence-cell#5 подтверждённая величина не оставляет '
      'креста на чистом дне', (tester) async {
    // Ревью нашло: жест отвечал `true` всегда, а свод — «значение дня не
    // сдвинулось». Двадцать минут уже записаны; человек открывает вопрос
    // ещё раз и подтверждает те же двадцать. Журнал заменяет строку тем же
    // числом, `writeDays` не пишет ничего и молчит, и список — тот, что
    // сейчас лишь читает этот кэш (`computed.abstinence-cell#9`), — обязан
    // остаться тем же, чем был до второго нажатия.
    await tapToday(tester);
    await answer(tester, '20');
    await readList(tester);
    expect(cellToday(tester), AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#2');

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AbstinenceOverviewCard.todayButtonKey));
    await tester.pumpAndSettle();
    expect(amountField(tester), '20',
        reason: 'computed.abstinence-cell#8 — вопрос открылся на том, что в '
            'дне уже записано');
    await answer(tester, '20');

    expect(scope.lapses.forDay(habit.id!, todayDay()), 20,
        reason: 'computed.abstinence-cell#8 — журнал остался при своих '
            'двадцати');
    await readList(tester);
    expect(cellToday(tester), AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#5 — на чистом дне стоит галочка, а '
            'не крест');

    // Единственная дверь жеста отвечает ответом свода — тот же вызов, что
    // делает `toggleLapseDay` после ответа на вопрос о величине, — те же
    // двадцать в дне, где двадцать и лежат.
    expect(
        setLapseDay(scope,
            habit: habit, date: getToday(), lapsed: true, amount: 20),
        isFalse,
        reason: 'computed.abstinence-sync#6 — значение дня не сдвинулось, и '
            'кнопке с календарём отвечать перерисовкой нечего');
  });

  testWidgets('computed.abstinence-cell#8 сорок пять минут — срыв, и трое '
      'согласны с этим', (tester) async {
    // Момент срыва и «сейчас» под счётчиком читаются одним и тем же крюком
    // (`computed.since#7`), и без подмены часов между записью момента (в
    // `answer`) и чтением карточки прошло бы настоящее время выполнения —
    // на медленной машине оно способно перевалить за секунду и дать «1
    // секунда» вместо «0 секунд». Часы прибиты на всё время теста.
    final int Function() realClock = systemCurrentTimeMillis;
    addTearDown(() => systemCurrentTimeMillis = realClock);
    final int nowMillis = realClock();
    systemCurrentTimeMillis = () => nowMillis;

    await tapToday(tester);
    await answer(tester, '45');

    expect(scope.lapses.forDay(habit.id!, todayDay()), 45,
        reason: 'computed.abstinence-cell#8');

    // Кнопка и счётчик — `tapToday` уже оставил экран привычки текущим.
    expect(find.text('Отменить срыв'), findsOneWidget,
        reason: 'computed.abstinence-screen#5');
    // Счётчик больше не пишет голую цифру: сорок пять минут записаны
    // мгновение назад, и счёт идёт от момента этого срыва, а карточка
    // показывает «0 секунд», а не «0».
    expect(find.text('0 секунд'), findsWidgets,
        reason: 'computed.since#4 — срыв сегодня начинает счёт заново, и в '
            'первую секунду после него это «0 секунд»');

    await readList(tester);
    expect(cellToday(tester), AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#2');
  });

  testWidgets('computed.abstinence-cell#8 вопрос без ответа фактом не '
      'становится', (tester) async {
    await tapToday(tester);

    expect(find.byType(NumberDialog), findsOneWidget,
        reason: 'computed.abstinence-cell#8');
    Navigator.of(tester.element(find.byType(NumberDialog))).pop();
    await tester.pumpAndSettle();

    expect(scope.lapses.forDay(habit.id!, todayDay()), isNull,
        reason: 'computed.abstinence-cell#8');
    await readList(tester);
    expect(cellToday(tester), AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#9 — список только читает: отказ от '
            'ответа ничего не записал, и рисовать ячейке нечего, кроме '
            'тишины');
  });

  testWidgets('computed.abstinence-cell#8 ноль — это молчание, а не срыв',
      (tester) async {
    // Ноль удовлетворяет «не больше допуска» при любом допуске, то есть
    // означает «ничего не было». Молчание есть отсутствие строки
    // (`computed.lapses#1`, `#2`), поэтому ноль в ответе равен отказу.
    await tapToday(tester);
    await answer(tester, '0');

    expect(scope.lapses.forDay(habit.id!, todayDay()), isNull,
        reason: 'computed.abstinence-cell#8');
    await readList(tester);
    expect(cellToday(tester), AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#8');
  });

  testWidgets('computed.abstinence-cell#8 при допуске ноль вопроса нет',
      (tester) async {
    commit(allowance: 0.0);

    await tapToday(tester);

    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.abstinence-cell#6 — общая дверь числа закрыта, и на '
            'умолчании лишнего шага нет');
    expect(scope.lapses.forDay(habit.id!, todayDay()),
        LapseRepository.minimumAmount,
        reason: 'computed.abstinence-cell#8 — нажатие пишет одну единицу, '
            'как и было');
    await readList(tester);
    expect(cellToday(tester), AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#2');
  });

  testWidgets('computed.abstinence-cell#8 снятие срыва величины не спрашивает',
      (tester) async {
    await tapToday(tester);
    await answer(tester, '45');

    await tester.tap(find.byKey(AbstinenceOverviewCard.todayButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.abstinence-cell#8 — «этого не было» количества не '
            'имеет');
    expect(scope.lapses.forDay(habit.id!, todayDay()), isNull,
        reason: 'computed.abstinence-cell#5');
  });

  testWidgets('computed.abstinence-cell#8 вопрос спрашивает только «сколько»',
      (tester) async {
    await tapToday(tester);

    expect(find.byType(NumberDialog), findsOneWidget,
        reason: 'computed.abstinence-cell#8');
    // Поле заметок у портированного попапа есть, и здесь его быть не должно:
    // журналу срывов заметку хранить негде — в `Lapses` нет такого столбца, —
    // и поле, которое принимает текст и молча его теряет, хуже отсутствующего
    // (`audit7.numeric-entry-popup-throws-away-a#1` заведён ровно на эту
    // форму: попап закрывается как ни в чём не бывало, а написанного нет).
    expect(find.byKey(const ValueKey<String>('number_notes')), findsNothing,
        reason: 'computed.abstinence-cell#8 — спрашивают величину, и только '
            'её; поле, которому нечего сделать с ответом, не показывают');
    // Спрошено и то, чем диалог остался: `findsNothing` зелено и тогда, когда
    // от попапа не осталось ничего.
    expect(find.byKey(const ValueKey<String>('number_value')), findsOneWidget,
        reason: 'computed.abstinence-cell#8 — величину по-прежнему вводят');
    expect(find.byKey(const ValueKey<String>('number_save_button')),
        findsOneWidget,
        reason: 'computed.abstinence-cell#8');
  });

  testWidgets('number-dialog.popup#18 вопрос о величине занимает тот же слот, '
      'что и портированный попап', (tester) async {
    await tapToday(tester);

    expect(find.byType(NumberDialog), findsOneWidget,
        reason: 'number-dialog.popup#18');
    expect(hasCurrentDialog, isTrue,
        reason: 'number-dialog.popup#18 — второй вход к тому же попапу встаёт '
            'в тот же слот: иначе второй тап положил бы второй диалог поверх '
            'первого, а уход приложения в фон оставил бы его висеть '
            '(`platform-glue.transient-ui-helpers#4`, `#5`)');

    // Ровно то, что делает `onPause` обоих экранов.
    dismissCurrentDialog();
    await tester.pumpAndSettle();

    expect(find.byType(NumberDialog), findsNothing,
        reason: 'number-dialog.popup#18');
    expect(scope.lapses.forDay(habit.id!, todayDay()), isNull,
        reason: 'computed.abstinence-cell#8 — закрытый чужой рукой вопрос '
            'фактом не становится');
    await readList(tester);
    expect(cellToday(tester), AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#9 — список ничего не писал и '
            'ничего не рисует поверх тишины');
  });

  testWidgets('computed.abstinence-cell#8 вопрос открывается на том, что в '
      'дне уже записано', (tester) async {
    await tapToday(tester);

    // Пустой день — ноль: открывать нечему.
    expect(amountField(tester), '0',
        reason: 'computed.abstinence-cell#8 — в дне ничего не записано');
    await answer(tester, '20');
    expect(scope.lapses.forDay(habit.id!, todayDay()), 20,
        reason: 'computed.abstinence-cell#8');

    // Двадцать минут при допуске тридцать обещание держат, ячейка чиста — и
    // следующее нажатие снова спрашивает величину. Открыть его нулём
    // значило бы предложить человеку стереть написанное, не показав ему, что
    // там написано: он подтвердил бы «45», а двадцать исчезли бы молча.
    await tester.tap(find.byKey(AbstinenceOverviewCard.todayButtonKey));
    await tester.pumpAndSettle();

    expect(amountField(tester), '20',
        reason: 'computed.abstinence-cell#8 — вопрос есть правка записанного, '
            'а не запись поверх вслепую');

    // И отказ от правки записанного не трогает.
    Navigator.of(tester.element(find.byType(NumberDialog))).pop();
    await tester.pumpAndSettle();

    expect(scope.lapses.forDay(habit.id!, todayDay()), 20,
        reason: 'computed.abstinence-cell#8');
  });

  testWidgets('computed.abstinence-cell#8 вопрос называет допуск и единицу',
      (tester) async {
    // «Сколько?» без «чего и из скольких» — вопрос, на который нечем
    // ответить. Единица приходит из полезной нагрузки словом самого человека
    // (`computed.allowance#2`), допуск — оттуда же.
    commit(allowance: 30.0, unit: 'минут');

    await tapToday(tester);

    // Не `find.text(...)`: экран самой привычки уже показывает то же
    // обещание в подписи под карточкой, а диалог должен повторить его над
    // полем — тот же текст в двух местах, и найден должен быть именно
    // `number_prompt`.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey<String>('number_prompt')))
          .data,
      'Не более 30 минут в день',
      reason: 'computed.abstinence-cell#8 — обещание, против которого вводят '
          'число, стоит над полем',
    );
  });

  testWidgets('computed.abstinence-cell#8 без единицы вопрос называет один '
      'допуск', (tester) async {
    // Единицу оставили пустой, и `count` есть признак этого, а не слово,
    // которое можно показать: «Не более 3 count в день» было бы мусором.
    commit(allowance: 3.0, unit: abstinenceUnitCount);

    await tapToday(tester);

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey<String>('number_prompt')))
          .data,
      'Не более 3 в день',
      reason: 'computed.abstinence-cell#8',
    );
  });
}
