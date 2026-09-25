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
DailyResult daily(
  BalanceSim sim,
  PlayStyle style, {
  required Duration perDay,
  int days = 14,
  Absence how = Absence.closed,
}) {
  final p = sim.start(style);
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

/// Итог долгой игры с похмельями.
class MarathonResult {
  final SimResult result;

  /// Длины заходов, от похмелья до похмелья. Последний, недоигранный, не
  /// входит: его длину решил конец прогона, а не игрок.
  final List<Duration> runs;

  /// Второй заход до той же точки — доля первого: за сколько во втором
  /// нагнано столько же, сколько за весь первый. Это «рывок» раздела 4 плана
  /// (цель — 0.40–0.55). `null` — до второго захода не дошли или за два
  /// первых столько не нагнали.
  final double? rerunShare;

  const MarathonResult({required this.result, required this.runs, required this.rerunShare});

  Duration? get longestRun =>
      runs.isEmpty ? null : runs.reduce((a, b) => a > b ? a : b);

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

  return MarathonResult(result: p.result, runs: runs, rerunShare: share);
}
