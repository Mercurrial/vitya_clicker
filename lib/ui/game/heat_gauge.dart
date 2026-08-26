import 'package:flutter/widgets.dart';

import '../theme/garage.dart';
import 'heat_controller.dart';

/// Шкала ГРАДУСА: полоса жара, подсвеченная зелёная зона (она уезжает) и
/// стрелка текущего состояния.
///
/// Читаемость важнее красоты: игрок должен с одного взгляда понимать «холодно /
/// в зоне / вот-вот перегрею», иначе механика превращается в лотерею.
class HeatGauge extends StatelessWidget {
  final HeatController controller;
  const HeatGauge({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final label = controller.isOverheated
            ? 'ПЕРЕГРЕВ'
            : controller.isInZone
                ? 'В САМЫЙ РАЗ'
                : 'ГРАДУС';
        final labelColor = controller.isOverheated
            ? GColors.hot
            : controller.isInZone
                ? GColors.green
                : GColors.textMid;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: GType.label().copyWith(color: labelColor)),
                if (controller.multiplier > 1) ...[
                  const SizedBox(width: GS.s2),
                  Text(
                    '×${controller.multiplier.toStringAsFixed(controller.multiplier == controller.multiplier.roundToDouble() ? 0 : 1)}',
                    style: GType.num(
                      size: 12,
                      weight: FontWeight.w700,
                      color: labelColor,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: GS.s2),
            SizedBox(
              height: 18,
              child: CustomPaint(
                painter: _GaugePainter(
                  heat: controller.heat,
                  zoneStart: controller.zoneStart,
                  zoneEnd: controller.zoneEnd,
                  overheated: controller.isOverheated,
                  inZone: controller.isInZone,
                ),
                size: Size.infinite,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double heat;
  final double zoneStart;
  final double zoneEnd;
  final bool overheated;
  final bool inZone;

  _GaugePainter({
    required this.heat,
    required this.zoneStart,
    required this.zoneEnd,
    required this.overheated,
    required this.inZone,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const trackHeight = 10.0;
    final top = (size.height - trackHeight) / 2;
    const radius = Radius.circular(trackHeight / 2);

    // Жёлоб.
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, top, size.width, trackHeight),
      radius,
    );
    canvas.drawRRect(track, Paint()..color = GColors.wellBg);

    // Зелёная зона — она гуляет, поэтому рисуется каждый кадр.
    final zs = zoneStart.clamp(0.0, 1.0) * size.width;
    final ze = zoneEnd.clamp(0.0, 1.0) * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(zs, top, ze, top + trackHeight), radius),
      Paint()..color = GColors.green.withOpacity(0.35),
    );

    // Залитая часть — текущий жар.
    final fillWidth = heat.clamp(0.0, 1.0) * size.width;
    if (fillWidth > 0) {
      final fill = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, fillWidth, trackHeight),
        radius,
      );
      final paint = Paint()
        ..shader = LinearGradient(
          colors: overheated
              ? const [GColors.hot, GColors.hot]
              : const [GColors.cold, GColors.amber],
        ).createShader(Rect.fromLTWH(0, top, size.width, trackHeight));
      canvas.drawRRect(fill, paint);
    }

    // Стрелка текущего положения.
    final needleColor = overheated
        ? GColors.hot
        : inZone
            ? GColors.green
            : GColors.textHi;
    final x = fillWidth.clamp(1.5, size.width - 1.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 1.5, top - 4, 3, trackHeight + 8),
        const Radius.circular(2),
      ),
      Paint()..color = needleColor,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.heat != heat ||
      old.zoneStart != zoneStart ||
      old.overheated != overheated ||
      old.inZone != inZone;
}
