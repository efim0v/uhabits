import 'package:test/test.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// Ported from uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/EntryTest.kt
void main() {
  group('models.entry-values', () {
    test('#1 immutable value object of date, value and notes', () {
      final a = Entry(LocalDate(0), Entry.yesManual, notes: 'n');
      final b = Entry(LocalDate(0), Entry.yesManual, notes: 'n');
      expect(a, b, reason: 'models.entry-values#1');
      expect(a.notes, 'n', reason: 'models.entry-values#1');
      expect(Entry(LocalDate(0), Entry.yesManual).notes, '',
          reason: 'models.entry-values#1');
      expect(a == Entry(LocalDate(1), Entry.yesManual, notes: 'n'), isFalse,
          reason: 'models.entry-values#1');
    });

    test('#2 the five reserved values', () {
      expect(Entry.skip, 3, reason: 'models.entry-values#2');
      expect(Entry.yesManual, 2, reason: 'models.entry-values#2');
      expect(Entry.yesAuto, 1, reason: 'models.entry-values#2');
      expect(Entry.no, 0, reason: 'models.entry-values#2');
      expect(Entry.unknown, -1, reason: 'models.entry-values#2');
    });

    test('#5 formattedValue names the reserved values', () {
      expect(Entry(LocalDate(0), Entry.yesManual).formattedValue, 'YES_MANUAL',
          reason: 'models.entry-values#5');
      expect(Entry(LocalDate(0), Entry.yesAuto).formattedValue, 'YES_AUTO',
          reason: 'models.entry-values#5');
      expect(Entry(LocalDate(0), Entry.no).formattedValue, 'NO',
          reason: 'models.entry-values#5');
      expect(Entry(LocalDate(0), Entry.skip).formattedValue, 'SKIP',
          reason: 'models.entry-values#5');
      expect(Entry(LocalDate(0), Entry.unknown).formattedValue, 'UNKNOWN',
          reason: 'models.entry-values#5');
      expect(Entry(LocalDate(0), 2000).formattedValue, '2000',
          reason: 'models.entry-values#5');
      expect(Entry(LocalDate(0), 3000).formattedValue, '3000',
          reason: 'models.entry-values#5');
    });

    test('#3 #7 reserved value semantics', () {
      // SKIP: not applicable. YES_MANUAL: user checked it. YES_AUTO: not
      // performed but not expected, given the frequency. NO: expected and not
      // performed. UNKNOWN: no data.
      expect(
          [Entry.skip, Entry.yesManual, Entry.yesAuto, Entry.no, Entry.unknown],
          [3, 2, 1, 0, -1],
          reason: 'models.entry-values#3 models.entry-values#7');
    });

    test('#4 numerical values are stored multiplied by 1000', () {
      final entry = Entry.raw(0, 2000);
      expect(entry.value / 1000.0, 2.0, reason: 'models.entry-values#4');
      expect(Entry.raw(0, 1500).value / 1000.0, 1.5,
          reason: 'models.entry-values#4');
    });

    test('#8 formattedValue renders unreserved integers as decimals', () {
      expect(Entry.raw(0, 12345).formattedValue, '12345',
          reason: 'models.entry-values#8');
    });

    test('#6 a numerical value of 3 is indistinguishable from SKIP', () {
      // Upstream bug, reproduced deliberately. See docs/parity/DEVIATIONS.md
      // before changing this.
      expect(Entry(LocalDate(0), 3).formattedValue, 'SKIP',
          reason: 'models.entry-values#6');
    });
  });

  group('models.entry-toggle-cycle', () {
    int next(int value, {bool skip = false, bool unknown = false}) =>
        Entry.nextToggleValue(value,
            isSkipEnabled: skip, areQuestionMarksEnabled: unknown);

    test('#2 YES_AUTO always becomes YES_MANUAL', () {
      expect(next(Entry.yesAuto), Entry.yesManual,
          reason: 'models.entry-toggle-cycle#2');
      expect(next(Entry.yesAuto, skip: true, unknown: true), Entry.yesManual,
          reason: 'models.entry-toggle-cycle#2');
    });

    test('#3 YES_MANUAL becomes SKIP only when skip is enabled', () {
      expect(next(Entry.yesManual, skip: true), Entry.skip,
          reason: 'models.entry-toggle-cycle#3');
      expect(next(Entry.yesManual, skip: false), Entry.no,
          reason: 'models.entry-toggle-cycle#3');
    });

    test('#4 SKIP always becomes NO', () {
      expect(next(Entry.skip, skip: true, unknown: true), Entry.no,
          reason: 'models.entry-toggle-cycle#4');
      expect(next(Entry.skip), Entry.no,
          reason: 'models.entry-toggle-cycle#4');
    });

    test('#5 NO becomes UNKNOWN only when question marks are enabled', () {
      expect(next(Entry.no, unknown: true), Entry.unknown,
          reason: 'models.entry-toggle-cycle#5');
      expect(next(Entry.no, unknown: false), Entry.yesManual,
          reason: 'models.entry-toggle-cycle#5');
    });

    test('#6 UNKNOWN always becomes YES_MANUAL', () {
      expect(next(Entry.unknown, skip: true, unknown: true), Entry.yesManual,
          reason: 'models.entry-toggle-cycle#6');
    });

    test('#7 any other value becomes YES_MANUAL', () {
      expect(next(2000, skip: true, unknown: true), Entry.yesManual,
          reason: 'models.entry-toggle-cycle#7');
    });

    test('#1 #9 nextToggleValue is a pure total function', () {
      for (final value in [-5, -1, 0, 1, 2, 3, 2000]) {
        final first = next(value, skip: true, unknown: true);
        final second = next(value, skip: true, unknown: true);
        expect(first, second,
            reason: 'models.entry-toggle-cycle#1 models.entry-values#9');
      }
    });

    test('#8 full cycle with skip and question marks enabled', () {
      var v = Entry.yesManual;
      v = next(v, skip: true, unknown: true);
      expect(v, Entry.skip, reason: 'models.entry-toggle-cycle#8');
      v = next(v, skip: true, unknown: true);
      expect(v, Entry.no, reason: 'models.entry-toggle-cycle#8');
      v = next(v, skip: true, unknown: true);
      expect(v, Entry.unknown, reason: 'models.entry-toggle-cycle#8');
      v = next(v, skip: true, unknown: true);
      expect(v, Entry.yesManual, reason: 'models.entry-toggle-cycle#8');
    });

    test('#9 cycle with both disabled is YES_MANUAL to NO and back', () {
      expect(next(Entry.yesManual), Entry.no,
          reason: 'models.entry-toggle-cycle#9');
      expect(next(Entry.no), Entry.yesManual,
          reason: 'models.entry-toggle-cycle#9');
    });
  });
}
