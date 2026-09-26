/// Профили с отсутствием: как играют те, кто не сидит в игре круглые сутки.
///
/// ## Зачем
///
/// Прежний симулятор знал три портрета, и все три сидели в открытой игре
/// 100 % времени. «Фоновый» — это не «зашёл и ушёл», а «открыто круглосуточно,
/// внимание 10 %». Поэтому он проглядел главное про AFK: 17 минут игры плюс
/// ночь открытой вкладки давали первую мудрость, при честных 37 минутах, — и
/// узнали об этом от живого игрока (docs/PLAN-1.0.md, раздел 2).
///
/// Здесь партия режется на куски игры и отсутствия. Все профили построены из
/// двух действий [BalanceSim.play] и [BalanceSim.away], поэтому то, что
/// меняет смысл отсутствия (поток времени, задача 5), меняет их все сразу.
library;

import '../content/game_content.dart';
import '../core/game_serializer.dart';
import '../engine/game_engine.dart';
import '../models/prestige_state.dart';
import 'balance_sim.dart';

const _day = Duration(days: 1);

/// Поиграл [playFor] с нуля и ушёл на [awayFor].
SimResult leaveAfter(
  BalanceSim sim,
  PlayStyle style, {
  required Duration playFor,
  required Duration awayFor,
  required Absence how,
}) {
  final p = sim.start(style);
  sim.play(p, playFor);
  sim.away(p, awayFor, how);
  return p.result;
}

/// Сколько активной игры стоит отсутствие [awayFor], начатое с [from].
///
/// Две дороги из одного места: игрок уходит — или остаётся и играет, пока не
/// нагонит столько же. Второе время и есть цена отсутствия в минутах игры.
/// Остающийся не ложится спать: похмелье не уменьшает нагнанное, но
/// сбрасывает производство, и сравнение стало бы сравнением правил похмелья.
///
/// `null` — за [limit] игры столько не нагнать.
Duration? activeEquivalent(
  BalanceSim sim,
  SimParty from,
  Duration awayFor,
  Absence how, {
  Duration limit = const Duration(hours: 6),
}) {
  final gone = from.fork();
  sim.away(gone, awayFor, how);
  final target = gone.state.prestige.totalEverEarned;

  final stays = from.fork(style: from.style.withPrestige(null));
  sim.play(stays, limit, until: (p) => p.state.prestige.totalEverEarned >= target);
  if (stays.state.prestige.totalEverEarned < target) return null;
  return stays.played - from.played;
}

/// Сколько надо сыграть с нуля, чтобы после [night] отсутствия была первая
/// мудрость. С точностью до минуты.
///
/// Это цель раздела 2 плана: ночь открытой вкладки не должна приносить
/// мудрость тому, кто поиграл пару минут. Без отсутствия ответ — время
/// первого похмелья; чем меньше ответ, тем больше делает за игрока ночь.
Duration overnightThreshold(
  BalanceSim sim,
  PlayStyle style,
  Absence how, {
  Duration night = const Duration(hours: 8),
}) {
  // Снимки каждую минуту до первой мудрости. Дальше искать незачем: там
  // мудрость есть и без ночи.
  final p = sim.start(style.withPrestige(null));
  final snaps = <SimParty>[p.fork()];
  while (!p.state.prestige.canPrestige) {
    sim.play(p, const Duration(minutes: 1));
    snaps.add(p.fork());
  }

  bool enough(int minutes) {
    final probe = snaps[minutes].fork();
    sim.away(probe, night, how);
    return probe.state.prestige.potentialWisdom > 0;
  }

  // Больше играл — больше производство к ночи, поэтому ответ монотонен и
  // ищется делением пополам.
  var lo = 0, hi = snaps.length - 1;
  while (lo < hi) {
    final mid = (lo + hi) ~/ 2;
    if (enough(mid)) {
      hi = mid;
    } else {
      lo = mid + 1;
    }
  }
  return Duration(minutes: lo);
}

/// Итог профиля «раз в день».
class DailyResult {
  final PlayStyle style;
  final Duration perDay;
  final Absence how;

  /// На какой день (с первого) появилась первая мудрость. `null` — не за
  /// эти дни.
  final int? firstWisdomDay;

  /// Мудрость, заслуженная историей, к концу каждого дня — с тем, что ещё
  /// не забрано похмельем.
  final List<int> wisdomByDay;

  final SimResult result;

  const DailyResult({
    required this.style,
    required this.perDay,
    required this.how,
    required this.firstWisdomDay,
    required this.wisdomByDay,
    required this.result,
  });
}

/// Заходит раз в день на [perDay], остальные сутки его нет.
///
/// [boost] — с какой скоростью он тратит поток, пока играет. Итог от
/// скорости не зависит, важно только успеть потратить копилку за заход: час
/// потока за 20 минут — это ×4 и выше.
DailyResult daily(
  BalanceSim sim,
  PlayStyle style, {
  required Duration perDay,
  int days = 14,
  Absence how = Absence.closed,
  double boost = 1.0,
}) {
  final p = sim.start(style)..boost = boost;
  final byDay = <int>[];
  for (var d = 0; d < days; d++) {
    sim.play(p, perDay);
    sim.away(p, _day - perDay, how);
    byDay.add(p.state.prestige.potentialWisdom);
  }
  final first = p.firstPrestige;
  return DailyResult(
    style: style,
    perDay: perDay,
    how: how,
    firstWisdomDay: first == null ? null : first.inDays + 1,
    wisdomByDay: byDay,
    result: p.result,
  );
}

/// Через сколько заходов после похмелья берётся следующая веха.
///
/// [wisdom] — мудрость в начале захода, [next] — порог следующей вехи
/// (`null` — дорожка кончилась), [runs] — через сколько похмелий мудрость
/// до него дошла (`null` — партия кончилась раньше, чем стало ясно; не
/// дошла вовсе — число оставшихся похмелий плюс один).
typedef MilestoneReach = ({int wisdom, int? next, int? runs});

/// Итог долгой игры с похмельями.
class MarathonResult {
  final SimResult result;

  /// Сколько длилась партия.
  final Duration horizon;

  /// Длины заходов, от похмелья до похмелья. Последний, недоигранный, не
  /// входит: его длину решил конец прогона, а не игрок.
  final List<Duration> runs;

  /// Второй заход до той же точки — доля первого: за сколько во втором
  /// нагнано столько же, сколько за весь первый. Это «рывок» раздела 4 плана
  /// (цель — 0.40–0.55). `null` — до второго захода не дошли или за два
  /// первых столько не нагнали.
  final double? rerunShare;

  /// Следующая веха от начала каждого захода до портала — первый заход
  /// начинается с нуля мудрости.
  final List<MilestoneReach> milestoneReach;

  const MarathonResult({
    required this.result,
    required this.horizon,
    required this.runs,
    required this.rerunShare,
    this.milestoneReach = const [],
  });

  Duration? get longestRun =>
      runs.isEmpty ? null : runs.reduce((a, b) => a > b ? a : b);

  /// Когда куплен коллайдер — портал в новый мир. `null` — не за партию.
  Duration? get portalAt => result.firstBuy[kGeneratorNames.last.id];

  /// Сколько раз игрок лёг спать до портала. Не дошёл — за всю партию.
  int get hangoversBeforePortal {
    final at = portalAt;
    return at == null
        ? result.hangovers.length
        : result.hangovers.where((h) => h < at).length;
  }

  /// Самый длинный заход до портала — вместе с тем, в котором портал взят,
  /// до самой покупки. Не дошёл — вместе с недоигранным последним: стена
  /// перед порталом — это именно он.
  Duration? get longestRunBeforePortal {
    final end = portalAt ?? horizon;
    var from = Duration.zero;
    Duration? longest;
    for (final h in [...result.hangovers.where((h) => h < end), end]) {
      final run = h - from;
      if (longest == null || run > longest) longest = run;
      from = h;
    }
    return longest;
  }

  /// Мудрость на отметке [at] — забранная, как на экране.
  int wisdomAt(Duration at) {
    var w = 0;
    for (final c in result.timeline) {
      if (c.at > at) break;
      w = c.wisdom;
    }
    return w;
  }
}

/// Играет [horizon] подряд и ложится спать по своему правилу.
MarathonResult marathon(
  BalanceSim sim,
  PlayStyle style, {
  Duration horizon = const Duration(hours: 30),
}) {
  final p = sim.start(style);
  SimParty? afterFirst;
  sim.play(p, horizon, until: (p) {
    if (afterFirst == null && p.hangovers.length == 1) afterFirst = p.fork();
    return false;
  });

  final runs = <Duration>[];
  var from = Duration.zero;
  for (final h in p.hangovers) {
    runs.add(h - from);
    from = h;
  }

  double? share;
  final second = afterFirst;
  if (second != null) {
    // Сразу после похмелья claimedMl — всё, что нагнано в первом заходе.
    final firstEarned = second.state.prestige.claimedMl;
    final firstRun = runs.first;
    final rerun = second.fork(style: style.withPrestige(null));
    sim.play(
      rerun,
      firstRun * 2,
      until: (q) => q.state.prestige.totalEverEarned - firstEarned >= firstEarned,
    );
    final reached = rerun.state.prestige.totalEverEarned - firstEarned >= firstEarned;
    if (reached) {
      share = (rerun.played - second.played).inSeconds / firstRun.inSeconds;
    }
  }

  final r = p.result;
  return MarathonResult(
    result: r,
    horizon: horizon,
    runs: runs,
    rerunShare: share,
    milestoneReach: _milestoneReach(r),
  );
}

/// Следующая веха от начала каждого захода до портала — через сколько
/// похмелий она взята. Считается по действующему балансу, поэтому здесь, в
/// прогоне, а не потом из результата.
List<MilestoneReach> _milestoneReach(SimResult r) {
  final portal = r.firstBuy[kGeneratorNames.last.id];
  final after = r.hangoverWisdom;
  final out = <MilestoneReach>[];
  // Заход k начинается с нуля (k = 0) или после похмелья k − 1.
  for (var k = 0; k <= after.length; k++) {
    final startsAt = k == 0 ? Duration.zero : r.hangovers[k - 1];
    if (portal != null && startsAt >= portal) break;
    final wisdom = k == 0 ? 0 : after[k - 1];
    final next = PrestigeState.nextMilestoneFor(wisdom)?.wisdom;
    int? runs;
    if (next != null) {
      for (var j = k; j < after.length; j++) {
        if (after[j] >= next) {
          runs = j - k + 1;
          break;
        }
      }
      // Не дошёл за все оставшиеся похмелья — известно только, что больше.
      // Если их хотя бы два, этого хватает для промаха; меньше — партия
      // кончилась раньше, чем стало ясно.
      if (runs == null && after.length - k >= 2) runs = after.length - k + 1;
    }
    out.add((wisdom: wisdom, next: next, runs: runs));
  }
  return out;
}

/// Итог вложений в поток: на какой день чего достиг.
class FluxInvestResult {
  /// Скорость дошла до 24 мин/ч — «сладкая точка»: копилка на сутки
  /// наполняется за 2,5 дня, дальше скорость окупается неделями.
  final int? rate24Day;

  /// Копилка выросла до предела.
  final int? bankMaxDay;

  /// Скорость дошла до предела — час потока за час.
  final int? rateMaxDay;

  const FluxInvestResult({this.rate24Day, this.bankMaxDay, this.rateMaxDay});
}

/// Заходит раз в [every] и вкладывает в улучшения потока долю [share]
/// начисленного; остальное тратит на ускорение.
///
/// Покупает то, что нужно: копилку — когда поток за отлучку в неё не
/// влезает или следующая скорость дороже всей копилки; иначе скорость.
/// Считается только поток, без гаража: улучшения потока покупаются за
/// поток, и остальная игра на них не влияет.
FluxInvestResult fluxInvestor({
  Duration every = _day,
  double share = 1.0,
  int maxDays = 400,
  GameEngine engine = const GameEngine(),
}) {
  final at = DateTime.utc(2026, 1, 1);
  var s = newGame(content: kGenerators, upgrades: kUpgrades, now: at);
  int? rate24, bankMax, rateMax;
  final hours = every.inMinutes / 60;
  for (var visit = 1; visit * hours <= maxDays * 24; visit++) {
    final credited = engine.creditAfk(s, every);
    s = credited.state;
    final burned = credited.gained * (1 - share);
    s = s.copyWith(flux: s.flux.copyWith(seconds: s.flux.seconds - burned));

    while (true) {
      final f = s.flux;
      final wantBank = !f.bankMaxed &&
          (f.earnedFor(every.inSeconds.toDouble()) >= f.bankSeconds ||
              f.rateCostSeconds > f.bankSeconds ||
              f.rateMaxed);
      final next = wantBank ? engine.buyFluxBank(s) : engine.buyFluxRate(s);
      if (identical(next, s)) break;
      s = next;
    }

    final day = (visit * hours / 24).ceil();
    if (rate24 == null && s.flux.minutesPerHour >= 24) rate24 = day;
    if (bankMax == null && s.flux.bankMaxed) bankMax = day;
    if (rateMax == null && s.flux.rateMaxed) rateMax = day;
    if (rateMax != null && bankMax != null) break;
  }
  return FluxInvestResult(rate24Day: rate24, bankMaxDay: bankMax, rateMaxDay: rateMax);
}
