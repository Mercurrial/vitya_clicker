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
import '../content/game_content.dart';
import '../content/sorts.dart';
import '../core/game_serializer.dart';
import '../engine/game_engine.dart';
import '../engine/market.dart';
import '../engine/production.dart';
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

/// Портрет игрока.
class PlayStyle {
  final String name;

  /// Нажатий в минуту. Ноль — игра оставлена в фоне.
  final double tapsPerMinute;

  /// Средний множитель жара, пока игрок за экраном.
  final double heat;

  /// Какую долю времени игрок реально смотрит в игру.
  final double attention;

  final BuyRule rule;

  /// Когда игрок ложится спать: при каком приросте мудрости относительно
  /// уже накопленной. 0.5 — «готов сбросить ради +50 % мудрости».
  /// `null` — не прессижит вовсе.
  final double? prestigeAt;

  const PlayStyle({
    required this.name,
    required this.tapsPerMinute,
    required this.heat,
    required this.attention,
    required this.rule,
    this.prestigeAt,
  });

  /// Тот, кто сидит в игре и считает.
  static const tryhard = PlayStyle(
    name: 'считает',
    tapsPerMinute: 90,
    heat: 1.6,
    attention: 0.9,
    rule: BuyRule.payback,
    prestigeAt: 0.5,
  );

  /// Обычный игрок: заходит, тыкает, покупает что подешевле.
  static const casual = PlayStyle(
    name: 'обычный',
    tapsPerMinute: 30,
    heat: 1.25,
    attention: 0.5,
    rule: BuyRule.cheapest,
    prestigeAt: 1.0,
  );

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
  final int prestiges;

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
    required this.prestiges,
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

  SimResult run(PlayStyle style, {Duration horizon = const Duration(hours: 2)}) {
    final start = DateTime.utc(2026, 1, 1);
    var now = start;
    var state = newGame(content: kGenerators, upgrades: kUpgrades, now: now);

    final timeline = <Checkpoint>[];
    final firstBuy = <String, Duration>{};
    final upgradeBought = <String, Duration>{};
    Duration? firstPrestige;
    var sales = 0;
    var overflowed = 0.0;
    var nextSample = Duration.zero;

    final steps = horizon.inMilliseconds ~/ step.inMilliseconds;
    final dt = step.inMilliseconds / 1000.0;

    // Нажатия копятся дробями. Первая версия округляла их на каждом шаге, и
    // игрок с 15 нажатиями в минуту при шаге в секунду не нажимал НИ РАЗУ:
    // 0.25 округлялось в ноль. Отчёт показывал, что обычный игрок за два часа
    // не покупает ничего, — и это была неправда про симулятор, а не про игру.
    var tapBudget = 0.0;
    var prestiges = 0;

    for (var i = 0; i < steps; i++) {
      final elapsed = Duration(milliseconds: i * step.inMilliseconds);
      now = start.add(elapsed);

      // --- Производство -------------------------------------------------
      final roomBefore = state.tankCapacity - state.resources.ml;
      final produced = state.mlPerSecond * style.heat * dt;
      state = engine.processTick(state, now, heatMultiplier: style.heat);
      if (produced > roomBefore) overflowed += produced - roomBefore;

      // --- Нажатия ------------------------------------------------------
      tapBudget += style.tapsPerMinute * style.attention * dt / 60;
      while (tapBudget >= 1) {
        state = engine.processTap(state, now, heatMultiplier: style.heat);
        tapBudget -= 1;
      }

      // --- Сорт ---------------------------------------------------------
      // Пока игрок за экраном и держит жар — сорт растёт, иначе сползает.
      state = engine.advanceSort(
        state,
        style.attention > 0.3 && style.heat > 1.05
            ? kSortGainPerSecond * style.attention * dt
            : -kSortDecayPerSecond * dt,
      );

      // --- Продажа ------------------------------------------------------
      // Игрок продаёт не только когда бак полон, но и когда хочет что-то
      // купить. Первая версия ждала полного бака — и при ёмкости в четыре
      // часа производства отчёт показывал шесть продаж за партию. Это была
      // неправдоподобная политика, которая прятала настоящую проблему.
      final wanted = _choose(state, style.rule, ignoreMoney: true);
      if (_shouldSell(state, now, style, wanted)) {
        state = engine.sellTo(state, _bestBuyer(state, now), now);
        sales++;
      }

      // --- Покупки ------------------------------------------------------
      var guard = 0;
      while (guard++ < 500) {
        final pick = _choose(state, style.rule);
        if (pick == null) break;
        final before = state;
        state = pick.apply(state);
        if (identical(before, state) || before == state) break;

        firstBuy.putIfAbsent(pick.id, () => elapsed);
        if (kUpgrades.any((u) => u.id == pick.id)) {
          upgradeBought.putIfAbsent(pick.id, () => elapsed);
        }
      }

      state = engine.checkAchievements(state).state;

      if (firstPrestige == null && state.prestige.canPrestige) {
        firstPrestige = elapsed;
      }

      // --- Похмелье -----------------------------------------------------
      final threshold = style.prestigeAt;
      if (threshold != null && state.prestige.canPrestige) {
        final gain = state.prestige.pendingWisdom;
        final worth = math.max(1.0, state.prestige.wisdom * threshold);
        if (gain >= worth) {
          state = engine.prestige(state, kGenerators, kUpgrades, now);
          prestiges++;
        }
      }

      // --- Показания ----------------------------------------------------
      if (elapsed >= nextSample) {
        timeline.add(_snapshot(state, elapsed));
        nextSample += sampleEvery;
      }
    }

    return SimResult(
      style: style,
      timeline: timeline,
      firstBuy: firstBuy,
      upgradeBought: upgradeBought,
      firstPrestige: firstPrestige,
      sales: sales,
      prestiges: prestiges,
      finalState: state,
      overflowedMl: overflowed,
    );
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
      final cost = engine.generatorCost(g);
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
        cost: u.cost,
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

/// Компактная запись больших чисел для таблиц.
String formatBig(double v) {
  if (!v.isFinite) return '∞';
  if (v < 1000) return v.toStringAsFixed(v < 10 ? 2 : 0);
  const suffixes = ['', 'К', 'М', 'Б', 'Т', 'Квд', 'Квт', 'Скс'];
  var i = 0;
  var x = v;
  while (x >= 1000 && i < suffixes.length - 1) {
    x /= 1000;
    i++;
  }
  return '${x.toStringAsFixed(x < 10 ? 2 : 1)}${suffixes[i]}';
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
