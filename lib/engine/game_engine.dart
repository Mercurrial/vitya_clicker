import '../content/achievements.dart';
import '../content/balance.dart';
import '../content/buyers.dart';
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
  ///
  /// [currentTime] касанию не нужен: метку времени оно не двигает — почему,
  /// см. [processTick].
  GameState registerTouch(GameState state, DateTime currentTime) {
    return state.copyWith(
      clicker: state.clicker.copyWith(totalTaps: state.clicker.totalTaps + 1),
    );
  }

  double _clampToRoom(GameState state, double amount) {
    final room = _room(state);
    return amount > room ? room : amount;
  }

  /// Пассивная генерация за прошедшее время.
  ///
  /// [heatMultiplier] — вот ради чего игрок тапает: жар множит весь поток.
  ///
  /// [speed] — ускорение потоком времени: ×2 проживает за секунду две
  /// секунды производства, лишняя списывается из потока. Кончился поток —
  /// ускорение кончилось вместе с ним, посреди тика тоже. Поэтому итог один
  /// на любой скорости: час потока — это час лишнего производства, на ×2 он
  /// проживается за час, на ×10 — за шесть минут.
  ///
  /// Время в игре и заходы ускорение не трогает: они считаются по настоящим
  /// часам, а не по производству.
  ///
  /// Излишек сверх ёмкости бака теряется. Если бак полон и не налилось ни
  /// капли, поток не списывается: сжечь его на стоящих аппаратах — не
  /// ускорение, а потеря.
  ///
  /// Метка [GameState.lastUpdateTime] — «до какого момента производство уже
  /// посчитано». Двигают её только тик и начисление AFK (`GameNotifier._tick`,
  /// загрузка сейва) — и похмелье, которое начинает заход заново. Касание,
  /// продажа и покупки её не трогают. Раньше трогали: каждое действие
  /// переставляло метку на «сейчас», и производство с прошлого тика
  /// пропадало. Тик идёт раз в 200 мс, касание приходит на каждое нажатие —
  /// при 30 нажатиях в минуту терялось около 5 % производства. Симулятор
  /// делает действия в тот же момент, что и тик, и потери не видел: игра
  /// шла медленнее целей баланса. А после сна приложения действие, пришедшее
  /// раньше первого тика, прятало от тика разрыв — и поток за отсутствие не
  /// начислялся вовсе.
  ///
  /// Цена этого — покупка задним числом. Купленный между тиками аппарат или
  /// улучшение считается следующим тиком с самого прошлого тика, то есть
  /// работает до 0,2 с «до покупки»; проданный бак так же задним числом
  /// освобождает место. Посчитать честно движок не может: для этого надо
  /// закрыть отрезок до покупки с тем жаром и ускорением, что были, а их
  /// знает только `GameNotifier`. Выигрыш — не больше тика того, что
  /// добавила покупка, и только при покупке или продаже; потеря была — тик
  /// всего производства на каждом нажатии.
  GameState processTick(
    GameState state,
    DateTime currentTime, {
    double heatMultiplier = 1.0,
    double speed = 1.0,
  }) {
    final rate = state.mlPerSecond * heatMultiplier;
    if (rate <= 0) return state.copyWith(lastUpdateTime: currentTime);

    final deltaSeconds =
        currentTime.difference(state.lastUpdateTime).inMilliseconds / 1000.0;
    if (deltaSeconds <= 0) return state.copyWith(lastUpdateTime: currentTime);

    final wanted = speed > 1 ? (speed - 1) * deltaSeconds : 0.0;
    final extra = wanted < state.flux.seconds ? wanted : state.flux.seconds;

    final produced = _clampToRoom(
      state,
      formulas.calculatePassiveGeneration(rate, deltaSeconds + extra),
    );
    if (produced <= 0) return state.copyWith(lastUpdateTime: currentTime);

    return state.copyWith(
      resources: state.resources.copyWith(ml: state.resources.ml + produced),
      prestige: state.prestige.copyWith(
        totalEverEarned: state.prestige.totalEverEarned + produced,
      ),
      flux: extra > 0
          ? state.flux.copyWith(seconds: state.flux.seconds - extra)
          : null,
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

  /// Начислить поток за AFK — время, когда игра не шла, — и сказать,
  /// сколько прибавилось.
  ///
  /// Производства за это время нет: закрытая игра не гонит. Раньше гнала —
  /// бак наливался за отсутствие, — и вместе с открытой вкладкой, которая
  /// гонит и так, отсутствие двигало игру мимо игрока. Теперь вместо
  /// самогона копится поток, и потратить его можно только играя.
  ///
  /// Единственная точка, где считается AFK: и запуск игры, и усыплённое
  /// системой приложение зовут именно её. Что игра «не шла», решают
  /// `bootstrap` и `GameNotifier`, а не движок.
  ///
  /// Полная копилка не переливается. Если в ней уже больше, чем влезает, —
  /// не отнимаем: копилку игрок не уменьшал.
  ({GameState state, double gained}) creditAfk(GameState state, Duration away) {
    if (away <= Duration.zero) return (state: state, gained: 0.0);

    final flux = state.flux;
    final room = flux.bankSeconds - flux.seconds;
    if (room <= 0) return (state: state, gained: 0.0);

    final earned = flux.earnedFor(away.inMilliseconds / 1000.0);
    final gained = earned < room ? earned : room;
    return (
      state: state.copyWith(flux: flux.copyWith(seconds: flux.seconds + gained)),
      gained: gained,
    );
  }

  /// Купить уровень «Крепкого сна»: +1 минута потока за час AFK. Платится
  /// самим потоком — выбор «ускориться сейчас или вложиться».
  GameState buyFluxRate(GameState state) {
    final flux = state.flux;
    if (!flux.canBuyRate) return state;
    return state.copyWith(
      flux: flux.copyWith(
        seconds: flux.seconds - flux.rateCostSeconds,
        rateLevel: flux.rateLevel + 1,
      ),
    );
  }

  /// Купить уровень «Долгого сна»: +1 час копилки.
  GameState buyFluxBank(GameState state) {
    final flux = state.flux;
    if (!flux.canBuyBank) return state;
    return state.copyWith(
      flux: flux.copyWith(
        seconds: flux.seconds - flux.bankCostSeconds,
        bankLevel: flux.bankLevel + 1,
      ),
    );
  }

  /// Засчитать [seconds] секунд игры на экране.
  ///
  /// Сколько прошло и держали ли зажим, знает только интерфейс: время
  /// приходит тиком игры, зажим — от пальца. Движок только складывает, как и
  /// с сортом, поэтому остаётся чистым и проверяется без экрана.
  ///
  /// AFK сюда не попадает: [creditAfk] эту функцию не зовёт, и время с
  /// закрытой игрой в «время в игре» не складывается. Ускорение — тоже:
  /// [seconds] — настоящие секунды, а не прожитые производством.
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
  /// Гостю — ещё и надбавка от вех мудрости. Здесь, а не в [sellTo]: цена,
  /// которую показывает кнопка гостя, обязана совпасть с тем, что он заплатит.
  double saleValueFor(GameState state, Buyer buyer, DateTime currentTime) {
    final volume = buyer.volumeFrom(state.resources.ml);
    return volume *
        Market.pricePerMl(currentTime, state.upgrades) *
        state.sort.multiplier *
        buyer.multiplier *
        (_isGuest(buyer) ? state.prestige.bonuses.guestPay : 1.0);
  }

  /// Гость — любой, кого нет среди постоянных покупателей: события
  /// превращаются в покупателя на лету (GarageEvent.asBuyer), и отдельного
  /// признака у них нет намеренно — движок про события не знает.
  static bool _isGuest(Buyer buyer) => !kBuyers.any((b) => b.id == buyer.id);

  /// Сдать товар покупателю.
  ///
  /// Хорошие покупатели забирают вместе с товаром и сорт — его придётся
  /// нарабатывать заново. Именно это делает «подождать и довести до кедрача»
  /// ставкой, а не очевидностью.
  GameState sellTo(GameState state, Buyer buyer, DateTime currentTime) {
    if (!canSellTo(state, buyer)) return state;

    final volume = buyer.volumeFrom(state.resources.ml);
    final revenue = saleValueFor(state, buyer, currentTime);
    final guest = _isGuest(buyer);

    return state.copyWith(
      resources: state.resources.copyWith(
        ml: state.resources.ml - volume,
        money: state.resources.money + revenue,
      ),
      sort: buyer.consumesSort ? state.sort.dropOneStep() : state.sort,
      stats: state.stats.addSale(volume, revenue, guest: guest),
      // Метку времени не трогаем — её двигает только тик, см. processTick.
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

  /// Базовая цена аппарата в момент [at].
  ///
  /// Весь ряд цен линеен по базовой, поэтому поправку на время достаточно
  /// приложить к ней одной — и цена штуки, и цена пачки, и «сколько влезет»
  /// сойдутся сами.
  ///
  /// Сейчас цена от времени не зависит: единственная такая поправка —
  /// подорожание сахара — вырезана вместе с житейскими неприятностями
  /// (docs/DECISIONS.md, «Состав релиза»). Время всё равно оставлено
  /// обязательным, а не необязательным с «обычной ценой» по умолчанию: когда
  /// поправка появится снова, первое же место, которое про него забудет,
  /// покажет игроку одну цену, а спишет другую.
  double _base(Generator g, DateTime at) => g.baseCost;

  /// Стоимость следующей штуки аппарата в момент [at], в рублях.
  double generatorCost(Generator g, DateTime at) =>
      formulas.calculateUpgradeCost(_base(g, at), _growth, g.ownedCount);

  /// Стоимость улучшения в момент [at]. Показывать и списывать надо эту, а
  /// не цену из самого [Upgrade] — по той же причине, что у [_base].
  double upgradeCost(Upgrade u, DateTime at) => u.cost;

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
      // Метку времени не трогаем — её двигает только тик, см. processTick.
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
      // Метку времени не трогаем — её двигает только тик, см. processTick.
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
      // Метку времени не трогаем — её двигает только тик, см. processTick.
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

    // Вехи — по мудрости ПОСЛЕ похмелья: веху, которую оно открыло, игрок
    // получает в этом же заходе, а не в следующем.
    final prestige = state.prestige.claimAll();
    final bonuses = prestige.bonuses;
    final kept = {
      for (final u in state.upgrades.items)
        if (u.purchased && bonuses.kept.contains(u.target)) u.id,
    };

    final next = GameState.initial(
      initialGenerators: startingGenerators(initialGenerators),
      initialUpgrades: [
        for (final u in initialUpgrades) kept.contains(u.id) ? u.copyWith(purchased: true) : u,
      ],
      prestige: prestige,
      // Достижения — мета-слой: они переживают похмелье вместе с мудростью,
      // иначе открытые ими функции отбирались бы обратно.
      achievements: state.achievements,
      // Статистика — за всю игру, а не за заход; похмелье только закрывает
      // заход и засекает следующий.
      stats: state.stats.finishRun(currentTime),
      // Поток — время игрока, а не имущество гаража: его улучшения куплены
      // за ожидание, и отнимать их похмельем значило бы наказать за сон.
      flux: state.flux,
      lastUpdateTime: currentTime,
    );
    return bonuses.startMoney > 0
        ? next.copyWith(resources: next.resources.copyWith(money: bonuses.startMoney))
        : next;
  }
}
