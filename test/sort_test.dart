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

  group('Покупатель', () {
    test('берёт весь бак и не трогает сорт', () {
      // Покупателей было трое, и это выглядело выбором. На деле сосед брал
      // всё и всегда, оптовик отличался на четверть цены, а свадьба забирала
      // два литра — смешные деньги через десять минут игры. Три кнопки
      // означали три раза прочитать одно и то же.
      expect(kBuyers.length, 1, reason: 'покупатель должен остаться один');

      final buyer = kBuyers.single;
      var s = fresh().copyWith(sort: const SortState(index: 3));
      s = s.copyWith(resources: s.resources.copyWith(ml: 5000));

      expect(engine.canSellTo(s, buyer), isTrue);
      final after = engine.sellTo(s, buyer, t0);

      expect(after.resources.ml, 0, reason: 'забирает весь бак');
      expect(after.resources.money, greaterThan(0));
      expect(after.sort.index, 3,
          reason: 'сорт тратится ожиданием, а не продажей');
    });

    test('пустой бак продать нельзя', () {
      expect(engine.canSellTo(fresh(), kBuyers.single), isFalse);
    });
  });
}
