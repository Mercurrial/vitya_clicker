import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/buyers.dart';
import '../../content/events.dart';
import '../../content/expenses.dart';
import '../../content/sorts.dart';
import '../../core/formatters.dart';
import '../../engine/market.dart';
import '../../models/game_state.dart';
import '../../providers/game_provider.dart';
import '../theme/content_colors.dart';
import '../theme/garage.dart';
import 'fill_bar.dart';
import 'trend_arrow.dart';

/// Верх экрана: касса, рынок, бак и продажа.
///
/// Здесь живёт вторая половина петли: нагнал → **продал** → купил. Продажа
/// поэтому не карточка с подписью, а кнопка — янтарная, как всё, что можно
/// нажать и получить деньги. Прошлая версия рисовала Петровича серой плашкой,
/// и главное действие игры выглядело как справка.
class TopPanel extends ConsumerStatefulWidget {
  const TopPanel({super.key});

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
    final next = _shownMoney + (target - _shownMoney) * (dt * 9).clamp(0.0, 1.0);
    // Перерисовываемся, только пока касса действительно едет. Цена и бак
    // приходят сами — с тиком игры через ref.watch.
    if ((next - _shownMoney).abs() > target.abs() * 1e-6 + 1e-3) {
      _shownMoney = next;
      if (mounted) setState(() {});
    } else if (_shownMoney != target) {
      _shownMoney = target;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameProvider);
    // Часы берём из провайдера, а не из DateTime.now(). От времени тут зависит
    // не только цена, но и то, стоит ли в гараже гость, — а появление целой
    // карточки сделало бы снимок экрана флакающим.
    final now = ref.read(timeProvider)();
    final price = Market.pricePerLitre(now, state.upgrades) * state.sort.multiplier;
    final rising = Market.wave(now) >= 1.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s4, GS.s2, GS.s4, GS.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CashAndMarket(
            money: _shownMoney,
            price: price,
            rising: rising,
            good: Market.isGoodMoment(now),
          ),
          const SizedBox(height: GS.s2),
          _TankBar(state: state),
          const SizedBox(height: GS.s3),
          _SellRow(state: state, now: now),
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

  /// Рынок заметно выше обычного — самое время сдавать.
  final bool good;

  const _CashAndMarket({
    required this.money,
    required this.price,
    required this.rising,
    required this.good,
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
                // Касса тикает каждый кадр — нули не срезаем, иначе ширина
                // числа прыгает туда-сюда.
                Fmt.money(money, trim: false),
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
            Text(good ? 'РЫНОК · ВЫГОДНО' : 'РЫНОК', style: GType.label().copyWith(
              color: good ? GColors.green : null,
            )),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  Fmt.pricePerLitre(price),
                  style: GType.num(size: 16, weight: FontWeight.w700),
                ),
                const SizedBox(width: 5),
                TrendArrow(up: rising, color: trendColor, size: 10),
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
    final room = state.tankCapacity - state.resources.ml;

    // Главный вопрос к баку — «когда он встанет», а не «сколько в него
    // влезает». Прошлая подпись «хватит на 30 мин» показывала ёмкость в
    // минутах производства и читалась как оставшееся время. Оно не убывало.
    final String status;
    if (full) {
      status = 'полный — аппараты стоят';
    } else if (rate > 0) {
      status = 'полный через ${Fmt.duration(Duration(seconds: (room / rate).ceil()))}';
    } else {
      status = '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('БАК', style: GType.label()),
            const SizedBox(width: GS.s2),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: Fmt.volume(state.resources.ml, trim: false),
                    style: GType.num(size: 12, weight: FontWeight.w700, color: GColors.textHi),
                  ),
                  TextSpan(
                    text: ' / ${Fmt.volume(state.tankCapacity)}',
                    style: GType.num(size: 11, color: GColors.textMid),
                  ),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '+${Fmt.rate(rate, trim: false)}',
              style: GType.num(size: 11, weight: FontWeight.w600, color: GColors.copper),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FillBar(
          value: state.tankFraction,
          height: 12,
          radius: 6,
          gradient: LinearGradient(
            colors: full
                ? const [GColors.hot, Color(0xFFFF7A5C)]
                : [sort.current.fromColor, sort.current.toColor],
          ),
          // Насечки, как на мерной таре.
          overlay: const CustomPaint(painter: _TicksPainter()),
        ),
        const SizedBox(height: 3),
        Text(
          status,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GType.num(
            size: 10,
            weight: full ? FontWeight.w700 : FontWeight.w400,
            color: full ? GColors.hot : GColors.textLo,
          ),
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
    for (var x = size.width / 10; x < size.width - 1; x += size.width / 10) {
      canvas.drawRect(Rect.fromLTWH(x.floorToDouble(), 0, 1, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_TicksPainter oldDelegate) => false;
}

/// Продажа: Петрович всегда, гость — когда пришёл.
///
/// Гость появляется сам и уходит по таймеру. Пока сорт не дотягивает, его
/// кнопка показывает, чего не хватает: это и есть подсказка, ради чего
/// стоит доводить сорт.
class _SellRow extends ConsumerWidget {
  final GameState state;
  final DateTime now;

  const _SellRow({required this.state, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.read(gameEngineProvider);
    final active = eventAt(now);
    // Тёща у Петровича: сбивает цену ему, и только ему.
    final expense = expenseAt(now);
    final cut = expense != null && expense.expense.kind == ExpenseKind.neighbor
        ? expense
        : null;
    final petrovich = kBuyers.first;
    final guest = active?.event.asBuyer;
    final payout = engine.saleValueFor(state, petrovich, now);
    // Кнопка горит, только когда за бак дадут хотя бы рубль. Иначе в первые
    // секунды игры самым ярким на экране была «ПРОДАТЬ · 0 ₽» — и новичок
    // жал её вместо того, чтобы зажать гараж.
    final worth = payout >= 1;

    final main = SellButton(
      title: guest == null ? 'ПРОДАТЬ ПЕТРОВИЧУ' : 'ПЕТРОВИЧУ',
      note: cut != null
          ? '${cut.expense.note} · ${Fmt.clock(cut.remaining)}'
          : (worth ? petrovich.note : 'бак почти пуст — пусть нальётся'),
      noteAlert: cut != null,
      payout: payout,
      available: worth && engine.canSellTo(state, petrovich),
      premium: false,
      compact: guest != null,
      // Звук и вибрация — внутри sellTo: сделка может не состояться.
      onTap: () => ref.read(gameProvider.notifier).sellTo(petrovich),
    );

    if (guest == null) return main;

    final canGuest = engine.canSellTo(state, guest);
    return Row(
      children: [
        Expanded(flex: 5, child: main),
        const SizedBox(width: GS.s2),
        Expanded(
          flex: 6,
          child: SellButton(
            title: guest.name.toUpperCase(),
            // Пока не берут — их собственная реплика («не первач же»): она
            // объясняет отказ лучше таблицы. Когда берут — во сколько раз
            // дороже Петровича.
            note: canGuest
                ? '${Fmt.mult(guest.multiplier)} · ещё ${Fmt.clock(active!.remaining)}'
                : '${guest.lockedNote} · ${Fmt.clock(active!.remaining)}',
            noteAlert: false,
            payout: engine.saleValueFor(state, guest, now),
            // Пока сорт не дотягивает, вместо суммы — чего не хватает. Это и
            // есть подсказка, ради чего стоит доводить сорт.
            lockedAmount: canGuest ? null : _needSort(guest),
            available: canGuest,
            premium: true,
            compact: true,
            onTap: () => ref.read(gameProvider.notifier).sellTo(guest),
          ),
        ),
      ],
    );
  }

  /// «сорт от „На кедраче“» — конкретная цель вместо «сорт получше».
  static String _needSort(Buyer b) {
    final i = b.minSortIndex.clamp(0, kSorts.length - 1);
    return 'сорт от «${kSorts[i].name}»';
  }
}

/// Кнопка продажи.
///
/// Янтарная, пока есть что сдать, — по правилу всей игры: янтарь значит
/// «можно нажать и получить». Гость подсвечен ярче: он платит втрое и уходит.
class SellButton extends StatefulWidget {
  final String title;
  final String note;
  final bool noteAlert;
  final double payout;
  final bool available;
  final bool premium;
  final bool compact;

  /// Что написать на месте суммы, пока продать нельзя. `null` — прочерк.
  final String? lockedAmount;
  final VoidCallback onTap;

  const SellButton({
    super.key,
    required this.title,
    required this.note,
    required this.noteAlert,
    required this.payout,
    required this.available,
    required this.premium,
    required this.compact,
    required this.onTap,
    this.lockedAmount,
  });

  @override
  State<SellButton> createState() => _SellButtonState();
}

class _SellButtonState extends State<SellButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.available;
    final premium = widget.premium;
    final fg = on ? GColors.onAmber : GColors.textLo;

    final locked = widget.lockedAmount;
    final amount = !on && locked != null
        ? Text(
            locked,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GType.ui(size: 11, weight: FontWeight.w600, color: GColors.amberDim),
          )
        : Text(
            on ? Fmt.money(widget.payout) : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GType.num(
              size: widget.compact ? 14 : 18,
              weight: FontWeight.w700,
              color: on ? GColors.onAmber : GColors.textLo,
            ),
          );

    final title = Text(
      widget.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GType.ui(
        size: widget.compact ? 10 : 11,
        weight: FontWeight.w700,
        color: fg,
        letterSpacing: 0.8,
      ),
    );

    final note = Text(
      widget.note,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GType.ui(
        size: 10,
        weight: widget.noteAlert ? FontWeight.w700 : FontWeight.w500,
        color: widget.noteAlert
            ? (on ? const Color(0xFF7A2410) : GColors.hot)
            : (on ? const Color(0xB32B1A06) : GColors.textLo),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: on ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: widget.compact ? 58 : 54,
          padding: const EdgeInsets.symmetric(horizontal: GS.s3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GR.button),
            gradient: on
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: premium
                        ? const [GColors.lamp, GColors.amber]
                        : const [GColors.amber, GColors.amberDim],
                  )
                : null,
            color: on ? null : GColors.wellBg,
            border: Border.all(
              color: on
                  ? (premium ? GColors.lamp : const Color(0x00000000))
                  : (premium ? const Color(0x55E8A33D) : GColors.border),
            ),
            boxShadow: on
                ? [
                    BoxShadow(
                      color: premium ? const Color(0x80FFD089) : GColors.amberGlow,
                      blurRadius: premium ? 22 : 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          // Узкая кнопка — в три строки: имя, сумма, условие. В две строки
          // сумма выдавливала имя в многоточие («ПЕТРОВИ…»).
          child: widget.compact
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, amount, note],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, const SizedBox(height: 2), note],
                      ),
                    ),
                    const SizedBox(width: GS.s2),
                    amount,
                  ],
                ),
        ),
      ),
    );
  }
}
