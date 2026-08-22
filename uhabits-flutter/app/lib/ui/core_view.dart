import 'package:flutter/widgets.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../platform/flutter_canvas.dart';

/// Hosts a chart written against the core's [core.View] interface.
///
/// The Android app wraps the same views in AndroidView/AndroidDataView; this is
/// the Flutter counterpart, and it is the only widget that needs to exist for
/// any of the ported charts to appear on screen.
class CoreView extends StatelessWidget {
  const CoreView({
    required this.view,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final core.View view;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (details) {
        view.onClick(details.localPosition.dx, details.localPosition.dy);
        onTap?.call();
      },
      onLongPressStart: (details) {
        view.onLongClick(details.localPosition.dx, details.localPosition.dy);
        onLongPress?.call();
      },
      child: CustomPaint(
        painter: _CoreViewPainter(view),
        size: Size.infinite,
      ),
    );
  }
}

class _CoreViewPainter extends CustomPainter {
  _CoreViewPainter(this.view);

  final core.View view;

  @override
  void paint(Canvas canvas, Size size) {
    view.draw(FlutterCanvas(canvas, size));
  }

  @override
  bool shouldRepaint(_CoreViewPainter oldDelegate) => true;
}
