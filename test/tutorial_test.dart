import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/tutorial.dart';

/// Обучение новичка.
///
/// Проверяем не тексты, а ПОВЕДЕНИЕ: что подсказка соответствует тому, что
/// игрок может сделать прямо сейчас, не ходит назад и сама исчезает у того,
/// кто уже разобрался.
void main() {
  TutorialFacts facts({
    bool touched = false,
    bool inWindow = false,
    double series = 0,
    double tank = 0,
    bool canBuy = false,
    int stills = 1,
  }) =>
      TutorialFacts(
        hasTouched: touched,
        wasInWindow: inWindow,
        series: series,
        tankFraction: tank,
        canAffordStill: canBuy,
        stillsOwned: stills,
      );

  group('Порядок обучения', () {
    test('новичку первым делом объясняют главное действие', () {
      expect(
        tutorialStepFor(facts(), TutorialStep.hold),
        TutorialStep.hold,
      );
    });

    test('коснулся — учим целиться в окно', () {
      expect(
        tutorialStepFor(facts(touched: true), TutorialStep.hold),
        TutorialStep.window,
      );
    });

    test('попал в окно — объясняем, что за это дают', () {
      expect(
        tutorialStepFor(facts(touched: true, inWindow: true), TutorialStep.window),
        TutorialStep.series,
      );
    });

    test('полный бак важнее серии: производство встало', () {
      expect(
        tutorialStepFor(
          facts(touched: true, inWindow: true, series: 0.5, tank: 0.95),
          TutorialStep.series,
        ),
        TutorialStep.sell,
      );
    });

    test('появились деньги — учим покупать', () {
      expect(
        tutorialStepFor(
          facts(touched: true, inWindow: true, canBuy: true),
          TutorialStep.sell,
        ),
        TutorialStep.buy,
      );
    });

    test('купил второй аппарат — обучение кончилось', () {
      expect(
        tutorialStepFor(
          facts(touched: true, inWindow: true, stills: 2),
          TutorialStep.buy,
        ),
        TutorialStep.done,
      );
    });
  });

  group('Обучение не мешает', () {
    test('подсказки не ходят назад', () {
      // Игрок продал бак, деньги кончились, серия слетела. Возвращать его к
      // «зажми палец» нельзя — это выглядит издевательством.
      final step = tutorialStepFor(facts(touched: true), TutorialStep.sell);
      expect(step.index, greaterThanOrEqualTo(TutorialStep.sell.index));
    });

    test('пройденное обучение больше не всплывает никогда', () {
      for (final f in [
        facts(),
        facts(touched: true),
        facts(tank: 1.0),
        facts(canBuy: true),
      ]) {
        expect(tutorialStepFor(f, TutorialStep.done), TutorialStep.done);
      }
    });

    test('тот, кто уже играл, обучения не видит', () {
      // Открыл сохранение: аппаратов много, деньги есть. Объяснять «зажми
      // палец» поздно и обидно.
      final step = tutorialStepFor(
        facts(touched: true, inWindow: true, stills: 40, canBuy: true),
        TutorialStep.hold,
      );
      expect(step, TutorialStep.done);
    });

    test('у каждого шага есть текст, и он про действие', () {
      for (final step in TutorialStep.values) {
        if (step.isDone) {
          expect(step.text, isEmpty);
          continue;
        }
        expect(step.text, isNotEmpty);
        expect(step.text.length, lessThan(70),
            reason: 'подсказку длиннее строки не читают: «${step.text}»');
        expect(step.text.contains('!'), isFalse,
            reason: 'обучение не кричит: «${step.text}»');
      }
    });
  });
}
