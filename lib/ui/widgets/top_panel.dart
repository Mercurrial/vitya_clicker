import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/buyers.dart';
import '../../content/events.dart';
import '../../core/formatters.dart';
import '../../engine/market.dart';
import '../../models/game_state.dart';
import '../../providers/game_provider.dart';
import '../game/heat_controller.dart';
import '../theme/content_colors.dart';
import '../theme/garage.dart';
import 'fill_bar.dart';

/// Верх экрана: касса, рынок, бак, сорт и покупатели.
///
/// Здесь становится видно главное решение игры. Раньше была одна кнопка
/// «продать» по абстрактному курсу, и выбора в ней не было. Теперь на экране
/// одновременно: какой сорт сейчас в баке, что с ним делает жар, и что за него
/// дадут трое разных покупателей — включая тех, кто заберёт сорт вместе с
/// товаром.
class TopPanel extends ConsumerStatefulWidget {
  final HeatController heat;
  const TopPanel({super.key, required this.heat});

  @override
  ConsumerState<TopPanel> createState() => _TopPanelState();
}

class _TopPanelState extends ConsumerState<TopPanel>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _shownMoney = 0;
  Duration _prev = Duration.zero;

  @override
  void initState() {
    super.initState();
    _shownMoney = ref.read(gameProvider).resources.money;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration now) {
    final dt = _prev == Duration.zero ? 0.016 : (now - _prev).inMicroseconds / 1e6;
    _prev = now;

    // Касса догоняет плавно: при продаже число не должно прыгать скачком.
    final target = ref.read(gameProvider).resources.money;
    _shownMoney += (target - _shownMoney) * (dt * 9).clamp(0.0, 1.0);

    // Цена и бак меняются непрерывно — перерисовываем каждый кадр.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameProvider);
    // Часы берём из провайдера, а не из DateTime.now(). От времени тут зависит
    // не только цена, но и то, стоит ли в гараже гость, — а появление целой
    // карточки сделало бы снимок экрана флакающим: тест то ловил бы событие,
    // то нет, в зависимости от того, в какую минуту его запустили.
    final now = ref.read(timeProvider)();
    final price = Market.pricePerLitre(now, state.upgrades) * state.sort.multiplier;
    final rising = Market.wave(now) >= 1.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s3, GS.s2, GS.s3, GS.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CashAndMarket(money: _shownMoney, price: price, rising: rising),
          const SizedBox(height: GS.s2),
          _TankBar(state: state),
          const SizedBox(height: GS.s2),
          _SortStrip(state: state, heat: widget.heat),
          const SizedBox(height: GS.s2),
          _BuyerRow(state: state, now: now),
        ],
      ),
    );
  }
}

/// Касса слева, рынок справа.
class _CashAndMarket extends StatelessWidget {
  final double money;
  final double price;
  final bool rising;

  const _CashAndMarket({
    required this.money,
    required this.price,
    required this.rising,
  });

  @override
  Widget build(BuildContext context) {
    final trendColor = rising ? GColors.green : GColors.hot;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('КАССА', style: GType.label()),
              Text(
                Fmt.money(money),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GType.num(
                  size: 30,
                  weight: FontWeight.w700,
                  color: GColors.textHi,
                  letterSpacing: -0.5,
                  shadows: const [Shadow(color: GColors.amberGlow, blurRadius: 20)],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: GS.s2),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('РЫНОК', style: GType.label()),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  Fmt.pricePerLitre(price),
                  style: GType.num(size: 14, weight: FontWeight.w700),
                ),
                const SizedBox(width: 4),
                Text(
                  rising ? '▲' : '▼',
                  style: GType.num(size: 11, weight: FontWeight.w600, color: trendColor),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Бак: заливка окрашена в цвет текущего сорта — видно не только сколько
/// налито, но и что именно.
class _TankBar extends StatelessWidget {
  final GameState state;
  const _TankBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final sort = state.sort;
    final full = state.isTankFull;
    final rate = state.mlPerSecond;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FillBar(
          value: state.tankFraction,
          height: 14,
          radius: 7,
          gradient: LinearGradient(
            colors: full
                ? const [GColors.hot, GColors.hot]
                : [sort.current.fromColor, sort.current.toColor],
          ),
          // Насечки, как на мерной таре.
          overlay: const CustomPaint(painter: _TicksPainter()),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${Fmt.volume(state.resources.ml)} / '
                '${Fmt.volume(state.tankCapacity)}'
                '${full ? '' : ' · хватит на ${Fmt.duration(state.tankBuffer)}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GType.num(size: 10, color: GColors.textMid),
              ),
            ),
            const SizedBox(width: GS.s2),
            Text(
              full ? 'БАК ПОЛОН' : Fmt.rate(rate),
              style: GType.num(
                size: 10,
                weight: FontWeight.w500,
                color: full ? GColors.hot : GColors.copper,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TicksPainter extends CustomPainter {
  const _TicksPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x47000000);
    for (var x = size.width / 10; x < size.width; x += size.width / 10) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_TicksPainter oldDelegate) => false;
}

/// Полоса сорта: пипки пройденных ступеней, название, множитель, прогресс и
/// подсказка о том, что сейчас делает жар.
class _SortStrip extends StatelessWidget {
  final GameState state;
  final HeatController heat;

  const _SortStrip({required this.state, required this.heat});

  @override
  Widget build(BuildContext context) {
    // Полоска сорта зависит от жара только цветом подсказки, а он меняется
    // вместе со статусом — раз в несколько секунд. Подписка на сам контроллер
    // перестраивала бы её каждый кадр.
    return ValueListenableBuilder<HeatStatus>(
      valueListenable: heat.statusNotifier,
      builder: (context, status, _) {
        final sort = state.sort;
        final index = sort.index;
        final hintColor = switch (status) {
          HeatStatus.overheated => GColors.hot,
          HeatStatus.inWindow => GColors.green,
          HeatStatus.off => GColors.textLo,
        };

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Пипки: сколько ступеней уже пройдено.
            for (var i = 0; i < 5; i++) ...[
              Container(
                width: 4,
                height: 6.0 + i * 3,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: i <= index
                      ? GColors.amber
                      : const Color(0x21FFFFFF),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
            const SizedBox(width: GS.s1),
            Flexible(
              child: Text(
                sort.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GType.ui(size: 12, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              Fmt.mult(sort.multiplier),
              style: GType.num(
                size: 11,
                weight: FontWeight.w700,
                color: sort.current.toColor,
              ),
            ),
            const SizedBox(width: GS.s2),
            Expanded(
              child: FillBar(
                value: sort.progress,
                height: 3,
                color: sort.current.toColor,
              ),
            ),
            const SizedBox(width: GS.s2),
            Text(
              heat.hint,
              style: GType.ui(size: 9, color: hintColor),
            ),
          ],
        );
      },
    );
  }
}

/// Покупатели: Петрович всегда и гость по случаю.
///
/// Гость появляется сам и уходит по таймеру — карточка одна и та же, меняется
/// только содержимое. Заблокированная карточка показывает, чего не хватает:
/// это и есть подсказка, ради чего стоит доводить сорт.
class _BuyerRow extends ConsumerWidget {
  final GameState state;
  final DateTime now;

  const _BuyerRow({required this.state, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.read(gameEngineProvider);
    final active = eventAt(now);

    Widget card(Buyer buyer, {Duration? countdown}) => _BuyerCard(
          buyer: buyer,
          available: engine.canSellTo(state, buyer),
          payout: engine.saleValueFor(state, buyer, now),
          countdown: countdown,
          onTap: () {
            HapticFeedback.mediumImpact();
            ref.read(gameProvider.notifier).sellTo(buyer);
          },
        );

    return Row(
      children: [
        for (final buyer in kBuyers) Expanded(child: card(buyer)),
        if (active != null) ...[
          const SizedBox(width: 6),
          Expanded(
            child: card(active.event.asBuyer, countdown: active.remaining),
          ),
        ],
      ],
    );
  }
}

class _BuyerCard extends StatefulWidget {
  final Buyer buyer;
  final bool available;
  final double payout;
  final VoidCallback onTap;

  /// Сколько осталось до ухода гостя. `null` — покупатель постоянный.
  final Duration? countdown;

  const _BuyerCard({
    required this.buyer,
    required this.available,
    required this.payout,
    required this.onTap,
    this.countdown,
  });

  @override
  State<_BuyerCard> createState() => _BuyerCardState();
}

class _BuyerCardState extends State<_BuyerCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.available;
    // Премиальные покупатели подсвечиваются: их доступность — событие.
    final hot = on && widget.buyer.multiplier > 1.0;
    final left = widget.countdown;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: on ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: on ? (hot ? null : GColors.surface2) : const Color(0x3D000000),
            gradient: hot
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3A2A16), GColors.surface2],
                  )
                : null,
            border: Border.all(
              color: hot
                  ? GColors.amber
                  : (on ? GColors.border : const Color(0x14FFFFFF)),
            ),
            boxShadow: hot
                ? const [BoxShadow(color: GColors.amberGlow, blurRadius: 16)]
                : GShadow.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      widget.buyer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GType.ui(
                        size: 11,
                        weight: FontWeight.w600,
                        color: on ? GColors.textHi : GColors.textLo,
                      ),
                    ),
                  ),
                  Text(
                    // У гостя вместо множителя — срок. Множитель он и так
                    // отрабатывает суммой ниже, а вот что он уйдёт — надо
                    // сказать прямо.
                    left != null ? Fmt.duration(left) : '×${widget.buyer.multiplier}',
                    style: GType.num(
                      size: 9,
                      weight: FontWeight.w700,
                      color: left != null
                          ? GColors.lamp
                          : (on ? GColors.brew : GColors.textLo),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                on ? Fmt.money(widget.payout) : '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GType.num(
                  size: 12,
                  weight: FontWeight.w700,
                  color: hot
                      ? GColors.lamp
                      : (on ? GColors.textHi : const Color(0xFF4E443A)),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                on ? widget.buyer.note : widget.buyer.lockedNote,
                // Ровно одна строка, и не «до двух». При двух карточка гостя
                // становилась выше карточки Петровича, панель подрастала — и
                // на экране 320×640 вёрстка переполнялась на два пикселя.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GType.ui(
                  size: 9,
                  color: hot ? GColors.lamp : (on ? GColors.textMid : GColors.textLo),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
