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
/// длина не зависит от аргумента: ночь — 8 часов, сутки — сутки.
library;

import 'dart:io';

import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/sim/balance_sim.dart';
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
  _printDeadContent(results);

  const players = [PlayStyle.tryhard, PlayStyle.casual];
  _printAway(sim, players);
  _printOvernight(sim, players);
  _printDaily(sim, players);
  _printMarathon(sim, players);
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
  stdout.writeln('МЁРТВЫЙ КОНТЕНТ: улучшения, не купленные НИ ОДНИМ игроком');
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
void _printAway(BalanceSim sim, List<PlayStyle> players) {
  _header('СУТКИ ОТСУТСТВИЯ — сколько это минут активной игры');
  stdout.writeln('  ${'игрок'.padRight(9)} ${'откуда'.padRight(24)} ${'закрыто'.padLeft(9)}  ${'вкладка'.padLeft(9)}');
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
      final closed = activeEquivalent(sim, p, const Duration(days: 1), Absence.closed);
      final tab = activeEquivalent(sim, p, const Duration(days: 1), Absence.tabOpen);
      stdout.writeln('  ${style.name.padRight(9)} ${label.padRight(24)} '
          '${_minutes(closed).padLeft(9)}  ${_minutes(tab).padLeft(9)}');
    }
  }
  stdout.writeln('');
}

/// Сколько сыграть с нуля, чтобы ночь принесла первую мудрость.
void _printOvernight(BalanceSim sim, List<PlayStyle> players) {
  _header('НОЧЬ (8 ч) — сколько сыграть до неё, чтобы утром была мудрость');
  stdout.writeln('  ${'игрок'.padRight(9)} ${'без ночи'.padLeft(9)}  ${'закрыто'.padLeft(9)}  ${'вкладка'.padLeft(9)}');
  for (final style in players) {
    final alone = sim.run(style.withPrestige(null), horizon: const Duration(hours: 8));
    final closed = overnightThreshold(sim, style, Absence.closed);
    final tab = overnightThreshold(sim, style, Absence.tabOpen);
    stdout.writeln('  ${style.name.padRight(9)} ${formatClock(alone.firstPrestige).padLeft(9)}  '
        '${_minutes(closed).padLeft(9)}  ${_minutes(tab).padLeft(9)}');
  }
  stdout.writeln('');
}

/// Заходит раз в день, остальное время игра закрыта.
void _printDaily(BalanceSim sim, List<PlayStyle> players) {
  _header('РАЗ В ДЕНЬ, остальное время закрыто — 14 дней');
  stdout.writeln('  ${'игрок'.padRight(9)} ${'в день'.padLeft(7)}  ${'1-я мудрость'.padLeft(13)}  '
      '${'мудрость к д7 / д14'.padLeft(20)}  похмелий');
  for (final style in players) {
    for (final m in [20, 60]) {
      final r = daily(sim, style, perDay: Duration(minutes: m));
      final first = r.firstWisdomDay == null ? '> 14 дн' : '${r.firstWisdomDay}-й день';
      stdout.writeln('  ${style.name.padRight(9)} ${'$m мин'.padLeft(7)}  ${first.padLeft(13)}  '
          '${'${r.wisdomByDay[6]} / ${r.wisdomByDay[13]}'.padLeft(20)}  ${r.result.prestiges}');
    }
  }
  stdout.writeln('');
}

/// 30 часов подряд, похмелье — когда прибавка окупает заход.
void _printMarathon(BalanceSim sim, List<PlayStyle> players) {
  _header('30 ЧАСОВ С ПОХМЕЛЬЯМИ — ложится, когда прибавка окупает заход');
  for (final style in players) {
    final m = marathon(sim, style);
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
}
