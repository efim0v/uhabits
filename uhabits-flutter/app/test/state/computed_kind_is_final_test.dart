/// `computed.definition#10` — вычисляемость задаётся при создании и не снимается.
///
/// Это не договорённость, а наблюдение о коде: пути «обычная → вычисляемая» на
/// существующей привычке нет, и пути обратно нет тоже — `remove` в репозитории
/// определений не зовёт никто, кроме собственного теста. Наблюдение живёт ровно
/// до первого коммита, который его нарушит, поэтому оно здесь и механическое.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Dart file the application and the core actually ship.
Iterable<File> shippedSources() sync* {
  for (final String root in <String>[
    'lib',
    '../packages/uhabits_core/lib',
  ]) {
    final Directory directory = Directory(root);
    if (!directory.existsSync()) continue;
    for (final FileSystemEntity entity
        in directory.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) yield entity;
    }
  }
}

/// Снятие метки — по имени вызывающего выражения, а не по буквальной цепочке
/// `scope.definitions.remove(`.
///
/// `final definitions = scope.definitions;\ndefinitions.remove(id);` — тот же
/// путь на двух строках, и поиск по одной только строке `definitions.remove(`
/// в исходнике целиком его бы тоже нашёл, но лишь потому, что имя случайно
/// совпало; регулярка ловит его надёжнее — по тому, что стоит слева от точки:
/// любое имя, оканчивающееся на `definition`/`definitions`/
/// `definitionRepository`, и заодно прямой `delete from HabitDefinitions`.
/// Имя, не несущее этого слова (`final r = ...; r.remove(id);`), мимо неё
/// проходит — это её граница, а не её обещание.
final RegExp takesTheMarkOff = RegExp(
  r'[Dd]efinition[sR]?[A-Za-z]*\s*\.\s*remove\s*\(|'
  r'delete\s+from\s+HabitDefinitions',
);

void main() {
  test('the search would find the call if it were there', () {
    // Иначе регулярка, сломанная опечаткой, даёт вечнозелёный тест: он ищет
    // то, чего не может найти, и всегда доволен.
    expect(
        takesTheMarkOff.hasMatch(
            'final definitions = scope.definitions;\ndefinitions.remove(1);'),
        isTrue,
        reason: 'computed.definition#10');
    expect(takesTheMarkOff.hasMatch('definitionRepository.remove(id);'), isTrue,
        reason: 'computed.definition#10');
    expect(takesTheMarkOff.hasMatch("db.run('delete from HabitDefinitions');"),
        isTrue,
        reason: 'computed.definition#10');
    expect(takesTheMarkOff.hasMatch('habitList.remove(habit);'), isFalse,
        reason: 'computed.definition#10 — удаление привычки меткой не '
            'является');
  });

  test('nothing that ships takes the mark off a habit', () {
    final List<String> callers = <String>[];
    for (final File file in shippedSources()) {
      final String source = file.readAsStringSync();
      // The declaration itself is not a call site.
      if (file.path.endsWith('computed/definition_repository.dart')) continue;
      if (takesTheMarkOff.hasMatch(source)) callers.add(file.path);
    }

    expect(callers, isEmpty,
        reason: 'computed.definition#10 — если появился путь, снимающий метку, '
            'запись отклонения «вид привычки после создания не меняется» '
            'больше не верна и должна быть переписана вместе с ним');
  });
}
