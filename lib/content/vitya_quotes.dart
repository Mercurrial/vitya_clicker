/// Реплики Вити.
///
/// По правилу частоты: **на тапе шуток нет** — его видят тысячи раз, и любая
/// умрёт к третьей минуте. Витя говорит только в редких местах: когда поднялся
/// сорт, когда спалил партию, когда сдал товар, когда проснулся с похмелья.
///
/// Тон сухой и уверенный. Витя — мастер, а не посмешище: смеёмся вместе с ним,
/// никогда над ним.
library;

import 'dart:math' as math;

enum VityaEvent { gradeUp, overheat, sold, hangover, newStill }

const Map<VityaEvent, List<String>> kVityaLines = {
  VityaEvent.gradeUp: [
    'Вот теперь пахнет как надо.',
    'Дед бы одобрил.',
    'Чувствуешь? Это уже не бражка.',
    'Пошёл ровный.',
    'За такое и денег не жалко.',
  ],
  VityaEvent.overheat: [
    'Ой, всё.',
    'Перегнал. Бывает.',
    'Это уже не самогон, это опыт.',
    'Кто ж так гонит-то.',
    'Ладно, переделаем.',
  ],
  VityaEvent.sold: [
    'Приятно иметь дело.',
    'Деньги — в дело.',
    'Не обманул, и на том спасибо.',
    'Пересчитал. Сходится.',
  ],
  VityaEvent.hangover: [
    'Приснится же такое.',
    'Голова — как чугун. Но идея была хорошая.',
    'Цех, значит. Ну-ну.',
    'Банка на месте. Остальное, выходит, показалось.',
    'Начинаем заново. Только умнее.',
  ],
  VityaEvent.newStill: [
    'Теперь заживём.',
    'Это уже серьёзно.',
    'Соседи точно заметят.',
    'Места в гараже всё меньше.',
  ],
};

/// Выдаёт реплики без повторов подряд — одна и та же фраза дважды кряду
/// убивает эффект надёжнее, чем плохая шутка.
class VityaVoice {
  final math.Random _rng;
  final Map<VityaEvent, String> _last = {};

  VityaVoice({math.Random? random}) : _rng = random ?? math.Random();

  String line(VityaEvent event) {
    final pool = kVityaLines[event];
    if (pool == null || pool.isEmpty) return '';
    if (pool.length == 1) return pool.first;

    final previous = _last[event];
    String pick;
    var guard = 0;
    do {
      pick = pool[_rng.nextInt(pool.length)];
      guard++;
    } while (pick == previous && guard < 8);

    _last[event] = pick;
    return pick;
  }
}
