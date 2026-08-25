import 'package:equatable/equatable.dart';
import 'upgrade.dart';

class UpgradesState extends Equatable {
  final List<Upgrade> items;

  const UpgradesState({
    this.items = const [],
  });

  UpgradesState copyWith({
    List<Upgrade>? items,
  }) {
    return UpgradesState(
      items: items != null ? List<Upgrade>.unmodifiable(items) : this.items,
    );
  }

  /// Суммарный множитель радиации ядра от купленных апгрейдов
  double get coreMultiplier {
    return items
        .where((u) => u.purchased && u.target == UpgradeTarget.coreOutput)
        .fold(1.0, (product, u) => product * u.multiplier);
  }

  /// Множитель для конкретного генератора (произведение всех применимых апгрейдов)
  double generatorMultiplier(String generatorId) {
    return items
        .where((u) =>
            u.purchased &&
            (u.target == UpgradeTarget.allGenerators ||
                (u.target == UpgradeTarget.generatorOutput &&
                    u.targetGeneratorId == generatorId)))
        .fold(1.0, (product, u) => product * u.multiplier);
  }

  /// Куплен ли хотя бы один апгрейд с данной целью (для синергий/флагов).
  bool hasPurchased(UpgradeTarget target) =>
      items.any((u) => u.purchased && u.target == target);

  @override
  List<Object?> get props => [items];

  @override
  bool get stringify => true;
}
