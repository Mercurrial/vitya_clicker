import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/kardashev_format.dart';
import '../../engine/production.dart';
import '../../providers/game_provider.dart';
import '../theme/kardashev_tokens.dart';
import '../widgets/core_button.dart';
import '../widgets/generator_row.dart';
import '../widgets/glyph.dart';
import '../widgets/hero_counter.dart';
import '../widgets/primitives.dart';
import '../widgets/upgrade_card.dart';

/// Phone-width cap so the layout stays mobile-shaped on wide (desktop/web) windows.
const double _kMaxWidth = 480;

/// KARDASHEV main screen — header (tier + hero counter + chips + progress),
/// the passive star core, and the glass bottom sheet with the three tabs.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: KColors.voidBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth < _kMaxWidth ? constraints.maxWidth : _kMaxWidth;
          return Center(
            child: SizedBox(
              width: w,
              height: constraints.maxHeight,
              child: Stack(
                children: [
                  const Positioned(top: 0, left: 0, right: 0, height: 340, child: _TopGlow()),
                  SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        const _Header(),
                        _CoreSection(reduceMotion: reduceMotion),
                        Expanded(
                          child: _Sheet(
                            tab: _tab,
                            reduceMotion: reduceMotion,
                            onTab: (i) => setState(() => _tab = i),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Faint cyan wash behind the header/core (matches the .km-app radial glow).
class _TopGlow extends StatelessWidget {
  const _TopGlow();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.7),
            radius: 1.1,
            colors: [Color(0x1434E2D6), Color(0x0034E2D6)],
            stops: [0.0, 0.75],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gps = ref.watch(gameProvider.select((s) => s.goldPerSecond));
    final p = ref.watch(gameProvider.select((s) => s.prestige));

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: Column(
        children: [
          Text(_tierLabel(gps), style: KType.tier()),
          const SizedBox(height: 12),
          const HeroCounter(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              KChip(icon: '▲', value: '${KFmt.compact(gps)} J/s', accent: true),
              const SizedBox(width: 12),
              KChip(icon: '◇', value: '${p.shards} · ×${p.globalMultiplier.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: KProgressBar(value: _kardashevProgress(gps)),
          ),
        ],
      ),
    );
  }
}

class _CoreSection extends StatelessWidget {
  final bool reduceMotion;
  const _CoreSection({required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    return CoreZone(reduceMotion: reduceMotion);
  }
}

class _Sheet extends StatelessWidget {
  final int tab;
  final bool reduceMotion;
  final ValueChanged<int> onTab;
  const _Sheet({required this.tab, required this.reduceMotion, required this.onTab});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(KR.sheet)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: KColors.glassBg,
            border: Border(top: BorderSide(color: KColors.glassBorder, width: 1)),
            boxShadow: KShadow.sheet,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: KSegmentedTabs(
                  tabs: const ['Generators', 'Upgrades', 'Ascend'],
                  index: tab,
                  onChanged: onTab,
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: reduceMotion ? 0 : 220),
                        child: tab == 0
                            ? const _GeneratorsTab(key: ValueKey('gen'))
                            : tab == 1
                                ? const _UpgradesTab(key: ValueKey('up'))
                                : const _SingularityTab(key: ValueKey('sing')),
                      ),
                    ),
                    const Positioned(top: 0, left: 0, right: 0, height: 22, child: _TopFade()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopFade extends StatelessWidget {
  const _TopFade();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xD910141D), Color(0x0010141D)],
          ),
        ),
      ),
    );
  }
}

class _GeneratorsTab extends ConsumerWidget {
  const _GeneratorsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final formulas = ref.read(formulasProvider);
    final gold = state.resources.gold;
    final gens = state.generators.items;

    bool unlocked(int i) => i == 0 || gens[i - 1].ownedCount > 0;

    var highlightIndex = -1;
    for (var i = 0; i < gens.length; i++) {
      final cost = formulas.calculateUpgradeCost(
          gens[i].baseCost, gens[i].costGrowthFactor, gens[i].ownedCount);
      if (unlocked(i) && gold < cost) {
        highlightIndex = i;
        break;
      }
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      itemCount: gens.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final g = gens[i];
        final isUnlocked = unlocked(i);
        final cost = formulas.calculateUpgradeCost(g.baseCost, g.costGrowthFactor, g.ownedCount);
        final affordable = isUnlocked && gold >= cost;

        final String rateText;
        if (!isUnlocked) {
          rateText = 'Locked';
        } else if (g.ownedCount > 0) {
          final out = Production.generatorOutput(g, state.generators, state.upgrades, state.prestige);
          rateText = '+${KFmt.compact(out)} J/s';
        } else {
          final per = g.baseProduction *
              state.upgrades.generatorMultiplier(g.id) *
              state.prestige.globalMultiplier;
          rateText = '+${KFmt.compact(per)} J/s ea';
        }

        return GeneratorRow(
          glyph: kGeneratorGlyphs[g.id] ?? 'fusion',
          name: g.name,
          count: g.ownedCount,
          rateText: rateText,
          priceText: isUnlocked ? '${KFmt.compact(cost)} J' : '—',
          affordable: affordable,
          locked: !isUnlocked,
          highlighted: i == highlightIndex && !affordable,
          onBuy: () => ref.read(gameProvider.notifier).buyGenerator(g.id),
        );
      },
    );
  }
}

class _UpgradesTab extends ConsumerWidget {
  const _UpgradesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final gold = state.resources.gold;
    final ups = state.upgrades.items;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: ups.length,
      itemBuilder: (context, i) {
        final u = ups[i];
        final UpgradeVisualState vs = u.purchased
            ? UpgradeVisualState.purchased
            : (gold >= u.cost ? UpgradeVisualState.available : UpgradeVisualState.locked);
        return UpgradeCard(
          glyph: kUpgradeGlyphs[u.id] ?? 'overclock',
          title: u.name,
          desc: u.description,
          priceText: '${KFmt.compact(u.cost)} J',
          state: vs,
          onBuy: () => ref.read(gameProvider.notifier).buyUpgrade(u.id),
        );
      },
    );
  }
}

class _SingularityTab extends ConsumerWidget {
  const _SingularityTab({super.key});

  Future<void> _confirm(BuildContext context, WidgetRef ref, int pending) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KColors.surface3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KR.card)),
        title: Text('Collapse to singularity?',
            style: KType.ui(size: 16, weight: FontWeight.w600)),
        content: Text(
          'Generators and upgrades reset. You gain +$pending Singularity Shards. '
          'Shards and their bonus are permanent and speed up every future run.',
          style: KType.ui(size: 13, color: KColors.textMid, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: KType.ui(size: 14, color: KColors.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Ascend',
                style: KType.ui(size: 14, weight: FontWeight.w600, color: KColors.accent)),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(gameProvider.notifier).prestige();
  }

  Widget _panel(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KColors.surface2,
          borderRadius: BorderRadius.circular(KR.card),
          border: Border.all(color: KColors.glassBorder, width: 1),
        ),
        child: child,
      );

  Widget _statRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KType.ui(size: 13, color: KColors.textMid)),
          Text(value, style: KType.mono(size: 13, weight: FontWeight.w600, color: KColors.textHi)),
        ],
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(gameProvider.select((s) => s.prestige));
    final pending = p.pendingShards;
    final bonusNow = 5.0 * p.shards;
    final bonusAfter = 5.0 * (p.shards + pending);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      children: [
        _panel(Column(
          children: [
            Text('SINGULARITY SHARDS', style: KType.tier()),
            const SizedBox(height: 10),
            Text('${p.shards}',
                style: KType.mono(
                    size: 40,
                    weight: FontWeight.w700,
                    color: KColors.accent,
                    shadows: const [Shadow(color: KColors.accentGlow, blurRadius: 22)])),
            const SizedBox(height: 6),
            Text('+${bonusNow.toStringAsFixed(0)}% to all production',
                style: KType.ui(size: 13, color: KColors.textMid)),
          ],
        )),
        const SizedBox(height: 12),
        _panel(Column(
          children: [
            _statRow('Total energy ever', '${KFmt.compact(p.totalEverEarned)} J'),
            const SizedBox(height: 10),
            _statRow('Ascend now', pending > 0 ? '+$pending shards' : 'not yet'),
            const SizedBox(height: 10),
            _statRow('Bonus after ascend', '+${bonusAfter.toStringAsFixed(0)}%'),
          ],
        )),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: KButton(
            variant: pending > 0 ? KButtonVariant.cta : KButtonVariant.ctaGhost,
            disabled: pending <= 0,
            onTap: () => _confirm(context, ref, pending),
            child: Text(pending > 0 ? 'Ascend  ·  +$pending' : 'Keep producing'),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Collapsing resets generators and upgrades. Shards are permanent.',
          textAlign: TextAlign.center,
          style: KType.ui(size: 12, color: KColors.textLo, height: 1.4),
        ),
      ],
    );
  }
}

String _tierLabel(double gps) {
  if (gps < 1e3) return 'KARDASHEV · TYPE 0';
  if (gps < 1e6) return 'KARDASHEV · TYPE I';
  if (gps < 1e9) return 'KARDASHEV · TYPE II';
  if (gps < 1e12) return 'KARDASHEV · TYPE III';
  return 'KARDASHEV · TYPE IV';
}

double _kardashevProgress(double gps) {
  if (gps <= 1) return 0.0;
  final decades = math.log(gps) / math.ln10; // ≈ log10(gps)
  return (decades / 18.0).clamp(0.0, 1.0);
}
