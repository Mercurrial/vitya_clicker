import 'package:equatable/equatable.dart';

/// Модель апгрейда. Каждый апгрейд применяет множитель к конкретной цели.
enum UpgradeTarget {
  coreOutput,        // Множитель на базовую радиацию ядра
  generatorOutput,   // Множитель на конкретный генератор (по generatorId)
  allGenerators,     // Множитель на ВСЕ генераторы
  synergyResonance,  // +10% ко всем за каждый тип генератора с 25+ штук
  synergyCoupling,   // Fusion Core +1% за каждый Geothermal Tap
}

class Upgrade extends Equatable {
  final String id;
  final String name;
  final String description;
  final double cost;
  final UpgradeTarget target;
  final String? targetGeneratorId; // Только для UpgradeTarget.generatorOutput
  final double multiplier;
  final bool purchased;

  const Upgrade({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.target,
    this.targetGeneratorId,
    required this.multiplier,
    this.purchased = false,
  });

  Upgrade copyWith({
    bool? purchased,
  }) {
    return Upgrade(
      id: id,
      name: name,
      description: description,
      cost: cost,
      target: target,
      targetGeneratorId: targetGeneratorId,
      multiplier: multiplier,
      purchased: purchased ?? this.purchased,
    );
  }

  @override
  List<Object?> get props => [id, name, description, cost, target, targetGeneratorId, multiplier, purchased];

  @override
  bool get stringify => true;
}
