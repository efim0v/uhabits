/// Overview воздержания: счётчик, кольцо, две доли и число срывов.
library;

import 'package:flutter/material.dart';
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

class AbstinenceOverviewCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final core.Theme theme = coreThemeOf(context);
    final core.AbstinenceStreaks streaks = core.abstinenceStreaksOf(habit);
    final int? since = core.abstinenceSinceMillis(habit, scope.lapses);
    final core.LocalDate today = core.getToday();
    final double level = habit.scores[today].value;

    // Один судья на всё: `isAbstinenceLapseDay` через `abstinenceSquareOf`,
    // тот же, которым судят ячейка списка, клетка календаря и кнопка ниже.
    // Вход тоже один — `habit.computedEntries` от дня обязательства до
    // сегодня. Журнал здесь не читается: он и значения дней расходятся на
    // пропуске, и подпись, читавшая журнал, объявляла срыв там, где сетка
    // показывала пропуск.
    final int todayValue = habit.computedEntries.get(today).value;
    final bool lapsedToday = isAbstinenceLapseDay(definition, todayValue);
    final List<core.Entry> days = habit.computedEntries.getByInterval(
        core.LocalDate(definition.committedFrom!), today);
    final bool Function(core.Entry)? isLapse =
        abstinenceCountsTowardsTotal(habit);
    final int lapsesTotal = isLapse == null ? 0 : days.where(isLapse).length;
    // `getByInterval` отдаёт дни от новых к старым, поэтому первое совпадение
    // и есть последний срыв. В будущее заглядывать незачем: срыв не может
    // лежать позже сегодняшнего дня.
    int? lastLapse;
    for (final core.Entry entry in days) {
      if (isAbstinenceLapseDay(definition, entry.value)) {
        lastLapse = entry.date.daysSince2000;
        break;
      }
    }
    final IntlLocalDateFormatter formatter =
        IntlLocalDateFormatter.of(context);

    return ComputedCard(
      theme: theme,
      title: l10n.overview,
      key: cardKey,
      // Кнопка живёт в `trailing`, ровно там же, где жила у счётчика, и
      // судит тем же судьёй. Пропуск — отметка человека, и нажатие её не
      // переписывает (`computed.day-write#4`): у пропущенного дня кнопка не
      // нажимается вовсе.
      trailing: TextButton(
        key: todayButtonKey,
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
          lapsedToday ? l10n.abstinenceUndoToday : l10n.abstinenceLapseToday,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Счётчик крупно и сверху: это ответ на вопрос, ради которого
          // экран открывают (`computed.abstinence-screen#11`).
          Text(
            since == null
                ? l10n.abstinenceDurationMinutes(0)
                : formatAbstinenceDuration(
                    l10n,
                    DateTime.fromMillisecondsSinceEpoch(since),
                    DateTime.now(),
                  ),
            key: counterKey,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          // Подпись прежняя, слово в слово: счётчик отвечает «сколько
          // держусь», она — «с каких пор». Задача 12 запрещает ослаблять её
          // проверки, а не показывать её было бы самым сильным ослаблением.
          Text(
            lastLapse == null
                ? l10n.abstinenceSince(formatter
                    .longFormat(core.LocalDate(definition.committedFrom!)))
                : l10n.abstinenceLastLapse(
                    formatter.longFormat(core.LocalDate(lastLapse))),
            key: subtitleKey,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              SizedBox(
                width: ringSize,
                height: ringSize,
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
