import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/buyers.dart';
import '../../content/events.dart';
import '../../content/sorts.dart';
import '../../core/formatters.dart';
import '../../engine/game_engine.dart';
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
      padding: const EdgeInsets.fromLTRB(GS.s4, 6, GS.s4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CashAndMarket(
            money: _shownMoney,
            price: price,
            rising: rising,
            good: Market.isGoodMoment(now),
          ),
          const SizedBox(height: 6),
          _SellRow(state: state, now: now),
        ],
      ),
    );
  }
}

/// Касса слева, рынок справа — одной строкой.
///
/// Подписи «КАССА» больше нет: число с рублём и так говорит, что это. Она
/// стоила строки, а высота верха — это высота магазина под ним (см.
/// docs/DECISIONS.md, «Главный экран»).
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
      children: [
        Expanded(
          // Касса ужимается, а не обрезается. На 320 точках «РЫНОК ·
          // ВЫГОДНО» забирал столько ширины, что главное число игры
          // выходило «8.75Скс…» — без рублей и без последней цифры.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              // Касса тикает каждый кадр — нули не срезаем, иначе ширина
              // числа прыгает туда-сюда.
              Fmt.money(money, trim: false),
              maxLines: 1,
              style: GType.num(
                size: 24,
                weight: FontWeight.w700,
                color: GColors.textHi,
                letterSpacing: -0.5,
                shadows: const [Shadow(color: GColors.amberGlow, blurRadius: 20)],
              ),
            ),
          ),
        ),
        const SizedBox(width: GS.s2),
        // Рынок — одной строкой с подписью: подпись над ценой делала
        // строку кассы на шесть точек выше, а их забирал у магазина.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Подпись и цена — по базовой линии; стрелка — по центру: у
            // рисунка базовой линии нет, и в общем ряду он улетал вверх.
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(good ? 'ВЫГОДНО' : 'РЫНОК', style: GType.label().copyWith(
                  color: good ? GColors.green : null,
                )),
                const SizedBox(width: 6),
                Text(
                  Fmt.pricePerLitre(price),
                  style: GType.num(size: 15, weight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(width: 5),
            TrendArrow(up: rising, color: trendColor, size: 10),
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
      mainAxisSize: MainAxisSize.min,
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
          ],
        ),
        const SizedBox(height: 3),
        FillBar(
          value: state.tankFraction,
          height: 10,
          radius: 5,
          gradient: LinearGradient(
            colors: full
                ? const [GColors.hot, Color(0xFFFF7A5C)]
                : [sort.current.fromColor, sort.current.toColor],
          ),
          // Насечки, как на мерной таре.
          overlay: const CustomPaint(painter: _TicksPainter()),
        ),
        const SizedBox(height: 3),
        // Скорость — в строке состояния, а не рядом с объёмом: в колонке
        // рядом с продажей они вдвоём не помещались.
        Row(
          children: [
            Expanded(
              child: Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GType.num(
                  size: 10,
                  weight: full ? FontWeight.w700 : FontWeight.w400,
                  color: full ? GColors.hot : GColors.textLo,
                ),
              ),
            ),
            // Полному баку скорость ни к чему — аппараты всё равно стоят, а
            // «полный — аппараты стоят» рядом с ней не помещалось.
            if (!full) ...[
              const SizedBox(width: GS.s1),
              Text(
                '+${Fmt.rate(rate, trim: false)}',
                maxLines: 1,
                style: GType.num(size: 10, weight: FontWeight.w600, color: GColors.copper),
              ),
            ],
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
    for (var x = size.width / 10; x < size.width - 1; x += size.width / 10) {
      canvas.drawRect(Rect.fromLTWH(x.floorToDouble(), 0, 1, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_TicksPainter oldDelegate) => false;
}

/// Бак во всю ширину, под ним — продажа Петровичу и место гостя рядом.
///
/// Место гостя есть всегда: пока гостя нет, в нём отсчёт до следующего, и
/// вёрстка не прыгает, когда он приходит и уходит, — а приходит он теперь
/// каждые десять минут. Пока сорт не дотягивает, кнопка гостя показывает,
/// чего не хватает: это и есть подсказка, ради чего стоит доводить сорт.
class _SellRow extends ConsumerWidget {
  final GameState state;
  final DateTime now;

  const _SellRow({required this.state, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.read(gameEngineProvider);
    final active = eventAt(now);
    final petrovich = kBuyers.first;
    final guest = active?.event.asBuyer;
    final payout = engine.saleValueFor(state, petrovich, now);
    // Кнопка горит, только когда за бак дадут хотя бы рубль. Иначе в первые
    // секунды игры самым ярким на экране была «ПРОДАТЬ · 0 ₽» — и новичок
    // жал её вместо того, чтобы зажать гараж.
    final worth = payout >= 1;

    final sellPetrovich = SellButton(
      title: 'ПРОДАТЬ ПЕТРОВИЧУ',
      note: worth ? petrovich.note : 'бак почти пуст',
      payout: payout,
      available: worth && engine.canSellTo(state, petrovich),
      premium: false,
      stacked: true,
      // Звук и вибрация — внутри sellTo: сделка может не состояться.
      onTap: () => ref.read(gameProvider.notifier).sellTo(petrovich),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TankBar(state: state),
        const SizedBox(height: GS.s2),
        // Обе продажи — на одном уровне, как решил владелец: сразу видно,
        // кому сдать выгоднее.
        Row(
            children: [
              Expanded(child: sellPetrovich),
              const SizedBox(width: GS.s2),
              Expanded(
                child: guest == null
                    // Место гостя не пропадает, пока его нет: в нём отсчёт до
                    // следующего. Гость приходит по часам (docs/DECISIONS.md,
                    // «Гости»), и отсчёт — повод вернуться к нужной минуте.
                    // Кто придёт — не пишем: это сюрприз, так решил владелец.
                    ? SellButton(
                        title: 'ГОСТЬ',
                        note: 'кто — неизвестно',
                        payout: 0,
                        lockedAmount: 'через ${Fmt.clock(untilNextEvent(now))}',
                        available: false,
                        premium: true,
                        stacked: true,
                        onTap: () {},
                      )
                    : _guestButton(ref, engine, guest, active!),
              ),
            ],
        ),
      ],
    );
  }

  Widget _guestButton(WidgetRef ref, GameEngine engine, Buyer guest, ActiveEvent active) {
    final canGuest = engine.canSellTo(state, guest);
    return SellButton(
      title: guest.name.toUpperCase(),
      // Пока не берут — их собственная реплика («не первач же»): она
      // объясняет отказ лучше таблицы. Когда берут — во сколько раз
      // дороже Петровича.
      note: canGuest
          ? '${Fmt.mult(guest.multiplier)} · ещё ${Fmt.clock(active.remaining)}'
          : '${guest.lockedNote} · ${Fmt.clock(active.remaining)}',
      payout: engine.saleValueFor(state, guest, now),
      // Пока сорт не дотягивает, вместо суммы — чего не хватает. Это и
      // есть подсказка, ради чего стоит доводить сорт.
      lockedAmount: canGuest ? null : _needSort(guest),
      available: canGuest,
      premium: true,
      stacked: true,
      onTap: () => ref.read(gameProvider.notifier).sellTo(guest),
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

  /// Мелкая строка под именем. `null` — без неё: в узкой кнопке у бака ей
  /// нет места, а «берёт всё, всегда» Петровича выучивается за минуту.
  final String? note;
  final double payout;
  final bool available;
  final bool premium;

  /// Имя над суммой — узкая кнопка рядом с баком. Иначе имя слева, сумма
  /// справа — кнопка во всю ширину.
  final bool stacked;

  /// Что написать на месте суммы, пока продать нельзя. `null` — прочерк.
  final String? lockedAmount;
  final VoidCallback onTap;

  const SellButton({
    super.key,
    required this.title,
    required this.payout,
    required this.available,
    required this.premium,
    required this.stacked,
    required this.onTap,
    this.note,
    this.lockedAmount,
  });

  /// Высота кнопки: под палец, не меньше 44.
  static const double height = 48;

  @override
  State<SellButton> createState() => _SellButtonState();
}

class _SellButtonState extends State<SellButton> {
  bool _down = false;

  /// Строка двухэтажной кнопки: постоянной высоты, текст ужимается.
  static Widget _slot(double height, Widget child) => SizedBox(
        height: height,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final on = widget.available;
    final premium = widget.premium;
    final fg = on ? GColors.onAmber : GColors.textLo;

    final locked = widget.lockedAmount;
    final Widget amount = !on && locked != null
        ? Text(
            locked,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GType.ui(size: 11, weight: FontWeight.w600, color: GColors.amberDim),
          )
        // Сумма ужимается, а не режется: «1.25 Млн» без рубля — уже не сумма.
        : FittedBox(
            fit: BoxFit.scaleDown,
            alignment: widget.stacked ? Alignment.centerLeft : Alignment.centerRight,
            child: Text(
              on ? Fmt.money(widget.payout) : '—',
              maxLines: 1,
              style: GType.num(
                size: 16,
                weight: FontWeight.w700,
                color: on ? GColors.onAmber : GColors.textLo,
              ),
            ),
          );

    final titleStyle = GType.ui(
      size: 10,
      weight: FontWeight.w700,
      color: fg,
      letterSpacing: 0.8,
    );
    final title = Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle);

    final note = widget.note == null
        ? null
        : Text(
            widget.note!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GType.ui(
              size: 10,
              weight: FontWeight.w500,
              color: on ? const Color(0xB32B1A06) : GColors.textLo,
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
          // Высота — нижняя граница, а не потолок: с крупным шрифтом в
          // настройках телефона имя и сумма в неё не влезали.
          constraints: const BoxConstraints(minHeight: SellButton.height),
          padding: const EdgeInsets.symmetric(horizontal: GS.s3, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GR.button - 2),
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
          // Двухэтажная кнопка — строками постоянной высоты: две такие
          // кнопки стоят рядом, и у суммы (16 кегль) и подсказки гостя
          // (11 кегль) высота строки разная — кнопки выходили разной высоты.
          // Не влезает в строку — ужимается, а не режется: на 320 точках
          // «ПРОДАТЬ ПЕТРОВИЧУ» в полкнопки не помещалось на пару точек.
          child: widget.stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _slot(13, Text(widget.title, maxLines: 1, style: titleStyle)),
                    _slot(21, amount is FittedBox ? amount.child! : amount),
                    if (note != null) _slot(13, note),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          if (note != null) ...[const SizedBox(height: 2), note],
                        ],
                      ),
                    ),
                    const SizedBox(width: GS.s2),
                    Flexible(child: amount),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Тонкая полоска над развёрнутым магазином: касса, бак, серия.
///
/// Сцена и верх закрыты шторкой, а эти три числа нужны и при покупке:
/// касса — чтобы видеть, на что хватает, бак — чтобы не пропустить полный,
/// серия — чтобы помнить, что она ждёт. Нажатие сворачивает магазин: вся
/// полоска — одна кнопка, и она выше 44 точек.
class ShopStrip extends ConsumerWidget {
  /// Набранная серия. Числом, а не контроллером: на паузе она не меняется.
  final double series;
  final VoidCallback onTap;

  const ShopStrip({super.key, required this.series, required this.onTap});

  /// Высота полоски.
  static const double height = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(gameProvider.select((s) => s.resources.money));
    final ml = ref.watch(gameProvider.select((s) => s.resources.ml));
    final state = ref.read(gameProvider);
    final full = state.isTankFull;
    final live = series > 1.05;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: GS.s4),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Fmt.money(money, trim: false),
                    maxLines: 1,
                    style: GType.num(size: 18, weight: FontWeight.w700, color: GColors.textHi),
                  ),
                ),
              ),
              const SizedBox(width: GS.s3),
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      full ? 'БАК ПОЛНЫЙ' : 'БАК ${Fmt.volume(ml)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GType.label().copyWith(color: full ? GColors.hot : null),
                    ),
                    const SizedBox(height: 3),
                    FillBar(
                      value: state.tankFraction,
                      height: 6,
                      gradient: LinearGradient(
                        colors: full
                            ? const [GColors.hot, Color(0xFFFF7A5C)]
                            : [state.sort.current.fromColor, state.sort.current.toColor],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: GS.s3),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: 'СЕРИЯ ',
                    style: GType.label().copyWith(color: live ? GColors.amber : GColors.textLo),
                  ),
                  TextSpan(
                    text: Fmt.mult(double.parse(series.toStringAsFixed(1))),
                    style: GType.num(
                      size: 13,
                      weight: FontWeight.w700,
                      color: live ? GColors.amber : GColors.textLo,
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
