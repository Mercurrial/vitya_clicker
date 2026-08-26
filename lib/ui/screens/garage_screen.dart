import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../engine/production.dart';
import '../../providers/game_provider.dart';
import '../game/heat_controller.dart';
import '../game/heat_gauge.dart';
import '../game/vitya_portrait.dart';
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
  }

  @override
  void dispose() {
    _heat.dispose();
    super.dispose();
  }

  ({String text, Color color}) _onTap() {
    final applied = _heat.stoke();
    final gained = ref.read(gameProvider).tapPower * applied;
    ref.read(gameProvider.notifier).tap(heatMultiplier: applied);

    final color = _heat.isOverheated
        ? GColors.hot
        : applied >= HeatController.greenMultiplier
            ? GColors.green
            : GColors.brew;
    return (text: '+${Fmt.litres(gained)}', color: color);
  }

  @override
  Widget build(BuildContext context) {
    final era = ref.watch(
      gameProvider.select((s) => _eraFor(s.prestige.totalEverEarned)),
    );

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
                    Expanded(
                      child: Center(
                        child: VityaPortrait(era: era, onTap: _onTap, size: 200),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(GS.s6, 0, GS.s6, GS.s3),
                      child: HeatGauge(controller: _heat),
                    ),
                    Expanded(
                      flex: 2,
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
        ],
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
    _shown = ref.read(gameProvider).resources.litres;
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

    final target = ref.read(gameProvider).resources.litres;
    _shown += (target - _shown) * (dt * 9).clamp(0.0, 1.0);

    final text = Fmt.short(_shown);
    if (text != _last) {
      _last = text;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final rate = ref.watch(gameProvider.select((s) => s.litresPerSecond));
    return Padding(
      padding: const EdgeInsets.only(top: GS.s4, bottom: GS.s2),
      child: Column(
        children: [
          Text('САМОГОН', style: GType.label()),
          const SizedBox(height: GS.s1),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(Fmt.short(_shown), style: GType.counter()),
              const SizedBox(width: 6),
              Text('Л', style: GType.num(size: 18, color: GColors.textMid)),
            ],
          ),
          const SizedBox(height: GS.s1),
          Text(
            rate > 0 ? Fmt.rate(rate) : 'аппараты простаивают',
            style: GType.num(size: 13, color: GColors.copper),
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
    final litres = state.resources.litres;

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
          affordable: open && litres >= cost,
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
    final litres = state.resources.litres;

    // Показываем только те, что уже имеют смысл: иначе список пугает.
    final visible = state.upgrades.items.where((u) {
      if (u.purchased) return true;
      return litres >= u.cost * 0.35;
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
          affordable: litres >= u.cost,
          purchased: u.purchased,
          onBuy: () => ref.read(gameProvider.notifier).buyUpgrade(u.id),
        );
      },
    );
  }
}
