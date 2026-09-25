import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/balance.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/upgrade.dart';

/// Улучшения по формуле вдоль всей лестницы (docs/PLAN-1.0.md, раздел 3).
///
/// Раньше их было 22 руками, и они обрывались на 60 млн ₽: дальше рост шёл
/// только поштучной покупкой, и заход после первого часа вставал. Теперь на
/// каждой ступени — три «×2 этой ступени», «все аппараты» и «цена за литр».
void main() {
  final t0 = DateTime.utc(2026);

  group('Состав', () {
    test('на каждой ступени пять улучшений, всего около семидесяти', () {
      for (final g in kGeneratorNames) {
        final own = kUpgrades.where((u) => u.id.contains('_${g.id}')).toList();
        expect(own, hasLength(5), reason: 'ступень ${g.id}');
        expect(
          own.where((u) =>
              u.target == UpgradeTarget.generatorOutput && u.targetGeneratorId == g.id),
          hasLength(3),
        );
        expect(own.where((u) => u.target == UpgradeTarget.allGenerators), hasLength(1));
        expect(own.where((u) => u.target == UpgradeTarget.quality), hasLength(1));
      }
      expect(kUpgrades.length, inInclusiveRange(65, 80));
    });

    test('строки названий идут по лестнице — ни одна не уехала на соседа', () {
      expect([for (final t in kTierUpgrades) t.generatorId],
          [for (final g in kGeneratorNames) g.id]);
    });

    test('названия написаны все и не повторяются', () {
      final names = [for (final u in kUpgrades) u.name];
      expect(names.every((n) => n.trim().isNotEmpty), isTrue);
      expect(names.toSet(), hasLength(names.length));
    });
  });

  group('Id — навсегда', () {
    // Купленное хранится в сейве списком id. После выпуска переименованный
    // id — это молча отобранная покупка.
    test('все по одной схеме и не повторяются', () {
      final ladder = [for (final g in kGeneratorNames) g.id].join('|');
      final scheme = RegExp('^(gen_($ladder)_[1-9]|(all|price)_($ladder)|(heat|tank|syn)_[1-9][0-9]*)\$');
      final ids = [for (final u in kUpgrades) u.id];
      for (final id in ids) {
        expect(scheme.hasMatch(id), isTrue, reason: '«$id» не по схеме');
      }
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('правка чисел не трогает id', () {
      final before = [for (final u in kUpgrades) u.id];
      final after = withBalance(
        kBalance.copyWith(tierCostRatio: 10, tierUpgradeCosts: [1, 2, 3]),
        () => [for (final u in kUpgrades) u.id],
      );
      expect(after, before);
    });
  });

  group('Цены — из баланса', () {
    test('в базовых ценах своей ступени', () {
      for (final (i, g) in kGenerators.indexed) {
        final t = kTierUpgrades[i];
        for (final (level, factor) in kBalance.tierUpgradeCosts.indexed) {
          final u = kUpgrades.firstWhere((u) => u.id == 'gen_${t.generatorId}_${level + 1}');
          expect(u.cost, closeTo(g.baseCost * factor, g.baseCost * factor * 1e-9));
        }
        expect(kUpgrades.firstWhere((u) => u.id == 'all_${g.id}').cost,
            closeTo(g.baseCost * kBalance.globalUpgradeCost, g.baseCost * 1e-6));
        expect(kUpgrades.firstWhere((u) => u.id == 'price_${g.id}').cost,
            closeTo(g.baseCost * kBalance.qualityUpgradeCost, g.baseCost * 1e-6));
      }
    });

    test('множители не кончаются до конца лестницы', () {
      // Та самая поломка: последнее улучшение стоило 60 млн ₽, а лестница
      // уходила на десять порядков дальше.
      final lastUpgrade = kUpgrades.map((u) => u.cost).reduce((a, b) => a > b ? a : b);
      expect(lastUpgrade, greaterThan(kGenerators.last.baseCost));
    });

    test('лестница пересобирается под новый баланс', () {
      final cost = kUpgrades.firstWhere((u) => u.id == 'gen_bidon_1').cost;
      withBalance(kBalance.copyWith(tierCostRatio: kBalance.tierCostRatio * 2), () {
        expect(kUpgrades.firstWhere((u) => u.id == 'gen_bidon_1').cost, closeTo(cost * 2, 1e-6));
      });
      expect(kUpgrades.firstWhere((u) => u.id == 'gen_bidon_1').cost, closeTo(cost, 1e-6));
    });
  });

  group('Действие', () {
    const engine = GameEngine();

    GameState rich() {
      final s = GameState.initial(
        initialGenerators: kGenerators,
        initialUpgrades: kUpgrades,
        lastUpdateTime: t0,
      );
      var r = s.copyWith(resources: s.resources.copyWith(money: 1e40));
      r = engine.buyGeneratorBulk(r, 'banka', 5, t0);
      return engine.buyGeneratorBulk(r, 'bidon', 5, t0);
    }

    test('«×2 ступени» удваивает только свою ступень', () {
      final s = rich();
      final after = engine.buyUpgrade(s, 'gen_bidon_2', t0);
      expect(after.upgrades.generatorMultiplier('bidon'), 2);
      expect(after.upgrades.generatorMultiplier('banka'), 1);
    });

    test('«все аппараты» удваивает всю лестницу', () {
      final s = rich();
      final after = engine.buyUpgrade(s, 'all_zavod', t0);
      expect(after.mlPerSecond, closeTo(s.mlPerSecond * 2, 1e-9));
    });

    test('в описании — то, что записано в балансе', () {
      final u = kUpgrades.firstWhere((u) => u.id == 'price_tanker');
      expect(u.description, contains('1.3'));
      expect(u.multiplier, kBalance.qualityUpgradeMultiplier);
    });
  });
}
