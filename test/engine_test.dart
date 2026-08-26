import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/engine/production.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/prestige_state.dart';

void main() {
  const engine = GameEngine();
  final t0 = DateTime.utc(2026, 1, 1);

  GameState fresh({PrestigeState prestige = const PrestigeState()}) =>
      GameState.initial(
        initialGenerators: kGenerators,
        initialUpgrades: kUpgrades,
        prestige: prestige,
        lastUpdateTime: t0,
      );

  group('Тап', () {
    test('даёт базовую силу и считает нажатия', () {
      final s = engine.processTap(fresh(), t0);
      expect(s.resources.litres, kBaseTapPower);
      expect(s.clicker.totalTaps, 1);
      expect(s.prestige.totalEverEarned, kBaseTapPower);
    });

    test('градус умножает добычу', () {
      final s = engine.processTap(fresh(), t0, heatMultiplier: 3.0);
      expect(s.resources.litres, kBaseTapPower * 3);
    });

    test('не зависит от литров в секунду — автокликер не решает', () {
      var s = fresh();
      // Купим аппаратов, чтобы поднять пассивный доход.
      s = s.copyWith(resources: s.resources.copyWith(litres: 1e6));
      for (var i = 0; i < 20; i++) {
        s = engine.buyGenerator(s, 'banka', t0);
      }
      expect(s.litresPerSecond, greaterThan(0));

      final before = s.resources.litres;
      final after = engine.processTap(s, t0).resources.litres;
      expect(after - before, closeTo(s.tapPower, 1e-9));
    });
  });

  group('Пассивный доход', () {
    test('без аппаратов ничего не капает', () {
      final s = engine.processTick(fresh(), t0.add(const Duration(minutes: 5)));
      expect(s.resources.litres, 0);
    });

    test('начисляется пропорционально времени', () {
      var s = fresh();
      s = s.copyWith(resources: s.resources.copyWith(litres: 100));
      s = engine.buyGenerator(s, 'banka', t0); // 0.1 Л/с
      final rate = s.litresPerSecond;

      final before = s.resources.litres;
      s = engine.processTick(s, t0.add(const Duration(seconds: 10)));
      expect(s.resources.litres - before, closeTo(rate * 10, 1e-9));
    });
  });

  group('Покупки', () {
    test('не проходят без денег', () {
      final s = fresh();
      expect(engine.buyGenerator(s, 'banka', t0), same(s));
      expect(engine.buyUpgrade(s, 'tap_ruka', t0), same(s));
    });

    test('цена растёт с каждой купленной штукой', () {
      var s = fresh();
      s = s.copyWith(resources: s.resources.copyWith(litres: 1e6));
      final first = engine.generatorCost(s.generators.items.first);
      s = engine.buyGenerator(s, 'banka', t0);
      final second = engine.generatorCost(s.generators.items.first);
      expect(second, greaterThan(first));
      expect(second / first, closeTo(kCostGrowth, 1e-9));
    });

    test('апгрейд тапа удваивает силу и покупается один раз', () {
      var s = fresh();
      s = s.copyWith(resources: s.resources.copyWith(litres: 1e6));
      final before = s.tapPower;
      s = engine.buyUpgrade(s, 'tap_ruka', t0);
      expect(s.tapPower, closeTo(before * 2, 1e-9));

      final spent = s.resources.litres;
      s = engine.buyUpgrade(s, 'tap_ruka', t0);
      expect(s.resources.litres, spent, reason: 'повторная покупка не должна списывать');
    });
  });

  group('Milestones', () {
    test('удваивают доход на 10/25/50/100', () {
      expect(Production.milestoneMultiplier(9), 1);
      expect(Production.milestoneMultiplier(10), 2);
      expect(Production.milestoneMultiplier(25), 4);
      expect(Production.milestoneMultiplier(50), 8);
      expect(Production.milestoneMultiplier(100), 16);
    });

    test('десятая банка даёт скачок больше, чем девятая', () {
      var s = fresh();
      s = s.copyWith(resources: s.resources.copyWith(litres: 1e9));
      final rates = <double>[];
      for (var i = 0; i < 10; i++) {
        s = engine.buyGenerator(s, 'banka', t0);
        rates.add(s.litresPerSecond);
      }
      final ninthStep = rates[8] - rates[7];
      final tenthStep = rates[9] - rates[8];
      expect(tenthStep, greaterThan(ninthStep * 2));
    });
  });

  group('Похмелье', () {
    test('без накоплений не даёт мудрости', () {
      final s = fresh();
      expect(s.prestige.canPrestige, isFalse);
      expect(engine.prestige(s, kGenerators, kUpgrades, t0), same(s));
    });

    test('мудрость считается как корень из нагнанного', () {
      const p = PrestigeState(totalEverEarned: 25e6);
      expect(p.potentialWisdom, 5);
      expect(p.pendingWisdom, 5);
    });

    test('сбрасывает гараж, но сохраняет мудрость и историю', () {
      var s = fresh(prestige: const PrestigeState(totalEverEarned: 25e6));
      s = s.copyWith(resources: s.resources.copyWith(litres: 1e6));
      s = engine.buyGenerator(s, 'banka', t0);

      final after = engine.prestige(s, kGenerators, kUpgrades, t0);
      expect(after.resources.litres, 0, reason: 'литры сгорают');
      expect(after.generators.items.first.ownedCount, 0, reason: 'аппараты сброшены');
      expect(after.prestige.wisdom, 5, reason: 'мудрость остаётся');
      expect(after.prestige.hangovers, 1);
      expect(after.prestige.totalEverEarned, 25e6, reason: 'история не обнуляется');
    });

    test('мудрость ускоряет следующий заход', () {
      final plain = fresh();
      final wise = fresh(prestige: const PrestigeState(wisdom: 10));
      expect(wise.tapPower, closeTo(plain.tapPower * 1.5, 1e-9));
    });
  });
}
