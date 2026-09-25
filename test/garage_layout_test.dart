import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/content/sorts.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/sort_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/game/heat_gauge.dart';
import 'package:idle_game/ui/game/vitya_portrait.dart';
import 'package:idle_game/ui/pixel/garage_scene.dart';
import 'package:idle_game/ui/pixel/pixel_sprite.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';

import 'package:idle_game/ui/theme/garage.dart';

import 'support/moments.dart';

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
  Widget app(GameState state, DateTime now) => ProviderScope(
        overrides: [
          initialStateProvider.overrideWithValue(state),
          timeProvider.overrideWithValue(() => now),
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

  Future<void> openOn(
    WidgetTester tester,
    GameState state,
    Size size, {
    DateTime? now,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(state, now ?? quietMoment));
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

    // Поздние аппараты широкие: три старших на правой полке не вставали в
    // неё даже по пикселю на клетку, и ряд уезжал за раму сцены. На 390
    // точках завод терял трубу, на 320 — половину корпуса вместе с биркой.
    // Снимки этого не ловили: на них семь банок, а не вся лестница.
    for (final screen in const [Size(320, 640), Size(390, 844)]) {
      testWidgets(
          'вся лестница на ${screen.width.toInt()}×${screen.height.toInt()} '
          'стоит внутри сцены', (tester) async {
        await openOn(
          tester,
          withStills({for (final g in kGeneratorNames) g.id: 1}),
          screen,
        );

        expect(tester.takeException(), isNull,
            reason: 'ряд аппаратов переполнился');

        final scene = rectOf(tester, find.byType(GarageScene));
        final stills = find.descendant(
          of: find.byType(GarageScene),
          matching: find.byType(PixelImage),
        );
        expect(stills, findsWidgets);
        for (final element in stills.evaluate()) {
          final box = element.renderObject! as RenderBox;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          expect(rect.left, greaterThanOrEqualTo(scene.left - 0.5),
              reason: 'аппарат уехал за левый край сцены: $rect');
          expect(rect.right, lessThanOrEqualTo(scene.right + 0.5),
              reason: 'аппарат уехал за правый край сцены: $rect');
        }
      });
    }
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

    testWidgets('гость помещается рядом с Петровичем на узком экране',
        (tester) async {
      // Карточек покупателей становится две, и происходит это само — игрок
      // ничего не нажимал. Значит, узкий экран обязан это пережить.
      await openOn(
        tester,
        withStills({'banka': 5}),
        const Size(320, 640),
        now: eventMoment,
      );

      expect(tester.takeException(), isNull,
          reason: 'при госте верхняя панель переполняется');
      expect(find.textContaining('ПЕТРОВИЧУ'), findsOneWidget);
      expect(find.byType(VityaPortrait), findsOneWidget);
    });

    testWidgets('название сорта получает место раньше полоски', (tester) async {
      // Название и полоска прогресса делили строку поровну, и «Двойной
      // перегон» резалось в «Двойной п…» даже на 390 точках.
      final longest = kSorts.indexed.reduce(
          (a, b) => a.$2.name.length >= b.$2.name.length ? a : b);
      final state = withStills({'banka': 5})
          .copyWith(sort: SortState(index: longest.$1, progress: 0.5));

      // Ahem рисует каждый знак квадратом в кегль — вдвое шире настоящего
      // шрифта. Поэтому экран — самый широкий, какой игра занимает: здесь
      // название влезает даже квадратами, и режет его только неравный делёж.
      await openOn(tester, state, const Size(460, 900));

      final name =
          tester.renderObject<RenderParagraph>(find.text(longest.$2.name));
      expect(name.didExceedMaxLines, isFalse,
          reason: 'название сорта обрезано, хотя место под него есть');
    });

    testWidgets('высота пульта не зависит от сорта', (tester) async {
      // У высшего сорта вместо полоски — подпись, и на 320 точках она
      // переносилась на вторую строку: пульт раздувался и толкал магазин.
      Future<double> panelAt(int sortIndex) async {
        await openOn(
          tester,
          withStills({'banka': 5})
              .copyWith(sort: SortState(index: sortIndex, progress: 0.5)),
          const Size(320, 640),
        );
        expect(tester.takeException(), isNull);
        return rectOf(tester, find.byType(HeatPanel)).height;
      }

      final low = await panelAt(0);
      for (var i = 1; i < kSorts.length; i++) {
        expect(await panelAt(i), low, reason: 'пульт с сортом №$i другой высоты');
      }
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
      //
      // Название сидит в FittedBox: на совсем узком экране оно ужимается, а
      // не режется. Место под него — это ширина коробки, а не самого текста.
      const needed = 160.0;
      final box = find.ancestor(of: label, matching: find.byType(FittedBox)).first;
      final available = tester.renderObject<RenderBox>(box).size.width;

      expect(available, greaterThanOrEqualTo(needed),
          reason: 'названию досталось $available точек при нужных $needed — '
              'на обычном телефоне оно будет ужиматься');
    });
  });
}
