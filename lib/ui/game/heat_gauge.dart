import 'package:flutter/widgets.dart';

import '../theme/garage.dart';
import 'heat_controller.dart';

/// Шкала ЖАРА ПОД КУБОМ.
///
/// Показывает жар, подвижное окно и что сейчас происходит с сортом. Границы
/// окна рисуются **поверх** заливки: раньше заливка их закрашивала, и после
/// перегрева игрок терял ориентир — было не видно, куда возвращаться.
class HeatGauge extends StatelessWidget {
  final HeatController controller;
  const HeatGauge({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final status = controller.status;
        final accent = switch (status) {
          HeatStatus.overheated => GColors.hot,
          HeatStatus.inWindow => GColors.green,
          HeatStatus.off => GColors.textMid,
        };

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('ЖАР ПОД КУБОМ', style: GType.label()),
                Text(
                  '${controller.label} · ${controller.sortHint}',
                  style: GType.num(size: 10, weight: FontWeight.w500, color: accent),
                ),
              ],
            ),
            const SizedBox(height: GS.s1),
            SizedBox(
              height: 18,
              child: CustomPaint(
                painter: _GaugePainter(
                  heat: controller.heat,
                  windowStart: controller.windowStart,
                  windowEnd: controller.windowEnd,
                  accent: accent,
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
  final double windowStart;
  final double windowEnd;
  final Color accent;

  _GaugePainter({
    required this.heat,
    required this.windowStart,
    required this.windowEnd,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const trackHeight = 8.0;
    final top = (size.height - trackHeight) / 2;
    const radius = Radius.circular(trackHeight / 2);

    // Жёлоб.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width, trackHeight),
        radius,
      ),
      Paint()..color = GColors.wellBg,
    );

    // Окно — подложка под заливкой, чтобы не спорить цветом.
    final ws = windowStart.clamp(0.0, 1.0) * size.width;
    final we = windowEnd.clamp(0.0, 1.0) * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(ws, top, we, top + trackHeight), radius),
      Paint()..color = GColors.green.withOpacity(0.22),
    );

    // Заливка жара.
    final fill = heat.clamp(0.0, 1.0) * size.width;
    if (fill > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, top, fill, trackHeight),
          radius,
        ),
        Paint()
          ..shader = LinearGradient(
            colors: [GColors.cold, accent],
          ).createShader(Rect.fromLTWH(0, top, size.width, trackHeight)),
      );
    }

    // Рамка окна ПОВЕРХ заливки — она обязана оставаться видимой всегда.
    final edge = Paint()
      ..color = GColors.green
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(ws, top - 3), Offset(ws, top + trackHeight + 3), edge);
    canvas.drawLine(Offset(we, top - 3), Offset(we, top + trackHeight + 3), edge);

    // Стрелка текущего жара.
    final x = fill.clamp(1.5, size.width - 1.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 1.5, top - 5, 3, trackHeight + 10),
        const Radius.circular(2),
      ),
      Paint()..color = GColors.lamp,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.heat != heat ||
      old.windowStart != windowStart ||
      old.accent != accent;
}
