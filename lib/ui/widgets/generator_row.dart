import 'package:flutter/widgets.dart';

import '../../engine/production.dart';
import '../theme/kardashev_tokens.dart';
import 'glyph.dart';
import 'primitives.dart';

/// A generator list row — ported from design/components/game/GeneratorRow.jsx.
/// left: glyph tile (cyan when owned), center: name + "×N" + J/s contribution,
/// right: Buy pill (amber if affordable). Locked rows dim; the next-to-unlock
/// row gets a cyan-edged highlight.
class GeneratorRow extends StatelessWidget {
  final String glyph;
  final String name;
  final int count;
  final String rateText;
  final String priceText;
  final bool affordable;
  final bool locked;
  final bool highlighted;
  final VoidCallback onBuy;

  const GeneratorRow({
    super.key,
    required this.glyph,
    required this.name,
    required this.count,
    required this.rateText,
    required this.priceText,
    required this.affordable,
    required this.locked,
    required this.highlighted,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final active = count > 0 && !locked;

    Widget row = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? KColors.surface3 : KColors.surface2,
        borderRadius: BorderRadius.circular(KR.card),
        border: Border.all(
          color: highlighted ? KColors.rowHighlightBorder : KColors.glassBorder,
          width: 1,
        ),
        boxShadow: highlighted
            ? const [BoxShadow(color: KColors.rowHighlightGlow, blurRadius: 18)]
            : const [],
      ),
      child: Row(
        children: [
          GlyphTile(name: glyph, active: active, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KType.name(),
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 8),
                      Text('×$count', style: KType.count()),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(rateText, style: KType.rate()),
                if (!locked && count > 0) _milestone(count),
              ],
            ),
          ),
          const SizedBox(width: 12),
          KButton(
            variant: affordable ? KButtonVariant.cta : KButtonVariant.ctaGhost,
            small: true,
            disabled: locked,
            minWidth: 84,
            onTap: onBuy,
            child: Text(priceText),
          ),
        ],
      ),
    );

    if (locked) row = Opacity(opacity: 0.45, child: row);
    return row;
  }

  /// Thin progress bar toward the next ×2 milestone + current multiplier.
  Widget _milestone(int count) {
    final steps = Production.milestoneSteps(count);
    final mult = Production.milestoneMultiplier(count).toInt();
    final hasNext = steps < Production.milestones.length;
    final next = hasNext ? Production.milestones[steps] : null;
    final prev = steps > 0 ? Production.milestones[steps - 1] : 0;
    final frac = next != null ? (count - prev) / (next - prev) : 1.0;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: KColors.white07,
                borderRadius: BorderRadius.circular(KR.pill),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: frac.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: KColors.accent,
                      borderRadius: BorderRadius.circular(KR.pill),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            next != null ? '×$mult · next @ $next' : '×$mult · max',
            style: KType.mono(size: 11, weight: FontWeight.w500, color: KColors.textLo),
          ),
        ],
      ),
    );
  }
}
