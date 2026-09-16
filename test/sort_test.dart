import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/buyers.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/content/sorts.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/sort_state.dart';

/// СОРТ и покупатели — ответ на настоящую дыру: ждать пика цены не имело
/// смысла, потому что ожидание ничего не давало. Теперь ожидание поднимает
/// сорт, а сорт открывает покупателей, которые платят кратно больше.
void main() {
  const engine = GameEngine();
  final t0 = DateTime.utc(2026, 1, 1);

  GameState fresh() => GameState.initial(
        initialGenerators: kGenerators,
        initialUpgrades: kUpgrades,
        lastUpdateTime: t0,
      );

  GameState withTank(double ml, {int sortIndex = 0}) {
    final s = fresh();
    return s.copyWith(
      resources: s.resources.copyWith(ml: ml),
      sort: SortState(index: sortIndex),
    );
  }

  group('Лестница сортов', () {
    test('новая игра начинается с первача', () {
      expect(fresh().sort.index, 0);
      expect(fresh().sort.name, 'Первач');
      expect(fresh().sort.multiplier, 1.0);
    });

    test('каждая следующая ступень дороже предыдущей', () {
      for (var i = 1; i < kSorts.length; i++) {
        expect(kSorts[i].multiplier, greaterThan(kSorts[i - 1].multiplier));
      }
    });

    test('накопленный прогресс переносится на следующую ступень', () {
      const s = SortState(index: 0, progress: 0.8);
      final next = s.advance(0.3);
      expect(next.index, 1);
      expect(next.progress, closeTo(0.1, 1e-9));
    });

    test('падение ниже нуля опускает на ступень', () {
      const s = SortState(index: 2, progress: 0.1);
      final next = s.advance(-0.3);
      expect(next.index, 1);
      expect(next.progress, closeTo(0.8, 1e-9));
    });

    test('выше верхней ступени и ниже первой не уходит', () {
      const top = SortState(index: 4, progress: 0.9);
      expect(top.advance(5.0).index, kSorts.length - 1);
      expect(top.advance(5.0).progress, 1.0);

      const bottom = SortState(index: 0, progress: 0.1);
      expect(bottom.advance(-5.0).index, 0);
      expect(bottom.advance(-5.0).progress, 0.0);
    });

    test('перегрев жжёт быстрее, чем окно растит', () {
      expect(kSortBurnPerSecond, greaterThan(kSortGainPerSecond));
    });
  });

  group('Сорт и выручка', () {
    test('лучший сорт даёт кратно больше за тот же объём', () {
      final plain = withTank(5000);
      final good = withTank(5000, sortIndex: 4);

      final a = engine.saleValueFor(plain, kBuyers.first, t0);
      final b = engine.saleValueFor(good, kBuyers.first, t0);

      expect(b / a, closeTo(kSorts[4].multiplier, 1e-9));
    });
  });

  group('Покупатели', () {
    Buyer byId(String id) => kBuyers.firstWhere((b) => b.id == id);

    test('сосед берёт всегда, даже первач', () {
      expect(engine.canSellTo(withTank(100), byId('petrovich')), isTrue);
    });

    test('оптовик требует сорт и объём', () {
      final optovik = byId('optovik');
      expect(engine.canSellTo(withTank(5000, sortIndex: 1), optovik), isFalse,
          reason: 'сорт низкий');
      expect(engine.canSellTo(withTank(100, sortIndex: 3), optovik), isFalse,
          reason: 'объёма мало');
      expect(engine.canSellTo(withTank(5000, sortIndex: 2), optovik), isTrue);
    });

    test('свадьба берёт только лучшее и только немного', () {
      final svadba = byId('svadba');
      expect(engine.canSellTo(withTank(9000, sortIndex: 2), svadba), isFalse);

      final s = withTank(9000, sortIndex: 4);
      expect(engine.canSellTo(s, svadba), isTrue);

      final after = engine.sellTo(s, svadba, t0);
      expect(after.resources.ml, 9000 - 2000, reason: 'забирает не больше 2 л·10³');
    });

    test('сосед не трогает сорт, а хорошие покупатели его расходуют', () {
      final s = withTank(5000, sortIndex: 3);

      final toNeighbour = engine.sellTo(s, byId('petrovich'), t0);
      expect(toNeighbour.sort.index, 3, reason: 'сосед в сортах не разбирается');

      final toWholesale = engine.sellTo(s, byId('optovik'), t0);
      expect(toWholesale.sort.index, 2, reason: 'репутация уходит с товаром');
    });

    test('выгоднее довести сорт, чем сдавать сразу соседу', () {
      // Именно эта разница делает ожидание осмысленным.
      final now = withTank(2000, sortIndex: 0);
      final later = withTank(2000, sortIndex: 3);

      final quick = engine.saleValueFor(now, byId('petrovich'), t0);
      final patient = engine.saleValueFor(later, byId('svadba'), t0);

      expect(patient, greaterThan(quick * 5));
    });

    test('недоступному покупателю продать нельзя', () {
      final s = withTank(5000, sortIndex: 0);
      expect(engine.sellTo(s, byId('svadba'), t0), same(s));
    });

    test('продажа переводит объём в деньги', () {
      final s = withTank(5000, sortIndex: 2);
      final expected = engine.saleValueFor(s, kBuyers.first, t0);
      final after = engine.sellTo(s, kBuyers.first, t0);

      expect(after.resources.ml, 0);
      expect(after.resources.money, closeTo(expected, 1e-6));
    });
  });
}
