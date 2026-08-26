import '../models/game_state.dart';
import '../models/generator.dart';
import '../models/upgrade.dart';
import 'formulas.dart';

/// Чистые переходы состояния. Никакого UI и никаких side-эффектов: движок
/// можно прогонять в тестах и в симуляторе баланса.
class GameEngine {
  final Formulas formulas;

  const GameEngine({this.formulas = const Formulas()});

  /// Нажатие по Вите — подкинуть дров под аппарат.
  ///
  /// Главная ценность тапа не здесь, а в жаре: он множит ВСЁ производство
  /// (см. [processTick]). Прямая отдача нужна лишь для того, чтобы нажатие
  /// ощущалось, и она намеренно считается как «доля секунды производства» —
  /// поэтому не отмирает с ростом империи, как отмирала бы константа.
  GameState processTap(
    GameState state,
    DateTime currentTime, {
    double heatMultiplier = 1.0,
  }) {
    final gain = state.tapYield * heatMultiplier;

    return state.copyWith(
      resources: state.resources.copyWith(ml: state.resources.ml + gain),
      clicker: state.clicker.copyWith(totalTaps: state.clicker.totalTaps + 1),
      prestige: state.prestige.copyWith(
        totalEverEarned: state.prestige.totalEverEarned + gain,
      ),
      lastUpdateTime: currentTime,
    );
  }

  /// Пассивная генерация за прошедшее время.
  ///
  /// [heatMultiplier] — вот ради чего игрок вообще тапает: жар под аппаратом
  /// множит весь поток, а не добавляет фиксированную каплю. Поэтому ценность
  /// нажатий растёт вместе с производством и никогда не обнуляется.
  ///
  /// Пока игра закрыта, множитель равен 1: отсутствие не наказывается, просто
  /// активная игра идёт быстрее.
  ///
  /// Та же функция обслуживает оффлайн-доход — разница только в величине
  /// [currentTime] минус метка состояния.
  GameState processTick(
    GameState state,
    DateTime currentTime, {
    double heatMultiplier = 1.0,
  }) {
    final rate = state.mlPerSecond * heatMultiplier;
    if (rate <= 0) return state.copyWith(lastUpdateTime: currentTime);

    final deltaSeconds =
        currentTime.difference(state.lastUpdateTime).inMilliseconds / 1000.0;
    if (deltaSeconds <= 0) return state.copyWith(lastUpdateTime: currentTime);

    final produced = formulas.calculatePassiveGeneration(rate, deltaSeconds);

    return state.copyWith(
      resources: state.resources.copyWith(ml: state.resources.ml + produced),
      prestige: state.prestige.copyWith(
        totalEverEarned: state.prestige.totalEverEarned + produced,
      ),
      lastUpdateTime: currentTime,
    );
  }

  /// Стоимость следующей штуки аппарата.
  double generatorCost(Generator g) => formulas.calculateUpgradeCost(
        g.baseCost,
        g.costGrowthFactor,
        g.ownedCount,
      );

  /// Покупка одного аппарата.
  GameState buyGenerator(GameState state, String generatorId, DateTime currentTime) {
    final index = state.generators.items.indexWhere((g) => g.id == generatorId);
    if (index == -1) return state;

    final generator = state.generators.items[index];
    final cost = generatorCost(generator);
    if (state.resources.ml < cost) return state;

    final items = List<Generator>.from(state.generators.items);
    items[index] = generator.copyWith(ownedCount: generator.ownedCount + 1);

    return state.copyWith(
      resources: state.resources.copyWith(ml: state.resources.ml - cost),
      generators: state.generators.copyWith(items: items),
      lastUpdateTime: currentTime,
    );
  }

  /// Покупка апгрейда (одноразового).
  GameState buyUpgrade(GameState state, String upgradeId, DateTime currentTime) {
    final index = state.upgrades.items.indexWhere((u) => u.id == upgradeId);
    if (index == -1) return state;

    final upgrade = state.upgrades.items[index];
    if (upgrade.purchased) return state;
    if (state.resources.ml < upgrade.cost) return state;

    final items = List<Upgrade>.from(state.upgrades.items);
    items[index] = upgrade.copyWith(purchased: true);

    return state.copyWith(
      resources: state.resources.copyWith(ml: state.resources.ml - upgrade.cost),
      upgrades: state.upgrades.copyWith(items: items),
      lastUpdateTime: currentTime,
    );
  }

  /// ПОХМЕЛЬЕ: сброс гаража в обмен на перманентную мудрость.
  GameState prestige(
    GameState state,
    List<Generator> initialGenerators,
    List<Upgrade> initialUpgrades,
    DateTime currentTime,
  ) {
    if (!state.prestige.canPrestige) return state;

    return GameState.initial(
      initialGenerators: initialGenerators,
      initialUpgrades: initialUpgrades,
      prestige: state.prestige.copyWith(
        wisdom: state.prestige.potentialWisdom,
        hangovers: state.prestige.hangovers + 1,
      ),
      lastUpdateTime: currentTime,
    );
  }
}
