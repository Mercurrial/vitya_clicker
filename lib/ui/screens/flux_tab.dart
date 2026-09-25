import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/balance.dart';
import '../../core/formatters.dart';
import '../../providers/game_provider.dart';
import '../theme/garage.dart';
import '../widgets/fill_bar.dart';
import '../widgets/panel.dart';

/// Скорости, которые выбираются одним нажатием. Остальные — «своя».
const List<double> kQuickSpeeds = [2, 3];

/// С какой «своей» скорости начинается выбор: ×2 и ×3 уже есть кнопками.
const double _kCustomMin = 4;
const double _kCustomDefault = 5;

String _time(double seconds) => Fmt.duration(Duration(seconds: seconds.floor()));

/// Вкладка «ПОТОК»: копилка, скорость, ускорение и улучшения потока.
///
/// Поток — время, накопленное, пока игра не шла (docs/DECISIONS.md, «AFK и
/// поток времени»). Здесь выбирается скорость; кнопка на главном экране
/// включает именно её, чтобы не лезть в шторку каждый раз.
class FluxTab extends ConsumerStatefulWidget {
  const FluxTab({super.key});

  @override
  ConsumerState<FluxTab> createState() => _FluxTabState();
}

class _FluxTabState extends ConsumerState<FluxTab> {
  /// Последняя «своя» скорость — чтобы, вернувшись к ней с ×2, игрок нашёл
  /// ту, что выставлял, а не начальную.
  double _custom = _kCustomDefault;

  @override
  Widget build(BuildContext context) {
    final flux = ref.watch(gameProvider.select((s) => s.flux));
    final speed = ref.watch(fluxSpeedProvider);
    final choice = ref.watch(fluxChoiceProvider);
    final notifier = ref.read(gameProvider.notifier);
    final on = speed > 1;
    final custom = !kQuickSpeeds.contains(choice);
    if (custom) _custom = choice;
    final max = Balance.current.fluxMaxSpeed;

    // На сколько настоящего времени хватит копилки на этой скорости.
    final lasts = flux.seconds / ((on ? speed : choice) - 1);

    return ListView(
      padding: const EdgeInsets.fromLTRB(GS.s4, GS.s2, GS.s4, GS.s6),
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ПОТОК ВРЕМЕНИ', style: GType.label()),
              const SizedBox(height: GS.s1),
              Text(
                _time(flux.seconds),
                style: GType.num(size: 32, weight: FontWeight.w700, color: GColors.amber),
              ),
              const SizedBox(height: GS.s2),
              FillBar(
                value: flux.bankSeconds <= 0 ? 0 : flux.seconds / flux.bankSeconds,
                height: 6,
                color: GColors.amber,
              ),
              const SizedBox(height: GS.s2),
              Text(
                'копилка ${_time(flux.bankSeconds)} · '
                '+${flux.minutesPerHour.round()} мин за час без игры',
                style: GType.num(size: 11, color: GColors.textMid),
              ),
              // Полная копилка — единственное, что игрок теряет, пока его
              // нет. Об этом надо сказать там, где её видно.
              if (flux.isBankFull) ...[
                const SizedBox(height: GS.s2),
                Text(
                  'Копилка полна — сверх неё поток не копится. Потрать его.',
                  key: const Key('flux-bank-full'),
                  style: GType.ui(size: 12, weight: FontWeight.w600, color: GColors.amber),
                ),
              ],
              const SizedBox(height: GS.s3),
              Text(
                'Пока игра закрыта, аппараты стоят, а время копится. Ускорение '
                'тратит его: итог один на любой скорости — час потока даёт час '
                'производства, на ×2 за час, на ×10 за шесть минут.',
                style: GType.body(),
              ),
              const SizedBox(height: GS.s4),
              Text('СКОРОСТЬ', style: GType.label()),
              const SizedBox(height: GS.s2),
              Row(
                children: [
                  for (final v in kQuickSpeeds) ...[
                    Expanded(
                      child: _Chip(
                        key: Key('flux-speed-${v.round()}'),
                        label: '×${v.round()}',
                        selected: choice == v,
                        onTap: () => notifier.chooseBoostSpeed(v),
                      ),
                    ),
                    const SizedBox(width: GS.s2),
                  ],
                  Expanded(
                    child: _Chip(
                      key: const Key('flux-speed-custom'),
                      label: custom ? 'СВОЯ ×${choice.round()}' : 'СВОЯ',
                      selected: custom,
                      onTap: () => notifier.chooseBoostSpeed(_custom),
                    ),
                  ),
                ],
              ),
              if (custom) ...[
                const SizedBox(height: GS.s2),
                Row(
                  children: [
                    _Step(
                      key: const Key('flux-speed-down'),
                      label: '−',
                      enabled: choice > _kCustomMin,
                      onTap: () => notifier.chooseBoostSpeed(choice - 1),
                    ),
                    Expanded(
                      child: Text(
                        '×${choice.round()}',
                        textAlign: TextAlign.center,
                        style: GType.num(size: 20, weight: FontWeight.w700),
                      ),
                    ),
                    _Step(
                      key: const Key('flux-speed-up'),
                      label: '+',
                      enabled: choice < max,
                      onTap: () => notifier.chooseBoostSpeed(choice + 1),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: GS.s3),
              WideButton(
                key: const Key('flux-boost'),
                label: on
                    ? 'ОСТАНОВИТЬ · ${Fmt.clock(Duration(seconds: lasts.ceil()))}'
                    : flux.seconds > 0
                        ? 'УСКОРИТЬ ×${choice.round()} · ${_time(lasts)}'
                        : 'ПОТОКА НЕТ',
                enabled: on || flux.seconds > 0,
                onTap: notifier.toggleBoost,
              ),
            ],
          ),
        ),
        const SizedBox(height: GS.s3),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('УЛУЧШЕНИЯ ПОТОКА', style: GType.label()),
              const SizedBox(height: GS.s1),
              Text(
                'Покупаются за сам поток и переживают похмелье.',
                style: GType.body(),
              ),
              const SizedBox(height: GS.s3),
              _UpgradeRow(
                buyKey: const Key('flux-rate-buy'),
                title: 'Крепкий сон',
                effect: '+1 мин потока за час без игры',
                now: 'сейчас ${flux.minutesPerHour.round()} мин/ч',
                cost: flux.rateCostSeconds,
                maxed: flux.rateMaxed,
                maxedNote: 'предел: час потока за час',
                affordable: flux.canBuyRate,
                onBuy: notifier.buyFluxRate,
              ),
              const SizedBox(height: GS.s3),
              _UpgradeRow(
                buyKey: const Key('flux-bank-buy'),
                title: 'Долгий сон',
                effect: '+1 ч копилки',
                now: 'сейчас ${_time(flux.bankSeconds)}',
                cost: flux.bankCostSeconds,
                maxed: flux.bankMaxed,
                maxedNote: 'предел: копилка на сутки',
                affordable: flux.canBuyBank,
                onBuy: notifier.buyFluxBank,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Выбор скорости. Под палец — 44 точки.
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: gEase,
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: GS.s1),
        decoration: BoxDecoration(
          color: selected ? GColors.copper : GColors.wellBg,
          borderRadius: BorderRadius.circular(GR.pill),
          border: Border.all(color: selected ? GColors.copper : GColors.border),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: GType.num(
              size: 14,
              weight: FontWeight.w700,
              color: selected ? GColors.textHi : GColors.textMid,
            ),
          ),
        ),
      ),
    );
  }
}

/// «−» и «+» у своей скорости.
class _Step extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _Step({super.key, required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: GColors.surface3,
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? GColors.copper : GColors.border),
        ),
        child: Text(
          label,
          style: GType.num(
            size: 20,
            weight: FontWeight.w700,
            color: enabled ? GColors.textHi : GColors.textLo,
          ),
        ),
      ),
    );
  }
}

/// Строка улучшения потока: что даёт, что сейчас, цена в потоке.
class _UpgradeRow extends StatelessWidget {
  final Key buyKey;
  final String title;
  final String effect;
  final String now;
  final double cost;
  final bool maxed;
  final String maxedNote;
  final bool affordable;
  final VoidCallback onBuy;

  const _UpgradeRow({
    required this.buyKey,
    required this.title,
    required this.effect,
    required this.now,
    required this.cost,
    required this.maxed,
    required this.maxedNote,
    required this.affordable,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GType.title()),
              Text(maxed ? maxedNote : effect, style: GType.body()),
              Text(now, style: GType.num(size: 11, color: GColors.textMid)),
            ],
          ),
        ),
        const SizedBox(width: GS.s2),
        GestureDetector(
          key: buyKey,
          behavior: HitTestBehavior.opaque,
          onTap: affordable ? onBuy : null,
          child: Container(
            constraints: const BoxConstraints(minWidth: 88, minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: GS.s3),
            decoration: BoxDecoration(
              gradient: affordable
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [GColors.amber, GColors.amberDim],
                    )
                  : null,
              color: affordable ? null : GColors.wellBg,
              borderRadius: BorderRadius.circular(GR.button),
              border: Border.all(color: affordable ? GColors.amber : GColors.border),
            ),
            child: Text(
              maxed ? 'ПРЕДЕЛ' : _time(cost),
              style: GType.num(
                size: 13,
                weight: FontWeight.w700,
                color: affordable ? GColors.onAmber : GColors.textLo,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
