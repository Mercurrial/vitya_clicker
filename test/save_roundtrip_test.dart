import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/generator.dart';
import 'package:idle_game/models/prestige_state.dart';

void main() {
  const ser = GameSerializer();
  const engine = GameEngine();
  final now = DateTime.utc(2026, 3, 1);

  GameState build() => GameState.initial(
        initialGenerators: kGenerators,
        initialUpgrades: kUpgrades,
        lastUpdateTime: now,
      );

  GameState played() {
    var s = build();
    s = s.copyWith(resources: s.resources.copyWith(ml: 500000));
    for (var i = 0; i < 12; i++) {
      s = engine.buyGenerator(s, 'banka', now);
    }
    s = engine.buyGenerator(s, 'bidon', now);
    s = engine.buyUpgrade(s, 'tap_ruka', now);
    s = engine.processTap(s, now);
    return s;
  }

  group('Круг сохранение → загрузка', () {
    test('прогресс восстанавливается полностью', () {
      final before = played();
      final json = ser.toJson(before, lastSeenMillis: 1700000000000);
      final after = ser.fromJson(
        json,
        content: kGenerators,
        upgrades: kUpgrades,
        now: now,
      );

      expect(after.resources.ml, closeTo(before.resources.ml, 1e-9));
      expect(after.clicker.totalTaps, before.clicker.totalTaps);
      expect(after.mlPerSecond, closeTo(before.mlPerSecond, 1e-9));

      int owned(GameState s, String id) =>
          s.generators.items.firstWhere((g) => g.id == id).ownedCount;
      expect(owned(after, 'banka'), owned(before, 'banka'));
      expect(owned(after, 'bidon'), owned(before, 'bidon'));

      final bought = after.upgrades.items.where((u) => u.purchased).map((u) => u.id);
      expect(bought, contains('tap_ruka'));
      expect(after.tapYield, closeTo(before.tapYield, 1e-9));
    });

    test('мудрость и история переживают сохранение', () {
      var s = build().copyWith(
        prestige: const PrestigeState(
          wisdom: 7,
          totalEverEarned: 5e7,
          hangovers: 3,
        ),
      );
      s = ser.fromJson(
        ser.toJson(s, lastSeenMillis: 1),
        content: kGenerators,
        upgrades: kUpgrades,
        now: now,
      );
      expect(s.prestige.wisdom, 7);
      expect(s.prestige.totalEverEarned, 5e7);
      expect(s.prestige.hangovers, 3);
    });

    test('метка последнего выхода читается обратно', () {
      final json = ser.toJson(build(), lastSeenMillis: 1712345678901);
      expect(ser.lastSeenOf(json), 1712345678901);
    });
  });

  group('Сейв переживает изменения контента', () {
    test('исчезнувший из игры аппарат просто игнорируется', () {
      final json = ser.toJson(played(), lastSeenMillis: 1);
      (json['stills'] as Map)['аппарат_которого_больше_нет'] = 99;

      final s = ser.fromJson(
        json,
        content: kGenerators,
        upgrades: kUpgrades,
        now: now,
      );
      expect(s.generators.items.length, kGenerators.length);
      expect(s.generators.items.any((g) => g.ownedCount == 99), isFalse);
    });

    test('новый аппарат появляется с нулём, старый прогресс цел', () {
      final json = ser.toJson(played(), lastSeenMillis: 1);

      const extra = Generator(
        id: 'novyi',
        name: 'Новый аппарат',
        baseCost: 1,
        costGrowthFactor: 1.1,
        baseProduction: 1,
      );
      final s = ser.fromJson(
        json,
        content: [...kGenerators, extra],
        upgrades: kUpgrades,
        now: now,
      );

      expect(s.generators.items.last.id, 'novyi');
      expect(s.generators.items.last.ownedCount, 0);
      expect(s.generators.items.first.ownedCount, 12);
    });

    test('купленный, но выброшенный апгрейд не ломает загрузку', () {
      final json = ser.toJson(played(), lastSeenMillis: 1);
      (json['bought'] as List).add('апгрейд_которого_нет');

      final s = ser.fromJson(
        json,
        content: kGenerators,
        upgrades: kUpgrades,
        now: now,
      );
      expect(s.upgrades.items.length, kUpgrades.length);
      expect(s.upgrades.items.where((u) => u.purchased).length, 1);
    });
  });

  group('Мусор в сейве не роняет игру', () {
    test('пустой объект даёт корректную новую игру', () {
      final s = ser.fromJson(
        <String, dynamic>{},
        content: kGenerators,
        upgrades: kUpgrades,
        now: now,
      );
      expect(s.resources.ml, 0);
      expect(s.prestige.wisdom, 0);
      expect(s.generators.items.length, kGenerators.length);
    });

    test('поля неверных типов и отрицательные значения обнуляются', () {
      final s = ser.fromJson(
        {
          'ml': 'много',
          'taps': -5,
          'stills': 'не карта',
          'bought': 'не список',
          'wisdom': null,
          'lifetime': double.nan,
        },
        content: kGenerators,
        upgrades: kUpgrades,
        now: now,
      );
      expect(s.resources.ml, 0);
      expect(s.clicker.totalTaps, 0);
      expect(s.prestige.wisdom, 0);
      expect(s.prestige.totalEverEarned, 0);
      expect(s.upgrades.items.every((u) => !u.purchased), isTrue);
    });
  });
}
