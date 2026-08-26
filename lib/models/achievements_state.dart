import 'package:equatable/equatable.dart';

import '../content/achievements.dart';
import 'achievement.dart';

/// Какие достижения уже взяты.
///
/// Хранится только набор идентификаторов: условия — чистые функции состояния,
/// пересчитываются на лету, а в сейв уходит минимум.
class AchievementsState extends Equatable {
  final Set<String> unlocked;

  const AchievementsState({this.unlocked = const {}});

  bool has(String id) => unlocked.contains(id);

  int get count => unlocked.length;

  /// Сколько рядов закрыто целиком.
  int get completedRows => kAchievementRows
      .where((row) => row.items.every((a) => unlocked.contains(a.id)))
      .length;

  /// Общий множитель к производству.
  ///
  /// Ряд даёт отдельную, куда более крупную прибавку — именно из-за этого
  /// ряд хочется добить, и достижения работают как система прогресса, а не
  /// как список галочек.
  double get multiplier {
    var m = 1.0;
    for (var i = 0; i < count; i++) {
      m *= kAchievementMultiplier;
    }
    for (var i = 0; i < completedRows; i++) {
      m *= kRowMultiplier;
    }
    return m;
  }

  /// Открыта ли функция, которую даёт какое-нибудь из взятых достижений.
  bool hasPerk(AchievementPerk perk) => kAllAchievements
      .any((a) => a.perk == perk && unlocked.contains(a.id));

  AchievementsState withUnlocked(Iterable<String> ids) =>
      AchievementsState(unlocked: {...unlocked, ...ids});

  @override
  List<Object?> get props => [unlocked];
}
