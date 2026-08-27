import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/achievements.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/engine/formulas.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/achievement.dart';
import 'package:idle_game/models/achievements_state.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/prestige_state.dart';

void main() {
  const engine = GameEngine();
  const formulas = Formulas();
  final t0 = DateTime.utc(2026, 1, 1);

  GameState fresh() => GameState.initial(
        initialGenerators: kGenerators,
        initialUpgrades: kUpgrades,
        lastUpdateTime: t0,
      );

  GameState withMoney(double money) {
    final s = fresh();
    return s.copyWith(resources: s.resources.copyWith(money: money));
  }

  group('Открытие достижений', () {
    test('новая игра начинается без единого', () {
      expect(fresh().achievements.count, 0);
      expect(fresh().achievements.multiplier, 1.0);
    });

    test('условие выполнено — достижение выдаётся', () {
      final tapped = engine.processTap(fresh(), t0);
      final checked = engine.checkAchievements(tapped);

      expect(checked.fresh.map((a) => a.id), contains('a_first_tap'));
      expect(checked.state.achievements.has('a_first_tap'), isTrue);
    });

    test('повторная проверка не выдаёт то же самое дважды', () {
      var s = engine.processTap(fresh(), t0);
      s = engine.checkAchievements(s).state;
      final again = engine.checkAchievements(s);

      expect(again.fresh, isEmpty);
      expect(again.state, same(s));
    });

    test('за раз может открыться сразу несколько', () {
      // Одной покупкой закрываются и «Первый рубль» (деньги на счету), и
      // «Начало дела» (аппарат куплен).
      var s = withMoney(1000);
      s = engine.buyGenerator(s, 'banka', t0);
      final checked = engine.checkAchievements(s);

      final ids = checked.fresh.map((a) => a.id).toSet();
      expect(ids, containsAll(['a_first_still', 'a_first_sale']));
      expect(ids.length, greaterThanOrEqualTo(2));
    });
  });

  group('Множитель', () {
    test('каждое достижение множит на свою долю', () {
      const one = AchievementsState(unlocked: {'a_first_tap'});
      expect(one.multiplier, closeTo(kAchievementMultiplier, 1e-12));
    });

    test('закрытый ряд добавляет отдельный, крупный множитель', () {
      final row = kAchievementRows.first;
      final all = AchievementsState(
        unlocked: {for (final a in row.items) a.id},
      );

      var expected = 1.0;
      for (var i = 0; i < row.items.length; i++) {
        expected *= kAchievementMultiplier;
      }
      expected *= kRowMultiplier;

      expect(all.completedRows, 1);
      expect(all.multiplier, closeTo(expected, 1e-12));
    });

    test('неполный ряд множителя ряда не даёт', () {
      final row = kAchievementRows.first;
      final partial = AchievementsState(
        unlocked: {for (final a in row.items.take(row.items.length - 1)) a.id},
      );
      expect(partial.completedRows, 0);
    });

    test('множитель реально ускоряет производство', () {
      var plain = withMoney(1e6);
      plain = engine.buyGenerator(plain, 'banka', t0);

      final boosted = plain.copyWith(
        achievements: const AchievementsState(
          unlocked: {'a_first_tap', 'a_first_still'},
        ),
      );

      expect(boosted.mlPerSecond, greaterThan(plain.mlPerSecond));
      expect(
        boosted.mlPerSecond,
        closeTo(plain.mlPerSecond * boosted.achievements.multiplier, 1e-9),
      );
    });
  });

  group('Открываемые функции', () {
    test('автопродажа приходит с закрытием ряда «Хозяйство»', () {
      final row = kAchievementRows[1];
      final state = AchievementsState(unlocked: {for (final a in row.items) a.id});
      expect(state.hasPerk(AchievementPerk.autoSell), isTrue);
    });

    test('без нужного достижения функции нет', () {
      const state = AchievementsState(unlocked: {'a_first_tap'});
      expect(state.hasPerk(AchievementPerk.autoSell), isFalse);
      expect(state.hasPerk(AchievementPerk.bulkBuy), isFalse);
    });
  });

  group('Похмелье', () {
    test('достижения переживают сброс вместе с мудростью', () {
      var s = fresh().copyWith(
        prestige: const PrestigeState(
          totalEverEarned: 25 * PrestigeState.mlPerWisdomStep,
        ),
        achievements: const AchievementsState(
          unlocked: {'a_first_tap', 'a_first_still'},
        ),
      );
      s = engine.prestige(s, kGenerators, kUpgrades, t0);

      expect(s.achievements.count, 2,
          reason: 'иначе открытые функции отбирались бы обратно');
      expect(s.prestige.wisdom, 5);
    });
  });

  group('Покупка пачками', () {
    test('цена пачки равна сумме отдельных покупок', () {
      final g = kGenerators.first;
      var manual = 0.0;
      for (var i = 0; i < 25; i++) {
        manual += formulas.calculateUpgradeCost(
          g.baseCost,
          g.costGrowthFactor,
          g.ownedCount + i,
        );
      }
      expect(
        formulas.bulkCost(g.baseCost, g.costGrowthFactor, g.ownedCount, 25),
        closeTo(manual, 1e-6),
      );
    });

    test('максимум никогда не уводит в минус', () {
      final g = kGenerators.first;
      for (final money in [0.0, 14.0, 15.0, 100.0, 12345.0, 1e9]) {
        final n = formulas.maxAffordable(
          g.baseCost,
          g.costGrowthFactor,
          g.ownedCount,
          money,
        );
        expect(
          formulas.bulkCost(g.baseCost, g.costGrowthFactor, g.ownedCount, n),
          lessThanOrEqualTo(money + 1e-6),
          reason: 'на $money ₽ насчитали $n штук',
        );
      }
    });

    test('максимум действительно максимальный: ещё одна уже не по карману', () {
      final g = kGenerators.first;
      const money = 5000.0;
      final n = formulas.maxAffordable(
        g.baseCost,
        g.costGrowthFactor,
        g.ownedCount,
        money,
      );
      expect(
        formulas.bulkCost(g.baseCost, g.costGrowthFactor, g.ownedCount, n + 1),
        greaterThan(money),
      );
    });

    test('пачка добавляет ровно столько штук и списывает ровно столько денег', () {
      var s = withMoney(1e6);
      final g = s.generators.items.first;
      final cost = engine.bulkCost(g, 10);

      s = engine.buyGeneratorBulk(s, g.id, 10, t0);

      expect(s.generators.items.first.ownedCount, 10);
      expect(s.resources.money, closeTo(1e6 - cost, 1e-6));
    });

    test('денег не хватает — берём сколько выходит, а не падаем', () {
      var s = withMoney(100);
      s = engine.buyGeneratorBulk(s, 'banka', 100, t0);

      expect(s.generators.items.first.ownedCount, greaterThan(0));
      expect(s.generators.items.first.ownedCount, lessThan(100));
      expect(s.resources.money, greaterThanOrEqualTo(0));
    });

    test('без денег покупка пачкой ничего не меняет', () {
      final s = fresh();
      expect(engine.buyGeneratorBulk(s, 'banka', 10, t0), same(s));
    });
  });
}
