/// A file written by the shipped build — schema 102 — opens under 103.
///
/// The schema itself is checked in memory by
/// `extension_migrations_test.dart`. What is not checked there is the one
/// thing that matters on a real phone: that `AppDatabase.openAndMigrate`
/// carries such a file forward without routing it into the
/// `<path>.invalid` quarantine and without losing anything already in it.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('uhabits_upgrade_102_103');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('a real file written by the shipped build opens and keeps everything',
      () {
    final String path = '${tempDir.path}/habits.db';
    // A file of exactly the shipped build: schema 102, a habit, a sleep
    // definition, and a day's entry. Built the same way
    // `AppDatabase.openAndMigrate` builds a brand-new file — an empty file is
    // a valid empty SQLite database — because there is no
    // `Sqlite3Database.open` that both creates and opens one.
    File(path).createSync(recursive: true);
    final Database old = const Sqlite3DatabaseOpener().open(path);
    old.setVersion(8);
    old.migrateTo(102, (int v) => migrationSqlFor(v) ?? '');
    old.run("insert into Habits (id, name, uuid) values (1, 'Sleep', 'u1')");
    old.run("insert into HabitDefinitions (habit, kind, payload) "
        "values (1, 'sleep', '{}')");
    old.run('insert into Repetitions (habit, timestamp, value) '
        'values (1, 1451606400000, 500000)');
    old.close();

    final Database upgraded = AppDatabase.openAndMigrate(path);
    addTearDown(upgraded.close);

    expect(upgraded.getVersion(), greaterThanOrEqualTo(103), reason: 'computed.schema#4');
    expect(upgraded.queryInt('select count(*) from Habits'), 1,
        reason: 'computed.schema#4 — подъём версии не карантинит файл');
    expect(upgraded.queryInt('select count(*) from HabitDefinitions'), 1,
        reason: 'computed.schema#4');
    expect(upgraded.queryInt('select count(*) from Lapses'), 0,
        reason: 'computed.schema#4 — журнал приезжает пустым');
    expect(File('$path.invalid').existsSync(), isFalse,
        reason: 'computed.schema#4 — карантин есть цена отката, а не '
            'обновления');
  });
}
