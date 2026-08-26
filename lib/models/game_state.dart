import 'package:equatable/equatable.dart';

import '../engine/production.dart';
import 'achievements_state.dart';
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
  final AchievementsState achievements;
  final DateTime lastUpdateTime;

  /// Кэш суммарного дохода в мл/с — пересчитывается только при изменении того,
  /// от чего он зависит (аппараты, апгрейды, мудрость).
  final double mlPerSecond;

  const GameState({
    required this.resources,
    required this.clicker,
    required this.generators,
    required this.upgrades,
    required this.prestige,
    required this.achievements,
    required this.lastUpdateTime,
    required this.mlPerSecond,
  });

  factory GameState.initial({
    required List<Generator> initialGenerators,
    List<Upgrade>? initialUpgrades,
    PrestigeState prestige = const PrestigeState(),
    AchievementsState achievements = const AchievementsState(),
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
      achievements: achievements,
      lastUpdateTime: lastUpdateTime ?? DateTime.now(),
      mlPerSecond: Production.mlPerSecond(gens, ups, prestige, achievements.multiplier),
    );
  }

  GameState copyWith({
    ResourcesState? resources,
    ClickerState? clicker,
    GeneratorsState? generators,
    UpgradesState? upgrades,
    PrestigeState? prestige,
    AchievementsState? achievements,
    DateTime? lastUpdateTime,
  }) {
    final nextGens = generators ?? this.generators;
    final nextUps = upgrades ?? this.upgrades;
    final nextPrestige = prestige ?? this.prestige;
    final nextAch = achievements ?? this.achievements;

    final recompute = generators != null ||
        upgrades != null ||
        prestige != null ||
        achievements != null;
    final nextRate = recompute
        ? Production.mlPerSecond(nextGens, nextUps, nextPrestige, nextAch.multiplier)
        : mlPerSecond;

    return GameState(
      resources: resources ?? this.resources,
      clicker: clicker ?? this.clicker,
      generators: nextGens,
      upgrades: nextUps,
      prestige: nextPrestige,
      achievements: nextAch,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      mlPerSecond: nextRate,
    );
  }

  /// Сколько влезает в бак.
  double get tankCapacity => Production.tankCapacity(upgrades);

  /// Бак полон — аппараты стоят, пора продавать.
  bool get isTankFull => resources.ml >= tankCapacity - 1e-9;

  /// Заполненность бака, 0..1 — для шкалы в интерфейсе.
  double get tankFraction =>
      tankCapacity <= 0 ? 0 : (resources.ml / tankCapacity).clamp(0.0, 1.0);

  /// Ручная отдача за нажатие, в мл.
  ///
  /// Берётся большее из двух: плоская база (она держит самое начало, когда
  /// аппаратов ещё нет) и доля секунды текущего производства (она не даёт
  /// нажатию обесцениться позже). Так тап остаётся осмысленным на всей
  /// дистанции, а не умирает через пять минут.
  ///
  /// Основная ценность тапа всё равно не тут, а в жаре — он множит весь поток.
  double get tapYield {
    final flat = clicker.baseTapPower *
        upgrades.tapMultiplier *
        prestige.globalMultiplier *
        achievements.multiplier;
    final share = mlPerSecond * Production.tapSeconds;
    return flat > share ? flat : share;
  }

  @override
  List<Object?> get props => [
        resources,
        clicker,
        generators,
        upgrades,
        prestige,
        achievements,
        lastUpdateTime,
        mlPerSecond,
      ];

  @override
  bool get stringify => true;
}
