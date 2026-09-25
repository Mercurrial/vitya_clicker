/// Моменты времени с известным содержанием.
///
/// Расписание событий выводится из часов (см. `lib/content/events.dart`), а
/// значит от часов зависит и то, что нарисовано на экране: при госте карточек
/// покупателей две, без него одна. Тест, который берёт `DateTime.now()`, ловил
/// бы то одно, то другое — и снимок экрана падал бы в зависимости от того, в
/// какую минуту его запустили.
///
/// Флакающий тест хуже отсутствующего: его перестают читать. Поэтому моменты
/// подбираются здесь — один раз, поиском от фиксированной даты, а дальше
/// используются как константы.
library;

import 'package:idle_game/content/events.dart';
import 'package:idle_game/content/expenses.dart';

/// Откуда ищем. Дата произвольная, но зафиксированная навсегда.
final DateTime _from = DateTime.utc(2026, 5, 1);

/// В гараже тихо: покупатель один, Петрович, и цены обычные.
final DateTime quietMoment = _search(busy: false);

/// В гараже гость: покупателей двое, у второго идёт отсчёт.
final DateTime eventMoment = _search(busy: true);

/// Сахар подорожал, гостя нет: над списками покупок висит полоса.
final DateTime supplyMoment =
    _search(busy: false, expense: ExpenseKind.supplies);

/// Тёща у Петровича, гостя нет: его карточка показывает урезанную цену.
final DateTime neighborMoment =
    _search(busy: false, expense: ExpenseKind.neighbor);

/// Расход в моментах гостя и тишины должен отсутствовать: иначе на снимке
/// экрана появлялось бы то, ради чего момент не выбирали.
DateTime _search({required bool busy, ExpenseKind? expense}) {
  for (var m = 0; m < 3 * 24 * 60; m++) {
    final t = _from.add(Duration(minutes: m));
    if ((eventAt(t) != null) != busy) continue;
    if (expenseAt(t)?.expense.kind != expense) continue;
    return t;
  }
  throw StateError(
    'за трое суток от $_from не нашлось момента, когда гость '
    '${busy ? "есть" : "отсутствует"}, а расход — ${expense ?? "нет"}. '
    'Значит, расписание выродилось — смотри eventAt() и expenseAt()',
  );
}
