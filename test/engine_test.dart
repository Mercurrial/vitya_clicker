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
      expect(s.resources.ml, kBaseTapMl);
      expect(s.clicker.totalTaps, 1);
      expect(s.prestige.totalEverEarned, kBaseTapMl);
    });

    test('градус умножает добычу', () {
      final s = engine.processTap(fresh(), t0, heatMultiplier: 3.0);
      expect(s.resources.ml, kBaseTapMl * 3);
    });

    test('отдача не обесценивается: растёт вместе с производством', () {
      var s = fresh();
      final atStart = s.tapYield;

      // Разгоняем пассивный доход.
      s = s.copyWith(resources: s.resources.copyWith(money: 1e9));
      for (var i = 0; i < 40; i++) {
        s = engine.buyGenerator(s, 'banka', t0);
      }
      expect(s.mlPerSecond, greaterThan(0));

      // Именно это чинит «через пять минут тап стал бесполезен»: отдача — доля
      // текущего потока, а не константа.
      expect(s.tapYield, greaterThan(atStart));
      expect(s.tapYield, closeTo(s.mlPerSecond * Production.tapSeconds, 1e-9));
    });
  });

  group('Пассивный доход', () {
    test('без аппаратов ничего не капает', () {
      final s = engine.processTick(fresh(), t0.add(const Duration(minutes: 5)));
      expect(s.resources.ml, 0);
    });

    test('начисляется пропорционально времени', () {
      var s = fresh();
      s = s.copyWith(resources: s.resources.copyWith(money: 100));
      s = engine.buyGenerator(s, 'banka', t0); // 1 мл/с
      final rate = s.mlPerSecond;

      final before = s.resources.ml;
      s = engine.processTick(s, t0.add(const Duration(seconds: 10)));
      expect(s.resources.ml - before, closeTo(rate * 10, 1e-9));
    });

    test('жар множит ВЕСЬ поток — ради этого и тапают', () {
      var s = fresh();
      s = s.copyWith(resources: s.resources.copyWith(money: 1e6));
      for (var i = 0; i < 5; i++) {
        s = engine.buyGenerator(s, 'banka', t0);
      }
      final base = s.resources.ml;
      final span = t0.add(const Duration(seconds: 10));

      final cold = engine.processTick(s, span).resources.ml - base;
      final hot = engine.processTick(s, span, heatMultiplier: 3.0).resources.ml - base;

      expect(hot, closeTo(cold * 3, 1e-9));
    });

    test('отсутствие не наказывается: без жара идёт базовая скорость', () {
      var s = fresh();
      s = s.copyWith(resources: s.resources.copyWith(money: 1e6));
      s = engine.buyGenerator(s, 'banka', t0);
      final base = s.resources.ml;
      final span = t0.add(const Duration(seconds: 10));

      final offline = engine.processTick(s, span).resources.ml - base;
      expect(offline, closeTo(s.mlPerSecond * 10, 1e-9));
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
      s = s.copyWith(resources: s.resources.copyWith(money: 1e6));
      final first = engine.generatorCost(s.generators.items.first);
      s = engine.buyGenerator(s, 'banka', t0);
      final second = engine.generatorCost(s.generators.items.first);
      expect(second, greaterThan(first));
      expect(second / first, closeTo(kCostGrowth, 1e-9));
    });

    test('апгрейд тапа удваивает силу и покупается один раз', () {
      var s = fresh();
      s = s.copyWith(resources: s.resources.copyWith(money: 1e6));
      final before = s.tapYield;
      s = engine.buyUpgrade(s, 'tap_ruka', t0);
      expect(s.tapYield, closeTo(before * 2, 1e-9));

      final spent = s.resources.money;
      s = engine.buyUpgrade(s, 'tap_ruka', t0);
      expect(s.resources.money, spent, reason: 'повторная покупка не должна списывать');
    });

    test('покупка списывает рубли, а не самогон', () {
      var s = fresh();
      s = s.copyWith(
        resources: s.resources.copyWith(money: 1000, ml: 500),
      );
      final cost = engine.generatorCost(s.generators.items.first);
      s = engine.buyGenerator(s, 'banka', t0);

      expect(s.resources.money, closeTo(1000 - cost, 1e-9));
      expect(s.resources.ml, 500, reason: 'товар в баке трогать нельзя');
    });
  });

  group('Бак растёт вместе с производством', () {
    // Ровно та системная поломка, которую нашёл плейтест: производство растёт
    // экспоненциально, а бак множителями — и он неизбежно отстаёт. Бак
    // заполнялся за шесть секунд, idle превращался в дежурство у кнопки, а
    // рынок обесценивался, потому что продавать приходилось всегда.
    test('запас времени не проседает при росте потока', () {
      var small = fresh();
      small = small.copyWith(resources: small.resources.copyWith(money: 1e12));
      // Достаточно аппаратов, чтобы поток, а не нижняя граница, задавал бак.
      for (var i = 0; i < 5; i++) {
        small = engine.buyGenerator(small, 'bidon', t0);
      }
      final smallBuffer = small.tankBuffer;

      var big = small;
      for (var i = 0; i < 30; i++) {
        big = engine.buyGenerator(big, 'bidon', t0);
        big = engine.buyGenerator(big, 'flyaga', t0);
      }

      expect(big.mlPerSecond, greaterThan(small.mlPerSecond * 50));
      expect(
        big.tankBuffer.inSeconds,
        closeTo(smallBuffer.inSeconds, 2),
        reason: 'запас времени должен держаться, а не таять',
      );
      expect(big.tankCapacity, greaterThan(small.tankCapacity * 50));
    });

    test('улучшение тары покупает время, а не литры', () {
      var s = fresh();
      s = s.copyWith(resources: s.resources.copyWith(money: 1e9));
      for (var i = 0; i < 10; i++) {
        s = engine.buyGenerator(s, 'bidon', t0);
      }
      final before = s.tankBuffer;
      s = engine.buyUpgrade(s, 'tank_kanistra', t0);

      expect(s.tankBuffer.inSeconds, closeTo(before.inSeconds * 2, 2));
    });

    test('в самом начале действует нижняя граница', () {
      final s = fresh();
      expect(s.mlPerSecond, 0);
      expect(s.tankCapacity, Production.baseTankMl);
    });
  });

  group('Бак', () {
    test('производство упирается в ёмкость', () {
      var s = fresh();
      s = s.copyWith(resources: s.resources.copyWith(money: 1e9));
      for (var i = 0; i < 30; i++) {
        s = engine.buyGenerator(s, 'bidon', t0);
      }
      // Целый час при таком потоке залил бы куда больше ёмкости.
      s = engine.processTick(s, t0.add(const Duration(hours: 1)));

      expect(s.resources.ml, closeTo(s.tankCapacity, 1e-6));
      expect(s.isTankFull, isTrue);
    });

    test('в полный бак не капает даже с тапа', () {
      var s = fresh();
      s = s.copyWith(resources: s.resources.copyWith(ml: s.tankCapacity));
      final before = s.resources.ml;
      s = engine.processTap(s, t0);

      expect(s.resources.ml, before);
      expect(s.clicker.totalTaps, 1, reason: 'нажатие всё равно засчитано');
    });

    test('улучшение бака увеличивает ёмкость', () {
      var s = fresh();
      s = s.copyWith(resources: s.resources.copyWith(money: 1e6));
      // Нужен поток: иначе ёмкость держит нижняя граница и множитель не виден.
      for (var i = 0; i < 10; i++) {
        s = engine.buyGenerator(s, 'bidon', t0);
      }
      final before = s.tankCapacity;
      s = engine.buyUpgrade(s, 'tank_kanistra', t0);
      expect(s.tankCapacity, closeTo(before * 2, 1e-6));
    });
  });

  group('Оффлайн', () {
    // Регрессия: запуск игры считал отсутствие по своей копии формулы, которая
    // не знала про ёмкость. После перезагрузки в бак на 2 литра наливалось
    // сорок с лишним тысяч.
    test('за сутки отсутствия бак не переполняется', () {
      var s = fresh();
      s = s.copyWith(resources: s.resources.copyWith(money: 1e9));
      for (var i = 0; i < 20; i++) {
        s = engine.buyGenerator(s, 'bidon', t0);
      }

      final result = engine.creditOffline(s, const Duration(days: 1), t0);

      expect(result.state.resources.ml, lessThanOrEqualTo(s.tankCapacity + 1e-6));
      expect(result.gained, lessThanOrEqualTo(s.tankCapacity + 1e-6));
      expect(result.gained, greaterThan(0));
    });

    test('начисленное совпадает с приростом бака', () {
      var s = fresh();
      s = s.copyWith(resources: s.resources.copyWith(money: 1e6));
      s = engine.buyGenerator(s, 'banka', t0);

      final before = s.resources.ml;
      final result = engine.creditOffline(s, const Duration(seconds: 30), t0);

      expect(result.gained, closeTo(result.state.resources.ml - before, 1e-9));
    });

    test('нулевое отсутствие ничего не меняет', () {
      final s = fresh();
      final result = engine.creditOffline(s, Duration.zero, t0);
      expect(result.gained, 0);
      expect(result.state, same(s));
    });
  });

  group('Продажа', () {
    test('переводит бак в рубли и опустошает его', () {
      var s = fresh();
      s = s.copyWith(resources: s.resources.copyWith(ml: 1000));
      final expected = engine.saleValue(s, t0);

      s = engine.sell(s, t0);
      expect(s.resources.ml, 0);
      expect(s.resources.money, closeTo(expected, 1e-9));
      expect(expected, greaterThan(0));
    });

    test('пустой бак продать нельзя', () {
      final s = fresh();
      expect(engine.sell(s, t0), same(s));
    });

    test('качество поднимает выручку за тот же объём', () {
      var plain = fresh();
      plain = plain.copyWith(resources: plain.resources.copyWith(ml: 1000));

      var good = fresh();
      good = good.copyWith(
        resources: good.resources.copyWith(money: 1e6, ml: 1000),
      );
      good = engine.buyUpgrade(good, 'q_peregonka', t0);

      expect(
        engine.saleValue(good, t0),
        greaterThan(engine.saleValue(plain, t0)),
      );
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
      s = s.copyWith(resources: s.resources.copyWith(money: 1e9));
      final rates = <double>[];
      for (var i = 0; i < 10; i++) {
        s = engine.buyGenerator(s, 'banka', t0);
        rates.add(s.mlPerSecond);
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
      // 25 шагов по 1e7 мл ⇒ √25 = 5.
      const p = PrestigeState(
        totalEverEarned: 25 * PrestigeState.mlPerWisdomStep,
      );
      expect(p.potentialWisdom, 5);
      expect(p.pendingWisdom, 5);
    });

    test('сбрасывает гараж, но сохраняет мудрость и историю', () {
      const earned = 25 * PrestigeState.mlPerWisdomStep;
      var s = fresh(prestige: const PrestigeState(totalEverEarned: earned));
      s = s.copyWith(resources: s.resources.copyWith(money: 1e6));
      s = engine.buyGenerator(s, 'banka', t0);

      final after = engine.prestige(s, kGenerators, kUpgrades, t0);
      expect(after.resources.ml, 0, reason: 'накопленное сгорает');
      expect(after.generators.items.first.ownedCount, 0, reason: 'аппараты сброшены');
      expect(after.prestige.wisdom, 5, reason: 'мудрость остаётся');
      expect(after.prestige.hangovers, 1);
      expect(after.prestige.totalEverEarned, earned, reason: 'история не обнуляется');
    });

    test('мудрость ускоряет следующий заход', () {
      final plain = fresh();
      final wise = fresh(prestige: const PrestigeState(wisdom: 10));
      expect(wise.tapYield, closeTo(plain.tapYield * 1.5, 1e-9));
    });
  });
}
