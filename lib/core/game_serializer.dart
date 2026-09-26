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

import '../content/achievements.dart';
import '../content/balance.dart';
import '../content/game_content.dart';
import '../content/sorts.dart';
import '../content/wisdom_milestones.dart';
import '../models/achievements_state.dart';
import '../models/sort_state.dart';
import '../models/clicker_state.dart';
import '../models/flux_state.dart';
import '../models/game_state.dart';
import '../models/generator.dart';
import '../models/generators_state.dart';
import '../models/portal_state.dart';
import '../models/prestige_state.dart';
import '../models/resources_state.dart';
import '../models/stats_state.dart';
import '../models/upgrade.dart';
import '../models/upgrades_state.dart';

class GameSerializer {
  const GameSerializer();

  Map<String, dynamic> toJson(GameState s, {required int lastSeenMillis}) {
    return {
      'ml': s.resources.ml,
      'money': s.resources.money,
      'taps': s.clicker.totalTaps,
      'stills': {
        for (final g in s.generators.items)
          if (g.ownedCount > 0) g.id: g.ownedCount,
      },
      'bought': [
        for (final u in s.upgrades.items)
          if (u.purchased) u.id,
      ],
      'achievements': s.achievements.unlocked.toList(),
      // Сорт — свойство того, что стоит в баке, поэтому уходит в сейв вместе
      // с объёмом: вернувшись, игрок находит свой товар таким, каким оставил.
      'sortIndex': s.sort.index,
      'sortProgress': s.sort.progress,
      // Факт, а не оценка: сколько было нагнано на момент последнего
      // похмелья. Мудрость из него вычисляется — см. PrestigeState.
      'claimedMl': s.prestige.claimedMl,
      'bonusWisdom': s.prestige.bonusWisdom,
      'lifetime': s.prestige.totalEverEarned,
      'hangovers': s.prestige.hangovers,
      // Наивысшая ступень — id аппарата, а не номер: номер уедет, если в
      // лестницу вставят ступень. Поле гаража, как и всё выше.
      if (s.maxTier case final tier?) 'maxTier': tier,
      // Статистика — своим блоком, а не россыпью ключей верхнего уровня: так
      // видно, какие поля к ней относятся, и следующему блоку есть куда лечь
      // рядом, не перемешиваясь.
      'stats': _statsToJson(s.stats),
      // Поток: накопленное — ресурс, как деньги; уровни — покупки. Скорость
      // начисления, копилка и цены вычисляются из уровней. Ключи добавочные:
      // в сейве без них читается ноль, и миграция не нужна.
      'flux': s.flux.seconds,
      'fluxRate': s.flux.rateLevel,
      'fluxBank': s.flux.bankLevel,
      // Портал — общий ключ, а не гаражный: снимки лежат по миру, из
      // которого портал открыт, и снимок следующего мира ляжет рядом.
      // Нет порталов — нет ключа: отсутствие и значит «не открыт».
      if (!s.portal.isEmpty) 'portal': _portalToJson(s.portal),
      // Под каким балансом игрок в последний раз видел игру. По этому числу
      // при обновлении показывается список изменений и начисляется
      // компенсация.
      'balanceVersion': kBalanceVersion,
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

    // Неизвестные идентификаторы отсеиваем: контент меняется, сейв не должен
    // тащить достижения, которых больше нет.
    final known = {for (final a in kAllAchievements) a.id};
    final unlocked = _asStringSet(json['achievements']).intersection(known);

    final base = GameState.initial(
      initialGenerators: gens,
      initialUpgrades: ups,
      achievements: AchievementsState(unlocked: unlocked),
      prestige: PrestigeState(
        claimedMl: _asDouble(json['claimedMl']),
        bonusWisdom: _asInt(json['bonusWisdom']),
        totalEverEarned: _asDouble(json['lifetime']),
        hangovers: _asInt(json['hangovers']),
      ),
      stats: _statsFromJson(json['stats'], now),
      flux: FluxState(
        seconds: _asDouble(json['flux']),
        rateLevel: _asInt(json['fluxRate']),
        bankLevel: _asInt(json['fluxBank']),
      ),
      portal: _portalFromJson(json['portal']),
      // Не меньше купленного сейчас — это GameState.initial досчитает сам.
      maxTier: switch (json['maxTier']) { final String id => id, _ => null },
      lastUpdateTime: now,
    );

    return base.copyWith(
      resources: ResourcesState(
        ml: _asDouble(json['ml']),
        money: _asDouble(json['money']),
      ),
      clicker: ClickerState(totalTaps: _asInt(json['taps'])),
      sort: SortState(
        index: _asInt(json['sortIndex']).clamp(0, kSorts.length - 1),
        progress: _asDouble(json['sortProgress']).clamp(0.0, 1.0),
      ),
    );
  }

  Map<String, dynamic> _statsToJson(StatsState t) => {
        'firstLaunch': t.firstLaunch.millisecondsSinceEpoch,
        'playSec': t.playSeconds,
        'holdSec': t.holdSeconds,
        'windowSec': t.windowSeconds,
        'soldMl': t.soldMl,
        'earned': t.earned,
        'sales': t.sales,
        'bestSale': t.bestSale,
        'guestSales': t.guestSales,
        'stillsBought': t.stillsBought,
        'upgradesBought': t.upgradesBought,
        'runStart': t.runStart.millisecondsSinceEpoch,
        if (t.fastestRunSeconds case final f?) 'fastestRunSec': f,
      };

  /// Статистика из сейва.
  ///
  /// В сейвах, записанных до статистики, блока нет — они читаются как новая
  /// статистика, начатая в момент загрузки. Историю им не досчитываем: до
  /// первого выпуска игроков нет (docs/DECISIONS.md), а выдуманные числа
  /// хуже нулей.
  StatsState _statsFromJson(dynamic v, DateTime now) {
    final j = v is Map ? v : const {};
    final fastest = _asDouble(j['fastestRunSec']);
    return StatsState(
      firstLaunch: _asMoment(j['firstLaunch']) ?? now,
      runStart: _asMoment(j['runStart']) ?? now,
      playSeconds: _asDouble(j['playSec']),
      holdSeconds: _asDouble(j['holdSec']),
      windowSeconds: _asDouble(j['windowSec']),
      soldMl: _asDouble(j['soldMl']),
      earned: _asDouble(j['earned']),
      sales: _asInt(j['sales']),
      bestSale: _asDouble(j['bestSale']),
      guestSales: _asInt(j['guestSales']),
      stillsBought: _asInt(j['stillsBought']),
      upgradesBought: _asInt(j['upgradesBought']),
      fastestRunSeconds: fastest > 0 ? fastest : null,
    );
  }

  /// Ключ мира в блоке `portal`.
  ///
  /// Руками, а не `World.name`: переименуй кто значение перечисления в коде —
  /// снимки у игроков молча перестали бы читаться. Новый мир без ключа здесь
  /// не соберётся: switch обязан перебрать все миры.
  static String _worldKey(World world) => switch (world) {
        World.garage => 'garage',
      };

  Map<String, dynamic> _portalToJson(PortalState p) => {
        for (final MapEntry(key: world, value: shot) in p.opened.entries)
          _worldKey(world): {
            'at': shot.at.millisecondsSinceEpoch,
            'lifetime': shot.lifetime,
            'claimedMl': shot.claimedMl,
            'bonusWisdom': shot.bonusWisdom,
            'hangovers': shot.hangovers,
            'playSec': shot.playSeconds,
          },
      };

  /// Порталы из сейва.
  ///
  /// Мусор не роняет загрузку: упади разбор здесь, читаемый сейв ушёл бы в
  /// отложенные копии как нечитаемый (`bootstrap.dart`), и игрок остался бы
  /// без гаража из-за одного лишнего ключа. Поэтому блок не того вида
  /// читается как «порталов нет», а снимок без понятного момента — как
  /// неоткрытый портал: момент и отличает снимок от набора нулей.
  PortalState _portalFromJson(dynamic v) {
    if (v is! Map) return const PortalState();
    return PortalState(Map.unmodifiable({
      for (final world in World.values)
        if (_snapshotFromJson(v[_worldKey(world)]) case final shot?) world: shot,
    }));
  }

  PortalSnapshot? _snapshotFromJson(dynamic v) {
    if (v is! Map) return null;
    final at = _asMoment(v['at']);
    if (at == null) return null;
    return PortalSnapshot(
      at: at,
      lifetime: _asDouble(v['lifetime']),
      claimedMl: _asDouble(v['claimedMl']),
      bonusWisdom: _asInt(v['bonusWisdom']),
      hangovers: _asInt(v['hangovers']),
      playSeconds: _asDouble(v['playSec']),
    );
  }

  /// Под какой версией баланса сейв был записан.
  ///
  /// Старые сейвы поля не имеют — для них это 1, то есть «до того, как баланс
  /// стали версионировать».
  int balanceVersionOf(Map<String, dynamic> json) {
    final v = json['balanceVersion'];
    return v is int && v > 0 ? v : 1;
  }

  /// Момент последнего выхода — для начисления потока за отсутствие.
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

  /// Момент времени из миллисекунд UTC. `null` — поля нет или оно битое.
  ///
  /// Не через [_asInt]: тот обрезает дробные числа до 2^31, а миллисекунды
  /// с 1970 года давно больше.
  static DateTime? _asMoment(dynamic v) {
    // Больше 8.64e15 DateTime не принимает и бросает исключение, а битое
    // поле не должно ронять загрузку.
    if (v is! num || !v.isFinite || v <= 0 || v > 8.64e15) return null;
    return DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
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

/// Состояние для новой игры. Стартовый набор — [startingGenerators].
GameState newGame({
  required List<Generator> content,
  required List<Upgrade> upgrades,
  required DateTime now,
}) =>
    GameState.initial(
      initialGenerators: startingGenerators(content),
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
