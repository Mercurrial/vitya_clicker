/// Симулятор баланса: прогон партии без интерфейса.
///
/// ## Зачем это существует
///
/// Первый баланс я «смоделировал» алгебраически: посмотрел на формулу цены,
/// на формулу дохода, убедился, что каждая по отдельности выглядит разумно, и
/// решил, что дело сделано. Игра развалилась за полчаса живой игры.
///
/// Ошибка была не в формулах, а в методе. В инкрементальной игре ломается не
/// отдельная формула, а **их композиция во времени**: мудрость множит доход,
/// доход копит историю, из истории растёт мудрость. Такую петлю нельзя увидеть,
/// глядя на слагаемые по очереди — её видно только если прогнать систему.
///
/// ## Чем меряем
///
/// Главная величина — **окупаемость лучшей покупки** (payback): за сколько
/// секунд покупка вернёт свою цену. Она переводит разные вещи в одну шкалу:
/// аппарат даёт мл/с, улучшение качества даёт ₽/мл, а окупаемость и там, и там
/// считается в секундах.
///
/// В здоровой игре окупаемость колеблется около минуты и не уезжает: игрок
/// всё время видит покупку «ещё чуть-чуть накопить». Если она валится к нулю —
/// экономика идёт вразнос, покупки бесплатны. Если растёт — игра встала.
///
/// Симулятор держит движок и контент настоящими: он зовёт тот же [GameEngine],
/// что и игра. Иначе он проверял бы не игру, а свою копию игры.
library;

import 'dart:math' as math;

import '../content/buyers.dart';
import '../content/events.dart';
import '../content/game_content.dart';
import '../content/sorts.dart';
import '../core/formatters.dart';
import '../core/game_serializer.dart';
import '../engine/game_engine.dart';
import '../engine/market.dart';
import '../engine/production.dart';
import '../models/achievement.dart';
import '../models/game_state.dart';
import '../models/upgrade.dart';

/// Как играет модельный игрок.
enum BuyRule {
  /// Берёт то, что быстрее окупится. Так играет тот, кто считает.
  payback,

  /// Берёт самое дешёвое из доступного. Так играет тот, кто не считает, —
  /// и таких большинство.
  cheapest,

  /// Берёт только самый старший доступный аппарат. Частая ошибка новичка:
  /// «дорогое значит лучшее».
  newest,
}

/// Когда игрок ложится спать.
sealed class PrestigeRule {
  const PrestigeRule();

  /// Лечь прямо сейчас? [runSeconds] — сколько игрок отыграл в этом заходе,
  /// [rate] — сколько он сейчас нагоняет в секунду.
  bool shouldPrestige(GameState state, {required double runSeconds, required double rate});
}

/// Старое правило: лечь, когда мудрость вырастет на [growth] от накопленной.
///
/// Оставлено только для сверки с прежними числами. Как правило оно плохое:
/// на большой мудрости само рождает стены. От 17 до 26 мудрости при +50 % —
/// девять удвоений нагнанного, и симулятор честно ждёт их все, хотя живой
/// игрок давно бы лёг.
class WisdomGrowthRule extends PrestigeRule {
  final double growth;

  const WisdomGrowthRule(this.growth);

  @override
  bool shouldPrestige(GameState state, {required double runSeconds, required double rate}) {
    final p = state.prestige;
    if (!p.canPrestige) return false;
    return p.pendingWisdom >= math.max(1.0, p.wisdom * growth);
  }
}

/// Лечь, когда прибавка множителя окупает заход.
///
/// Мудрость множит всё производство, а общий множитель сокращает следующий
/// заход почти пропорционально: с множителем ×r до той же точки доходишь за
/// 1/r времени. Значит, заход длиной T с прибавкой ×r стоит ln(r)/T — столько
/// «порядков» ускорения он приносит за час игры. Игрок ложится, когда ждать
/// следующую мудрость невыгодно: её прибавка, растянутая на заход вместе с
/// ожиданием, даёт меньше, чем уже есть сейчас.
///
/// Ожидание следующей мудрости считается по нынешнему потоку, как его видит
/// игрок по полосе. Поток по дороге растёт, так что правило ложится чуть
/// раньше идеала — как и живой игрок, который не знает будущего.
///
/// Множитель берётся из самого [PrestigeState], а не своей формулой: иначе
/// правка веса мудрости не дошла бы до правила. Вместе с вехами «всё ×N»:
/// следующую веху игрок видит на вкладке мудрости и дождётся её, если она
/// того стоит. Вехи ступеней правило не учитывает — сколько они дадут,
/// зависит от того, какая ступень гонит, и живой игрок этого тоже не
/// сосчитает.
class PaybackRule extends PrestigeRule {
  const PaybackRule();

  @override
  bool shouldPrestige(GameState state, {required double runSeconds, required double rate}) {
    final p = state.prestige;
    if (!p.canPrestige || runSeconds <= 0) return false;

    final base = p.productionMultiplier;
    final now = p.claimAll().productionMultiplier / base;
    // Чуть выше порога: иначе округление log2 внизу отдаёт ту же мудрость.
    final nextAt = p.nextWisdomAtMl * (1 + 1e-9);
    final next = p.copyWith(claimedMl: nextAt).productionMultiplier / base;
    if (now <= 1) return false;

    final wait = rate > 0 ? (nextAt - p.totalEverEarned) / rate : double.infinity;
    return math.log(now) / runSeconds >= math.log(next) / (runSeconds + wait);
  }
}

/// Как игрок обходится с гостями (lib/content/events.dart).
///
/// Гость приходит раз в 10 минут на 5 и платит ×1,7–3,6 от Петровича — это
/// самая большая надбавка в игре. Цели баланса долго мерились без него, и
/// внимательный игрок в игре доходил быстрее, чем в симуляторе.
enum GuestHabit {
  /// Гостей не замечает, сдаёт только Петровичу. Нужен для сверки с целями,
  /// снятыми до гостей, и для колонки «без гостей» в отчёте.
  ignores,

  /// Сдаёт гостю, только если тот случайно на месте в момент продажи и игрок
  /// его заметил — в доле продаж, равной вниманию. Расписания не держит в
  /// голове и ради гостя ничего не откладывает.
  ifThere,

  /// Знает расписание и держит бак для гостя, если тот успеет прийти раньше,
  /// чем бак переполнится; иначе продаёт как без гостей.
  waits,
}

/// Портрет игрока.
class PlayStyle {
  final String name;

  /// Нажатий в минуту. Ноль — игра оставлена в фоне.
  final double tapsPerMinute;

  /// Средний множитель СЕРИИ за партию.
  ///
  /// Это не «жар под кубом», а то, во что он превращается: удержание в окне
  /// копит серию, серия множит производство. Внимательный игрок держит её
  /// почти на максимуме, фоновый — не держит вовсе.
  final double heat;

  /// Какую долю времени игрок реально смотрит в игру.
  final double attention;

  final BuyRule rule;

  /// Когда игрок ложится спать. `null` — не ложится вовсе.
  final PrestigeRule? prestige;

  final GuestHabit guests;

  const PlayStyle({
    required this.name,
    required this.tapsPerMinute,
    required this.heat,
    required this.attention,
    required this.rule,
    this.prestige,
    required this.guests,
  });

  PlayStyle _copy({PrestigeRule? Function()? prestige, GuestHabit? guests}) => PlayStyle(
        name: name,
        tapsPerMinute: tapsPerMinute,
        heat: heat,
        attention: attention,
        rule: rule,
        prestige: prestige == null ? this.prestige : prestige(),
        guests: guests ?? this.guests,
      );

  /// Тот же игрок с другим правилом похмелья.
  PlayStyle withPrestige(PrestigeRule? rule) => _copy(prestige: () => rule);

  /// Тот же игрок, который гостей не замечает.
  PlayStyle get withoutGuests => _copy(guests: GuestHabit.ignores);

  /// Тот, кто сидит в игре и считает.
  static const tryhard = PlayStyle(
    name: 'считает',
    tapsPerMinute: 90,
    heat: 2.7,
    attention: 0.9,
    rule: BuyRule.payback,
    prestige: PaybackRule(),
    guests: GuestHabit.waits,
  );

  /// Обычный игрок: заходит, тыкает, покупает что подешевле.
  static const casual = PlayStyle(
    name: 'обычный',
    tapsPerMinute: 30,
    heat: 1.8,
    attention: 0.5,
    rule: BuyRule.cheapest,
    prestige: PaybackRule(),
    guests: GuestHabit.ifThere,
  );

  /// Тот же игрок на прежнем правиле похмелья: «считает» ложился при +50 %
  /// мудрости, «обычный» — при +100 %, «фоновый» не ложился. Нужен для
  /// сверки с числами, снятыми до смены правила.
  PlayStyle get onLegacyRule => withPrestige(switch (name) {
        'считает' => const WisdomGrowthRule(0.5),
        'обычный' => const WisdomGrowthRule(1.0),
        _ => null,
      });

  /// Тот, кто заглядывает пару раз в день.
  ///
  /// Нажатий мало, но они есть — и это принципиально. С нулём нажатий игрок
  /// заперт навсегда: производства нет, денег нет, купить первую банку не на
  /// что. Это не баг симулятора, а свойство жанра: первый клик обязателен.
  static const idler = PlayStyle(
    name: 'фоновый',
    tapsPerMinute: 4,
    heat: 1.0,
    attention: 0.1,
    rule: BuyRule.cheapest,
    guests: GuestHabit.ifThere,
  );

  static const all = [tryhard, casual, idler];
}

/// Снимок партии в один момент.
class Checkpoint {
  final Duration at;
  final double mlPerSecond;
  final double money;
  final double revenuePerSecond;

  /// Окупаемость лучшей доступной покупки. `null` — покупать нечего.
  final Duration? payback;

  /// Что именно окупается лучше всего.
  final String? bestBuy;

  final int wisdom;
  final int sortIndex;

  /// Доля общего дохода, которую даёт самый сильный аппарат. Близко к 1 —
  /// остальные аппараты декоративные.
  final double topGeneratorShare;

  /// За сколько наполнится бак при текущем потоке. Это и есть «на сколько
  /// можно уйти», и одновременно — как редко игрок вообще жмёт «продать».
  final Duration tankBuffer;

  /// Нагнано за всё время. Из этого числа растёт мудрость, поэтому его надо
  /// видеть: когда мудрость ведёт себя странно, причина всегда здесь.
  final double lifetimeMl;

  const Checkpoint({
    required this.at,
    required this.mlPerSecond,
    required this.money,
    required this.revenuePerSecond,
    required this.payback,
    required this.bestBuy,
    required this.wisdom,
    required this.sortIndex,
    required this.topGeneratorShare,
    required this.tankBuffer,
    required this.lifetimeMl,
  });
}

/// Итог прогона.
class SimResult {
  final PlayStyle style;
  final List<Checkpoint> timeline;

  /// Когда впервые куплен каждый аппарат.
  final Map<String, Duration> firstBuy;

  /// Когда впервые куплено каждое улучшение.
  final Map<String, Duration> upgradeBought;

  /// Когда стало возможно первое похмелье.
  final Duration? firstPrestige;

  final int sales;

  /// Сколько раз игрок лёг спать за партию.
  int get prestiges => hangovers.length;

  /// Когда игрок ложился спать — от начала партии, вместе с отсутствием.
  final List<Duration> hangovers;

  /// Мудрость сразу после каждого похмелья — по нему видно, когда
  /// бралась какая веха.
  final List<int> hangoverWisdom;

  /// Сколько игрок провёл в игре. Без отсутствия совпадает с длиной партии.
  final Duration played;

  final GameState finalState;

  /// Сколько миллилитров потеряно из-за переполнения бака.
  final double overflowedMl;

  const SimResult({
    required this.style,
    required this.timeline,
    required this.firstBuy,
    required this.upgradeBought,
    required this.firstPrestige,
    required this.sales,
    required this.hangovers,
    required this.hangoverWisdom,
    required this.played,
    required this.finalState,
    required this.overflowedMl,
  });

  /// Аппараты, до которых игрок так и не добрался.
  List<String> get unreached => [
        for (final g in kGenerators)
          if (!firstBuy.containsKey(g.id)) g.id,
      ];

  /// Наибольшее производство за партию.
  ///
  /// Мерить по последнему кадру нельзя: игрок мог только что лечь спать, и
  /// в этот момент у него честный ноль. Пик показывает, докуда он дошёл.
  double get peakMlPerSecond {
    var peak = 0.0;
    for (final c in timeline) {
      if (c.mlPerSecond > peak) peak = c.mlPerSecond;
    }
    return peak;
  }

  /// Улучшения, которые не были куплены ни разу, — кандидаты в мёртвый контент.
  List<String> get unboughtUpgrades => [
        for (final u in kUpgrades)
          if (!upgradeBought.containsKey(u.id)) u.id,
      ];
}

/// Как игрока нет.
///
/// Прежний симулятор этого различия не знал: все модельные игроки сидели в
/// открытой игре 100 % времени, а `creditOffline` не звался ни разу. Поэтому
/// он и проглядел, что ночь открытой вкладки после 17 минут игры даёт первую
/// мудрость (docs/PLAN-1.0.md, раздел 2).
enum Absence {
  /// Вкладка открыта, в неё не смотрят. Игра идёт сама, с автопродажей.
  tabOpen,

  /// Игра закрыта или усыплена системой. Производства нет — копится поток
  /// времени, как в `bootstrap`.
  closed,
}

/// Партия, которую можно продолжать с любого места.
///
/// Изменяемая намеренно: профили режут одну партию на куски игры и
/// отсутствия, и таскать состояние через каждый кусок руками — значит
/// потерять по дороге то, что симулятор о партии узнал.
class SimParty {
  final PlayStyle style;

  /// Когда партия началась, по часам игры. Рынок и гости живут по этим часам.
  final DateTime origin;

  GameState state;

  /// Сколько прошло от начала партии, вместе с отсутствием.
  Duration elapsed = Duration.zero;

  /// Сколько из этого игрок был в игре.
  Duration played = Duration.zero;

  /// Сколько игрок отыграл в нынешнем заходе — с последнего похмелья.
  /// Отсутствие сюда не входит: заход игрок меряет своим временем.
  Duration runPlayed = Duration.zero;

  /// С какой скоростью игрок тратит поток, пока играет. 1 — не тратит.
  /// Кончился поток — ускорение кончается само, как в игре.
  double boost = 1.0;

  final List<Checkpoint> timeline = [];
  final Map<String, Duration> firstBuy = {};
  final Map<String, Duration> upgradeBought = {};
  final List<Duration> hangovers = [];
  final List<int> hangoverWisdom = [];
  Duration? firstPrestige;
  int sales = 0;
  double overflowedMl = 0;

  double _tapBudget = 0;

  /// Доля продаж при госте, в которых «обычный» его замечает, копится
  /// дробями, как нажатия: жребий симулятору нельзя, иначе прогон не
  /// повторяется.
  double _guestNotice = 0;
  Duration _nextSample = Duration.zero;

  SimParty._({required this.style, required this.origin, required this.state});

  DateTime get now => origin.add(elapsed);

  /// Та же партия, но дальше идущая своей дорогой: «а если бы он ушёл
  /// сейчас». Состояние игры неизменяемо, копируются только журналы.
  SimParty fork({PlayStyle? style}) => SimParty._(
        style: style ?? this.style,
        origin: origin,
        state: state,
      )
        ..elapsed = elapsed
        ..played = played
        ..runPlayed = runPlayed
        ..boost = boost
        ..timeline.addAll(timeline)
        ..firstBuy.addAll(firstBuy)
        ..upgradeBought.addAll(upgradeBought)
        ..hangovers.addAll(hangovers)
        ..hangoverWisdom.addAll(hangoverWisdom)
        ..firstPrestige = firstPrestige
        ..sales = sales
        ..overflowedMl = overflowedMl
        .._tapBudget = _tapBudget
        .._guestNotice = _guestNotice
        .._nextSample = _nextSample;

  void _noteFirstPrestige() {
    if (firstPrestige == null && state.prestige.canPrestige) {
      firstPrestige = elapsed;
    }
  }

  SimResult get result => SimResult(
        style: style,
        timeline: List.unmodifiable(timeline),
        firstBuy: Map.unmodifiable(firstBuy),
        upgradeBought: Map.unmodifiable(upgradeBought),
        firstPrestige: firstPrestige,
        sales: sales,
        hangovers: List.unmodifiable(hangovers),
        hangoverWisdom: List.unmodifiable(hangoverWisdom),
        played: played,
        finalState: state,
        overflowedMl: overflowedMl,
      );
}

/// Кандидат на покупку: во что обойдётся и что даст.
class _Candidate {
  final String id;
  final String label;
  final double cost;

  /// Прирост выручки в рублях за секунду.
  final double deltaRevenuePerSecond;

  final GameState Function(GameState) apply;

  const _Candidate({
    required this.id,
    required this.label,
    required this.cost,
    required this.deltaRevenuePerSecond,
    required this.apply,
  });

  /// Секунды до возврата вложенного. `double.infinity` — не окупится никогда.
  double get paybackSeconds =>
      deltaRevenuePerSecond <= 0 ? double.infinity : cost / deltaRevenuePerSecond;
}

class BalanceSim {
  final GameEngine engine;

  /// Шаг симуляции. Секунда достаточна: решения игрок принимает не чаще.
  final Duration step;

  /// Как часто снимать показания.
  final Duration sampleEvery;

  const BalanceSim({
    this.engine = const GameEngine(),
    this.step = const Duration(seconds: 1),
    this.sampleEvery = const Duration(minutes: 1),
  });

  /// Цена без рыночной волны — для решений. Волна нужна для выручки, но
  /// решения по ней принимать нельзя: получится шум, а не анализ.
  static double _steadyPricePerMl(GameState s) =>
      Market.basePricePerMl * Market.qualityMultiplier(s.upgrades);

  /// Сыграть партию с нуля без отрыва от экрана.
  SimResult run(PlayStyle style, {Duration horizon = const Duration(hours: 2)}) {
    final party = start(style);
    play(party, horizon);
    return party.result;
  }

  /// Новая партия. Дальше её ведут [play] и [away] в любом порядке.
  SimParty start(PlayStyle style) {
    final at = DateTime.utc(2026, 1, 1);
    return SimParty._(
      style: style,
      origin: at,
      state: newGame(content: kGenerators, upgrades: kUpgrades, now: at),
    );
  }

  /// Игрок сидит в игре [length] (или пока не выполнится [until]).
  ///
  /// Продолжает партию с того места, где она стоит: «час, потом ещё час» —
  /// то же самое, что «два часа подряд». На этом держатся все профили с
  /// отсутствием: они режут одну партию на куски, а не собирают свою.
  void play(SimParty p, Duration length, {bool Function(SimParty p)? until}) {
    final style = p.style;
    final steps = length.inMilliseconds ~/ step.inMilliseconds;
    final dt = step.inMilliseconds / 1000.0;

    for (var i = 0; i < steps; i++) {
      if (until != null && until(p)) return;
      final elapsed = p.elapsed;
      final now = p.now;
      var state = p.state;

      // --- Производство -------------------------------------------------
      final roomBefore = state.tankCapacity - state.resources.ml;
      final extra = math.min((p.boost - 1) * dt, state.flux.seconds);
      final produced = state.mlPerSecond * style.heat * (dt + extra);
      state = engine.processTick(
        state,
        now,
        heatMultiplier: style.heat,
        speed: p.boost,
      );
      if (produced > roomBefore) p.overflowedMl += produced - roomBefore;

      // --- Касания ------------------------------------------------------
      // Самогона они не дают: вся польза активной игры уже учтена множителем
      // жара выше. Считаем их только ради достижений на количество касаний.
      //
      // Нажатия копятся дробями. Первая версия округляла их на каждом шаге, и
      // игрок с 15 нажатиями в минуту при шаге в секунду не нажимал НИ РАЗУ:
      // 0.25 округлялось в ноль. Отчёт показывал, что обычный игрок за два
      // часа не покупает ничего, — и это была неправда про симулятор, а не
      // про игру.
      p._tapBudget += style.tapsPerMinute * style.attention * dt / 60;
      while (p._tapBudget >= 1) {
        state = engine.registerTouch(state, now);
        p._tapBudget -= 1;
      }

      // --- Сорт ---------------------------------------------------------
      // Пока игрок за экраном и держит жар — сорт растёт, иначе сползает.
      state = engine.advanceSort(
        state,
        _sortGrows(style)
            ? kSortGainPerSecond * state.prestige.bonuses.sortSpeed * style.attention * dt
            : -kSortDecayPerSecond * dt,
      );

      // --- Продажа ------------------------------------------------------
      // Игрок продаёт не только когда бак полон, но и когда хочет что-то
      // купить. Первая версия ждала полного бака — и при ёмкости в четыре
      // часа производства отчёт показывал шесть продаж за партию. Это была
      // неправдоподобная политика, которая прятала настоящую проблему.
      final wanted = _choose(state, style.rule, ignoreMoney: true);
      final buyer = _buyerNow(p, state, now, wanted);
      if (buyer != null) {
        state = engine.sellTo(state, buyer, now);
        p.sales++;
      }

      // --- Покупки ------------------------------------------------------
      var guard = 0;
      while (guard++ < 500) {
        final pick = _choose(state, style.rule);
        if (pick == null) break;
        final before = state;
        state = pick.apply(state);
        if (identical(before, state) || before == state) break;

        p.firstBuy.putIfAbsent(pick.id, () => elapsed);
        if (kUpgrades.any((u) => u.id == pick.id)) {
          p.upgradeBought.putIfAbsent(pick.id, () => elapsed);
        }
      }

      state = engine.checkAchievements(state).state;
      p.state = state;
      p._noteFirstPrestige();

      // --- Похмелье -----------------------------------------------------
      p.runPlayed += step;
      final rule = style.prestige;
      if (rule != null &&
          rule.shouldPrestige(
            state,
            runSeconds: p.runPlayed.inMilliseconds / 1000.0,
            rate: state.mlPerSecond * style.heat,
          )) {
        p.state = engine.prestige(state, kGenerators, kUpgrades, now);
        p.hangovers.add(elapsed);
        p.hangoverWisdom.add(p.state.prestige.wisdom);
        p.runPlayed = Duration.zero;
      }

      // --- Показания ----------------------------------------------------
      // Только пока игрок в игре: окупаемость — это то, что он видит, когда
      // выбирает покупку, а не то, что стоит на экране, пока его нет.
      if (elapsed >= p._nextSample) {
        p.timeline.add(_snapshot(p.state, elapsed));
        p._nextSample = elapsed + sampleEvery;
      }

      p.elapsed += step;
      p.played += step;
    }
  }

  /// Игрока нет [length]. Как именно нет — решает [how].
  ///
  /// Единственное место, где симулятор знает про отсутствие: закрытая игра
  /// копит поток ([_closed]), и все профили получают это разом.
  void away(SimParty p, Duration length, Absence how) {
    if (length <= Duration.zero) return;
    switch (how) {
      case Absence.tabOpen:
        _tabOpen(p, length);
      case Absence.closed:
        _closed(p, length);
    }
  }

  /// Вкладка открыта, но в неё не смотрят: гонит на жаре ×1, сорт сползает,
  /// никто ничего не покупает и не продаёт. Полный бак сдаёт автопродажа,
  /// если цель её уже открыла, — как `GameNotifier._tick`. Без неё бак
  /// встаёт полным, и дальше производство идёт мимо.
  void _tabOpen(SimParty p, Duration length) {
    final steps = length.inMilliseconds ~/ step.inMilliseconds;
    final dt = step.inMilliseconds / 1000.0;
    for (var i = 0; i < steps; i++) {
      final now = p.now;
      var state = p.state;
      final roomBefore = state.tankCapacity - state.resources.ml;
      final produced = state.mlPerSecond * dt;
      state = engine.processTick(state, now);
      if (produced > roomBefore) p.overflowedMl += produced - roomBefore;
      state = engine.advanceSort(state, -kSortDecayPerSecond * dt);
      if (state.achievements.hasPerk(AchievementPerk.autoSell) && state.isTankFull) {
        state = engine.sell(state, now);
        p.sales++;
      }
      p.state = engine.checkAchievements(state).state;
      p._noteFirstPrestige();
      p.elapsed += step;
    }
  }

  /// Игра закрыта: производства нет, копится поток — тем же
  /// [GameEngine.creditAfk], что и в `bootstrap`. Метка времени подтягивается
  /// к возвращению, как у загруженного сейва.
  void _closed(SimParty p, Duration length) {
    p.elapsed += length;
    p.state = engine
        .creditAfk(p.state, length)
        .state
        .copyWith(lastUpdateTime: p.now);
  }

  Checkpoint _snapshot(GameState state, Duration at) {
    final best = _choose(state, BuyRule.payback, ignoreMoney: true);
    final price = _steadyPricePerMl(state);

    // Доля самого сильного аппарата — показывает, не превратились ли младшие
    // тиры в декорацию.
    var top = 0.0;
    for (final g in state.generators.items) {
      final out = Production.generatorOutput(
        g,
        state.generators,
        state.upgrades,
        state.prestige,
        state.achievements.multiplier,
      );
      if (out > top) top = out;
    }

    return Checkpoint(
      at: at,
      mlPerSecond: state.mlPerSecond,
      money: state.resources.money,
      revenuePerSecond: state.mlPerSecond * price,
      payback: best == null || !best.paybackSeconds.isFinite
          ? null
          : Duration(milliseconds: (best.paybackSeconds * 1000).round()),
      bestBuy: best?.label,
      wisdom: state.prestige.wisdom,
      sortIndex: state.sort.index,
      topGeneratorShare: state.mlPerSecond <= 0 ? 0 : top / state.mlPerSecond,
      tankBuffer: state.tankBuffer,
      lifetimeMl: state.prestige.totalEverEarned,
    );
  }

  /// Кому игрок сдал бы бак прямо сейчас — то же решение, что в [play].
  /// Открыто ради тестов поведения с гостями: по итогам партии не видно,
  /// почему продажа случилась или нет.
  Buyer? buyerNow(SimParty p) =>
      _buyerNow(p, p.state, p.now, _choose(p.state, p.style.rule, ignoreMoney: true));

  /// Кому продать прямо сейчас. `null` — не продавать.
  ///
  /// Гость — тот же покупатель для движка ([GarageEvent.asBuyer]), поэтому
  /// цена с вехами «гости платят ×N» приходит из [GameEngine.saleValueFor]
  /// сама. Автопродажа гостей не знает (`GameNotifier._tick` зовёт
  /// `engine.sell`), и в [_tabOpen] её так и нет.
  Buyer? _buyerNow(SimParty p, GameState state, DateTime now, _Candidate? want) {
    if (state.resources.ml <= 0) return null;
    if (_fillsForGoal(state)) return null;
    final style = p.style;
    final active = style.guests == GuestHabit.ignores ? null : eventAt(now);
    final guest = active?.event.asBuyer;
    final guestTakes = guest != null && engine.canSellTo(state, guest);

    switch (style.guests) {
      case GuestHabit.ignores:
        break;

      case GuestHabit.ifThere:
        if (!_shouldSell(state, now, style, want)) return null;
        if (guestTakes) {
          p._guestNotice += style.attention;
          if (p._guestNotice >= 1) {
            p._guestNotice -= 1;
            return guest;
          }
        }
        return _bestBuyer(state, now);

      case GuestHabit.waits:
        final grows = _sortGrows(style);
        if (guestTakes) {
          // Каждая сделка с гостем роняет сорт на ступень. Сдавать гостю
          // каждую секунду, как Петровичу, — значит съехать до первача, и
          // шабашка тогда платит меньше, чем Петрович за дедов запас. Кто
          // считает, даёт сорту дорасти: это секунды, а гость стоит пять
          // минут. Не ждёт, только если гость уходит или бак уже полон.
          final topped = !grows || state.sort.isTop;
          final leaving = active!.remaining <= step;
          return topped || leaving || state.tankFraction >= 0.97 ? guest : null;
        }
        // Гостя нет — ждать до его прихода; гость есть, но сорт ещё не тот
        // и растёт — ждать, пока дорастёт (считаем, что сразу). Ждать можно,
        // пока бак не переполнится: перелив — чистая потеря, дороже любой
        // надбавки.
        final wait = guest != null && grows ? Duration.zero : untilNextEvent(now);
        final rate = state.mlPerSecond * style.heat * (state.flux.seconds > 0 ? p.boost : 1);
        final fillsBy = state.resources.ml + rate * wait.inMilliseconds / 1000;
        if (fillsBy < state.tankCapacity * 0.97) return null;
    }
    return _shouldSell(state, now, style, want) ? _bestBuyer(state, now) : null;
  }

  /// Цели «Целый литр» и «Под завязку» — налить бак. Живой игрок берёт их
  /// в первые минуты: бак наливается сам, пока он учится держать жар, а
  /// цели висят на экране подсказкой. Симулятор продавал каждую секунду, и
  /// бак у него не наливался никогда: ряды «Гараж» и «Хозяйство» не
  /// закрывались, и все цели баланса мерились без их ×1,35. Вскрылось на
  /// гостях — тот, кто ждёт гостя, копит бак и «Целый литр» брал, а без
  /// гостей нет, и половина прибавки от гостей оказалась этим литром.
  ///
  /// Налить бак игрок даёт, только когда это недолго: в первые секунды
  /// поток — миллилитр в секунду, и бак на 2 литра наливался бы полчаса.
  static const goalFillMax = Duration(minutes: 5);

  static bool _fillsForGoal(GameState state) {
    final a = state.achievements;
    if (a.has('a_full_tank') && a.has('a_litre')) return false;
    // Полный бак тоже держит: цели засчитываются после продажи, и продай
    // он полный бак в тот же шаг, «Под завязку» не засчиталась бы никогда.
    return state.tankBuffer <= goalFillMax;
  }

  /// Растёт ли у игрока сорт, пока он играет, — то же условие, что в [play].
  static bool _sortGrows(PlayStyle style) => style.attention > 0.3 && style.heat > 1.05;

  /// Пора ли продавать.
  ///
  /// Полный бак — остановленное производство, тут продаёт кто угодно. Дальше
  /// начинается разница: внимательный игрок сдаёт, когда хочет купить, и ловит
  /// хороший рынок; невнимательный ждёт, пока нальётся.
  bool _shouldSell(GameState state, DateTime now, PlayStyle style, _Candidate? want) {
    if (state.resources.ml <= 0) return false;
    if (state.tankFraction >= 0.97) return true;

    // Сдать, когда хочется купить, — это делает кто угодно, даже тот, кто
    // заглядывает раз в день. Первая версия требовала для этого внимания выше
    // 0.3, и редкий игрок оказывался заперт навсегда: бак меньше минимального
    // объёма не наполнялся, продажи не случалось, денег на первую банку не
    // появлялось. Тест это поймал, и он был прав — но прав про симулятор,
    // а не про игру.
    final needsMoney = want != null && state.resources.money < want.cost;
    if (needsMoney && state.resources.ml > 0) return true;

    // А вот ловить выгодный рынок умеет только тот, кто в него смотрит.
    if (style.attention < 0.3) return false;
    return Market.isGoodMoment(now) && state.tankFraction > 0.5;
  }

  /// Кому выгоднее сдать прямо сейчас.
  Buyer _bestBuyer(GameState state, DateTime now) {
    Buyer best = kBuyers.first;
    var bestValue = -1.0;
    for (final b in kBuyers) {
      if (!engine.canSellTo(state, b)) continue;
      final value = engine.saleValueFor(state, b, now);
      if (value > bestValue) {
        bestValue = value;
        best = b;
      }
    }
    return best;
  }

  /// Выбрать покупку по правилу. [ignoreMoney] — для анализа: «что было бы
  /// лучшей покупкой, будь деньги».
  _Candidate? _choose(GameState state, BuyRule rule, {bool ignoreMoney = false}) {
    final options = _candidates(state)
        .where((c) => ignoreMoney || c.cost <= state.resources.money)
        .toList();
    if (options.isEmpty) return null;

    switch (rule) {
      case BuyRule.payback:
        options.sort((a, b) => a.paybackSeconds.compareTo(b.paybackSeconds));
        final best = options.first;
        return best.paybackSeconds.isFinite ? best : null;

      case BuyRule.cheapest:
        options.sort((a, b) => a.cost.compareTo(b.cost));
        return options.first;

      case BuyRule.newest:
        final gens = options.where((c) => kGenerators.any((g) => g.id == c.id));
        if (gens.isEmpty) return options.first;
        return gens.last;
    }
  }

  /// Всё, что игрок может купить, приведённое к одной шкале «₽ вложено →
  /// ₽/с получено».
  List<_Candidate> _candidates(GameState state) {
    final out = <_Candidate>[];
    final price = _steadyPricePerMl(state);
    final rateNow = state.mlPerSecond;

    for (final g in state.generators.items) {
      final cost = engine.generatorCost(g, state.lastUpdateTime);
      final after = engine.buyGenerator(
        state.copyWith(
          resources: state.resources.copyWith(money: double.maxFinite),
        ),
        g.id,
        state.lastUpdateTime,
      );
      out.add(_Candidate(
        id: g.id,
        label: g.name,
        cost: cost,
        deltaRevenuePerSecond: (after.mlPerSecond - rateNow) * price,
        apply: (s) => engine.buyGenerator(s, g.id, s.lastUpdateTime),
      ));
    }

    for (final u in state.upgrades.items) {
      if (u.purchased) continue;
      final after = engine.buyUpgrade(
        state.copyWith(
          resources: state.resources.copyWith(money: double.maxFinite),
        ),
        u.id,
        state.lastUpdateTime,
      );

      // Улучшения бака не двигают ни поток, ни цену — их польза в том, что
      // реже простаивает производство. Оцениваем как долю потока, которую
      // расширение спасает от перелива.
      final double gain;
      if (u.target == UpgradeTarget.tankCapacity) {
        gain = rateNow * price * 0.15;
      } else {
        gain = after.mlPerSecond * _steadyPricePerMl(after) - rateNow * price;
      }

      out.add(_Candidate(
        id: u.id,
        label: u.name,
        cost: engine.upgradeCost(u, state.lastUpdateTime),
        deltaRevenuePerSecond: gain,
        apply: (s) => engine.buyUpgrade(s, u.id, s.lastUpdateTime),
      ));
    }

    return out;
  }
}

/// Красивый вывод для отчёта.
String formatDuration(Duration? d) {
  if (d == null) return '—';
  if (d.inSeconds < 90) return '${d.inSeconds}с';
  if (d.inMinutes < 90) return '${d.inMinutes}м';
  final hours = d.inMinutes / 60;
  return '${hours.toStringAsFixed(1)}ч';
}

/// Время с точностью до секунды: 36:46 или 2:05:00. Для сверки прогонов,
/// где [formatDuration] теряет разницу.
String formatClock(Duration? d) {
  if (d == null) return '—';
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (d.inHours == 0) return '${d.inMinutes}:$s';
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  return '${d.inHours}:$m:$s';
}

/// Компактная запись больших чисел для таблиц — теми же суффиксами, что в
/// игре. Свой список обрывался на секстиллионах, и за порталом отчёт писал
/// «1234.5Скс».
String formatBig(double v) {
  if (!v.isFinite) return '∞';
  if (v < 1000) return v.toStringAsFixed(v < 10 ? 2 : 0);
  return Fmt.short(v, trim: false);
}

/// Медиана — устойчивее среднего к одиночным выбросам.
double median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

/// Во сколько раз величина меняется за прогон — грубая мера «разноса».
double spread(List<double> values) {
  final clean = values.where((v) => v.isFinite && v > 0).toList();
  if (clean.length < 2) return 1;
  final lo = clean.reduce(math.min);
  final hi = clean.reduce(math.max);
  return hi / lo;
}
