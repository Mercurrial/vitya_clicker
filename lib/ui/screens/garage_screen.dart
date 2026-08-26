import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../engine/market.dart';
import '../../engine/production.dart';
import '../../providers/game_provider.dart';
import '../game/heat_controller.dart';
import '../game/heat_gauge.dart';
import '../game/vitya_portrait.dart';
import '../pixel/garage_scene.dart';
import '../theme/art_style.dart';
import '../theme/garage.dart';
import '../widgets/shop.dart';

/// Ширина «телефона»: на широком экране игра не растягивается, иначе карточки
/// разъезжаются на пол-экрана и верстка ломается.
const double _kPhoneWidth = 460;

class GarageScreen extends ConsumerStatefulWidget {
  const GarageScreen({super.key});

  @override
  ConsumerState<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends ConsumerState<GarageScreen>
    with TickerProviderStateMixin {
  late final HeatController _heat;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _heat = HeatController(vsync: this);
    // Жар живёт в интерфейсе, но множит пассивный поток в движке — поэтому
    // текущее значение непрерывно отдаём в состояние игры.
    _heat.addListener(_pushHeat);
  }

  void _pushHeat() => ref.read(gameProvider.notifier).setHeat(_heat.multiplier);

  @override
  void dispose() {
    _heat.removeListener(_pushHeat);
    _heat.dispose();
    super.dispose();
  }

  ({String text, Color color}) _onTap() {
    final applied = _heat.stoke();
    final gained = ref.read(gameProvider).tapYield * applied;
    ref.read(gameProvider.notifier).tap(heatMultiplier: applied);

    final color = _heat.isOverheated
        ? GColors.hot
        : applied >= HeatController.greenMultiplier
            ? GColors.green
            : GColors.brew;
    return (text: '+${Fmt.volume(gained)}', color: color);
  }

  @override
  Widget build(BuildContext context) {
    final era = ref.watch(
      gameProvider.select((s) => _eraFor(s.prestige.totalEverEarned)),
    );
    final style = ref.watch(artStyleProvider);

    return ColoredBox(
      color: GColors.bg,
      child: Stack(
        children: [
          const Positioned.fill(child: _LampLight()),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kPhoneWidth),
              child: SafeArea(
                child: Column(
                  children: [
                    const _Counter(),
                    // Гараж — центр экрана. Портрет висит на его стене, а
                    // купленные аппараты встают на полки: империю видно.
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: GS.s3),
                        child: AnimatedBuilder(
                          animation: _heat,
                          builder: (context, _) => GarageScene(
                            heat: _heat.heat,
                            hanging: VityaPortrait(
                              era: era,
                              onTap: _onTap,
                              size: 116,
                              style: style.portrait,
                              radius: style.radius * 0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(GS.s6, GS.s3, GS.s6, GS.s3),
                      child: HeatGauge(controller: _heat),
                    ),
                    Expanded(
                      flex: 4,
                      child: _Shelf(
                        tab: _tab,
                        onTab: (i) => setState(() => _tab = i),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Переключатель стиля — временный, чтобы выбрать язык игры глазами.
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            right: 10,
            child: _StyleToggle(style: style),
          ),
        ],
      ),
    );
  }
}

/// Кнопка смены визуального языка. Инструмент выбора, а не часть игры —
/// уедет, как только стиль будет утверждён.
class _StyleToggle extends ConsumerWidget {
  final ArtStyle style;
  const _StyleToggle({required this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          ref.read(artStyleProvider.notifier).state = style.next,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: GColors.wellBg,
          borderRadius: BorderRadius.circular(style.radius > 0 ? GR.pill : 0),
          border: Border.all(color: GColors.border),
        ),
        child: Text(style.label, style: GType.label()),
      ),
    );
  }
}

VityaEra _eraFor(double lifetime) {
  if (lifetime < 1e5) return VityaEra.start;
  if (lifetime < 1e9) return VityaEra.work;
  return VityaEra.boss;
}

/// Тёплый свет лампы под потолком гаража.
class _LampLight extends StatelessWidget {
  const _LampLight();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.85),
            radius: 1.0,
            colors: [GColors.lampGlow, Color(0x0014100C)],
            stops: [0.0, 0.7],
          ),
        ),
      ),
    );
  }
}

/// Счётчик литров. Плавно догоняет реальное значение, иначе при тике раз в
/// 200 мс число дёргается скачками и «дешевит» ощущение.
class _Counter extends ConsumerStatefulWidget {
  const _Counter();

  @override
  ConsumerState<_Counter> createState() => _CounterState();
}

class _CounterState extends ConsumerState<_Counter>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _shown = 0;
  String _last = '';
  Duration _prev = Duration.zero;

  @override
  void initState() {
    super.initState();
    _shown = ref.read(gameProvider).resources.money;
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

    // Касса сглаживается: при продаже число не должно прыгать скачком.
    final target = ref.read(gameProvider).resources.money;
    _shown += (target - _shown) * (dt * 9).clamp(0.0, 1.0);

    final text = Fmt.money(_shown);
    if (text != _last) {
      _last = text;
      if (mounted) setState(() {});
    }
    // Бак и рынок меняются непрерывно — обновляем каждый кадр.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameProvider);
    final now = DateTime.now();
    final price = Market.pricePerLitre(now, state.upgrades);
    final value = state.resources.ml * Market.pricePerMl(now, state.upgrades);
    final goodMoment = Market.isGoodMoment(now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s4, GS.s3, GS.s4, GS.s2),
      child: Column(
        children: [
          Text('КАССА', style: GType.label()),
          Text(Fmt.money(_shown), style: GType.counter()),
          const SizedBox(height: GS.s2),
          _TankBar(
            fraction: state.tankFraction,
            ml: state.resources.ml,
            capacity: state.tankCapacity,
            rate: state.mlPerSecond,
            full: state.isTankFull,
          ),
          const SizedBox(height: GS.s2),
          Row(
            children: [
              Expanded(
                child: _SellButton(
                  value: value,
                  enabled: state.resources.ml > 0,
                  hot: goodMoment,
                  onTap: () => ref.read(gameProvider.notifier).sell(),
                ),
              ),
              const SizedBox(width: GS.s3),
              _PriceTag(price: price, hot: goodMoment),
            ],
          ),
        ],
      ),
    );
  }
}

/// Бак: сколько налито и как быстро прибывает. Полный бак — красный сигнал,
/// потому что в этот момент аппараты стоят.
class _TankBar extends StatelessWidget {
  final double fraction;
  final double ml;
  final double capacity;
  final double rate;
  final bool full;

  const _TankBar({
    required this.fraction,
    required this.ml,
    required this.capacity,
    required this.rate,
    required this.full,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(GR.pill),
          child: SizedBox(
            height: 10,
            child: Stack(
              children: [
                const ColoredBox(color: GColors.wellBg, child: SizedBox.expand()),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: full
                            ? const [GColors.hot, GColors.hot]
                            : const [GColors.brew, GColors.amber],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${Fmt.volume(ml)} / ${Fmt.volume(capacity)}',
              style: GType.num(size: 11, color: GColors.textMid),
            ),
            Text(
              full
                  ? 'БАК ПОЛОН — АППАРАТЫ СТОЯТ'
                  : (rate > 0 ? Fmt.rate(rate) : 'аппараты простаивают'),
              style: GType.num(
                size: 11,
                color: full ? GColors.hot : GColors.copper,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Кнопка продажи. Янтарная — только когда есть что сдавать; на пике рынка
/// добавляется свечение, чтобы момент было видно боковым зрением.
class _SellButton extends StatefulWidget {
  final double value;
  final bool enabled;
  final bool hot;
  final VoidCallback onTap;

  const _SellButton({
    required this.value,
    required this.enabled,
    required this.hot,
    required this.onTap,
  });

  @override
  State<_SellButton> createState() => _SellButtonState();
}

class _SellButtonState extends State<_SellButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: on
          ? () {
              HapticFeedback.mediumImpact();
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GR.button),
            gradient: on
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [GColors.amber, GColors.amberDim],
                  )
                : null,
            color: on ? null : GColors.wellBg,
            border: on ? null : Border.all(color: GColors.border),
            boxShadow: on && widget.hot
                ? const [BoxShadow(color: GColors.amberGlow, blurRadius: 20)]
                : null,
          ),
          child: Text(
            on ? 'ПРОДАТЬ · ${Fmt.money(widget.value)}' : 'НЕЧЕГО ПРОДАВАТЬ',
            style: GType.ui(
              size: 14,
              weight: FontWeight.w700,
              color: on ? GColors.onAmber : GColors.textLo,
            ),
          ),
        ),
      ),
    );
  }
}

/// Текущая цена на рынке. Её видно всегда — иначе решение «продавать сейчас
/// или подождать» превращается в угадайку.
class _PriceTag extends StatelessWidget {
  final double price;
  final bool hot;

  const _PriceTag({required this.price, required this.hot});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: GS.s3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: GColors.wellBg,
        borderRadius: BorderRadius.circular(GR.button),
        border: Border.all(color: hot ? GColors.amber : GColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('РЫНОК', style: GType.label().copyWith(fontSize: 9)),
          Text(
            Fmt.pricePerLitre(price),
            style: GType.num(
              size: 12,
              weight: FontWeight.w700,
              color: hot ? GColors.amber : GColors.textHi,
            ),
          ),
        ],
      ),
    );
  }
}

/// Нижняя полка: вкладки и списки покупок.
class _Shelf extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;
  const _Shelf({required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: GColors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GR.sheet)),
        boxShadow: GShadow.sheet,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(GS.s4, GS.s3, GS.s4, GS.s2),
            child: _Tabs(index: tab, onChanged: onTab),
          ),
          Expanded(
            child: tab == 0 ? const _StillsTab() : const _UpgradesTab(),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _Tabs({required this.index, required this.onChanged});

  static const _labels = ['АППАРАТЫ', 'УЛУЧШЕНИЯ'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: GColors.wellBg,
        borderRadius: BorderRadius.circular(GR.pill),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: gEase,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? GColors.copper : null,
                    borderRadius: BorderRadius.circular(GR.pill),
                  ),
                  child: Text(
                    _labels[i],
                    style: GType.tab().copyWith(
                      color: i == index ? GColors.textHi : GColors.textMid,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StillsTab extends ConsumerWidget {
  const _StillsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final engine = ref.read(gameEngineProvider);
    final gens = state.generators.items;
    // Аппараты покупаются за ДЕНЬГИ, а не за товар в баке.
    final money = state.resources.money;

    // Открыт первый аппарат и любой следующий за уже купленным — лестница
    // ведёт игрока и не вываливает сразу 13 позиций.
    bool unlocked(int i) => i == 0 || gens[i - 1].ownedCount > 0;

    final visible = <int>[];
    for (var i = 0; i < gens.length; i++) {
      if (unlocked(i)) {
        visible.add(i);
      } else {
        visible.add(i); // одна закрытая строка-дразнилка
        break;
      }
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(GS.s4, GS.s2, GS.s4, GS.s6),
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: GS.s2),
      itemBuilder: (context, k) {
        final i = visible[k];
        final g = gens[i];
        final open = unlocked(i);
        final cost = engine.generatorCost(g);
        return StillRow(
          name: g.name,
          owned: g.ownedCount,
          output: Production.generatorOutput(g, state.generators, state.upgrades, state.prestige),
          cost: cost,
          affordable: open && money >= cost,
          locked: !open,
          onBuy: () => ref.read(gameProvider.notifier).buyGenerator(g.id),
        );
      },
    );
  }
}

class _UpgradesTab extends ConsumerWidget {
  const _UpgradesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    // Улучшения тоже покупаются за деньги.
    final money = state.resources.money;

    // Показываем только те, что уже имеют смысл: иначе список пугает.
    final visible = state.upgrades.items.where((u) {
      if (u.purchased) return true;
      return money >= u.cost * 0.35;
    }).toList();

    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(GS.s6),
          child: Text(
            'Пока нечего улучшать.\nГони дальше.',
            textAlign: TextAlign.center,
            style: GType.body(),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(GS.s4, GS.s2, GS.s4, GS.s6),
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: GS.s2),
      itemBuilder: (context, i) {
        final u = visible[i];
        return UpgradeRow(
          name: u.name,
          effect: u.description,
          cost: u.cost,
          affordable: money >= u.cost,
          purchased: u.purchased,
          onBuy: () => ref.read(gameProvider.notifier).buyUpgrade(u.id),
        );
      },
    );
  }
}
