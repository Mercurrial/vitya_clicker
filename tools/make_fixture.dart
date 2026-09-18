/// Снять эталонный сейв текущей версии.
///
/// Запускать ОДИН РАЗ при выпуске версии:
///   dart run tools/make_fixture.dart 1.0.0
///
/// Полученный файл больше не правится никогда: это снимок того, что реально
/// лежит у игроков. Каждая следующая версия обязана его открыть — см.
/// test/release_contract_test.dart.
library;

import 'dart:io';

import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/core/save.dart';
import 'package:idle_game/engine/game_engine.dart';

void main(List<String> args) {
  final version = args.isEmpty ? 'dev' : args.first;
  const engine = GameEngine();
  const ser = GameSerializer();
  final t = DateTime.utc(2026);

  // Не новая игра, а середина партии: куплено разное, взяты улучшения,
  // накоплена история, доведён сорт. Пустой сейв ничего бы не проверял.
  var s = newGame(content: kGenerators, upgrades: kUpgrades, now: t);
  s = s.copyWith(resources: s.resources.copyWith(money: 5e7));
  for (final (id, n) in [('banka', 32), ('bidon', 14), ('flyaga', 6), ('dedov', 2)]) {
    s = engine.buyGeneratorBulk(s, id, n, t);
  }
  for (final u in kUpgrades.take(8)) {
    s = engine.buyUpgrade(s, u.id, t);
  }
  s = engine.registerTouch(s, t);
  s = engine.advanceSort(s, 2.4);
  s = engine.checkAchievements(s).state;
  s = s.copyWith(
    resources: s.resources.copyWith(ml: 12345.6, money: 98765.4),
    prestige: s.prestige.copyWith(totalEverEarned: 8.4e9, hangovers: 1),
  );

  final json = ser.toJson(s, lastSeenMillis: 1800000000000);
  final path = 'test/fixtures/save_$version.json';
  File(path).writeAsStringSync(const SaveCodec().encode(json));
  stdout.writeln('записан $path');
  stdout.writeln('ЭТОТ ФАЙЛ БОЛЬШЕ НЕ ПРАВИТСЯ.');
}
