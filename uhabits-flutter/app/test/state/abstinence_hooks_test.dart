/// Хуки, которые не смотрят на вид, — и воздержание под ними.
///
/// Четыре из восьми хуков слоя написаны через «есть ли у привычки определение»,
/// а не «какое». Значит второй вид получает их даром. Это и проверяется: даром
/// без теста есть догадка, а хуки закрывают потерю данных.
library;

// Commands and core models are reached by their `src` path, exactly as
// lib/state does.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/computed_habit_hooks.dart';
import 'package:uhabits/state/show_habit_model.dart';
import 'package:uhabits/state/widget_sync.dart' show WidgetBehavior;
import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/delete_habits_command.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// Постит в никуда: `WidgetBehavior` снимает уведомление на каждой записи, а
/// платформы, с которой его снимать, здесь нет. Форма взята дословно из
/// `app/test/state/computed_write_paths_test.dart:144`.
class _SilentTray implements SystemTray {
  @override
  void log(String msg) {}

  @override
  void removeNotification(int notificationId) {}

  @override
  void showNotification(
    Habit habit,
    int notificationId,
    LocalDate date,
    int reminderTime,
  ) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Database database;
  late AppScope scope;
  late Habit quit;

  setUp(() {
    setToday(LocalDate(9000));
    tempDir = Directory.systemTemp.createTempSync('uhabits_abstinence_hooks');
    database = AppDatabase.openAndMigrate('${tempDir.path}/habits.db');
    scope = AppScope.open(
      database,
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    scope.preferences.isFirstRun = false;

    quit = scope.modelFactory.buildHabit()
      ..name = 'No smoking'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0
      ..unit = '';
    scope.habitList.add(quit);
    scope.definitions.save(
      quit.id!,
      const HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 9000,
      ),
    );
  });

  tearDown(() {
    scope.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    resetToday();
  });

  // Хук 2.
  test('deleting one withdraws its alarms, whatever kind it is', () {
    final List<int> withdrawn = <int>[];
    final ComputedHabitHooks hooks =
        ComputedHabitHooks(withdrawAlarms: (Habit h) => withdrawn.add(h.id!));

    hooks.onCommandFinished(DeleteHabitsCommand(scope.habitList, <Habit>[quit]));
    hooks.onCommandFinished(
        ArchiveHabitsCommand(scope.habitList, <Habit>[quit]));

    expect(withdrawn, <int>[quit.id!, quit.id!],
        reason: 'computed.lifecycle#5');
  });

  // Хук 5.
  test('a computed day keeps the note the person wrote', () {
    quit.originalEntries
        .add(Entry(LocalDate(9000), Entry.unknown, notes: 'третий день'));
    const DayWriter().write(quit, 9000, 500000);

    expect(quit.originalEntries.get(LocalDate(9000)).notes, 'третий день',
        reason: 'computed.day-write#1');
  });

  // Хук 6.
  test('the widget, the notification and the queue write nothing here', () {
    final WidgetBehavior behavior = WidgetBehavior(
      habitList: scope.habitList,
      commandRunner: scope.commandRunner,
      notificationTray: NotificationTray(
        scope.taskRunner,
        scope.commandRunner,
        scope.preferences,
        _SilentTray(),
      ),
      preferences: scope.preferences,
      isComputed: (int id) => scope.definitions.isComputed(id),
    );

    behavior.onAddRepetition(quit, LocalDate(9000));
    behavior.onToggleRepetition(quit, LocalDate(9000));
    behavior.onIncrement(quit, LocalDate(9000), 1000);

    expect(quit.originalEntries.get(LocalDate(9000)).value, Entry.unknown,
        reason: 'computed.write-paths#1');
  });

  test('and it is numerical, so the unguarded yes/no toggle cannot reach it',
      () {
    // The one door with no guard is the yes/no toggle — a ported presenter
    // whose signature is closed by parity rules. It is out of reach only
    // while every computed habit is numerical, and this is where that stops
    // being a hope (см. DEVIATIONS.md, «переключение да/нет-привычки»).
    //
    // Страховка, а не доказательство: привычку выше построил числовой сам
    // тест, и при удалённой фиче эта строка останется зелёной. Настоящая
    // проверка правила — следующим тестом.
    expect(quit.isNumerical, isTrue, reason: 'computed.write-paths#5');
  });

  test('the kinds this build can create are numerical by construction', () {
    // Тип берётся у продакшна, а не у привычки, которую тест построил себе
    // сам, — этим он и отличается от страховки выше. `sleepHabitType` есть
    // константа, которой заводится сон (`sleep/stored_value.dart:68`);
    // воздержание заводится редактором, и его тип прибит там же, в наборе
    // Задачи 29, той же цитатой.
    //
    // Длина `ComputedKind.values` закреплена намеренно: третий вычисляемый вид
    // обязан пройти этой строкой и назвать свой тип, а не проскользнуть мимо
    // правила молча.
    expect(ComputedKind.values, hasLength(2),
        reason: 'computed.write-paths#5 — третий вид обязан пройти здесь');
    expect(sleepHabitType, HabitType.numerical,
        reason: 'computed.write-paths#5');
  });

  // Хук 7. Презентер строится тем же путём, которым его строит приложение —
  // через `ShowHabitModel`, как в `computed_guard_wiring_test.dart:62`, — а не
  // собирается тестом: у него шесть обязательных сотрудников, и собранный
  // вручную доказывал бы про себя, а не про экран.
  test('randomise does nothing at all', () {
    final ShowHabitModel model =
        ShowHabitModel(scope: scope, habit: quit, theme: LightTheme());
    addTearDown(model.dispose);
    quit.originalEntries.add(Entry(LocalDate(8999), 500000));

    model.menuPresenter.onRandomize();

    expect(quit.originalEntries.get(LocalDate(8999)).value, 500000,
        reason: 'computed.lifecycle#3 — originalEntries.clear() is '
            'deleteByHabitId, and it would take the journal with it');
  });
}
