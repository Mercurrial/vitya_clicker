/// Перебор баланса: ищет числа, при которых игра попадает в цели.
///
/// Это ответ на вопрос «почему не получилось с первого раза». Не получилось
/// потому, что числа подбирались рассуждением: каждая формула по отдельности
/// выглядела разумной. Но экономика — это не набор формул, а их композиция во
/// времени, и её поведение рассуждением не предсказывается. Единственный
/// честный способ — прогнать и посмотреть.
///
/// Порог первой мудрости не перебирается: 2,5 часа — решение владельца, и
/// каждому варианту кривой порог снимается с неё самой
/// ([firstWisdomFromCurve]). Перебираются лестница и цены улучшений.
///
/// Полная оценка варианта — партия на 15 часов, это около минуты. Поэтому
/// сетка сначала отсеивается быстрой оценкой (только первый заход), а
/// полностью считаются несколько лучших.
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

  final coarse = <({Balance balance, Score score})>[];

  // Сетка намеренно грубая: задача не найти идеал, а понять, в какой области
  // он лежит. Точную настройку делает человек, глядя на полный отчёт.
  for (final growth in [1.14, 1.15, 1.16]) {
    for (final costRatio in [26.0, 28.0, 30.0]) {
      for (final outputRatio in [6.0, 6.5]) {
        for (final tierUps in const [
          [30.0, 1e3, 1e5],
          [100.0, 1e4, 1e6],
        ]) {
          final shape = kBalance.copyWith(
            costGrowth: growth,
            tierCostRatio: costRatio,
            tierOutputRatio: outputRatio,
            tierUpgradeCosts: tierUps,
          );
          final candidate = shape.copyWith(firstWisdomMl: firstWisdomFromCurve(shape));
          coarse.add((balance: candidate, score: scoreBalance(candidate, quick: true)));
        }
      }
    }
  }
  coarse.sort((a, b) => a.score.penalty.compareTo(b.score.penalty));

  stdout.writeln('Полная оценка пяти лучших по первому заходу:\n');
  stdout.writeln('  РОСТ  ЦЕНА×  ВЫХОД×  ×2 СТУПЕНИ       ПОРОГ   ОБЫЧН  СТУП  ОКУП мед/90%/худ  РЫВОК  12-я   НОЧЬ  ШТРАФ');
  stdout.writeln('  ${'-' * 104}');
  for (final c in coarse.take(5)) {
    final b = c.balance;
    final s = scoreBalance(b);
    final worst = s.paybackByRun.fold<RunPayback?>(
      null,
      (w, r) => w == null || r.worst > w.worst ? r : w,
    );
    stdout.writeln(
      '  ${b.costGrowth.toStringAsFixed(2)}  '
      '${b.tierCostRatio.toStringAsFixed(0).padLeft(5)}  '
      '${b.tierOutputRatio.toStringAsFixed(1).padLeft(6)}  '
      '${b.tierUpgradeCosts.map(formatBig).join('/').padRight(14)}  '
      '${b.firstWisdomMl.toStringAsExponential(2).padLeft(8)}  '
      '${formatClock(s.firstWisdomCasual).padLeft(7)}  '
      '${s.tiersAtFirstWisdom.toString().padLeft(4)}  '
      '${worst == null ? '—'.padLeft(16) : '${formatDuration(worst.median)}/${formatDuration(worst.p90)}/${formatDuration(worst.worst)}'.padLeft(16)}  '
      '${s.rerunShare == null ? '—' : '${(s.rerunShare! * 100).round()} %'}  '
      '${formatDuration(s.tier12At).padLeft(5)}  '
      '${(s.overnightTab == null ? '—' : '${s.overnightTab!.inMinutes}м').padLeft(5)}  '
      '${s.penalty.toStringAsFixed(2).padLeft(5)}',
    );
  }
  stdout.writeln('\nОКУП — заход с самой долгой худшей окупаемостью.');
}
