import 'package:equatable/equatable.dart';
import '../engine/production.dart';
import 'resources_state.dart';
import 'clicker_state.dart';
import 'generators_state.dart';
import 'generator.dart';
import 'upgrade.dart';
import 'upgrades_state.dart';
import 'prestige_state.dart';

class GameState extends Equatable {
  final ResourcesState resources;
  final ClickerState clicker;
  final GeneratorsState generators;
  final UpgradesState upgrades;
  final PrestigeState prestige;
  final DateTime lastUpdateTime;
  final double goldPerSecond;

  const GameState({
    required this.resources,
    required this.clicker,
    required this.generators,
    required this.upgrades,
    required this.prestige,
    required this.lastUpdateTime,
    required this.goldPerSecond,
  });

  factory GameState.initial({
    required List<Generator> initialGenerators,
    List<Upgrade>? initialUpgrades,
    PrestigeState prestige = const PrestigeState(),
    DateTime? lastUpdateTime,
  }) {
    final genState = GeneratorsState(items: List.unmodifiable(initialGenerators));
    final upgState = UpgradesState(
        items: initialUpgrades != null ? List.unmodifiable(initialUpgrades) : const []);
    return GameState(
      resources: const ResourcesState(),
      clicker: const ClickerState(),
      generators: genState,
      upgrades: upgState,
      prestige: prestige,
      lastUpdateTime: lastUpdateTime ?? DateTime.now(),
      goldPerSecond: Production.goldPerSecond(genState, upgState, prestige),
    );
  }

  GameState copyWith({
    ResourcesState? resources,
    ClickerState? clicker,
    GeneratorsState? generators,
    UpgradesState? upgrades,
    PrestigeState? prestige,
    DateTime? lastUpdateTime,
  }) {
    final nextGenerators = generators ?? this.generators;
    final nextUpgrades = upgrades ?? this.upgrades;
    final nextPrestige = prestige ?? this.prestige;

    // goldPerSecond depends on generators, upgrades and prestige (shards).
    final recompute = generators != null || upgrades != null || prestige != null;
    final newGps = recompute
        ? Production.goldPerSecond(nextGenerators, nextUpgrades, nextPrestige)
        : goldPerSecond;

    return GameState(
      resources: resources ?? this.resources,
      clicker: clicker ?? this.clicker,
      generators: nextGenerators,
      upgrades: nextUpgrades,
      prestige: nextPrestige,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      goldPerSecond: newGps,
    );
  }

  @override
  List<Object?> get props =>
      [resources, clicker, generators, upgrades, prestige, lastUpdateTime, goldPerSecond];

  @override
  bool get stringify => true;
}
