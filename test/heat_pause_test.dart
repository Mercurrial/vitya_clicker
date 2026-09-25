import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/sort_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/game/heat_controller.dart';

import 'support/moments.dart';

/// «У Вити заняты руки»: пока магазин развёрнут, жар стоит.
///
/// Решение владельца (docs/DECISIONS.md, «Главный экран»), разбор — в
/// docs/PLAN-1.0.md, раздел 9. Жар, серия и сорт не растут и не пропадают,
/// производство идёт по базе, а покупка жар не подкидывает. Иначе магазин
/// стал бы местом, где серия копится без пальца.
void main() {
  group('Контроллер жара на паузе', () {
    /// Довести жар до окна и набрать немного серии.
    Future<HeatController> warmed(WidgetTester tester) async {
      final c = HeatController(vsync: tester);
      c.startStoking();
      for (var i = 0; i < 200 && c.status != HeatStatus.inWindow; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(c.status, HeatStatus.inWindow, reason: 'жар так и не дошёл до окна');
      // Ровно в окне серия растёт; отпускаем, пока жар ещё в нём.
      await tester.pump(const Duration(milliseconds: 300));
      c.stopStoking();
      await tester.pump(const Duration(milliseconds: 50));
      expect(c.series, greaterThan(0));
      return c;
    }

    testWidgets('жар, серия и окно стоят, сколько ни жди', (tester) async {
      final c = await warmed(tester);
      c.paused = true;
      final heat = c.heat;
      final series = c.series;
      final window = c.windowStart;

      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(c.heat, heat, reason: 'жар остыл на паузе');
      expect(c.series, series, reason: 'серия растаяла на паузе');
      expect(c.windowStart, window, reason: 'окно уехало на паузе');
      expect(c.status, HeatStatus.paused);
      c.dispose();
    });

    testWidgets('серия на паузе не множит, но и не пропадает', (tester) async {
      final c = await warmed(tester);
      final before = c.seriesMultiplier;
      expect(before, greaterThan(1.0));

      c.paused = true;
      expect(c.multiplier, 1.0, reason: 'производство на паузе — по базе');
      expect(c.seriesMultiplier, before);
      c.dispose();
    });

    testWidgets('покупка на паузе жар не подкидывает', (tester) async {
      final c = await warmed(tester);

      // Без паузы покупка жар подкидывает — иначе проверка ниже ничего не
      // значит.
      final cold = c.heat;
      c.stokeOnPurchase();
      expect(c.heat, greaterThan(cold));

      c.paused = true;
      final heat = c.heat;
      c.stokeOnPurchase();
      c.stokeOnPurchase();
      await tester.pump(const Duration(seconds: 5));
      expect(c.heat, heat);
      c.dispose();
    });

    testWidgets('на паузе зажать нельзя, а зажатый палец отпускается',
        (tester) async {
      final c = HeatController(vsync: tester);
      c.startStoking();
      await tester.pump(const Duration(milliseconds: 100));
      c.paused = true;
      expect(c.isStoking, isFalse,
          reason: 'после сворачивания жар поехал бы вверх без пальца');

      c.startStoking();
      expect(c.isStoking, isFalse);
      c.dispose();
    });

    testWidgets('после паузы всё продолжается с того же места', (tester) async {
      final c = await warmed(tester);
      c.paused = true;
      await tester.pump(const Duration(seconds: 30));
      final heat = c.heat;
      final series = c.series;

      c.paused = false;
      expect(c.heat, heat);
      expect(c.series, series);
      expect(c.status, isNot(HeatStatus.paused));

      // Руки освободились — жар снова живой: без пальца он остывает.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.heat, lessThan(heat));
      c.dispose();
    });
  });

  group('Тик игры на паузе', () {
    GameState start() {
      const engine = GameEngine();
      var s = GameState.initial(
        initialGenerators: kGenerators,
        initialUpgrades: kUpgrades,
        lastUpdateTime: quietMoment,
      );
      s = s.copyWith(resources: s.resources.copyWith(money: 1e9));
      s = engine.buyGeneratorBulk(s, 'banka', 5, quietMoment);
      return s.copyWith(
        resources: s.resources.copyWith(money: 0, ml: 0),
        sort: const SortState(index: 1, progress: 0.5),
      );
    }

    /// Игра без экрана: жар выставляется руками, часы двигаются руками.
    Future<({ProviderContainer scope, void Function(Duration) advance})> open(
      WidgetTester tester,
      GameState state,
    ) async {
      var now = quietMoment;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          initialStateProvider.overrideWithValue(state),
          timeProvider.overrideWithValue(() => now),
        ],
        child: const SizedBox(),
      ));
      final scope = ProviderScope.containerOf(tester.element(find.byType(SizedBox)));
      scope.read(gameProvider); // запускает тик
      return (scope: scope, advance: (Duration d) => now = now.add(d));
    }

    /// Прожить секунду игры: часы вперёд и тики за неё.
    Future<void> second(WidgetTester tester, void Function(Duration) advance) async {
      for (var i = 0; i < 5; i++) {
        advance(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('производство по базе, даже если серия набрана', (tester) async {
      final game = await open(tester, start());
      // Первые тики открывают цели за банки, а цели множат производство.
      // Базу берём, когда они уже взяты.
      await second(tester, game.advance);
      final base = game.scope.read(gameProvider).mlPerSecond;

      game.scope.read(heatMultiplierProvider.notifier).state = 3.0;
      game.scope.read(heatStatusProvider.notifier).state = HeatStatus.paused;
      final before = game.scope.read(gameProvider).resources.ml;
      await second(tester, game.advance);

      final made = game.scope.read(gameProvider).resources.ml - before;
      expect(made, closeTo(base, base * 0.01),
          reason: 'на паузе серия ×3 не должна множить производство');

      // Для сравнения: в окне та же серия множит.
      game.scope.read(heatStatusProvider.notifier).state = HeatStatus.inWindow;
      final mid = game.scope.read(gameProvider).resources.ml;
      await second(tester, game.advance);
      expect(game.scope.read(gameProvider).resources.ml - mid,
          closeTo(base * 3, base * 0.03));
    });

    testWidgets('сорт стоит, а без паузы сползает', (tester) async {
      final game = await open(tester, start());
      game.scope.read(heatStatusProvider.notifier).state = HeatStatus.paused;
      final sort = game.scope.read(gameProvider).sort;
      for (var i = 0; i < 10; i++) {
        await second(tester, game.advance);
      }
      expect(game.scope.read(gameProvider).sort, sort,
          reason: 'минута в магазине стоила бы ступени сорта');

      game.scope.read(heatStatusProvider.notifier).state = HeatStatus.off;
      await second(tester, game.advance);
      expect(game.scope.read(gameProvider).sort.progress, lessThan(sort.progress));
    });

    testWidgets('автопродажа идёт по часам и на паузе', (tester) async {
      var state = start();
      // «Первая тысяча» открывает автопродажу. Бак почти полный — за пару
      // секунд нальётся и сдастся сам.
      state = state.copyWith(
        achievements: state.achievements.withUnlocked(['a_thousand']),
      );
      state = state.copyWith(
        resources: state.resources.copyWith(ml: state.tankCapacity - 1),
      );
      final game = await open(tester, state);
      game.scope.read(heatStatusProvider.notifier).state = HeatStatus.paused;

      await second(tester, game.advance);
      await second(tester, game.advance);

      expect(game.scope.read(gameProvider).resources.money, greaterThan(0),
          reason: 'бак на паузе не сдался — автопродажа встала вместе с жаром');
    });
  });
}
