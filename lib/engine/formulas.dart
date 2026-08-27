import 'dart:math';

class Formulas {
  const Formulas();

  /// Стоимость следующей штуки: base × growth^owned.
  double calculateUpgradeCost(double baseCost, double costGrowthFactor, int ownedCount) {
    return baseCost * pow(costGrowthFactor, ownedCount);
  }

  /// Пассивная добыча за промежуток времени (в секундах).
  double calculatePassiveGeneration(double mlPerSecond, double deltaTimeSeconds) {
    return mlPerSecond * deltaTimeSeconds;
  }

  /// Во сколько обойдётся сразу [count] штук.
  ///
  /// Сумма геометрической прогрессии, а не цикл: покупка «максимум» при тысячах
  /// штук не должна упираться в производительность.
  double bulkCost(double baseCost, double growth, int owned, int count) {
    if (count <= 0) return 0;
    final first = calculateUpgradeCost(baseCost, growth, owned);
    if (growth == 1.0) return first * count;
    return first * (pow(growth, count) - 1) / (growth - 1);
  }

  /// Сколько штук получится купить на [money].
  ///
  /// Обратная к [bulkCost]: решаем n из суммы прогрессии через логарифм.
  /// Результат подстраховываем проверкой, чтобы ошибка округления не позволила
  /// купить на рубль больше, чем есть.
  int maxAffordable(double baseCost, double growth, int owned, double money) {
    if (money <= 0) return 0;
    final first = calculateUpgradeCost(baseCost, growth, owned);
    if (money < first) return 0;
    if (growth <= 1.0) return (money / first).floor();

    final ratio = money * (growth - 1) / first + 1;
    var n = (log(ratio) / log(growth)).floor();
    if (n < 0) n = 0;

    // Подрезаем, если логарифм «переехал» на штуку вверх.
    while (n > 0 && bulkCost(baseCost, growth, owned, n) > money) {
      n--;
    }
    return n;
  }
}
