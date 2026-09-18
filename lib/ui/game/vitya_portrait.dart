import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../pixel/pixel_portrait.dart';
import '../theme/garage.dart';

/// Эпоха Вити — портрет растёт вместе с производством.
///
/// Смысл в почтении: чем больше империя, тем торжественнее обрамление. Юмор
/// берётся из контраста «эпическая рама ↔ обычный человек», а не из издёвки.
enum VityaEra { start, work, boss }

extension _EraAsset on VityaEra {
  String get asset => switch (this) {
        VityaEra.start => 'assets/images/vitya/vitya_doc.jpg',
        VityaEra.work => 'assets/images/vitya/vitya_frown.jpg',
        VityaEra.boss => 'assets/images/vitya/vitya_boss.jpg',
      };

  /// Подпись под портретом — сухая, как табличка в музее.
  String get caption => switch (this) {
        VityaEra.start => 'В. — начинающий',
        VityaEra.work => 'В. — за работой',
        VityaEra.boss => 'В. — директор производства',
      };
}

/// Портрет Вити.
///
/// Жестов не ловит: зона касания одна и она снаружи, на всей сцене. Отсюда
/// только отдача — сжатие в момент зажима, чтобы касание ощущалось.
class VityaPortrait extends StatefulWidget {
  final VityaEra era;

  /// Держат ли сейчас палец. Портрет САМ жесты не ловит.
  ///
  /// Ловил — и это был баг: вложенный GestureDetector выигрывал арену у
  /// внешнего, тот получал onTapCancel и тут же отменял поддув, начатый
  /// внутренним. Зажим не работал вовсе. Зона касания должна быть одна, и она
  /// снаружи — на всей сцене.
  final bool pressed;

  final double size;

  /// Как переводить фотографию: спрайт или плакат.
  final PixelPortraitStyle style;

  /// Радиус рамы: пиксельный стиль требует рубленых углов.
  final double radius;

  const VityaPortrait({
    super.key,
    required this.era,
    required this.pressed,
    this.size = 220,
    this.style = PixelPortraitStyle.pixel,
    this.radius = GR.card,
  });

  @override
  State<VityaPortrait> createState() => _VityaPortraitState();
}

class _VityaPortraitState extends State<VityaPortrait>
    with TickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VityaPortrait old) {
    super.didUpdateWidget(old);
    if (widget.pressed == old.pressed) return;
    if (widget.pressed) {
      _press.forward();
      HapticFeedback.lightImpact();
    } else {
      _press.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Размер — по содержимому, без обёртки с заданной шириной.
    //
    // Раньше тут стоял SizedBox(width: size), и он же ограничивал подпись:
    // «В. — директор производства» в ширину рамы не влезает и рвётся ровно
    // по тире. Ширину задаёт сама рама внутри, а табличке позволено выступать
    // за её края — так её и вешают.
    //
    // Высота тоже по содержимому: до этого стоял множитель 1.28, подобранный
    // на глаз, и стоило подписи стать на строку выше, портрет вылезал за свой
    // бокс жёлтой полосой.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            final t = _press.value;
            // Squash & stretch: чуть сжимается по вертикали и расплывается
            // по горизонтали — приём из классической анимации, из-за него
            // нажатие ощущается «мясистым».
            return Transform.scale(
              scaleX: 1 + 0.035 * t,
              scaleY: 1 - 0.055 * t,
              child: child,
            );
          },
          child: _Frame(
            era: widget.era,
            size: widget.size,
            style: widget.style,
            radius: widget.radius,
          ),
        ),
      ],
    );
  }
}

/// Рама портрета: медный кант, тёплый свет сверху, табличка снизу.
class _Frame extends StatelessWidget {
  final VityaEra era;
  final double size;
  final PixelPortraitStyle style;
  final double radius;

  const _Frame({
    required this.era,
    required this.size,
    required this.style,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final grand = era == VityaEra.boss;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size * 1.1,
          padding: EdgeInsets.all(grand ? 8 : 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: grand
                  ? const [GColors.amber, GColors.copperDim]
                  : const [GColors.copper, GColors.copperDim],
            ),
            boxShadow: [
              const BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 22,
                  offset: Offset(0, 10)),
              if (grand)
                const BoxShadow(
                    color: GColors.amberGlow, blurRadius: 34, spreadRadius: 2),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius > 0 ? radius - 6 : 0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PixelPortrait(asset: era.asset, style: style),
                // Свет лампы сверху — сажает фото в гараж.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33FFD089),
                        Color(0x00000000),
                        Color(0x4D14100C)
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: GS.s2),
        // Табличка как в музее — сухо и серьёзно, в этом и шутка.
        //
        // Шире рамы намеренно: «В. — директор производства» в ширину портрета
        // не влезает и рвётся ровно по тире, отчего подпись читается как
        // обрывок. Табличке позволено выступать за раму — так её и вешают.
        //
        // Ширину задаёт сама рама (Container выше), а не обёртка вокруг всего
        // портрета — поэтому подписи никто не мешает быть шире, и колонка
        // просто становится по ней.
        //
        // OverflowBox тут не годится: в колонке он получает неограниченную
        // высоту, растягивается на бесконечность и утаскивает за экран всю
        // сцену. Проверено — пропал и портрет, и полки с аппаратами.
        Text(
          era.caption,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          style: GType.label(),
        ),
      ],
    );
  }
}
