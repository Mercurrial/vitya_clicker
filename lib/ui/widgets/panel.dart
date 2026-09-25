import 'package:flutter/widgets.dart';

import '../theme/garage.dart';

/// Карточка вкладки: тёмная поверхность со скруглением.
class Panel extends StatelessWidget {
  final Widget child;
  const Panel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GS.s4),
      decoration: BoxDecoration(
        color: GColors.surface2,
        borderRadius: BorderRadius.circular(GR.card),
        border: Border.all(color: GColors.border),
      ),
      child: child,
    );
  }
}

/// Строка «подпись — значение».
///
/// Подпись уступает место значению и переносится, а не вылезает за край:
/// на 320 точках «Нагнано за всё время» рядом с «2.34К л» уже впритык, а
/// значение, в отличие от подписи, резать нельзя.
class StatLine extends StatelessWidget {
  final String label;
  final String value;
  const StatLine(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: GType.body())),
        const SizedBox(width: GS.s2),
        Text(
          value,
          style: GType.num(size: 13, weight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Широкая кнопка действия во всю карточку.
class WideButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool danger;
  final VoidCallback onTap;

  const WideButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GR.button),
          gradient: enabled && !danger
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [GColors.amber, GColors.amberDim],
                )
              : null,
          color: enabled && !danger ? null : GColors.wellBg,
          border: Border.all(
            color: danger
                ? GColors.hot
                : (enabled ? GColors.amber : GColors.border),
          ),
        ),
        child: Text(
          label,
          style: GType.ui(
            size: 14,
            weight: FontWeight.w700,
            color: danger
                ? GColors.hot
                : (enabled ? GColors.onAmber : GColors.textLo),
          ),
        ),
      ),
    );
  }
}

