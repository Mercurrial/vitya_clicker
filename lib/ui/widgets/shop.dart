import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/formatters.dart';
import '../../engine/production.dart';
import '../theme/garage.dart';

/// Кнопка покупки. Янтарная — только когда денег хватает: янтарь в игре значит
/// ровно одно — «можно взять».
class BuyButton extends StatefulWidget {
  final String label;
  final bool affordable;
  final VoidCallback onTap;

  const BuyButton({
    super.key,
    required this.label,
    required this.affordable,
    required this.onTap,
  });

  @override
  State<BuyButton> createState() => _BuyButtonState();
}

class _BuyButtonState extends State<BuyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.affordable;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: on
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          constraints: const BoxConstraints(minWidth: 92, minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: GS.s3),
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
            boxShadow: on
                ? const [BoxShadow(color: GColors.amberGlow, blurRadius: 14, offset: Offset(0, 4))]
                : null,
          ),
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GType.num(
              size: 13,
              weight: FontWeight.w700,
              color: on ? GColors.onAmber : GColors.textLo,
            ),
          ),
        ),
      ),
    );
  }
}

/// Строка аппарата в списке.
class StillRow extends StatelessWidget {
  final String name;
  final int owned;
  final double output;
  final double cost;
  final bool affordable;
  final bool locked;

  /// Сколько штук уйдёт за одно нажатие. Больше единицы — показываем это на
  /// кнопке, иначе непонятно, за что списали.
  final int buyCount;

  final VoidCallback onBuy;

  const StillRow({
    super.key,
    required this.name,
    required this.owned,
    required this.output,
    required this.cost,
    required this.affordable,
    required this.locked,
    required this.onBuy,
    this.buyCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (locked) return const _LockedRow();

    return Container(
      padding: const EdgeInsets.all(GS.s3),
      decoration: BoxDecoration(
        color: GColors.surface2,
        borderRadius: BorderRadius.circular(GR.card),
        border: Border.all(color: GColors.border),
        boxShadow: GShadow.card,
      ),
      child: Row(
        children: [
          _CountBadge(owned: owned),
          const SizedBox(width: GS.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GType.title()),
                const SizedBox(height: 2),
                Text(
                  owned > 0 ? '+${Fmt.rate(output)}' : 'ещё не куплен',
                  style: GType.num(size: 12, color: GColors.textMid),
                ),
                if (owned > 0) ...[
                  const SizedBox(height: GS.s2),
                  _MilestoneBar(owned: owned),
                ],
              ],
            ),
          ),
          const SizedBox(width: GS.s3),
          BuyButton(
            label: buyCount > 1 ? '×$buyCount   ${Fmt.money(cost)}' : Fmt.money(cost),
            affordable: affordable,
            onTap: onBuy,
          ),
        ],
      ),
    );
  }
}

class _LockedRow extends StatelessWidget {
  const _LockedRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: GColors.surface1,
        borderRadius: BorderRadius.circular(GR.card),
        border: Border.all(color: GColors.hairline),
      ),
      child: Text('— ещё не открыто —', style: GType.label()),
    );
  }
}

/// Количество купленного в медном кружке.
class _CountBadge extends StatelessWidget {
  final int owned;
  const _CountBadge({required this.owned});

  @override
  Widget build(BuildContext context) {
    final active = owned > 0;
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? GColors.copperDim : GColors.wellBg,
        border: Border.all(color: active ? GColors.copper : GColors.border, width: 1.5),
      ),
      child: Text(
        '$owned',
        style: GType.num(
          size: 16,
          weight: FontWeight.w700,
          color: active ? GColors.textHi : GColors.textLo,
        ),
      ),
    );
  }
}

/// Прогресс до следующего удвоения — показывает, что скачок близко.
class _MilestoneBar extends StatelessWidget {
  final int owned;
  const _MilestoneBar({required this.owned});

  @override
  Widget build(BuildContext context) {
    final steps = Production.milestoneSteps(owned);
    final mult = Production.milestoneMultiplier(owned).toInt();
    final hasNext = steps < Production.milestones.length;
    final next = hasNext ? Production.milestones[steps] : null;
    final prev = steps > 0 ? Production.milestones[steps - 1] : 0;
    final frac = next != null ? (owned - prev) / (next - prev) : 1.0;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GR.pill),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  const ColoredBox(color: GColors.wellBg, child: SizedBox.expand()),
                  FractionallySizedBox(
                    widthFactor: frac.clamp(0.0, 1.0),
                    child: const ColoredBox(color: GColors.copper),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: GS.s2),
        Text(
          next != null ? '×$mult · до ×${mult * 2} осталось ${next - owned}' : '×$mult · предел',
          style: GType.num(size: 10, color: GColors.textLo),
        ),
      ],
    );
  }
}

/// Строка апгрейда. Список, а не сетка: русские названия длинные, в две
/// колонки они превращаются в кашу из переносов.
class UpgradeRow extends StatelessWidget {
  final String name;
  final String effect;
  final double cost;
  final bool affordable;
  final bool purchased;
  final VoidCallback onBuy;

  const UpgradeRow({
    super.key,
    required this.name,
    required this.effect,
    required this.cost,
    required this.affordable,
    required this.purchased,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: purchased ? 0.45 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(GS.s3),
        decoration: BoxDecoration(
          color: GColors.surface2,
          borderRadius: BorderRadius.circular(GR.card),
          border: Border.all(
            color: affordable && !purchased ? GColors.amber : GColors.border,
          ),
          boxShadow: affordable && !purchased
              ? const [BoxShadow(color: GColors.amberGlow, blurRadius: 16)]
              : GShadow.card,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: GType.title()),
                  const SizedBox(height: 3),
                  Text(effect, style: GType.body()),
                ],
              ),
            ),
            const SizedBox(width: GS.s3),
            if (purchased)
              Text('куплено', style: GType.label().copyWith(color: GColors.green))
            else
              BuyButton(label: Fmt.money(cost), affordable: affordable, onTap: onBuy),
          ],
        ),
      ),
    );
  }
}
