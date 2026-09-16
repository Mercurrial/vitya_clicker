import 'dart:math' as math;

import 'package:equatable/equatable.dart';

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
class PrestigeState extends Equatable {
  /// Накопленная мудрость (перманентная).
  final int wisdom;

  /// Сколько миллилитров Витя нагнал за всё время, включая прошлые жизни.
  final double totalEverEarned;

  /// Сколько раз он уже просыпался с больной головой.
  final int hangovers;

  const PrestigeState({
    this.wisdom = 0,
    this.totalEverEarned = 0.0,
    this.hangovers = 0,
  });

  /// Каждая единица мудрости даёт +8 % ко всему производству.
  ///
  /// Больше, чем было (+5 %), — потому что и достаются они теперь куда реже.
  static const double bonusPerWisdom = 0.08;

  /// Первая мудрость приходит за тонну самогона (1e6 мл = 1000 л).
  static const double firstWisdomMl = 1e6;

  double get globalMultiplier => 1.0 + bonusPerWisdom * wisdom;

  /// Сколько мудрости заслужено всей историей.
  ///
  /// `log2(1 + всего/тонна)`: первая тонна даёт единицу, дальше каждая
  /// следующая ступень требует удвоения.
  static int wisdomFor(double totalMl) {
    if (totalMl <= 0) return 0;
    final steps = math.log(1 + totalMl / firstWisdomMl) / math.ln2;
    return steps.isFinite ? steps.floor() : 0;
  }

  int get potentialWisdom => wisdomFor(totalEverEarned);

  /// Сколько мудрости добавится за похмелье прямо сейчас.
  int get pendingWisdom {
    final d = potentialWisdom - wisdom;
    return d > 0 ? d : 0;
  }

  /// Есть ли смысл ложиться спать.
  bool get canPrestige => pendingWisdom > 0;

  /// Сколько нужно нагнать до следующей мудрости.
  double get nextWisdomAtMl =>
      firstWisdomMl * (math.pow(2, potentialWisdom + 1) - 1);

  /// Продвижение к следующей мудрости, 0..1 — для полосы в интерфейсе.
  double get progressToNext {
    final from = firstWisdomMl * (math.pow(2, potentialWisdom) - 1);
    final to = nextWisdomAtMl;
    if (to <= from) return 0;
    return ((totalEverEarned - from) / (to - from)).clamp(0.0, 1.0);
  }

  PrestigeState copyWith({int? wisdom, double? totalEverEarned, int? hangovers}) =>
      PrestigeState(
        wisdom: wisdom ?? this.wisdom,
        totalEverEarned: totalEverEarned ?? this.totalEverEarned,
        hangovers: hangovers ?? this.hangovers,
      );

  @override
  List<Object?> get props => [wisdom, totalEverEarned, hangovers];

  @override
  bool get stringify => true;
}
