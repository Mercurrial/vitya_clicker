import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/expenses.dart';
import '../../core/formatters.dart';
import '../../core/sfx.dart';
import '../../engine/production.dart';
import '../../models/achievement.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/game_provider.dart';
import '../theme/garage.dart';
import '../widgets/shop.dart';
import 'goals_tab.dart';
import 'vitya_tab.dart';

/// Режим «купить максимум».
const int kBuyMax = -1;

/// Сколько штук берём за одно нажатие: 1, 10, 100 или максимум.
final buyAmountProvider = StateProvider<int>((ref) => 1);

/// Режимы покупки пачкой.
const List<(int, String)> kBuyModes = [
  (1, '×1'),
  (10, '×10'),
  (100, '×100'),
  (kBuyMax, 'МАКС'),
];

/// Нижняя полка: вкладки и списки покупок.
class Shelf extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;
  const Shelf({super.key, required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: GColors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GR.sheet - 6)),
        boxShadow: GShadow.sheet,
        border: Border(top: BorderSide(color: GColors.hairline)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(GS.s3, GS.s3, GS.s3, GS.s2),
            child: _Tabs(index: tab, onChanged: onTab),
          ),
          // Подорожание видно там, где за него платят: над списками покупок.
          if (tab < 2) const _SupplyStrip(),
          Expanded(
            child: switch (tab) {
              0 => const _StillsTab(),
              1 => const _UpgradesTab(),
              2 => const GoalsTab(),
              _ => const VityaTab(),
            },
          ),
        ],
      ),
    );
  }
}

class _Tabs extends ConsumerWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _Tabs({required this.index, required this.onChanged});

  static const _labels = ['АППАРАТЫ', 'УЛУЧШЕНИЯ', 'ЦЕЛИ', 'ВИТЯ'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final engine = ref.read(gameEngineProvider);
    final now = ref.read(timeProvider)();
    final money = state.resources.money;

    // Сколько чего можно взять прямо сейчас. Без этих чисел вкладку
    // приходится открывать наугад: вдруг там что-то появилось.
    final gens = state.generators.items;
    final affordableStills = [
      for (var i = 0; i < gens.length; i++)
        if ((i == 0 || gens[i - 1].ownedCount > 0) &&
            money >= engine.generatorCost(gens[i], now))
          i,
    ].length;
    final affordableUpgrades = state.upgrades.items
        .where((u) => !u.purchased && money >= engine.upgradeCost(u, now))
        .length;
    final canSleep = state.prestige.pendingWisdom > 0;

    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0x40000000),
        borderRadius: BorderRadius.circular(GR.pill),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              // «УЛУЧШЕНИЯ» — самое длинное слово; ему чуть больше места,
              // иначе на узком экране оно уходило в многоточие.
              flex: i == 1 ? 13 : (i == 2 ? 8 : 10),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (i != index) ref.read(feedbackProvider).buzz(Buzz.select);
                  onChanged(i);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: gEase,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: i == index ? GColors.copper : null,
                          borderRadius: BorderRadius.circular(GR.pill),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _labels[i],
                            maxLines: 1,
                            style: GType.tab().copyWith(
                              fontSize: 11,
                              color: i == index ? GColors.textHi : GColors.textMid,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Метка «тут есть что взять» — над углом вкладки, а не
                    // числом в строке: число отнимало ширину у подписи.
                    if (_dot(i, affordableStills, affordableUpgrades, canSleep) case final n?)
                      Positioned(top: -6, right: 0, child: _Dot(count: n)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Что показать в углу вкладки. `null` — ничего.
  static int? _dot(int tab, int stills, int upgrades, bool sleep) => switch (tab) {
        0 when stills > 0 => stills,
        1 when upgrades > 0 => upgrades,
        3 when sleep => 0,
        _ => null,
      };
}

/// Кружок в углу вкладки. Ноль — просто точка: «загляни сюда».
class _Dot extends StatelessWidget {
  final int count;
  const _Dot({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: GColors.amber,
        borderRadius: BorderRadius.circular(GR.pill),
        border: Border.all(color: GColors.surface1, width: 1.5),
      ),
      child: count > 0
          ? Text(
              '$count',
              style: GType.num(size: 9, weight: FontWeight.w700, color: GColors.onAmber),
            )
          : null,
    );
  }
}

/// Переключатель «сколько брать за раз».
///
/// Четыре кнопки в ряд, а не одна «по кругу»: по кругу надо было нажать до
/// трёх раз, чтобы попасть в нужный режим, и каждый раз гадать, какой будет
/// следующим. Появляется только после достижения, которое открывает покупку
/// пачками: автоматизация в жанре зарабатывается, а не выдаётся.
class _BuyModeBar extends ConsumerWidget {
  const _BuyModeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(buyAmountProvider);
    return Row(
      children: [
        Text('БРАТЬ ПО', style: GType.label()),
        const SizedBox(width: GS.s2),
        Expanded(
          child: Container(
            height: 30,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0x40000000),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                for (final (value, label) in kBuyModes)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (value == mode) return;
                        ref.read(feedbackProvider).buzz(Buzz.select);
                        ref.read(buyAmountProvider.notifier).state = value;
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: value == mode ? GColors.surface3 : null,
                          borderRadius: BorderRadius.circular(8),
                          border: value == mode ? Border.all(color: GColors.copper) : null,
                        ),
                        child: Text(
                          label,
                          style: GType.num(
                            size: 11,
                            weight: FontWeight.w700,
                            color: value == mode ? GColors.textHi : GColors.textMid,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StillsTab extends ConsumerWidget {
  const _StillsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final engine = ref.read(gameEngineProvider);
    final now = ref.read(timeProvider)();
    final gens = state.generators.items;
    // Аппараты покупаются за ДЕНЬГИ, а не за товар в баке.
    final money = state.resources.money;

    // Открыт первый аппарат и любой следующий за уже купленным — лестница
    // ведёт игрока и не вываливает сразу 13 позиций.
    bool unlocked(int i) => i == 0 || gens[i - 1].ownedCount > 0;

    final visible = <int>[];
    for (var i = 0; i < gens.length; i++) {
      visible.add(i);
      if (!unlocked(i)) break; // одна закрытая строка-дразнилка
    }

    final bulk = state.achievements.hasPerk(AchievementPerk.bulkBuy);
    final mode = ref.watch(buyAmountProvider);
    final header = bulk ? 1 : 0;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(GS.s3, GS.s1, GS.s3, GS.s6),
      itemCount: visible.length + header,
      separatorBuilder: (_, __) => const SizedBox(height: GS.s2),
      itemBuilder: (context, k) {
        if (k < header) return const _BuyModeBar();
        final i = visible[k - header];
        final g = gens[i];
        final open = unlocked(i);

        // Сколько уйдёт за одно нажатие в текущем режиме.
        final wanted = (!bulk || mode == 1)
            ? 1
            : (mode == kBuyMax ? engine.affordableCount(state, g, now) : mode);
        final count = wanted < 1 ? 1 : wanted;
        final cost = count > 1 ? engine.bulkCost(g, count, now) : engine.generatorCost(g, now);

        return StillRow(
          id: g.id,
          name: g.name,
          owned: g.ownedCount,
          output: Production.generatorOutput(
            g,
            state.generators,
            state.upgrades,
            state.prestige,
            state.achievements.multiplier,
          ),
          cost: cost,
          buyCount: count,
          affordable: open && money >= cost,
          locked: !open,
          unlockAfter: i > 0 ? gens[i - 1].name : null,
          onBuy: () => ref.read(gameProvider.notifier).buyGenerator(g.id, count: count),
        );
      },
    );
  }
}

/// Показывать ли уже купленные улучшения.
///
/// По умолчанию нет. Список рос с каждой покупкой, купленное копилось сверху,
/// и найти то, что ещё можно взять, становилось всё труднее — а именно за
/// этим на вкладку и заходят.
final showBoughtUpgradesProvider = StateProvider<bool>((ref) => false);

class _UpgradesTab extends ConsumerWidget {
  const _UpgradesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final showBought = ref.watch(showBoughtUpgradesProvider);
    final engine = ref.read(gameEngineProvider);
    final now = ref.read(timeProvider)();
    // Улучшения тоже покупаются за деньги.
    final money = state.resources.money;

    final bought = state.upgrades.items.where((u) => u.purchased).length;

    // Показываем только те, что уже имеют смысл: иначе список пугает. Порядок
    // — по цене: то, что можно взять первым, стоит первым. В файле контента
    // улучшения сгруппированы по осям, и доступное оказывалось где-то внизу.
    final visible = state.upgrades.items.where((u) {
      if (u.purchased) return showBought;
      // По обычной цене, а не по сегодняшней: подорожание сахара не должно
      // прятать из списка то, что там только что было.
      return money >= u.cost * 0.35;
    }).toList()
      ..sort((a, b) {
        if (a.purchased != b.purchased) return a.purchased ? 1 : -1;
        return a.cost.compareTo(b.cost);
      });

    // Что откроется следующим — чтобы пустой список не был тупиком.
    final upcoming = state.upgrades.items
        .where((u) => !u.purchased && money < u.cost * 0.35)
        .fold<double?>(null, (min, u) => min == null || u.cost < min ? u.cost : min);

    // Кнопка «показать купленное» идёт последней строкой списка, а не над
    // ним: сверху она отодвигала бы то, ради чего на вкладку заходят.
    final extra = bought > 0 ? 1 : 0;
    final hint = upcoming != null ? 1 : 0;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(GS.s3, GS.s1, GS.s3, GS.s6),
      itemCount: visible.length + hint + extra,
      separatorBuilder: (_, __) => const SizedBox(height: GS.s2),
      itemBuilder: (context, i) {
        if (i < visible.length) {
          final u = visible[i];
          final cost = engine.upgradeCost(u, now);
          return UpgradeRow(
            name: u.name,
            effect: u.description,
            target: u.target,
            cost: cost,
            affordable: money >= cost,
            purchased: u.purchased,
            onBuy: () => ref.read(gameProvider.notifier).buyUpgrade(u.id),
          );
        }
        if (i < visible.length + hint) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: GS.s3, horizontal: GS.s4),
            child: Text(
              visible.isEmpty
                  ? 'Пока нечего улучшать. Следующее появится, когда в кассе '
                      'будет около ${Fmt.money(upcoming! * 0.35)}.'
                  : 'Следующее улучшение появится ближе к ${Fmt.money(upcoming! * 0.35)} в кассе.',
              textAlign: TextAlign.center,
              style: GType.ui(size: 12, color: GColors.textLo, height: 1.35),
            ),
          );
        }
        return _ToggleBought(count: bought, showing: showBought);
      },
    );
  }
}

/// Полоса «сахар подорожал» над списками покупок.
///
/// Только для подорожания: тёща бьёт по продаже и показывается на кнопке
/// Петровича, там, где продают.
class _SupplyStrip extends ConsumerWidget {
  const _SupplyStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Подписка на игру — ради перерисовки каждым тиком: отсчёт должен идти.
    ref.watch(gameProvider);
    final active = expenseAt(ref.read(timeProvider)());
    if (active == null || active.expense.kind != ExpenseKind.supplies) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(GS.s3, 0, GS.s3, GS.s2),
      padding: const EdgeInsets.symmetric(horizontal: GS.s3, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x266A8CAF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x556A8CAF)),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              '${active.expense.title} · ${active.expense.note}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // Не красный: красный в игре один раз, у участкового. Расход —
              // неприятность, а не тревога.
              style: GType.ui(size: 11, weight: FontWeight.w600, color: GColors.cold),
            ),
          ),
          const SizedBox(width: GS.s2),
          Text(
            Fmt.clock(active.remaining),
            style: GType.num(size: 11, weight: FontWeight.w700, color: GColors.cold),
          ),
        ],
      ),
    );
  }
}

/// Кнопка «показать купленное».
class _ToggleBought extends ConsumerWidget {
  final int count;
  final bool showing;

  const _ToggleBought({required this.count, required this.showing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(feedbackProvider).buzz(Buzz.select);
        ref.read(showBoughtUpgradesProvider.notifier).state = !showing;
      },
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GR.pill),
          border: Border.all(color: GColors.border),
        ),
        child: Text(
          showing ? 'СКРЫТЬ КУПЛЕННОЕ' : 'ПОКАЗАТЬ КУПЛЕННОЕ · $count',
          style: GType.label(),
        ),
      ),
    );
  }
}
