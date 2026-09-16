/// Покупатели самогона.
///
/// Раньше была одна кнопка «продать» по абстрактному курсу, и решения в ней не
/// было. Теперь их трое, и каждый — это выбор, а не кнопка:
///
///   • Петрович берёт всё и всегда, но дёшево — и **не трогает сорт**
///   • Оптовик платит по рынку, но требует приличный сорт и объём
///   • Свадьба платит втрое, но берёт немного и только лучшее
///
/// Продажа хорошим покупателям **сбрасывает сорт на ступень**: репутация
/// уходит вместе с товаром, и её надо нарабатывать заново. Из-за этого
/// «подождать и довести до кедрача» становится осмысленной ставкой.
library;

class Buyer {
  final String id;
  final String name;

  /// Множитель к цене.
  final double multiplier;

  /// Минимальный сорт (индекс в kSorts), с которого покупатель берёт.
  final int minSortIndex;

  /// Минимальный объём в баке, мл.
  final double minMl;

  /// Максимум за одну сделку, мл. `null` — заберёт всё.
  final double? maxMl;

  /// Сбрасывает ли сорт на ступень после сделки.
  final bool consumesSort;

  /// Короткая подпись под суммой.
  final String note;

  /// Что показать, пока покупатель недоступен.
  final String lockedNote;

  const Buyer({
    required this.id,
    required this.name,
    required this.multiplier,
    required this.minSortIndex,
    required this.minMl,
    required this.maxMl,
    required this.consumesSort,
    required this.note,
    required this.lockedNote,
  });

  /// Сколько заберёт из бака прямо сейчас.
  double volumeFrom(double ml) {
    final cap = maxMl;
    if (cap == null) return ml;
    return ml < cap ? ml : cap;
  }
}

const List<Buyer> kBuyers = [
  Buyer(
    id: 'petrovich',
    name: 'Петрович',
    multiplier: 0.8,
    minSortIndex: 0,
    minMl: 0,
    maxMl: null,
    // Сосед не разбирается в сортах — потому и сорт не расходует.
    consumesSort: false,
    note: 'берёт всё, всегда',
    lockedNote: '',
  ),
  Buyer(
    id: 'optovik',
    name: 'Оптовик',
    multiplier: 1.0,
    minSortIndex: 2,
    minMl: 500,
    maxMl: null,
    consumesSort: true,
    note: 'весь бак',
    lockedNote: 'от «Двойного», 500 л',
  ),
  Buyer(
    id: 'svadba',
    name: 'Свадьба',
    multiplier: 2.2,
    minSortIndex: 3,
    minMl: 0,
    maxMl: 2000,
    consumesSort: true,
    note: 'до 2.00К л',
    lockedNote: 'от «На кедраче»',
  ),
];
