import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/engine/market.dart';
import 'package:idle_game/models/upgrade.dart';
import 'package:idle_game/models/upgrades_state.dart';

void main() {
  UpgradesState withPurchased(Set<String> ids) => UpgradesState(
        items: [
          for (final u in kUpgrades) u.copyWith(purchased: ids.contains(u.id)),
        ],
      );

  final none = withPurchased(const {});

  group('Волна рынка', () {
    test('детерминирована: один момент — одна цена', () {
      final t = DateTime.utc(2026, 5, 17, 13, 45, 12);
      expect(Market.wave(t), Market.wave(t));
    });

    test('не зависит от часового пояса', () {
      final utc = DateTime.utc(2026, 5, 17, 13, 0, 0);
      final local = utc.toLocal();
      expect(Market.wave(local), closeTo(Market.wave(utc), 1e-12));
    });

    test('держится в заданных пределах', () {
      // Проходим сутки с шагом в 7 секунд — этого хватает, чтобы поймать
      // и пики, и провалы обеих волн.
      var lo = double.infinity;
      var hi = -double.infinity;
      var t = DateTime.utc(2026, 5, 17);
      for (var i = 0; i < 12343; i++) {
        final w = Market.wave(t);
        if (w < lo) lo = w;
        if (w > hi) hi = w;
        t = t.add(const Duration(seconds: 7));
      }
      expect(lo, greaterThanOrEqualTo(1 - Market.swing - 1e-9));
      expect(hi, lessThanOrEqualTo(1 + Market.swing + 1e-9));
    });

    test('действительно ходит, а не стоит на месте', () {
      final a = Market.wave(DateTime.utc(2026, 5, 17, 12, 0, 0));
      final b = Market.wave(DateTime.utc(2026, 5, 17, 12, 4, 0));
      expect((a - b).abs(), greaterThan(0.02));
    });
  });

  group('Цена', () {
    test('без улучшений колеблется вокруг базовой', () {
      final t = DateTime.utc(2026, 5, 17, 9, 30);
      final price = Market.pricePerMl(t, none);
      expect(price, greaterThan(Market.basePricePerMl * (1 - Market.swing) - 1e-9));
      expect(price, lessThan(Market.basePricePerMl * (1 + Market.swing) + 1e-9));
    });

    test('качество поднимает цену ровно на свой множитель', () {
      final t = DateTime.utc(2026, 5, 17, 9, 30);
      final better = withPurchased({'q_peregonka'});
      final factor = kUpgrades.firstWhere((u) => u.id == 'q_peregonka').multiplier;

      expect(
        Market.pricePerMl(t, better),
        closeTo(Market.pricePerMl(t, none) * factor, 1e-12),
      );
    });

    test('несколько улучшений качества перемножаются', () {
      final both = withPurchased({'q_peregonka', 'q_filtr'});
      final f1 = kUpgrades.firstWhere((u) => u.id == 'q_peregonka').multiplier;
      final f2 = kUpgrades.firstWhere((u) => u.id == 'q_filtr').multiplier;

      expect(
        Market.qualityMultiplier(both),
        closeTo(f1 * f2, 1e-12),
      );
    });

    test('улучшения не про качество на цену не влияют', () {
      final onlyTank = withPurchased({'tank_kanistra'});
      expect(Market.qualityMultiplier(onlyTank), 1.0);
    });

    test('цена за литр в тысячу раз больше цены за миллилитр', () {
      final t = DateTime.utc(2026, 5, 17, 9, 30);
      expect(
        Market.pricePerLitre(t, none),
        closeTo(Market.pricePerMl(t, none) * 1000, 1e-9),
      );
    });
  });

  group('Хороший момент', () {
    test('отмечается только на заметном подъёме', () {
      var t = DateTime.utc(2026, 5, 17);
      var flagged = 0;
      const steps = 4000;
      for (var i = 0; i < steps; i++) {
        if (Market.isGoodMoment(t)) flagged++;
        t = t.add(const Duration(seconds: 11));
      }
      final share = flagged / steps;
      // Момент должен быть событием, а не фоном: редкий, но достижимый.
      expect(share, greaterThan(0.03));
      expect(share, lessThan(0.35));
    });
  });

  group('Улучшения качества как контент', () {
    test('в игре есть отдельная ось качества', () {
      final quality =
          kUpgrades.where((u) => u.target == UpgradeTarget.quality).toList();
      expect(quality.length, greaterThanOrEqualTo(3));
      expect(quality.every((u) => u.multiplier > 1), isTrue);
    });

    test('и отдельная ось ёмкости бака', () {
      final tank =
          kUpgrades.where((u) => u.target == UpgradeTarget.tankCapacity).toList();
      expect(tank.length, greaterThanOrEqualTo(3));
      expect(tank.every((u) => u.multiplier > 1), isTrue);
    });
  });
}
