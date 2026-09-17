import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../content/balance.dart';

/// ПОХМЕЛЬЕ — престиж-слой.
///
/// Витя просыпается, гараж пуст, аппарата нет. Но осталась МУДРОСТЬ: она
/// переживает любой сброс и ускоряет каждый следующий заход.
///
/// ## Почему логарифм, а не корень
///
/// Сначала мудрость считалась как √(всего нагнанного). Это выглядело разумно,
/// но давало **положительную обратную связь**: мудрость множит производство,
/// производство копит «всего нагнанное», из него снова растёт мудрость. За
/// полчаса игры набегало 119 137 мудрости — то есть +595 685 % к производству,
/// и игра кончалась.
///
/// Корень тут не спасает: корень от экспоненты — всё ещё экспонента.
/// Логарифм спасает: **каждая следующая мудрость требует вдвое больше**
/// нагнанного, поэтому награда растёт медленнее, чем разгоняется петля, и
/// система приходит в равновесие вместо взрыва.
///
/// ## Почему мудрость НЕ хранится
///
/// Здесь лежит [claimedMl] — сколько нагнано на момент последнего похмелья, —
/// а мудрость из него вычисляется. Разница не косметическая.
///
/// Когда мудрость лежала в сейве числом, смена формулы оставляла это число от
/// старой формулы: понадобилась миграция, которая пересчитала его один раз и
/// тем самым заморозила. Любая следующая правка потребовала бы новой миграции,
/// и каждая работала бы только на тех, кто обновился.
///
/// Теперь в сейве лежит факт («нагнал столько-то»), а не оценка факта. Правка
/// формулы применяется у всех и сразу, включая уже накопленное. Ровно это и
/// делает правку баланса после релиза безопасной.
class PrestigeState extends Equatable {
  /// Сколько было нагнано на момент последнего похмелья. Из этого растёт
  /// накопленная мудрость.
  final double claimedMl;

  /// Мудрость, выданная не за игру, а компенсацией за правку баланса.
  ///
  /// Это тоже ФАКТ («мы ему выдали»), а не производное, поэтому хранится.
  final int bonusWisdom;

  /// Сколько миллилитров Витя нагнал за всё время, включая прошлые жизни.
  final double totalEverEarned;

  /// Сколько раз он уже просыпался с больной головой.
  final int hangovers;

  const PrestigeState({
    this.claimedMl = 0.0,
    this.bonusWisdom = 0,
    this.totalEverEarned = 0.0,
    this.hangovers = 0,
  });

  /// Каждая единица мудрости даёт прибавку ко всему производству.
  static double get bonusPerWisdom => Balance.current.bonusPerWisdom;

  /// Сколько надо нагнать до первой мудрости.
  static double get firstWisdomMl => Balance.current.firstWisdomMl;

  /// Накопленная мудрость.
  int get wisdom => wisdomFor(claimedMl) + bonusWisdom;

  double get globalMultiplier => 1.0 + bonusPerWisdom * wisdom;

  /// Сколько мудрости стоит такая история.
  ///
  /// `log2(1 + всего/первая)`: первая порция даёт единицу, дальше каждая
  /// следующая ступень требует удвоения.
  static int wisdomFor(double totalMl) {
    if (totalMl <= 0) return 0;
    final steps = math.log(1 + totalMl / firstWisdomMl) / math.ln2;
    return steps.isFinite ? steps.floor() : 0;
  }

  /// Сколько мудрости заслужено всей историей.
  int get potentialWisdom => wisdomFor(totalEverEarned) + bonusWisdom;

  /// Сколько мудрости добавится за похмелье прямо сейчас.
  int get pendingWisdom {
    final d = potentialWisdom - wisdom;
    return d > 0 ? d : 0;
  }

  /// Есть ли смысл ложиться спать.
  bool get canPrestige => pendingWisdom > 0;

  /// Ступени, заработанные историей, без компенсации: по ним считается полоса
  /// прогресса, и подмешивать в неё подарки нельзя — полоса поедет.
  int get _earnedSteps => wisdomFor(totalEverEarned);

  /// Сколько нужно нагнать до следующей мудрости.
  double get nextWisdomAtMl =>
      firstWisdomMl * (math.pow(2, _earnedSteps + 1) - 1);

  /// Продвижение к следующей мудрости, 0..1 — для полосы в интерфейсе.
  double get progressToNext {
    final from = firstWisdomMl * (math.pow(2, _earnedSteps) - 1);
    final to = nextWisdomAtMl;
    if (to <= from) return 0;
    return ((totalEverEarned - from) / (to - from)).clamp(0.0, 1.0);
  }

  /// Забрать всё заработанное — это и есть похмелье.
  PrestigeState claimAll() => copyWith(
        claimedMl: totalEverEarned,
        hangovers: hangovers + 1,
      );

  /// Начислить компенсацию за правку баланса.
  PrestigeState withCompensation(int extra) =>
      extra <= 0 ? this : copyWith(bonusWisdom: bonusWisdom + extra);

  PrestigeState copyWith({
    double? claimedMl,
    int? bonusWisdom,
    double? totalEverEarned,
    int? hangovers,
  }) =>
      PrestigeState(
        claimedMl: claimedMl ?? this.claimedMl,
        bonusWisdom: bonusWisdom ?? this.bonusWisdom,
        totalEverEarned: totalEverEarned ?? this.totalEverEarned,
        hangovers: hangovers ?? this.hangovers,
      );

  @override
  List<Object?> get props => [claimedMl, bonusWisdom, totalEverEarned, hangovers];

  @override
  bool get stringify => true;
}
