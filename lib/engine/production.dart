import '../models/generator.dart';
import '../models/generators_state.dart';
import '../models/prestige_state.dart';
import '../models/upgrade.dart';
import '../models/upgrades_state.dart';

/// Расчёт производства.
///
/// Доход аппарата — это плоская база, на которую последовательно ложатся
/// множители:
///   штук × базовый доход
///     × milestone   (×2 на 10/25/50/100 — ступенчатые скачки, «ускорение»)
///     × апгрейды    (персональные ×N и глобальные ×N)
///     × синергии    (Наставник Петрович, Семейный подряд)
///     × мудрость    (престиж)
///
/// Функция чистая: зависит только от состояния. Это обязательное условие для
/// оффлайн-дохода — его считаем как f(состояние, прошедшее время).
class Production {
  const Production._();

  /// Синергия «Наставник Петрович»: этот аппарат растёт от количества вот того.
  static const String _menteeId = 'dedov';
  static const String _mentorId = 'banka';

  /// Ёмкость бака без улучшений — два литра.
  ///
  /// Бак не декорация: когда он полон, аппараты встают. Это честно (ёмкость
  /// действительно кончается) и создаёт причину вернуться — пока игрока нет,
  /// бак наполняется, он приходит и продаёт.
  static const double baseTankMl = 2000;

  /// Ёмкость бака с учётом улучшений.
  static double tankCapacity(UpgradesState ups) =>
      baseTankMl *
      ups.items
          .where((u) => u.purchased && u.target == UpgradeTarget.tankCapacity)
          .fold(1.0, (product, u) => product * u.multiplier);

  /// Сколько секунд производства стоит одно нажатие.
  ///
  /// Именно доля от текущего потока, а не константа: константу экспоненциальный
  /// рост генераторов обесценивает за считанные минуты, а доля живёт всегда.
  static const double tapSeconds = 0.25;

  /// Количества, на которых доход аппарата удваивается.
  static const List<int> milestones = [10, 25, 50, 100];

  static int milestoneSteps(int owned) {
    var steps = 0;
    for (final m in milestones) {
      if (owned >= m) steps++;
    }
    return steps;
  }

  /// ×2 за каждый достигнутый рубеж.
  static double milestoneMultiplier(int owned) {
    var m = 1.0;
    for (var i = 0; i < milestoneSteps(owned); i++) {
      m *= 2.0;
    }
    return m;
  }

  /// Миллилитры в секунду от одного аппарата со всеми множителями.
  static double generatorOutput(
    Generator g,
    GeneratorsState gens,
    UpgradesState ups,
    PrestigeState prestige, [
    double achievementMultiplier = 1.0,
  ]) {
    if (g.ownedCount == 0) return 0.0;
    var out = g.ownedCount * g.baseProduction;
    out *= milestoneMultiplier(g.ownedCount);
    out *= ups.generatorMultiplier(g.id);
    out *= _synergyMultiplier(g, gens, ups);
    out *= prestige.globalMultiplier;
    out *= achievementMultiplier;
    return out;
  }

  /// Суммарные миллилитры в секунду.
  static double mlPerSecond(
    GeneratorsState gens,
    UpgradesState ups,
    PrestigeState prestige, [
    double achievementMultiplier = 1.0,
  ]) {
    var sum = 0.0;
    for (final g in gens.items) {
      sum += generatorOutput(g, gens, ups, prestige, achievementMultiplier);
    }
    return sum;
  }

  static double _synergyMultiplier(Generator g, GeneratorsState gens, UpgradesState ups) {
    var f = 1.0;

    // Семейный подряд: каждый аппарат от 25 штук даёт +10% ко всем.
    if (ups.hasPurchased(UpgradeTarget.synergyResonance)) {
      var k = 0;
      for (final x in gens.items) {
        if (x.ownedCount >= 25) k++;
      }
      f *= 1.0 + 0.10 * k;
    }

    // Наставник Петрович: «Дедов» +1% за каждую банку.
    if (g.id == _menteeId && ups.hasPurchased(UpgradeTarget.synergyCoupling)) {
      f *= 1.0 + 0.01 * _ownedOf(gens, _mentorId);
    }

    return f;
  }

  static int _ownedOf(GeneratorsState gens, String id) {
    for (final x in gens.items) {
      if (x.id == id) return x.ownedCount;
    }
    return 0;
  }
}
