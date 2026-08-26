import 'package:equatable/equatable.dart';

import '../engine/production.dart';
import 'clicker_state.dart';
import 'generator.dart';
import 'generators_state.dart';
import 'prestige_state.dart';
import 'resources_state.dart';
import 'upgrade.dart';
import 'upgrades_state.dart';

/// Полное состояние игры. Всё, что нужно для сейва и для расчёта дохода.
class GameState extends Equatable {
  final ResourcesState resources;
  final ClickerState clicker;
  final GeneratorsState generators;
  final UpgradesState upgrades;
  final PrestigeState prestige;
  final DateTime lastUpdateTime;

  /// Кэш суммарного дохода — пересчитывается только при изменении того,
  /// от чего он зависит (аппараты, апгрейды, мудрость).
  final double litresPerSecond;

  const GameState({
    required this.resources,
    required this.clicker,
    required this.generators,
    required this.upgrades,
    required this.prestige,
    required this.lastUpdateTime,
    required this.litresPerSecond,
  });

  factory GameState.initial({
    required List<Generator> initialGenerators,
    List<Upgrade>? initialUpgrades,
    PrestigeState prestige = const PrestigeState(),
    DateTime? lastUpdateTime,
  }) {
    final gens = GeneratorsState(items: List.unmodifiable(initialGenerators));
    final ups = UpgradesState(
      items: initialUpgrades != null ? List.unmodifiable(initialUpgrades) : const [],
    );
    return GameState(
      resources: const ResourcesState(),
      clicker: const ClickerState(),
      generators: gens,
      upgrades: ups,
      prestige: prestige,
      lastUpdateTime: lastUpdateTime ?? DateTime.now(),
      litresPerSecond: Production.litresPerSecond(gens, ups, prestige),
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
    final nextGens = generators ?? this.generators;
    final nextUps = upgrades ?? this.upgrades;
    final nextPrestige = prestige ?? this.prestige;

    final recompute = generators != null || upgrades != null || prestige != null;
    final nextRate = recompute
        ? Production.litresPerSecond(nextGens, nextUps, nextPrestige)
        : litresPerSecond;

    return GameState(
      resources: resources ?? this.resources,
      clicker: clicker ?? this.clicker,
      generators: nextGens,
      upgrades: nextUps,
      prestige: nextPrestige,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      litresPerSecond: nextRate,
    );
  }

  /// Литры за одно нажатие: база × апгрейды тапа × мудрость.
  ///
  /// Намеренно НЕ зависит от литров в секунду — иначе автокликер становился бы
  /// главной стратегией поздней игры.
  double get tapPower =>
      clicker.baseTapPower * upgrades.tapMultiplier * prestige.globalMultiplier;

  @override
  List<Object?> get props => [
        resources,
        clicker,
        generators,
        upgrades,
        prestige,
        lastUpdateTime,
        litresPerSecond,
      ];

  @override
  bool get stringify => true;
}
