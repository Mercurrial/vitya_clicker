import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/game/heat_controller.dart';
import 'package:idle_game/ui/game/heat_gauge.dart';
import 'package:idle_game/ui/pixel/garage_scene.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';
import 'package:idle_game/ui/screens/shelf.dart';
import 'package:idle_game/ui/screens/shelf_sheet.dart';
import 'package:idle_game/ui/theme/garage.dart';
import 'package:idle_game/ui/widgets/shop.dart';
import 'package:idle_game/ui/widgets/top_panel.dart';

import 'support/moments.dart';

/// Шторка магазина: два положения (docs/DECISIONS.md, «Главный экран»).
///
/// Заведена, потому что на телефоне магазин занимал четверть экрана и была
/// видна одна строка списка. Цели владельца: в «Гараже» шапка около
/// четверти экрана, стена около 40 %, магазин — остальное; в «Магазине» —
/// около 90 %; кнопки не меньше 44 точек; гараж остаётся зоной зажима.
///
/// Шрифты — настоящие, как в shelf_layout_test.dart: Ahem рисует каждый знак
/// квадратом, и доли экрана с ним получаются про другой экран.
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

  GameState state() {
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
      resources: s.resources.copyWith(money: 500, ml: 300),
      // «Целый литр» открывает кнопку количества — она тоже кнопка.
      achievements: s.achievements.withUnlocked(['a_litre']),
    );
  }

  Future<ProviderContainer> openOn(
    WidgetTester tester,
    Size size, {
    DateTime? now,
    double textScale = 1.0,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        initialStateProvider.overrideWithValue(state()),
        timeProvider.overrideWithValue(() => now ?? quietMoment),
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

  final grabber = find.byKey(const ValueKey('shelf-grabber'));

  /// Какую долю экрана занимает магазин — от видимого края шторки до низа.
  /// Прозрачная полоса над краем (kShelfGrabOverhang) не в счёт.
  double shelfShare(WidgetTester tester, Size screen) {
    final top = rectOf(tester, grabber).top + kShelfGrabOverhang;
    return (screen.height - top) / screen.height;
  }

  /// Дать шторке доехать. pumpAndSettle здесь не годится: шкала жара
  /// движется всегда, и кадры не кончаются.
  ///
  /// Кадров два: на первом анимация только заводит тикер и ещё не сдвинута.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('Положения', () {
    testWidgets('по умолчанию — «Гараж»: шапка, стена и треть на магазин',
        (tester) async {
      const screen = Size(390, 844);
      final scope = await openOn(tester, screen);
      expect(tester.takeException(), isNull);

      expect(scope.read(shelfPositionProvider), ShelfPosition.garage);
      final share = shelfShare(tester, screen);
      expect(share, inInclusiveRange(0.33, 0.38),
          reason: 'магазин занимает ${(share * 100).toStringAsFixed(1)} % экрана');
      final top = rectOf(tester, find.byType(TopPanel)).height / screen.height;
      expect(top, lessThanOrEqualTo(0.25),
          reason: 'шапка — ${(top * 100).toStringAsFixed(1)} % экрана');
      final wall = 1 - share - top;
      expect(wall, greaterThanOrEqualTo(0.4),
          reason: 'стене осталось ${(wall * 100).toStringAsFixed(1)} % экрана');
      expect(find.byType(GarageScene).hitTestable(), findsOneWidget);
    });

    testWidgets('«Магазин» — около 90 % экрана, сверху касса, бак и серия',
        (tester) async {
      const screen = Size(390, 844);
      final scope = await openOn(tester, screen);

      await tester.tap(grabber);
      await settle(tester);

      expect(scope.read(shelfPositionProvider), ShelfPosition.shop);
      final share = shelfShare(tester, screen);
      expect(share, inInclusiveRange(0.88, 0.96),
          reason: 'магазин занимает ${(share * 100).toStringAsFixed(1)} % экрана');
      expect(find.byType(ShopStrip).hitTestable(), findsOneWidget);
      // Гараж закрыт шторкой — зажимать его нечем.
      expect(find.byType(GarageScene).hitTestable(), findsNothing);
    });

    testWidgets('на телефоне с адресной строкой магазин тоже главный',
        (tester) async {
      // 390×740 — так выглядит телефон владельца в Chrome.
      const screen = Size(390, 740);
      await openOn(tester, screen);
      expect(tester.takeException(), isNull);
      expect(shelfShare(tester, screen), greaterThanOrEqualTo(0.33));

      await tester.tap(grabber);
      await settle(tester);
      expect(shelfShare(tester, screen), greaterThanOrEqualTo(0.88));
    });

    testWidgets('тянется пальцем: вверх — в магазин, вниз — в гараж',
        (tester) async {
      final scope = await openOn(tester, const Size(390, 844));

      await tester.drag(grabber, const Offset(0, -300));
      await settle(tester);
      expect(scope.read(shelfPositionProvider), ShelfPosition.shop);

      await tester.drag(grabber, const Offset(0, 300));
      await settle(tester);
      expect(scope.read(shelfPositionProvider), ShelfPosition.garage);
    });

    // Первая версия шторки ловила только первый сдвиг пальца: на нём в
    // шторку добавлялись затемнение и полоска, Flutter пересобирал её
    // вместе с жестом, и она застревала посередине. Рывок в тесте этого не
    // видел — он укладывался в один сдвиг. Поэтому здесь палец идёт медленно
    // и мелкими шагами, как настоящий, и мышью тоже: так играют в браузере.
    for (final kind in const [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
      testWidgets('шторка идёт за пальцем всю дорогу (${kind.name})', (tester) async {
        final scope = await openOn(tester, const Size(390, 844));
        final before = rectOf(tester, grabber).top;

        final gesture = await tester.startGesture(tester.getCenter(grabber), kind: kind);
        for (var i = 0; i < 16; i++) {
          await gesture.moveBy(const Offset(0, -20));
          await tester.pump(const Duration(milliseconds: 100));
        }
        final moved = before - rectOf(tester, grabber).top;
        expect(moved, closeTo(320, 20), reason: 'шторка отстала от пальца: $moved из 320');

        await gesture.up();
        await settle(tester);
        expect(scope.read(shelfPositionProvider), ShelfPosition.shop);
      });
    }

    testWidgets('рывок одним событием тоже считается', (tester) async {
      // Медленный телефон присылает быстрый рывок одним сдвигом. По
      // умолчанию путь до порога перетаскивания терялся, и такой рывок
      // шторку не двигал вовсе.
      final scope = await openOn(tester, const Size(390, 740));
      final gesture = await tester.startGesture(tester.getCenter(grabber));
      await gesture.moveBy(const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await settle(tester);
      expect(scope.read(shelfPositionProvider), ShelfPosition.shop);
    });

    testWidgets('тянется и за строку вкладок', (tester) async {
      // В ручку на ходу не попасть — шапка шторки вся тянется.
      final scope = await openOn(tester, const Size(390, 844));

      await tester.drag(find.text('ЦЕЛИ'), const Offset(0, -300));
      await settle(tester);
      expect(scope.read(shelfPositionProvider), ShelfPosition.shop);
    });

    testWidgets('короткий рывок возвращает шторку на место', (tester) async {
      final scope = await openOn(tester, const Size(390, 844));

      await tester.timedDrag(
        grabber,
        const Offset(0, -60),
        const Duration(milliseconds: 600),
      );
      await settle(tester);
      expect(scope.read(shelfPositionProvider), ShelfPosition.garage);
    });

    testWidgets('полоска над магазином сворачивает его', (tester) async {
      final scope = await openOn(tester, const Size(390, 844));
      await tester.tap(grabber);
      await settle(tester);

      await tester.tap(find.byType(ShopStrip));
      await settle(tester);
      expect(scope.read(shelfPositionProvider), ShelfPosition.garage);
      expect(find.byType(GarageScene).hitTestable(), findsOneWidget);
    });

    testWidgets('вкладки работают в обоих положениях', (tester) async {
      await openOn(tester, const Size(390, 844));
      await tester.tap(find.text('УЛУЧШЕНИЯ'));
      await tester.pump();
      expect(find.byType(UpgradeRow), findsWidgets);

      await tester.tap(grabber);
      await settle(tester);
      await tester.tap(find.text('АППАРАТЫ'));
      await tester.pump();
      expect(find.byType(StillRow), findsWidgets);
    });
  });

  group('У Вити заняты руки', () {
    testWidgets('развёрнутый магазин ставит жар на паузу, свёрнутый снимает',
        (tester) async {
      final scope = await openOn(tester, const Size(390, 844));
      expect(scope.read(heatStatusProvider), isNot(HeatStatus.paused));

      await tester.tap(grabber);
      await settle(tester);
      expect(scope.read(heatStatusProvider), HeatStatus.paused);
      expect(scope.read(heatMultiplierProvider), 1.0);

      await tester.tap(find.byType(ShopStrip));
      await settle(tester);
      expect(scope.read(heatStatusProvider), isNot(HeatStatus.paused));
    });

    testWidgets('пока тянут шторку, пауза не наступает', (tester) async {
      // Потянуть — ещё не значит уйти в магазин: палец может передумать.
      final scope = await openOn(tester, const Size(390, 844));
      final gesture = await tester.startGesture(tester.getCenter(grabber));
      await gesture.moveBy(const Offset(0, -40));
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();
      expect(scope.read(heatStatusProvider), isNot(HeatStatus.paused));
      await gesture.up();
      await settle(tester);
    });
  });

  group('Гараж — зона зажима', () {
    Future<void> expectHolds(WidgetTester tester, ProviderContainer scope, Finder where) async {
      final gesture = await tester.startGesture(tester.getCenter(where));
      await tester.pump(const Duration(milliseconds: 50));
      expect(scope.read(heatHoldingProvider), isTrue,
          reason: 'зажим не начался: $where');
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(scope.read(heatHoldingProvider), isFalse);
    }

    testWidgets('зажимается и сцена, и пульт под ней', (tester) async {
      final scope = await openOn(tester, const Size(390, 844));
      await expectHolds(tester, scope, find.byType(GarageScene));
      await expectHolds(tester, scope, find.byType(HeatPanel));
    });

    testWidgets('в развёрнутом магазине гараж не зажимается', (tester) async {
      final scope = await openOn(tester, const Size(390, 844));
      final where = tester.getCenter(find.byType(GarageScene));
      await tester.tap(grabber);
      await settle(tester);

      final gesture = await tester.startGesture(where);
      await tester.pump(const Duration(milliseconds: 50));
      expect(scope.read(heatHoldingProvider), isFalse);
      await gesture.up();
    });
  });

  group('Кнопки под палец', () {
    const minTap = 44.0;

    for (final screen in const [Size(320, 640), Size(390, 740), Size(390, 844)]) {
      final name = '${screen.width.toInt()}×${screen.height.toInt()}';

      testWidgets('на $name все кнопки не меньше 44 точек', (tester) async {
        await openOn(tester, screen, now: eventMoment);
        expect(tester.takeException(), isNull);

        void check(Finder f, String what) {
          expect(f, findsWidgets, reason: 'не нашлось: $what');
          for (final e in f.evaluate()) {
            final size = (e.renderObject! as RenderBox).size;
            expect(size.height, greaterThanOrEqualTo(minTap),
                reason: '$what: ${size.height} точек в высоту');
            expect(size.width, greaterThanOrEqualTo(minTap),
                reason: '$what: ${size.width} точек в ширину');
          }
        }

        check(grabber, 'ручка шторки');
        check(find.byType(SellButton), 'продажа');
        check(find.byType(BuyButton), 'покупка аппарата');
        for (final tab in ['АППАРАТЫ', 'УЛУЧШЕНИЯ', 'ЦЕЛИ', 'ВИТЯ']) {
          check(
            find.ancestor(of: find.text(tab), matching: find.byType(GestureDetector)).first,
            'вкладка «$tab»',
          );
        }
        check(
          find
              .ancestor(
                of: find.descendant(of: find.byType(Shelf), matching: find.text('×1')),
                matching: find.byType(GestureDetector),
              )
              .first,
          'кнопка количества',
        );

        await tester.tap(grabber);
        await settle(tester);
        check(find.byType(ShopStrip), 'полоска над магазином');
      });
    }
  });

  group('Место под то, что придёт', () {
    testWidgets('шапка не больше четверти экрана и с гостем, и без', (tester) async {
      // Стена берёт всё, что оставили шапка и магазин. Шапка вырастет —
      // стена молча сожмётся; тест скажет об этом раньше.
      for (final screen in const [Size(320, 640), Size(390, 740), Size(390, 844)]) {
        for (final now in [quietMoment, eventMoment]) {
          await openOn(tester, screen, now: now);
          expect(tester.takeException(), isNull);
          // «Примерно четверть» — на 320×640 шапка выходит 25,4 %.
          expect(rectOf(tester, find.byType(TopPanel)).height / screen.height,
              lessThanOrEqualTo(0.27),
              reason: 'на ${screen.width.toInt()}×${screen.height.toInt()}');
        }
      }
    });

    testWidgets('гость пришёл и ушёл — ничего не сдвинулось', (tester) async {
      // Место гостя стоит всегда: гость приходит каждые десять минут, и
      // прыгай вёрстка при каждом его приходе, кнопки уезжали бы из-под пальца.
      await openOn(tester, const Size(390, 740), now: quietMoment);
      final quiet = rectOf(tester, find.byType(GarageScene));
      await openOn(tester, const Size(390, 740), now: eventMoment);
      expect(rectOf(tester, find.byType(GarageScene)), quiet);
    });

    testWidgets('обе продажи — на одном уровне', (tester) async {
      await openOn(tester, const Size(390, 844), now: eventMoment);
      final buttons = find.byType(SellButton).evaluate().map((e) {
        final box = e.renderObject! as RenderBox;
        return box.localToGlobal(Offset.zero) & box.size;
      }).toList();
      expect(buttons, hasLength(2));
      expect(buttons[0].top, buttons[1].top);
      expect(buttons[0].height, buttons[1].height);
    });

    testWidgets('крупный системный шрифт не ужимает вкладки, а листает их',
        (tester) async {
      // Вкладок станет больше — поток и мудрость (docs/PLAN-1.0.md). Тот же
      // случай уже сейчас даёт крупный шрифт в настройках телефона.
      await openOn(tester, const Size(320, 640), textScale: 1.3);
      expect(tester.takeException(), isNull);

      for (final label in ['АППАРАТЫ', 'УЛУЧШЕНИЯ']) {
        final text = find.text(label);
        final room = rectOf(
          tester,
          find.ancestor(of: text, matching: find.byType(FittedBox)).first,
        ).width;
        final natural = tester.renderObject<RenderBox>(text).size.width;
        expect(room / natural, greaterThanOrEqualTo(0.95),
            reason: '«$label» ужалась до ${(room / natural).toStringAsFixed(2)}');
      }
    });
  });
}
