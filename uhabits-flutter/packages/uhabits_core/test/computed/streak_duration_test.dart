import 'package:test/test.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  setUp(() => setToday(LocalDate(9000)));
  tearDown(resetToday);

  test('#8 a finished streak lasted as many days as it holds', () {
    // Серия с 8990 по 8999: срыв случился 9000-го, значит с начала до срыва
    // прошло ровно десять суток — столько же, сколько дней в серии.
    final Streak finished = Streak(LocalDate(8990), LocalDate(8999));

    expect(elapsedDaysOf(finished), 10,
        reason: 'computed.streak#8 — у завершённой серии включительный счёт '
            'и есть прошедшее время');
    expect(elapsedDaysOf(finished), finished.length,
        reason: 'computed.streak#8');
  });

  test('#8 the running streak has not lived through today yet', () {
    final Streak running = Streak(LocalDate(8990), LocalDate(9000));

    expect(running.length, 11,
        reason: 'портированный счёт включителен — это не меняется');
    expect(elapsedDaysOf(running), 10,
        reason: 'computed.streak#8 — сегодня ещё идёт, и целыми сутками не '
            'стало');
  });

  test('#8 a streak begun today has lasted no days at all', () {
    expect(elapsedDaysOf(Streak(LocalDate(9000), LocalDate(9000))), 0,
        reason: 'computed.streak#8 — первый день не превращается в единицу '
            'просто оттого, что начался');
  });

  test('#9 the running streak has not beaten an equal finished one', () {
    final Streak finished = Streak(LocalDate(8000), LocalDate(8010));
    final Streak running = Streak(LocalDate(8990), LocalDate(9000));

    expect(finished.length, running.length,
        reason: 'по включительному счёту они равны');
    expect(elapsedDaysOf(running), lessThan(elapsedDaysOf(finished)),
        reason: 'computed.streak#9 — идущая серия обходит завершённую только '
            'когда сегодняшний день закончится');
  });

  test('#8 the running streak agrees with the days-without-a-lapse counter',
      () {
    final Streak running = Streak(LocalDate(8990), LocalDate(9000));

    expect(elapsedDaysOf(running), LocalDate(8990).daysUntil(LocalDate(9000)),
        reason: 'computed.streak#8 — прошедшие сутки есть расстояние от '
            'начала серии до сегодня, тем же счётом, каким его меряет '
            'счётчик дней без срыва');
  });

  test('#8 the day asked about is the day answered about', () {
    final Streak running = Streak(LocalDate(8990), LocalDate(9000));

    // Без этой проверки реализация, которая молча берёт `getToday()` и
    // выбрасывает `asOf`, прошла бы все проверки выше: у них сегодня и есть
    // 9000. А `asOf` передаёт вниз вся вышестоящая арифметика воздержания,
    // и день, о котором спросили, обязан быть днём, о котором ответили.
    expect(elapsedDaysOf(running, asOf: LocalDate(9010)), 11,
        reason: 'computed.streak#8 — на десятый день после конца серия '
            'завершена, и прошедших суток в ней одиннадцать, включительно '
            'с последним');
    expect(elapsedDaysOf(running, asOf: LocalDate(9000)), 10,
        reason: 'computed.streak#8 — а в свой последний день она ещё идёт, '
            'и сегодняшний день целыми сутками не стал');
  });
}
