import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/balance.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/core/save.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/prestige_state.dart';

/// Обновление игры без обиды у игрока.
///
/// Это главное требование ко всей затее: баланс будет меняться после релиза,
/// и вопрос не «как не менять», а «как поменять так, чтобы тот, кто уже
/// играет, не почувствовал себя обманутым».
///
/// Механизм держится на одном принципе: **в сейве лежат факты, а не оценки**.
/// Сколько куплено, сколько нагнано — факты. Доход, цены, мудрость — оценки,
/// и они пересчитываются при каждой загрузке. Эти тесты стерегут принцип:
/// стоит кому-нибудь положить в сейв производное число, и они упадут.
void main() {
  const ser = GameSerializer();
  const codec = SaveCodec();
  final now = DateTime.utc(2026, 6, 1);

  GameState load(Map<String, dynamic> json) => ser.fromJson(
        json,
        content: kGenerators,
        upgrades: kUpgrades,
        now: now,
      );

  group('Правка баланса применяется к старому сейву сама', () {
    test('мудрость пересчитывается по новой формуле, а не остаётся старой', () {
      // Игрок наиграл на 10 ступеней при действующих числах.
      final claimed = PrestigeState.firstWisdomMl * 1023;
      final saved = ser.toJson(
        GameState.initial(
          initialGenerators: kGenerators,
          initialUpgrades: kUpgrades,
          prestige: PrestigeState(claimedMl: claimed, totalEverEarned: claimed),
          lastUpdateTime: now,
        ),
        lastSeenMillis: 1,
      );
      expect(load(saved).prestige.wisdom, 10);

      // Выходит обновление, где первая мудрость даётся вчетверо легче.
      withBalance(
        kBalance.copyWith(firstWisdomMl: PrestigeState.firstWisdomMl / 4),
        () {
          // log2(1 + 1023·4) = 11.99…, то есть одиннадцать ступеней.
          expect(
            load(saved).prestige.wisdom,
            11,
            reason: 'новая формула обязана примениться к УЖЕ накопленному',
          );
        },
      );
    });

    test('в сейве не лежит ни одного производного числа', () {
      var s = GameState.initial(
        initialGenerators: kGenerators,
        initialUpgrades: kUpgrades,
        lastUpdateTime: now,
      );
      s = s.copyWith(resources: s.resources.copyWith(money: 1e9));
      s = const GameEngine().buyGenerator(s, 'banka', now);

      final json = ser.toJson(s, lastSeenMillis: 1);

      // Доход, ёмкость бака, цена, мудрость — всё это считается из фактов.
      // Попадание любого из них в сейв означает, что правка баланса перестанет
      // действовать на тех, кто уже играет.
      for (final forbidden in [
        'mlPerSecond',
        'tankCapacity',
        'wisdom',
        'pricePerMl',
        'tapYield',
        'baseCost',
        'baseProduction',
        'costGrowth',
      ]) {
        expect(
          json.containsKey(forbidden),
          isFalse,
          reason: 'в сейве оказалась ОЦЕНКА «$forbidden», а не факт: '
              'после правки баланса она останется от старых чисел',
        );
      }
    });

    test('цена аппаратов берётся из текущего баланса, а не из сейва', () {
      final json = ser.toJson(
        GameState.initial(
          initialGenerators: kGenerators,
          initialUpgrades: kUpgrades,
          lastUpdateTime: now,
        ),
        lastSeenMillis: 1,
      );

      final normal = load(json).generators.items.first.baseCost;
      withBalance(kBalance.copyWith(firstGeneratorCost: 999), () {
        expect(load(json).generators.items.first.baseCost, 999);
      });
      expect(load(json).generators.items.first.baseCost, normal);
    });
  });

  // Журнал из нескольких выпусков. В выпуске 1.0.0 запись одна — v1, и на
  // ней не проверить ни «пропущенные выпуски», ни сложение компенсаций.
  // Поэтому поведение проверяется на подставном журнале, а настоящий —
  // только на то, что обязано быть верным всегда.
  const log = [
    BalanceRelease(
      version: 1,
      title: 'Точка отсчёта',
      changes: ['Первая версия баланса, с которой начинают все игроки.'],
    ),
    BalanceRelease(
      version: 2,
      title: 'Строже',
      isNerf: true,
      compensationWisdom: 3,
      changes: ['Аппараты дорожают быстрее, за это три мудрости сверху.'],
    ),
    BalanceRelease(
      version: 3,
      title: 'Мягче',
      changes: ['Бак стал больше, и продавать можно реже, чем раньше.'],
    ),
    BalanceRelease(
      version: 4,
      title: 'Снова строже',
      isNerf: true,
      compensationWisdom: 2,
      changes: ['До мудрости дальше, за это две мудрости сверху.'],
    ),
  ];

  group('Игроку рассказывают, что изменилось', () {
    test('новичок не видит новостей о том, чего не застал', () {
      expect(releasesSince(kBalanceVersion), isEmpty);
    });

    test('тот, кто играл на прошлом балансе, видит все пропущенные выпуски', () {
      expect([for (final r in releasesSince(1, log)) r.version], [2, 3, 4]);
      expect([for (final r in releasesSince(3, log)) r.version], [4]);
      expect(releasesSince(4, log), isEmpty);
    });

    test('каждый выпуск объясняет изменения человеческим языком', () {
      for (final release in kBalanceLog) {
        expect(release.title, isNotEmpty);
        expect(release.changes, isNotEmpty,
            reason: 'выпуск без объяснений хуже, чем отсутствие экрана');
        for (final change in release.changes) {
          expect(change.length, greaterThan(20),
              reason: '«баланс улучшен» — это не объяснение: «$change»');
        }
      }
    });

    test('за ослабление полагается компенсация', () {
      for (final release in kBalanceLog) {
        if (!release.isNerf) continue;
        expect(
          release.compensationWisdom,
          greaterThan(0),
          reason: 'выпуск «${release.title}» делает хуже и ничего не даёт взамен',
        );
      }
    });

    test('версия баланса не отстаёт от журнала', () {
      final newest = kBalanceLog.map((r) => r.version).fold(0, (a, b) => a > b ? a : b);
      expect(
        kBalanceVersion,
        greaterThanOrEqualTo(newest),
        reason: 'в журнале есть выпуск новее текущей версии — забыли поднять',
      );
    });

    test('версии в журнале не повторяются и идут по возрастанию', () {
      final versions = [for (final r in kBalanceLog) r.version];
      expect(versions.toSet().length, versions.length, reason: 'дубль версии');
      final sorted = [...versions]..sort();
      expect(versions, sorted);
    });
  });

  group('Компенсация', () {
    test('начисляется один раз и суммируется по пропущенным выпускам', () {
      expect(compensationSince(kBalanceVersion), 0,
          reason: 'тот, кто уже всё видел, второй раз не получает');
      expect(compensationSince(4, log), 0);
      expect(compensationSince(2, log), 2);
      expect(compensationSince(1, log), 5);
    });

    test('компенсация прибавляется к мудрости, а не подменяет заработанное', () {
      final claimed = PrestigeState.firstWisdomMl * 7; // три ступени
      final p = PrestigeState(claimedMl: claimed, totalEverEarned: claimed);
      expect(p.wisdom, 3);

      final compensated = p.withCompensation(2);
      expect(compensated.wisdom, 5);
      expect(compensated.claimedMl, claimed,
          reason: 'подарок не должен искажать историю игрока');
    });

    test('компенсация не создаёт ложного «можно лечь спать»', () {
      final claimed = PrestigeState.firstWisdomMl * 7;
      final p = PrestigeState(claimedMl: claimed, totalEverEarned: claimed)
          .withCompensation(4);
      expect(p.pendingWisdom, 0,
          reason: 'подарок увеличивает и накопленное, и потенциал одинаково');
      expect(p.canPrestige, isFalse);
    });

    test('повторный запуск до сохранения не удваивает подарок', () {
      // Опасный случай: игра начислила компенсацию, показала экран, и её
      // закрыли до того, как сейв лёг на диск. При следующем запуске сейв
      // всё ещё помечен старой версией — компенсация посчитается снова.
      //
      // Удвоения быть не должно: подарок считается от версии В СЕЙВЕ и
      // применяется к только что загруженному состоянию, а не к тому, что
      // уже лежит в памяти.
      final claimed = PrestigeState.firstWisdomMl * 7;
      final oldSave = {
        ...ser.toJson(
          GameState.initial(
            initialGenerators: kGenerators,
            initialUpgrades: kUpgrades,
            prestige: PrestigeState(claimedMl: claimed, totalEverEarned: claimed),
            lastUpdateTime: now,
          ),
          lastSeenMillis: 1,
        ),
      }..remove('balanceVersion'); // сейв с той поры, когда пометки не было

      final gift = compensationSince(ser.balanceVersionOf(oldSave), log);
      expect(gift, greaterThan(0));

      PrestigeState afterLaunch() =>
          load(oldSave).prestige.withCompensation(gift);

      expect(afterLaunch().bonusWisdom, gift);
      expect(afterLaunch().bonusWisdom, gift,
          reason: 'второй запуск с тем же сейвом обязан дать столько же');
    });

    test('компенсация переживает сохранение', () {
      final claimed = PrestigeState.firstWisdomMl * 7;
      final s = GameState.initial(
        initialGenerators: kGenerators,
        initialUpgrades: kUpgrades,
        prestige: PrestigeState(claimedMl: claimed, totalEverEarned: claimed)
            .withCompensation(3),
        lastUpdateTime: now,
      );
      final back = load(ser.toJson(s, lastSeenMillis: 1));
      expect(back.prestige.bonusWisdom, 3);
      expect(back.prestige.wisdom, 6);
    });
  });

  group('Версия баланса в сейве', () {
    test('свежий сейв помечен текущей версией', () {
      final json = ser.toJson(
        GameState.initial(
          initialGenerators: kGenerators,
          initialUpgrades: kUpgrades,
          lastUpdateTime: now,
        ),
        lastSeenMillis: 1,
      );
      expect(ser.balanceVersionOf(json), kBalanceVersion);
    });

    test('сейв без пометки считается самым старым', () {
      expect(ser.balanceVersionOf(<String, dynamic>{}), 1);
      expect(ser.balanceVersionOf({'balanceVersion': 'мусор'}), 1);
      expect(ser.balanceVersionOf({'balanceVersion': -3}), 1);
    });
  });

  group('Цепочка миграций доживает до сегодня', () {
    test('каждая версия от первой до текущей имеет миграцию', () {
      // Дыра в цепочке означает, что чей-то сейв не доедет до сегодня.
      // До выпуска версия одна и проверять нечего; тест начнёт работать с
      // первой миграцией.
      for (var v = 1; v < kSaveVersion; v++) {
        final json = '{"version": $v}';
        expect(
          codec.decode(json).wasCorrupt,
          isFalse,
          reason: 'нет миграции с версии $v — такой сейв игра потеряет',
        );
      }
    });
  });
}
