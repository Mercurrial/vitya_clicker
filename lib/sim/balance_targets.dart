/// Чего мы хотим от экономики — числами, а не ощущением.
///
/// Эти рамки существуют, чтобы баланс нельзя было сломать незаметно. Прошлый
/// раз он ломался именно так: каждая правка выглядела улучшением, а игра
/// целиком разваливалась за полчаса — и узнали мы об этом от человека, который
/// в неё поиграл. Теперь границы проверяются тестом при каждом изменении.
///
/// Числа не с потолка:
///
/// * **Первое похмелье через 20–75 минут.** Меньше — престиж наступает раньше,
///   чем игрок понял правила, и обесценивает всё, что было до него. Больше —
///   половина игроков до него не доживает.
/// * **Окупаемость покупки в районе минуты.** Это и есть то самое «ещё чуть-чуть
///   накоплю»: короче — покупки перестают быть решением, длиннее — игра
///   ощущается стоячей.
/// * **Не вся лестница за вечер.** Тринадцать аппаратов — это контент; если
///   внимательный игрок проходит их за четыре часа, дальше играть не во что.
library;

import 'dart:math' as math;

import '../content/balance.dart';
import '../content/game_content.dart';
import 'balance_sim.dart';

abstract final class BalanceTargets {
  /// Первое похмелье у внимательного игрока.
  static const prestigeMin = Duration(minutes: 20);
  static const prestigeMax = Duration(minutes: 75);

  /// Медианная окупаемость лучшей покупки.
  static const paybackMin = Duration(seconds: 25);
  static const paybackMax = Duration(minutes: 8);

  /// Сколько ступеней из тринадцати позволительно открыть за четыре часа.
  static const maxTiersInFourHours = 11;

  /// Сколько ступеней обязано открыться — иначе игра не «долгая», а мёртвая.
  static const minTiersInFourHours = 3;

  /// Бак: и «слишком мал» и «слишком велик» одинаково ломают игру.
  static const tankMin = Duration(minutes: 1);
  static const tankMax = Duration(minutes: 45);

  static String get summary => '''
  • первое похмелье: ${prestigeMin.inMinutes}–${prestigeMax.inMinutes} мин
  • окупаемость покупки: ${paybackMin.inSeconds} с – ${paybackMax.inMinutes} мин
  • за 4 часа открыто $minTiersInFourHours–$maxTiersInFourHours из 13 аппаратов
  • запас бака: ${tankMin.inMinutes}–${tankMax.inMinutes} мин производства''';
}

/// Насколько вариант баланса промахивается мимо целей.
class Score {
  final Duration? firstPrestige;
  final double medianPayback;
  final int tiersReached;
  final Duration maxTankBuffer;

  /// Ноль — попал во всё. Чем больше, тем хуже.
  final double penalty;

  const Score({
    required this.firstPrestige,
    required this.medianPayback,
    required this.tiersReached,
    required this.maxTankBuffer,
    required this.penalty,
  });

  bool get hitsTargets => penalty == 0;
}

/// Прогнать вариант и оценить.
///
/// Считает по внимательному игроку: он быстрее всех доходит до краёв, поэтому
/// на нём раньше всего видно, что экономика поехала.
Score scoreBalance(Balance candidate, {Duration horizon = const Duration(hours: 4)}) {
  return withBalance(candidate, () {
    const sim = BalanceSim(sampleEvery: Duration(minutes: 2));
    final r = sim.run(PlayStyle.tryhard, horizon: horizon);

    final paybacks = [
      for (final c in r.timeline)
        if (c.payback != null) c.payback!.inMilliseconds / 1000.0,
    ];
    final med = median(paybacks);
    final tiers = kGeneratorCount - r.unreached.length;

    var maxTank = Duration.zero;
    for (final c in r.timeline) {
      if (c.tankBuffer > maxTank) maxTank = c.tankBuffer;
    }

    var penalty = 0.0;
    penalty += _miss(
      r.firstPrestige?.inSeconds.toDouble(),
      BalanceTargets.prestigeMin.inSeconds.toDouble(),
      BalanceTargets.prestigeMax.inSeconds.toDouble(),
    );
    penalty += _miss(
      med,
      BalanceTargets.paybackMin.inSeconds.toDouble(),
      BalanceTargets.paybackMax.inSeconds.toDouble(),
    );
    if (tiers > BalanceTargets.maxTiersInFourHours) {
      penalty += (tiers - BalanceTargets.maxTiersInFourHours) * 0.5;
    }
    if (tiers < BalanceTargets.minTiersInFourHours) {
      penalty += (BalanceTargets.minTiersInFourHours - tiers) * 2.0;
    }
    if (maxTank > BalanceTargets.tankMax) {
      penalty += _ratio(
        maxTank.inSeconds / BalanceTargets.tankMax.inSeconds,
      );
    }

    return Score(
      firstPrestige: r.firstPrestige,
      medianPayback: med,
      tiersReached: tiers,
      maxTankBuffer: maxTank,
      penalty: penalty,
    );
  });
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
