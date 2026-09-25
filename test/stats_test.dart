import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/events.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/content/measures.dart';
import 'package:idle_game/core/formatters.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/core/save.dart';
import 'package:idle_game/core/save_code.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/prestige_state.dart';
import 'package:idle_game/models/stats_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/pixel/garage_scene.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';
import 'package:idle_game/ui/screens/vitya_tab.dart';
import 'package:idle_game/ui/theme/garage.dart';

import 'support/moments.dart';

/// Статистика игрока.
///
/// Главное, что тут проверяется, — что счётчики честные: время в игре идёт
/// только пока игра на экране, зажим — только пока держат палец, и всё это
/// не теряется ни при сохранении, ни при переносе кодом.
void main() {
  const engine = GameEngine();
  const ser = GameSerializer();
  final t0 = DateTime.utc(2026, 3, 1, 12);

  GameState fresh() => newGame(content: kGenerators, upgrades: kUpgrades, now: t0);

  GameState rich() {
    final s = fresh();
    return s.copyWith(resources: s.resources.copyWith(money: 1e12));
  }

  group('Движок складывает время', () {
    test('зажим копится, только пока держишь', () {
      var s = fresh();
      for (var i = 0; i < 3; i++) {
        s = engine.recordPlay(s, 0.2, holding: true, inWindow: false);
      }
      for (var i = 0; i < 2; i++) {
        s = engine.recordPlay(s, 0.2, holding: false, inWindow: false);
      }

      expect(s.stats.holdSeconds, closeTo(0.6, 1e-9));
      expect(s.stats.playSeconds, closeTo(1.0, 1e-9));
    });

    test('окно считается отдельно от зажима', () {
      // Жар проходит окно и без пальца, пока остывает.
      var s = engine.recordPlay(fresh(), 1, holding: false, inWindow: true);
      s = engine.recordPlay(s, 1, holding: true, inWindow: false);

      expect(s.stats.windowSeconds, closeTo(1, 1e-9));
      expect(s.stats.holdSeconds, closeTo(1, 1e-9));
      expect(s.stats.playSeconds, closeTo(2, 1e-9));
    });

    test('нулевое и отрицательное время ничего не меняет', () {
      final s = fresh();
      expect(engine.recordPlay(s, 0, holding: true, inWindow: true), s);
      expect(engine.recordPlay(s, -5, holding: true, inWindow: true), s);
    });

    test('оффлайн не добавляет времени в игре', () {
      var s = fresh();
      s = engine.recordPlay(s, 10, holding: true, inWindow: true);
      final before = s.stats;

      final back = engine.creditOffline(s, const Duration(hours: 8), t0);

      expect(back.gained, greaterThan(0), reason: 'оффлайн вообще не начислился');
      expect(back.state.stats.playSeconds, before.playSeconds);
      expect(back.state.stats.holdSeconds, before.holdSeconds);
      expect(back.state.stats.windowSeconds, before.windowSeconds);
    });
  });

  group('Движок считает торговлю и покупки', () {
    GameState withTank(double ml, {int sort = 0}) {
      final s = fresh();
      return s.copyWith(
        resources: s.resources.copyWith(ml: ml),
        sort: s.sort.copyWith(index: sort),
      );
    }

    test('продажа складывает литры, выручку и лучшую сделку', () {
      var s = withTank(5000);
      final first = engine.saleValue(s, quietMoment);
      s = engine.sell(s, quietMoment);

      s = s.copyWith(resources: s.resources.copyWith(ml: 1000));
      final second = engine.saleValue(s, quietMoment);
      s = engine.sell(s, quietMoment);

      expect(s.stats.soldMl, closeTo(6000, 1e-9));
      expect(s.stats.earned, closeTo(first + second, 1e-9));
      expect(s.stats.sales, 2);
      expect(s.stats.bestSale, closeTo(first, 1e-9),
          reason: 'лучшая — первая, пятилитровая; вторая меньше');
      expect(s.stats.guestSales, 0);
    });

    test('сделка с гостем считается и как сделка, и как гость', () {
      final guest = kGarageEvents.first.asBuyer;
      var s = withTank(3000, sort: guest.minSortIndex);
      s = engine.sellTo(s, guest, quietMoment);

      expect(s.stats.sales, 1);
      expect(s.stats.guestSales, 1);
    });

    test('несостоявшаяся продажа не считается', () {
      final s = engine.sell(fresh(), quietMoment);
      expect(s.stats.sales, 0);
    });

    test('аппараты считаются поштучно, пачкой — сколько реально взяли', () {
      var s = engine.buyGenerator(rich(), 'banka', t0);
      s = engine.buyGeneratorBulk(s, 'banka', 10, t0);
      expect(s.stats.stillsBought, 11);

      // Денег на одну: из заказанных ста куплена одна.
      final cost = engine.generatorCost(
          s.generators.items.firstWhere((g) => g.id == 'banka'), t0);
      s = s.copyWith(resources: s.resources.copyWith(money: cost));
      s = engine.buyGeneratorBulk(s, 'banka', 100, t0);
      expect(s.stats.stillsBought, 12);

      // Денег нет — покупки нет.
      s = engine.buyGenerator(s, 'banka', t0);
      expect(s.stats.stillsBought, 12);
    });

    test('улучшение считается один раз', () {
      var s = engine.buyUpgrade(rich(), 'tap_ruka', t0);
      s = engine.buyUpgrade(s, 'tap_ruka', t0);
      expect(s.stats.upgradesBought, 1);
    });
  });

  group('Похмелье', () {
    // Каждая следующая мудрость требует удвоения нагнанного, поэтому история
    // удваивается, а не прибавляется: иначе второе похмелье не наступит.
    GameState readyToSleep(GameState s) => s.copyWith(
          prestige: s.prestige.copyWith(
            totalEverEarned:
                s.prestige.totalEverEarned * 2 + PrestigeState.firstWisdomMl * 3,
          ),
        );

    GameState sleep(GameState s, DateTime at) =>
        engine.prestige(readyToSleep(s), kGenerators, kUpgrades, at);

    test('не сбрасывает статистику', () {
      var s = engine.buyGenerator(rich(), 'banka', t0);
      s = engine.recordPlay(s, 30, holding: true, inWindow: true);
      final before = s.stats;

      s = sleep(s, t0.add(const Duration(hours: 1)));

      expect(s.stats.playSeconds, before.playSeconds);
      expect(s.stats.holdSeconds, before.holdSeconds);
      expect(s.stats.stillsBought, before.stillsBought);
      expect(s.stats.firstLaunch, before.firstLaunch);
    });

    test('засекает самый быстрый заход — от пробуждения до похмелья', () {
      var s = fresh();
      expect(s.stats.fastestRunSeconds, isNull);

      final first = t0.add(const Duration(hours: 3));
      s = sleep(s, first);
      expect(s.stats.fastestRunSeconds, closeTo(3 * 3600, 1e-6));
      expect(s.stats.runStart, first);

      // Второй заход быстрее — он и рекорд.
      final second = first.add(const Duration(hours: 1));
      s = sleep(s, second);
      expect(s.stats.fastestRunSeconds, closeTo(3600, 1e-6));

      // Третий медленнее — рекорд остаётся.
      s = sleep(s, second.add(const Duration(hours: 5)));
      expect(s.stats.fastestRunSeconds, closeTo(3600, 1e-6));
    });

    test('часы, переведённые назад, не ставят рекорд', () {
      final s = sleep(fresh(), t0.subtract(const Duration(hours: 1)));
      expect(s.stats.fastestRunSeconds, isNull);
    });
  });

  group('Сейв', () {
    GameState played() {
      var s = engine.buyGenerator(rich(), 'banka', t0);
      s = engine.buyUpgrade(s, 'tap_ruka', t0);
      s = engine.recordPlay(s, 125.4, holding: true, inWindow: true);
      s = engine.recordPlay(s, 30, holding: false, inWindow: false);
      s = s.copyWith(resources: s.resources.copyWith(ml: 4200));
      s = engine.sell(s, quietMoment);
      s = s.copyWith(
        prestige: s.prestige.copyWith(totalEverEarned: PrestigeState.firstWisdomMl * 3),
      );
      return engine.prestige(s, kGenerators, kUpgrades, t0.add(const Duration(minutes: 90)));
    }

    GameState load(Map<String, dynamic> json, DateTime now) =>
        ser.fromJson(json, content: kGenerators, upgrades: kUpgrades, now: now);

    test('переживает сохранение и загрузку', () {
      final before = played();
      // Загружаем в другой момент: отметки времени обязаны прийти из сейва,
      // а не из часов загрузки.
      final after = load(
        ser.toJson(before, lastSeenMillis: 1),
        t0.add(const Duration(days: 3)),
      );
      expect(after.stats, before.stats);
    });

    test('переживает перенос кодом', () {
      final before = played();
      final code = encodeSaveCode(
        const SaveCodec().encode(ser.toJson(before, lastSeenMillis: 1)),
      );

      final parsed = decodeSaveCode(code);
      expect(parsed.isOk, isTrue, reason: parsed.message);
      final loaded = const SaveCodec().decode(parsed.save);
      final after = load(loaded.data!, t0.add(const Duration(days: 3)));

      expect(after.stats, before.stats);
    });

    test('сейв без статистики начинает её с момента загрузки', () {
      final now = t0.add(const Duration(days: 10));
      final s = load(<String, dynamic>{'version': kSaveVersion}, now);

      expect(s.stats, StatsState.startedAt(now));
    });

    test('мусор в статистике не роняет загрузку', () {
      final now = t0.add(const Duration(days: 10));
      final s = load({
        'stats': {
          'firstLaunch': 1e300,
          'runStart': 'вчера',
          'playSec': 'много',
          'holdSec': double.nan,
          'sales': -3,
          'fastestRunSec': -1,
        },
      }, now);

      expect(s.stats, StatsState.startedAt(now));
    });

    final fixtures = Directory('test/fixtures')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));
    for (final file in fixtures) {
      final name = file.uri.pathSegments.last;
      test('эталон $name читается, статистика — с момента загрузки', () {
        final now = t0.add(const Duration(days: 200));
        final loaded = const SaveCodec().decode(file.readAsStringSync());
        expect(loaded.wasCorrupt, isFalse);

        final s = load(loaded.data!, now);
        expect(s.stats, StatsState.startedAt(now));

        // А то, что в эталоне было, — на месте.
        final original = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        expect(s.clicker.totalTaps, original['taps']);
        expect(s.prestige.hangovers, original['hangovers']);
      });
    }
  });

  group('Часы в игре', () {
    Future<ProviderContainer> open(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialStateProvider.overrideWithValue(
              newGame(content: kGenerators, upgrades: kUpgrades, now: quietMoment),
            ),
            timeProvider.overrideWithValue(() => quietMoment),
          ],
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark, fontFamily: GType.uiFamily),
            home: const Scaffold(body: GarageScreen()),
          ),
        ),
      );
      addTearDown(() => tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed));
      return ProviderScope.containerOf(tester.element(find.byType(GarageScreen)));
    }

    /// Игра на экране: кадры идут чаще тиков, как в настоящем браузере.
    /// Один `pump` на весь срок нарисовал бы один кадр в конце — так выглядит
    /// как раз вкладка, которую не показывают.
    Future<void> watch(WidgetTester tester, Duration d) async {
      const frame = Duration(milliseconds: 50);
      for (var t = Duration.zero; t < d; t += frame) {
        await tester.pump(frame);
      }
    }

    double played(ProviderContainer game) => game.read(gameProvider).stats.playSeconds;

    // Один тик — 0.2 с: на столько показания могут разойтись с секундомером.
    const tick = 0.21;

    testWidgets('идут, пока игра на экране', (tester) async {
      final game = await open(tester);
      final before = played(game);

      await watch(tester, const Duration(seconds: 3));

      expect(played(game) - before, closeTo(3, tick));
    });

    testWidgets('зажим копится, только пока держишь палец', (tester) async {
      final game = await open(tester);

      final finger = await tester.startGesture(tester.getCenter(find.byType(GarageScene)));
      await watch(tester, const Duration(seconds: 2));
      await finger.up();
      await watch(tester, const Duration(seconds: 3));

      final stats = game.read(gameProvider).stats;
      expect(stats.holdSeconds, closeTo(2, tick));
      expect(stats.playSeconds, closeTo(5, tick));
    });

    testWidgets('свёрнутая вкладка не накручивает часы', (tester) async {
      final game = await open(tester);
      await watch(tester, const Duration(seconds: 1));

      // Браузер не останавливает таймеры свёрнутой вкладки, а только
      // прореживает: тики идут, и часы обязаны стоять вопреки им. Кадры тут
      // рисуются нарочно — худший случай: стоять часы обязаны и по одному
      // жизненному циклу.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      final hidden = played(game);
      await watch(tester, const Duration(seconds: 30));
      expect(played(game), hidden);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await watch(tester, const Duration(seconds: 2));
      expect(played(game), closeTo(hidden + 2, tick));
    });

    testWidgets('нет кадров — часы стоят, хоть тики и идут', (tester) async {
      // Так проверка в браузере и нашла дыру: вкладка, открытая сразу в
      // фоне, считается «видимой» — жизненный цикл молчит, — но кадров не
      // рисует. Таймеры у неё при этом идут без замедления.
      final game = await open(tester);

      await tester.pump(const Duration(minutes: 1));
      expect(played(game), lessThanOrEqualTo(tick),
          reason: 'минута без единого кадра засчитана как игра');

      // Показали — пошли.
      final shown = played(game);
      await watch(tester, const Duration(seconds: 2));
      expect(played(game), closeTo(shown + 2, tick));
    });

    testWidgets('окно без фокуса — игра на экране, часы идут', (tester) async {
      final game = await open(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final before = played(game);
      await watch(tester, const Duration(seconds: 2));

      expect(played(game) - before, closeTo(2, tick));
    });
  });

  group('Показ', () {
    test('нагнанное переливается в банки и самую крупную меру', () {
      expect(pourInto(0), isEmpty);
      expect(pourInto(30), isEmpty, reason: 'меньше рюмки');
      expect(pourInto(150).single.$2, kShot);

      final jarOnly = pourInto(9000);
      expect(jarOnly.single.$2, kJar);
      expect(jarOnly.single.$1, closeTo(3, 1e-9));

      // 8 400 000 литров — эталонный сейв 1.0.0: банки и три бассейна.
      final big = pourInto(8.4e9);
      expect(big.first.$2, kJar);
      expect(big.last.$2.one, 'олимпийский бассейн');
      expect(big.last.$1, closeTo(3.36, 1e-9));

      expect(pourInto(1e25).last.$2, kMeasures.last, reason: 'крупнее Байкала мер нет');
    });

    test('число с мерой склоняется и сокращается', () {
      String baths(double n) => Fmt.counted(n, 'ванна', 'ванны', 'ванн');
      expect(baths(1), '1 ванна');
      expect(baths(3.9), '3 ванны');
      expect(baths(12), '12 ванн');
      expect(baths(2500), '2.5К ванн');
    });

    for (final (label, state) in [
      ('новая игра', () => newGame(content: kGenerators, upgrades: kUpgrades, now: quietMoment)),
      (
        'огромные числа',
        () {
          final s = newGame(content: kGenerators, upgrades: kUpgrades, now: quietMoment);
          final far = quietMoment.subtract(const Duration(days: 999));
          return s.copyWith(
            prestige: s.prestige.copyWith(totalEverEarned: 3e25, hangovers: 12345),
            stats: StatsState(
              firstLaunch: far,
              runStart: far,
              playSeconds: 9e7,
              holdSeconds: 8e7,
              windowSeconds: 7e7,
              soldMl: 3e25,
              earned: 9e30,
              sales: 123456789,
              bestSale: 8e29,
              guestSales: 9876543,
              stillsBought: 987654321,
              upgradesBought: 12345,
              fastestRunSeconds: 9e6,
            ),
          );
        },
      ),
    ]) {
      testWidgets('на 320×640 ничего не вылезает: $label', (tester) async {
        tester.view
          ..physicalSize = const Size(320, 640)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(ProviderScope(
          overrides: [
            initialStateProvider.overrideWithValue(state()),
            timeProvider.overrideWithValue(() => quietMoment),
          ],
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark, fontFamily: GType.uiFamily),
            home: const Scaffold(body: VityaTab()),
          ),
        ));

        // Список ленивый: строки, до которых не доскроллили, не строятся и
        // не переполняются. Поэтому листаем до конца.
        await tester.dragUntilVisible(
          find.text('ЕСЛИ СЛИТЬ ВСЁ НАГНАННОЕ'),
          find.byType(ListView),
          const Offset(0, -150),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
