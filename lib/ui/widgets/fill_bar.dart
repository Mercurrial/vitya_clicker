/// Полоса заполнения — единственная на всю игру.
///
/// ## Зачем отдельный виджет
///
/// Полос в игре пять: бак, сорт, серия, до следующей ступени, до мудрости.
/// Все пять были написаны одинаковым куском вёрстки, скопированным из места в
/// место, и все пять **не работали**: заливка не появлялась вовсе.
///
/// Причина тонкая и стоит того, чтобы записать её здесь, а не в истории
/// коммитов. Заливка выглядела так:
///
/// ```dart
/// SizedBox(
///   height: 14,
///   child: Stack(children: [
///     ColoredBox(color: фон, child: SizedBox.expand()),
///     FractionallySizedBox(widthFactor: 0.5, child: ColoredBox(color: цвет)),
///   ]),
/// )
/// ```
///
/// `Stack` по умолчанию идёт с `StackFit.loose` и раздаёт детям ослабленные
/// ограничения: высота `0..14`, а не `14`. `FractionallySizedBox` без
/// `heightFactor` высоту не трогает и передаёт её ребёнку как есть. Ребёнок —
/// голый `ColoredBox` без содержимого, а такой выбирает **наименьшую**
/// допустимую высоту. Ноль. Заливка рисовалась исправно и была ровно ноль
/// пикселей ростом.
///
/// Фон при этом работал — у него внутри `SizedBox.expand`, который требует
/// максимум. Поэтому дефект выглядел как «полоска есть, но всегда пустая», и
/// пережил и ревью, и снимки экрана: на снимке пустая полоса неотличима от
/// полосы в нуле.
///
/// Виджет закрывает ошибку конструкцией, а не внимательностью: `StackFit.expand`
/// даёт детям жёсткие ограничения, `heightFactor: 1` растягивает заливку на всю
/// высоту, а `Alignment.centerLeft` заставляет её расти слева направо — без
/// этого половинная заливка оказалась бы посередине.
library;

import 'package:flutter/widgets.dart';

import '../theme/garage.dart';

class FillBar extends StatelessWidget {
  /// Заполненность, 0..1. Значения вне диапазона обрезаются: считать проценты
  /// должен вызывающий, но падать из-за деления на ноль полоса не обязана.
  final double value;

  final double height;

  /// Цвет заливки. Игнорируется, если задан [gradient].
  final Color? color;

  /// Градиент заливки — для бака, где цвет показывает ещё и сорт.
  final Gradient? gradient;

  /// Цвет жёлоба.
  final Color track;

  /// Скругление. По умолчанию — в половину высоты, то есть пилюля.
  final double? radius;

  /// Поверх заливки: насечки мерной тары и прочее украшение.
  final Widget? overlay;

  const FillBar({
    super.key,
    required this.value,
    required this.height,
    this.color,
    this.gradient,
    this.track = GColors.wellBg,
    this.radius,
    this.overlay,
  }) : assert(color != null || gradient != null, 'полосе нужен цвет заливки');

  @override
  Widget build(BuildContext context) {
    final fraction = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          // Жёсткие ограничения детям — см. шапку файла.
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color, gradient: gradient),
                ),
              ),
            ),
            if (overlay != null) overlay!,
          ],
        ),
      ),
    );
  }
}
