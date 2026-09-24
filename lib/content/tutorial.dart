/// Обучение новичка.
///
/// ## Почему не экран с правилами
///
/// Три экрана текста перед игрой закрывают не глядя. Прочитанное до первого
/// касания не запоминается: игроку нечего связать со словами, он ещё не
/// нажимал ни разу.
///
/// Поэтому обучение здесь **вплетено в игру**. Одна короткая строка за раз,
/// привязанная к тому, что игрок может сделать прямо сейчас. Сделал — строка
/// исчезает сама, появляется следующая. Читать нечего, надо просто делать.
///
/// ## Почему шаг ВЫЧИСЛЯЕТСЯ, а не хранится
///
/// Шаг выводится из состояния игры: если у игрока уже есть деньги на второй
/// аппарат, объяснять «зажми палец» поздно. Хранится только водяной знак —
/// самый дальний пройденный шаг, чтобы подсказки не ходили назад, когда игрок
/// продал бак и деньги кончились.
///
/// Благодаря этому обучение само собой пропускается у того, кто уже играл: он
/// открывает сохранение и никаких подсказок не видит.
library;

/// Чему учим. Порядок — это и есть порядок обучения.
enum TutorialStep {
  /// Главное действие игры. Без него не работает ничего.
  hold,

  /// Зачем держать: попасть в окно.
  window,

  /// Что за это дают.
  series,

  /// Бак полон — производство встало.
  sell,

  /// На что тратить деньги.
  buy,

  /// Больше подсказок нет.
  done;

  /// Что показать. Одна строка, глагол в начале: подсказка про действие.
  String get text => switch (this) {
        TutorialStep.hold => 'Зажми палец на гараже — Витя подкинет дров',
        TutorialStep.window => 'Держи стрелку жара в зелёном окне',
        TutorialStep.series => 'В окне растёт СЕРИЯ — она множит весь доход',
        TutorialStep.sell => 'Бак полон — продай Петровичу, кнопка наверху',
        TutorialStep.buy => 'Есть деньги — купи ещё аппарат внизу',
        TutorialStep.done => '',
      };

  bool get isDone => this == TutorialStep.done;
}

/// Что игра знает о положении дел, когда решает, чему учить.
///
/// Отдельный тип, а не `GameState`: обучению нужны и вещи из интерфейса
/// (попал ли жар в окно), которых в состоянии игры нет и быть не должно.
class TutorialFacts {
  final bool hasTouched;
  final bool wasInWindow;
  final double series;
  final double tankFraction;
  final bool canAffordStill;
  final int stillsOwned;

  const TutorialFacts({
    required this.hasTouched,
    required this.wasInWindow,
    required this.series,
    required this.tankFraction,
    required this.canAffordStill,
    required this.stillsOwned,
  });
}

/// Чему учить прямо сейчас.
///
/// [furthest] — самый дальний шаг, который игрок уже прошёл. Возвращаться
/// назад обучение не должно: подсказка «продай» не имеет права снова стать
/// «зажми палец» только потому, что бак опустел.
TutorialStep tutorialStepFor(TutorialFacts facts, TutorialStep furthest) {
  if (furthest.isDone) return TutorialStep.done;

  // Порядок проверок — от позднего к раннему. Так тот, кто уже далеко ушёл,
  // не получает подсказок из начала: они бы выглядели издевательством.
  TutorialStep natural() {
    if (facts.stillsOwned >= 2) return TutorialStep.done;
    if (facts.canAffordStill) return TutorialStep.buy;
    if (facts.tankFraction >= 0.9) return TutorialStep.sell;
    if (facts.series >= 0.15) return TutorialStep.sell;
    if (facts.wasInWindow) return TutorialStep.series;
    if (facts.hasTouched) return TutorialStep.window;
    return TutorialStep.hold;
  }

  final step = natural();
  return step.index >= furthest.index ? step : furthest;
}
