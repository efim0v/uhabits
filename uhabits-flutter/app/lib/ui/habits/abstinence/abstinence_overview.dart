/// Overview воздержания: счётчик, кольцо, две доли, число срывов и кнопка.
library;

// `date_utils.dart` не отдаёт свой крюк через барель ядра — тем же путём его
// читают `widget_sync.dart` и `abstinence_sync.dart`.
// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/time/date_utils.dart'
    show systemCurrentTimeMillis;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../state/app_scope.dart';
import '../../common/views/ring_view.dart';
// `show coreThemeOf`, as in `show_habit_screen.dart`: `app_theme.dart` also
// declares its own `toFlutterColor`, and the one this file uses is the
// card's own copy (`computed_card.dart`), per the brief.
import '../../theme/app_theme.dart' show coreThemeOf;
import '../computed/computed_card.dart';
import '../list/list_header.dart' show IntlLocalDateFormatter;
import 'abstinence_button_view.dart' show isAbstinenceLapseDay;
import 'abstinence_calendar.dart' show abstinenceCountsTowardsTotal;
import 'abstinence_duration.dart';
import 'abstinence_gestures.dart';

class AbstinenceOverviewCard extends StatefulWidget {
  const AbstinenceOverviewCard({
    required this.habit,
    required this.definition,
    required this.scope,
    required this.onLapse,
    super.key,
  });

  final core.Habit habit;
  final core.HabitDefinition definition;
  final AppScope scope;

  /// Перерисовать экран, когда срыв записан.
  final VoidCallback onLapse;

  // Ключи те же, что были у карточки-счётчика, и это не лень: пять
  // существующих проверок в `abstinence_screen_test.dart` жмут кнопку по
  // `abstinence.today`. Число переехало, поведение — нет, и менять ключ
  // значило бы переписать работающие тесты ради переименования.
  static const Key cardKey = Key('abstinence.counter');
  static const Key todayButtonKey = Key('abstinence.today');
  static const Key counterKey = Key('abstinence.duration');
  static const Key subtitleKey = Key('abstinence.subtitle');

  /// `show_habit_overview.xml`: кольцо 30dp, как у портированного Overview.
  static const double ringSize = 30.0;

  @override
  State<AbstinenceOverviewCard> createState() => _AbstinenceOverviewCardState();
}

class _AbstinenceOverviewCardState extends State<AbstinenceOverviewCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  @override
  void dispose() {
    // Без отмены таймер пережил бы карточку: он держит только `setState`
    // этого `State`, но зона `flutter_test` считает такой висящий таймер
    // ошибкой ровно потому, что в настоящем приложении это была бы утечка —
    // виджет ушёл с экрана, а будильник продолжал бы будить дерево, которого
    // больше нет.
    _tick?.cancel();
    super.dispose();
  }

  /// Планирует следующую перерисовку ровно на границу минуты.
  ///
  /// Не «через шестьдесят секунд от того, как открыли экран» — так цифра
  /// менялась бы в случайный момент внутри минуты, — а на первый момент
  /// после «сейчас», у которого миллисекунды от начала минуты нулевые: ровно
  /// тогда меняется младшая единица счётчика (`computed.since#5`).
  void _scheduleTick() {
    final int msIntoMinute = systemCurrentTimeMillis() % 60000;
    final int delay = 60000 - msIntoMinute;
    _tick = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() {});
      _scheduleTick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final core.Habit habit = widget.habit;
    final core.HabitDefinition definition = widget.definition;
    final AppScope scope = widget.scope;
    final VoidCallback onLapse = widget.onLapse;

    final L10n l10n = L10n.of(context);
    final core.Theme theme = coreThemeOf(context);
    final core.AbstinenceStreaks streaks = core.abstinenceStreaksOf(habit);
    final core.LocalDate today = core.getToday();
    final double level = habit.scores[today].value;

    // Один судья на всё: `isAbstinenceLapseDay`, тот же, которым судят ячейка
    // списка, клетка календаря и кнопка ниже. Вход тоже один —
    // `habit.computedEntries` от дня обязательства до сегодня. Журнал здесь
    // не читается: он и значения дней расходятся на пропуске, и подпись,
    // читавшая журнал, объявляла срыв там, где сетка показывала пропуск.
    bool isLapseValue(int value) => isAbstinenceLapseDay(definition, value);

    final int todayValue = habit.computedEntries.get(today).value;
    final bool lapsedToday = isLapseValue(todayValue);
    final int? since = core.abstinenceSinceMillis(habit, scope.lapses,
        isLapseValue: isLapseValue);
    // Тот же день, что взял счётчик, и взят он тем же вызовом: число над
    // подписью и дата в ней называют один срыв потому, что спрашивают его
    // одной функцией, а не потому, что два цикла написаны одинаково
    // (`computed.abstinence-screen#2`).
    final int? lastLapse =
        core.lastAbstinenceLapseDay(habit, isLapseValue: isLapseValue);
    final List<core.Entry> days = habit.computedEntries.getByInterval(
        core.LocalDate(definition.committedFrom!), today);
    final bool Function(core.Entry)? isLapse =
        abstinenceCountsTowardsTotal(habit);
    final int lapsesTotal = isLapse == null ? 0 : days.where(isLapse).length;
    final IntlLocalDateFormatter formatter =
        IntlLocalDateFormatter.of(context);

    return ComputedCard(
      theme: theme,
      title: l10n.overview,
      key: AbstinenceOverviewCard.cardKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Счётчик крупно и сверху: это ответ на вопрос, ради которого
          // экран открывают (`computed.abstinence-screen#11`). Рамка вокруг
          // него — цветом границы из темы, тем же `contrast20`, которым уже
          // очерчена ячейка списка (`entry_panel.dart`) — не выдумана заново
          // для этой карточки.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: toFlutterColor(theme.contrast20)),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              since == null
                  ? l10n.abstinenceDurationMinutes(0)
                  : formatAbstinenceDuration(
                      l10n,
                      DateTime.fromMillisecondsSinceEpoch(since),
                      // Тот же крюк, что пишет момент срыва
                      // (`computed.since#7`): подмена часов в тесте обязана
                      // двигать и его, и это число одним поворотом одного
                      // винта, а не двумя.
                      DateTime.fromMillisecondsSinceEpoch(
                          systemCurrentTimeMillis()),
                    ),
              key: AbstinenceOverviewCard.counterKey,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          // Подпись прежняя, слово в слово: счётчик отвечает «сколько
          // держусь», она — «с каких пор». Задача 12 запрещает ослаблять её
          // проверки, а не показывать её было бы самым сильным ослаблением.
          Text(
            lastLapse == null
                ? l10n.abstinenceSince(formatter
                    .longFormat(core.LocalDate(definition.committedFrom!)))
                : l10n.abstinenceLastLapse(
                    formatter.longFormat(core.LocalDate(lastLapse))),
            key: AbstinenceOverviewCard.subtitleKey,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              SizedBox(
                width: AbstinenceOverviewCard.ringSize,
                height: AbstinenceOverviewCard.ringSize,
                child: RingView(
                  percentage: level,
                  color: toFlutterColor(theme.colorOf(habit.color)),
                  backgroundColor: toFlutterColor(theme.cardBackgroundColor),
                  inactiveColor: toFlutterColor(theme.lowContrastTextColor),
                  text: '${(level * 100).round()}%',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Сто процентов от самого себя — не новость; рекорд —
                    // новость (`computed.abstinence-screen#11`). А пока
                    // рекорда нет вовсе — серий ни одной или лучшая длится
                    // ноль суток, — строки нет: сравнивать не с чем, и
                    // «рекорд» за ноль прожитых суток был бы неправдой
                    // (`computed.streak#12`).
                    if (streaks.hasRecord)
                      _shareLine(
                        context,
                        label: l10n.abstinenceOfRecord,
                        share:
                            streaks.currentIsBest ? null : streaks.shareOfBest,
                        instead: streaks.currentIsBest
                            ? l10n.abstinenceIsRecord
                            : null,
                      ),
                    // Первой попытке сравнивать не с чем, и строки нет вовсе.
                    if (streaks.shareOfPrevious != null)
                      _shareLine(
                        context,
                        label: l10n.abstinenceOfPrevious,
                        share: streaks.shareOfPrevious,
                      ),
                    // «Всего срывов» остаётся: число уже считается верно и
                    // отвечает на осмысленный вопрос.
                    _shareLine(
                      context,
                      label: l10n.abstinenceLapsesTotal,
                      instead: '$lapsesTotal',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Полноширинная кнопка с заливкой, а не строка в углу шапки: тот
          // же `FilledButton`, каким сон подтверждает введённую ночь
          // (`sleep/manual_entry_sheet.dart`) — действие, которое ничего не
          // рушит и снимается тем же нажатием, обходится без кричащего
          // предупреждающего цвета. Судит тем же судьёй, что и подпись выше.
          // Пропуск — отметка человека, и нажатие её не переписывает
          // (`computed.day-write#4`): у пропущенного дня кнопка не
          // нажимается вовсе.
          FilledButton(
            key: AbstinenceOverviewCard.todayButtonKey,
            onPressed: todayValue == core.Entry.skip
                ? null
                : () async {
                    final bool written = await toggleLapseDay(
                      context,
                      scope,
                      habit: habit,
                      definition: definition,
                      date: today,
                      lapsed: !lapsedToday,
                      theme: theme,
                    );
                    if (written) onLapse();
                  },
            child: Text(
              lapsedToday
                  ? l10n.abstinenceUndoToday
                  : l10n.abstinenceLapseToday,
            ),
          ),
        ],
      ),
    );
  }
}

/// Строка «подпись — значение»: доля в процентах, либо готовое слово вместо
/// неё, когда доли нет.
///
/// Ровно один из [share] и [instead] не пуст. Доля печатается целыми
/// процентами: `'${(share * 100).round()}%'`.
Widget _shareLine(
  BuildContext context, {
  required String label,
  double? share,
  String? instead,
}) {
  final core.Theme theme = coreThemeOf(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: <Widget>[
        Text(
          share == null ? instead! : '${(share * 100).round()}%',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: toFlutterColor(theme.highContrastTextColor),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: toFlutterColor(theme.mediumContrastTextColor),
            ),
          ),
        ),
      ],
    ),
  );
}
