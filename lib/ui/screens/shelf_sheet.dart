import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sfx.dart';
import '../../providers/feedback_provider.dart';
import '../theme/garage.dart';

/// Два положения шторки магазина (docs/DECISIONS.md, «Главный экран»).
enum ShelfPosition {
  /// По умолчанию: магазин на половину экрана, над ним живой гараж.
  garage,

  /// Магазин почти на весь экран. У Вити заняты руки: жар, серия и сорт
  /// стоят (см. HeatController.paused).
  shop,
}

/// Где сейчас шторка. В провайдере, а не в состоянии виджета: от неё
/// зависит пауза жара, и её же переключает полоска над развёрнутым
/// магазином.
///
/// В сейв не пишется: каждый заход начинается с гаража. Открыться сразу в
/// магазине значило бы открыться на паузе.
final shelfPositionProvider = StateProvider<ShelfPosition>((ref) => ShelfPosition.garage);

/// Высота магазина в положении «Гараж» для экрана высотой [height].
///
/// Половина экрана — цель владельца «не меньше 50 % при 390×844». Но сцене
/// и пульту над магазином нужно своё: на телефоне с адресной строкой
/// (390×740) половина экрана сжимала сцену так, что первая банка выходила
/// ростом в сантиметр. Поэтому магазин берёт меньшее из «половины» и
/// «всего, что оставили верх и гараж», — и никогда не меньше двух строк
/// списка.
double shelfGarageHeight(double height) {
  final half = height * _kGarageShare;
  final leftover = height - kTopPanelHeight - kGarageZoneMin;
  return math.max(kShelfMinHeight, math.min(half, leftover));
}

/// Высота магазина в положении «Магазин»: весь экран, кроме полоски сверху.
double shelfShopHeight(double height) => height - kShopStripHeight;

/// Доля экрана под магазином в положении «Гараж». С запасом над 50 %:
/// ровно половина при округлении вёрстки оказывалась бы 49.9.
const double _kGarageShare = 0.505;

/// Высота верха (касса, рынок, бак, продажа) без гостя. Оценка, которую
/// проверяет test/shelf_sheet_test.dart: верх вырос — тест скажет.
const double kTopPanelHeight = 100;

/// Меньше этого гаражу со сценой и пультом не отдаём: сцене остаётся около
/// 210 точек. При 180 первая банка на полу выходила в 32 точки ростом —
/// тест вёрстки требует не меньше 40, а глазом её было не найти.
const double kGarageZoneMin = 300;

/// Меньше этого магазину не отдаём: вкладки и две строки аппаратов.
const double kShelfMinHeight = 240;

/// Высота полоски над развёрнутым магазином (см. ShopStrip).
const double kShopStripHeight = 48;

/// Сколько хватательной зоны шторки выступает над её краем.
///
/// Ручка шторки — кнопка, и ей положено 44 точки. Рисовать 44 точки ручки
/// значило отнять их у списка; поэтому видимая ручка низкая, а ловит палец
/// и прозрачная полоса над ней — поверх нижнего поля гаража, где нечего
/// зажимать.
const double kShelfGrabOverhang = 16;

/// Видимая часть ручки над вкладками.
const double _kGrabberHeight = 28;

/// Шторка магазина: два положения, тянется пальцем, щёлкает по ручке.
///
/// Растягивается на весь экран под верхом, но ловит касания только своей
/// частью: всё, что выше неё, остаётся гаражу.
class ShelfSheet extends ConsumerStatefulWidget {
  /// Содержимое — вкладки и списки.
  final Widget child;

  /// Полоска над развёрнутым магазином.
  final Widget strip;

  const ShelfSheet({super.key, required this.child, required this.strip});

  @override
  ConsumerState<ShelfSheet> createState() => _ShelfSheetState();
}

class _ShelfSheetState extends ConsumerState<ShelfSheet>
    with SingleTickerProviderStateMixin {
  /// 0 — «Гараж», 1 — «Магазин».
  late final AnimationController _t;

  /// Сколько точек между положениями — для перевода пальца в долю хода.
  double _travel = 1;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: ref.read(shelfPositionProvider) == ShelfPosition.shop ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _settle(ShelfPosition to) {
    final notifier = ref.read(shelfPositionProvider.notifier);
    if (notifier.state != to) {
      ref.read(feedbackProvider).buzz(Buzz.select);
      notifier.state = to;
    }
    _animateTo(to);
  }

  void _animateTo(ShelfPosition to) {
    _t.animateTo(to == ShelfPosition.shop ? 1 : 0, curve: gEase);
  }

  void _toggle() => _settle(
        ref.read(shelfPositionProvider) == ShelfPosition.shop
            ? ShelfPosition.garage
            : ShelfPosition.shop,
      );

  /// Где была шторка, когда палец её взял.
  double _dragFrom = 0;

  void _onDragStart(DragStartDetails d) => _dragFrom = _t.value;

  void _onDragUpdate(DragUpdateDetails d) {
    _t.value = (_t.value - d.delta.dy / _travel).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    final moved = _t.value - _dragFrom;
    // Бросок решает раньше положения: смахнул вверх — значит, в магазин,
    // даже если палец прошёл треть пути.
    //
    // Но только если бросок туда же, куда палец и тянул. Скорость
    // оценивается по отметкам времени событий, и в браузере они бывают
    // кривыми: шторку тянули вниз, а скорость пришла −8000, «вверх», — и
    // шторка возвращалась в магазин, сколько её ни тяни.
    final agrees = moved == 0 || (v < 0) == (moved > 0);
    final ShelfPosition to;
    if (v.abs() > 400 && agrees) {
      to = v < 0 ? ShelfPosition.shop : ShelfPosition.garage;
    } else {
      to = _t.value > 0.5 ? ShelfPosition.shop : ShelfPosition.garage;
    }
    _settle(to);
  }

  @override
  Widget build(BuildContext context) {
    // Положение могли сменить снаружи — полоской над магазином.
    ref.listen(shelfPositionProvider, (_, to) => _animateTo(to));

    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final low = shelfGarageHeight(h);
        final high = shelfShopHeight(h);
        _travel = math.max(1, high - low);

        return AnimatedBuilder(
          animation: _t,
          child: _SheetBody(
            onToggle: _toggle,
            onDragStart: _onDragStart,
            onDragUpdate: _onDragUpdate,
            onDragEnd: _onDragEnd,
            child: widget.child,
          ),
          builder: (context, body) {
            final t = _t.value;
            final sheetH = lerpDouble(low, high, t)!;
            // Состав детей постоянный, даже когда затемнение и полоска не
            // видны. Сначала их добавляли условием «t > 0» — и на первом же
            // сдвиге пальца шторка съезжала в списке детей с первого места
            // на третье, Flutter пересобирал её заново вместе с жестом, и
            // шторка застревала посередине.
            return Stack(
              children: [
                // Гараж под развёрнутым магазином гаснет: видно, что он
                // никуда не делся, но сейчас не до него.
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(color: Color.fromRGBO(0, 0, 0, 0.55 * t)),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: kShopStripHeight,
                  child: IgnorePointer(
                    ignoring: t < 0.5,
                    child: Opacity(
                      opacity: t,
                      child: ColoredBox(color: GColors.bg, child: widget.strip),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: sheetH + kShelfGrabOverhang,
                  child: body!,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Сама шторка: ручка, вкладки, список.
class _SheetBody extends StatelessWidget {
  final VoidCallback onToggle;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final Widget child;

  const _SheetBody({
    required this.onToggle,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Тянуть можно за всю шапку — ручку и вкладки: в ручку на ходу не
    // попасть. Касание по вкладке остаётся касанием: жест решает, тянут
    // или жмут, по тому, сдвинулся ли палец.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // Путь пальца считается от касания, а не от порога, после которого
      // жест признан перетаскиванием. По умолчанию путь до порога теряется,
      // и быстрый рывок, уложившийся в одно событие, не двигал шторку вовсе.
      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragStart: onDragStart,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ручка — кнопка: прозрачная полоса над краем и видимая ручка
          // вместе дают 44 точки.
          Semantics(
            button: true,
            label: 'магазин',
            child: GestureDetector(
              key: const ValueKey('shelf-grabber'),
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: SizedBox(
                height: kShelfGrabOverhang + _kGrabberHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: kShelfGrabOverhang),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: GColors.surface1,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(GR.sheet - 6)),
                          boxShadow: GShadow.sheet,
                          border: Border(top: BorderSide(color: GColors.hairline)),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: GColors.border,
                            borderRadius: BorderRadius.circular(GR.pill),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ColoredBox(color: GColors.surface1, child: child),
          ),
        ],
      ),
    );
  }
}
