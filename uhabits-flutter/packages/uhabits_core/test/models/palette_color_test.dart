import 'package:test/test.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/palette_color.dart';

/// Rules from docs/parity/FEATURES.md: models.palette-color, models.habit-type-enums.
/// No Kotlin unit tests exist for these classes; the cases below come from the
/// rules and from the Kotlin sources PaletteColor.kt, HabitType.kt,
/// NumericalHabitType.kt and uhabits-android .../utils/PaletteUtils.kt.
void main() {
  const csvColors = <String>[
    '#D32F2F', //  0 red
    '#E64A19', //  1 deep orange
    '#F57C00', //  2 orange
    '#FF8F00', //  3 amber
    '#F9A825', //  4 yellow
    '#AFB42B', //  5 lime
    '#7CB342', //  6 light green
    '#388E3C', //  7 green
    '#00897B', //  8 teal
    '#00ACC1', //  9 cyan
    '#039BE5', // 10 light blue
    '#1976D2', // 11 blue
    '#303F9F', // 12 indigo
    '#5E35B1', // 13 deep purple
    '#8E24AA', // 14 purple
    '#D81B60', // 15 pink
    '#5D4037', // 16 brown
    '#303030', // 17 dark grey
    '#757575', // 18 grey
    '#aaaaaa', // 19 light grey
  ];

  group('models.palette-color', () {
    test('#1 immutable value object wrapping a single paletteIndex', () {
      const a = PaletteColor(8);
      const b = PaletteColor(8);
      expect(a.paletteIndex, 8, reason: 'models.palette-color#1');
      expect(a, b, reason: 'models.palette-color#1');
      expect(a.hashCode, b.hashCode, reason: 'models.palette-color#1');
      expect(a == const PaletteColor(9), isFalse,
          reason: 'models.palette-color#1');
      expect(identical(a, b), isTrue, reason: 'models.palette-color#1');
      expect(a.toString(), 'PaletteColor(paletteIndex=8)',
          reason: 'models.palette-color#1');
    });

    test('#2 toCsvColor maps 0..19 to the fixed hex list, in order', () {
      for (var i = 0; i < csvColors.length; i++) {
        expect(PaletteColor(i).toCsvColor(), csvColors[i],
            reason: 'models.palette-color#2');
      }
      expect(csvColors.length, 20, reason: 'models.palette-color#2');
      // Spot-check the named colors called out by the rule.
      expect(const PaletteColor(0).toCsvColor(), '#D32F2F',
          reason: 'models.palette-color#2');
      expect(const PaletteColor(8).toCsvColor(), '#00897B',
          reason: 'models.palette-color#2');
      expect(const PaletteColor(11).toCsvColor(), '#1976D2',
          reason: 'models.palette-color#2');
      expect(const PaletteColor(19).toCsvColor(), '#aaaaaa',
          reason: 'models.palette-color#2');
    });

    test('#3 toCsvColor throws for an index outside 0..19', () {
      expect(() => const PaletteColor(20).toCsvColor(), throwsRangeError,
          reason: 'models.palette-color#3');
      expect(() => const PaletteColor(-1).toCsvColor(), throwsRangeError,
          reason: 'models.palette-color#3');
      expect(() => const PaletteColor(100).toCsvColor(), throwsRangeError,
          reason: 'models.palette-color#3');
    });

    test('#4 compareTo is a plain method over paletteIndex, and drives '
        'BY_COLOR_ASC / BY_COLOR_DESC ordering', () {
      expect(const PaletteColor(1).compareTo(const PaletteColor(2)),
          lessThan(0),
          reason: 'models.palette-color#4');
      expect(const PaletteColor(2).compareTo(const PaletteColor(2)), 0,
          reason: 'models.palette-color#4');
      expect(const PaletteColor(19).compareTo(const PaletteColor(0)),
          greaterThan(0),
          reason: 'models.palette-color#4');
      expect(const PaletteColor(-5).compareTo(const PaletteColor(0)),
          lessThan(0),
          reason: 'models.palette-color#4');
      // It is a plain method: PaletteColor does not implement Comparable.
      expect(const PaletteColor(0) is Comparable, isFalse,
          reason: 'models.palette-color#4');

      final asc = <PaletteColor>[
        const PaletteColor(11),
        const PaletteColor(3),
        const PaletteColor(8),
      ]..sort((a, b) => a.compareTo(b));
      expect(asc.map((c) => c.paletteIndex).toList(), <int>[3, 8, 11],
          reason: 'models.palette-color#4');
      final desc = <PaletteColor>[
        const PaletteColor(11),
        const PaletteColor(3),
        const PaletteColor(8),
      ]..sort((a, b) => b.compareTo(a));
      expect(desc.map((c) => c.paletteIndex).toList(), <int>[11, 8, 3],
          reason: 'models.palette-color#4');
    });

    test('#6 toFixedAndroidColor maps 0..19 to the same fixed colors as ARGB',
        () {
      for (var i = 0; i < csvColors.length; i++) {
        final expected =
            int.parse('FF${csvColors[i].substring(1)}', radix: 16);
        expect(PaletteColor(i).toFixedAndroidColor(), expected,
            reason: 'models.palette-color#6');
      }
      expect(const PaletteColor(0).toFixedAndroidColor(), 0xFFD32F2F,
          reason: 'models.palette-color#6');
      expect(const PaletteColor(8).toFixedAndroidColor(), 0xFF00897B,
          reason: 'models.palette-color#6');
      expect(const PaletteColor(19).toFixedAndroidColor(), 0xFFAAAAAA,
          reason: 'models.palette-color#6');
    });

    test('#7 toFixedAndroidColor throws outside 0..19, with no clamping', () {
      expect(() => const PaletteColor(20).toFixedAndroidColor(),
          throwsRangeError,
          reason: 'models.palette-color#7');
      expect(() => const PaletteColor(-1).toFixedAndroidColor(),
          throwsRangeError,
          reason: 'models.palette-color#7');
    });
  });

  group('models.habit-type-enums', () {
    test('#1 HabitType has exactly two entries with fixed persisted ints', () {
      expect(HabitType.values.length, 2,
          reason: 'models.habit-type-enums#1');
      expect(HabitType.values, <HabitType>[HabitType.yesNo, HabitType.numerical],
          reason: 'models.habit-type-enums#1');
      expect(HabitType.yesNo.value, 0, reason: 'models.habit-type-enums#1');
      expect(HabitType.numerical.value, 1,
          reason: 'models.habit-type-enums#1');
    });

    test('#2 HabitType.fromInt accepts 0 and 1 and throws otherwise', () {
      expect(HabitType.fromInt(0), HabitType.yesNo,
          reason: 'models.habit-type-enums#2');
      expect(HabitType.fromInt(1), HabitType.numerical,
          reason: 'models.habit-type-enums#2');
      expect(() => HabitType.fromInt(2), throwsStateError,
          reason: 'models.habit-type-enums#2');
      expect(() => HabitType.fromInt(-1), throwsStateError,
          reason: 'models.habit-type-enums#2');
    });

    test('#3 NumericalHabitType has exactly two entries with fixed ints', () {
      expect(NumericalHabitType.values.length, 2,
          reason: 'models.habit-type-enums#3');
      expect(
          NumericalHabitType.values,
          <NumericalHabitType>[
            NumericalHabitType.atLeast,
            NumericalHabitType.atMost,
          ],
          reason: 'models.habit-type-enums#3');
      expect(NumericalHabitType.atLeast.value, 0,
          reason: 'models.habit-type-enums#3');
      expect(NumericalHabitType.atMost.value, 1,
          reason: 'models.habit-type-enums#3');
    });

    test('#4 NumericalHabitType.fromInt accepts 0 and 1, throws otherwise', () {
      expect(NumericalHabitType.fromInt(0), NumericalHabitType.atLeast,
          reason: 'models.habit-type-enums#4');
      expect(NumericalHabitType.fromInt(1), NumericalHabitType.atMost,
          reason: 'models.habit-type-enums#4');
      expect(() => NumericalHabitType.fromInt(2), throwsStateError,
          reason: 'models.habit-type-enums#4');
      expect(() => NumericalHabitType.fromInt(-1), throwsStateError,
          reason: 'models.habit-type-enums#4');
    });

    test('#5 the Kotlin enum names are available verbatim for CSV export', () {
      expect(HabitType.yesNo.csvName, 'YES_NO',
          reason: 'models.habit-type-enums#5');
      expect(HabitType.numerical.csvName, 'NUMERICAL',
          reason: 'models.habit-type-enums#5');
      expect(NumericalHabitType.atLeast.csvName, 'AT_LEAST',
          reason: 'models.habit-type-enums#5');
      expect(NumericalHabitType.atMost.csvName, 'AT_MOST',
          reason: 'models.habit-type-enums#5');
    });
  });
}
