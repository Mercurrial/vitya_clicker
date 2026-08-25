import 'package:flutter/widgets.dart';

import '../theme/kardashev_tokens.dart';

/// KARDASHEV button — ported from design/components/core/Button.jsx.
/// cta = amber gradient (affordable only); ctaGhost = dim outline;
/// accent = cyan (identity); ghost = transparent. Shrinks to 0.96 on press.
enum KButtonVariant { cta, ctaGhost, accent, ghost }

class KButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final KButtonVariant variant;
  final bool small;
  final bool disabled;
  final double? minWidth;
  final double? height;

  const KButton({
    super.key,
    required this.child,
    this.onTap,
    this.variant = KButtonVariant.accent,
    this.small = false,
    this.disabled = false,
    this.minWidth,
    this.height,
  });

  @override
  State<KButton> createState() => _KButtonState();
}

class _KButtonState extends State<KButton> {
  bool _down = false;

  void _set(bool v) {
    if (widget.disabled) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height ?? (widget.small ? 36.0 : 44.0);
    final pad = widget.small ? 14.0 : 20.0;
    final fontSize = widget.small ? 13.0 : 14.0;

    Color? bg;
    Gradient? grad;
    Color fg;
    List<BoxShadow> shadow = const [];
    BoxBorder? border;

    switch (widget.variant) {
      case KButtonVariant.cta:
        grad = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KColors.ctaGradA, KColors.ctaGradB],
        );
        fg = KColors.onCta;
        shadow = const [BoxShadow(color: KColors.ctaGlow, blurRadius: 20, offset: Offset(0, 6))];
        break;
      case KButtonVariant.ctaGhost:
        bg = const Color(0x00000000);
        fg = KColors.textLo;
        border = Border.all(color: const Color(0x1AFFFFFF), width: 1);
        break;
      case KButtonVariant.accent:
        bg = KColors.accent;
        fg = KColors.onAccent;
        shadow = const [BoxShadow(color: KColors.accentGlow, blurRadius: 16, offset: Offset(0, 4))];
        break;
      case KButtonVariant.ghost:
        bg = const Color(0x00000000);
        fg = KColors.textMid;
        border = Border.all(color: KColors.glassBorder, width: 1);
        break;
    }

    final disabled = widget.disabled;

    Widget content = AnimatedScale(
      scale: _down ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: Container(
        constraints: BoxConstraints(minWidth: widget.minWidth ?? 0, minHeight: h, maxHeight: h),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: pad),
        decoration: BoxDecoration(
          color: grad == null ? bg : null,
          gradient: disabled ? null : grad,
          borderRadius: BorderRadius.circular(KR.pill),
          border: border,
          boxShadow: disabled ? const [] : shadow,
        ),
        child: DefaultTextStyle(
          style: KType.ui(size: fontSize, weight: FontWeight.w600, color: fg),
          child: widget.child,
        ),
      ),
    );

    if (disabled) content = Opacity(opacity: 0.42, child: content);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: disabled ? null : widget.onTap,
      child: content,
    );
  }
}

/// Stat chip under the hero counter (J/s, J/tap).
class KChip extends StatelessWidget {
  final String icon;
  final String value;
  final bool accent;
  const KChip({super.key, required this.icon, required this.value, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final color = accent ? KColors.accent : KColors.textMid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: KColors.white03,
        borderRadius: BorderRadius.circular(KR.pill),
        border: Border.all(color: KColors.glassBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: KType.ui(size: 12, color: color)),
          const SizedBox(width: 6),
          Text(value, style: KType.chip(color)),
        ],
      ),
    );
  }
}

/// Thin Kardashev-scale progress bar.
class KProgressBar extends StatelessWidget {
  final double value;
  const KProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: KColors.white07,
        borderRadius: BorderRadius.circular(KR.pill),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v <= 0 ? 0.0 : v,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [KColors.accentDim, KColors.accent]),
              borderRadius: BorderRadius.circular(KR.pill),
              boxShadow: const [BoxShadow(color: KColors.accentGlow, blurRadius: 12)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented tabs for the bottom sheet; the active cyan pill slides.
class KSegmentedTabs extends StatelessWidget {
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  const KSegmentedTabs({super.key, required this.tabs, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final n = tabs.length;
    final alignX = n <= 1 ? 0.0 : (index / (n - 1)) * 2 - 1;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: KColors.black28,
        borderRadius: BorderRadius.circular(KR.pill),
        border: Border.all(color: KColors.glassBorder, width: 1),
      ),
      child: SizedBox(
        height: 36,
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: Alignment(alignX, 0),
              duration: const Duration(milliseconds: 260),
              curve: kDecelerate,
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: KColors.accent,
                    borderRadius: BorderRadius.circular(KR.pill),
                    boxShadow: const [BoxShadow(color: KColors.accentGlow, blurRadius: 12, offset: Offset(0, 2))],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: KType.ui(
                            size: 14,
                            weight: FontWeight.w600,
                            color: i == index ? KColors.onAccent : KColors.textMid,
                            letterSpacing: 14 * 0.04,
                          ),
                          child: Text(tabs[i].toUpperCase()),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
