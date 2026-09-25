import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/formatters.dart';
import '../../engine/production.dart';
import '../../models/upgrade.dart';
import '../pixel/pixel_sprite.dart';
import '../pixel/still_sprites.dart';
import '../theme/garage.dart';
import 'fill_bar.dart';

/// Кнопка покупки. Янтарная — только когда денег хватает: янтарь в игре значит
/// ровно одно — «можно взять».
class BuyButton extends StatefulWidget {
  final String label;

  /// Мелкая строка над ценой: «×10» при покупке пачкой.
  final String? caption;
  final bool affordable;
  final VoidCallback onTap;

  const BuyButton({
    super.key,
    required this.label,
    required this.affordable,
    required this.onTap,
    this.caption,
  });

  @override
  State<BuyButton> createState() => _BuyButtonState();
}

class _BuyButtonState extends State<BuyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.affordable;
    final caption = widget.caption;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      // Отдача — внутри самой покупки: денег может не хватить, и щёлкать в
      // ответ на несостоявшееся действие нечестно.
      onTap: on ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          constraints: const BoxConstraints(minWidth: 84, minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: GS.s3, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GR.button - 4),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (caption != null)
                Text(
                  caption,
                  style: GType.num(
                    size: 9,
                    weight: FontWeight.w700,
                    color: on ? const Color(0xB32B1A06) : GColors.textLo,
                  ),
                ),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GType.num(
                  size: 13,
                  weight: FontWeight.w700,
                  color: on ? GColors.onAmber : GColors.textMid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка аппарата в списке.
///
/// Слева — тот же спрайт, что стоит в гараже: игрок узнаёт в списке то, что
/// видит на полу, и магазин перестаёт быть ведомостью.
class StillRow extends StatelessWidget {
  final String id;
  final String name;
  final int owned;
  final double output;
  final double cost;
  final bool affordable;
  final bool locked;

  /// Как называется ступень, после которой откроется эта.
  final String? unlockAfter;

  /// Сколько штук уйдёт за одно нажатие. Больше единицы — показываем это на
  /// кнопке, иначе непонятно, за что списали.
  final int buyCount;

  final VoidCallback onBuy;

  const StillRow({
    super.key,
    required this.id,
    required this.name,
    required this.owned,
    required this.output,
    required this.cost,
    required this.affordable,
    required this.locked,
    required this.onBuy,
    this.unlockAfter,
    this.buyCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (locked) return _LockedRow(id: id, after: unlockAfter);

    return Container(
      padding: const EdgeInsets.fromLTRB(GS.s2, GS.s2, GS.s3, GS.s2),
      decoration: BoxDecoration(
        color: GColors.surface2,
        borderRadius: BorderRadius.circular(GR.button),
        border: Border.all(color: affordable ? const Color(0x55E8A33D) : GColors.border),
      ),
      child: Row(
        children: [
          _StillIcon(id: id, owned: owned),
          const SizedBox(width: GS.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Название — главное в строке. На экране 375 точек «Трёхлитровая
                // банка» не влезала и обрезалась многоточием; значок и кнопка
                // цены ужаты ради неё, а не наоборот.
                // На узком экране название ужимается, а не обрезается:
                // «Трёхлитровая …» — это уже не название, а загадка.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    name,
                    maxLines: 1,
                    style: GType.ui(size: 14, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  owned > 0 ? 'гонит ${Fmt.rate(output)}' : 'ещё не куплен',
                  style: GType.num(size: 11, color: owned > 0 ? GColors.copper : GColors.textLo),
                ),
                if (owned > 0) ...[
                  const SizedBox(height: 5),
                  _MilestoneBar(owned: owned),
                ],
              ],
            ),
          ),
          const SizedBox(width: GS.s2),
          BuyButton(
            label: Fmt.money(cost),
            caption: buyCount > 1 ? '+$buyCount шт.' : null,
            affordable: affordable,
            onTap: onBuy,
          ),
        ],
      ),
    );
  }
}

/// Значок аппарата: колодец со спрайтом и счётчиком в углу.
class _StillIcon extends StatelessWidget {
  final String id;
  final int owned;
  const _StillIcon({required this.id, required this.owned});

  @override
  Widget build(BuildContext context) {
    final sprite = stillSpriteFor(id);
    // Целый пиксель, чтобы спрайт в списке был таким же чётким, как на полу.
    final pixel = pixelToFit(sprite, 46, max: 3);

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A140F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GColors.hairline),
              ),
              alignment: Alignment.center,
              child: PixelImage.scaled(
                sprite: sprite,
                pixel: pixel,
                palette: kStillPalette,
              ),
            ),
          ),
          if (owned > 0)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: GColors.copper,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: GColors.surface2, width: 2),
                ),
                child: Text(
                  '$owned',
                  style: GType.num(size: 10, weight: FontWeight.w700, color: GColors.textHi),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ещё не открытый аппарат: силуэт и условие.
///
/// Силуэт — самая дешёвая интрига в жанре: видно, что там что-то большое, и
/// не видно, что именно.
class _LockedRow extends StatelessWidget {
  final String id;
  final String? after;
  const _LockedRow({required this.id, required this.after});

  @override
  Widget build(BuildContext context) {
    final sprite = stillSpriteFor(id);
    final pixel = pixelToFit(sprite, 34, max: 2);
    return Container(
      padding: const EdgeInsets.fromLTRB(GS.s2, GS.s2, GS.s3, GS.s2),
      decoration: BoxDecoration(
        color: GColors.surface1,
        borderRadius: BorderRadius.circular(GR.button),
        border: Border.all(color: GColors.hairline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 36,
            child: Center(
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Color(0xFF3A2E24), BlendMode.srcIn),
                child: PixelImage.scaled(sprite: sprite, pixel: pixel, palette: kStillPalette),
              ),
            ),
          ),
          const SizedBox(width: GS.s3),
          Expanded(
            child: Text(
              after == null ? 'Следующая ступень' : 'Откроется, когда купишь «$after»',
              maxLines: 2,
              style: GType.ui(size: 12, color: GColors.textLo, height: 1.25),
            ),
          ),
        ],
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

    return LayoutBuilder(
      builder: (context, c) => Row(
        children: [
          Expanded(
            child: FillBar(value: frac, height: 4, color: GColors.copper),
          ),
          const SizedBox(width: GS.s2),
          // Подпись важнее полоски: полоска ужимается, подпись — нет. Когда
          // они делили ширину поровну, «→ ×16» уходило в многоточие.
          //
          // Но и подписи есть предел: у дорогого аппарата кнопка цены шире
          // («1.23 Скс ₽»), и на 320 точках подпись вылезала за край
          // строки, когда от полоски уже ничего не оставалось. Тогда она
          // ужимается.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: math.max(0, c.maxWidth - GS.s2)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                next != null ? 'ещё ${next - owned} → ×${mult * 2}' : '×$mult · предел',
                maxLines: 1,
                style: GType.num(size: 10, color: GColors.textMid),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ось улучшения: что именно оно двигает.
///
/// Улучшения конкурируют между собой — объём против цены против бака, — и
/// различать их надо до чтения описания. Цвет и короткое слово дают это за
/// долю секунды.
({String label, Color color}) upgradeAxis(UpgradeTarget t) => switch (t) {
      UpgradeTarget.heatControl => (label: 'ЖАР', color: GColors.green),
      UpgradeTarget.tankCapacity => (label: 'БАК', color: GColors.cold),
      UpgradeTarget.quality => (label: 'ЦЕНА', color: GColors.amber),
      UpgradeTarget.generatorOutput => (label: 'ОБЪЁМ', color: GColors.copper),
      UpgradeTarget.allGenerators => (label: 'ОБЪЁМ', color: GColors.copper),
      UpgradeTarget.synergyCoupling => (label: 'СВЯЗКА', color: GColors.lamp),
      UpgradeTarget.synergyResonance => (label: 'СВЯЗКА', color: GColors.lamp),
    };

/// Строка улучшения.
///
/// Список, а не сетка: русские названия длинные, в две колонки они
/// превращаются в кашу из переносов.
class UpgradeRow extends StatelessWidget {
  final String name;
  final String effect;
  final UpgradeTarget target;
  final double cost;
  final bool affordable;
  final bool purchased;
  final VoidCallback onBuy;

  const UpgradeRow({
    super.key,
    required this.name,
    required this.effect,
    required this.target,
    required this.cost,
    required this.affordable,
    required this.purchased,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final axis = upgradeAxis(target);
    return Opacity(
      opacity: purchased ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(GS.s3, GS.s2 + 2, GS.s3, GS.s2 + 2),
        decoration: BoxDecoration(
          color: GColors.surface2,
          borderRadius: BorderRadius.circular(GR.button),
          border: Border.all(
            color: affordable && !purchased ? const Color(0x55E8A33D) : GColors.border,
          ),
        ),
        child: Row(
          children: [
            // Полоса цвета оси слева — видно ещё до того, как прочитал.
            Container(
              width: 4,
              height: 38,
              decoration: BoxDecoration(
                color: axis.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: GS.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GType.ui(size: 14, weight: FontWeight.w600, height: 1.2),
                  ),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '${axis.label}  ',
                        style: GType.ui(
                          size: 10,
                          weight: FontWeight.w700,
                          color: axis.color,
                          letterSpacing: 0.8,
                        ),
                      ),
                      TextSpan(text: effect, style: GType.ui(size: 12, color: GColors.textMid)),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: GS.s2),
            if (purchased)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: GS.s2),
                child: Text('ЕСТЬ', style: GType.label().copyWith(color: GColors.green)),
              )
            else
              BuyButton(label: Fmt.money(cost), affordable: affordable, onTap: onBuy),
          ],
        ),
      ),
    );
  }
}
