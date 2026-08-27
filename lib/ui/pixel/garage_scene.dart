import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/game_provider.dart';
import '../theme/garage.dart';
import 'pixel_sprite.dart';
import 'still_sprites.dart';

/// Гараж Вити — сцена, а не список.
///
/// Главная задача: **империю должно быть видно**. Пока покупка меняла лишь
/// число в таблице, игра ощущалась как ведомость. Теперь каждый купленный
/// аппарат физически встаёт на полку, кипит и парит, поэтому прогресс читается
/// глазами, а не только цифрами.
class GarageScene extends ConsumerStatefulWidget {
  /// Текущий жар: подсвечивает огонь под аппаратами и ускоряет кипение.
  final double heat;

  /// Что висит на стене — портрет Вити. Он часть сцены, а не отдельный блок:
  /// так гараж читается как единое место, а не как набор панелей.
  final Widget hanging;

  const GarageScene({super.key, required this.heat, required this.hanging});

  @override
  ConsumerState<GarageScene> createState() => _GarageSceneState();
}

class _GarageSceneState extends ConsumerState<GarageScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _time = 0;
  Duration _prev = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration now) {
    final dt = _prev == Duration.zero ? 0.016 : (now - _prev).inMicroseconds / 1e6;
    _prev = now;
    _time += dt;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owned = ref.watch(
      gameProvider.select(
        (s) => [
          for (final g in s.generators.items)
            if (g.ownedCount > 0) (id: g.id, count: g.ownedCount),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(GR.card),
          child: Stack(
            children: [
              const Positioned.fill(child: _Wall()),
              Positioned.fill(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: GS.s3),
                      child: widget.hanging,
                    ),
                    Expanded(
                      child: owned.isEmpty
                          ? const _EmptyGarage()
                          : _Shelves(
                              items: owned,
                              time: _time,
                              heat: widget.heat,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Кирпичная стена и пол — фон, который не отвлекает.
class _Wall extends StatelessWidget {
  const _Wall();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WallPainter(), size: Size.infinite);
  }
}

class _WallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF241C15),
    );

    // Кладка: намеренно очень контрастно-приглушённая, чтобы не спорить с
    // аппаратами на переднем плане.
    final brick = Paint()..color = const Color(0x14FFFFFF);
    const bw = 26.0, bh = 13.0;
    for (var y = 0.0, r = 0; y < size.height; y += bh, r++) {
      final offset = r.isEven ? 0.0 : bw / 2;
      for (var x = -bw; x < size.width; x += bw) {
        canvas.drawRect(
          Rect.fromLTWH(x + offset + 1, y + 1, bw - 2, bh - 2),
          brick,
        );
      }
    }

    // Свет лампы сверху.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.9),
          radius: 1.1,
          colors: [Color(0x33FFD089), Color(0x00000000)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_WallPainter old) => false;
}

class _EmptyGarage extends StatelessWidget {
  const _EmptyGarage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GS.s5),
        child: Text(
          'Пусто.\nКупи первую банку.',
          textAlign: TextAlign.center,
          style: GType.body(),
        ),
      ),
    );
  }
}

/// Полки с аппаратами. Заполняются снизу вверх по мере роста производства.
class _Shelves extends StatelessWidget {
  final List<({String id, int count})> items;
  final double time;
  final double heat;

  const _Shelves({required this.items, required this.time, required this.heat});

  @override
  Widget build(BuildContext context) {
    // Новые аппараты — ближе к зрителю: показываем последние приобретения.
    final shown = items.length > 6 ? items.sublist(items.length - 6) : items;

    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s2, GS.s4, GS.s2, GS.s2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (var row = 0; row < (shown.length / 3).ceil(); row++) ...[
            Expanded(
              child: _ShelfRow(
                items: shown.skip(row * 3).take(3).toList(),
                time: time,
                heat: heat,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShelfRow extends StatelessWidget {
  final List<({String id, int count})> items;
  final double time;
  final double heat;

  const _ShelfRow({required this.items, required this.time, required this.heat});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final it in items)
                _Still(id: it.id, count: it.count, time: time, heat: heat),
            ],
          ),
        ),
        // Сама полка.
        Container(
          height: 5,
          margin: const EdgeInsets.only(top: 2),
          decoration: const BoxDecoration(
            color: Color(0xFF4A3524),
            border: Border(
              top: BorderSide(color: Color(0xFF6B4E33), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Один аппарат на полке: пар, корпус, счётчик штук.
class _Still extends StatelessWidget {
  final String id;
  final int count;
  final double time;
  final double heat;

  const _Still({
    required this.id,
    required this.count,
    required this.time,
    required this.heat,
  });

  @override
  Widget build(BuildContext context) {
    final sprite = stillSpriteFor(id);

    // Кипение ускоряется вместе с жаром — видно, что тапы что-то делают.
    final speed = 1.0 + heat;
    final frame = ((time * 2.2 * speed).floor()) % kSteamFrames.length;

    // Жидкость слегка колышется: сдвигаем только нижние строки.
    int shift(int row) {
      if (row < sprite.height - 7) return 0;
      final phase = math.sin(time * 3.4 * speed + row);
      return phase > 0.6 ? 1 : (phase < -0.6 ? -1 : 0);
    }

    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 18,
            child: PixelImage(sprite: kSteamFrames[frame], size: 44),
          ),
          PixelImage(sprite: sprite, size: 56, rowShift: shift),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xCC1A1410),
              borderRadius: BorderRadius.circular(GR.pill),
            ),
            child: Text(
              '$count',
              style: GType.num(
                size: 11,
                weight: FontWeight.w700,
                color: GColors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
