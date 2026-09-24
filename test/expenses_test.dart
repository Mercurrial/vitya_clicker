import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/buyers.dart';
import 'package:idle_game/content/events.dart';
import 'package:idle_game/content/expenses.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/content/raid.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/engine/market.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/sort_state.dart';

import 'support/moments.dart';

/// События с расходом.
///
/// Главное обещание механики — расход бьёт только по решениям: покупке и
/// продаже. Отсюда и проверки: цена, которую видишь, равна цене, которую
/// спишут; тот, кто не играет, не теряет ничего; гостей тёща не касается.
void main() {
  final start = DateTime.utc(2026, 6, 1);
  const engine = GameEngine();

  GameState rich(DateTime now) {
    final s = newGame(content: kGenerators, upgrades: kUpgrades, now: now);
    return s.copyWith(resources: s.resources.copyWith(money: 1e9, ml: 5000));
  }

  group('Неприятности случаются, но не постоянно', () {
    test('большую часть времени всё как обычно', () {
      var busy = 0;
      const minutes = 7 * 24 * 60;
      for (var m = 0; m < minutes; m++) {
        if (expenseAt(start.add(Duration(minutes: m))) != null) busy++;
      }
      final share = busy / minutes;
      expect(share, lessThan(0.25),
          reason: 'расход, который идёт всегда, — это просто новые цены: '
              'занято ${(share * 100).round()}% времени');
      expect(share, greaterThan(0.03),
          reason: 'неприятности, которой не бывает, не существует');
    });

    test('все неприятности когда-нибудь выпадают', () {
      final seen = <String>{};
      for (var m = 0; m < 14 * 24 * 60; m += 5) {
        final e = expenseAt(start.add(Duration(minutes: m)));
        if (e != null) seen.add(e.expense.id);
      }
      expect(seen, kGarageExpenses.map((e) => e.id).toSet());
    });

    test('не ходят парой ни с гостем, ни с участковым', () {
      // Своё зерно у каждого расписания. Совпадения случайны и редки; если
      // они частые, зёрна перепутались.
      var withGuest = 0, withRaid = 0;
      const minutes = 7 * 24 * 60;
      for (var m = 0; m < minutes; m++) {
        final now = start.add(Duration(minutes: m));
        if (expenseAt(now) == null) continue;
        if (eventAt(now) != null) withGuest++;
        if (raidAt(now) != null) withRaid++;
      }
      // Случайное пересечение двух независимых расписаний — порядка
      // произведения их долей, то есть несколько процентов. Лесенка из
      // одинаковых зёрен дала бы все десятки.
      expect(withGuest / minutes, lessThan(0.06));
      expect(withRaid / minutes, lessThan(0.01));
    });

    test('остаток убывает и не выходит за длину окна', () {
      for (var m = 0; m < 24 * 60; m++) {
        final e = expenseAt(start.add(Duration(minutes: m)));
        if (e == null) continue;
        expect(e.remaining, greaterThan(Duration.zero));
        expect(e.remaining, lessThanOrEqualTo(kExpenseWindow));
      }
    });

    test('расписание одно на всех: пояс ничего не меняет', () {
      final utc = DateTime.utc(2026, 6, 1, 14, 5);
      expect(expenseAt(utc.toLocal())?.expense.id, expenseAt(utc)?.expense.id);
    });
  });

  group('Переждать можно, но не обязательно', () {
    test('подорожание заметное, но не вдвое', () {
      for (final e in kGarageExpenses) {
        final hit = e.kind == ExpenseKind.supplies ? e.factor : 1 / e.factor;
        expect(hit, greaterThan(1.1), reason: '${e.id}: незаметно — не событие');
        expect(hit, lessThan(1.6),
            reason: '${e.id}: при такой разнице выбора нет — только ждать');
      }
    });

    test('окно короче получаса: переждать реально', () {
      expect(kExpenseWindow, lessThan(const Duration(minutes: 30)));
    });
  });

  group('Сахар подорожал', () {
    final t = supplyMoment;
    final factor = kGarageExpenses
        .firstWhere((e) => e.kind == ExpenseKind.supplies)
        .factor;

    test('аппарат дороже ровно на множитель', () {
      final g = rich(quietMoment).generators.items.first;
      expect(engine.generatorCost(g, t),
          closeTo(engine.generatorCost(g, quietMoment) * factor, 1e-9));
    });

    test('списывают ту же цену, что показали — и за штуку, и за пачку', () {
      // Показанная и списанная цена считаются одной функцией. Проверяем
      // именно это: разойтись им — худшее, что может сделать магазин.
      var s = rich(t);
      final g = s.generators.items.first;

      final one = engine.generatorCost(g, t);
      var after = engine.buyGenerator(s, g.id, t);
      expect(s.resources.money - after.resources.money, closeTo(one, 1e-6));

      final ten = engine.bulkCost(g, 10, t);
      after = engine.buyGeneratorBulk(s, g.id, 10, t);
      expect(s.resources.money - after.resources.money, closeTo(ten, 1e-6));

      final u = s.upgrades.items.first;
      final cost = engine.upgradeCost(u, t);
      expect(cost, closeTo(u.cost * factor, 1e-9));
      after = engine.buyUpgrade(s, u.id, t);
      expect(s.resources.money - after.resources.money, closeTo(cost, 1e-6));
    });

    test('«сколько влезет» считается по сегодняшней цене', () {
      var s = rich(t);
      final g = s.generators.items.first;
      s = s.copyWith(
        resources: s.resources.copyWith(money: engine.generatorCost(g, quietMoment)),
      );
      expect(engine.affordableCount(s, g, quietMoment), 1);
      expect(engine.affordableCount(s, g, t), 0,
          reason: 'обещать штуку, которую не продадут, нельзя');
      expect(engine.buyGenerator(s, g.id, t), same(s));
    });

    test('продажу не трогает', () {
      final s = rich(t);
      expect(neighborFactorAt(t), 1.0);
      expect(
        engine.saleValueFor(s, kBuyers.first, t),
        greaterThan(0),
      );
    });
  });

  group('Тёща у Петровича', () {
    final t = neighborMoment;
    final factor = kGarageExpenses
        .firstWhere((e) => e.kind == ExpenseKind.neighbor)
        .factor;

    test('Петрович платит меньше ровно на множитель', () {
      final s = rich(t);
      // Та же сделка без тёщи — по тому же рынку и сорту, посчитанная вручную.
      final fair = s.resources.ml *
          Market.pricePerMl(t, s.upgrades) *
          s.sort.multiplier *
          kBuyers.first.multiplier;

      final withCut = engine.saleValueFor(s, kBuyers.first, t);
      expect(withCut, closeTo(fair * factor, 1e-6));

      // И списывают ровно показанное.
      final sold = engine.sellTo(s, kBuyers.first, t);
      expect(sold.resources.money - s.resources.money, closeTo(withCut, 1e-6));
    });

    test('гостей тёща не касается', () {
      // Именно к ним и стоит присмотреться, пока она гостит.
      var s = rich(t);
      s = s.copyWith(sort: const SortState(index: 4));
      for (final e in kGarageEvents) {
        final buyer = e.asBuyer;
        final value = engine.saleValueFor(s, buyer, t);
        final petrovich = engine.saleValueFor(s, kBuyers.first, t);
        expect(value / petrovich, closeTo(e.multiplier / factor, 1e-9),
            reason: '${e.id}: гость должен платить свой множитель, без поправки');
      }
    });

    test('покупки не трогает', () {
      expect(supplyFactorAt(t), 1.0);
    });
  });

  group('Кто не играет, тот не теряет', () {
    test('оффлайн за время неприятности начисляется как обычно', () {
      // Производство расход не трогает вовсе. Проверяем на полном окне:
      // сколько накапало бы за двенадцать минут отсутствия в разгар любой
      // неприятности — ровно столько же, сколько в тихую минуту.
      for (final t in [supplyMoment, neighborMoment]) {
        var s = newGame(content: kGenerators, upgrades: kUpgrades, now: t);
        s = engine.buyGenerator(
          s.copyWith(resources: s.resources.copyWith(money: 1e6)),
          'banka',
          t,
        );
        final during = engine.creditOffline(s, const Duration(minutes: 5), t);

        final q = s.copyWith(lastUpdateTime: quietMoment);
        final quiet =
            engine.creditOffline(q, const Duration(minutes: 5), quietMoment);

        expect(during.gained, closeTo(quiet.gained, 1e-9));
      }
    });
  });
}
