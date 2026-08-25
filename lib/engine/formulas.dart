import 'dart:math';

class Formulas {
  const Formulas();

  /// Расчет добычи за один клик
  double calculateClickGain(double baseClickPower, double multipliers) {
    return baseClickPower * multipliers;
  }

  /// Расчет стоимости: baseCost * (growthFactor ^ ownedCount)
  double calculateUpgradeCost(double baseCost, double costGrowthFactor, int ownedCount) {
    return baseCost * pow(costGrowthFactor, ownedCount);
  }

  /// Расчет пассивного дохода за промежуток времени (в секундах)
  double calculatePassiveGeneration(double goldPerSecond, double deltaTimeSeconds) {
    return goldPerSecond * deltaTimeSeconds;
  }
}
