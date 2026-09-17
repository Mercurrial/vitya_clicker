import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/balance.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/sim/balance_sim.dart';
import 'package:idle_game/sim/balance_targets.dart';

/// Проверка баланса прогоном, а не рассуждением.
///
/// Прошлый баланс сломался именно потому, что проверялся рассуждением: каждая
/// формула по отдельности выглядела разумной, а игра целиком разваливалась за
/// полчаса — и узнали мы об этом от человека, который в неё поиграл.
///
/// Эти тесты медленнее обычных (каждый прогоняет несколько часов игрового
/// времени), и это нормально: один прогон здесь стоит дешевле, чем один
/// испорченный вечер у игрока.
void main() {
  group('Действующий баланс попадает в цели', () {
    late Score score;

    setUpAll(() => score = scoreBalance(kBalance));

    test('первое похмелье наступает не слишком рано и не слишком поздно', () {
      final at = score.firstPrestige;
      expect(at, isNotNull, reason: 'до похмелья вообще не дошли за 4 часа');
      expect(
        at!,
        greaterThanOrEqualTo(BalanceTargets.prestigeMin),
        reason: 'престиж раньше, чем игрок понял правила, обесценивает всё до него',
      );
      expect(at, lessThanOrEqualTo(BalanceTargets.prestigeMax));
    });

    test('окупаемость покупки держится в районе минут, а не секунд', () {
      final median = Duration(seconds: score.medianPayback.round());
      expect(
        median,
        greaterThanOrEqualTo(BalanceTargets.paybackMin),
        reason: 'покупка, которая окупается за секунды, перестаёт быть решением',
      );
      expect(
        median,
        lessThanOrEqualTo(BalanceTargets.paybackMax),
        reason: 'слишком долгая окупаемость ощущается как стоячая игра',
      );
    });

    test('лестница не проходится за один вечер', () {
      expect(score.tiersReached, greaterThanOrEqualTo(BalanceTargets.minTiersInFourHours));
      expect(
        score.tiersReached,
        lessThanOrEqualTo(BalanceTargets.maxTiersInFourHours),
        reason: 'если все 13 аппаратов открыты за 4 часа, дальше играть не во что',
      );
    });

    test('бак не разрастается до размеров, при которых продажа не нужна', () {
      expect(
        score.maxTankBuffer,
        lessThanOrEqualTo(BalanceTargets.tankMax),
        reason: 'бак на несколько часов убивает и рынок, и сорт: продавать незачем',
      );
    });

    test('в сумме — ни одного промаха', () {
      expect(score.penalty, 0.0, reason: 'подробности в тестах выше');
    });
  });

  group('Экономика ведёт себя как экономика', () {
    test('невнимательный игрок отстаёт от внимательного, но не стоит', () {
      const sim = BalanceSim();
      final tryhard = sim.run(PlayStyle.tryhard, horizon: const Duration(hours: 2));
      final casual = sim.run(PlayStyle.casual, horizon: const Duration(hours: 2));

      expect(
        casual.peakMlPerSecond,
        greaterThan(0),
        reason: 'тот, кто играет вполсилы, всё равно обязан двигаться',
      );
      // Мерить «кто купил больше РАЗНЫХ вещей» нельзя: тот, кто берёт всё
      // подряд подешевле, наберёт больше наименований, ничего этим не добившись.
      // Внимание окупается производством, а не ассортиментом.
      expect(
        tryhard.peakMlPerSecond,
        greaterThan(casual.peakMlPerSecond),
        reason: 'внимание должно окупаться, иначе играть внимательно незачем',
      );
    });

    test('редкие заходы не запирают игрока навсегда', () {
      // Жанр требует первого клика, но дальше игра обязана двигаться сама.
      const sim = BalanceSim();
      final idle = sim.run(PlayStyle.idler, horizon: const Duration(hours: 4));
      expect(
        idle.peakMlPerSecond,
        greaterThan(0),
        reason: 'четыре захода в день должны хотя бы запустить производство',
      );
    });

    test('продажа остаётся регулярным действием, а не разовым', () {
      const sim = BalanceSim();
      final r = sim.run(PlayStyle.casual, horizon: const Duration(hours: 2));
      expect(
        r.sales,
        greaterThan(20),
        reason: 'если за два часа продаж единицы — рынок и сорт декоративны',
      );
    });

    test('ни один аппарат не остаётся вечно бесполезным', () {
      // Каждая ступень обязана когда-нибудь стать лучшей покупкой. Ступень,
      // которая ни разу не выгодна, — это выброшенная работа.
      const sim = BalanceSim();
      final r = sim.run(PlayStyle.tryhard, horizon: const Duration(hours: 4));
      final reached = r.firstBuy.keys.toSet();
      final ladder = [for (final g in kGeneratorNames) g.id];

      // Купленные ступени обязаны идти подряд от начала: пропуск означает,
      // что какая-то ступень хуже следующей и её просто перешагнули.
      var seenGap = false;
      for (final id in ladder) {
        if (!reached.contains(id)) {
          seenGap = true;
        } else if (seenGap) {
          fail('ступень $id куплена, а предыдущая — нет: лестница с дырой');
        }
      }
    });
  });

  group('Смена баланса', () {
    test('withBalance возвращает всё как было', () {
      final before = Balance.current;
      withBalance(kBalance.copyWith(costGrowth: 2.0), () {
        expect(Balance.current.costGrowth, 2.0);
      });
      expect(identical(Balance.current, before), isTrue);
    });

    test('withBalance восстанавливает баланс даже при исключении', () {
      final before = Balance.current;
      expect(
        () => withBalance(kBalance.copyWith(costGrowth: 2.0), () {
          throw StateError('упало');
        }),
        throwsStateError,
      );
      expect(identical(Balance.current, before), isTrue,
          reason: 'иначе один упавший тест испортит все следующие');
    });

    test('лестница пересобирается под новый баланс', () {
      final base = kGenerators.first.baseCost;
      withBalance(kBalance.copyWith(firstGeneratorCost: base * 10), () {
        expect(kGenerators.first.baseCost, closeTo(base * 10, 1e-9));
      });
      expect(kGenerators.first.baseCost, closeTo(base, 1e-9));
    });

    test('заведомо сломанный баланс тест не пропустит', () {
      // Страховка на саму проверку: если цели перестанут ловить разнос,
      // они бесполезны. Дешёвые аппараты — это та самая экономика,
      // которая развалилась в первый раз.
      final broken = kBalance.copyWith(costGrowth: 1.05, tierCostRatio: 4);
      expect(scoreBalance(broken).penalty, greaterThan(0));
    });
  });
}
