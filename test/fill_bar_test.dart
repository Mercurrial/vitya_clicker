import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/ui/theme/garage.dart';
import 'package:idle_game/ui/widgets/fill_bar.dart';

/// Полосы заполнения.
///
/// Тест существует из-за конкретной поломки: все пять полос в игре рисовали
/// заливку нулевой высоты, и выглядело это как «полоска всегда пустая».
/// Проверять цвет пикселей было бы хрупко, поэтому проверяем РАЗМЕР заливки —
/// именно он и обнулялся.
///
/// Разбор причины — в шапке `lib/ui/widgets/fill_bar.dart`.
void main() {
  /// Размер закрашенной части. Ищем по `DecoratedBox` внутри полосы: жёлоб
  /// рисуется `ColoredBox`, так что спутать их нельзя.
  Size fillSize(WidgetTester tester) {
    final fill = find.descendant(
      of: find.byType(FillBar),
      matching: find.byType(DecoratedBox),
    );
    expect(fill, findsOneWidget, reason: 'заливка не найдена вовсе');
    return tester.getSize(fill);
  }

  Future<void> pump(WidgetTester tester, double value) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            child: FillBar(value: value, height: 10, color: GColors.amber),
          ),
        ),
      ),
    );
  }

  group('Заливка занимает то место, которое ей положено', () {
    testWidgets('половина — это половина ширины и вся высота', (tester) async {
      await pump(tester, 0.5);
      expect(fillSize(tester), const Size(100, 10));
    });

    testWidgets('высота не зависит от заполненности', (tester) async {
      // Ровно то, что было сломано: заливка любой ширины, но нулевой высоты.
      for (final v in [0.01, 0.25, 0.75, 1.0]) {
        await pump(tester, v);
        expect(fillSize(tester).height, 10,
            reason: 'при заполненности $v заливка стала плоской');
      }
    });

    testWidgets('полная полоса закрашена целиком', (tester) async {
      await pump(tester, 1.0);
      expect(fillSize(tester), const Size(200, 10));
    });

    testWidgets('пустая полоса ничего не закрашивает', (tester) async {
      await pump(tester, 0);
      expect(fillSize(tester).width, 0);
    });
  });

  group('Полоса растёт слева направо', () {
    testWidgets('заливка прижата к левому краю, а не по центру', (tester) async {
      // FractionallySizedBox по умолчанию центрирует ребёнка. Полоса,
      // растущая из середины в обе стороны, — не полоса прогресса.
      await pump(tester, 0.5);

      final bar = tester.getRect(find.byType(FillBar));
      final fill = tester.getRect(
        find.descendant(
          of: find.byType(FillBar),
          matching: find.byType(DecoratedBox),
        ),
      );

      expect(fill.left, bar.left);
    });
  });

  group('Полоса не падает от плохих чисел', () {
    testWidgets('значения вне диапазона обрезаются', (tester) async {
      await pump(tester, 1.7);
      expect(fillSize(tester).width, 200);

      await pump(tester, -0.4);
      expect(fillSize(tester).width, 0);
    });

    testWidgets('NaN не роняет кадр', (tester) async {
      // Деление на ноль в «сколько осталось до следующей ступени» вполне
      // возможно, и падать из-за этого весь экран не должен.
      await pump(tester, double.nan);
      expect(fillSize(tester).width, 0);
      expect(tester.takeException(), isNull);
    });
  });
}
