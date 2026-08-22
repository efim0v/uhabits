/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/PaletteColor.kt
/// (plus the fixed-palette part of uhabits-android/.../utils/PaletteUtils.kt).
class PaletteColor {
  const PaletteColor(this.paletteIndex);

  final int paletteIndex;

  /// The canonical CSV / export mapping. Valid indices are 0..19; anything
  /// else throws, exactly as the Kotlin array lookup does.
  String toCsvColor() {
    return const <String>[
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
      '#aaaaaa' // 19 light grey
    ][paletteIndex];
  }

  /// The fixed (theme-independent) palette used by the Android widgets and by
  /// the instrumentation tests, as opaque ARGB. Same 20 colors as
  /// [toCsvColor]; out-of-range indices throw, there is no clamping.
  int toFixedAndroidColor() {
    return const <int>[
      0xFFD32F2F, //  0 red
      0xFFE64A19, //  1 deep orange
      0xFFF57C00, //  2 orange
      0xFFFF8F00, //  3 amber
      0xFFF9A825, //  4 yellow
      0xFFAFB42B, //  5 lime
      0xFF7CB342, //  6 light green
      0xFF388E3C, //  7 green
      0xFF00897B, //  8 teal
      0xFF00ACC1, //  9 cyan
      0xFF039BE5, // 10 light blue
      0xFF1976D2, // 11 blue
      0xFF303F9F, // 12 indigo
      0xFF5E35B1, // 13 deep purple
      0xFF8E24AA, // 14 purple
      0xFFD81B60, // 15 pink
      0xFF5D4037, // 16 brown
      0xFF303030, // 17 dark grey
      0xFF757575, // 18 grey
      0xFFAAAAAA // 19 light grey
    ][paletteIndex];
  }

  /// A plain method, not an implementation of [Comparable]: it is only ever
  /// called explicitly, by the BY_COLOR_ASC / BY_COLOR_DESC comparators.
  int compareTo(PaletteColor other) =>
      paletteIndex.compareTo(other.paletteIndex);

  @override
  bool operator ==(Object other) =>
      other is PaletteColor && other.paletteIndex == paletteIndex;

  @override
  int get hashCode => paletteIndex.hashCode;

  @override
  String toString() => 'PaletteColor(paletteIndex=$paletteIndex)';
}
