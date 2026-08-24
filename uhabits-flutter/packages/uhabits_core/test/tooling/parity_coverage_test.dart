import 'dart:io';

import 'package:test/test.dart';

// The coverage tool is not a package, so it is reached by path. It lives one
// level above the two packages precisely because it reasons about both.
import '../../../../tool/parity_coverage.dart';

/// Ids here are deliberately fictional, and these tests deliberately cite no
/// rule at all. The tool scans this very directory for citations, so naming a
/// real rule would mark it cited by a test that never exercises it — the exact
/// self-deception the ledger exists to prevent. This file tests the ledger
/// machinery, not any behaviour the ledger describes.
const _first = <String>[
  '- [x] `alpha.one`',
  '1. `alpha.one#1` first rule',
  '2. `alpha.one#2` second rule',
  '- [ ] `alpha.two`',
  '1. `alpha.two#1` only rule',
];

const _second = <String>[
  '# A heading, and a stray rule before any feature',
  '1. `orphan.rule#1` belongs to nothing',
  '- [ ] `beta.one`',
  '1. `beta.one#1` first rule',
  '- [~] `beta.gone`',
  '1. `beta.gone#1` superseded rule',
];

void main() {
  group('parseLedgers', () {
    test('collects features and rules from every file', () {
      final ledger = parseLedgers([_first, _second]);
      expect(
        ledger.rulesByFeature.keys,
        containsAll(<String>['alpha.one', 'alpha.two', 'beta.one', 'beta.gone']),
      );
      expect(ledger.rulesByFeature['alpha.one'],
          equals(<String>['alpha.one#1', 'alpha.one#2']));
      expect(ledger.rulesByFeature['beta.one'], equals(<String>['beta.one#1']));
    });

    test('a feature never continues across a file boundary', () {
      // Without the reset, `orphan.rule#1` would attach to `alpha.two`, the
      // last feature of the previous file, and quietly hold it open.
      final ledger = parseLedgers([_first, _second]);
      expect(ledger.rulesByFeature['alpha.two'],
          equals(<String>['alpha.two#1']));
      expect(ledger.rulesByFeature.values.expand((r) => r),
          isNot(contains('orphan.rule#1')));
    });

    test('carries the checked and superseded marks over', () {
      final ledger = parseLedgers([_first, _second]);
      expect(ledger.checkedFeatures, contains('alpha.one'));
      expect(ledger.checkedFeatures, isNot(contains('alpha.two')));
      expect(ledger.supersededFeatures, contains('beta.gone'));
    });

    test('a rule marked not applicable leaves its feature', () {
      final ledger = parseLedgers([
        <String>[
          '- [ ] `gamma.one`',
          '1. `gamma.one#1` a normal rule',
          '2. `gamma.one#2` **не применимо к порту:** нет прообраза',
        ]
      ]);
      expect(ledger.rulesByFeature['gamma.one'],
          equals(<String>['gamma.one#1']));
      expect(ledger.notApplicableRules, contains('gamma.one#2'));
    });
  });

  group('the real ledgers', () {
    late Directory repoRoot;

    setUp(() {
      // test runs from packages/uhabits_core
      repoRoot = Directory.current.parent.parent.parent;
    });

    test('both files exist and are read together', () {
      final parity = File('${repoRoot.path}/docs/parity/FEATURES.md');
      final extensions = File('${repoRoot.path}/docs/extensions/SLEEP.md');
      expect(parity.existsSync(), isTrue);
      expect(extensions.existsSync(), isTrue);

      final separately = parseLedgers([parity.readAsLinesSync()])
              .rulesByFeature
              .length +
          parseLedgers([extensions.readAsLinesSync()]).rulesByFeature.length;
      final together = parseLedgers([
        parity.readAsLinesSync(),
        extensions.readAsLinesSync(),
      ]).rulesByFeature.length;

      expect(together, separately);
      expect(together, greaterThan(parseLedgers([parity.readAsLinesSync()]).rulesByFeature.length));
    });

    test('extension rules are all prefixed, so ids cannot collide', () {
      final extensions =
          File('${repoRoot.path}/docs/extensions/SLEEP.md').readAsLinesSync();
      final ledger = parseLedgers([extensions]);
      for (final feature in ledger.rulesByFeature.keys) {
        expect(feature, startsWith('sleep.'));
      }
      for (final rule in ledger.rulesByFeature.values.expand((r) => r)) {
        expect(rule, startsWith('sleep.'));
      }
    });
  });
}
