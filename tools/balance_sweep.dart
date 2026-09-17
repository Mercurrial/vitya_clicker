/// Перебор баланса: ищет числа, при которых игра попадает в цели.
///
/// Это ответ на вопрос «почему не получилось с первого раза». Не получилось
/// потому, что числа подбирались рассуждением: каждая формула по отдельности
/// выглядела разумной. Но экономика — это не набор формул, а их композиция во
/// времени, и её поведение рассуждением не предсказывается. Единственный
/// честный способ — прогнать и посмотреть.
///
/// Запуск:
///   dart run tools/balance_sweep.dart
library;

import 'dart:io';

import 'package:idle_game/content/balance.dart';
import 'package:idle_game/sim/balance_sim.dart';
import 'package:idle_game/sim/balance_targets.dart';

void main() {
  stdout.writeln('Перебор баланса. Цели:\n${BalanceTargets.summary}\n');

  final results = <({Balance balance, Score score})>[];

  // Сетка намеренно грубая: задача не найти идеал, а понять, в какой области
  // он лежит. Точную настройку делает человек, глядя на полный отчёт.
  for (final growth in [1.15, 1.18, 1.22, 1.26]) {
    for (final costRatio in [12.3, 16.0, 22.0, 30.0]) {
      for (final outputRatio in [6.05, 7.5, 9.0]) {
        for (final firstWisdom in [2.5e7, 2.5e8, 2.5e9]) {
          final candidate = kBalance.copyWith(
            costGrowth: growth,
            tierCostRatio: costRatio,
            tierOutputRatio: outputRatio,
            firstWisdomMl: firstWisdom,
          );
          results.add((balance: candidate, score: scoreBalance(candidate)));
        }
      }
    }
  }

  results.sort((a, b) => a.score.penalty.compareTo(b.score.penalty));

  stdout.writeln('  РОСТ  ЦЕНА×  ВЫХОД×  1-я МУДР    ПОХМ   ОКУП(мед)  ТИРОВ    БАК  ШТРАФ');
  stdout.writeln('  ${'-' * 74}');
  for (final r in results.take(20)) {
    final b = r.balance;
    final s = r.score;
    stdout.writeln(
      '  ${b.costGrowth.toStringAsFixed(2).padLeft(4)}  '
      '${b.tierCostRatio.toStringAsFixed(1).padLeft(5)}  '
      '${b.tierOutputRatio.toStringAsFixed(2).padLeft(6)}  '
      '${formatBig(b.firstWisdomMl).padLeft(8)}  '
      '${formatDuration(s.firstPrestige).padLeft(7)}  '
      '${formatDuration(Duration(seconds: s.medianPayback.round())).padLeft(9)}  '
      '${s.tiersReached.toString().padLeft(5)}  '
      '${formatDuration(s.maxTankBuffer).padLeft(5)}  '
      '${s.penalty.toStringAsFixed(2).padLeft(5)}',
    );
  }

  // Второй проход — мелкой сеткой вокруг победителя. Грубая сетка показывает
  // область, точная доводит до нуля штрафа.
  final coarse = results.first;
  stdout.writeln('\nТочный проход вокруг лучшего...');
  final refined = _refine(coarse.balance, coarse.score);

  final best = refined.balance;
  stdout.writeln('\nЛучший вариант (штраф ${refined.score.penalty.toStringAsFixed(3)}):');
  stdout.writeln('  costGrowth: ${best.costGrowth}');
  stdout.writeln('  tierCostRatio: ${best.tierCostRatio}');
  stdout.writeln('  tierOutputRatio: ${best.tierOutputRatio}');
  stdout.writeln('  firstWisdomMl: ${best.firstWisdomMl.toStringAsExponential(2)}');
  stdout.writeln('  первое похмелье: ${formatDuration(refined.score.firstPrestige)}');
  stdout.writeln('  окупаемость: ${formatDuration(
    Duration(seconds: refined.score.medianPayback.round()),
  )}');
  stdout.writeln('  ступеней за 4 ч: ${refined.score.tiersReached} из 13');
}

/// Покоординатный спуск: по очереди дёргаем каждый параметр, оставляем то, что
/// улучшило. Простой метод, но для четырёх чисел его достаточно, а главное —
/// он не требует от нас догадок о том, как параметры связаны.
({Balance balance, Score score}) _refine(Balance start, Score startScore) {
  var best = start;
  var bestScore = startScore;

  final knobs = <String, List<double> Function(Balance)>{
    'costGrowth': (b) => _around(b.costGrowth, 0.02),
    'tierCostRatio': (b) => _around(b.tierCostRatio, 2.0),
    'tierOutputRatio': (b) => _around(b.tierOutputRatio, 0.5),
    'firstWisdomMl': (b) => [b.firstWisdomMl / 2, b.firstWisdomMl * 2],
  };

  for (var pass = 0; pass < 4 && bestScore.penalty > 0; pass++) {
    for (final entry in knobs.entries) {
      for (final value in entry.value(best)) {
        final candidate = switch (entry.key) {
          'costGrowth' => best.copyWith(costGrowth: value),
          'tierCostRatio' => best.copyWith(tierCostRatio: value),
          'tierOutputRatio' => best.copyWith(tierOutputRatio: value),
          _ => best.copyWith(firstWisdomMl: value),
        };
        final score = scoreBalance(candidate);
        if (score.penalty < bestScore.penalty) {
          best = candidate;
          bestScore = score;
        }
      }
    }
  }

  return (balance: best, score: bestScore);
}

List<double> _around(double value, double step) => [value - step, value + step];
