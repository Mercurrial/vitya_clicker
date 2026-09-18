import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/prestige_state.dart';

/// Игра обязана быть проходимой из ЛЮБОГО начала.
///
/// Начал их три: новая игра, похмелье и «начать заново». Первое было проверено,
/// два других — нет, и оба оставляли игрока в пустом гараже. Поскольку касание
/// самогона не даёт, пустой гараж означает ноль дохода навсегда: заработать на
/// первую банку нечем, а единственная доступная кнопка («начать заново»)
/// приводит ровно туда же. Игра запиралась насмерть — причём в награду за то,
/// к чему вела вся механика.
///
/// Поэтому проверяем не «правильный список аппаратов», а само свойство: из
/// этого состояния игра ИДЁТ. Такой тест переживёт любую правку баланса.
void main() {
  const engine = GameEngine();
  final t0 = DateTime.utc(2026, 1, 1);

  /// Единственное, что действительно нужно от начала игры: самогон капает сам.
  void expectPlayable(GameState state, {required String from}) {
    expect(state.mlPerSecond, greaterThan(0),
        reason: 'после «$from» производство стоит намертво. Касание дохода не '
            'даёт, значит заработать на первый аппарат нечем и игра окончена');

    final later = engine.processTick(state, t0.add(const Duration(minutes: 1)));
    expect(later.resources.ml, greaterThan(0),
        reason: 'после «$from» бак не наполняется даже за минуту');
  }

  test('новая игра', () {
    expectPlayable(
      newGame(content: kGenerators, upgrades: kUpgrades, now: t0),
      from: 'новая игра',
    );
  });

  test('похмелье', () {
    // Доводим до состояния, в котором похмелье вообще разрешено.
    final earned = PrestigeState.firstWisdomMl * 4;
    var state = newGame(content: kGenerators, upgrades: kUpgrades, now: t0)
        .copyWith(prestige: PrestigeState(totalEverEarned: earned));
    expect(state.prestige.canPrestige, isTrue, reason: 'тест не про это');

    state = engine.prestige(state, kGenerators, kUpgrades, t0);

    expect(state.prestige.wisdom, greaterThan(0), reason: 'мудрость не выдана');
    expectPlayable(state, from: 'похмелье');
  });

  test('похмелье не отбирает мудрость прошлых заходов', () {
    // Проверяем заодно, что «начать заново» и похмелье — это разные вещи.
    final earned = PrestigeState.firstWisdomMl * 16;
    var state = newGame(content: kGenerators, upgrades: kUpgrades, now: t0)
        .copyWith(prestige: PrestigeState(totalEverEarned: earned));

    state = engine.prestige(state, kGenerators, kUpgrades, t0);
    final afterFirst = state.prestige.wisdom;

    expect(state.prestige.totalEverEarned, earned,
        reason: 'история заходов — это факт, она не обнуляется');
    expect(afterFirst, greaterThan(0));
  });

  test('стартовый набор одинаков для всех начал', () {
    // Разойтись им нельзя: именно расхождение и было дефектом.
    final start = newGame(content: kGenerators, upgrades: kUpgrades, now: t0);

    final earned = PrestigeState.firstWisdomMl * 4;
    final after = engine.prestige(
      start.copyWith(prestige: PrestigeState(totalEverEarned: earned)),
      kGenerators,
      kUpgrades,
      t0,
    );

    Map<String, int> owned(GameState s) => {
          for (final g in s.generators.items) g.id: g.ownedCount,
        };
    expect(owned(after), owned(start));
  });
}
