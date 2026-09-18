import 'package:flutter/widgets.dart';

import '../../core/formatters.dart';
import '../theme/garage.dart';
import '../widgets/fill_bar.dart';
import 'heat_controller.dart';

/// Шкала ЖАРА ПОД КУБОМ.
///
/// Показывает жар, подвижное окно и что сейчас происходит с сортом. Границы
/// окна рисуются **поверх** заливки: раньше заливка их закрашивала, и после
/// перегрева игрок терял ориентир — было не видно, куда возвращаться.
class HeatGauge extends StatelessWidget {
  final HeatController controller;
  const HeatGauge({super.key, required this.controller});

  /// Подписи и шкала обновляются по-разному — и это главное здесь.
  ///
  /// Шкала ползёт непрерывно, ей нужен каждый кадр. Подписи меняются раз в
  /// несколько секунд, и раньше они перестраивались вместе со шкалой: два
  /// текста, Row и Column шестьдесят раз в секунду на ровном месте.
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<HeatStatus>(
          valueListenable: controller.statusNotifier,
          builder: (context, status, _) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('ЖАР ПОД КУБОМ', style: GType.label()),
              const SizedBox(width: GS.s2),
              // Состояние — гибкое. «В САМЫЙ РАЗ · сорт растёт» вместе с
              // заголовком не влезает в узкий телефон, и строка вылезала за
              // край жёлто-чёрной лентой.
              Flexible(
                child: Text(
                  '${controller.label} · ${controller.hint}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: GType.num(
                    size: 10,
                    weight: FontWeight.w500,
                    color: _accentFor(status),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: GS.s1),
        // СЕРИЯ — то, ради чего вообще держат палец. Её обязано быть видно
        // рядом со шкалой: без неё зажим выглядит бессмысленным.
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final mult = controller.multiplier;
            return Row(
              children: [
                Expanded(
                  child: FillBar(
                    value: controller.series,
                    height: 5,
                    color: GColors.amber,
                  ),
                ),
                const SizedBox(width: GS.s2),
                Text(
                  '${Fmt.mult(mult)} СЕРИЯ',
                  style: GType.num(
                    size: 10,
                    weight: FontWeight.w700,
                    color: mult > 1.05 ? GColors.amber : GColors.textLo,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: GS.s2),
        SizedBox(
          height: 18,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => CustomPaint(
              painter: _GaugePainter(
                heat: controller.heat,
                windowStart: controller.windowStart,
                windowEnd: controller.windowEnd,
                accent: _accentFor(controller.status),
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ],
    );
  }

  static Color _accentFor(HeatStatus status) => switch (status) {
        HeatStatus.overheated => GColors.hot,
        HeatStatus.inWindow => GColors.green,
        HeatStatus.off => GColors.textMid,
      };
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
