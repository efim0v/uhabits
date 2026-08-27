/// Оправа блока вычисляемой привычки — та же, что у карточек ниже.
///
/// Копия `SleepCard`, а не его переиспользование: у сна оправа названа по виду,
/// и импортировать «сон» в воздержание — врать про то, что это. Когда сон
/// переедет на слой 2 (шаг 4 в «Порядке работы»), `SleepCard` схлопывается
/// сюда; до тех пор две копии в тридцать строк дешевле, чем один общий файл с
/// неверным именем.
library;

import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

/// Та же округлённая конверсия, что у `FlutterCanvas.setColor`.
Color toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round(),
      (color.red * 255).round(),
      (color.green * 255).round(),
      (color.blue * 255).round(),
    );

class ComputedCard extends StatelessWidget {
  const ComputedCard({
    required this.theme,
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final core.Theme theme;
  final String title;
  final Widget child;
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
