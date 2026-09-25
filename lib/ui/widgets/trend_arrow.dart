import 'package:flutter/widgets.dart';

/// Треугольник-стрелка: ▲ или ▼, нарисованный, а не набранный.
///
/// Ни в Rubik, ни в IBM Plex Mono этих знаков нет. Браузер подставлял их из
/// запасного шрифта, который CanvasKit скачивает из сети, — без сети на их
/// месте был бы пустой квадрат. Рисунок от шрифта не зависит.
class TrendArrow extends StatelessWidget {
  final bool up;
  final Color color;
  final double size;

  /// Сколько стрелок подряд: две — «падает быстро».
  final int count;

  const TrendArrow({
    super.key,
    required this.up,
    required this.color,
    this.size = 9,
    this.count = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 1),
            child: CustomPaint(
              size: Size(size, size * 0.8),
              painter: _TrianglePainter(up: up, color: color),
            ),
          ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final bool up;
  final Color color;
  _TrianglePainter({required this.up, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = up
        ? (Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height))
        : (Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width / 2, size.height));
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.up != up || old.color != color;
}
