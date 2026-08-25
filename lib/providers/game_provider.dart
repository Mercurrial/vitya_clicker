import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_state.dart';
import '../models/generator.dart';
import '../models/upgrade.dart';
import '../engine/game_engine.dart';
import '../engine/formulas.dart';

final timeProvider = Provider<DateTime Function()>((ref) => () => DateTime.now());

final formulasProvider = Provider<Formulas>((ref) => const Formulas());

final gameEngineProvider = Provider<GameEngine>((ref) {
  final formulas = ref.watch(formulasProvider);
  return GameEngine(formulas: formulas);
});

/// Стартовые генераторы (контент игры, отделён от логики)
final initialGeneratorsProvider = Provider<List<Generator>>((ref) {
  return const [
    Generator(
      id: 'photovoltaic',
      name: 'Photovoltaic Lattice',
      baseCost: 20,
      costGrowthFactor: 1.10,
      baseProduction: 0.1,
    ),
    Generator(
      id: 'geothermal',
      name: 'Geothermal Tap',
      baseCost: 150,
      costGrowthFactor: 1.10,
      baseProduction: 1.0,
    ),
    Generator(
      id: 'fusion',
      name: 'Fusion Core',
      baseCost: 1700,
      costGrowthFactor: 1.10,
      baseProduction: 8.0,
    ),
    Generator(
      id: 'antimatter',
      name: 'Antimatter Loop',
      baseCost: 18000,
      costGrowthFactor: 1.10,
      baseProduction: 47.0,
    ),
    Generator(
      id: 'dyson',
      name: 'Dyson Swarm',
      baseCost: 200000,
      costGrowthFactor: 1.10,
      baseProduction: 260.0,
    ),
    Generator(
      id: 'neutron',
      name: 'Neutron Forge',
      baseCost: 2100000,
      costGrowthFactor: 1.10,
      baseProduction: 1400.0,
    ),
    Generator(
      id: 'blackhole',
      name: 'Black-Hole Accretor',
      baseCost: 30000000,
      costGrowthFactor: 1.10,
      baseProduction: 7800.0,
    ),
    Generator(
      id: 'filament',
      name: 'Galactic Filament',
      baseCost: 500000000,
      costGrowthFactor: 1.10,
      baseProduction: 44000.0,
    ),
  ];
});

/// Стартовые апгрейды (контент игры)
final initialUpgradesProvider = Provider<List<Upgrade>>((ref) {
  return const [
    // Tap (click) upgrades
    Upgrade(
      id: 'core_x3',
      name: 'Core Ignition',
      description: 'Core radiance ×3',
      cost: 300,
      target: UpgradeTarget.coreOutput,
      multiplier: 3.0,
    ),
    Upgrade(
      id: 'core_x5',
      name: 'Plasma Injection',
      description: 'Core radiance ×5',
      cost: 6000,
      target: UpgradeTarget.coreOutput,
      multiplier: 5.0,
    ),
    // Generator upgrades
    Upgrade(
      id: 'photo_x2',
      name: 'Lattice Tuning',
      description: 'Photovoltaic Lattice ×2',
      cost: 200,
      target: UpgradeTarget.generatorOutput,
      targetGeneratorId: 'photovoltaic',
      multiplier: 2.0,
    ),
    Upgrade(
      id: 'geo_x2',
      name: 'Mantle Breach',
      description: 'Geothermal Tap ×2',
      cost: 1000,
      target: UpgradeTarget.generatorOutput,
      targetGeneratorId: 'geothermal',
      multiplier: 2.0,
    ),
    Upgrade(
      id: 'fusion_x2',
      name: 'Fusion Overclock',
      description: 'Fusion Core ×2',
      cost: 11000,
      target: UpgradeTarget.generatorOutput,
      targetGeneratorId: 'fusion',
      multiplier: 2.0,
    ),
    Upgrade(
      id: 'cascade',
      name: 'Resonance Cascade',
      description: 'All generators +50%',
      cost: 50000,
      target: UpgradeTarget.allGenerators,
      multiplier: 1.5,
    ),
    // Synergy upgrades (combos, not flat multipliers)
    Upgrade(
      id: 'coupling',
      name: 'Magnetic Coupling',
      description: 'Fusion Core +1% per Geothermal Tap',
      cost: 80000,
      target: UpgradeTarget.synergyCoupling,
      multiplier: 1.0,
    ),
    Upgrade(
      id: 'resonance',
      name: 'Lattice Resonance',
      description: 'Each generator at 25+: +10% to all',
      cost: 250000,
      target: UpgradeTarget.synergyResonance,
      multiplier: 1.0,
    ),
    Upgrade(
      id: 'dyson_x2',
      name: 'Stellar Catalyst',
      description: 'Dyson Swarm ×2',
      cost: 300000,
      target: UpgradeTarget.generatorOutput,
      targetGeneratorId: 'dyson',
      multiplier: 2.0,
    ),
    Upgrade(
      id: 'blackhole_x3',
      name: 'Event Horizon',
      description: 'Black-Hole Accretor ×3',
      cost: 50000000,
      target: UpgradeTarget.generatorOutput,
      targetGeneratorId: 'blackhole',
      multiplier: 3.0,
    ),
  ];
});

class GameNotifier extends Notifier<GameState> {
  Timer? _timer;

  @override
  GameState build() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _tick();
    });

    ref.onDispose(() {
      _timer?.cancel();
    });

    final initialGens = ref.watch(initialGeneratorsProvider);
    final initialUpgs = ref.watch(initialUpgradesProvider);
    return GameState.initial(
      initialGenerators: initialGens,
      initialUpgrades: initialUpgs,
    );
  }

  void _tick() {
    final engine = ref.read(gameEngineProvider);
    final now = ref.read(timeProvider)();
    state = engine.processTick(state, now);
  }

  void buyGenerator(String generatorId) {
    final engine = ref.read(gameEngineProvider);
    final now = ref.read(timeProvider)();
    state = engine.buyGenerator(state, generatorId, now);
  }

  void buyUpgrade(String upgradeId) {
    final engine = ref.read(gameEngineProvider);
    final now = ref.read(timeProvider)();
    state = engine.buyUpgrade(state, upgradeId, now);
  }

  void prestige() {
    final engine = ref.read(gameEngineProvider);
    final now = ref.read(timeProvider)();
    final gens = ref.read(initialGeneratorsProvider);
    final upgs = ref.read(initialUpgradesProvider);
    state = engine.prestige(state, gens, upgs, now);
  }
}

final gameProvider = NotifierProvider<GameNotifier, GameState>(() {
  return GameNotifier();
});
