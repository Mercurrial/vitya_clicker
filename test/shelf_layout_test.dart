import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';
import 'package:idle_game/ui/screens/shelf.dart';
import 'package:idle_game/ui/theme/garage.dart';
import 'package:idle_game/ui/widgets/shop.dart';

import 'support/moments.dart';
import 'support/shelf_tabs.dart';

/// Нижняя полка на узком экране: кнопка количества, вкладки и место под список.
///
/// Здесь — настоящие шрифты игры, а не Ahem, как в остальных тестах вёрстки.
/// Ahem рисует каждый знак квадратом в кегль, и вопрос «сколько строк
/// влезает» он решает неверно: строка аппарата выходит в 80 точек вместо 71,
/// подпись вкладки — на треть шире настоящей. Проверять ими то, что видит
/// игрок, — значит проверять другой экран.
///
/// Шрифт, раз загруженный, остаётся на весь файл: поэтому эти проверки живут
/// отдельно и не делят файл с теми, что рассчитаны на Ahem.
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

  /// Самая высокая строка — у купленного аппарата: название, выработка и
  /// полоска до следующего множителя. Поэтому купленных два.
  ///
  /// Сейв записан в ту же минуту, в которую открыт: иначе за оффлайн бак
  /// наливается до краёв, «Целый литр» берётся сам, и кнопка есть всегда.
  GameState stateWith({required bool bulk, double money = 500}) {
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
      resources: s.resources.copyWith(money: money),
      // «Целый литр» открывает покупку пачками.
      achievements: bulk ? s.achievements.withUnlocked(['a_litre']) : s.achievements,
    );
  }

  Future<void> openOn(WidgetTester tester, GameState state, Size size) async {
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
  }

  Rect rectOf(WidgetTester tester, Finder finder) {
    final box = tester.renderObject<RenderBox>(finder);
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Подпись режима на кнопке количества. Ищем внутри полки: «×1» пишет и
  /// множитель серии на пульте.
  Finder amount(String label) =>
      find.descendant(of: find.byType(Shelf), matching: find.text(label));

  const tabs = ['АППАРАТЫ', 'УЛУЧШЕНИЯ', 'МУДРОСТЬ', 'ЦЕЛИ', 'ВИТЯ'];

  group('Кнопка количества', () {
    testWidgets('до «Целого литра» её нет', (tester) async {
      await openOn(tester, stateWith(bulk: false), const Size(320, 640));
      for (final (_, label) in kBuyModes) {
        expect(amount(label), findsNothing);
      }
    });

    testWidgets('одна, справа в строке вкладок', (tester) async {
      await openOn(tester, stateWith(bulk: true), const Size(320, 640));
      expect(tester.takeException(), isNull);

      // Со строкой, а не с последней вкладкой: на 320 точках вкладок больше,
      // чем влезает, строка листается, и последней вкладки может не быть на
      // экране.
      final button = rectOf(tester, amount('×1'));
      final strip = rectOf(tester, shelfTabs);
      expect(button.left, greaterThanOrEqualTo(strip.right),
          reason: 'кнопка должна стоять справа от вкладок');
      expect((button.center.dy - strip.center.dy).abs(), lessThan(1),
          reason: 'кнопка ушла из строки вкладок: $button против $strip');

      // Остальных режимов на экране нет: не ряд, а одна кнопка.
      for (final (_, label) in kBuyModes.skip(1)) {
        expect(amount(label), findsNothing);
      }
    });

    testWidgets('ходит по кругу ×1 → ×10 → ×100 → МАКС → ×1', (tester) async {
      await openOn(tester, stateWith(bulk: true), const Size(320, 640));
      final scope = ProviderScope.containerOf(tester.element(find.byType(Shelf)));

      final order = [...kBuyModes, kBuyModes.first];
      for (var i = 0; i < order.length - 1; i++) {
        final (value, label) = order[i];
        expect(scope.read(buyAmountProvider), value);
        expect(amount(label), findsOneWidget);
        await tester.tap(amount(label));
        await tester.pump();
      }
      expect(scope.read(buyAmountProvider), kBuyModes.first.$1);
    });

    testWidgets('×10 и правда покупает десять', (tester) async {
      await openOn(tester, stateWith(bulk: true, money: 1e12), const Size(320, 640));
      final scope = ProviderScope.containerOf(tester.element(find.byType(Shelf)));
      int banki() => scope
          .read(gameProvider)
          .generators
          .items
          .firstWhere((g) => g.id == 'banka')
          .ownedCount;

      await tester.tap(amount('×1'));
      await tester.pump();
      final before = banki();
      await tester.tap(find.descendant(
        of: find.byType(StillRow).first,
        matching: find.byType(BuyButton),
      ));
      await tester.pump();

      expect(banki(), before + 10);
    });
  });

  group('Узкий экран 320×640', () {
    testWidgets('подписи вкладок не ужимаются рядом с кнопкой', (tester) async {
      // Первая кнопка по кругу, шириной в 56, резала «УЛУЧШЕНИЯ», и её
      // заменили рядом. Подпись в FittedBox не обрежется — она сожмётся, и
      // это тоже потеря: мелкий кегль на телефоне не читается.
      await openOn(tester, stateWith(bulk: true), const Size(320, 640));

      for (final label in tabs) {
        final text = await shelfTab(tester, label);
        final room = rectOf(
          tester,
          find.ancestor(of: text, matching: find.byType(FittedBox)).first,
        ).width;
        final natural = tester.renderObject<RenderBox>(text).size.width;
        expect(room / natural, greaterThanOrEqualTo(0.95),
            reason: '«$label» ужалась до ${(room / natural).toStringAsFixed(2)}: '
                'нужно $natural точек, досталось $room');
      }
    });

  });

  // Ряд «БРАТЬ ПО» стоял первым в списке, и на 320×640 строкам оставалось 41
  // точка из 83 — половина первого аппарата. Список, в котором не видно ни
  // одной строки целиком, выглядит пустым: покупать нечего.
  //
  // Двух строк на 320×640 тогда не было и без ряда: им нужно 154 точки,
  // списку доставалось 83. Владелец решил (docs/DECISIONS.md, «Главный
  // экран»): магазин — шторка, в «Гараже» на треть экрана, но не меньше двух
  // строк; остальное — разворотом. 390×740 — телефон владельца с адресной
  // строкой Chrome.
  for (final (screen, rows) in const [
    (Size(320, 640), 2),
    (Size(390, 740), 2),
    (Size(390, 844), 2),
  ]) {
    testWidgets(
        'на ${screen.width.toInt()}×${screen.height.toInt()} в списке '
        'целиком видно строк аппаратов: $rows', (tester) async {
      await openOn(tester, stateWith(bulk: true), screen);
      expect(tester.takeException(), isNull);

      final list = rectOf(tester,
          find.ancestor(of: find.byType(StillRow).first, matching: find.byType(ListView)).first);
      final whole = find.byType(StillRow).evaluate().where((e) {
        final box = e.renderObject! as RenderBox;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        return rect.top >= list.top - 0.5 && rect.bottom <= list.bottom + 0.5;
      }).length;

      expect(whole, greaterThanOrEqualTo(rows),
          reason: 'целиком видно строк: $whole; списку досталось '
              '${list.height.toStringAsFixed(1)} точек');
    });
  }
}
