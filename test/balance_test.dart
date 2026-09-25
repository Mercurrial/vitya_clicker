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
    // Одна оценка на всю группу: в ней партия на 15 часов с похмельями, и
    // гонять её на каждый тест — минуты впустую.
    late Score score;

    setUpAll(() => score = scoreBalance(kBalance));

    test('первая мудрость у того, кто считает, — через 2,5 часа', () {
      final at = score.firstWisdom;
      expect(at, isNotNull, reason: 'первой мудрости нет вовсе');
      expect(at!, greaterThanOrEqualTo(BalanceTargets.firstWisdomMin),
          reason: 'первая мудрость в ${formatClock(at)} — раньше решения владельца');
      expect(at, lessThanOrEqualTo(BalanceTargets.firstWisdomMax),
          reason: 'первая мудрость в ${formatClock(at)} — позже решения владельца');
    });

    test('обычный игрок доходит до первой мудрости не позже 4,5 часа', () {
      expect(score.firstWisdomCasual, isNotNull);
      expect(score.firstWisdomCasual!, lessThanOrEqualTo(BalanceTargets.firstWisdomCasualMax),
          reason: 'у «обычного» первая мудрость в ${formatClock(score.firstWisdomCasual)}');
    });

    test('порог первой мудрости снят с кривой, а не подобран', () {
      // Поменяли лестницу или улучшения и забыли снять порог заново — 2,5
      // часа уехали бы молча. Цель выше это тоже поймает, но позже и
      // невнятно; здесь сказано, что делать.
      final curve = firstWisdomFromCurve(kBalance);
      expect(kBalance.firstWisdomMl / curve, closeTo(1, 0.02),
          reason: 'кривая к 2,5 ч даёт ${curve.toStringAsExponential(3)} мл, '
              'а в kBalance записано ${kBalance.firstWisdomMl.toStringAsExponential(3)}: '
              'перепиши firstWisdomMl');
    });

    test('к первой мудрости открыто 8–10 ступеней из 13', () {
      expect(score.tiersAtFirstWisdom,
          inInclusiveRange(BalanceTargets.tiersAtFirstWisdomMin, BalanceTargets.tiersAtFirstWisdomMax));
    });

    test('окупаемость в каждом заходе — минуты, а не часы', () {
      expect(score.paybackByRun, isNotEmpty);
      for (final (i, r) in score.paybackByRun.indexed) {
        final run = 'заход ${i + 1}: медиана ${formatDuration(r.median)}, '
            '90 % ${formatDuration(r.p90)}, худшая ${formatDuration(r.worst)}';
        if (r.finished) {
          expect(r.median, greaterThanOrEqualTo(BalanceTargets.paybackMedianMin),
              reason: '$run — покупка, которая окупается за секунды, перестаёт быть решением');
          expect(r.median, lessThanOrEqualTo(BalanceTargets.paybackMedianMax), reason: run);
        }
        expect(r.p90, lessThanOrEqualTo(BalanceTargets.paybackP90Max), reason: run);
        expect(r.worst, lessThanOrEqualTo(BalanceTargets.paybackWorstMax),
            reason: '$run — стена: игрок ждёт, а не играет');
      }
    });

    test('после первой мудрости — рывок: второй заход 40–55 % первого', () {
      expect(score.rerunShare, isNotNull);
      expect(score.rerunShare!,
          inInclusiveRange(BalanceTargets.rerunMin, BalanceTargets.rerunMax));
    });

    test('12-я ступень — через 10–14 часов игры', () {
      expect(score.tier12At, isNotNull, reason: 'за партию до 12-й ступени не дошли');
      final reason = '12-я ступень на ${formatDuration(score.tier12At)}';
      expect(score.tier12At!, greaterThanOrEqualTo(BalanceTargets.tier12Min), reason: reason);
      expect(score.tier12At!, lessThanOrEqualTo(BalanceTargets.tier12Max), reason: reason);
    });

    test('ночь открытой вкладки не даёт мудрость за пару минут игры', () {
      expect(score.overnightTab!, greaterThanOrEqualTo(BalanceTargets.overnightTabMin),
          reason: 'хватает ${score.overnightTab!.inMinutes} мин игры и ночи вкладки');
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
      expect(scoreBalance(broken, quick: true).penalty, greaterThan(0));
    });
  });
}
