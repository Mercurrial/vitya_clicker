import '../models/generator.dart';
import '../models/generators_state.dart';
import '../models/prestige_state.dart';
import '../models/upgrade.dart';
import '../models/upgrades_state.dart';

/// Centralised production maths for KARDASHEV (Stage 1).
///
/// A generator's output stacks four multipliers on top of its flat base:
///   owned · baseProduction
///     × milestone (×2 at 10/25/50/100 owned — the acceleration injector)
///     × upgrade   (per-generator ×N and global "all generators" ×N)
///     × synergy   (Resonance breadth bonus, Fusion↔Geothermal coupling)
///     × prestige  (1 + 0.05 · shards)
class Production {
  const Production._();

  /// J/s the star core radiates with zero generators (click-free bootstrap).
  static const double coreBase = 1.0;

  /// Core radiance: base × core upgrades × prestige multiplier.
  static double coreOutput(UpgradesState ups, PrestigeState prestige) =>
      coreBase * ups.coreMultiplier * prestige.globalMultiplier;

  /// Owned counts at which a generator's output doubles.
  static const List<int> milestones = [10, 25, 50, 100];

  static int milestoneSteps(int owned) {
    var steps = 0;
    for (final m in milestones) {
      if (owned >= m) steps++;
    }
    return steps;
  }

  /// ×2 per milestone reached.
  static double milestoneMultiplier(int owned) {
    var m = 1.0;
    for (var i = 0; i < milestoneSteps(owned); i++) {
      m *= 2.0;
    }
    return m;
  }

  /// J/s produced by a single generator, all multipliers applied.
  static double generatorOutput(
    Generator g,
    GeneratorsState gens,
    UpgradesState ups,
    PrestigeState prestige,
  ) {
    if (g.ownedCount == 0) return 0.0;
    var out = g.ownedCount * g.baseProduction;
    out *= milestoneMultiplier(g.ownedCount);
    out *= ups.generatorMultiplier(g.id);
    out *= _synergyMultiplier(g, gens, ups);
    out *= prestige.globalMultiplier;
    return out;
  }

  /// Total passive J/s across all generators.
  static double goldPerSecond(
    GeneratorsState gens,
    UpgradesState ups,
    PrestigeState prestige,
  ) {
    var sum = coreOutput(ups, prestige);
    for (final g in gens.items) {
      sum += generatorOutput(g, gens, ups, prestige);
    }
    return sum;
  }

  static double _synergyMultiplier(Generator g, GeneratorsState gens, UpgradesState ups) {
    var f = 1.0;
    // Resonance: each generator type at >= 25 owned grants +10% to ALL.
    if (ups.hasPurchased(UpgradeTarget.synergyResonance)) {
      var k = 0;
      for (final x in gens.items) {
        if (x.ownedCount >= 25) k++;
      }
      f *= 1.0 + 0.10 * k;
    }
    // Coupling: Fusion Core gains +1% per Geothermal Tap owned.
    if (g.id == 'fusion' && ups.hasPurchased(UpgradeTarget.synergyCoupling)) {
      f *= 1.0 + 0.01 * _ownedOf(gens, 'geothermal');
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
