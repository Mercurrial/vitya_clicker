/// Сейвы для осмотра игры глазами: начало, середина, поздняя игра.
///
/// Вёрстка ломалась именно там, куда не доходят руками: длинные числа,
/// тринадцатый аппарат, открытые перки. Доиграть до этого за вечер нельзя,
/// поэтому состояние собирается здесь — тем же движком, что и в игре.
///
///   dart run tools/demo_saves.dart
///
/// Печатает по строке на стадию: `имя<TAB>сейв`. Сейв кладётся в браузере в
/// `localStorage['flutter.vitya_save_v1']` как JSON-строка, после чего страницу
/// надо перезагрузить.
library;

import 'dart:convert';
import 'dart:io';

import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/core/save.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';

void main() {
  const engine = GameEngine();
  const ser = GameSerializer();
  final t = DateTime.now().toUtc();

  GameState build({
    required Map<String, int> stills,
    required int upgrades,
    required double money,
    required double ml,
    required double sort,
    required double lifetime,
    int hangovers = 0,
    double claimed = 0,
  }) {
    var s = newGame(content: kGenerators, upgrades: kUpgrades, now: t);
    s = s.copyWith(resources: s.resources.copyWith(money: 1e300));
    stills.forEach((id, n) => s = engine.buyGeneratorBulk(s, id, n, t));
    for (final u in kUpgrades.take(upgrades)) {
      s = engine.buyUpgrade(s, u.id, t);
    }
    for (var i = 0; i < 40; i++) {
      s = engine.registerTouch(s, t);
    }
    s = engine.advanceSort(s, sort);
    s = s.copyWith(
      resources: s.resources.copyWith(money: money, ml: ml),
      prestige: s.prestige.copyWith(
        totalEverEarned: lifetime,
        hangovers: hangovers,
        claimedMl: claimed,
      ),
    );
    return engine.checkAchievements(s).state;
  }

  final stages = <String, GameState>{
    'early': build(
      stills: {'banka': 6},
      upgrades: 1,
      money: 240,
      ml: 900,
      sort: 0.4,
      lifetime: 4e4,
    ),
    'mid': build(
      stills: {'banka': 40, 'bidon': 22, 'flyaga': 11, 'dedov': 4},
      upgrades: 8,
      money: 3.4e6,
      ml: 5.2e5,
      sort: 2.3,
      lifetime: 3.1e8,
      hangovers: 1,
      claimed: 2.5e8,
    ),
    'late': build(
      stills: {
        for (final g in kGeneratorNames.take(12)) g.id: 150 - 10 * kGeneratorNames.indexOf(g),
      },
      upgrades: 20,
      money: 8.7e21,
      ml: 3.3e19,
      sort: 4.6,
      lifetime: 6.4e24,
      hangovers: 9,
      claimed: 1e23,
    ),
    // Вся лестница, с коллайдером. В 'late' его нет намеренно — там полка
    // смотрится, когда до конца ещё есть куда расти; а коллайдер на полу
    // без этой стадии не видел никто.
    'final': build(
      stills: {
        for (final g in kGeneratorNames) g.id: 160 - 10 * kGeneratorNames.indexOf(g),
      },
      upgrades: kUpgrades.length,
      money: 4.1e27,
      ml: 2.2e25,
      sort: 4.9,
      lifetime: 9.9e30,
      hangovers: 14,
      claimed: 5e29,
    ),
  };

  stages.forEach((name, s) {
    final json = ser.toJson(s, lastSeenMillis: t.millisecondsSinceEpoch);
    stdout.writeln('$name\t${jsonEncode(const SaveCodec().encode(json))}');
  });
}
