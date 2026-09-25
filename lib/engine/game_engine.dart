import '../content/achievements.dart';
import '../content/balance.dart';
import '../content/buyers.dart';
import '../content/expenses.dart';
import '../content/game_content.dart';
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

  /// Отметить касание — только для счётчика и достижений.
  ///
  /// Самогона касание НЕ даёт, и это главное решение всей переделки. Пока
  /// давало, выигрывал тот, кто быстрее долбит по экрану: спам приносил
  /// больше любой осмысленной игры, а «подождать хороший сорт» становилось
  /// проигрышной стратегией. Навыка в этом не было — только выносливость.
  ///
  /// Теперь касание влияет на производство единственным путём — через жар
  /// (см. [processTick] и его множитель). Жар держат зажимом, поэтому долбить
  /// по экрану бессмысленно физически.
  GameState registerTouch(GameState state, DateTime currentTime) {
    return state.copyWith(
      clicker: state.clicker.copyWith(totalTaps: state.clicker.totalTaps + 1),
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

  /// Засчитать [seconds] секунд игры на экране.
  ///
  /// Сколько прошло и держали ли зажим, знает только интерфейс: время
  /// приходит тиком игры, зажим — от пальца. Движок только складывает, как и
  /// с сортом, поэтому остаётся чистым и проверяется без экрана.
  ///
  /// Оффлайн сюда не попадает: [creditOffline] эту функцию не зовёт, и
  /// время с закрытой игрой в «время в игре» не складывается.
  GameState recordPlay(
    GameState state,
    double seconds, {
    required bool holding,
    required bool inWindow,
  }) {
    if (seconds <= 0) return state;
    return state.copyWith(
      stats: state.stats.addPlay(seconds, holding: holding, inWindow: inWindow),
    );
  }

  /// Двинуть сорт: жар в окне поднимает, перегрев жжёт, мимо — медленно сползает.
  ///
  /// Интерфейс присылает уже посчитанную дельту, движок про шкалу не знает и
  /// остаётся чистым.
  GameState advanceSort(GameState state, double delta) {
    if (delta == 0) return state;
    final next = state.sort.advance(delta);
    return next == state.sort ? state : state.copyWith(sort: next);
  }

  /// Возьмёт ли этот покупатель товар прямо сейчас.
  bool canSellTo(GameState state, Buyer buyer) =>
      state.resources.ml > 0 &&
      state.resources.ml >= buyer.minMl &&
      state.sort.index >= buyer.minSortIndex;

  /// Сколько заплатит покупатель за то, что в баке.
  ///
  /// Цена складывается из рыночной за миллилитр, надбавки за **сорт** (чем
  /// лучше нагнали, тем дороже) и коэффициента покупателя.
  ///
  /// Постоянному покупателю цену может сбить расход (тёща гостит, см.
  /// `expenses.dart`). Гостей это не касается: их множитель — их условие.
  double saleValueFor(GameState state, Buyer buyer, DateTime currentTime) {
    final volume = buyer.volumeFrom(state.resources.ml);
    final neighbor =
        buyer.id == kBuyers.first.id ? neighborFactorAt(currentTime) : 1.0;
    return volume *
        Market.pricePerMl(currentTime, state.upgrades) *
        state.sort.multiplier *
        buyer.multiplier *
        neighbor;
  }

  /// Сдать товар покупателю.
  ///
  /// Хорошие покупатели забирают вместе с товаром и сорт — его придётся
  /// нарабатывать заново. Именно это делает «подождать и довести до кедрача»
  /// ставкой, а не очевидностью.
  GameState sellTo(GameState state, Buyer buyer, DateTime currentTime) {
    if (!canSellTo(state, buyer)) return state;

    final volume = buyer.volumeFrom(state.resources.ml);
    final revenue = saleValueFor(state, buyer, currentTime);
    // Гость — любой, кого нет среди постоянных покупателей: события
    // превращаются в покупателя на лету (GarageEvent.asBuyer), и отдельного
    // признака у них нет намеренно — движок про события не знает.
    final guest = !kBuyers.any((b) => b.id == buyer.id);

    return state.copyWith(
      resources: state.resources.copyWith(
        ml: state.resources.ml - volume,
        money: state.resources.money + revenue,
      ),
      sort: buyer.consumesSort ? state.sort.dropOneStep() : state.sort,
      stats: state.stats.addSale(volume, revenue, guest: guest),
      lastUpdateTime: currentTime,
    );
  }

  /// Сдать бак соседу — он берёт всегда. Этим пользуется автопродажа.
  GameState sell(GameState state, DateTime currentTime) =>
      sellTo(state, kBuyers.first, currentTime);

  /// Сколько дадут за бак у соседа прямо сейчас.
  double saleValue(GameState state, DateTime currentTime) =>
      saleValueFor(state, kBuyers.first, currentTime);

  /// Скорость удорожания — одна на всю игру, из баланса.
  double get _growth => Balance.current.costGrowth;

  /// Базовая цена аппарата с поправкой на расход в момент [at].
  ///
  /// Весь ряд цен линеен по базовой, поэтому подорожание сахара достаточно
  /// приложить к ней одной — и цена штуки, и цена пачки, и «сколько влезет»
  /// сойдутся сами.
  ///
  /// Время во всех ценах обязательное, а не необязательное с «обычной ценой»
  /// по умолчанию. Иначе первое же место, которое про него забудет, покажет
  /// игроку одну цену, а спишет другую.
  double _base(Generator g, DateTime at) => g.baseCost * supplyFactorAt(at);

  /// Стоимость следующей штуки аппарата в момент [at], в рублях.
  double generatorCost(Generator g, DateTime at) =>
      formulas.calculateUpgradeCost(_base(g, at), _growth, g.ownedCount);

  /// Стоимость улучшения в момент [at]. Цена в самом [Upgrade] — обычная,
  /// без поправки на расход; показывать и списывать надо эту.
  double upgradeCost(Upgrade u, DateTime at) => u.cost * supplyFactorAt(at);

  /// Покупка одного аппарата — за деньги, а не за товар.
  GameState buyGenerator(GameState state, String generatorId, DateTime currentTime) {
    final index = state.generators.items.indexWhere((g) => g.id == generatorId);
    if (index == -1) return state;

    final generator = state.generators.items[index];
    final cost = generatorCost(generator, currentTime);
    if (state.resources.money < cost) return state;

    final items = List<Generator>.from(state.generators.items);
    items[index] = generator.copyWith(ownedCount: generator.ownedCount + 1);

    return state.copyWith(
      resources: state.resources.copyWith(money: state.resources.money - cost),
      generators: state.generators.copyWith(items: items),
      stats: state.stats.copyWith(stillsBought: state.stats.stillsBought + 1),
      lastUpdateTime: currentTime,
    );
  }

  /// Сколько штук игрок может позволить прямо сейчас.
  int affordableCount(GameState state, Generator g, DateTime at) =>
      formulas.maxAffordable(
        _base(g, at),
        _growth,
        g.ownedCount,
        state.resources.money,
      );

  /// Цена пачки в [count] штук в момент [at].
  double bulkCost(Generator g, int count, DateTime at) =>
      formulas.bulkCost(_base(g, at), _growth, g.ownedCount, count);

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
    final affordable = affordableCount(state, generator, currentTime);
    final take = count < affordable ? count : affordable;
    if (take <= 0) return state;

    final cost = bulkCost(generator, take, currentTime);

    final items = List<Generator>.from(state.generators.items);
    items[index] = generator.copyWith(ownedCount: generator.ownedCount + take);

    return state.copyWith(
      resources: state.resources.copyWith(money: state.resources.money - cost),
      generators: state.generators.copyWith(items: items),
      stats: state.stats.copyWith(stillsBought: state.stats.stillsBought + take),
      lastUpdateTime: currentTime,
    );
  }

  /// Покупка улучшения (одноразового).
  GameState buyUpgrade(GameState state, String upgradeId, DateTime currentTime) {
    final index = state.upgrades.items.indexWhere((u) => u.id == upgradeId);
    if (index == -1) return state;

    final upgrade = state.upgrades.items[index];
    if (upgrade.purchased) return state;
    final cost = upgradeCost(upgrade, currentTime);
    if (state.resources.money < cost) return state;

    final items = List<Upgrade>.from(state.upgrades.items);
    items[index] = upgrade.copyWith(purchased: true);

    return state.copyWith(
      resources: state.resources.copyWith(money: state.resources.money - cost),
      upgrades: state.upgrades.copyWith(items: items),
      stats: state.stats.copyWith(upgradesBought: state.stats.upgradesBought + 1),
      lastUpdateTime: currentTime,
    );
  }

  /// ПОПАЛСЯ: участковый застал Витю за работой.
  ///
  /// Забирает часть бака и роняет сорт на ступень. Именно часть, а не всё:
  /// потеря должна быть обидной, но восполнимой за несколько минут — иначе
  /// механика перестаёт быть напряжением и становится поводом закрыть игру.
  ///
  /// Историю ([totalEverEarned]) конфискация НЕ трогает. Нагнанное было
  /// нагнано, и мудрость за него уже заслужена; отбирать её задним числом
  /// значило бы наказывать дважды.
  GameState seizeByPolice(GameState state, DateTime currentTime) {
    if (state.resources.ml <= 0 && state.sort.index == 0) return state;

    return state.copyWith(
      resources: state.resources.copyWith(
        ml: state.resources.ml * (1 - Balance.current.raidSeizure),
      ),
      sort: state.sort.dropOneStep(),
      lastUpdateTime: currentTime,
    );
  }

  /// ПОХМЕЛЬЕ: заход начинается заново в обмен на перманентную мудрость.
  ///
  /// Начинается именно ЗАНОВО, а не с нуля: в гараже остаётся та же банка, с
  /// которой Витя начинал. Разница не косметическая — при пустом гараже игра
  /// после похмелья не запускалась вовсе. Стартовый набор берётся из
  /// [startingGenerators], а не из переданного списка, чтобы этот путь не мог
  /// разойтись с новой игрой.
  GameState prestige(
    GameState state,
    List<Generator> initialGenerators,
    List<Upgrade> initialUpgrades,
    DateTime currentTime,
  ) {
    if (!state.prestige.canPrestige) return state;

    return GameState.initial(
      initialGenerators: startingGenerators(initialGenerators),
      initialUpgrades: initialUpgrades,
      prestige: state.prestige.claimAll(),
      // Достижения — мета-слой: они переживают похмелье вместе с мудростью,
      // иначе открытые ими функции отбирались бы обратно.
      achievements: state.achievements,
      // Статистика — за всю игру, а не за заход; похмелье только закрывает
      // заход и засекает следующий.
      stats: state.stats.finishRun(currentTime),
      lastUpdateTime: currentTime,
    );
  }
}
