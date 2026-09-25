import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/balance.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/content/sorts.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/flux_state.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/sort_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/game/heat_gauge.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';
import 'package:idle_game/ui/screens/shelf.dart';
import 'package:idle_game/ui/theme/garage.dart';
import 'package:idle_game/ui/widgets/boost_button.dart';
import 'package:idle_game/ui/widgets/shop.dart';

import 'support/moments.dart';
import 'support/shelf_tabs.dart';

/// Поток на экране: кнопка ускорения на главном экране и вкладка «ПОТОК».
///
/// Кнопка встала на главный экран, который только что ужимали ради
/// магазина, поэтому здесь же проверяется, что магазин своё не потерял:
/// две строки аппаратов, кнопки под палец (docs/DECISIONS.md, «Главный
/// экран»).
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const fonts = {
      GType.uiFamily: ['Rubik-Variable.ttf'],
      GType.numFamily: [
        'IBMPlexMono-Regular.ttf',
        'IBMPlexMono-Medium.ttf',
        'IBMPlexMono-SemiBold.ttf',
        'IBMPlexMono-Bold.ttf',
      ],
    };
    for (final MapEntry(key: family, value: files) in fonts.entries) {
      final loader = FontLoader(family);
      for (final file in files) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
  });

  /// Гараж с двумя купленными аппаратами и потоком. Метка времени — в ту же
  /// минуту, что и часы теста: иначе первый тик принял бы разрыв за сон и
  /// доначислил потока.
  GameState withFlux(double seconds, {int rate = 0, int bank = 0}) {
    const engine = GameEngine();
    final t = quietMoment;
    var s = GameState.initial(
      initialGenerators: kGenerators,
      initialUpgrades: kUpgrades,
      lastUpdateTime: t,
    );
    s = s.copyWith(resources: s.resources.copyWith(money: 1e30));
    s = engine.buyGeneratorBulk(s, 'banka', 5, t);
    s = engine.buyGeneratorBulk(s, 'bidon', 2, t);
    return s.copyWith(
      resources: s.resources.copyWith(money: 500),
      flux: FluxState(seconds: seconds, rateLevel: rate, bankLevel: bank),
    );
  }

  Future<ProviderContainer> openOn(WidgetTester tester, GameState state, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        initialStateProvider.overrideWithValue(state),
        timeProvider.overrideWithValue(() => quietMoment),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: GColors.bg,
          fontFamily: GType.uiFamily,
          useMaterial3: true,
        ),
        home: const Scaffold(body: GarageScreen()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    return ProviderScope.containerOf(tester.element(find.byType(GarageScreen)));
  }

  Rect rectOf(WidgetTester tester, Finder finder) {
    final box = tester.renderObject<RenderBox>(finder);
    return box.localToGlobal(Offset.zero) & box.size;
  }

  final tab = find.descendant(of: find.byType(Shelf), matching: find.text('ПОТОК'));

  /// Открыть вкладку потока в развёрнутом магазине. В «Гараже» шторка
  /// показывает только верх списка, а остальное лежит под краем экрана, и
  /// нажатие туда не попадёт — как и палец игрока.
  Future<void> openTab(WidgetTester tester) async {
    final scope = ProviderScope.containerOf(tester.element(find.byType(GarageScreen)));
    scope.read(shelfPositionProvider.notifier).state = ShelfPosition.shop;
    // pumpAndSettle не годится: шкала жара движется всегда.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('Кнопка на главном экране', () {
    testWidgets('без потока её нет, и вкладки потока тоже', (tester) async {
      await openOn(tester, withFlux(0), const Size(390, 844));
      expect(find.byType(BoostButton), findsNothing);
      expect(tab, findsNothing);
    });

    testWidgets('включает и выключает ускорение', (tester) async {
      final game = await openOn(tester, withFlux(3600), const Size(390, 844));
      expect(find.byType(BoostButton), findsOneWidget);

      await tester.tap(find.byType(BoostButton));
      await tester.pump(const Duration(milliseconds: 200));
      expect(game.read(fluxSpeedProvider), game.read(fluxChoiceProvider));
      expect(game.read(fluxSpeedProvider), greaterThan(1));

      await tester.tap(find.byType(BoostButton));
      await tester.pump(const Duration(milliseconds: 200));
      expect(game.read(fluxSpeedProvider), 1);
    });

    testWidgets('нажатие на кнопку не подкидывает дров', (tester) async {
      // Кнопка стоит рядом с пультом, а пульт — зона зажима.
      final game = await openOn(tester, withFlux(3600), const Size(390, 844));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(BoostButton)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(game.read(heatHoldingProvider), isFalse);
      await gesture.up();
    });

    testWidgets('пульт рядом с кнопкой по-прежнему зажимается', (tester) async {
      final game = await openOn(tester, withFlux(3600), const Size(390, 844));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(HeatPanel)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(game.read(heatHoldingProvider), isTrue);
      await gesture.up();
    });

    testWidgets('кнопка по высоте пульта и не меньше 44 точек', (tester) async {
      await openOn(tester, withFlux(3600), const Size(320, 640));
      final button = rectOf(tester, find.byType(BoostButton));
      final panel = rectOf(tester, find.byType(HeatPanel));
      expect(button.height, greaterThanOrEqualTo(44));
      expect(button.width, greaterThanOrEqualTo(44));
      expect(button.top, closeTo(panel.top, 0.5));
      expect(button.bottom, closeTo(panel.bottom, 0.5));
    });

    testWidgets('название сорта рядом с кнопкой не обрезается', (tester) async {
      final longest = kSorts.indexed
          .reduce((a, b) => a.$2.name.length >= b.$2.name.length ? a : b);
      final state = withFlux(3600).copyWith(sort: SortState(index: longest.$1, progress: 0.5));
      for (final size in const [Size(320, 640), Size(390, 844)]) {
        await openOn(tester, state, size);
        final name = tester.renderObject<RenderParagraph>(find.text(longest.$2.name));
        expect(name.didExceedMaxLines, isFalse,
            reason: 'на ${size.width.toInt()} точках «${longest.$2.name}» обрезано');
      }
    });
  });

  group('Цели главного экрана с кнопкой', () {
    // Цели задачи 2 плана и решения владельца: две строки аппаратов целиком,
    // кнопки не меньше 44 точек. 390×740 — телефон владельца с адресной
    // строкой Chrome.
    for (final screen in const [Size(320, 640), Size(390, 740), Size(390, 844)]) {
      final name = '${screen.width.toInt()}×${screen.height.toInt()}';

      testWidgets('на $name в магазине по-прежнему две строки', (tester) async {
        await openOn(tester, withFlux(3600), screen);
        expect(tester.takeException(), isNull);
        expect(find.byType(BoostButton), findsOneWidget);

        final list = rectOf(tester,
            find.ancestor(of: find.byType(StillRow).first, matching: find.byType(ListView)).first);
        final whole = find.byType(StillRow).evaluate().where((e) {
          final box = e.renderObject! as RenderBox;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          return rect.top >= list.top - 0.5 && rect.bottom <= list.bottom + 0.5;
        }).length;
        expect(whole, greaterThanOrEqualTo(2),
            reason: 'целиком видно строк: $whole');
      });

      testWidgets('на $name вкладка потока без переполнений, кнопки под палец',
          (tester) async {
        await openOn(tester, withFlux(3600), screen);
        await openTab(tester);
        expect(tester.takeException(), isNull);

        for (final key in const [
          'flux-speed-2',
          'flux-speed-3',
          'flux-speed-custom',
          'flux-boost',
          'flux-rate-buy',
          'flux-bank-buy',
        ]) {
          final f = find.byKey(Key(key));
          await tester.ensureVisible(f);
          await tester.pump();
          final r = rectOf(tester, f);
          expect(r.height, greaterThanOrEqualTo(44), reason: '$key: ${r.height} в высоту');
          expect(r.width, greaterThanOrEqualTo(44), reason: '$key: ${r.width} в ширину');
        }
        for (final label in const ['АППАРАТЫ', 'УЛУЧШЕНИЯ', 'МУДРОСТЬ', 'ПОТОК', 'ЦЕЛИ', 'ВИТЯ']) {
          final t = await shelfTab(tester, label);
          await tester.ensureVisible(t);
          await tester.pump();
          final hit = find.ancestor(of: t, matching: find.byType(GestureDetector)).first;
          expect(rectOf(tester, hit).height, greaterThanOrEqualTo(44), reason: label);
        }
      });
    }
  });

  group('Вкладка «ПОТОК»', () {
    testWidgets('появляется вместе с потоком', (tester) async {
      await openOn(tester, withFlux(60), const Size(390, 844));
      expect(tab, findsOneWidget);
    });

    testWidgets('включить и выключить', (tester) async {
      final game = await openOn(tester, withFlux(3600), const Size(390, 844));
      await openTab(tester);

      final boost = find.byKey(const Key('flux-boost'));
      await tester.ensureVisible(boost);
      await tester.tap(boost);
      await tester.pump(const Duration(milliseconds: 200));
      expect(game.read(fluxSpeedProvider), 2);
      expect(find.textContaining('ОСТАНОВИТЬ'), findsOneWidget);

      await tester.tap(boost);
      await tester.pump(const Duration(milliseconds: 200));
      expect(game.read(fluxSpeedProvider), 1);
    });

    testWidgets('выбрать скорость: ×2, ×3 и своя до предела', (tester) async {
      final game = await openOn(tester, withFlux(3600), const Size(390, 844));
      await openTab(tester);

      await tester.tap(find.byKey(const Key('flux-speed-3')));
      await tester.pump();
      expect(game.read(fluxChoiceProvider), 3);

      await tester.tap(find.byKey(const Key('flux-speed-custom')));
      await tester.pump();
      expect(game.read(fluxChoiceProvider), 5);

      final up = find.byKey(const Key('flux-speed-up'));
      for (var i = 0; i < 10; i++) {
        await tester.tap(up);
        await tester.pump();
      }
      expect(game.read(fluxChoiceProvider), Balance.current.fluxMaxSpeed,
          reason: 'своя скорость ушла за предел');

      final down = find.byKey(const Key('flux-speed-down'));
      for (var i = 0; i < 10; i++) {
        await tester.tap(down);
        await tester.pump();
      }
      expect(game.read(fluxChoiceProvider), 4,
          reason: 'своя скорость — от ×4: ×2 и ×3 уже есть кнопками');
    });

    testWidgets('смена скорости на ходу переключает ускорение', (tester) async {
      final game = await openOn(tester, withFlux(3600), const Size(390, 844));
      await openTab(tester);
      final boost = find.byKey(const Key('flux-boost'));
      await tester.ensureVisible(boost);
      await tester.tap(boost);
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('flux-speed-3')));
      await tester.tap(find.byKey(const Key('flux-speed-3')));
      await tester.pump();
      expect(game.read(fluxSpeedProvider), 3);
    });

    testWidgets('купить уровень за поток', (tester) async {
      final game = await openOn(tester, withFlux(3600), const Size(390, 844));
      await openTab(tester);

      final rate = find.byKey(const Key('flux-rate-buy'));
      await tester.ensureVisible(rate);
      await tester.tap(rate);
      await tester.pump();
      var f = game.read(gameProvider).flux;
      expect(f.rateLevel, 1);
      expect(f.seconds, 3600 - 45 * 60);

      // Осталось 15 минут — на копилку за 30 не хватает.
      final bank = find.byKey(const Key('flux-bank-buy'));
      await tester.ensureVisible(bank);
      await tester.tap(bank);
      await tester.pump();
      f = game.read(gameProvider).flux;
      expect(f.bankLevel, 0, reason: 'на копилку не хватало — а она купилась');
    });

    testWidgets('купить копилку за поток', (tester) async {
      final game = await openOn(tester, withFlux(3600), const Size(390, 844));
      await openTab(tester);
      final bank = find.byKey(const Key('flux-bank-buy'));
      await tester.ensureVisible(bank);
      await tester.tap(bank);
      await tester.pump();
      final f = game.read(gameProvider).flux;
      expect(f.bankLevel, 1);
      expect(f.seconds, 3600 - 30 * 60);
    });

    testWidgets('копилка полна — об этом сказано', (tester) async {
      await openOn(tester, withFlux(3600), const Size(390, 844));
      await openTab(tester);
      expect(find.byKey(const Key('flux-bank-full')), findsOneWidget);
    });

    testWidgets('копилка не полна — не сказано', (tester) async {
      await openOn(tester, withFlux(1800), const Size(390, 844));
      await openTab(tester);
      expect(find.byKey(const Key('flux-bank-full')), findsNothing);
    });
  });
}
