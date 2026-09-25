/// События с расходом: у Вити что-то пошло не так.
///
/// ## Зачем
///
/// Гости из `events.dart` приносят деньги, участковый из `raid.dart` — страх.
/// Не хватало третьего: обычной житейской неприятности, которая ничего не
/// отбирает, но заставляет подумать. Сахар подорожал — покупать сейчас или
/// переждать? Тёща у Петровича — сдать ему бак дешевле или придержать?
///
/// ## Почему расход бьёт только по решениям
///
/// Событие меняет цену покупки или продажи — и больше ничего. Производство оно
/// не трогает. Отсюда два следствия, и оба нарочные:
///
/// * **Тот, кто не играет, не теряет ничего.** Оффлайн никто не покупает и не
///   продаёт, значит, и переплачивать некому. Наказывать за то, что человек
///   живёт своей жизнью, игра не должна — то же правило, что у ШУХЕРА.
/// * **Выход есть всегда.** Любой расход можно переждать: окно короткое, а
///   после него цены прежние. Событие ставит вопрос «сейчас или потом», а не
///   выставляет счёт.
///
/// ## Почему расписание из часов
///
/// По той же причине, что и у гостей (см. шапку `events.dart`): чистая функция
/// времени ничего не хранит в сейве, переживает оффлайн и проверяется тестом.
library;

import 'events.dart' show scheduleHash;

/// По чему бьёт расход.
enum ExpenseKind {
  /// Дорожают аппараты и улучшения.
  supplies,

  /// Постоянный покупатель платит меньше. Гостей это не касается — к ним и
  /// стоит присмотреться.
  neighbor,
}

/// Что стряслось.
class GarageExpense {
  final String id;

  /// Заголовок плашки: «Сахар подорожал».
  final String title;

  /// Строка под заголовком — что именно подорожало и насколько.
  final String note;

  final ExpenseKind kind;

  /// Множитель к цене. Для [ExpenseKind.supplies] больше единицы — платишь
  /// больше; для [ExpenseKind.neighbor] меньше — получаешь меньше.
  final double factor;

  const GarageExpense({
    required this.id,
    required this.title,
    required this.note,
    required this.kind,
    required this.factor,
  });
}

/// Что может стрястись.
///
/// Множители умеренные нарочно: переждать должно быть разумно, но не
/// обязательно. Если купить со скидкой в треть проще, чем подождать десять
/// минут, игрок будет покупать и молча злиться; если переплата вдвое — будет
/// только ждать, и выбора опять не станет.
const List<GarageExpense> kGarageExpenses = [
  GarageExpense(
    id: 'sahar',
    title: 'Сахар подорожал',
    note: 'аппараты и улучшения ×1.3',
    kind: ExpenseKind.supplies,
    factor: 1.3,
  ),
  GarageExpense(
    id: 'tyoscha',
    title: 'Тёща у Петровича',
    note: 'берёт с оглядкой, ×0.7',
    kind: ExpenseKind.neighbor,
    factor: 0.7,
  ),
];

/// Идущий прямо сейчас расход.
class ActiveExpense {
  final GarageExpense expense;

  /// Сколько осталось.
  final Duration remaining;

  const ActiveExpense({required this.expense, required this.remaining});
}

/// Сколько длится неприятность.
///
/// Двенадцать минут — столько, чтобы переждать было реально, и при этом
/// заметно: бак за это время успевает налиться.
const Duration kExpenseWindow = Duration(minutes: 12);

/// Шаг расписания.
const Duration _slot = Duration(minutes: 55);

/// В какой доле отрезков что-то случается.
const int _chancePercent = 50;

/// Что стряслось в момент [now]. `null` — всё как обычно.
ActiveExpense? expenseAt(DateTime now) {
  final ms = now.toUtc().millisecondsSinceEpoch;
  final slotMs = _slot.inMilliseconds;
  final windowMs = kExpenseWindow.inMilliseconds;

  final slot = ms ~/ slotMs;
  // Своё зерно, отличное и от гостей (slot), и от участкового (slot*2+1):
  // иначе неприятности ходили бы парой с кем-то из них.
  final h = scheduleHash(slot * 3 + 2);

  if (h % 100 >= _chancePercent) return null;

  final start = (h >> 8) % (slotMs - windowMs);
  final offset = ms - slot * slotMs;
  if (offset < start || offset >= start + windowMs) return null;

  return ActiveExpense(
    expense: kGarageExpenses[(h >> 4) % kGarageExpenses.length],
    remaining: Duration(milliseconds: start + windowMs - offset),
  );
}

/// Во сколько раз дороже покупки в момент [now].
double supplyFactorAt(DateTime now) {
  final e = expenseAt(now)?.expense;
  return e != null && e.kind == ExpenseKind.supplies ? e.factor : 1.0;
}

/// Во сколько раз меньше платит постоянный покупатель в момент [now].
double neighborFactorAt(DateTime now) {
  final e = expenseAt(now)?.expense;
  return e != null && e.kind == ExpenseKind.neighbor ? e.factor : 1.0;
}
