import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/ui/pixel/garage_room.dart';

void main() {
  group('Стадия помещения', () {
    test('банка и змеевик — это всё ещё гараж', () {
      expect(stageForTier(0), GarageStage.garage);
      expect(stageForTier(4), GarageStage.garage);
    });

    test('с гаражного цеха начинается цех', () {
      expect(stageForTier(5), GarageStage.shop);
      expect(stageForTier(8), GarageStage.shop);
    });

    test('с завода помещение перестаёт быть гаражом', () {
      expect(stageForTier(9), GarageStage.plant);
      expect(stageForTier(12), GarageStage.plant);
    });

    test('каждый аппарат попадает в какую-то стадию', () {
      // Если в контент добавят аппарат, а стадии забудут — тест упадёт здесь,
      // а не в виде голой кирпичной стены вокруг коллайдера.
      for (var i = 0; i < kGenerators.length; i++) {
        expect(() => stageForTier(i), returnsNormally);
      }
      expect(stageForTier(kGenerators.length - 1), GarageStage.plant,
          reason: 'последний аппарат обязан стоять на производстве');
    });

    test('у каждой стадии есть название', () {
      for (final stage in GarageStage.values) {
        expect(stageName(stage), isNotEmpty);
      }
      expect(
        GarageStage.values.map(stageName).toSet().length,
        GarageStage.values.length,
        reason: 'названия не должны повторяться',
      );
    });
  });

  group('Лампа', () {
    test('качается сильнее, когда жарко', () {
      double amplitude(double heat) {
        var peak = 0.0;
        for (var t = 0.0; t < 40; t += 0.05) {
          peak = peak > SwingingLamp.swing(t, heat).abs()
              ? peak
              : SwingingLamp.swing(t, heat).abs();
        }
        return peak;
      }

      expect(amplitude(1.0), greaterThan(amplitude(0.0)));
    });

    test('не улетает за пределы сцены даже при перегреве', () {
      for (var t = 0.0; t < 200; t += 0.1) {
        expect(SwingingLamp.swing(t, 5.0).abs(), lessThan(20),
            reason: 'жар выше единицы не должен раскачивать лампу до потолка');
      }
    });
  });

  group('Отрисовка', () {
    testWidgets('комната рисуется на всех стадиях и не падает на нулевом размере',
        (tester) async {
      for (final stage in GarageStage.values) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 320,
                height: 240,
                child: Stack(
                  children: [
                    Positioned.fill(child: RoomBackground(stage: stage)),
                    const Positioned.fill(
                      child: SwingingLamp(time: 3.7, heat: 0.8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }

      // Сцена успевает появиться в дереве с нулевым размером — деление на
      // высоту там обязано не родить NaN.
      await tester.pumpWidget(
        const Center(
          child: SizedBox(
            width: 0,
            height: 0,
            child: SwingingLamp(time: 1, heat: 1),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
