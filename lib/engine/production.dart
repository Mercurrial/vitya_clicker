import 'dart:math' as math;

import '../content/balance.dart';
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

  /// Минимальная ёмкость — пока производства почти нет.
  static double get baseTankMl => Balance.current.baseTankMl;

  /// Сколько секунд производства держит бак без улучшений.
  static double get baseBufferSeconds => Balance.current.baseBufferSeconds;

  /// Ёмкость бака.
  ///
  /// Считается как **запас времени**, а не как фиксированный объём. Это
  /// принципиально: производство растёт экспоненциально, и любой плоский объём
  /// оно обгоняет за считанные минуты — бак начинает переполняться за шесть
  /// секунд, idle превращается в дежурство у кнопки, а рынок обесценивается,
  /// потому что продавать приходится всегда, а не на пике.
  ///
  /// Привязка к потоку это лечит: улучшения увеличивают не литры, а часы, на
  /// которые можно уйти. Нижняя граница нужна для самого начала, когда
  /// аппаратов ещё нет.
  /// Потолок обязателен. Улучшения бака перемножаются (×2·×3·×4·×5 = ×120), и
  /// без ограничения запас доходил до четырёх часов производства. Симулятор
  /// показал, чем это кончается: бак перестаёт наполняться за сеанс, продажа
  /// перестаёт быть решением, а вместе с ней обесцениваются рынок и сорт.
  static double tankCapacity(UpgradesState ups, double mlPerSecond) {
    final grown = baseBufferSeconds *
        ups.items
            .where((u) => u.purchased && u.target == UpgradeTarget.tankCapacity)
            .fold(1.0, (product, u) => product * u.multiplier);
    final buffer = math.min(grown, Balance.current.maxBufferSeconds);
    final byFlow = mlPerSecond * buffer;
    return byFlow > baseTankMl ? byFlow : baseTankMl;
  }

  /// На сколько времени хватит бака при текущем потоке — это и есть то, что
  /// игрок реально покупает, расширяя тару.
  static Duration tankBuffer(UpgradesState ups, double mlPerSecond) {
    if (mlPerSecond <= 0) return Duration.zero;
    final seconds = tankCapacity(ups, mlPerSecond) / mlPerSecond;
    return Duration(seconds: seconds.round());
  }

  /// Количества, на которых доход аппарата удваивается.
  static List<int> get milestones => Balance.current.milestones;

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
