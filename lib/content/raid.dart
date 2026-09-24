/// ШУХЕР: участковый Николай Петрович на обходе.
///
/// ## Зачем эта механика вообще
///
/// Вся остальная игра — про накопление. Копится самогон, копится сорт, копится
/// мудрость; неудача выглядит как «накопилось меньше». Напряжения в этом нет
/// ни на копейку, и через полчаса игра превращается в наблюдение за числами.
///
/// ШУХЕР — единственное место, где можно **потерять**. И устроен он нарочно
/// наизнанку по отношению ко всему остальному: всю игру палец держат, а здесь
/// его надо отпустить. Один и тот же жест меняет знак — из-за этого механика
/// не требует ни новой кнопки, ни объяснений длиннее строки.
///
/// ## Почему наказание именно такое
///
/// Попался — участковый забирает часть бака и роняет сорт на ступень. Не всё:
/// потерять час работы из-за того, что не заметил плашку, — это повод удалить
/// игру, а не повод собраться. Потерянное восстанавливается за несколько минут,
/// а неприятно ровно настолько, чтобы в следующий раз отпустить вовремя.
///
/// Того, кто не играет, ШУХЕР не трогает вовсе: попасться можно только держа
/// палец. Оффлайн-игрок не рискует ничем, и это правильно — наказывать за то,
/// что человек живёт своей жизнью, игра не должна.
///
/// ## Почему расписание из часов
///
/// По той же причине, что и у событий (см. `events.dart`): чистая функция
/// времени ничего не хранит в сейве, переживает оффлайн и проверяется тестом.
library;

import 'events.dart' show scheduleHash;

/// Что происходит за воротами.
enum RaidPhase {
  /// Машина подъехала. Есть несколько секунд, чтобы затихнуть.
  warning,

  /// Участковый у ворот. Держишь жар — попался.
  search,
}

class RaidState {
  final RaidPhase phase;

  /// Сколько осталось до конца текущей фазы.
  final Duration remaining;

  /// Какой это по счёту обход. Нужен интерфейсу, чтобы понимать, что обход
  /// СМЕНИЛСЯ: без этого попавшийся один раз считался бы попавшимся вечно.
  final int id;

  const RaidState({
    required this.phase,
    required this.remaining,
    required this.id,
  });

  bool get isWarning => phase == RaidPhase.warning;
  bool get isSearch => phase == RaidPhase.search;

  /// Строка для плашки.
  String get title =>
      isWarning ? 'ШУХЕР · участковый во дворе' : 'ШУХЕР · он у ворот';

  String get advice =>
      isWarning ? 'Туши. Осталось ${remaining.inSeconds} с' : 'Не дыши';
}

/// Сколько даётся на то, чтобы затихнуть.
const Duration kRaidWarning = Duration(seconds: 7);

/// Сколько участковый стоит у ворот.
const Duration kRaidSearch = Duration(seconds: 13);

/// Доля бака, которую он забирает, живёт в балансе (`raidSeizure`): это число
/// экономики, и его правка обязана проходить через версию и объяснение.

/// Шаг расписания.
const Duration _slot = Duration(minutes: 50);

/// В какой доле отрезков случается обход.
const int _chancePercent = 60;

/// Что происходит за воротами в момент [now]. `null` — тихо.
RaidState? raidAt(DateTime now) {
  final ms = now.toUtc().millisecondsSinceEpoch;
  final slotMs = _slot.inMilliseconds;
  final totalMs = kRaidWarning.inMilliseconds + kRaidSearch.inMilliseconds;

  final slot = ms ~/ slotMs;
  // Смещение зерна, чтобы обходы не ходили парой с покупателями: иначе гость
  // и участковый приходили бы в одну минуту, и это читалось бы как заговор.
  final h = scheduleHash(slot * 2 + 1);

  if (h % 100 >= _chancePercent) return null;

  final start = (h >> 9) % (slotMs - totalMs);
  final offset = ms - slot * slotMs;
  if (offset < start || offset >= start + totalMs) return null;

  final into = offset - start;
  if (into < kRaidWarning.inMilliseconds) {
    return RaidState(
      phase: RaidPhase.warning,
      remaining: Duration(milliseconds: kRaidWarning.inMilliseconds - into),
      id: slot,
    );
  }
  return RaidState(
    phase: RaidPhase.search,
    remaining: Duration(milliseconds: totalMs - into),
    id: slot,
  );
}
