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
library;

import 'dart:io';

import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/sim/balance_sim.dart';

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
