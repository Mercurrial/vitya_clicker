import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/game_provider.dart';
import '../theme/garage.dart';
import 'garage_room.dart';
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
          for (var i = 0; i < s.generators.items.length; i++)
            if (s.generators.items[i].ownedCount > 0)
              (id: s.generators.items[i].id, count: s.generators.items[i].ownedCount, tier: i),
        ],
      ),
    );

    // Помещение — по старшему аппарату: банка и коллайдер не стоят в одной
    // комнате.
    final stage = stageForTier(owned.isEmpty ? 0 : owned.last.tier);

    return ClipRRect(
      borderRadius: BorderRadius.circular(GR.card),
      child: Stack(
        children: [
          Positioned.fill(child: RoomBackground(stage: stage)),
          Positioned.fill(
            child: SwingingLamp(time: _time, heat: widget.heat),
          ),
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
          // Табличка помещения. Мелкая и в углу: это подпись к сцене, а не
          // заголовок.
          Positioned(
            left: GS.s2,
            bottom: GS.s1,
            child: Text(
              stageName(stage),
              style: GType.label().copyWith(
                fontSize: 8,
                color: GColors.textLo,
              ),
            ),
          ),
        ],
      ),
    );
  }
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

/// То, что стоит в гараже.
typedef _Owned = ({String id, int count, int tier});

/// Полки с аппаратами. Заполняются снизу вверх по мере роста производства.
class _Shelves extends StatelessWidget {
  final List<_Owned> items;
  final double time;
  final double heat;

  const _Shelves({required this.items, required this.time, required this.heat});

  @override
  Widget build(BuildContext context) {
    // Новые аппараты — ближе к зрителю: показываем последние приобретения.
    final shown = items.length > 6 ? items.sublist(items.length - 6) : items;
    final rows = (shown.length / 3).ceil();

    return Padding(
      // Снизу оставляем ровно полосу пола: нижний ряд обязан стоять на полу,
      // а не висеть над ним.
      padding: const EdgeInsets.fromLTRB(GS.s2, GS.s4, GS.s2, kFloorHeight),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (var row = 0; row < rows; row++)
            Expanded(
              child: _ShelfRow(
                items: shown.skip(row * 3).take(3).toList(),
                time: time,
                heat: heat,
                // Нижний ряд стоит на полу — доски под ним не нужно.
                onFloor: row == rows - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _ShelfRow extends StatelessWidget {
  final List<_Owned> items;
  final double time;
  final double heat;
  final bool onFloor;

  const _ShelfRow({
    required this.items,
    required this.time,
    required this.heat,
    required this.onFloor,
  });

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
        if (!onFloor)
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
      child: LayoutBuilder(
        builder: (context, c) {
          // Аппарат подгоняется под высоту полки, а не стоит фиксированным.
          // Раньше ширина была прибита к 56 пикселям, и высокий спрайт в два
          // ряда вылезал за край полки — ровно та «обрезанная вёрстка», на
          // которую жаловался плейтест.
          //
          // Когда места совсем мало, лишнее отбрасывается по порядку
          // важности: сам аппарат нужен всегда, счётчик — почти всегда, пар —
          // украшение. Так сцена сжимается, а не рвётся.
          final available = c.maxHeight;
          final showSteam = available >= 58;
          final showCounter = available >= 36;
          final reserved = (showSteam ? _steamHeight : 0.0) +
              (showCounter ? _counterHeight + 2 : 0.0);
          final forSprite = math.max(6.0, available - reserved);
          final width = math.min(
            _maxStillWidth,
            forSprite * sprite.width / sprite.height,
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (showSteam)
                SizedBox(
                  height: _steamHeight,
                  child: PixelImage(sprite: kSteamFrames[frame], size: width * 0.8),
                ),
              PixelImage(sprite: sprite, size: width, rowShift: shift),
              if (showCounter) ...[
                const SizedBox(height: 2),
                SizedBox(
                  height: _counterHeight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
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
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Что занимает место над и под аппаратом. Вынесено в константы, потому что
/// эти же числа вычитаются из высоты полки — разъедутся, и спрайт снова
/// полезет за край.
const double _steamHeight = 18;
const double _counterHeight = 16;

/// Шире делать незачем: три аппарата в ряд на телефоне и так впритык.
const double _maxStillWidth = 56;
