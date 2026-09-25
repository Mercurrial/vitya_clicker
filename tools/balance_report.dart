/// Отчёт по балансу: прогоняет партии и печатает таблицы.
///
/// Запуск:
///   dart run tools/balance_report.dart          # два часа игры
///   dart run tools/balance_report.dart 8        # восемь часов
///
/// Читать так:
///   ОКУП   — за сколько окупится лучшая доступная покупка. Это главная цифра.
///            Держится около минуты — экономика здорова. Валится к нулю —
///            покупки бесплатны, игра идёт вразнос. Растёт — игра встала.
///   ТОП%   — какую долю дохода даёт сильнейший аппарат. Под 100% значит, что
///            остальные превратились в декорацию.
///
/// Вторая половина — профили с отсутствием (lib/sim/sim_profiles.dart). Их
/// длина не зависит от аргумента: ночь — 8 часов, сутки — сутки. В конце —
/// цели баланса с числами. Весь отчёт идёт несколько минут.
library;

import 'dart:io';

import 'package:idle_game/content/balance.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/sim/balance_sim.dart';
import 'package:idle_game/sim/balance_targets.dart';
import 'package:idle_game/sim/sim_profiles.dart';

void main(List<String> args) {
  final hours = args.isEmpty ? 2 : int.tryParse(args.first) ?? 2;
  final horizon = Duration(hours: hours);
  const sim = BalanceSim();

  stdout.writeln('ВИТЯ ГОНИТ — отчёт по балансу, $hours ч игрового времени\n');

  final results = [
    for (final style in PlayStyle.all) sim.run(style, horizon: horizon),
  ];

  for (final r in results) {
    _printRun(r);
  }

  _printLadder(results);

  const players = [PlayStyle.tryhard, PlayStyle.casual];
  _printAway(sim, players);
  _printOvernight(sim, players);
  _printDaily(sim, players);
  _printFlux();
  final marathons = _printMarathon(sim, players);

  // Мёртвый контент — после партии на 30 часов: улучшения идут вдоль всей
  // лестницы, и старшие за несколько часов не купит никто. Без неё раздел
  // показывал бы полсписка, который на деле покупается.
  _printDeadContent([...results, ...marathons]);
  _printTargets();
}

void _printRun(SimResult r) {
  stdout.writeln('─' * 76);
  stdout.writeln('ИГРОК: ${r.style.name}  '
      '(${r.style.tapsPerMinute.toStringAsFixed(0)} нажатий/мин, '
      'жар ×${r.style.heat}, внимание ${(r.style.attention * 100).round()}%, '
      'покупает: ${r.style.rule.name})');
  stdout.writeln('─' * 76);

  stdout.writeln('  ВРЕМЯ     МЛ/С       ₽/С        ОКУП    БАК     ТОП%  МУДР   ВСЕГО  ЛУЧШАЯ ПОКУПКА');

  // Печатаем не каждую минуту, а по разрежённой сетке: таблица должна
  // помещаться в экран, иначе её никто не прочитает.
  final stride = (r.timeline.length / 14).ceil().clamp(1, 1000);
  for (var i = 0; i < r.timeline.length; i += stride) {
    final c = r.timeline[i];
    stdout.writeln(
      '  ${formatDuration(c.at).padLeft(6)}  '
      '${formatBig(c.mlPerSecond).padLeft(9)}  '
      '${formatBig(c.revenuePerSecond).padLeft(9)}  '
      '${formatDuration(c.payback).padLeft(7)}  '
      '${formatDuration(c.tankBuffer).padLeft(6)}  '
      '${(c.topGeneratorShare * 100).toStringAsFixed(0).padLeft(5)}  '
      '${c.wisdom.toString().padLeft(4)}  '
      '${formatBig(c.lifetimeMl).padLeft(6)}  '
      '${c.bestBuy ?? '—'}',
    );
  }

  final paybacks = [
    for (final c in r.timeline)
      if (c.payback != null) c.payback!.inMilliseconds / 1000.0,
  ];

  stdout.writeln('');
  stdout.writeln('  Первое похмелье:  ${formatDuration(r.firstPrestige)}');
  stdout.writeln('  Похмелий за партию: ${r.prestiges}');
  stdout.writeln('  Продаж:           ${r.sales}');
  stdout.writeln('  Окупаемость:      медиана ${formatDuration(
    Duration(seconds: median(paybacks).round()),
  )}, размах ×${spread(paybacks).toStringAsFixed(0)}');
  stdout.writeln('  Перелив мимо бака: ${formatBig(r.overflowedMl)} мл');
  stdout.writeln('  Не дошёл до:      ${r.unreached.isEmpty ? '—' : r.unreached.join(', ')}');
  stdout.writeln('');
}

/// Лестница аппаратов: когда до какого доходят руки.
void _printLadder(List<SimResult> results) {
  stdout.writeln('─' * 76);
  stdout.writeln('ЛЕСТНИЦА: когда куплен первый экземпляр');
  stdout.writeln('─' * 76);
  stdout.write('  ${'АППАРАТ'.padRight(26)}');
  for (final r in results) {
    stdout.write(r.style.name.padLeft(12));
  }
  stdout.writeln('');

  for (final g in kGenerators) {
    stdout.write('  ${g.name.padRight(26)}');
    for (final r in results) {
      stdout.write(formatDuration(r.firstBuy[g.id]).padLeft(12));
    }
    stdout.writeln('');
  }
  stdout.writeln('');
}

/// Контент, до которого никто не дотянулся, — это выброшенная работа.
void _printDeadContent(List<SimResult> results) {
  stdout.writeln('─' * 76);
  stdout.writeln('МЁРТВЫЙ КОНТЕНТ: улучшения, не купленные НИ ОДНИМ игроком, в том числе за 30 ч');
  stdout.writeln('─' * 76);

  final dead = <String>{for (final u in kUpgrades) u.id};
  for (final r in results) {
    dead.removeWhere((id) => r.upgradeBought.containsKey(id));
  }

  if (dead.isEmpty) {
    stdout.writeln('  Нет — всё когда-нибудь покупается.');
  } else {
    for (final id in dead) {
      final u = kUpgrades.firstWhere((x) => x.id == id);
      stdout.writeln('  ${u.name.padRight(34)} ${formatBig(u.cost).padLeft(10)} ₽');
    }
  }
  stdout.writeln('');
}

void _header(String title) {
  stdout.writeln('─' * 76);
  stdout.writeln(title);
  stdout.writeln('─' * 76);
}

String _minutes(Duration? d) => d == null ? '> 6 ч' : '${d.inMinutes} мин';

/// Сутки без игрока — в минутах активной игры с того же места.
///
/// Закрытая игра не гонит — она копит поток, и минута потока — минута
/// производства, когда его потратят. Поэтому для неё показан поток.
void _printAway(BalanceSim sim, List<PlayStyle> players) {
  _header('СУТКИ ОТСУТСТВИЯ — сколько это минут активной игры');
  stdout.writeln('  ${'игрок'.padRight(9)} ${'откуда'.padRight(24)} ${'закрыто, поток'.padLeft(15)}  ${'вкладка'.padLeft(9)}');
  for (final style in players) {
    final spots = <(String, SimParty)>[];
    for (final m in [10, 30]) {
      final p = sim.start(style);
      sim.play(p, Duration(minutes: m));
      spots.add(('с нуля +$m мин', p));
    }
    for (final m in [2, 30]) {
      final p = sim.start(style);
      sim.play(p, const Duration(hours: 30), until: (p) => p.hangovers.isNotEmpty);
      if (p.hangovers.isEmpty) continue;
      sim.play(p, Duration(minutes: m));
      spots.add(('1-е похмелье +$m мин', p));
    }
    for (final (label, p) in spots) {
      final gone = p.fork();
      sim.away(gone, const Duration(days: 1), Absence.closed);
      final flux = Duration(seconds: (gone.state.flux.seconds - p.state.flux.seconds).round());
      final tab = activeEquivalent(sim, p, const Duration(days: 1), Absence.tabOpen);
      stdout.writeln('  ${style.name.padRight(9)} ${label.padRight(24)} '
          '${_minutes(flux).padLeft(15)}  ${_minutes(tab).padLeft(9)}');
    }
  }
  stdout.writeln('');
}

/// Сколько сыграть с нуля, чтобы ночь принесла первую мудрость.
void _printOvernight(BalanceSim sim, List<PlayStyle> players) {
  // Ночь закрытой игры мудрости не приносит: она копит поток, а не самогон.
  _header('НОЧЬ (8 ч) ОТКРЫТОЙ ВКЛАДКИ — сколько сыграть до неё, чтобы утром была мудрость');
  stdout.writeln('  ${'игрок'.padRight(9)} ${'без ночи'.padLeft(9)}  ${'вкладка'.padLeft(9)}');
  for (final style in players) {
    final alone = sim.run(style.withPrestige(null), horizon: const Duration(hours: 8));
    final tab = overnightThreshold(sim, style, Absence.tabOpen);
    stdout.writeln('  ${style.name.padRight(9)} ${formatClock(alone.firstPrestige).padLeft(9)}  '
        '${_minutes(tab).padLeft(9)}');
  }
  stdout.writeln('');
}

/// Заходит раз в день, остальное время игра закрыта. Поток либо не
/// тратит, либо тратит весь на пределе скорости — итог от скорости не
/// зависит, лишь бы копилка успевала опустеть за заход.
void _printDaily(BalanceSim sim, List<PlayStyle> players) {
  _header('РАЗ В ДЕНЬ, остальное время закрыто — 14 дней');
  stdout.writeln('  ${'игрок'.padRight(9)} ${'в день'.padLeft(7)}  ${'поток'.padRight(11)} '
      '${'1-я мудрость'.padLeft(13)}  ${'мудрость к д7 / д14'.padLeft(20)}  похмелий');
  final speed = kBalance.fluxMaxSpeed;
  for (final style in players) {
    for (final (m, boost) in [(20, 1.0), (20, speed), (60, speed)]) {
      final r = daily(sim, style, perDay: Duration(minutes: m), boost: boost);
      final first = r.firstWisdomDay == null ? '> 14 дн' : '${r.firstWisdomDay}-й день';
      final how = boost > 1 ? 'тратит ×${boost.round()}' : 'не тратит';
      stdout.writeln('  ${style.name.padRight(9)} ${'$m мин'.padLeft(7)}  ${how.padRight(11)} '
          '${first.padLeft(13)}  ${'${r.wisdomByDay[6]} / ${r.wisdomByDay[13]}'.padLeft(20)}  '
          '${r.result.prestiges}');
    }
  }
  stdout.writeln('');
}

/// Улучшения потока: кто вкладывает, к какому дню до чего доходит.
void _printFlux() {
  _header('УЛУЧШЕНИЯ ПОТОКА — на какой день: 24 мин/ч · копилка 24 ч · 60 мин/ч');
  for (final (label, every) in [('раз в сутки', const Duration(days: 1)), ('раз в 2,5 дня', const Duration(hours: 60))]) {
    for (final (share, how) in [(1.0, 'весь поток'), (0.5, 'половину')]) {
      final r = fluxInvestor(every: every, share: share);
      String d(int? day) => day == null ? '—' : 'д$day';
      stdout.writeln('  ${label.padRight(14)} ${how.padRight(11)} '
          '${d(r.rate24Day).padLeft(5)}  ${d(r.bankMaxDay).padLeft(5)}  ${d(r.rateMaxDay).padLeft(5)}');
    }
  }
  stdout.writeln('');
}

/// 30 часов подряд, похмелье — когда прибавка окупает заход.
List<SimResult> _printMarathon(BalanceSim sim, List<PlayStyle> players) {
  _header('30 ЧАСОВ С ПОХМЕЛЬЯМИ — ложится, когда прибавка окупает заход');
  final out = <SimResult>[];
  for (final style in players) {
    final m = marathon(sim, style);
    out.add(m.result);
    final r = m.result;
    final share = m.rerunShare;
    stdout.writeln('  ${style.name}: похмелий ${r.prestiges}, '
        'самый длинный заход ${formatDuration(m.longestRun)}, '
        'ступеней ${kGeneratorCount - r.unreached.length} из $kGeneratorCount, '
        '2-й заход до той же точки — ${share == null ? '—' : '${(share * 100).round()} %'} первого');
    stdout.writeln('    похмелья: ${r.hangovers.map(formatClock).join('  ')}');
    stdout.writeln('    заходы:   ${m.runs.map(formatDuration).join(' · ')}');
    stdout.writeln('    мудрость к 6 / 10 / 12 / 30 ч: '
        '${[6, 10, 12, 30].map((h) => m.wisdomAt(Duration(hours: h))).join(' / ')}');
  }
  stdout.writeln('');
  return out;
}

/// Цели из lib/sim/balance_targets.dart — то же, что проверяет
/// test/balance_test.dart, но с числами, а не только «прошёл / нет».
void _printTargets() {
  _header('ЦЕЛИ — то же, что проверяет test/balance_test.dart');
  final s = scoreBalance(kBalance);
  final curve = firstWisdomFromCurve(kBalance);
  String mark(bool ok) => ok ? '  ' : '✗ ';
  bool within(Duration? d, Duration lo, Duration hi) => d != null && d >= lo && d <= hi;

  stdout.writeln('${mark(within(s.firstWisdom, BalanceTargets.firstWisdomMin, BalanceTargets.firstWisdomMax))}'
      '1-я мудрость, «считает»: ${formatClock(s.firstWisdom)}');
  stdout.writeln('${mark(within(s.firstWisdomCasual, Duration.zero, BalanceTargets.firstWisdomCasualMax))}'
      '1-я мудрость, «обычный»: ${formatClock(s.firstWisdomCasual)}');
  stdout.writeln('${mark((kBalance.firstWisdomMl / curve - 1).abs() <= 0.02)}'
      'порог: в балансе ${kBalance.firstWisdomMl.toStringAsExponential(3)}, '
      'с кривой к ${formatClock(BalanceTargets.firstWisdomAt)} — ${curve.toStringAsExponential(3)} мл');
  stdout.writeln('${mark(s.tiersAtFirstWisdom >= BalanceTargets.tiersAtFirstWisdomMin && s.tiersAtFirstWisdom <= BalanceTargets.tiersAtFirstWisdomMax)}'
      'ступеней к 1-й мудрости: ${s.tiersAtFirstWisdom} из $kGeneratorCount');
  stdout.writeln('  окупаемость по заходам после ${BalanceTargets.paybackSkip.inMinutes}-й минуты, медиана / 90 % / худшая:');
  for (final (i, r) in s.paybackByRun.indexed) {
    final ok = (!r.finished ||
            (r.median >= BalanceTargets.paybackMedianMin &&
                r.median <= BalanceTargets.paybackMedianMax)) &&
        r.p90 <= BalanceTargets.paybackP90Max &&
        r.worst <= BalanceTargets.paybackWorstMax;
    stdout.writeln('${mark(ok)}  заход ${i + 1}${r.finished ? '' : ' (недоигран)'}: '
        '${formatDuration(r.median)} / ${formatDuration(r.p90)} / ${formatDuration(r.worst)}');
  }
  final rerun = s.rerunShare;
  stdout.writeln('${mark(rerun != null && rerun >= BalanceTargets.rerunMin && rerun <= BalanceTargets.rerunMax)}'
      'рывок: 2-й заход до той же точки — ${rerun == null ? '—' : '${(rerun * 100).toStringAsFixed(1)} %'} первого');
  stdout.writeln('${mark(within(s.tier12At, BalanceTargets.tier12Min, BalanceTargets.tier12Max))}'
      '12-я ступень, «считает»: ${formatDuration(s.tier12At)}');
  stdout.writeln('${mark(s.overnightTab != null && s.overnightTab! >= BalanceTargets.overnightTabMin)}'
      'ночь открытой вкладки даёт мудрость после ${s.overnightTab?.inMinutes} мин игры');
  final d20 = s.dailyFirstWisdomDay, d20c = s.dailyFirstWisdomDayCasual;
  stdout.writeln('${mark(d20 != null && d20 >= BalanceTargets.dailyFirstWisdomDayMin && d20 <= BalanceTargets.dailyFirstWisdomDayMax && d20c != null && d20c <= BalanceTargets.dailyFirstWisdomDayCasualMax)}'
      '${BalanceTargets.dailySession.inMinutes} мин в день, весь поток: 1-я мудрость — '
      '«считает» ${d20 == null ? '—' : '$d20-й день'}, «обычный» ${d20c == null ? '—' : '$d20c-й день'}');
  stdout.writeln('${mark(s.maxTankBuffer <= BalanceTargets.tankMax)}'
      'запас бака, наибольший: ${formatDuration(s.maxTankBuffer)}');
  stdout.writeln('  штраф: ${s.penalty.toStringAsFixed(2)} (ноль — всё в целях)');
  stdout.writeln('');
}
