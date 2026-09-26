/// Чего мы хотим от экономики — числами, а не ощущением.
///
/// Эти рамки существуют, чтобы баланс нельзя было сломать незаметно. Прошлый
/// раз он ломался именно так: каждая правка выглядела улучшением, а игра
/// целиком разваливалась за полчаса — и узнали мы об этом от человека, который
/// в неё поиграл. Теперь границы проверяются тестом при каждом изменении.
///
/// Числа — из docs/PLAN-1.0.md, раздел «Новые цели баланса»:
///
/// * **Первая мудрость — через 2,5 часа** активной игры у того, кто считает.
///   Это решение владельца, принятое вместе с потоком времени: 20 минут игры
///   и час потока в день дают первую мудрость на 2–3-й день. Не попадает —
///   крутится поток, а не эти 2,5 часа.
/// * **Окупаемость — минуты, а не часы, в каждом заходе.** Прежняя экономика
///   после первого часа вставала: множители кончались, окупаемость лучшей
///   покупки уходила к 7–10 часам. Растянуть такой заход значило заставить
///   игрока ждать.
/// * **Рывок после похмелья.** Второй заход до той же точки — 40–55 %
///   первого: при +8 % за мудрость он был всего на 20 % короче, и похмелье не
///   ощущалось наградой.
/// * **Ночь открытой вкладки не приносит мудрость тому, кто поиграл пару
///   минут.** Было 17 минут игры — и утром мудрость.
/// * **20 минут в день, остальное закрыто, весь поток тратит** — первая
///   мудрость у «считает» на 2–3-й день, у «обычного» не позже 4-го. Это
///   замысел владельца про поток времени. Промахивается — крутятся скорость
///   и копилка потока, а не экономика.
/// * **Коллайдер — портал, и до него далеко:** у «считает» 24–30 часов, у
///   обычного — не раньше 36. По дороге 10–16 похмелий, ни одного захода
///   дольше 4 часов, и следующая веха мудрости не дальше двух заходов. Без
///   вех после 12-й ступени вставала стена — вехи несут вторую половину
///   игры, а цена коллайдера ставит портал в её конец.
library;

import 'dart:math' as math;

import '../content/balance.dart';
import '../content/game_content.dart';
import 'balance_sim.dart';
import 'sim_profiles.dart';

abstract final class BalanceTargets {
  /// К этому моменту «считает» нагоняет ровно на первую мудрость — с него
  /// порог и снимается ([firstWisdomFromCurve]).
  static const firstWisdomAt = Duration(hours: 2, minutes: 30);

  /// Первая мудрость у того, кто считает.
  static const firstWisdomMin = Duration(hours: 2, minutes: 15);
  static const firstWisdomMax = Duration(hours: 2, minutes: 45);

  /// Первая мудрость у обычного игрока — не позже.
  static const firstWisdomCasualMax = Duration(hours: 4, minutes: 30);

  /// Окупаемость лучшей покупки в каждом заходе, после его 10-й минуты.
  ///
  /// Первые минуты захода не считаются: сразу после похмелья окупается всё
  /// за секунды, и эти секунды тянули бы медиану вниз, пряча стену в конце.
  static const paybackSkip = Duration(minutes: 10);
  static const paybackMedianMin = Duration(minutes: 3);
  static const paybackMedianMax = Duration(minutes: 10);
  static const paybackP90Max = Duration(minutes: 20);
  static const paybackWorstMax = Duration(minutes: 30);

  /// Сколько ступеней открыто к первой мудрости. Меньше — первый заход
  /// беден; больше — на потом ничего не остаётся.
  static const tiersAtFirstWisdomMin = 8;
  static const tiersAtFirstWisdomMax = 10;

  /// Второй заход до той же точки — доля первого.
  static const rerunMin = 0.40;
  static const rerunMax = 0.55;

  /// Когда «считает» доходит до 12-й ступени. Коллайдер (13-я) — отдельная
  /// долгая цель, его отодвигают вехи мудрости (задача 7 плана).
  static const tier12Min = Duration(hours: 10);
  static const tier12Max = Duration(hours: 14);

  /// Отрезок партии с похмельями, на котором меряется окупаемость: с запасом
  /// за верхней границей [tier12Max].
  ///
  /// Дальше 12-й ступени окупаемость не меряется. До портала лестница
  /// кончается на орбитальной, и конец каждого позднего захода — ожидание
  /// следующей мудрости: всё куплено, а следующая штука окупается часами.
  /// Стену там ловит [longestRunMax] — длина захода, а не окупаемость.
  static const marathonLength = Duration(hours: 15);

  /// Коллайдер — портал в новый мир — у того, кто считает. Раньше суток
  /// игры нельзя: портал — цель второй половины игры, а не тринадцатая
  /// ступень (docs/DECISIONS.md, «Экономика и мудрость»).
  static const portalMin = Duration(hours: 24);
  static const portalMax = Duration(hours: 30);

  /// Коллайдер у обычного игрока — не раньше. «Недели через две по два
  /// часа в день» — это и есть 36 часов с запасом на поток.
  static const portalCasualMin = Duration(hours: 36);

  /// Сколько раз «считает» ляжет спать до портала.
  static const hangoversMin = 10;
  static const hangoversMax = 16;

  /// Самый длинный заход до портала. Длиннее — стена: игрок ждёт, а не
  /// играет. Без вех заходы вырастали до 6–8 часов.
  static const longestRunMax = Duration(hours: 4);

  /// Следующая веха — не дальше стольких заходов от любого похмелья до
  /// портала.
  static const milestoneRunsMax = 2;

  /// Длина партий, на которых меряется портал: у «считает» — с запасом за
  /// [portalMax], чтобы после портала успели случиться похмелья и было видно,
  /// через сколько заходов бралась последняя веха; у «обычного» — ровно
  /// [portalCasualMin].
  static const portalHorizon = Duration(hours: 32);

  /// Сколько надо сыграть, чтобы ночь (8 ч) открытой вкладки принесла первую
  /// мудрость, — не меньше.
  static const overnightTabMin = Duration(minutes: 60);

  /// «Играет 20 минут в день, остальное время закрыто, весь поток тратит»:
  /// на какой день первая мудрость. Дни считаются с первого.
  static const dailySession = Duration(minutes: 20);
  static const dailyFirstWisdomDayMin = 2;
  static const dailyFirstWisdomDayMax = 3;
  static const dailyFirstWisdomDayCasualMax = 4;

  /// Копилка потока на старте наполняется за столько AFK — не дольше.
  static const fluxBankFillMax = Duration(hours: 6);

  /// Улучшения потока (L1): окупаемость +1 мин/ч для того, кто заходит раз
  /// в сутки, — на старте и у самого предела.
  static const fluxPaybackFirstDays = 2.0;
  static const fluxPaybackLastDays = 45.0;

  /// «Раз в сутки» доходит до часа потока за час: вкладывая весь поток — к
  /// этому дню, половину — к этому, с допуском ±20 %.
  static const fluxRateMaxDayAll = 49;
  static const fluxRateMaxDayHalf = 102;
  static const fluxRateMaxDayTolerance = 0.2;

  /// Бак: и «слишком мал» и «слишком велик» одинаково ломают игру.
  static const tankMin = Duration(minutes: 1);
  static const tankMax = Duration(minutes: 45);

  static String get summary => '''
  • первая мудрость: «считает» ${_hm(firstWisdomMin)}–${_hm(firstWisdomMax)}, «обычный» ≤ ${_hm(firstWisdomCasualMax)}
  • окупаемость в каждом заходе после ${paybackSkip.inMinutes}-й минуты: медиана ${paybackMedianMin.inMinutes}–${paybackMedianMax.inMinutes} мин, 90 % ≤ ${paybackP90Max.inMinutes} мин, худшая ≤ ${paybackWorstMax.inMinutes} мин
  • ступеней к первой мудрости: $tiersAtFirstWisdomMin–$tiersAtFirstWisdomMax из 13
  • второй заход до той же точки: ${(rerunMin * 100).round()}–${(rerunMax * 100).round()} % первого
  • 12-я ступень у «считает»: ${tier12Min.inHours}–${tier12Max.inHours} ч
  • коллайдер (портал): «считает» ${portalMin.inHours}–${portalMax.inHours} ч, «обычный» не раньше ${portalCasualMin.inHours} ч
  • до портала у «считает»: похмелий $hangoversMin–$hangoversMax, заход не длиннее ${longestRunMax.inHours} ч, следующая веха не дальше $milestoneRunsMax заходов
  • ночь открытой вкладки даёт мудрость не раньше ${overnightTabMin.inMinutes} мин игры
  • ${dailySession.inMinutes} мин в день, остальное закрыто, весь поток тратит: первая мудрость у «считает» на $dailyFirstWisdomDayMin–$dailyFirstWisdomDayMax-й день, у «обычного» не позже $dailyFirstWisdomDayCasualMax-го
  • копилка потока на старте наполняется не дольше чем за ${fluxBankFillMax.inHours} ч AFK
  • улучшения потока: окупаемость +1 мин/ч раз в сутки — ${fluxPaybackFirstDays.round()} дн на старте … ${fluxPaybackLastDays.round()} дн у предела; час в час — к дню $fluxRateMaxDayAll (весь поток) и $fluxRateMaxDayHalf (половина), ±${(fluxRateMaxDayTolerance * 100).round()} %
  • запас бака: ${tankMin.inMinutes}–${tankMax.inMinutes} мин производства''';

  static String _hm(Duration d) =>
      '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';
}

/// Сколько «считает» нагоняет к [BalanceTargets.firstWisdomAt] — это и есть
/// порог первой мудрости для такой кривой.
///
/// Порог не подбирается: 2,5 часа — решение владельца, а кривая — лестница и
/// улучшения. Поменял кривую — сними порог заново и перепиши в `kBalance`;
/// тест сверяет, что записанный не разошёлся с кривой.
///
/// До первой мудрости порог ни на что не влияет, поэтому прогон с любым
/// порогом даёт то же нагнанное.
double firstWisdomFromCurve(Balance candidate) => withBalance(candidate, () {
      const sim = BalanceSim(sampleEvery: Duration(hours: 1));
      final r = sim.run(
        PlayStyle.tryhard.withPrestige(null),
        horizon: BalanceTargets.firstWisdomAt,
      );
      return r.finalState.prestige.totalEverEarned;
    });

/// «Играет 20 минут в день, остальное время закрыто, весь поток тратит».
///
/// Тратит на пределе скорости: итог от неё не зависит, а на пределе копилка
/// точно успевает опустеть за заход. Дней — на один больше самой поздней
/// цели: промах на день виден как промах, а не как «не дождались».
DailyResult dailyWithFlux(BalanceSim sim, PlayStyle style) => daily(
      sim,
      style,
      perDay: BalanceTargets.dailySession,
      days: BalanceTargets.dailyFirstWisdomDayCasualMax + 1,
      boost: Balance.current.fluxMaxSpeed,
    );

/// Окупаемость одного захода.
class RunPayback {
  final Duration median;
  final Duration p90;
  final Duration worst;

  /// Заход доигран до похмелья. У недоигранного последнего медиана не
  /// в счёт: его длину решил конец прогона, а не игрок, и полчаса свежего
  /// захода, где всё дёшево, тянут медиану вниз. Стену в нём видно и так —
  /// по 90 % и худшей.
  final bool finished;

  const RunPayback({
    required this.median,
    required this.p90,
    required this.worst,
    required this.finished,
  });
}

/// Насколько вариант баланса промахивается мимо целей.
class Score {
  /// Первая мудрость у «считает» и у «обычного». `null` — не дождались.
  final Duration? firstWisdom;
  final Duration? firstWisdomCasual;

  final int tiersAtFirstWisdom;

  /// Окупаемость по заходам партии с похмельями. Пусто в быстрой оценке.
  final List<RunPayback> paybackByRun;

  final double? rerunShare;

  /// Когда куплена 12-я ступень. `null` — не за партию (или быстрая оценка).
  final Duration? tier12At;

  final Duration? overnightTab;

  /// «20 минут в день»: день первой мудрости у «считает» и у «обычного».
  /// `null` — не за проверенные дни (или быстрая оценка).
  final int? dailyFirstWisdomDay;
  final int? dailyFirstWisdomDayCasual;

  final Duration maxTankBuffer;

  /// Партии с похмельями до портала: «считает» на [BalanceTargets.portalHorizon],
  /// «обычный» на [BalanceTargets.portalCasualMin]. `null` — быстрая оценка.
  final MarathonResult? marathon;
  final MarathonResult? marathonCasual;

  /// Ноль — попал во всё. Чем больше, тем хуже.
  final double penalty;

  const Score({
    required this.firstWisdom,
    required this.firstWisdomCasual,
    required this.tiersAtFirstWisdom,
    required this.paybackByRun,
    required this.rerunShare,
    required this.tier12At,
    required this.overnightTab,
    this.dailyFirstWisdomDay,
    this.dailyFirstWisdomDayCasual,
    required this.maxTankBuffer,
    this.marathon,
    this.marathonCasual,
    required this.penalty,
  });

  /// Когда «считает» и «обычный» берут коллайдер. `null` — не за партию.
  Duration? get portalAt => marathon?.portalAt;
  Duration? get portalAtCasual => marathonCasual?.portalAt;

  /// Самая дальняя следующая веха, в заходах, от похмелий до портала.
  /// `null` — нечего мерить: быстрая оценка или партия кончилась раньше.
  int? get milestoneRunsWorst {
    int? worst;
    for (final r in marathon?.milestoneReach ?? const <MilestoneReach>[]) {
      final runs = r.runs;
      if (runs != null && (worst == null || runs > worst)) worst = runs;
    }
    return worst;
  }

  /// Дорожка вех кончилась раньше портала — следующей вехи не видно.
  bool get milestonesRunOut =>
      marathon?.milestoneReach.any((r) => r.next == null) ?? false;

  bool get hitsTargets => penalty == 0;
}

/// Прогнать вариант и оценить.
///
/// Считает по внимательному игроку: он быстрее всех доходит до краёв, поэтому
/// на нём раньше всего видно, что экономика поехала. «Обычный» нужен только
/// для верхней границы первой мудрости.
///
/// [quick] — только первый заход: без партии на 15 часов и без ночи. Этого
/// хватает, чтобы поймать разнос, и это в десятки раз быстрее.
///
/// [guests] — `false`: игроки не замечают гостей. Цели меряются с гостями,
/// как в игре; без них — только для сверки, насколько гости ускоряют.
Score scoreBalance(Balance candidate, {bool quick = false, bool guests = true}) {
  return withBalance(candidate, () {
    const sim = BalanceSim(sampleEvery: Duration(minutes: 1));
    final tryhard = guests ? PlayStyle.tryhard : PlayStyle.tryhard.withoutGuests;
    final casualStyle = guests ? PlayStyle.casual : PlayStyle.casual.withoutGuests;

    // Первый заход без похмелья: до первой мудрости правило похмелья ни на
    // что не влияет, а дальше смотреть незачем.
    final first = sim.start(tryhard.withPrestige(null));
    sim.play(first, BalanceTargets.firstWisdomMax * 2,
        until: (p) => p.firstPrestige != null);
    final firstWisdom = first.firstPrestige;
    final tiers = [
      for (final g in kGenerators)
        if (first.firstBuy.containsKey(g.id)) g.id,
    ].length;

    final casual = sim.start(casualStyle.withPrestige(null));
    sim.play(casual, BalanceTargets.firstWisdomCasualMax * 2,
        until: (p) => p.firstPrestige != null);

    var maxTank = Duration.zero;
    for (final c in first.timeline) {
      if (c.tankBuffer > maxTank) maxTank = c.tankBuffer;
    }

    final runs = <RunPayback>[];
    double? rerun;
    Duration? tier12;
    Duration? overnight;
    int? daily20, daily20Casual;
    MarathonResult? m, mCasual;
    if (!quick) {
      // Одна партия на всё: её первые 15 часов — та же партия, что прежняя
      // на 15 часов, поэтому окупаемость меряется по ним, как раньше.
      m = marathon(sim, tryhard, horizon: BalanceTargets.portalHorizon);
      runs.addAll(_paybackByRun(m.result, upTo: BalanceTargets.marathonLength));
      rerun = m.rerunShare;
      tier12 = m.result.firstBuy[kGenerators[11].id];
      for (final c in m.result.timeline) {
        if (c.tankBuffer > maxTank) maxTank = c.tankBuffer;
      }
      mCasual = marathon(sim, casualStyle, horizon: BalanceTargets.portalCasualMin);
      overnight = overnightThreshold(sim, tryhard, Absence.tabOpen);
      daily20 = dailyWithFlux(sim, tryhard).firstWisdomDay;
      daily20Casual = dailyWithFlux(sim, casualStyle).firstWisdomDay;
    }

    var penalty = 0.0;
    penalty += _miss(
      firstWisdom?.inSeconds.toDouble(),
      BalanceTargets.firstWisdomMin.inSeconds.toDouble(),
      BalanceTargets.firstWisdomMax.inSeconds.toDouble(),
    );
    penalty += _miss(
      casual.firstPrestige?.inSeconds.toDouble(),
      1,
      BalanceTargets.firstWisdomCasualMax.inSeconds.toDouble(),
    );
    if (tiers > BalanceTargets.tiersAtFirstWisdomMax) {
      penalty += (tiers - BalanceTargets.tiersAtFirstWisdomMax) * 0.5;
    }
    if (tiers < BalanceTargets.tiersAtFirstWisdomMin) {
      penalty += (BalanceTargets.tiersAtFirstWisdomMin - tiers) * 0.5;
    }
    if (maxTank > BalanceTargets.tankMax) {
      penalty += _ratio(maxTank.inSeconds / BalanceTargets.tankMax.inSeconds);
    }
    if (!quick) {
      for (final r in runs) {
        if (r.finished) {
          penalty += _miss(
            r.median.inSeconds.toDouble(),
            BalanceTargets.paybackMedianMin.inSeconds.toDouble(),
            BalanceTargets.paybackMedianMax.inSeconds.toDouble(),
          );
        }
        penalty += _ratio(r.p90.inSeconds / BalanceTargets.paybackP90Max.inSeconds);
        penalty += _ratio(r.worst.inSeconds / BalanceTargets.paybackWorstMax.inSeconds);
      }
      penalty += _miss(rerun, BalanceTargets.rerunMin, BalanceTargets.rerunMax);
      penalty += _miss(
        tier12?.inSeconds.toDouble(),
        BalanceTargets.tier12Min.inSeconds.toDouble(),
        BalanceTargets.tier12Max.inSeconds.toDouble(),
      );
      penalty += _miss(
        overnight?.inSeconds.toDouble(),
        BalanceTargets.overnightTabMin.inSeconds.toDouble(),
        double.infinity,
      );
      penalty += _miss(
        daily20?.toDouble(),
        BalanceTargets.dailyFirstWisdomDayMin.toDouble(),
        BalanceTargets.dailyFirstWisdomDayMax.toDouble(),
      );
      penalty += _miss(
        daily20Casual?.toDouble(),
        1,
        BalanceTargets.dailyFirstWisdomDayCasualMax.toDouble(),
      );
      penalty += _miss(
        m!.portalAt?.inSeconds.toDouble(),
        BalanceTargets.portalMin.inSeconds.toDouble(),
        BalanceTargets.portalMax.inSeconds.toDouble(),
      );
      // «Обычный» не взял портал за всю партию — это и есть попадание.
      final casualPortal = mCasual!.portalAt;
      if (casualPortal != null) {
        penalty += _miss(
          casualPortal.inSeconds.toDouble(),
          BalanceTargets.portalCasualMin.inSeconds.toDouble(),
          double.infinity,
        );
      }
      penalty += _miss(
        m.hangoversBeforePortal.toDouble(),
        BalanceTargets.hangoversMin.toDouble(),
        BalanceTargets.hangoversMax.toDouble(),
      );
      penalty += _ratio(
          (m.longestRunBeforePortal ?? Duration.zero).inSeconds / BalanceTargets.longestRunMax.inSeconds);
      for (final r in m.milestoneReach) {
        if (r.next == null) {
          penalty += 4.0; // дорожка кончилась раньше портала
        } else if (r.runs != null) {
          penalty += _ratio(r.runs! / BalanceTargets.milestoneRunsMax);
        }
      }
    }

    return Score(
      firstWisdom: firstWisdom,
      firstWisdomCasual: casual.firstPrestige,
      tiersAtFirstWisdom: tiers,
      paybackByRun: runs,
      rerunShare: rerun,
      tier12At: tier12,
      overnightTab: overnight,
      dailyFirstWisdomDay: daily20,
      dailyFirstWisdomDayCasual: daily20Casual,
      maxTankBuffer: maxTank,
      marathon: m,
      marathonCasual: mCasual,
      penalty: penalty,
    );
  });
}

/// Окупаемость по заходам: от похмелья до похмелья, без первых
/// [BalanceTargets.paybackSkip] каждого. Последний, недоигранный заход
/// тоже входит — стена в нём так же видна игроку (см. [RunPayback.finished]).
///
/// [upTo] — считать партию кончившейся на этой отметке: заход, который её
/// пересекает, — недоигранный последний.
List<RunPayback> _paybackByRun(SimResult r, {required Duration upTo}) {
  final bounds = [Duration.zero, ...r.hangovers.where((h) => h < upTo)];
  final out = <RunPayback>[];
  for (var i = 0; i < bounds.length; i++) {
    final from = bounds[i] + BalanceTargets.paybackSkip;
    final to = i + 1 < bounds.length ? bounds[i + 1] : null;
    final seconds = [
      for (final c in r.timeline)
        if (c.at >= from && c.at < (to ?? upTo) && c.payback != null)
          c.payback!.inMilliseconds / 1000.0,
    ];
    if (seconds.isEmpty) continue;
    seconds.sort();
    Duration at(double q) => Duration(
        seconds: seconds[math.min(seconds.length - 1, (q * seconds.length).floor())].round());
    out.add(RunPayback(
      median: Duration(seconds: median(seconds).round()),
      p90: at(0.9),
      worst: Duration(seconds: seconds.last.round()),
      finished: to != null,
    ));
  }
  return out;
}

/// Промах мимо коридора — в двоичных порядках.
///
/// Логарифм, а не отношение: промах вдвое и промах в тысячу раз обязаны
/// отличаться, но не настолько, чтобы один плохой вариант затмил сравнение
/// всех остальных.
double _miss(double? value, double lo, double hi) {
  if (value == null) return 4.0; // не случилось вовсе
  if (value <= 0) return 4.0;
  if (value < lo) return _ratio(lo / value);
  if (value > hi) return _ratio(value / hi);
  return 0;
}

double _ratio(double ratio) =>
    ratio <= 1 ? 0 : math.log(ratio) / math.ln2;
