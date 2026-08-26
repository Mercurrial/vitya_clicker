/// Перевод состояния игры в сейв и обратно.
///
/// Ключевое решение: в сейв кладётся **только прогресс**, а не описания
/// аппаратов и апгрейдов. Аппараты хранятся как `{id: сколько куплено}`,
/// апгрейды — как список купленных id.
///
/// Благодаря этому контент можно менять безболезненно: добавили новый аппарат —
/// у старых сейвов он просто будет с нулём; удалили или переименовали —
/// неизвестный id тихо игнорируется. Если бы мы сохраняли baseCost и прочие
/// числа, любая правка баланса ломала бы сохранения.
library;

import '../models/clicker_state.dart';
import '../models/game_state.dart';
import '../models/generator.dart';
import '../models/generators_state.dart';
import '../models/prestige_state.dart';
import '../models/resources_state.dart';
import '../models/upgrade.dart';
import '../models/upgrades_state.dart';

class GameSerializer {
  const GameSerializer();

  Map<String, dynamic> toJson(GameState s, {required int lastSeenMillis}) {
    return {
      'ml': s.resources.ml,
      'taps': s.clicker.totalTaps,
      'stills': {
        for (final g in s.generators.items)
          if (g.ownedCount > 0) g.id: g.ownedCount,
      },
      'bought': [
        for (final u in s.upgrades.items)
          if (u.purchased) u.id,
      ],
      'wisdom': s.prestige.wisdom,
      'lifetime': s.prestige.totalEverEarned,
      'hangovers': s.prestige.hangovers,
      'lastSeen': lastSeenMillis,
    };
  }

  /// Собирает состояние поверх текущего описания контента.
  ///
  /// [content] и [upgrades] — актуальные определения из `lib/content`; из сейва
  /// берутся только количества и отметки о покупке.
  GameState fromJson(
    Map<String, dynamic> json, {
    required List<Generator> content,
    required List<Upgrade> upgrades,
    required DateTime now,
  }) {
    final owned = _asIntMap(json['stills']);
    final bought = _asStringSet(json['bought']);

    final gens = [
      for (final g in content) g.copyWith(ownedCount: owned[g.id] ?? 0),
    ];
    final ups = [
      for (final u in upgrades) u.copyWith(purchased: bought.contains(u.id)),
    ];

    final base = GameState.initial(
      initialGenerators: gens,
      initialUpgrades: ups,
      prestige: PrestigeState(
        wisdom: _asInt(json['wisdom']),
        totalEverEarned: _asDouble(json['lifetime']),
        hangovers: _asInt(json['hangovers']),
      ),
      lastUpdateTime: now,
    );

    return base.copyWith(
      resources: ResourcesState(ml: _asDouble(json['ml'])),
      clicker: ClickerState(totalTaps: _asInt(json['taps'])),
    );
  }

  /// Момент последнего выхода — для расчёта оффлайн-дохода.
  int? lastSeenOf(Map<String, dynamic> json) {
    final v = json['lastSeen'];
    return v is int ? v : null;
  }

  // --- Разбор с защитой от мусора: битые поля не должны ронять загрузку. ---

  static double _asDouble(dynamic v) {
    if (v is num) {
      final d = v.toDouble();
      return d.isFinite && d >= 0 ? d : 0.0;
    }
    return 0.0;
  }

  static int _asInt(dynamic v) {
    if (v is int) return v >= 0 ? v : 0;
    if (v is num) return v.toInt().clamp(0, 1 << 31);
    return 0;
  }

  static Map<String, int> _asIntMap(dynamic v) {
    if (v is! Map) return const {};
    final out = <String, int>{};
    v.forEach((key, value) {
      if (key is String) {
        final n = _asInt(value);
        if (n > 0) out[key] = n;
      }
    });
    return out;
  }

  static Set<String> _asStringSet(dynamic v) {
    if (v is! List) return const {};
    return {for (final x in v) if (x is String) x};
  }
}

/// Пустое состояние для новой игры.
GameState newGame({
  required List<Generator> content,
  required List<Upgrade> upgrades,
  required DateTime now,
}) =>
    GameState.initial(
      initialGenerators: content,
      initialUpgrades: upgrades,
      lastUpdateTime: now,
    );

/// Хелпер: [GeneratorsState] из списка — держим рядом, чтобы сериализатор
/// оставался единственным местом сборки состояния из данных.
GeneratorsState generatorsFrom(List<Generator> items) =>
    GeneratorsState(items: List.unmodifiable(items));

/// То же для апгрейдов.
UpgradesState upgradesFrom(List<Upgrade> items) =>
    UpgradesState(items: List.unmodifiable(items));
