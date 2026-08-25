import 'package:equatable/equatable.dart';

class Generator extends Equatable {
  final String id;
  final String name;
  final double baseCost;
  final double costGrowthFactor;
  final double baseProduction;
  final int ownedCount;

  const Generator({
    required this.id,
    required this.name,
    required this.baseCost,
    required this.costGrowthFactor,
    required this.baseProduction,
    this.ownedCount = 0,
  });

  Generator copyWith({
    String? id,
    String? name,
    double? baseCost,
    double? costGrowthFactor,
    double? baseProduction,
    int? ownedCount,
  }) {
    return Generator(
      id: id ?? this.id,
      name: name ?? this.name,
      baseCost: baseCost ?? this.baseCost,
      costGrowthFactor: costGrowthFactor ?? this.costGrowthFactor,
      baseProduction: baseProduction ?? this.baseProduction,
      ownedCount: ownedCount ?? this.ownedCount,
    );
  }

  @override
  List<Object?> get props => [id, name, baseCost, costGrowthFactor, baseProduction, ownedCount];

  @override
  bool get stringify => true;
}
