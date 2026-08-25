/// The chrome the sleep blocks share with the rest of the habit screen.
library;

import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

/// Same rounding as `FlutterCanvas.setColor` and `core.Color.toInt`.
Color toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round(),
      (color.red * 255).round(),
      (color.green * 255).round(),
      (color.blue * 255).round(),
    );

/// A block on the habit screen, dressed like the cards below it.
///
/// The sleep blocks sit above the ported column rather than inside it: that
/// column follows `ShowHabitCard`'s declaration order, a parity rule closed by
/// tests, and adding entries to the enum would make those tests assert
/// something the ledger does not say.
class SleepCard extends StatelessWidget {
  const SleepCard({
    required this.theme,
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final core.Theme theme;

  /// The small heading above the block.
  final String title;

  final Widget child;

  /// An action shown at the end of the heading row.
  final Widget? trailing;

  static const EdgeInsets margin = EdgeInsets.fromLTRB(3, 0, 3, 1);
  static const EdgeInsets padding = EdgeInsets.fromLTRB(16, 16, 16, 16);
  static const double elevation = 1.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        elevation: elevation,
        color: toFlutterColor(theme.cardBackgroundColor),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w500,
                        color: toFlutterColor(theme.mediumContrastTextColor),
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders a duration in minutes as hours and minutes: `6:48`.
///
/// Not a time of day, so it is deliberately not put through the locale's clock
/// format: "6:48 PM" would be a different quantity entirely.
String formatDurationMinutes(int minutes) {
  final int clamped = minutes < 0 ? 0 : minutes;
  final String mm = (clamped % 60).toString().padLeft(2, '0');
  return '${clamped ~/ 60}:$mm';
}

/// The colour a component's score is written in.
///
/// Three bands rather than a gradient: the number itself carries the precision,
/// and the colour only has to answer "is this fine, slipping, or gone".
Color scoreColor(core.Theme theme, double score) {
  if (score >= 0.8) return const Color(0xFF4CAF50);
  if (score >= 0.5) return const Color(0xFFFFA000);
  return const Color(0xFFE53935);
}
