// Reports how much of the parity ledger is actually asserted by Dart tests.
//
// Every behavior rule in docs/parity/FEATURES.md carries a stable id such as
// `models.entry-values#4`. Tests cite that id in their `reason:` argument. This
// tool cross-references the two, so "did we bring the whole feature over" is a
// question with a mechanical answer instead of an opinion.
//
// Usage:
//   dart tool/parity_coverage.dart              # summary
//   dart tool/parity_coverage.dart --uncited    # list uncited rules
//   dart tool/parity_coverage.dart --verify     # exit 1 if a checked feature has uncited rules
import 'dart:io';

final _featureLine = RegExp(r'^- \[( |x)\] `([a-zA-Z0-9._-]+)`');
final _ruleLine = RegExp(r'^\d+\. `([a-zA-Z0-9._-]+#\d+)`');
final _citation = RegExp(r'[a-zA-Z0-9._-]+#\d+');

void main(List<String> args) {
  final repoRoot = Directory.current.path.endsWith('uhabits-flutter')
      ? Directory.current.parent.path
      : Directory.current.path;
  final ledgerFile = File('$repoRoot/docs/parity/FEATURES.md');
  if (!ledgerFile.existsSync()) {
    stderr.writeln('Parity ledger not found at ${ledgerFile.path}');
    exit(2);
  }

  final rulesByFeature = <String, List<String>>{};
  final checkedFeatures = <String>{};
  String? currentFeature;

  for (final line in ledgerFile.readAsLinesSync()) {
    final featureMatch = _featureLine.firstMatch(line);
    if (featureMatch != null) {
      currentFeature = featureMatch.group(2)!;
      rulesByFeature.putIfAbsent(currentFeature, () => <String>[]);
      if (featureMatch.group(1) == 'x') checkedFeatures.add(currentFeature);
      continue;
    }
    final ruleMatch = _ruleLine.firstMatch(line);
    if (ruleMatch != null && currentFeature != null) {
      rulesByFeature[currentFeature]!.add(ruleMatch.group(1)!);
    }
  }

  final cited = <String>{};
  for (final dir in ['packages/uhabits_core/test', 'app/test', 'app/integration_test']) {
    final directory = Directory('$repoRoot/uhabits-flutter/$dir');
    if (!directory.existsSync()) continue;
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final match in _citation.allMatches(entity.readAsStringSync())) {
        cited.add(match.group(0)!);
      }
    }
  }

  final allRules = rulesByFeature.values.expand((r) => r).toSet();
  final citedRules = cited.intersection(allRules);
  final uncited = allRules.difference(cited);

  final brokenPromises = <String, List<String>>{};
  for (final feature in checkedFeatures) {
    final missing =
        rulesByFeature[feature]!.where((r) => !cited.contains(r)).toList();
    if (missing.isNotEmpty) brokenPromises[feature] = missing;
  }

  final featuresFullyCited = rulesByFeature.entries
      .where((e) => e.value.isNotEmpty && e.value.every(cited.contains))
      .length;

  stdout.writeln('Parity coverage');
  stdout.writeln('  features:            ${rulesByFeature.length}');
  stdout.writeln('  features checked:    ${checkedFeatures.length}');
  stdout.writeln('  features fully cited:$featuresFullyCited');
  stdout.writeln('  rules:               ${allRules.length}');
  stdout.writeln('  rules cited by tests:${citedRules.length}');
  stdout.writeln('  rules uncited:       ${uncited.length}');

  if (args.contains('--uncited')) {
    for (final entry in rulesByFeature.entries) {
      final missing = entry.value.where((r) => !cited.contains(r)).toList();
      if (missing.isEmpty) continue;
      stdout.writeln('\n${entry.key} (${missing.length}/${entry.value.length} uncited)');
      for (final rule in missing) {
        stdout.writeln('  $rule');
      }
    }
  }

  if (brokenPromises.isNotEmpty) {
    stdout.writeln('\nChecked features with uncited rules:');
    brokenPromises.forEach((feature, missing) {
      stdout.writeln('  $feature: ${missing.join(", ")}');
    });
    if (args.contains('--verify')) exit(1);
  } else if (args.contains('--verify')) {
    stdout.writeln('\nEvery checked feature is fully cited.');
  }
}
