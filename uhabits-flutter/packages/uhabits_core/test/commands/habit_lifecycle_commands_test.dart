import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/create_habit_command.dart';
import 'package:uhabits_core/src/commands/delete_habits_command.dart';
import 'package:uhabits_core/src/commands/edit_habit_command.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/model_factory.dart';
import 'package:uhabits_core/src/models/model_observable.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/CreateHabitCommand.kt,
/// .../commands/EditHabitCommand.kt, .../commands/DeleteHabitsCommand.kt,
/// .../models/ModelFactory.kt, .../models/Habit.kt,
/// .../models/HabitNotFoundException.kt, .../models/memory/MemoryHabitList.kt
/// and their tests
/// (.../commonTest/.../commands/CreateHabitCommandTest.kt,
/// .../commands/EditHabitCommandTest.kt,
/// .../commands/DeleteHabitsCommandTest.kt).
///
/// Every `expect` carries the parity-ledger rule id it exercises.

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// A [MemoryModelFactory] that records every `buildHabit()` call, so that the
/// step order inside `CreateHabitCommand.run()` can be observed.
class _SpyModelFactory extends MemoryModelFactory {
  _SpyModelFactory(this.log);

  final List<String> log;

  @override
  Habit buildHabit() {
    log.add('buildHabit');
    return super.buildHabit();
  }
}

/// A [MemoryHabitList] that records the mutating calls the commands make, and
/// lets a test observe the habit exactly at the moment `add` receives it.
class _SpyHabitList extends MemoryHabitList {
  _SpyHabitList(this.log);

  final List<String> log;

  final List<List<Habit>> updateCalls = <List<Habit>>[];

  final List<Habit> removed = <Habit>[];

  /// Runs after `add` has been logged but before the real insertion.
  void Function(Habit habit)? onAdd;

  @override
  void add(Habit habit) {
    log.add('add(${habit.name})');
    onAdd?.call(habit);
    super.add(habit);
  }

  @override
  void update(List<Habit> habits) {
    log.add('update(${habits.map((h) => h.name).join(',')})');
    updateCalls.add(habits);
    super.update(habits);
  }

  @override
  void remove(Habit h) {
    log.add('remove(${h.name})');
    removed.add(h);
    super.remove(h);
  }
}

/// Records the commands the runner reports as finished.
class _RecordingCommandRunnerListener implements CommandRunnerListener {
  _RecordingCommandRunnerListener([this.onFinished]);

  final void Function(Command command)? onFinished;

  final List<Command> finished = <Command>[];

  @override
  void onCommandFinished(Command command) {
    finished.add(command);
    onFinished?.call(command);
  }
}

void main() {
  // -------------------------------------------------------------------------
  // BaseUnitTest.setUp, inlined (commands.test-harness)
  // -------------------------------------------------------------------------
  late MemoryModelFactory memoryModelFactory;
  late HabitList habitList;
  late HabitFixtures fixtures;
  late ModelFactory modelFactory;
  late TaskRunner taskRunner;
  late CommandRunner commandRunner;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    memoryModelFactory = MemoryModelFactory();
    habitList = memoryModelFactory.buildHabitList();
    fixtures = HabitFixtures(memoryModelFactory, habitList);
    modelFactory = memoryModelFactory;
    taskRunner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    commandRunner = CommandRunner(taskRunner);
  });

  tearDown(resetToday);

  // -------------------------------------------------------------------------
  // commands.create-habit
  // -------------------------------------------------------------------------
  group('commands.create-habit', () {
    late Habit model;
    late CreateHabitCommand command;

    setUp(() {
      // CreateHabitCommandTest.setUp
      model = fixtures.createEmptyHabit();
      model.name = 'New habit';
      model.reminder = Reminder(8, 30, WeekdayList.everyDay);
      command = CreateHabitCommand(modelFactory, habitList, model);
    });

    test('constructor takes modelFactory, habitList, model in that order', () {
      expect(
        command.modelFactory,
        same(modelFactory),
        reason: 'commands.create-habit#1 — the first constructor argument, '
            'and the first destructuring component, is modelFactory',
      );
      expect(
        command.habitList,
        same(habitList),
        reason: 'commands.create-habit#1 — the second constructor argument, '
            'and the second destructuring component, is habitList',
      );
      expect(
        command.model,
        same(model),
        reason: 'commands.create-habit#1 — the third constructor argument, '
            'and the third destructuring component, is model',
      );
      expect(
        command,
        isA<Command>(),
        reason: 'commands.create-habit#1 — CreateHabitCommand is a Command',
      );
    });

    test('run() does buildHabit, copyFrom, add, recompute in that order', () {
      final log = <String>[];
      final spyFactory = _SpyModelFactory(log);
      final spyList = _SpyHabitList(log);
      final spyFixtures = HabitFixtures(spyFactory, spyList);
      final template = spyFixtures.createEmptyHabit();
      template.name = 'New habit';
      log.clear();

      final today = getToday();
      var nameAtAdd = '';
      var idAtAdd = -1;
      var computedAtAdd = -99;
      spyList.onAdd = (habit) {
        nameAtAdd = habit.name;
        idAtAdd = habit.id ?? -1;
        computedAtAdd = habit.computedEntries.get(today).value;
        // Seeding an entry here makes step (4) observable: only a recompute
        // that runs after `add` can move it into computedEntries.
        habit.originalEntries.add(Entry(today, Entry.yesManual));
      };

      CreateHabitCommand(spyFactory, spyList, template).run();

      expect(
        log,
        <String>['buildHabit', 'add(New habit)'],
        reason: 'commands.create-habit#2 — run() calls exactly '
            'modelFactory.buildHabit() and then habitList.add(habit); there '
            'is no other collaborator call',
      );
      expect(
        nameAtAdd,
        'New habit',
        reason: 'commands.create-habit#2 — step (2) habit.copyFrom(model) '
            'runs before step (3) habitList.add(habit)',
      );
      expect(
        idAtAdd,
        -1,
        reason: 'commands.create-habit#2 — the habit reaching step (3) is the '
            'factory-built one, still without an id',
      );
      expect(
        computedAtAdd,
        Entry.unknown,
        reason: 'commands.create-habit#2 — step (4) habit.recompute() has not '
            'run yet when step (3) habitList.add(habit) is entered',
      );
      expect(
        spyList.getByPosition(0).computedEntries.get(today).value,
        Entry.yesManual,
        reason: 'commands.create-habit#2 — step (4) habit.recompute() runs '
            'after step (3) habitList.add(habit)',
      );
    });

    test('the stored habit is a new object; the model is only a template', () {
      command.run();
      final stored = habitList.getByPosition(0);

      expect(
        identical(stored, model),
        isFalse,
        reason: 'commands.create-habit#3 — the inserted habit is a NEW object '
            'built by the factory, not the model itself',
      );
      expect(
        habitList.any((h) => identical(h, model)),
        isFalse,
        reason: 'commands.create-habit#3 — the model argument is never itself '
            'added to the list',
      );

      model.name = 'mutated afterwards';
      model.color = const PaletteColor(19);
      expect(
        stored.name,
        'New habit',
        reason: 'commands.create-habit#3 — mutating model afterwards does not '
            'affect the stored habit',
      );
      expect(
        stored.color,
        const PaletteColor(3),
        reason: 'commands.create-habit#3 — mutating model afterwards does not '
            'affect the stored habit',
      );
    });

    test('ModelFactory.buildHabit() produces the documented defaults', () {
      final habit = modelFactory.buildHabit();

      expect(
        habit.color,
        const PaletteColor(8),
        reason: 'commands.create-habit#4 — default color is PaletteColor(8)',
      );
      expect(
        habit.description,
        '',
        reason: 'commands.create-habit#4 — default description is ""',
      );
      expect(
        habit.frequency,
        Frequency.daily,
        reason: 'commands.create-habit#4 — default frequency is DAILY',
      );
      expect(
        habit.id,
        isNull,
        reason: 'commands.create-habit#4 — default id is null',
      );
      expect(
        habit.isArchived,
        isFalse,
        reason: 'commands.create-habit#4 — default isArchived is false',
      );
      expect(
        habit.name,
        '',
        reason: 'commands.create-habit#4 — default name is ""',
      );
      expect(
        habit.position,
        0,
        reason: 'commands.create-habit#4 — default position is 0',
      );
      expect(
        habit.question,
        '',
        reason: 'commands.create-habit#4 — default question is ""',
      );
      expect(
        habit.reminder,
        isNull,
        reason: 'commands.create-habit#4 — default reminder is null',
      );
      expect(
        habit.targetType,
        NumericalHabitType.atLeast,
        reason: 'commands.create-habit#4 — default targetType is AT_LEAST',
      );
      expect(
        habit.targetValue,
        0.0,
        reason: 'commands.create-habit#4 — default targetValue is 0.0',
      );
      expect(
        habit.type,
        HabitType.yesNo,
        reason: 'commands.create-habit#4 — default type is YES_NO',
      );
      expect(
        habit.unit,
        '',
        reason: 'commands.create-habit#4 — default unit is ""',
      );
      expect(
        habit.computedEntries.getKnown(),
        isEmpty,
        reason: 'commands.create-habit#4 — buildHabit gives a fresh empty '
            'computedEntries',
      );
      expect(
        habit.originalEntries.getKnown(),
        isEmpty,
        reason: 'commands.create-habit#4 — buildHabit gives a fresh empty '
            'originalEntries',
      );
      expect(
        habit.scores[getToday()].value,
        0.0,
        reason: 'commands.create-habit#4 — buildHabit gives a fresh empty '
            'scores list',
      );
      expect(
        habit.streaks.getBest(10),
        isEmpty,
        reason: 'commands.create-habit#4 — buildHabit gives a fresh empty '
            'streaks list',
      );
      expect(
        habit.uuid,
        matches(RegExp(r'^[0-9a-f]{32}$')),
        reason: 'commands.create-habit#4 — the Habit init block replaces a '
            'null uuid with Uuid.random().toHexString(), 32 lowercase hex '
            'characters',
      );

      final second = modelFactory.buildHabit();
      expect(
        identical(second.originalEntries, habit.originalEntries),
        isFalse,
        reason: 'commands.create-habit#4 — every buildHabit() call gets its '
            'own collaborators',
      );
      expect(
        second.uuid,
        isNot(habit.uuid),
        reason: 'commands.create-habit#4 — each generated uuid is random',
      );
    });

    test('Habit.copyFrom copies the model fields but not id or entries', () {
      final today = getToday();
      final source = modelFactory.buildHabit();
      source.color = const PaletteColor(15);
      source.description = 'a description';
      source.frequency = Frequency(3, 7);
      source.id = 99;
      source.isArchived = true;
      source.name = 'source';
      source.position = 7;
      source.question = 'a question?';
      source.reminder = Reminder(8, 30, WeekdayList.everyDay);
      source.targetType = NumericalHabitType.atMost;
      source.targetValue = 12.5;
      source.type = HabitType.numerical;
      source.unit = 'km';
      source.uuid = 'a' * 32;

      final target = modelFactory.buildHabit();
      target.id = 42;
      target.copyFrom(source);

      expect(target.color, const PaletteColor(15),
          reason: 'commands.create-habit#5 — copyFrom copies color');
      expect(target.description, 'a description',
          reason: 'commands.create-habit#5 — copyFrom copies description');
      expect(target.frequency, Frequency(3, 7),
          reason: 'commands.create-habit#5 — copyFrom copies frequency');
      expect(target.isArchived, isTrue,
          reason: 'commands.create-habit#5 — copyFrom copies isArchived');
      expect(target.name, 'source',
          reason: 'commands.create-habit#5 — copyFrom copies name');
      expect(target.position, 7,
          reason: 'commands.create-habit#5 — copyFrom copies position');
      expect(target.question, 'a question?',
          reason: 'commands.create-habit#5 — copyFrom copies question');
      expect(target.reminder, Reminder(8, 30, WeekdayList.everyDay),
          reason: 'commands.create-habit#5 — copyFrom copies reminder');
      expect(target.targetType, NumericalHabitType.atMost,
          reason: 'commands.create-habit#5 — copyFrom copies targetType');
      expect(target.targetValue, 12.5,
          reason: 'commands.create-habit#5 — copyFrom copies targetValue');
      expect(target.type, HabitType.numerical,
          reason: 'commands.create-habit#5 — copyFrom copies type');
      expect(target.unit, 'km',
          reason: 'commands.create-habit#5 — copyFrom copies unit');
      expect(target.uuid, 'a' * 32,
          reason: 'commands.create-habit#5 — copyFrom copies uuid');
      expect(
        target.id,
        42,
        reason: 'commands.create-habit#5 — copyFrom explicitly does NOT copy '
            'id',
      );

      // Entries, scores and streaks are not copied either.
      final scored = fixtures.createShortHabit();
      expect(
        scored.scores[today].value,
        greaterThan(0.0),
        reason: 'commands.create-habit#5 — precondition: the fixture has a '
            'non-zero score to not copy',
      );
      final target2 = modelFactory.buildHabit();
      target2.copyFrom(scored);
      expect(
        target2.originalEntries.getKnown(),
        isEmpty,
        reason: 'commands.create-habit#5 — copyFrom copies no entries',
      );
      expect(
        target2.computedEntries.getKnown(),
        isEmpty,
        reason: 'commands.create-habit#5 — copyFrom copies no entries',
      );
      expect(
        target2.scores[today].value,
        0.0,
        reason: 'commands.create-habit#5 — copyFrom copies no scores',
      );
      expect(
        target2.streaks.getBest(10),
        isEmpty,
        reason: 'commands.create-habit#5 — copyFrom copies no streaks',
      );
    });

    test('the created habit inherits the template uuid, null included', () {
      model.uuid = 'b' * 32;
      command.run();
      expect(
        habitList.getByPosition(0).uuid,
        'b' * 32,
        reason: 'commands.create-habit#6 — because copyFrom copies uuid, the '
            'created habit inherits the template uuid, which is how the '
            'importer preserves identity across imports',
      );

      final nullUuidList = memoryModelFactory.buildHabitList();
      final nullUuidModel = modelFactory.buildHabit();
      nullUuidModel.name = 'no uuid';
      nullUuidModel.uuid = null;
      CreateHabitCommand(modelFactory, nullUuidList, nullUuidModel).run();
      expect(
        nullUuidList.getByPosition(0).uuid,
        isNull,
        reason: 'commands.create-habit#6 — the factory-generated random uuid '
            'is overwritten by null when model.uuid is null; in practice '
            'callers pass a factory-built habit, so uuid is always non-null',
      );
    });

    test('entries on the model are not imported', () {
      final today = getToday();
      final template = fixtures.createShortHabit();
      template.name = 'has entries';
      expect(
        template.originalEntries.getKnown(),
        isNotEmpty,
        reason: 'commands.create-habit#7 — precondition: the template carries '
            'entries',
      );

      CreateHabitCommand(modelFactory, habitList, template).run();
      final stored = habitList.getByPosition(0);

      expect(
        stored.originalEntries.getKnown(),
        isEmpty,
        reason: 'commands.create-habit#7 — the created habit\'s '
            'originalEntries is empty; callers that need entries '
            '(LoopDBImporter) add them afterwards',
      );
      expect(
        stored.computedEntries.get(today).value,
        Entry.unknown,
        reason: 'commands.create-habit#7 — with no original entries there is '
            'nothing to compute',
      );
      expect(
        template.originalEntries.getKnown(),
        isNotEmpty,
        reason: 'commands.create-habit#7 — the template keeps its own entries',
      );
    });

    test('MemoryHabitList.add assigns ids, rejects duplicates and resorts', () {
      var notified = 0;
      final list = MemoryHabitList();
      list.observable.addListener(ModelObservableListener(() => notified++));

      final b = fixtures.createEmptyHabit(name: 'b');
      final a = fixtures.createEmptyHabit(name: 'a');
      list.add(b);
      expect(
        b.id,
        0,
        reason: 'commands.create-habit#8 — a null id is assigned '
            'list.size.toLong()',
      );
      list.add(a);
      expect(
        a.id,
        1,
        reason: 'commands.create-habit#8 — a null id is assigned '
            'list.size.toLong()',
      );
      expect(
        notified,
        2,
        reason: 'commands.create-habit#8 — add() ends in resort(), which '
            'fires the list observable',
      );
      expect(
        list.getByPosition(0).name,
        'a',
        reason: 'commands.create-habit#8 — add() ends in resort(), which '
            'sorts the list',
      );

      expect(
        () => list.add(b),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains('habit already added'),
          ),
        ),
        reason: 'commands.create-habit#8 — adding a habit the list already '
            'contains throws IllegalArgumentException("habit already added")',
      );

      final duplicate = fixtures.createEmptyHabit(name: 'c');
      duplicate.id = 0;
      expect(
        () => list.add(duplicate),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('duplicate id'),
          ),
        ),
        reason: 'commands.create-habit#8 — a non-null id already present in '
            'the list throws RuntimeException("duplicate id")',
      );
    });

    test('run() grows the list by one and stores the model name', () {
      // CreateHabitCommandTest.testExecute
      expect(
        habitList.isEmpty,
        isTrue,
        reason: 'commands.create-habit#10 — precondition: the list starts '
            'empty',
      );
      command.run();
      expect(
        habitList.size(),
        1,
        reason: 'commands.create-habit#10 — after run() the list has grown by '
            'exactly 1',
      );
      expect(
        habitList.getByPosition(0).name,
        model.name,
        reason: 'commands.create-habit#10 — the habit at position 0 carries '
            'the model name',
      );
    });

    test('recompute runs after insertion, before any listener is notified',
        () {
      final today = getToday();
      final log = <String>[];
      final spyList = _SpyHabitList(log);
      spyList.onAdd = (habit) {
        habit.originalEntries.add(Entry(today, Entry.yesManual));
      };
      final seeded = CreateHabitCommand(modelFactory, spyList, model);

      var computedAtNotify = -99;
      commandRunner.addListener(
        _RecordingCommandRunnerListener((_) {
          computedAtNotify = spyList.getByPosition(0).computedEntries
              .get(today)
              .value;
        }),
      );
      commandRunner.run(seeded);

      expect(
        computedAtNotify,
        Entry.yesManual,
        reason: 'commands.create-habit#11 — habit.recompute() runs after '
            'insertion and before any listener is notified',
      );

      // A habit with no entries still ends up with scores and streaks, all
      // zero.
      final plainListener = _RecordingCommandRunnerListener();
      commandRunner.addListener(plainListener);
      commandRunner.run(command);
      final stored = habitList.getByPosition(0);
      expect(
        plainListener.finished, hasLength(1),
        reason: 'commands.create-habit#11 — the listener is notified after '
            'the command has finished',
      );
      expect(
        stored.scores[today].value,
        0.0,
        reason: 'commands.create-habit#11 — scores exist and are zero for a '
            'habit with no entries',
      );
      expect(
        stored.streaks.getBest(10),
        isEmpty,
        reason: 'commands.create-habit#11 — streaks exist and are empty for a '
            'habit with no entries',
      );
    });
  });

  // -------------------------------------------------------------------------
  // commands.edit-habit
  // -------------------------------------------------------------------------
  group('commands.edit-habit', () {
    late Habit habit;
    late Habit modified;
    late LocalDate today;

    setUp(() {
      // EditHabitCommandTest.setUp
      habit = fixtures.createShortHabit();
      habit.name = 'original';
      habit.frequency = Frequency.daily;
      habit.recompute();
      habitList.add(habit);
      modified = fixtures.createEmptyHabit();
      modified.copyFrom(habit);
      modified.name = 'modified';
      habitList.add(modified);
      today = getToday();
    });

    test('constructor takes habitList, habitId, modified in that order', () {
      final command = EditHabitCommand(habitList, habit.id!, modified);
      expect(
        command.habitList,
        same(habitList),
        reason: 'commands.edit-habit#1 — the first constructor argument, and '
            'the first destructuring component, is habitList',
      );
      expect(
        command.habitId,
        habit.id,
        reason: 'commands.edit-habit#1 — the second constructor argument, and '
            'the second destructuring component, is habitId',
      );
      expect(
        command.modified,
        same(modified),
        reason: 'commands.edit-habit#1 — the third constructor argument, and '
            'the third destructuring component, is modified',
      );
      expect(
        command,
        isA<Command>(),
        reason: 'commands.edit-habit#1 — EditHabitCommand is a Command',
      );
    });

    test('run() performs its steps in order', () {
      final log = <String>[];
      final spyList = _SpyHabitList(log);
      final spyFixtures = HabitFixtures(memoryModelFactory, spyList);
      final target = spyFixtures.createShortHabit();
      target.name = 'original';
      target.frequency = Frequency.daily;
      target.recompute();
      spyList.add(target);

      final replacement = spyFixtures.createEmptyHabit();
      replacement.copyFrom(target);
      replacement.name = 'modified';
      replacement.frequency = Frequency(2, 3);

      log.clear();
      spyList.observable.addListener(
        ModelObservableListener(
          () => log.add('list:${target.scores[today].value}'),
        ),
      );
      target.observable.addListener(
        ModelObservableListener(
          () => log.add('habit:${target.scores[today].value}'),
        ),
      );

      final oldScore = target.scores[today].value;
      EditHabitCommand(spyList, target.id!, replacement).run();
      final newScore = target.scores[today].value;

      expect(
        newScore,
        isNot(oldScore),
        reason: 'commands.edit-habit#2 — precondition: the frequency change '
            'moves the score, so the two notification snapshots differ',
      );
      expect(
        log,
        <String>[
          'update(modified)',
          'list:$oldScore',
          'habit:$oldScore',
          'list:$newScore',
        ],
        reason: 'commands.edit-habit#2 — run() does getById, copyFrom, '
            'habitList.update, habit.observable.notifyListeners, recompute '
            'and habitList.resort, in that order, and nothing else',
      );
      expect(
        target.name,
        'modified',
        reason: 'commands.edit-habit#2 — step (3) habit.copyFrom(modified) '
            'ran before step (4) habitList.update(habit)',
      );

      final missing = EditHabitCommand(habitList, 987654, modified);
      expect(
        missing.run,
        throwsA(isA<HabitNotFoundException>()),
        reason: 'commands.edit-habit#2 — step (2): a null getById result '
            'throws HabitNotFoundException',
      );
      expect(
        HabitNotFoundException().toString(),
        'HabitNotFoundException',
        reason: 'commands.edit-habit#2 — HabitNotFoundException carries no '
            'message',
      );
    });

    test('the existing instance is edited in place', () {
      final sizeBefore = habitList.size();
      EditHabitCommand(habitList, habit.id!, modified).run();

      expect(
        habitList.size(),
        sizeBefore,
        reason: 'commands.edit-habit#3 — the modified habit is never inserted '
            'into the list',
      );
      expect(
        identical(habitList.getById(habit.id!), habit),
        isTrue,
        reason: 'commands.edit-habit#3 — the command edits the EXISTING habit '
            'instance in place',
      );
      expect(
        habit.name,
        'modified',
        reason: 'commands.edit-habit#3 — the modified habit is only a value '
            'carrier',
      );
    });

    test('id survives the edit; position and uuid are overwritten', () {
      final originalId = habit.id;
      final originalPosition = habit.position;
      final originalUuid = habit.uuid;

      // The fixture pattern: modified.copyFrom(original) first, so a plain
      // rename round-trips position and uuid unchanged.
      EditHabitCommand(habitList, habit.id!, modified).run();
      expect(
        habit.id,
        originalId,
        reason: 'commands.edit-habit#4 — copyFrom does not copy id, so the '
            'edited habit keeps its original id',
      );
      expect(
        habit.position,
        originalPosition,
        reason: 'commands.edit-habit#4 — callers build modified by first '
            'doing modified.copyFrom(original), so position round-trips',
      );
      expect(
        habit.uuid,
        originalUuid,
        reason: 'commands.edit-habit#4 — callers build modified by first '
            'doing modified.copyFrom(original), so uuid round-trips',
      );

      // Without that discipline, whatever the carrier holds wins.
      modified.position = 42;
      modified.uuid = 'f' * 32;
      EditHabitCommand(habitList, habit.id!, modified).run();
      expect(
        habit.position,
        42,
        reason: 'commands.edit-habit#4 — copyFrom DOES copy position, so the '
            'carrier overwrites the stored one',
      );
      expect(
        habit.uuid,
        'f' * 32,
        reason: 'commands.edit-habit#4 — copyFrom DOES copy uuid, so the '
            'carrier overwrites the stored one',
      );
      expect(
        habit.id,
        originalId,
        reason: 'commands.edit-habit#4 — the id is still not copied',
      );
    });

    test('renaming leaves the entries and the score untouched', () {
      // EditHabitCommandTest.testExecute
      final command = EditHabitCommand(habitList, habit.id!, modified);
      final originalScore = habit.scores[today].value;
      final originalEntries = habit.originalEntries.getKnown();

      expect(
        habit.name,
        'original',
        reason: 'commands.edit-habit#5 — precondition: the habit starts named '
            '"original"',
      );
      command.run();
      expect(
        habit.name,
        'modified',
        reason: 'commands.edit-habit#5 — the rename lands',
      );
      expect(
        habit.scores[today].value,
        originalScore,
        reason: 'commands.edit-habit#5 — renaming a habit whose frequency is '
            'unchanged leaves scores[today].value unchanged',
      );
      expect(
        habit.originalEntries.getKnown(),
        originalEntries,
        reason: 'commands.edit-habit#5 — entries are untouched: '
            'originalEntries survive the edit',
      );
    });

    test('frequency, type, targetType and targetValue take effect', () {
      final entries = habit.originalEntries.getKnown();
      final reference = modelFactory.buildHabit();
      for (final entry in entries) {
        reference.originalEntries.add(entry);
      }
      reference.frequency = Frequency(1, 7);
      reference.recompute();

      final beforeScore = habit.scores[today].value;
      modified.frequency = Frequency(1, 7);
      EditHabitCommand(habitList, habit.id!, modified).run();

      expect(
        habit.frequency,
        Frequency(1, 7),
        reason: 'commands.edit-habit#6 — the frequency change lands',
      );
      expect(
        habit.computedEntries.getByInterval(today.minus(20), today),
        reference.computedEntries.getByInterval(today.minus(20), today),
        reason: 'commands.edit-habit#6 — recompute() rebuilds computedEntries '
            'from originalEntries under the new frequency',
      );
      expect(
        habit.scores[today].value,
        reference.scores[today].value,
        reason: 'commands.edit-habit#6 — recompute() then recomputes the '
            'scores',
      );
      expect(
        habit.scores[today].value,
        isNot(beforeScore),
        reason: 'commands.edit-habit#6 — the frequency change actually moves '
            'the score, which only step (6) can do',
      );
      expect(
        habit.streaks.getBest(10).length,
        reference.streaks.getBest(10).length,
        reason: 'commands.edit-habit#6 — recompute() then recomputes the '
            'streaks',
      );

      modified.type = HabitType.numerical;
      modified.targetType = NumericalHabitType.atMost;
      modified.targetValue = 1.0;
      EditHabitCommand(habitList, habit.id!, modified).run();
      expect(
        habit.type,
        HabitType.numerical,
        reason: 'commands.edit-habit#6 — the type change lands',
      );
      expect(
        habit.targetType,
        NumericalHabitType.atMost,
        reason: 'commands.edit-habit#6 — the targetType change lands',
      );
      expect(
        habit.targetValue,
        1.0,
        reason: 'commands.edit-habit#6 — the targetValue change lands',
      );
    });

    test('the habit observable fires before recompute, resort after', () {
      final log = <String>[];
      final spyList = _SpyHabitList(log);
      final spyFixtures = HabitFixtures(memoryModelFactory, spyList);
      final target = spyFixtures.createShortHabit();
      target.name = 'original';
      target.frequency = Frequency.daily;
      target.recompute();
      spyList.add(target);

      final replacement = spyFixtures.createEmptyHabit();
      replacement.copyFrom(target);
      replacement.frequency = Frequency(2, 3);

      log.clear();
      spyList.observable.addListener(
        ModelObservableListener(
          () => log.add('list:${target.scores[today].value}'),
        ),
      );
      target.observable.addListener(
        ModelObservableListener(
          () => log.add('habit:${target.scores[today].value}'),
        ),
      );

      final oldScore = target.scores[today].value;
      EditHabitCommand(spyList, target.id!, replacement).run();
      final newScore = target.scores[today].value;

      expect(
        newScore,
        isNot(oldScore),
        reason: 'commands.edit-habit#7 — precondition: recompute moves the '
            'score, so the two notification snapshots are distinguishable',
      );
      expect(
        log,
        contains('habit:$oldScore'),
        reason: 'commands.edit-habit#7 — the habit ModelObservable is '
            'notified BEFORE recompute, so it still sees the old score',
      );
      expect(
        log.indexOf('habit:$oldScore'),
        lessThan(log.lastIndexOf('list:$newScore')),
        reason: 'commands.edit-habit#7 — the habit ModelObservable fires '
            'before the list is re-sorted',
      );
      expect(
        log.last,
        'list:$newScore',
        reason: 'commands.edit-habit#7 — the list is re-sorted AFTER '
            'recompute, so the sort sees the fresh scores',
      );

      // The same fact stated through a score-based ordering: editing a habit
      // so that its score crosses another habit's reorders the list.
      final scoreList = memoryModelFactory.buildHabitList();
      final scoreFixtures = HabitFixtures(memoryModelFactory, scoreList);
      final low = scoreFixtures.createEmptyHabit(name: 'low');
      low.frequency = Frequency(2, 7);
      low.originalEntries.add(Entry(today, Entry.yesManual));
      low.recompute();
      final high = scoreFixtures.createEmptyHabit(name: 'high');
      high.frequency = Frequency(1, 7);
      high.originalEntries.add(Entry(today, Entry.yesManual));
      high.recompute();
      scoreList.add(low);
      scoreList.add(high);
      scoreList.primaryOrder = HabitListOrder.byScoreDesc;

      expect(
        low.scores[today].value,
        lessThan(high.scores[today].value),
        reason: 'commands.edit-habit#7 — precondition: "low" starts below '
            '"high"',
      );
      final orderedBefore = scoreList.indexOf(low) < scoreList.indexOf(high);

      final carrier = scoreFixtures.createEmptyHabit(name: 'low');
      carrier.copyFrom(low);
      carrier.frequency = Frequency.daily;
      EditHabitCommand(scoreList, low.id!, carrier).run();

      expect(
        low.scores[today].value,
        greaterThan(high.scores[today].value),
        reason: 'commands.edit-habit#7 — precondition: after the edit "low" '
            'outscores "high"',
      );
      expect(
        scoreList.indexOf(low) < scoreList.indexOf(high),
        isNot(orderedBefore),
        reason: 'commands.edit-habit#7 — BY_SCORE orderings see the fresh '
            'scores, because resort runs after recompute',
      );
    });

    test('update(habit) delegates to update(listOf(habit))', () {
      final log = <String>[];
      final spyList = _SpyHabitList(log);
      final spyFixtures = HabitFixtures(memoryModelFactory, spyList);
      final target = spyFixtures.createShortHabit();
      target.name = 'original';
      spyList.add(target);
      final replacement = spyFixtures.createEmptyHabit();
      replacement.copyFrom(target);
      replacement.name = 'modified';

      var notifications = 0;
      spyList.observable
          .addListener(ModelObservableListener(() => notifications++));

      EditHabitCommand(spyList, target.id!, replacement).run();

      expect(
        spyList.updateCalls,
        hasLength(1),
        reason: 'commands.edit-habit#8 — run() calls habitList.update exactly '
            'once',
      );
      expect(
        spyList.updateCalls.single,
        hasLength(1),
        reason: 'commands.edit-habit#8 — update(habit) delegates to '
            'update(listOf(habit))',
      );
      expect(
        identical(spyList.updateCalls.single.single, target),
        isTrue,
        reason: 'commands.edit-habit#8 — the single element of that list is '
            'the stored habit',
      );
      expect(
        notifications,
        2,
        reason: 'commands.edit-habit#8 — a single EditHabitCommand fires the '
            'list observable more than once (update-resort and the final '
            'resort); MemoryHabitList has no inner observable, so the memory '
            'port fires twice where SQLiteHabitList fires three times',
      );
    });

    test('HabitNotFoundException stops the runner before onPostExecute', () {
      final listener = _RecordingCommandRunnerListener();
      commandRunner.addListener(listener);
      final command = EditHabitCommand(habitList, 987654, modified);

      expect(
        () => commandRunner.run(command),
        throwsA(isA<HabitNotFoundException>()),
        reason: 'commands.edit-habit#9 — the exception escapes the coroutine',
      );
      expect(
        listener.finished,
        isEmpty,
        reason: 'commands.edit-habit#9 — CommandRunner never reaches '
            'onPostExecute, so no listener is notified and no toast is shown',
      );
    });
  });

  // -------------------------------------------------------------------------
  // commands.delete-habits
  // -------------------------------------------------------------------------
  group('commands.delete-habits', () {
    late List<Habit> selected;
    late Habit extra;
    late DeleteHabitsCommand command;

    setUp(() {
      // DeleteHabitsCommandTest.setUp
      selected = <Habit>[];
      for (var i = 0; i < 3; i++) {
        final habit = fixtures.createShortHabit();
        habitList.add(habit);
        selected.add(habit);
      }
      extra = fixtures.createShortHabit();
      extra.name = 'extra';
      habitList.add(extra);
      command = DeleteHabitsCommand(habitList, selected);
    });

    test('constructor takes habitList, selected in that order', () {
      expect(
        command.habitList,
        same(habitList),
        reason: 'commands.delete-habits#1 — the first constructor argument, '
            'and the first destructuring component, is habitList',
      );
      expect(
        command.selected,
        same(selected),
        reason: 'commands.delete-habits#1 — the second constructor argument, '
            'and the second destructuring component, is selected',
      );
      expect(
        command,
        isA<Command>(),
        reason: 'commands.delete-habits#1 — DeleteHabitsCommand is a Command',
      );
    });

    test('run() removes one habit at a time, in the given order', () {
      final log = <String>[];
      final spyList = _SpyHabitList(log);
      final spyFixtures = HabitFixtures(memoryModelFactory, spyList);
      final chosen = <Habit>[];
      for (var i = 0; i < 3; i++) {
        final habit = spyFixtures.createEmptyHabit(name: 's$i');
        spyList.add(habit);
        chosen.add(habit);
      }
      log.clear();

      DeleteHabitsCommand(spyList, chosen).run();

      expect(
        log,
        <String>['remove(s0)', 'remove(s1)', 'remove(s2)'],
        reason: 'commands.delete-habits#2 — run() is exactly '
            '`for (h in selected) habitList.remove(h)`: one removal call per '
            'selected habit, in the order the list was given',
      );
      expect(
        spyList.updateCalls,
        isEmpty,
        reason: 'commands.delete-habits#2 — there is no batching and no '
            'transaction',
      );
      expect(
        spyList.removed.map(identityHashCode).toList(),
        chosen.map(identityHashCode).toList(),
        reason: 'commands.delete-habits#2 — the very habits handed in are the '
            'ones removed',
      );
    });

    test('deletion is permanent', () {
      final ids = selected.map((h) => h.id!).toList();
      command.run();

      for (final id in ids) {
        expect(
          habitList.getById(id),
          isNull,
          reason: 'commands.delete-habits#3 — deletion is permanent: the '
              'habit cannot be found again',
        );
      }
      for (final habit in selected) {
        expect(
          habitList.any((h) => identical(h, habit)),
          isFalse,
          reason: 'commands.delete-habits#3 — no copy of the habit is '
              'retained in the list',
        );
      }
      // Re-running is not an undo: there is no undo() on Command at all.
      command.run();
      expect(
        habitList.size(),
        1,
        reason: 'commands.delete-habits#3 — nothing can restore a deleted '
            'habit',
      );
    });

    test('MemoryHabitList.remove notifies but does not renumber positions', () {
      for (var i = 0; i < selected.length; i++) {
        selected[i].position = i;
      }
      extra.position = 3;
      habitList.resort();

      var notified = 0;
      habitList.observable.addListener(ModelObservableListener(() {
        notified++;
      }));

      command.run();

      expect(
        notified,
        3,
        reason: 'commands.delete-habits#4 — MemoryHabitList.remove fires the '
            'list observable once per removal',
      );
      expect(
        habitList.size(),
        1,
        reason: 'commands.delete-habits#4 — the habits are gone from the '
            'backing list',
      );
      expect(
        extra.position,
        3,
        reason: 'commands.delete-habits#4 — MemoryHabitList.remove does NOT '
            'renumber the position of the remaining habits',
      );
    });

    test('removing a habit that is not in the list is a silent no-op', () {
      final stranger = fixtures.createEmptyHabit(name: 'stranger');
      stranger.id = 999;

      var notified = 0;
      habitList.observable.addListener(ModelObservableListener(() {
        notified++;
      }));

      DeleteHabitsCommand(habitList, <Habit>[stranger]).run();

      expect(
        habitList.size(),
        4,
        reason: 'commands.delete-habits#6 — removing a habit that is not in '
            'the list is a silent no-op for MemoryHabitList',
      );
      expect(
        notified,
        1,
        reason: 'commands.delete-habits#6 — MemoryHabitList still fires the '
            'observable for the no-op removal',
      );
    });

    test('deleting 3 of 4 habits leaves "extra" at position 0', () {
      // DeleteHabitsCommandTest.testExecute
      expect(
        habitList.size(),
        4,
        reason: 'commands.delete-habits#7 — precondition: four habits',
      );
      command.run();
      expect(
        habitList.size(),
        1,
        reason: 'commands.delete-habits#7 — deleting 3 of 4 habits leaves '
            'size() == 1',
      );
      expect(
        habitList.getByPosition(0).name,
        'extra',
        reason: 'commands.delete-habits#7 — the survivor is the habit named '
            '"extra", at position 0',
      );
    });

    test('an empty selection is a no-op but still notifies listeners', () {
      final empty = DeleteHabitsCommand(habitList, <Habit>[]);
      final listener = _RecordingCommandRunnerListener();
      commandRunner.addListener(listener);

      var notified = 0;
      habitList.observable.addListener(ModelObservableListener(() {
        notified++;
      }));

      commandRunner.run(empty);

      expect(
        habitList.size(),
        4,
        reason: 'commands.delete-habits#8 — an empty selected list makes '
            'run() a complete no-op',
      );
      expect(
        notified,
        0,
        reason: 'commands.delete-habits#8 — a complete no-op touches the list '
            'not at all',
      );
      expect(
        listener.finished,
        <Command>[empty],
        reason: 'commands.delete-habits#8 — CommandRunner still notifies all '
            'listeners afterwards',
      );
    });
  });
}
