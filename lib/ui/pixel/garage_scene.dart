import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/game_provider.dart';
import '../game/heat_controller.dart';
import '../theme/garage.dart';
import 'garage_room.dart';
import 'pixel_sprite.dart';
import 'still_sprites.dart';

/// Гараж Вити — сцена, а не список.
///
/// Главная задача: **империю должно быть видно**. Пока покупка меняла лишь
/// число в таблице, игра ощущалась как ведомость. Здесь каждый купленный
/// аппарат физически стоит в гараже: три новейших — крупно на полу, старшие
/// по возрасту перебираются на полки по бокам от портрета.
///
/// Все аппараты рисуются **одним размером пикселя**. Раньше каждый подгонялся
/// под свою ячейку, и банка выходила крупнее цистерны; теперь цистерна
/// действительно больше, и рост дела читается по силуэтам на полу.
class GarageScene extends ConsumerStatefulWidget {
  /// Жар приходит КОНТРОЛЛЕРОМ, а не числом: на него подписаны только те,
  /// кто от него рисуется, — лампа и аппараты. Обёртка над всей сценой
  /// перестраивала бы её шестьдесят раз в секунду.
  final HeatController heat;

  /// Портрет Вити под заданный размер рамы. Размер решает сцена: она знает,
  /// сколько у неё высоты и сколько надо оставить аппаратам.
  final Widget Function(double size) portrait;

  const GarageScene({super.key, required this.heat, required this.portrait});

  @override
  ConsumerState<GarageScene> createState() => _GarageSceneState();
}

class _GarageSceneState extends ConsumerState<GarageScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _prev = Duration.zero;

  /// Время сцены живёт в уведомителе, а не в поле состояния: кадр двигает
  /// одно число, и перерисовываются только подписанные на него художники.
  final ValueNotifier<double> _time = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration now) {
    final dt = _prev == Duration.zero ? 0.016 : (now - _prev).inMicroseconds / 1e6;
    _prev = now;
    _time.value += dt;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owned = ref.watch(
      gameProvider.select(
        (s) => _OwnedList([
          for (var i = 0; i < s.generators.items.length; i++)
            if (s.generators.items[i].ownedCount > 0)
              (id: s.generators.items[i].id, count: s.generators.items[i].ownedCount, tier: i),
        ]),
      ),
    ).items;

    // Помещение — по старшему аппарату: банка и коллайдер не стоят в одной
    // комнате.
    final stage = stageForTier(owned.isEmpty ? 0 : owned.last.tier);

    return ClipRRect(
      borderRadius: BorderRadius.circular(GR.card),
      child: Stack(
        children: [
          // Комната рисуется один раз на стадию: её painter возвращает
          // shouldRepaint == false.
          Positioned.fill(child: RoomBackground(stage: stage)),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, c) => _SceneLayout(
                size: c.biggest,
                owned: owned,
                portrait: widget.portrait,
                time: _time,
                heat: widget.heat,
              ),
            ),
          ),
          // Лампа — поверх аппаратов: её свет ложится и на них.
          Positioned.fill(
            child: IgnorePointer(
              child: ListenableBuilder(
                listenable: Listenable.merge([_time, widget.heat]),
                builder: (_, __) => SwingingLamp(
                  time: _time.value,
                  heat: widget.heat.heat,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// То, что стоит в гараже.
typedef _Owned = ({String id, int count, int tier});

/// Список со сравнением по содержимому.
///
/// Селектор Riverpod сравнивает результат через `==`, а у двух списков с
/// одинаковым содержимым оно ложно. Без обёртки сцена перестраивалась на
/// каждом тике игры — десять раз в секунду, хотя купленное не менялось.
class _OwnedList {
  final List<_Owned> items;
  const _OwnedList(this.items);

  @override
  bool operator ==(Object other) =>
      other is _OwnedList && listEquals(other.items, items);

  @override
  int get hashCode => Object.hashAll(items);
}

/// Раскладка сцены: портрет на стене, полки по бокам, аппараты на полу.
///
/// Всё считается от размера сцены, а не прибито числами: сцена живёт и на
/// 320×640, и на планшете, и в обоих случаях аппараты обязаны помещаться.
class _SceneLayout extends StatelessWidget {
  final Size size;
  final List<_Owned> owned;
  final Widget Function(double size) portrait;
  final ValueListenable<double> time;
  final HeatController heat;

  const _SceneLayout({
    required this.size,
    required this.owned,
    required this.portrait,
    required this.time,
    required this.heat,
  });

  /// Сколько новейших аппаратов стоит на полу.
  static const int _onFloor = 3;

  /// Сколько помещается на одну полку.
  static const int _perShelf = 3;

  @override
  Widget build(BuildContext context) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return const SizedBox.shrink();

    final floorY = h - kFloorHeight;

    // Портрет — треть высоты, но не мельче, чем его можно узнать.
    final frame = (h * 0.34).clamp(64.0, 112.0).floorToDouble();
    final frameH = frame * 1.1;
    const portraitTop = 10.0;
    final plaqueBottom = portraitTop + frameH + 26;

    final floor = owned.length > _onFloor ? owned.sublist(owned.length - _onFloor) : owned;
    final older = owned.length > _onFloor ? owned.sublist(0, owned.length - _onFloor) : <_Owned>[];
    // На полках — самые свежие из старших, по три с каждой стороны.
    final shelved = older.length > _perShelf * 2
        ? older.sublist(older.length - _perShelf * 2)
        : older;
    final left = shelved.take(_perShelf).toList();
    final right = shelved.skip(_perShelf).toList();

    // --- Пол -------------------------------------------------------------
    final floorPixel = _fitPixel(
      floor,
      width: w - 24,
      height: floorY + 4 - plaqueBottom - _tagSpace,
      max: 5,
      onFloor: true,
    );

    // --- Полки -----------------------------------------------------------
    final shelfY = (portraitTop + frameH - 2).floorToDouble();
    final sideW = (w - frame) / 2 - 20;
    // Над аппаратом на полке висит бирка — оставляем ей место.
    final shelfPixel = math.min(
      floorPixel,
      math.min(
        _fitPixel(left, width: sideW, height: shelfY - 30, max: 3),
        _fitPixel(right, width: sideW, height: shelfY - 30, max: 3),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Полки висят всегда, даже пустые: пустая полка — это обещание, что
        // на ней что-то появится.
        for (final side in [0, 1])
          Positioned(
            left: side == 0 ? 10 : null,
            right: side == 1 ? 10 : null,
            top: shelfY,
            width: sideW,
            child: const _ShelfBoard(),
          ),
        for (final (side, items) in [(0, left), (1, right)])
          if (items.isNotEmpty)
            Positioned(
              left: side == 0 ? 10 : null,
              right: side == 1 ? 10 : null,
              width: sideW,
              bottom: h - shelfY,
              child: _Row(
                items: items,
                pixel: shelfPixel,
                time: time,
                heat: heat,
                steam: false,
                tagBelow: false,
              ),
            ),
        Positioned(
          top: portraitTop,
          left: 0,
          right: 0,
          child: Center(child: portrait(frame)),
        ),
        if (floor.isEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: kFloorHeight + 16,
            child: Text(
              'Пусто. Купи первую банку.',
              textAlign: TextAlign.center,
              style: GType.body(),
            ),
          )
        else
          Positioned(
            left: 12,
            right: 12,
            // Основания стоят чуть ниже кромки пола — так предметы стоят НА
            // полу, а не на линии стены.
            bottom: h - floorY - 4,
            child: _Row(
              items: floor,
              pixel: floorPixel,
              time: time,
              heat: heat,
              steam: true,
              tagBelow: true,
            ),
          ),
      ],
    );
  }

  /// Место под бирку с количеством под аппаратами на полу.
  static const double _tagSpace = 6;

  /// Крупнейший целый пиксель, при котором ряд помещается в заданную область.
  static double _fitPixel(
    List<_Owned> items, {
    required double width,
    required double height,
    required double max,
    bool onFloor = false,
  }) {
    if (items.isEmpty) return max;
    var spriteW = 0.0;
    var spriteH = 0.0;
    for (final it in items) {
      final s = stillSpriteFor(it.id);
      spriteW += s.width + _gap;
      spriteH = math.max(
        spriteH,
        s.height + (onFloor ? (stillHasFire(it.id) ? _fireRows : 0) + _steamRows : 0),
      );
    }
    final byW = width / spriteW;
    final byH = height / spriteH;
    // Шаг в полточки — см. PixelPainter: на телефоне это целые пиксели.
    return (math.min(byW, byH) * 2).floorToDouble().clamp(2.0, max * 2) / 2;
  }

  /// Зазор между аппаратами в пикселях спрайта.
  static const double _gap = 4;
}

/// Сколько строк спрайта занимает огонь под аппаратом.
const double _fireRows = 4;

/// Сколько строк занимает пар над аппаратом.
const double _steamRows = 4;

/// Доска полки на кронштейнах.
class _ShelfBoard extends StatelessWidget {
  const _ShelfBoard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 6,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF5A3D25),
                border: Border(
                  top: BorderSide(color: Color(0xFF8A6440), width: 2),
                  bottom: BorderSide(color: Color(0xFF2E1E12), width: 2),
                ),
              ),
            ),
          ),
          // Тень доски на стене.
          const Positioned(
            left: 2,
            right: 2,
            top: 6,
            height: 4,
            child: ColoredBox(color: Color(0x40000000)),
          ),
          for (final a in const [0.12, 0.84])
            Positioned(
              left: 0,
              right: 0,
              top: 6,
              child: Align(
                alignment: Alignment(a * 2 - 1, -1),
                child: const SizedBox(
                  width: 4,
                  height: 8,
                  child: ColoredBox(color: Color(0xFF2E2822)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ряд аппаратов одного масштаба, выровненный по основанию.
class _Row extends StatelessWidget {
  final List<_Owned> items;
  final double pixel;
  final ValueListenable<double> time;
  final HeatController heat;
  final bool steam;

  /// Бирка под аппаратом (на полу) или на нём самом (на полке, где под ним
  /// доска).
  final bool tagBelow;

  const _Row({
    required this.items,
    required this.pixel,
    required this.time,
    required this.heat,
    required this.steam,
    required this.tagBelow,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final it in items)
          _Still(
            id: it.id,
            count: it.count,
            pixel: pixel,
            time: time,
            heat: heat,
            steam: steam,
            tagBelow: tagBelow,
          ),
      ],
    );
  }
}

/// Один аппарат: пар, корпус, огонь, бирка с количеством.
class _Still extends StatelessWidget {
  final String id;
  final int count;
  final double pixel;
  final ValueListenable<double> time;
  final HeatController heat;
  final bool steam;
  final bool tagBelow;

  const _Still({
    required this.id,
    required this.count,
    required this.pixel,
    required this.time,
    required this.heat,
    required this.steam,
    required this.tagBelow,
  });

  @override
  Widget build(BuildContext context) {
    final sprite = stillSpriteFor(id);
    // На полке огня нет: горящая полка читается как пожар, а не как работа.
    final fire = steam && stillHasFire(id);
    final spriteW = sprite.width * pixel;
    final fireH = fire ? _fireRows * pixel : 0.0;
    final steamPixel = math.max(1.0, (pixel * 0.75).floorToDouble());

    final body = ListenableBuilder(
      listenable: Listenable.merge([time, heat]),
      builder: (_, __) {
        final status = heat.status;
        final inWindow = status == HeatStatus.inWindow;
        final overheated = status == HeatStatus.overheated;
        // Кипение ускоряется вместе с жаром — видно, что палец что-то делает.
        final speed = 1.0 + heat.heat;
        final t = time.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (steam)
              SizedBox(
                height: _steamRows * pixel,
                child: PixelImage.scaled(
                  sprite: kSteamFrames[(t * 2.2 * speed).floor() % kSteamFrames.length],
                  pixel: steamPixel,
                  palette: kStillPalette,
                ),
              ),
            PixelImage.scaled(
              sprite: sprite,
              pixel: pixel,
              palette: stillPaletteFor(inWindow: inWindow, overheated: overheated),
            ),
            if (fire)
              SizedBox(
                width: spriteW,
                height: fireH,
                child: Center(
                  child: PixelImage.scaled(
                    sprite: () {
                      final frames = fireFramesFor(inWindow: inWindow, overheated: overheated);
                      return frames[(t * 9 * speed).floor() % frames.length];
                    }(),
                    pixel: pixel,
                    palette: kStillPalette,
                  ),
                ),
              ),
          ],
        );
      },
    );


    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // Контактная тень: без неё предмет висит в воздухе.
        Positioned(
          bottom: -3,
          child: Container(
            width: spriteW * 0.9,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0x66000000),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        body,
        // На полу бирка — под аппаратом, на полосе пола. На полке под
        // аппаратом доска, а ниже — табличка портрета, поэтому там бирка
        // висит над ним.
        Positioned(
          bottom: tagBelow ? -18 : null,
          top: tagBelow ? null : -15,
          child: _CountTag(count: count, small: !tagBelow),
        ),
      ],
    );
  }
}

/// Сколько штук этого аппарата у Вити.
class _CountTag extends StatelessWidget {
  final int count;
  final bool small;
  const _CountTag({required this.count, required this.small});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 3 : 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xE6120D09),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x33E8A33D)),
      ),
      child: Text(
        '×$count',
        maxLines: 1,
        softWrap: false,
        style: GType.num(
          size: small ? 9 : 10,
          weight: FontWeight.w700,
          color: GColors.amber,
        ),
      ),
    );
  }
}
