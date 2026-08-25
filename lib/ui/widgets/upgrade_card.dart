import 'package:flutter/widgets.dart';

import '../theme/kardashev_tokens.dart';
import 'glyph.dart';
import 'primitives.dart';

enum UpgradeVisualState { available, locked, purchased }

/// Upgrade card (2-up grid) — ported from design/components/game/UpgradeCard.jsx.
/// available = amber border + glow + active Buy; locked = dimmed;
/// purchased = cyan check + struck-through price + faded.
class UpgradeCard extends StatelessWidget {
  final String glyph;
  final String title;
  final String desc;
  final String priceText;
  final UpgradeVisualState state;
  final VoidCallback onBuy;

  const UpgradeCard({
    super.key,
    required this.glyph,
    required this.title,
    required this.desc,
    required this.priceText,
    required this.state,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final available = state == UpgradeVisualState.available;
    final purchased = state == UpgradeVisualState.purchased;
    final locked = state == UpgradeVisualState.locked;
    final opacity = purchased ? 0.4 : (locked ? 0.5 : 1.0);

    final priceColor = purchased
        ? KColors.textLo
        : available
            ? KColors.ctaSolid
            : KColors.textLo;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: KColors.surface2,
        borderRadius: BorderRadius.circular(KR.card),
        border: Border.all(color: available ? KColors.ctaSolid : KColors.glassBorder, width: 1),
        boxShadow: available ? const [BoxShadow(color: KColors.ctaGlow, blurRadius: 18)] : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Glyph(name: glyph, size: 24, tint: available),
          const SizedBox(height: 8),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: KType.cardTitle()),
          const SizedBox(height: 8),
          Expanded(child: Text(desc, style: KType.desc())),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  priceText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KType.price(priceColor).copyWith(
                    decoration: purchased ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
              ),
              if (!purchased) ...[
                const SizedBox(width: 8),
                KButton(
                  variant: available ? KButtonVariant.cta : KButtonVariant.ctaGhost,
                  small: true,
                  disabled: !available,
                  minWidth: 60,
                  height: 32,
                  onTap: onBuy,
                  child: const Text('Buy'),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    card = Opacity(opacity: opacity, child: card);

    if (purchased) {
      card = Stack(
        children: [
          card,
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: KColors.accent),
              child: Text('✓', style: KType.ui(size: 12, weight: FontWeight.w700, color: KColors.onAccent)),
            ),
          ),
        ],
      );
    }

    return card;
  }
}
