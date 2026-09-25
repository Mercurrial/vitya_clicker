import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/balance.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/bootstrap.dart';
import 'package:idle_game/core/game_clock.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/core/save.dart';
import 'package:idle_game/core/save_code.dart';
import 'package:idle_game/core/settings.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/main.dart';
import 'package:idle_game/models/flux_state.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/providers/settings_provider.dart';
import 'package:idle_game/sim/balance_targets.dart';
import 'package:idle_game/sim/sim_profiles.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';
import 'package:idle_game/ui/theme/garage.dart';

import 'support/moments.dart';

/// Поток времени: AFK копит поток, ускорение его тратит.
///
/// Главное здесь — что отсутствие больше не гонит самогон мимо игрока: ни
/// закрытая игра, ни уснувшее приложение, ни возврат во вкладку. Числа
/// потока — из docs/PLAN-1.0.md, раздел 2, и сверяются с целями, а не
/// переписываются сюда.
void main() {
  const engine = GameEngine();
  const ser = GameSerializer();
  final t0 = DateTime.utc(2026, 3, 1, 12);

  GameState fresh() => newGame(content: kGenerators, upgrades: kUpgrades, now: t0);

  GameState withFlux(double seconds, {int rate = 0, int bank = 0}) => fresh().copyWith(
        flux: FluxState(seconds: seconds, rateLevel: rate, bankLevel: bank),
      );

  group('Начисление', () {
    test('час AFK — 10 минут потока', () {
      final r = engine.creditAfk(fresh(), const Duration(hours: 1));
      expect(r.gained, closeTo(10 * 60, 1e-9));
      expect(r.state.flux.seconds, closeTo(10 * 60, 1e-9));
    });

    test('копилка на старте наполняется за 6 часов AFK', () {
      final f = fresh().flux;
      final fill = Duration(seconds: (f.bankSeconds / f.earnedFor(1)).round());
      expect(fill, lessThanOrEqualTo(BalanceTargets.fluxBankFillMax));
    });

    test('сверх копилки не копится, сколько бы ни прошло', () {
      final day = engine.creditAfk(fresh(), const Duration(days: 1));
      final week = engine.creditAfk(fresh(), const Duration(days: 7));
      expect(day.state.flux.seconds, day.state.flux.bankSeconds);
      expect(week.state.flux.seconds, day.state.flux.seconds);
      expect(day.state.flux.isBankFull, isTrue);
    });

    test('полная копилка ничего не прибавляет и не отнимает', () {
      final full = withFlux(3600);
      final r = engine.creditAfk(full, const Duration(hours: 5));
      expect(r.gained, 0);
      expect(r.state, same(full));
    });

    test('уровни ускоряют начисление и растят копилку', () {
      final s = withFlux(0, rate: 5, bank: 2);
      expect(s.flux.minutesPerHour, 15);
      expect(s.flux.bankSeconds, 3 * 3600);
      final r = engine.creditAfk(s, const Duration(hours: 2));
      expect(r.gained, closeTo(30 * 60, 1e-9));
    });

    test('AFK не гонит самогон и не трогает гараж', () {
      final s = fresh();
      final r = engine.creditAfk(s, const Duration(hours: 8));
      expect(r.state.resources, s.resources);
      expect(r.state.prestige, s.prestige);
      expect(r.state.generators, s.generators);
    });

    test('откат часов не даёт потока', () {
      // Метка из будущего — часы перевели назад.
      final clock = GameClock(now: () => t0);
      final away = clock.since(t0.add(const Duration(hours: 5)).millisecondsSinceEpoch);
      expect(away.rolledBack, isTrue);
      final r = engine.creditAfk(fresh(), away.elapsed);
      expect(r.gained, 0);
    });

    test('похмелье поток не трогает', () {
      var s = withFlux(1234, rate: 3, bank: 1);
      s = s.copyWith(
        prestige: s.prestige.copyWith(totalEverEarned: Balance.current.firstWisdomMl * 2),
      );
      final after = engine.prestige(s, kGenerators, kUpgrades, t0);
      expect(after.prestige.hangovers, 1, reason: 'похмелье не случилось');
      expect(after.flux, s.flux);
    });
  });

  group('Ускорение', () {
    /// Прожить [realSeconds] настоящих секунд на скорости [speed], сдавая бак
    /// каждую секунду, — как автопродажа. Возвращает нагнанное и остаток
    /// потока.
    ({double ml, double flux}) spend(GameState start, double speed, int realSeconds) {
      var s = start;
      var ml = 0.0;
      for (var i = 1; i <= realSeconds; i++) {
        s = engine.processTick(s, t0.add(Duration(seconds: i)), speed: speed);
        ml += s.resources.ml;
        s = s.copyWith(resources: s.resources.copyWith(ml: 0));
      }
      return (ml: ml, flux: s.flux.seconds);
    }

    test('итог один на любой скорости', () {
      // Час потока — час лишнего производства: на ×2 он проживается за
      // час, на ×10 — за шесть минут. Лишнее сверх настоящего времени
      // одинаково.
      final start = withFlux(3600, bank: 0);
      final rate = start.mlPerSecond;
      final x2 = spend(start, 2, 3600);
      final x10 = spend(start, 10, 400);

      expect(x2.flux, closeTo(0, 1e-6));
      expect(x10.flux, closeTo(0, 1e-6));
      final extra2 = x2.ml - rate * 3600;
      final extra10 = x10.ml - rate * 400;
      expect(extra2, closeTo(rate * 3600, 1e-6));
      expect(extra10, closeTo(extra2, 1e-6));
    });

    test('поток кончается посреди тика — ускорение кончается вместе с ним', () {
      final start = withFlux(3);
      final next = engine.processTick(start, t0.add(const Duration(seconds: 1)), speed: 10);
      expect(next.flux.seconds, 0);
      expect(next.resources.ml, closeTo(start.mlPerSecond * 4, 1e-9));
    });

    test('без потока скорость ничего не даёт', () {
      final start = fresh();
      final plain = engine.processTick(start, t0.add(const Duration(seconds: 1)));
      final fast = engine.processTick(start, t0.add(const Duration(seconds: 1)), speed: 10);
      expect(fast, plain);
    });

    test('на полном баке поток не сгорает', () {
      final start = withFlux(600);
      final full = start.copyWith(
        resources: start.resources.copyWith(ml: start.tankCapacity),
      );
      final next = engine.processTick(full, t0.add(const Duration(seconds: 1)), speed: 10);
      expect(next.flux.seconds, 600);
    });
  });

  group('Улучшения потока (L1)', () {
    test('цены растут линейно: 45 + 20·n и 30 + 15·m минут', () {
      expect(withFlux(0).flux.rateCostSeconds, 45 * 60);
      expect(withFlux(0, rate: 1).flux.rateCostSeconds, 65 * 60);
      expect(withFlux(0, rate: 49).flux.rateCostSeconds, 1025 * 60);
      expect(withFlux(0).flux.bankCostSeconds, 30 * 60);
      expect(withFlux(0, bank: 1).flux.bankCostSeconds, 45 * 60);
      expect(withFlux(0, bank: 22).flux.bankCostSeconds, 360 * 60);
    });

    test('покупка платится потоком', () {
      final s = engine.buyFluxRate(withFlux(3600));
      expect(s.flux.rateLevel, 1);
      expect(s.flux.seconds, 3600 - 45 * 60);
      final b = engine.buyFluxBank(withFlux(3600));
      expect(b.flux.bankLevel, 1);
      expect(b.flux.seconds, 3600 - 30 * 60);
    });

    test('не хватает потока — ничего не покупается', () {
      final s = withFlux(10);
      expect(engine.buyFluxRate(s), same(s));
      expect(engine.buyFluxBank(s), same(s));
    });

    test('больше часа потока за час и копилки больше суток нельзя', () {
      final top = withFlux(1e9, rate: 50, bank: 23);
      expect(top.flux.minutesPerHour, 60);
      expect(top.flux.bankSeconds, 24 * 3600);
      expect(engine.buyFluxRate(top), same(top));
      expect(engine.buyFluxBank(top), same(top));
    });

    test('окупаемость +1 мин/ч раз в сутки: 2 дня на старте, 45 у предела', () {
      // Кто заходит раз в сутки, получает с уровня +23 минуты в день.
      double days(FluxState f) => f.rateCostSeconds / (23 * 60) ;
      expect(days(withFlux(0).flux), closeTo(BalanceTargets.fluxPaybackFirstDays, 0.5));
      expect(days(withFlux(0, rate: 49).flux), closeTo(BalanceTargets.fluxPaybackLastDays, 1));
    });

    test('раз в сутки доходит до часа в час к нужному дню', () {
      const tol = BalanceTargets.fluxRateMaxDayTolerance;
      final all = fluxInvestor(share: 1);
      final half = fluxInvestor(share: 0.5);
      expect(all.rateMaxDay, isNotNull);
      expect(half.rateMaxDay, isNotNull);
      expect(all.rateMaxDay!.toDouble(),
          closeTo(BalanceTargets.fluxRateMaxDayAll, BalanceTargets.fluxRateMaxDayAll * tol),
          reason: 'весь поток — на ${all.rateMaxDay}-й день');
      expect(half.rateMaxDay!.toDouble(),
          closeTo(BalanceTargets.fluxRateMaxDayHalf, BalanceTargets.fluxRateMaxDayHalf * tol),
          reason: 'половина — на ${half.rateMaxDay}-й день');
    });

    test('тот, кто тратит половину, не застревает', () {
      // Первая версия цен ставила их вровень с копилкой — и игрок, который
      // хоть часть потока тратил, застревал на 10 мин/ч навсегда.
      final half = fluxInvestor(share: 0.5, every: const Duration(hours: 60));
      expect(half.rate24Day, isNotNull);
      expect(half.bankMaxDay, isNotNull);
    });
  });

  group('Сейв', () {
    test('поток и уровни переживают сохранение', () {
      final before = withFlux(1234.5, rate: 7, bank: 3);
      final json = ser.toJson(before, lastSeenMillis: 1);
      expect(json['flux'], 1234.5);
      expect(json['fluxRate'], 7);
      expect(json['fluxBank'], 3);

      final after = ser.fromJson(json, content: kGenerators, upgrades: kUpgrades, now: t0);
      expect(after.flux, before.flux);
    });

    test('поток переживает перенос кодом', () {
      final before = withFlux(777, rate: 2, bank: 5);
      const codec = SaveCodec();
      final code = encodeSaveCode(codec.encode(ser.toJson(before, lastSeenMillis: 1)));
      final back = decodeSaveCode(code);
      expect(back.isOk, isTrue, reason: back.message);
      final json = codec.decode(back.save).data!;
      final after = ser.fromJson(json, content: kGenerators, upgrades: kUpgrades, now: t0);
      expect(after.flux, before.flux);
    });

    test('сейв без ключей потока читается как ноль', () {
      final json = ser.toJson(fresh(), lastSeenMillis: 1)
        ..remove('flux')
        ..remove('fluxRate')
        ..remove('fluxBank');
      final after = ser.fromJson(json, content: kGenerators, upgrades: kUpgrades, now: t0);
      expect(after.flux, const FluxState());
    });

    test('мусор в ключах потока не роняет загрузку', () {
      final json = ser.toJson(fresh(), lastSeenMillis: 1)
        ..['flux'] = -5
        ..['fluxRate'] = 'много'
        ..['fluxBank'] = [1, 2];
      final after = ser.fromJson(json, content: kGenerators, upgrades: kUpgrades, now: t0);
      expect(after.flux, const FluxState());
    });
  });

  group('В игре', () {
    late DateTime now;

    /// Игра на экране с часами, которые двигает тест.
    Future<ProviderContainer> open(WidgetTester tester, GameState start) async {
      now = quietMoment;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialStateProvider.overrideWithValue(start),
            timeProvider.overrideWithValue(() => now),
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

    /// Прожить [d]: часы и тики идут вместе, кадры — чаще тиков.
    Future<void> live(WidgetTester tester, Duration d) async {
      const step = Duration(milliseconds: 50);
      for (var t = Duration.zero; t < d; t += step) {
        now = now.add(step);
        await tester.pump(step);
      }
    }

    GameState startWith(double flux) =>
        newGame(content: kGenerators, upgrades: kUpgrades, now: quietMoment)
            .copyWith(flux: FluxState(seconds: flux));

    testWidgets('усыплённое приложение получает поток, а не производство', (tester) async {
      final game = await open(tester, startWith(0));
      await live(tester, const Duration(seconds: 1));
      final before = game.read(gameProvider);

      // Система усыпила игру на час: таймеры стояли, часы шли.
      now = now.add(const Duration(hours: 1));
      await live(tester, const Duration(milliseconds: 200));

      final after = game.read(gameProvider);
      final oneTick = before.mlPerSecond * 3 * 0.25;
      expect(after.prestige.totalEverEarned - before.prestige.totalEverEarned,
          lessThan(oneTick),
          reason: 'час сна посчитан производством');
      expect(after.flux.seconds, closeTo(10 * 60, 1));
      final back = game.read(afkReturnProvider);
      expect(back, isNotNull, reason: 'экрану возвращения нечего показать');
      expect(back!.gained, closeTo(10 * 60, 1));
    });

    testWidgets('скрытая вкладка гонит сама и поток не копит', (tester) async {
      final game = await open(tester, startWith(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      final before = game.read(gameProvider).prestige.totalEverEarned;

      await live(tester, const Duration(seconds: 5));

      final after = game.read(gameProvider);
      expect(after.prestige.totalEverEarned, greaterThan(before));
      expect(after.flux.seconds, 0);
    });

    testWidgets('ускорение тратит поток, а время в игре идёт по часам', (tester) async {
      final game = await open(tester, startWith(3600));
      await live(tester, const Duration(seconds: 1));
      final played = game.read(gameProvider).stats.playSeconds;

      game.read(gameProvider.notifier).startBoost(5);
      expect(game.read(fluxSpeedProvider), 5);
      await live(tester, const Duration(seconds: 4));

      final s = game.read(gameProvider);
      expect(s.flux.seconds, closeTo(3600 - 4 * 4, 0.9));
      expect(s.stats.playSeconds - played, closeTo(4, 0.21),
          reason: 'ускорение накрутило время в игре');
    });

    testWidgets('скрыли игру — ускорение выключилось', (tester) async {
      final game = await open(tester, startWith(3600));
      game.read(gameProvider.notifier).startBoost(10);
      await live(tester, const Duration(milliseconds: 400));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await live(tester, const Duration(milliseconds: 400));

      expect(game.read(fluxSpeedProvider), 1);
      final left = game.read(gameProvider).flux.seconds;
      await live(tester, const Duration(seconds: 2));
      expect(game.read(gameProvider).flux.seconds, left);
    });

    testWidgets('поток кончился — ускорение выключилось', (tester) async {
      final game = await open(tester, startWith(1));
      game.read(gameProvider.notifier).startBoost(10);
      await live(tester, const Duration(seconds: 1));

      expect(game.read(gameProvider).flux.seconds, 0);
      expect(game.read(fluxSpeedProvider), 1);
    });

    testWidgets('без потока ускорение не включается', (tester) async {
      final game = await open(tester, startWith(0));
      game.read(gameProvider.notifier).startBoost(3);
      expect(game.read(fluxSpeedProvider), 1);
    });

    testWidgets('скорость не больше предела', (tester) async {
      final game = await open(tester, startWith(60));
      game.read(gameProvider.notifier).startBoost(50);
      expect(game.read(fluxSpeedProvider), Balance.current.fluxMaxSpeed);
    });
  });

  group('Возврат во вкладку', () {
    testWidgets('двойного счёта нет', (tester) async {
      // Регрессия: при resumed main.dart начислял оффлайн от момента ухода,
      // хотя тики всё это время шли. Отлучка короче бака засчитывалась
      // дважды: 2 мин → ×2.
      var now = quietMoment;
      final start = newGame(content: kGenerators, upgrades: kUpgrades, now: now);
      final boot = Bootstrap(
        state: start,
        saves: SaveService(storage: MemorySaveStorage()),
        settings: MemorySettingsStore(),
        offline: OfflineResult.none,
        fluxGained: 0,
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          initialStateProvider.overrideWithValue(boot.state),
          saveServiceProvider.overrideWithValue(boot.saves),
          settingsStoreProvider.overrideWithValue(boot.settings),
          timeProvider.overrideWithValue(() => now),
          clockProvider.overrideWithValue(GameClock(now: () => now)),
        ],
        child: VityaApp(boot: boot),
      ));
      addTearDown(() => tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed));
      final game = ProviderScope.containerOf(tester.element(find.byType(GarageScreen)));

      Future<void> live(Duration d) async {
        const step = Duration(milliseconds: 50);
        for (var t = Duration.zero; t < d; t += step) {
          now = now.add(step);
          await tester.pump(step);
        }
      }

      final before = game.read(gameProvider);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await live(const Duration(seconds: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await live(const Duration(milliseconds: 200));

      final after = game.read(gameProvider);
      final made = after.prestige.totalEverEarned - before.prestige.totalEverEarned;
      // Скрытая вкладка гонит сама — за 10.2 с около 10 с производства.
      // Двойной счёт дал бы вдвое больше; запас — на серию, которая
      // остывает не мгновенно.
      final lived = before.mlPerSecond * 10.2;
      expect(made, lessThan(lived * 1.5), reason: 'отлучка засчитана дважды');
      expect(made, greaterThan(lived * 0.9));
      expect(find.text('ПОКА ТЕБЯ НЕ БЫЛО'), findsNothing);
    });
  });
}
