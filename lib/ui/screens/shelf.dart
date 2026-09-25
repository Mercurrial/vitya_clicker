import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/sfx.dart';
import '../../engine/production.dart';
import '../../models/achievement.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/game_provider.dart';
import '../theme/garage.dart';
import '../widgets/shop.dart';
import 'flux_tab.dart';
import 'goals_tab.dart';
import 'vitya_tab.dart';

/// Поля по бокам подписи вкладки — внутри подложки.
const double _kTabPad = 1;

/// Отступ подложки выбранной вкладки от края строки.
const double _kTabInset = 3;

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

/// Вкладки шторки. Своим перечислением, а не номером: вкладка потока
/// появляется не сразу, и с номерами выбранная вкладка съезжала бы на
/// соседнюю в тот момент, когда поток приходит.
enum ShelfTab {
  stills('АППАРАТЫ'),
  upgrades('УЛУЧШЕНИЯ'),
  flux('ПОТОК'),
  goals('ЦЕЛИ'),
  vitya('ВИТЯ');

  final String label;
  const ShelfTab(this.label);
}

/// Содержимое шторки магазина: вкладки и списки покупок.
///
/// Рамку, ручку и положения рисует ShelfSheet; здесь — только то, что
/// внутри.
class Shelf extends ConsumerWidget {
  final ShelfTab tab;
  final ValueChanged<ShelfTab> onTab;
  const Shelf({super.key, required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Вкладка потока — с первым потоком, как кнопка ускорения: пустая
    // копилка новичку ничего не говорит, а на 320 точках пятая вкладка
    // уводит строку в прокрутку.
    final flux = ref.watch(gameProvider.select((s) => s.flux.opened)) ||
        ref.watch(fluxSpeedProvider) > 1;
    final tabs = [
      for (final t in ShelfTab.values)
        if (t != ShelfTab.flux || flux) t,
    ];
    final shown = tabs.contains(tab) ? tab : ShelfTab.stills;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(GS.s3, 0, GS.s3, GS.s2),
          child: _Tabs(tabs: tabs, selected: shown, onChanged: onTab),
        ),
        Expanded(
          child: switch (shown) {
            ShelfTab.stills => const _StillsTab(),
            ShelfTab.upgrades => const _UpgradesTab(),
            ShelfTab.flux => const FluxTab(),
            ShelfTab.goals => const GoalsTab(),
            ShelfTab.vitya => const VityaTab(),
          },
        ),
      ],
    );
  }
}

/// Высота строки вкладок — она же высота кнопки количества. Под палец.
const double _kTabsHeight = 44;

class _Tabs extends ConsumerWidget {
  final List<ShelfTab> tabs;
  final ShelfTab selected;
  final ValueChanged<ShelfTab> onChanged;
  const _Tabs({required this.tabs, required this.selected, required this.onChanged});

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
    // Поток: сколько улучшений по карману, а полная копилка — просто точка:
    // сверх неё поток уже не копится, и его пора тратить.
    final f = state.flux;
    final fluxBuys = (f.canBuyRate ? 1 : 0) + (f.canBuyBank ? 1 : 0);
    final bulk = state.achievements.hasPerk(AchievementPerk.bulkBuy);

    int? dot(ShelfTab t) => switch (t) {
          ShelfTab.stills when affordableStills > 0 => affordableStills,
          ShelfTab.upgrades when affordableUpgrades > 0 => affordableUpgrades,
          ShelfTab.flux when fluxBuys > 0 => fluxBuys,
          ShelfTab.flux when f.isBankFull => 0,
          ShelfTab.vitya when canSleep => 0,
          _ => null,
        };

    return Row(
      children: [
        Expanded(child: _tabs(context, ref, dot)),
        // Количество — в строке вкладок, а не отдельным рядом под ними: ряд
        // съедал высоту у списка ради выбора, который делают раз в десять
        // минут. Кнопка стоит на всех вкладках: исчезай она вне «АППАРАТОВ»,
        // вкладки меняли бы ширину и уезжали из-под пальца.
        if (bulk) ...[
          const SizedBox(width: GS.s1),
          const _BuyAmountButton(),
        ],
      ],
    );
  }

  TextStyle _style(bool selected) => GType.tab().copyWith(
        fontSize: 11,
        color: selected ? GColors.textHi : GColors.textMid,
      );

  Widget _tabs(BuildContext context, WidgetRef ref, int? Function(ShelfTab) dot) {
    final labels = [for (final t in tabs) t.label];
    Widget tab(int i) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (tabs[i] != selected) ref.read(feedbackProvider).buzz(Buzz.select);
            onChanged(tabs[i]);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Подложка выбранной вкладки — с отступом от края строки, а
              // ловит палец вся высота строки: отступ внутри строки отнимал
              // у кнопки шесть точек из сорока четырёх.
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: gEase,
                  margin: const EdgeInsets.all(_kTabInset),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: _kTabPad),
                  decoration: BoxDecoration(
                    color: tabs[i] == selected ? GColors.copper : null,
                    borderRadius: BorderRadius.circular(GR.pill),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(labels[i], maxLines: 1, style: _style(tabs[i] == selected)),
                  ),
                ),
              ),
              // Метка «тут есть что взять» — над углом вкладки, а не
              // числом в строке: число отнимало ширину у подписи.
              if (dot(tabs[i]) case final n?)
                Positioned(top: -3, right: 3, child: _Dot(count: n)),
            ],
          ),
        );

    return Container(
      height: _kTabsHeight,
      decoration: BoxDecoration(
        color: const Color(0x40000000),
        borderRadius: BorderRadius.circular(GR.pill),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // Сколько каждой подписи нужно, чтобы не ужиматься.
          final scaler = MediaQuery.textScalerOf(context);
          double widthOf(String label) {
            final painter = TextPainter(
              text: TextSpan(text: label, style: _style(true)),
              textDirection: TextDirection.ltr,
              textScaler: scaler,
              maxLines: 1,
            )..layout();
            final w = painter.width;
            painter.dispose();
            // Не уже 44 точек: вкладка — кнопка. «ВИТЯ» по подписи выходила
            // в 40, и на 320 точках в неё целились, а не попадали.
            return math.max(w + (_kTabPad + _kTabInset) * 2, 44.0);
          }

          final natural = [for (final label in labels) widthOf(label)];
          final needed = natural.fold<double>(0, (a, b) => a + b);

          // Помещаются — делят строку по замеренной ширине подписей: тогда
          // ужимаются все поровну, а не одна. Раньше делили по числу букв,
          // и это было почти то же самое: у заглавных Rubik знаки почти одной
          // ширины. А веса, подобранные на глаз, давали ВИТЕ лишнее, и
          // «АППАРАТЫ» на 320 точках ужимались до двух третей.
          //
          if (needed <= c.maxWidth) {
            return Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(flex: (natural[i] * 10).round(), child: tab(i)),
              ],
            );
          }
          // Не помещаются — строка листается вбок, а подписи остаются в
          // свой размер. Вкладок станет больше (поток, мудрость — план
          // релиза 1.0.0), и ужимать их все до нечитаемого кегля нельзя.
          return ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < labels.length; i++)
                SizedBox(width: natural[i] + GS.s2, child: tab(i)),
            ],
          );
        },
      ),
    );
  }
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

/// Кнопка количества — одна, по кругу: ×1 → ×10 → ×100 → МАКС.
///
/// Решение владельца (docs/DECISIONS.md, «Интерфейс»), а не деталь вёрстки.
/// 24.09 её уже меняли на ряд «БРАТЬ ПО» из четырёх кнопок под вкладками:
/// по кругу до нужного режима бывает три нажатия. Ряд же забирал у списка
/// 38 точек, и на 320×640 от первой строки аппарата оставалась половина.
///
/// Ширина постоянная: у «×1» и «×100» разная длина, и подстраивайся кнопка
/// под подпись, вкладки дёргались бы на каждом нажатии. И узкая: первая
/// такая кнопка, шириной в 56, резала «УЛУЧШЕНИЯ» на узком экране. Уже 44
/// в неё трудно попасть пальцем, а «МАКС» влезает и в 40.
///
/// Появляется только после достижения, которое открывает покупку пачками:
/// автоматизация в жанре зарабатывается, а не выдаётся.
class _BuyAmountButton extends ConsumerWidget {
  const _BuyAmountButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(buyAmountProvider);
    final i = kBuyModes.indexWhere((m) => m.$1 == mode);
    final label = i < 0 ? kBuyModes.first.$2 : kBuyModes[i].$2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(feedbackProvider).buzz(Buzz.select);
        ref.read(buyAmountProvider.notifier).state = kBuyModes[(i + 1) % kBuyModes.length].$1;
      },
      child: Container(
        width: 44,
        height: _kTabsHeight,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: GColors.surface3,
          borderRadius: BorderRadius.circular(GR.pill),
          border: Border.all(color: GColors.copper),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: GType.num(size: 12, weight: FontWeight.w700, color: GColors.textHi),
          ),
        ),
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(GS.s3, GS.s1, GS.s3, GS.s6),
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: GS.s2),
      itemBuilder: (context, k) {
        final i = visible[k];
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
      // По обычной цене, а не по сегодняшней: поправка на время (см.
      // GameEngine.upgradeCost) не должна прятать из списка то, что там
      // только что было.
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
        height: 44,
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
