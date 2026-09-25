import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/balance.dart';
import 'package:idle_game/models/prestige_state.dart';

/// Вес мудрости: первая — ×2 ко всему, каждая следующая — ещё +50 %
/// (docs/DECISIONS.md, «Экономика и мудрость»).
///
/// При прежних +8 % за каждую второй заход был всего на 20 % короче первого:
/// похмелье не ощущалось наградой.
void main() {
  PrestigeState withWisdom(int steps) => PrestigeState(
        // wisdom = log2(1 + claimed / first): ровно steps ступеней.
        claimedMl: PrestigeState.firstWisdomMl * ((1 << steps) - 1),
      );

  test('без мудрости множителя нет', () {
    expect(withWisdom(0).wisdom, 0);
    expect(withWisdom(0).globalMultiplier, 1.0);
  });

  test('первая — ×2, дальше +50 % за каждую', () {
    expect(withWisdom(1).globalMultiplier, 2.0);
    expect(withWisdom(2).globalMultiplier, 2.5);
    expect(withWisdom(3).globalMultiplier, 3.0);
    expect(withWisdom(10).globalMultiplier, 6.5);
  });

  test('компенсация считается мудростью наравне с заработанной', () {
    const p = PrestigeState(bonusWisdom: 1);
    expect(p.globalMultiplier, 2.0);
  });

  test('вес берётся из баланса — правка доходит до всех', () {
    withBalance(kBalance.copyWith(firstWisdomBonus: 0.5, bonusPerWisdom: 0.1), () {
      expect(withWisdom(1).globalMultiplier, 1.5);
      expect(withWisdom(3).globalMultiplier, closeTo(1.7, 1e-12));
    });
    expect(withWisdom(1).globalMultiplier, 2.0);
  });
}
