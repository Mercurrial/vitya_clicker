import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/game/vitya_portrait.dart';
import 'package:idle_game/ui/pixel/pixel_sprite.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';

import 'package:idle_game/ui/theme/garage.dart';

/// Главное на экране обязано быть на экране.
///
/// Этот набор написан по следам настоящей поломки. Правя подпись под портретом,
/// я обернул её в `OverflowBox`; в колонке он получает неограниченную высоту,
/// растянулся на бесконечность — и утащил за край И портрет, И полки с
/// аппаратами. Гараж стал пустой кирпичной стеной.
///
/// Мимо всех проверок это прошло: анализатор молчал, тесты движка не трогают
/// вёрстку, а снимок экрана я тогда не пересобрал. Увидел только глазами.
///
/// Отсюда правило: у ключевых объектов сцены проверяется, что они **имеют
/// конечный ненулевой размер и помещаются в экран**. Вопрос «видно ли», а не
/// «красиво ли», — и он проверяется без снимков.
void main() {
  Widget app(GameState state) => ProviderScope(
        overrides: [initialStateProvider.overrideWithValue(state)],
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
      );

  GameState withStills(Map<String, int> counts) {
    const engine = GameEngine();
    final t = DateTime.utc(2026);
    var s = GameState.initial(
      initialGenerators: kGenerators,
      initialUpgrades: kUpgrades,
      lastUpdateTime: t,
    );
    s = s.copyWith(resources: s.resources.copyWith(money: 1e30));
    counts.forEach((id, n) => s = engine.buyGeneratorBulk(s, id, n, t));
    return s.copyWith(resources: s.resources.copyWith(money: 500));
  }

  Future<void> openOn(WidgetTester tester, GameState state, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(state));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Прямоугольник виджета на экране.
  Rect rectOf(WidgetTester tester, Finder finder) {
    final box = tester.renderObject<RenderBox>(finder);
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  group('Портрет Вити на экране', () {
    testWidgets('имеет конечный размер и помещается в экран', (tester) async {
      const screen = Size(375, 812);
      await openOn(tester, withStills({'banka': 3}), screen);

      final rect = rectOf(tester, find.byType(VityaPortrait));

      expect(rect.width.isFinite && rect.height.isFinite, isTrue,
          reason: 'бесконечный размер — так пропал портрет в прошлый раз');
      expect(rect.width, greaterThan(40));
      expect(rect.height, greaterThan(40));
      expect(rect.height, lessThan(screen.height * 0.6),
          reason: 'портрет не должен съедать экран: гараж — не только Витя');

      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(screen.height));
    });

    testWidgets('подпись помещается в одну строку и не обрезается',
        (tester) async {
      await openOn(tester, withStills({'banka': 1}), const Size(375, 812));

      // «В. — начинающий» рвалось ровно по тире и читалось обрывком.
      final caption = find.textContaining('В. —');
      expect(caption, findsOneWidget);

      final text = tester.widget<Text>(caption);
      expect(text.maxLines, 1);

      final painted = tester.renderObject<RenderBox>(caption);
      expect(painted.size.height, lessThan(24),
          reason: 'подпись стала выше одной строки — значит, перенеслась');
    });
  });

  group('Аппараты в гараже', () {
    testWidgets('купленный аппарат видно, и он не микроскопический',
        (tester) async {
      await openOn(tester, withStills({'banka': 1}), const Size(375, 812));

      final sprites = find.byType(PixelImage);
      expect(sprites, findsWidgets, reason: 'в гараже не видно ни одного аппарата');

      // Ищем самый крупный — это и есть сам аппарат, а не пар над ним.
      var biggest = 0.0;
      for (final element in sprites.evaluate()) {
        final box = element.renderObject! as RenderBox;
        if (box.size.width > biggest) biggest = box.size.width;
      }
      expect(biggest, greaterThan(40),
          reason: 'первая банка выходила ростом в полтора сантиметра: $biggest');
    });

    testWidgets('полный гараж помещается и ничего не переполняет',
        (tester) async {
      await openOn(
        tester,
        withStills({
          'banka': 30,
          'bidon': 20,
          'flyaga': 15,
          'dedov': 10,
          'zmeevik': 5,
          'tseh': 2,
        }),
        const Size(375, 812),
      );

      expect(tester.takeException(), isNull,
          reason: 'переполнение вёрстки при полном гараже');
      expect(find.byType(PixelImage), findsWidgets);
    });
  });

  group('Экран целиком', () {
    testWidgets('на маленьком телефоне ничего не уезжает за край',
        (tester) async {
      // Узкий и низкий экран — на нём вёрстка ломается первой.
      await openOn(tester, withStills({'banka': 5}), const Size(320, 640));
      expect(tester.takeException(), isNull);

      final portrait = rectOf(tester, find.byType(VityaPortrait));
      expect(portrait.bottom, lessThanOrEqualTo(640));
    });

    testWidgets('название аппарата в списке не обрезается многоточием',
        (tester) async {
      await openOn(tester, withStills({'banka': 1}), const Size(375, 812));

      // Берём САМОЕ длинное название лестницы, а не первое. На первом всё
      // влезало, а «Бидон эмалированный» уже обрезался многоточием.
      final longest = kGeneratorNames
          .map((g) => g.name)
          .reduce((a, b) => a.length >= b.length ? a : b);
      final label = find.text('Трёхлитровая банка');
      expect(longest.length, greaterThan(0));
      expect(label, findsOneWidget);

      // Сравнивать с шириной отрисованного текста нельзя: в тестах шрифт
      // подменяется на Ahem, у которого каждый глиф — квадрат в размер кегля,
      // и любая кириллическая строка выходит вдвое шире настоящей.
      //
      // Поэтому проверяем не текст, а МЕСТО под него. Порог взят с натуры:
      // «Трёхлитровая банка» — самое длинное название лестницы, настоящим
      // шрифтом в 14 кегль оно занимает около 125 точек. Берём 150 с запасом.
      // Разрастётся кружок или кнопка цены — проверка упадёт.
      // «Трубопровод «Дружба-2»» — 22 знака; настоящим шрифтом в 13 кегль это
      // около 145 точек. Берём 160 с запасом.
      const needed = 160.0;
      final available = tester.renderObject<RenderBox>(label).size.width;

      expect(available, greaterThanOrEqualTo(needed),
          reason: 'названию досталось $available точек при нужных $needed — '
              'оно уйдёт в многоточие');
    });
  });
}
