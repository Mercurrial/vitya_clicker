import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/balance.dart';
import 'package:idle_game/content/buyers.dart';
import 'package:idle_game/content/events.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/content/wisdom_milestones.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/engine/production.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/prestige_state.dart';
import 'package:idle_game/models/sort_state.dart';
import 'package:idle_game/models/upgrade.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/game/heat_controller.dart' show HeatStatus;
import 'package:idle_game/ui/screens/garage_screen.dart';
import 'package:idle_game/ui/screens/shelf.dart';

import 'support/moments.dart';

/// Вехи мудрости — «магазин мудрости» без траты (docs/DECISIONS.md,
/// «Экономика и мудрость»).
///
/// Главное свойство — вехи не хранятся: они вычисляются из `claimedMl` и
/// `bonusWisdom` по текущему балансу. Правка баланса доходит до всех сама,
/// как и правка самой мудрости, а сейв не получает ни одного нового ключа.
void main() {
  const engine = GameEngine();
  const ser = GameSerializer();

  /// Ровно [steps] мудрости: wisdom = log2(1 + claimed / first).
  double claimedFor(int steps) => PrestigeState.firstWisdomMl * ((1 << steps) - 1);

  PrestigeState withWisdom(int steps) => PrestigeState(claimedMl: claimedFor(steps));

  /// Гараж с парой банок и бидонов и мудростью [wisdom].
  GameState garage({int wisdom = 0, DateTime? at}) {
    final t = at ?? quietMoment;
    var s = GameState.initial(
      initialGenerators: kGenerators,
      initialUpgrades: kUpgrades,
      prestige: withWisdom(wisdom),
      lastUpdateTime: t,
    );
    s = s.copyWith(resources: s.resources.copyWith(money: 1e30));
    s = engine.buyGeneratorBulk(s, 'banka', 10, t);
    s = engine.buyGeneratorBulk(s, 'bidon', 3, t);
    return s.copyWith(resources: s.resources.copyWith(money: 0));
  }

  /// Состояние, в котором похмелье поднимет мудрость до [after].
  GameState readyToSleep({required int before, required int after}) {
    final s = garage(wisdom: before);
    return s.copyWith(
      prestige: s.prestige.copyWith(totalEverEarned: claimedFor(after) * 1.0001),
    );
  }

  double outputOf(GameState s, String id) => Production.generatorOutput(
        s.generators.items.firstWhere((g) => g.id == id),
        s.generators,
        s.upgrades,
        s.prestige,
        s.achievements.multiplier,
      );

  /// Подменить дорожку вех на время теста.
  T withPath<T>(List<WisdomMilestone> path, T Function() body) =>
      withBalance(kBalance.copyWith(wisdomMilestones: path), body);

  group('Вехи вычисляются, а не хранятся', () {
    test('взяты все вехи, до которых хватает мудрости, и только они', () {
      final path = PrestigeState.pathOf();
      expect(path, isNotEmpty);
      expect(withWisdom(0).milestones, isEmpty);

      for (final w in {path.first.wisdom, path[path.length ~/ 2].wisdom, path.last.wisdom}) {
        final taken = withWisdom(w).milestones;
        expect(taken.every((m) => m.wisdom <= w), isTrue);
        expect(taken.length, path.where((m) => m.wisdom <= w).length);
        // На ступень ниже эта веха ещё не взята — и она-то и есть следующая.
        final below = withWisdom(w - 1);
        expect(below.milestones.length, lessThan(taken.length));
        expect(below.nextMilestone!.wisdom, w);
      }
      expect(withWisdom(path.last.wisdom).nextMilestone, isNull,
          reason: 'дорожка пройдена — следующей нет');
    });

    test('компенсация открывает вехи наравне с заработанной мудростью', () {
      final first = PrestigeState.pathOf().first;
      final p = PrestigeState(bonusWisdom: first.wisdom);
      expect(p.milestones, contains(first));
    });

    test('в сейве вех нет, а после перезапуска они те же', () {
      final s = garage(wisdom: 21);
      final json = ser.toJson(s, lastSeenMillis: quietMoment.millisecondsSinceEpoch);
      final text = jsonEncode(json);
      expect(text, isNot(contains('milestone')),
          reason: 'вехи — вывод из мудрости, а не факт: в сейве им не место');

      final back = ser.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
        content: kGenerators,
        upgrades: kUpgrades,
        now: quietMoment,
      );
      expect(back.prestige.milestones, s.prestige.milestones);
      expect(back.prestige.milestones, isNotEmpty);
      expect(back.mlPerSecond, closeTo(s.mlPerSecond, s.mlPerSecond * 1e-9));
    });

    test('правка порога мудрости пересчитывает вехи', () {
      // Тот же сейв, порог вчетверо выше — мудрости на две меньше, и вехи
      // выше неё отпадают сами. Это ослабление по обычному правилу баланса.
      final s = garage(wisdom: 21);
      final before = s.prestige.milestones.length;
      withBalance(kBalance.copyWith(firstWisdomMl: kBalance.firstWisdomMl * 4), () {
        expect(s.prestige.wisdom, 19);
        expect(s.prestige.milestones.length, lessThan(before));
      });
      expect(s.prestige.milestones.length, before,
          reason: 'вернули баланс — вернулись и вехи');
    });

    test('правка списка вех доходит до всех, и старый список не залипает', () {
      final p = withWisdom(3);
      withPath(const [WisdomMilestone(World.garage, 1, AllBoost(3))], () {
        expect(p.bonuses.all, 3);
      });
      withPath(const [WisdomMilestone(World.garage, 1, AllBoost(5))], () {
        expect(p.bonuses.all, 5);
      });
      expect(p.bonuses.all, MilestoneBonuses.of(PrestigeState.milestonesFor(3)).all);
    });
  });

  group('Что дают вехи', () {
    // Производство считается по действующему балансу в момент вопроса, а не
    // по тому, при котором собран гараж: поэтому «до» меряется внутри своей
    // дорожки, а не снаружи.
    (double, double) bankaAndBidon(List<WisdomMilestone> path) => withPath(path, () {
          final s = garage(wisdom: 1);
          return (outputOf(s, 'banka'), outputOf(s, 'bidon'));
        });

    test('ступень — множит свою и не трогает соседнюю', () {
      final (banka, bidon) = bankaAndBidon(const []);
      final (banka3, bidon3) =
          bankaAndBidon(const [WisdomMilestone(World.garage, 1, StillBoost('banka', 3))]);
      expect(banka3, closeTo(banka * 3, 1e-6));
      expect(bidon3, closeTo(bidon, 1e-6));
    });

    test('всё производство — множит всю лестницу', () {
      final plain = withPath(const [], () => garage(wisdom: 1).mlPerSecond);
      final boosted = withPath(
          const [WisdomMilestone(World.garage, 1, AllBoost(2))], () => garage(wisdom: 1).mlPerSecond);
      expect(boosted, closeTo(plain * 2, 1e-6));
    });

    test('веха, которую открыл сон, действует уже в этом заходе', () {
      withPath(const [WisdomMilestone(World.garage, 2, RunStart(5000))], () {
        final early = engine.prestige(
            readyToSleep(before: 0, after: 1), kGenerators, kUpgrades, quietMoment);
        expect(early.resources.money, 0, reason: 'до вехи мудрости не хватило');

        final woke = engine.prestige(
            readyToSleep(before: 1, after: 2), kGenerators, kUpgrades, quietMoment);
        expect(woke.prestige.wisdom, 2);
        expect(woke.resources.money, 5000,
            reason: 'веха на двух мудростях, сон до них довёл — заход с деньгами');
      });
    });

    test('переживает похмелье только то, что открыто вехой', () {
      withPath(const [WisdomMilestone(World.garage, 1, KeepUpgrades(UpgradeTarget.heatControl))], () {
        var s = readyToSleep(before: 0, after: 1);
        s = s.copyWith(resources: s.resources.copyWith(money: 1e30));
        for (final id in ['heat_1', 'heat_2', 'tank_1', 'gen_banka_1']) {
          s = engine.buyUpgrade(s, id, quietMoment);
        }
        final woke = engine.prestige(s, kGenerators, kUpgrades, quietMoment);
        bool bought(String id) => woke.upgrades.items.firstWhere((u) => u.id == id).purchased;
        expect(bought('heat_1'), isTrue);
        expect(bought('heat_2'), isTrue);
        expect(bought('heat_3'), isFalse, reason: 'не было куплено — не с чего оставаться');
        expect(bought('tank_1'), isFalse);
        expect(bought('gen_banka_1'), isFalse);
      });
    });

    test('гости платят больше, а сосед — как раньше', () {
      final guest = kGarageEvents.first.asBuyer;
      final plain = withPath(const [], () {
        final s = garage(wisdom: 1);
        return s.copyWith(
          resources: s.resources.copyWith(ml: 1e6),
          sort: const SortState(index: 4),
        );
      });
      final (guestPlain, neighbourPlain) = withPath(const [], () => (
            engine.saleValueFor(plain, guest, quietMoment),
            engine.saleValueFor(plain, kBuyers.first, quietMoment),
          ));
      withPath(const [WisdomMilestone(World.garage, 1, GuestPay(1.5))], () {
        expect(engine.saleValueFor(plain, guest, quietMoment), closeTo(guestPlain * 1.5, 1e-6));
        expect(engine.saleValueFor(plain, kBuyers.first, quietMoment), closeTo(neighbourPlain, 1e-9));
        // Сколько показано на кнопке гостя, столько он и платит.
        final sold = engine.sellTo(plain, guest, quietMoment);
        expect(sold.resources.money - plain.resources.money, closeTo(guestPlain * 1.5, 1e-6));
      });
    });

    group('сорт', () {
      /// Игра без экрана: жар в окне, часы двигаются руками.
      Future<double> gainInWindow(WidgetTester tester, List<WisdomMilestone> path) async {
        final saved = Balance.current;
        Balance.current = kBalance.copyWith(wisdomMilestones: path);
        addTearDown(() => Balance.current = saved);

        var now = quietMoment;
        final state = garage(wisdom: 1).copyWith(sort: const SortState(index: 1));
        await tester.pumpWidget(ProviderScope(
          overrides: [
            initialStateProvider.overrideWithValue(state),
            timeProvider.overrideWithValue(() => now),
          ],
          child: const SizedBox(),
        ));
        final scope = ProviderScope.containerOf(tester.element(find.byType(SizedBox)));
        scope.read(heatStatusProvider.notifier).state = HeatStatus.inWindow;
        final before = scope.read(gameProvider).sort.progress;
        for (var i = 0; i < 5; i++) {
          now = now.add(const Duration(milliseconds: 200));
          await tester.pump(const Duration(milliseconds: 200));
        }
        final gained = scope.read(gameProvider).sort.progress - before;
        await tester.pumpWidget(const SizedBox());
        return gained;
      }

      testWidgets('растёт быстрее под пальцем', (tester) async {
        final plain = await gainInWindow(tester, const []);
        final fast = await gainInWindow(
            tester, const [WisdomMilestone(World.garage, 1, SortSpeed(1.5))]);
        expect(plain, greaterThan(0));
        expect(fast, closeTo(plain * 1.5, plain * 0.01));
      });
    });
  });

  group('Вкладка «МУДРОСТЬ»', () {
    Future<void> openWisdom(WidgetTester tester, GameState state) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          initialStateProvider.overrideWithValue(state),
          timeProvider.overrideWithValue(() => quietMoment),
        ],
        child: const MaterialApp(home: Scaffold(body: GarageScreen())),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      final scope = ProviderScope.containerOf(tester.element(find.byType(GarageScreen)));
      scope.read(shelfPositionProvider.notifier).state = ShelfPosition.shop;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final tab = find.descendant(of: find.byType(Shelf), matching: find.text('МУДРОСТЬ'));
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('есть с первого запуска: похмелье объясняется заранее', (tester) async {
      await openWisdom(tester, garage());
      expect(find.byKey(const Key('wisdom-sleep')), findsOneWidget);
      expect(find.text('ЕЩЁ РАНО'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('следующая веха видна, с тем, сколько до неё осталось', (tester) async {
      final path = PrestigeState.pathOf();
      final next = path[1];
      final w = next.wisdom - 1;
      expect(path.first.wisdom, lessThanOrEqualTo(w));
      await openWisdom(tester, garage(wisdom: w));
      final line = tester.widget<Text>(find.byKey(const Key('wisdom-next'))).data!;
      expect(line, contains('${next.wisdom}'));
      expect(line, contains('ещё 1'));
    });

    testWidgets('сон, который откроет веху, говорит об этом заранее', (tester) async {
      final first = PrestigeState.pathOf().first;
      await openWisdom(tester, readyToSleep(before: 0, after: first.wisdom));
      expect(find.byKey(const Key('wisdom-opens')), findsOneWidget);
      expect(find.textContaining('ЛЕЧЬ ПРОСПАТЬСЯ'), findsOneWidget);
    });
  });
}
