/// Все числа экономики и их отпечаток.
///
/// После выпуска любая правка того, от чего зависят доход, цены и скорость
/// прогресса, обязана поднять версию баланса, объяснить правку игроку и при
/// ухудшении компенсировать (CLAUDE.md). Забыть это легко: правишь одно
/// число, тесты зелёные, а у игрока молча поехал доход. Поэтому
/// `release_contract_test` сверяет отпечаток этих чисел с записанным.
///
/// Первый отпечаток собирался из одних полей `Balance`, и мимо него проходила
/// половина дохода: цены сортов, гости, ×1.05 за цель, девять улучшений,
/// написанных руками, серия жара, рынок, формула мудрости. Поднять цену
/// «Дедова запаса» можно было, не тронув ни версии, ни журнала. Теперь в
/// отпечатке всё, что ниже, а `economy_fingerprint_test` следит, чтобы новое
/// число нельзя было забыть: каждое поле `Balance`, каждое поле таблиц и
/// каждая константа файлов экономики — либо в отпечатке, либо в списке
/// исключений с причиной.
///
/// ## Что входит
///
/// * `Balance` — все поля, в том числе цена коллайдера и дорожка вех
///   мудрости: веха может дать и отнять бонус, как любое другое число.
/// * Таблицы: аппараты и улучшения (`kGenerators` и `kUpgrades` строятся из
///   `Balance`; улучшения жара, бака и связки — руками), сорта, постоянный
///   покупатель, гости — такими, какими их видит продажа (`asBuyer`), ряды
///   целей с перками.
/// * Отдельные числа ([Economy.constants]): скорости сорта, расписание
///   гостей, ×1.05 за цель и ×1.35 за ряд, размах рынка, все числа жара и
///   серии, порог AFK.
/// * Формулы, в которые числа вписаны прямо в код ([Economy.formulas]), —
///   снятые в контрольных точках: волна рынка, мудрость и её множитель, ×2 за
///   рубеж, связки, бак, цены аппаратов, выручка, поток, сорт, стартовый
///   набор, сколько раз за неделю приходит каждый гость.
///
/// ## Что сознательно не входит
///
/// * Тексты, цвета сортов, вёрстка, анимации, звук и вибрация — на доход не
///   влияют.
/// * Пороги целей («накопить 1 000 ₽»). Условие цели — код, а не данные:
///   отпечаток видит id, ряды, перки и множители, но не пороги. Чтобы их
///   покрыть, пороги надо вынести в данные.
/// * Модели игроков и цели симулятора (`lib/sim/`) — это мерка, а не игра.
/// * Подсветка «хороший момент продать» (`Market.isGoodMoment`) и пресеты
///   ускорения на вкладке потока — подсказка и удобство: итог от них не
///   зависит, предел ускорения — в `Balance`.
/// * Мелкие числа управления жаром, вписанные в код контроллера: зазор окна
///   до перегрева, стартовое место окна, предел шага кадра.
///
/// ## Почему числа округлены
///
/// Каждое число записано с точностью до десяти значащих цифр. Всё, что
/// считается через `pow`, `log` и `sin`, берётся из библиотеки платформы и в
/// последнем знаке может разойтись между Windows, где пишут код, и Linux, где
/// проверяет CI. Отпечаток, записанный на одной машине, не должен падать на
/// другой, а правку баланса десятая значащая цифра не спрячет.
library;

import 'dart:convert';

import 'package:idle_game/content/achievements.dart';
import 'package:idle_game/content/balance.dart';
import 'package:idle_game/content/buyers.dart';
import 'package:idle_game/content/events.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/content/sorts.dart';
import 'package:idle_game/content/wisdom_milestones.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/engine/market.dart';
import 'package:idle_game/engine/production.dart';
import 'package:idle_game/models/achievement.dart';
import 'package:idle_game/models/achievements_state.dart';
import 'package:idle_game/models/flux_state.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/generator.dart';
import 'package:idle_game/models/generators_state.dart';
import 'package:idle_game/models/prestige_state.dart';
import 'package:idle_game/models/resources_state.dart';
import 'package:idle_game/models/sort_state.dart';
import 'package:idle_game/models/upgrade.dart';
import 'package:idle_game/models/upgrades_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/game/heat_controller.dart';

/// Входы отпечатка.
///
/// Таблицы — параметрами, а не глобальными константами: так тест может
/// подменить любое одно число и убедиться, что отпечаток его видит.
class Economy {
  final Balance balance;
  final List<Generator> generators;
  final List<Upgrade> upgrades;
  final List<Sort> sorts;
  final List<Buyer> buyers;
  final List<GarageEvent> guests;
  final List<AchievementRow> goalRows;

  /// Числа вне таблиц — по имени в коде.
  final Map<String, num> constants;

  /// Формулы в контрольных точках — по тому, что вызвано и с чем.
  final Map<String, num> formulas;

  const Economy({
    required this.balance,
    required this.generators,
    required this.upgrades,
    required this.sorts,
    required this.buyers,
    required this.guests,
    required this.goalRows,
    required this.constants,
    required this.formulas,
  });

  Economy copyWith({
    List<Generator>? generators,
    List<Upgrade>? upgrades,
    List<Sort>? sorts,
    List<Buyer>? buyers,
    List<GarageEvent>? guests,
    List<AchievementRow>? goalRows,
    Map<String, num>? constants,
    Map<String, num>? formulas,
  }) =>
      Economy(
        balance: balance,
        generators: generators ?? this.generators,
        upgrades: upgrades ?? this.upgrades,
        sorts: sorts ?? this.sorts,
        buyers: buyers ?? this.buyers,
        guests: guests ?? this.guests,
        goalRows: goalRows ?? this.goalRows,
        constants: constants ?? this.constants,
        formulas: formulas ?? this.formulas,
      );
}

/// Экономика, которая сейчас в игре.
///
/// Баланс — действующий (`Balance.current`), а не `kBalance`: тест подменяет
/// его через `withBalance`, и таблицы с формулами пересобираются под него.
Economy currentEconomy() => Economy(
      balance: Balance.current,
      generators: kGenerators,
      upgrades: kUpgrades,
      sorts: kSorts,
      buyers: kBuyers,
      guests: kGarageEvents,
      goalRows: kAchievementRows,
      constants: _constants(),
      formulas: _formulas(),
    );

/// Отпечаток: строка на число или запись таблицы, `ключ = значение`.
///
/// Строки, а не хеш: когда отпечаток разойдётся с записанным, сразу видно,
/// какое число поехало, а в diff правки баланса — что именно в ней
/// поменялось.
String economyFingerprint(Economy e) {
  final b = e.balance;
  return [
    'Balance.costGrowth = ${_n(b.costGrowth)}',
    'Balance.firstWisdomMl = ${_n(b.firstWisdomMl)}',
    'Balance.firstWisdomBonus = ${_n(b.firstWisdomBonus)}',
    'Balance.bonusPerWisdom = ${_n(b.bonusPerWisdom)}',
    'Balance.basePricePerMl = ${_n(b.basePricePerMl)}',
    'Balance.baseTankMl = ${_n(b.baseTankMl)}',
    'Balance.baseBufferSeconds = ${_n(b.baseBufferSeconds)}',
    'Balance.maxBufferSeconds = ${_n(b.maxBufferSeconds)}',
    'Balance.milestones = ${b.milestones.map(_n).join(', ')}',
    'Balance.firstGeneratorCost = ${_n(b.firstGeneratorCost)}',
    'Balance.tierCostRatio = ${_n(b.tierCostRatio)}',
    'Balance.firstGeneratorOutput = ${_n(b.firstGeneratorOutput)}',
    'Balance.tierOutputRatio = ${_n(b.tierOutputRatio)}',
    'Balance.tierUpgradeCosts = ${b.tierUpgradeCosts.map(_n).join(', ')}',
    'Balance.tierUpgradeMultiplier = ${_n(b.tierUpgradeMultiplier)}',
    'Balance.globalUpgradeCost = ${_n(b.globalUpgradeCost)}',
    'Balance.globalUpgradeMultiplier = ${_n(b.globalUpgradeMultiplier)}',
    'Balance.qualityUpgradeCost = ${_n(b.qualityUpgradeCost)}',
    'Balance.qualityUpgradeMultiplier = ${_n(b.qualityUpgradeMultiplier)}',
    'Balance.fluxMinutesPerHour = ${_n(b.fluxMinutesPerHour)}',
    'Balance.fluxMaxMinutesPerHour = ${_n(b.fluxMaxMinutesPerHour)}',
    'Balance.fluxBankHours = ${_n(b.fluxBankHours)}',
    'Balance.fluxMaxBankHours = ${_n(b.fluxMaxBankHours)}',
    'Balance.fluxRateCostBase = ${_n(b.fluxRateCostBase)}',
    'Balance.fluxRateCostStep = ${_n(b.fluxRateCostStep)}',
    'Balance.fluxBankCostBase = ${_n(b.fluxBankCostBase)}',
    'Balance.fluxBankCostStep = ${_n(b.fluxBankCostStep)}',
    'Balance.fluxMaxSpeed = ${_n(b.fluxMaxSpeed)}',
    'Balance.colliderCostFactor = ${_n(b.colliderCostFactor)}',
    // Веха — по строке: правка одной вехи видна в diff отдельно, и сдвиг
    // списка на одну веху не перекрашивает все строки ниже неё в «новые».
    for (var i = 0; i < b.wisdomMilestones.length; i++)
      'Balance.wisdomMilestones[$i] = ${_milestone(b.wisdomMilestones[i])}',
    for (final g in e.generators)
      'kGenerators.${g.id} = baseCost=${_n(g.baseCost)} '
          'baseProduction=${_n(g.baseProduction)}',
    for (final u in e.upgrades)
      'kUpgrades.${u.id} = cost=${_n(u.cost)} target=${u.target.name} '
          'targetGeneratorId=${u.targetGeneratorId} multiplier=${_n(u.multiplier)}',
    for (var i = 0; i < e.sorts.length; i++)
      'kSorts[$i] = multiplier=${_n(e.sorts[i].multiplier)}',
    for (final buyer in e.buyers) 'kBuyers.${buyer.id} = ${_buyer(buyer)}',
    // Гость — таким, каким его видит продажа: часть условий сделки
    // (уносит ли сорт, сколько берёт) задана не в таблице, а в asBuyer.
    for (final guest in e.guests)
      'kGarageEvents.${guest.id} = ${_buyer(guest.asBuyer)}',
    for (var i = 0; i < e.goalRows.length; i++)
      'kAchievementRows[$i] = ${_goals(e.goalRows[i])}',
    for (final c in e.constants.entries) '${c.key} = ${_n(c.value)}',
    for (final f in e.formulas.entries) '${f.key} = ${_n(f.value)}',
  ].join('\n');
}

/// Чем отпечаток [actual] отличается от записанного [expected] — по строке
/// на ключ: что стало другим, что пропало, что появилось.
List<String> fingerprintChanges(String expected, String actual) {
  final was = _parse(expected);
  final now = _parse(actual);
  return [
    for (final k in was.keys)
      if (!now.containsKey(k))
        '− $k = ${was[k]}'
      else if (now[k] != was[k])
        '  $k: ${was[k]} → ${now[k]}',
    for (final k in now.keys)
      if (!was.containsKey(k)) '+ $k = ${now[k]}',
  ];
}

/// Строки — без отступов: упавший тест печатает отпечаток с отступом, и
/// скопированный оттуда как есть он обязан читаться так же.
Map<String, String> _parse(String fingerprint) => {
      for (final line in const LineSplitter().convert(fingerprint).map((l) => l.trim()))
        if (line.contains(' = '))
          line.substring(0, line.indexOf(' = ')):
              line.substring(line.indexOf(' = ') + 3),
    };

/// Ряд целей — id подряд, с перком через двоеточие: перк открывает
/// автопродажу и покупку пачками, а это тоже скорость.
String _goals(AchievementRow row) => [
      for (final a in row.items)
        a.perk == AchievementPerk.none ? a.id : '${a.id}:${a.perk.name}',
    ].join(' ');

/// Веха — мир, порог и эффект со всеми его числами.
String _milestone(WisdomMilestone m) =>
    'world=${m.world.name} wisdom=${m.wisdom} ${switch (m.effect) {
      StillBoost(:final generatorId, :final factor) =>
        'StillBoost generatorId=$generatorId factor=${_n(factor)}',
      AllBoost(:final factor) => 'AllBoost factor=${_n(factor)}',
      RunStart(:final money) => 'RunStart money=${_n(money)}',
      KeepUpgrades(:final target) => 'KeepUpgrades target=${target.name}',
      SortSpeed(:final factor) => 'SortSpeed factor=${_n(factor)}',
      GuestPay(:final factor) => 'GuestPay factor=${_n(factor)}',
    }}';

String _buyer(Buyer b) =>'multiplier=${_n(b.multiplier)} '
    'minSortIndex=${b.minSortIndex} minMl=${_n(b.minMl)} '
    'maxMl=${b.maxMl == null ? 'null' : _n(b.maxMl!)} '
    'consumesSort=${b.consumesSort}';

/// Число — как его пишут руками: `15`, `1.15`, `8.4e13`.
///
/// Десять значащих цифр — см. «Почему числа округлены» в шапке файла.
String _n(num v) {
  if (v is int) return '$v';
  final r = double.parse(v.toStringAsPrecision(10));
  if (!r.isFinite) return '$r';
  if (r == 0 || (r.abs() >= 1e-4 && r.abs() < 1e7)) {
    final s = r.toString();
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
  final parts = r.toStringAsExponential(9).split('e');
  var mantissa = parts[0];
  if (mantissa.contains('.')) {
    mantissa = mantissa.replaceFirst(RegExp(r'0+$'), '');
    if (mantissa.endsWith('.')) {
      mantissa = mantissa.substring(0, mantissa.length - 1);
    }
  }
  return '${mantissa}e${parts[1].replaceFirst('+', '')}';
}

/// Числа вне таблиц. Ключ — то, как число названо в коде: по нему его и
/// искать, когда строка отпечатка поедет.
Map<String, num> _constants() => {
      'kSortGainPerSecond': kSortGainPerSecond,
      'kSortBurnPerSecond': kSortBurnPerSecond,
      'kSortDecayPerSecond': kSortDecayPerSecond,
      'kEventPeriod, с': kEventPeriod.inMilliseconds / 1000,
      'kEventWindow, с': kEventWindow.inMilliseconds / 1000,
      'kAchievementMultiplier': kAchievementMultiplier,
      'kRowMultiplier': kRowMultiplier,
      'Market.swing': Market.swing,
      // Серия множит всё производство активного игрока, а числа окна решают,
      // сколько её удаётся держать и как быстро растёт сорт: это доход, хоть
      // и живёт в интерфейсе.
      'HeatController.risePerSecond': HeatController.risePerSecond,
      'HeatController.decayPerSecond': HeatController.decayPerSecond,
      'HeatController.seriesGraceSeconds': HeatController.seriesGraceSeconds,
      'HeatController.seriesFadeSeconds': HeatController.seriesFadeSeconds,
      'HeatController.seriesFillSeconds': HeatController.seriesFillSeconds,
      'HeatController.maxSeriesMultiplier': HeatController.maxSeriesMultiplier,
      'HeatController.purchaseStoke': HeatController.purchaseStoke,
      'HeatController.baseWindowSize': HeatController.baseWindowSize,
      'HeatController.maxWindowSize': HeatController.maxWindowSize,
      'HeatController.windowSpeed': HeatController.windowSpeed,
      'HeatController.windowMin': HeatController.windowMin,
      'HeatController.overheatAt': HeatController.overheatAt,
      // Что короче порога — производство, что длиннее — поток: порог делит
      // время игрока между ними.
      'GameNotifier.afkGap, с': GameNotifier.afkGap.inMilliseconds / 1000,
    };

/// Формулы, снятые в контрольных точках.
///
/// Часть чисел экономики вписана прямо в код формул: ×2 за рубеж, +10 %
/// «Семейного подряда» от 25 штук, периоды и веса волны рынка, логарифм по
/// основанию 2 в мудрости, «гость уносит сорт». Константой их не назвать,
/// поэтому отпечаток берёт результат: поменяй такое число — поменяется
/// значение в одной из точек ниже.
///
/// Точки выбраны мимо границ округления вниз: мудрость в ровно 1·первой —
/// это `log(2)/ln2`, который на одной платформе даёт 1, а на другой может
/// дать 0.9999999999999999 и после `floor` — ноль.
Map<String, num> _formulas() {
  const engine = GameEngine();
  final b = Balance.current;
  final gens = kGenerators;
  final ups = kUpgrades;
  DateTime at(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

  UpgradesState bought(bool Function(Upgrade u) which) => UpgradesState(items: [
        for (final u in ups) which(u) ? u.copyWith(purchased: true) : u,
      ]);
  final none = bought((_) => false);
  final everything = bought((_) => true);
  final links = bought((u) =>
      u.target == UpgradeTarget.synergyCoupling ||
      u.target == UpgradeTarget.synergyResonance);
  final tanks = bought((u) => u.target == UpgradeTarget.tankCapacity);
  final quality = bought((u) => u.target == UpgradeTarget.quality);

  // Пробный гараж: у первых ступеней разные количества, чтобы сработали
  // рубежи и обе связки. «Семейный подряд» считает аппараты от 25 штук —
  // поэтому 25 есть, а 24 нет; «Наставник» растит «Дедова» от банок.
  const counts = [30, 25, 24, 12, 5, 1];
  final garage = GeneratorsState(items: [
    for (var i = 0; i < gens.length; i++)
      gens[i].copyWith(ownedCount: i < counts.length ? counts[i] : 0),
  ]);
  final wise = PrestigeState(claimedMl: 5 * b.firstWisdomMl);
  final allGoals = AchievementsState(unlocked: {
    for (final row in kAchievementRows)
      for (final a in row.items) a.id,
  });
  final firstRow = AchievementsState(unlocked: {
    for (final a in kAchievementRows.first.items) a.id,
  });

  // Литр лучшего сорта при всём качестве — одна сделка с каждым.
  final sale = GameState.initial(
    initialGenerators: gens,
    initialUpgrades: quality.items,
    lastUpdateTime: at(0),
  ).copyWith(
    resources: const ResourcesState(ml: 1000),
    sort: SortState(index: kSorts.length - 1),
  );

  final start = GameState.initial(
    initialGenerators: startingGenerators(gens),
    initialUpgrades: ups,
    flux: const FluxState(seconds: 100),
    lastUpdateTime: at(0),
  );
  final ticked = engine.processTick(start, at(10), heatMultiplier: 2, speed: 3);
  final asleep = start.copyWith(flux: const FluxState());
  const flux = FluxState(rateLevel: 3, bankLevel: 2);

  // Кто из гостей сколько раз приходит за неделю. Неделя — с понедельника
  // 5 января 2026 года, произвольного, но зафиксированного навсегда.
  final week = {for (final e in kGarageEvents) e.id: 0};
  final monday = DateTime.utc(2026, 1, 5);
  final slots =
      const Duration(days: 7).inMilliseconds ~/ kEventPeriod.inMilliseconds;
  for (var i = 0; i < slots; i++) {
    final guest = eventAt(monday.add(kEventPeriod * i));
    if (guest != null) week[guest.event.id] = week[guest.event.id]! + 1;
  }

  return {
    for (final s in const [0, 50, 150, 300, 450, 600, 1000, 3000])
      'Market.wave(t=$s с)': Market.wave(at(s)),
    for (final k in const [0.5, 1.5, 2.5, 5.0, 10.0, 100.0, 1e4])
      'PrestigeState.wisdomFor(${_n(k)}·firstWisdomMl)':
          PrestigeState.wisdomFor(k * b.firstWisdomMl),
    'PrestigeState(всего 5·firstWisdomMl).nextWisdomAtMl / firstWisdomMl':
        PrestigeState(totalEverEarned: 5 * b.firstWisdomMl).nextWisdomAtMl /
            b.firstWisdomMl,
    for (final w in const [0, 1, 2, 5])
      'PrestigeState.multiplierFor($w)': PrestigeState.multiplierFor(w),
    for (final n in const [9, 10, 30, 100, 500])
      'Production.milestoneMultiplier($n)': Production.milestoneMultiplier(n),
    'Production.mlPerSecond(пробный гараж)':
        Production.mlPerSecond(garage, none, const PrestigeState()),
    'Production.mlPerSecond(пробный гараж, связки)':
        Production.mlPerSecond(garage, links, const PrestigeState()),
    'Production.mlPerSecond(пробный гараж, всё куплено, мудрость 2, все цели)':
        Production.mlPerSecond(garage, everything, wise, allGoals.multiplier),
    'Production.tankCapacity(1 мл/с)': Production.tankCapacity(none, 1),
    'Production.tankCapacity(1000 мл/с)': Production.tankCapacity(none, 1000),
    'Production.tankCapacity(1000 мл/с, весь бак)':
        Production.tankCapacity(tanks, 1000),
    'AchievementsState(первый ряд).multiplier': firstRow.multiplier,
    'AchievementsState(все цели).multiplier': allGoals.multiplier,
    'GameEngine.generatorCost(${gens.first.id}, 10 шт.)':
        engine.generatorCost(gens.first.copyWith(ownedCount: 10), at(0)),
    'GameEngine.bulkCost(${gens[1].id}, +10 к 5 шт.)':
        engine.bulkCost(gens[1].copyWith(ownedCount: 5), 10, at(0)),
    for (final buyer in [
      ...kBuyers,
      for (final e in kGarageEvents) e.asBuyer,
    ])
      'GameEngine.saleValueFor(${buyer.id}, литр лучшего сорта, всё качество, t=0)':
          engine.saleValueFor(sale, buyer, at(0)),
    'GameEngine.processTick(10 с, жар ×2, ускорение ×3): налито, мл':
        ticked.resources.ml,
    'GameEngine.processTick(10 с, жар ×2, ускорение ×3): потока ушло, с':
        start.flux.seconds - ticked.flux.seconds,
    'GameEngine.creditAfk(3 ч, копилка пуста).gained, с':
        engine.creditAfk(asleep, const Duration(hours: 3)).gained,
    'GameEngine.creditAfk(30 ч, копилка пуста).gained, с':
        engine.creditAfk(asleep, const Duration(hours: 30)).gained,
    'FluxState(rateLevel 3, bankLevel 2).minutesPerHour': flux.minutesPerHour,
    'FluxState(rateLevel 3, bankLevel 2).bankSeconds': flux.bankSeconds,
    'FluxState(rateLevel 3, bankLevel 2).rateCostSeconds': flux.rateCostSeconds,
    'FluxState(rateLevel 3, bankLevel 2).bankCostSeconds': flux.bankCostSeconds,
    'SortState(3, 0.5).dropOneStep(): ступень + прогресс':
        _sortPosition(const SortState(index: 3, progress: 0.5).dropOneStep()),
    'SortState().advance(2.5): ступень + прогресс':
        _sortPosition(const SortState().advance(2.5)),
    for (final g in startingGenerators(gens))
      if (g.ownedCount > 0) 'startingGenerators: ${g.id}': g.ownedCount,
    for (final w in week.entries) 'eventAt за неделю: ${w.key}': w.value,
  };
}

double _sortPosition(SortState s) => s.index + s.progress;
