import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/garage.dart';
import 'poster_portrait.dart';

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

/// Один всплеск: брызги + улетающая цифра.
class _Splash {
  final AnimationController ctrl;
  final List<Offset> drops;
  final String text;
  final Color textColor;
  _Splash(this.ctrl, this.drops, this.text, this.textColor);
}

/// Портрет Вити — цель нажатия.
///
/// Правило игры: на тапе НЕТ шуток (их видят тысячи раз, любая умрёт), только
/// ощущение — отдача, брызги, цифра, хаптика.
class VityaPortrait extends StatefulWidget {
  final VityaEra era;

  /// Возвращает текст для всплывающей цифры (например «+12 Л») и цвет.
  final ({String text, Color color}) Function() onTap;

  final double size;

  /// Ширина портрета в крупных пикселях (0 — плакатный вид).
  final double pixels;

  /// Сколько тонов оставить в портрете.
  final double levels;

  /// Радиус рамы: пиксельный стиль требует рубленых углов.
  final double radius;

  const VityaPortrait({
    super.key,
    required this.era,
    required this.onTap,
    this.size = 220,
    this.pixels = 0,
    this.levels = 4,
    this.radius = GR.card,
  });

  @override
  State<VityaPortrait> createState() => _VityaPortraitState();
}

class _VityaPortraitState extends State<VityaPortrait> with TickerProviderStateMixin {
  late final AnimationController _press;
  final List<_Splash> _splashes = [];
  final math.Random _rng = math.Random();

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
    for (final s in _splashes) {
      s.ctrl.dispose();
    }
    _press.dispose();
    super.dispose();
  }

  void _handleTap() {
    final result = widget.onTap();

    // Отдача: быстрое сжатие, мягкий возврат.
    _press.forward(from: 0).then((_) {
      if (mounted) _press.reverse();
    });

    HapticFeedback.lightImpact();

    final drops = List.generate(7, (i) {
      final angle = -math.pi / 2 + (_rng.nextDouble() - 0.5) * 2.2;
      final dist = 50 + _rng.nextDouble() * 60;
      return Offset(math.cos(angle) * dist, math.sin(angle) * dist);
    });

    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    final splash = _Splash(ctrl, drops, result.text, result.color);
    setState(() => _splashes.add(splash));

    ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        ctrl.dispose();
        if (mounted) setState(() => _splashes.remove(splash));
      }
    });
    ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _handleTap(),
            child: AnimatedBuilder(
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
                pixels: widget.pixels,
                levels: widget.levels,
                radius: widget.radius,
              ),
            ),
          ),
          for (final s in _splashes) ..._splashWidgets(s),
        ],
      ),
    );
  }

  List<Widget> _splashWidgets(_Splash s) => [
        // Капли самогона.
        for (final d in s.drops)
          AnimatedBuilder(
            animation: s.ctrl,
            builder: (_, __) {
              final t = Curves.easeOut.transform(s.ctrl.value);
              // Лёгкая гравитация: капли летят вверх и опадают.
              final dy = d.dy * t + 90 * t * t;
              return IgnorePointer(
                child: Transform.translate(
                  offset: Offset(d.dx * t, dy),
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: GColors.brew,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        // Цифра добычи.
        AnimatedBuilder(
          animation: s.ctrl,
          builder: (_, __) {
            final t = Curves.easeOut.transform(s.ctrl.value);
            return IgnorePointer(
              child: Transform.translate(
                offset: Offset(0, -widget.size * 0.42 - 70 * t),
                child: Opacity(
                  opacity: (1 - t * t).clamp(0.0, 1.0),
                  child: Text(
                    s.text,
                    style: GType.num(
                      size: 22,
                      weight: FontWeight.w700,
                      color: s.textColor,
                      shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 8)],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ];
}

/// Рама портрета: медный кант, тёплый свет сверху, табличка снизу.
class _Frame extends StatelessWidget {
  final VityaEra era;
  final double size;
  final double pixels;
  final double levels;
  final double radius;

  const _Frame({
    required this.era,
    required this.size,
    required this.pixels,
    required this.levels,
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
              const BoxShadow(color: Color(0x99000000), blurRadius: 22, offset: Offset(0, 10)),
              if (grand)
                const BoxShadow(color: GColors.amberGlow, blurRadius: 34, spreadRadius: 2),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius > 0 ? radius - 6 : 0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PosterPortrait(
                  asset: era.asset,
                  pixels: pixels,
                  levels: levels,
                ),
                // Свет лампы сверху — сажает фото в гараж.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x33FFD089), Color(0x00000000), Color(0x4D14100C)],
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
        Text(era.caption, style: GType.label()),
      ],
    );
  }
}
