import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/buyers.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';
import 'package:idle_game/ui/theme/garage.dart';

import 'support/moments.dart';

/// Метка времени производства: до какого момента самогон уже посчитан.
///
/// Тик считает производство от [GameState.lastUpdateTime] до «сейчас».
/// Касание, продажа и покупки сами ничего не производят, но раньше
/// переставляли метку на «сейчас» — и выбрасывали всё, что нагналось с
/// прошлого тика. Симулятор делает действия в тот же момент, что и тик, и
/// этой потери не видел, поэтому ловить её приходится здесь.
void main() {
  const engine = GameEngine();
  final t0 = DateTime.utc(2026, 3, 1, 12);
  const tick = Duration(milliseconds: 200);

  /// Гараж с аппаратами, деньгами на покупки и самогоном на продажу.
  GameState garage() {
    var s = newGame(content: kGenerators, upgrades: kUpgrades, now: t0);
    s = s.copyWith(resources: s.resources.copyWith(money: 1e6));
    s = engine.buyGeneratorBulk(s, 'banka', 5, t0);
    s = engine.buyGeneratorBulk(s, 'bidon', 2, t0);
    return s.copyWith(resources: s.resources.copyWith(ml: 10));
  }

  group('Движок', () {
    test('касание, продажа и покупки не двигают метку', () {
      final start = garage();
      final between = t0.add(const Duration(milliseconds: 120));
      final actions = <String, GameState Function(GameState)>{
        'касание': (s) => engine.registerTouch(s, between),
        'продажа': (s) => engine.sellTo(s, kBuyers.first, between),
        'покупка аппарата': (s) => engine.buyGenerator(s, 'banka', between),
        'покупка пачкой': (s) => engine.buyGeneratorBulk(s, 'banka', 10, between),
        'покупка улучшения': (s) => engine.buyUpgrade(s, 'heat_1', between),
      };

      for (final e in actions.entries) {
        final after = e.value(start);
        expect(after, isNot(equals(start)),
            reason: 'действие «${e.key}» не состоялось — проверять нечего');
        expect(after.lastUpdateTime, t0,
            reason: 'метку сдвинуло действие «${e.key}»: производство с '
                'прошлого тика пропадёт');
      }
    });

    /// [ticks] тиков по 200 мс на жаре ×2; [between] — что игрок делает
    /// посередине между тиками. Возвращает, сколько нагнано.
    double made(int ticks, GameState Function(GameState s, DateTime at)? between) {
      final start = garage();
      var s = start;
      var now = t0;
      for (var i = 0; i < ticks; i++) {
        if (between != null) s = between(s, now.add(tick ~/ 2));
        now = now.add(tick);
        s = engine.processTick(s, now, heatMultiplier: 2);
      }
      return s.prestige.totalEverEarned - start.prestige.totalEverEarned;
    }

    test('касания между тиками не съедают производство', () {
      final expected = garage().mlPerSecond * 2 * 50 * 0.2;
      expect(made(50, null), closeTo(expected, 1e-6));
      expect(made(50, engine.registerTouch), closeTo(expected, 1e-6),
          reason: 'касание выбросило производство с прошлого тика');
    });

    test('продажи между тиками не съедают производство', () {
      final expected = garage().mlPerSecond * 2 * 50 * 0.2;
      expect(made(50, (s, at) => engine.sellTo(s, kBuyers.first, at)),
          closeTo(expected, 1e-6),
          reason: 'продажа выбросила производство с прошлого тика');
    });
  });

  group('После сна', () {
    late DateTime now;

    /// Игра на экране с часами, которые двигает тест.
    Future<ProviderContainer> open(WidgetTester tester) async {
      now = quietMoment;
      final start = newGame(content: kGenerators, upgrades: kUpgrades, now: now);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialStateProvider.overrideWithValue(
              start.copyWith(resources: start.resources.copyWith(money: 1e6, ml: 10)),
            ),
            timeProvider.overrideWithValue(() => now),
          ],
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark, fontFamily: GType.uiFamily),
            home: const Scaffold(body: GarageScreen()),
          ),
        ),
      );
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

    // Разрыв ловит тик — по метке времени. Если первым после пробуждения
    // пришло действие и сдвинуло метку, разрыва тик уже не видит, и час сна
    // пропадает без следа.
    final first = <String, void Function(GameNotifier g)>{
      'касание': (g) => g.registerTouch(),
      'продажа': (g) => g.sellTo(kBuyers.first),
      'покупка': (g) => g.buyGenerator('banka'),
    };
    for (final e in first.entries) {
      testWidgets('${e.key} раньше первого тика не съедает поток', (tester) async {
        final game = await open(tester);
        await live(tester, const Duration(seconds: 1));

        // Система усыпила игру на час: таймеры стояли, часы шли.
        now = now.add(const Duration(hours: 1));
        e.value(game.read(gameProvider.notifier));
        await live(tester, tick);

        expect(game.read(gameProvider).flux.seconds, closeTo(10 * 60, 1),
            reason: 'действие «${e.key}» спрятало разрыв от тика');
        expect(game.read(afkReturnProvider), isNotNull,
            reason: 'экрану возвращения нечего показать');
      });
    }
  });
}
