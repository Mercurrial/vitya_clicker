import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Prestige ("Singularity") state. Persists across resets.
///
/// Shards are earned from total energy ever produced:
///   shards = floor(sqrt(totalEverEarned / 1e6))
/// and grant a permanent global production multiplier (+5% each, additive).
class PrestigeState extends Equatable {
  final int shards;
  final double totalEverEarned;

  const PrestigeState({this.shards = 0, this.totalEverEarned = 0.0});

  /// +5% to all production per shard (additive). 0 shards ⇒ ×1.0.
  double get globalMultiplier => 1.0 + 0.05 * shards;

  /// Shards you would hold after prestiging right now.
  int get potentialShards {
    if (totalEverEarned <= 0) return 0;
    return math.sqrt(totalEverEarned / 1e6).floor();
  }

  /// Shards gained by prestiging right now (never negative).
  int get pendingShards {
    final d = potentialShards - shards;
    return d > 0 ? d : 0;
  }

  PrestigeState copyWith({int? shards, double? totalEverEarned}) => PrestigeState(
        shards: shards ?? this.shards,
        totalEverEarned: totalEverEarned ?? this.totalEverEarned,
      );

  @override
  List<Object?> get props => [shards, totalEverEarned];

  @override
  bool get stringify => true;
}
