import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// ПОХМЕЛЬЕ — престиж-слой.
///
/// Витя просыпается, гараж пуст, аппарата нет. Но осталась МУДРОСТЬ: она
/// переживает любой сброс и ускоряет каждый следующий заход.
///
/// Мудрость считается от суммарно нагнанного за всё время:
///   мудрость = ⌊√(всего литров / 1e6)⌋
/// Корень — намеренно: он делает первые заходы щедрыми, а поздние — плавными,
/// иначе престиж либо не окупается, либо мгновенно ломает баланс.
class PrestigeState extends Equatable {
  /// Накопленная мудрость (перманентная).
  final int wisdom;

  /// Сколько литров Витя нагнал за всё время, включая прошлые жизни.
  final double totalEverEarned;

  /// Сколько раз он уже просыпался с больной головой.
  final int hangovers;

  const PrestigeState({
    this.wisdom = 0,
    this.totalEverEarned = 0.0,
    this.hangovers = 0,
  });

  /// Каждая единица мудрости даёт +5 % ко всему производству.
  static const double bonusPerWisdom = 0.05;

  /// Порог, за который начисляется первая мудрость.
  static const double litresPerWisdomStep = 1e6;

  double get globalMultiplier => 1.0 + bonusPerWisdom * wisdom;

  /// Сколько мудрости было бы, если проспаться прямо сейчас.
  int get potentialWisdom {
    if (totalEverEarned <= 0) return 0;
    return math.sqrt(totalEverEarned / litresPerWisdomStep).floor();
  }

  /// Сколько мудрости добавится за похмелье прямо сейчас.
  int get pendingWisdom {
    final d = potentialWisdom - wisdom;
    return d > 0 ? d : 0;
  }

  /// Есть ли смысл ложиться спать.
  bool get canPrestige => pendingWisdom > 0;

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
