import 'package:equatable/equatable.dart';

import '../engine/production.dart';
import 'achievements_state.dart';
import 'clicker_state.dart';
import 'flux_state.dart';
import 'generator.dart';
import 'generators_state.dart';
import 'portal_state.dart';
import 'prestige_state.dart';
import 'resources_state.dart';
import 'sort_state.dart';
import 'stats_state.dart';
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

  /// Сорт того, что сейчас в баке. Поднимается жаром, горит от перегрева.
  final SortState sort;

  /// Статистика игрока — переживает похмелье, в производство не входит.
  final StatsState stats;

  /// Поток времени — копится за AFK, тратится ускорением. Переживает похмелье.
  final FluxState flux;

  /// Открытые порталы — снимки, записанные первой покупкой коллайдера.
  /// Переживает похмелье.
  final PortalState portal;

  /// Наивысшая ступень лестницы за всё время — id аппарата. `null` — не
  /// куплено ни одной ступени (в игре так не бывает: банка есть с начала).
  ///
  /// Id, а не номер ступени: номер уедет, если в лестницу вставят ступень,
  /// и игрок молча окажется на соседней. Id вечные (`game_content.dart`).
  ///
  /// Только растёт и переживает похмелье: похмелье забирает аппараты, а не
  /// то, докуда Витя дошёл. Задним числом её не восстановить, поэтому
  /// поднимается она сама — в [GameState.initial] и [copyWith], стоит
  /// аппаратам поменяться, — а не в каждом месте, где их покупают.
  final String? maxTier;

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
    required this.sort,
    required this.stats,
    this.flux = const FluxState(),
    this.portal = const PortalState(),
    this.maxTier,
    required this.lastUpdateTime,
    required this.mlPerSecond,
  });

  factory GameState.initial({
    required List<Generator> initialGenerators,
    List<Upgrade>? initialUpgrades,
    PrestigeState prestige = const PrestigeState(),
    AchievementsState achievements = const AchievementsState(),
    StatsState? stats,
    FluxState flux = const FluxState(),
    PortalState portal = const PortalState(),
    String? maxTier,
    DateTime? lastUpdateTime,
  }) {
    final at = lastUpdateTime ?? DateTime.now();
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
      sort: const SortState(),
      stats: stats ?? StatsState.startedAt(at),
      flux: flux,
      portal: portal,
      maxTier: _higherTier(maxTier, gens),
      lastUpdateTime: at,
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
    SortState? sort,
    StatsState? stats,
    FluxState? flux,
    PortalState? portal,
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
      sort: sort ?? this.sort,
      stats: stats ?? this.stats,
      flux: flux ?? this.flux,
      portal: portal ?? this.portal,
      maxTier: generators != null ? _higherTier(maxTier, nextGens) : maxTier,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      mlPerSecond: nextRate,
    );
  }

  /// Выше из двух: ступень [reached] или старшая из купленных в [gens].
  ///
  /// Порядок ступеней — порядок в [gens], то есть в лестнице. Id, которого
  /// в лестнице нет, не в счёт: сравнить его не с чем, а оставить — значит
  /// держать ступень, которая может оказаться ниже купленной.
  static String? _higherTier(String? reached, GeneratorsState gens) {
    final items = gens.items;
    var top = items.indexWhere((g) => g.id == reached);
    for (var i = items.length - 1; i > top; i--) {
      if (items[i].ownedCount > 0) {
        top = i;
        break;
      }
    }
    return top < 0 ? null : items[top].id;
  }

  /// Сколько влезает в бак. Растёт вместе с производством, иначе экспонента
  /// обгоняет тару и игра превращается в дежурство у кнопки.
  double get tankCapacity => Production.tankCapacity(upgrades, mlPerSecond);

  /// На сколько времени хватит бака при текущем потоке.
  Duration get tankBuffer => Production.tankBuffer(upgrades, mlPerSecond);

  /// Бак полон — аппараты стоят, пора продавать.
  bool get isTankFull => resources.ml >= tankCapacity - 1e-9;

  /// Заполненность бака, 0..1 — для шкалы в интерфейсе.
  double get tankFraction =>
      tankCapacity <= 0 ? 0 : (resources.ml / tankCapacity).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [
        resources,
        clicker,
        generators,
        upgrades,
        prestige,
        achievements,
        sort,
        stats,
        flux,
        portal,
        maxTier,
        lastUpdateTime,
        mlPerSecond,
      ];

  @override
  bool get stringify => true;
}
