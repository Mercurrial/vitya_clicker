import '../content/achievements.dart';
import '../models/achievement.dart';
import '../models/game_state.dart';
import '../models/generator.dart';
import '../models/upgrade.dart';
import 'formulas.dart';
import 'market.dart';

/// Чистые переходы состояния. Никакого UI и никаких side-эффектов: движок
/// можно прогонять в тестах и в симуляторе баланса.
class GameEngine {
  final Formulas formulas;

  const GameEngine({this.formulas = const Formulas()});

  /// Сколько влезет в бак сверх того, что уже налито.
  double _room(GameState state) {
    final room = state.tankCapacity - state.resources.ml;
    return room > 0 ? room : 0.0;
  }

  /// Нажатие по Вите — подкинуть дров под аппарат.
  ///
  /// Главная ценность тапа не здесь, а в жаре: он множит ВСЁ производство
  /// (см. [processTick]). Прямая отдача нужна лишь для того, чтобы нажатие
  /// ощущалось, и она считается как доля секунды производства — поэтому не
  /// отмирает с ростом империи, как отмирала бы константа.
  GameState processTap(
    GameState state,
    DateTime currentTime, {
    double heatMultiplier = 1.0,
  }) {
    // В полный бак не налить — это и есть сигнал «пора продавать».
    final gain = _clampToRoom(state, state.tapYield * heatMultiplier);
    if (gain <= 0) {
      return state.copyWith(
        clicker: state.clicker.copyWith(totalTaps: state.clicker.totalTaps + 1),
        lastUpdateTime: currentTime,
      );
    }

    return state.copyWith(
      resources: state.resources.copyWith(ml: state.resources.ml + gain),
      clicker: state.clicker.copyWith(totalTaps: state.clicker.totalTaps + 1),
      prestige: state.prestige.copyWith(
        totalEverEarned: state.prestige.totalEverEarned + gain,
      ),
      lastUpdateTime: currentTime,
    );
  }

  double _clampToRoom(GameState state, double amount) {
    final room = _room(state);
    return amount > room ? room : amount;
  }

  /// Пассивная генерация за прошедшее время.
  ///
  /// [heatMultiplier] — вот ради чего игрок тапает: жар множит весь поток.
  /// Пока игра закрыта, множитель равен 1: отсутствие не наказывается, просто
  /// активная игра идёт быстрее.
  ///
  /// Та же функция обслуживает оффлайн-доход — разница только в величине
  /// [currentTime] минус метка состояния. Излишек сверх ёмкости бака теряется:
  /// вернувшись, игрок находит полный бак, а не бесконечную выручку.
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

    final produced = _clampToRoom(
      state,
      formulas.calculatePassiveGeneration(rate, deltaSeconds),
    );
    if (produced <= 0) return state.copyWith(lastUpdateTime: currentTime);

    return state.copyWith(
      resources: state.resources.copyWith(ml: state.resources.ml + produced),
      prestige: state.prestige.copyWith(
        totalEverEarned: state.prestige.totalEverEarned + produced,
      ),
      lastUpdateTime: currentTime,
    );
  }

  /// Пересчитать достижения и вернуть те, что открылись только что.
  ///
  /// Условия — чистые функции состояния, поэтому проверка не зависит от того,
  /// поймали мы момент или нет: вернувшись после отсутствия, игрок получит всё,
  /// что заслужил, разом.
  ({GameState state, List<Achievement> fresh}) checkAchievements(GameState state) {
    final fresh = <Achievement>[];
    for (final a in kAllAchievements) {
      if (state.achievements.has(a.id)) continue;
      if (a.check(state)) fresh.add(a);
    }
    if (fresh.isEmpty) return (state: state, fresh: const []);

    return (
      state: state.copyWith(
        achievements: state.achievements.withUnlocked(fresh.map((a) => a.id)),
      ),
      fresh: fresh,
    );
  }

  /// Начислить за время отсутствия и сказать, сколько накапало.
  ///
  /// Единственная точка, где считается оффлайн: и запуск игры, и возврат из
  /// фона зовут именно её. Раньше запуск считал по своей копии формулы,
  /// которая не знала про ёмкость бака, — и после перезагрузки в двухлитровый
  /// бак наливались десятки тысяч литров.
  ({GameState state, double gained}) creditOffline(
    GameState state,
    Duration credited,
    DateTime now,
  ) {
    if (credited <= Duration.zero) return (state: state, gained: 0.0);

    final before = state.resources.ml;
    var next = state.copyWith(lastUpdateTime: now.subtract(credited));
    next = processTick(next, now);
    return (state: next, gained: next.resources.ml - before);
  }

  /// Сдать весь бак по текущей цене.
  ///
  /// Цена зависит от момента, поэтому продажа — это решение, а не рутина:
  /// на пике рынка тот же бак стоит заметно дороже.
  GameState sell(GameState state, DateTime currentTime) {
    final ml = state.resources.ml;
    if (ml <= 0) return state;

    final revenue = ml * Market.pricePerMl(currentTime, state.upgrades);

    return state.copyWith(
      resources: state.resources.copyWith(
        ml: 0,
        money: state.resources.money + revenue,
      ),
      lastUpdateTime: currentTime,
    );
  }

  /// Сколько дадут за бак прямо сейчас.
  double saleValue(GameState state, DateTime currentTime) =>
      state.resources.ml * Market.pricePerMl(currentTime, state.upgrades);

  /// Стоимость следующей штуки аппарата, в рублях.
  double generatorCost(Generator g) => formulas.calculateUpgradeCost(
        g.baseCost,
        g.costGrowthFactor,
        g.ownedCount,
      );

  /// Покупка одного аппарата — за деньги, а не за товар.
  GameState buyGenerator(GameState state, String generatorId, DateTime currentTime) {
    final index = state.generators.items.indexWhere((g) => g.id == generatorId);
    if (index == -1) return state;

    final generator = state.generators.items[index];
    final cost = generatorCost(generator);
    if (state.resources.money < cost) return state;

    final items = List<Generator>.from(state.generators.items);
    items[index] = generator.copyWith(ownedCount: generator.ownedCount + 1);

    return state.copyWith(
      resources: state.resources.copyWith(money: state.resources.money - cost),
      generators: state.generators.copyWith(items: items),
      lastUpdateTime: currentTime,
    );
  }

  /// Сколько штук игрок может позволить прямо сейчас.
  int affordableCount(GameState state, Generator g) => formulas.maxAffordable(
        g.baseCost,
        g.costGrowthFactor,
        g.ownedCount,
        state.resources.money,
      );

  /// Цена пачки в [count] штук.
  double bulkCost(Generator g, int count) =>
      formulas.bulkCost(g.baseCost, g.costGrowthFactor, g.ownedCount, count);

  /// Купить сразу несколько штук.
  ///
  /// Покупать сотню аппаратов по одному нажатию — не сложность, а мучение;
  /// в серьёзных инкрементальных играх пачки есть всегда. Если денег хватает
  /// не на всё [count], берём столько, сколько выходит.
  GameState buyGeneratorBulk(
    GameState state,
    String generatorId,
    int count,
    DateTime currentTime,
  ) {
    if (count <= 0) return state;

    final index = state.generators.items.indexWhere((g) => g.id == generatorId);
    if (index == -1) return state;

    final generator = state.generators.items[index];
    final affordable = affordableCount(state, generator);
    final take = count < affordable ? count : affordable;
    if (take <= 0) return state;

    final cost = bulkCost(generator, take);

    final items = List<Generator>.from(state.generators.items);
    items[index] = generator.copyWith(ownedCount: generator.ownedCount + take);

    return state.copyWith(
      resources: state.resources.copyWith(money: state.resources.money - cost),
      generators: state.generators.copyWith(items: items),
      lastUpdateTime: currentTime,
    );
  }

  /// Покупка улучшения (одноразового).
  GameState buyUpgrade(GameState state, String upgradeId, DateTime currentTime) {
    final index = state.upgrades.items.indexWhere((u) => u.id == upgradeId);
    if (index == -1) return state;

    final upgrade = state.upgrades.items[index];
    if (upgrade.purchased) return state;
    if (state.resources.money < upgrade.cost) return state;

    final items = List<Upgrade>.from(state.upgrades.items);
    items[index] = upgrade.copyWith(purchased: true);

    return state.copyWith(
      resources: state.resources.copyWith(money: state.resources.money - upgrade.cost),
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
      // Достижения — мета-слой: они переживают похмелье вместе с мудростью,
      // иначе открытые ими функции отбирались бы обратно.
      achievements: state.achievements,
      lastUpdateTime: currentTime,
    );
  }
}
