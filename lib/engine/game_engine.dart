import '../models/game_state.dart';
import '../models/generator.dart';
import '../models/upgrade.dart';
import 'formulas.dart';

class GameEngine {
  final Formulas formulas;

  const GameEngine({this.formulas = const Formulas()});

  /// Игровой тик: пассивная генерация за прошедшее время.
  GameState processTick(GameState state, DateTime currentTime) {
    final double goldPerSecond = state.goldPerSecond;

    if (goldPerSecond <= 0) {
      return state.copyWith(lastUpdateTime: currentTime);
    }

    final double deltaTimeSeconds =
        currentTime.difference(state.lastUpdateTime).inMilliseconds / 1000.0;

    if (deltaTimeSeconds <= 0) {
      return state.copyWith(lastUpdateTime: currentTime);
    }

    final double generated =
        formulas.calculatePassiveGeneration(goldPerSecond, deltaTimeSeconds);

    return state.copyWith(
      resources: state.resources.copyWith(gold: state.resources.gold + generated),
      prestige: state.prestige.copyWith(
        totalEverEarned: state.prestige.totalEverEarned + generated,
      ),
      lastUpdateTime: currentTime,
    );
  }

  /// Покупка генератора.
  GameState buyGenerator(GameState state, String generatorId, DateTime currentTime) {
    final index = state.generators.items.indexWhere((g) => g.id == generatorId);
    if (index == -1) return state;

    final generator = state.generators.items[index];
    final cost = formulas.calculateUpgradeCost(
        generator.baseCost, generator.costGrowthFactor, generator.ownedCount);

    if (state.resources.gold < cost) return state;

    final newGenerator = generator.copyWith(ownedCount: generator.ownedCount + 1);
    final newItems = List<Generator>.from(state.generators.items);
    newItems[index] = newGenerator;

    return state.copyWith(
      resources: state.resources.copyWith(gold: state.resources.gold - cost),
      generators: state.generators.copyWith(items: newItems),
      lastUpdateTime: currentTime,
    );
  }

  /// Покупка апгрейда.
  GameState buyUpgrade(GameState state, String upgradeId, DateTime currentTime) {
    final index = state.upgrades.items.indexWhere((u) => u.id == upgradeId);
    if (index == -1) return state;

    final upgrade = state.upgrades.items[index];
    if (upgrade.purchased) return state;
    if (state.resources.gold < upgrade.cost) return state;

    final newUpgrade = upgrade.copyWith(purchased: true);
    final newItems = List<Upgrade>.from(state.upgrades.items);
    newItems[index] = newUpgrade;

    return state.copyWith(
      resources: state.resources.copyWith(gold: state.resources.gold - upgrade.cost),
      upgrades: state.upgrades.copyWith(items: newItems),
      lastUpdateTime: currentTime,
    );
  }

  /// Престиж: сброс генераторов/апгрейдов/энергии в обмен на перманентные шарды.
  /// totalEverEarned сохраняется (валюта считается от него); shards растут.
  GameState prestige(
    GameState state,
    List<Generator> initialGenerators,
    List<Upgrade> initialUpgrades,
    DateTime currentTime,
  ) {
    final potential = state.prestige.potentialShards;
    if (potential <= state.prestige.shards) return state; // нечего получать

    return GameState.initial(
      initialGenerators: initialGenerators,
      initialUpgrades: initialUpgrades,
      prestige: state.prestige.copyWith(shards: potential),
      lastUpdateTime: currentTime,
    );
  }
}
