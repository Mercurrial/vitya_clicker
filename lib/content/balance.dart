/// Числа экономики — в одном месте и с версией.
///
/// ## Зачем отдельный файл и зачем версия
///
/// Баланс будет меняться после релиза. Это не «если», а «когда»: ни одна
/// экономика не выходит правильной с первого раза, и наша не вышла. Значит,
/// вопрос не «как не менять баланс», а **«как поменять его, не обидев того,
/// кто уже играет»**.
///
/// Ответ состоит из двух частей, и вторая важнее первой.
///
/// **Первая.** Все настраиваемые числа собраны здесь и нигде не продублированы.
/// Правка баланса — это правка одного файла, а не поиск констант по проекту.
///
/// **Вторая, главная.** В сейве не хранится ничего производного от этих чисел.
/// Сейв хранит только ФАКТЫ: сколько чего куплено, что открыто, сколько всего
/// нагнано за историю. Всё остальное — доход, цены, мудрость — вычисляется из
/// фактов по текущему балансу при каждой загрузке. Поэтому смена баланса
/// применяется к старому сейву сама собой, без миграции и без пересчёта.
///
/// Разница видна на мудрости. Сначала она лежала в сейве числом. Формула
/// изменилась — и число осталось от старой формулы: пришлось писать миграцию
/// v3→v4, которая пересчитывала его один раз и навсегда замораживала ошибку.
/// Теперь в сейве лежит `claimedMl` — сколько нагнано на момент последнего
/// похмелья, — а мудрость из него ВЫЧИСЛЯЕТСЯ. Поменяем формулу ещё раз —
/// пересчитается у всех и сразу, включая уже накопленное.
///
/// ## Что всё-таки требует внимания
///
/// Автоматически переносится всё, кроме одного случая: **ослабления**. Если
/// новый баланс делает аппараты слабее, игрок в момент обновления обнаружит,
/// что его доход упал. Это единственная ситуация, ради которой существует
/// [kBalanceLog]: каждый выпуск объявляет, что изменилось, и если изменение
/// болезненное — какую компенсацию за него дают. Игрок видит это списком при
/// первом запуске новой версии, а не догадывается сам.
library;

/// Версия баланса. Поднимать при ЛЮБОМ изменении чисел ниже, даже безобидном:
/// по ней игра понимает, что игроку надо показать список изменений.
///
/// Это не версия сейва (`kSaveVersion`) — та про формат данных. Формат может
/// не меняться годами, а баланс править каждую неделю.
const int kBalanceVersion = 4;

/// Настраиваемые числа.
///
/// Живёт статическим полем [current], а не параметром в двадцати конструкторах.
/// Баланс действительно глобален и в игре меняется ровно один раз — никогда;
/// подменять его нужно только симулятору, чтобы прогнать варианты. Плата за
/// удобство — дисциплина: менять [current] позволено только через [withBalance].
class Balance {
  /// Во сколько раз дорожает каждая следующая штука аппарата.
  ///
  /// Главный тормоз экономики. При 1.10 покупка окупалась за считанные
  /// секунды, и за две с половиной минуты производство улетало с нуля до
  /// двадцати литров в секунду. Классическое значение жанра — 1.15.
  final double costGrowth;

  /// Сколько нагнать до первой мудрости, мл.
  ///
  /// Прямо задаёт длину первого захода: это единственное число, которым время
  /// до первого похмелья настраивается в лоб.
  final double firstWisdomMl;

  /// Прибавка к производству за каждую единицу мудрости.
  final double bonusPerWisdom;

  /// Базовая цена за миллилитр, ₽.
  final double basePricePerMl;

  /// Плоская отдача за нажатие, пока аппаратов нет, мл.
  final double baseTapMl;

  /// Доля секунды производства, которую стоит одно нажатие потом.
  final double tapSeconds;

  /// Минимальная ёмкость бака, мл.
  final double baseTankMl;

  /// Сколько секунд производства держит бак без улучшений.
  final double baseBufferSeconds;

  /// Потолок ёмкости в секундах производства.
  ///
  /// Без потолка улучшения бака перемножались (×2·×3·×4·×5 = ×120) и доводили
  /// запас до четырёх часов. Звучит щедро, а на деле ломает игру: бак
  /// перестаёт наполняться за сеанс, продажа перестаёт быть решением, и вместе
  /// с ней обесцениваются и рынок, и сорт — вся средняя часть игры.
  final double maxBufferSeconds;

  /// Количества, на которых доход аппарата удваивается.
  final List<int> milestones;

  /// Цена первого аппарата, ₽.
  final double firstGeneratorCost;

  /// Во сколько раз дороже каждый следующий аппарат лестницы.
  final double tierCostRatio;

  /// Выход первого аппарата, мл/с.
  final double firstGeneratorOutput;

  /// Во сколько раз больше гонит каждый следующий аппарат лестницы.
  ///
  /// Вместе с [tierCostRatio] это главный регулятор длины игры: отношение
  /// «дороже / продуктивнее» задаёт, насколько каждая следующая ступень
  /// невыгоднее предыдущей, а значит — сколько её придётся зарабатывать.
  final double tierOutputRatio;

  const Balance({
    required this.costGrowth,
    required this.firstWisdomMl,
    required this.bonusPerWisdom,
    required this.basePricePerMl,
    required this.baseTapMl,
    required this.tapSeconds,
    required this.baseTankMl,
    required this.baseBufferSeconds,
    required this.maxBufferSeconds,
    required this.milestones,
    required this.firstGeneratorCost,
    required this.tierCostRatio,
    required this.firstGeneratorOutput,
    required this.tierOutputRatio,
  });

  /// Действующий баланс.
  static Balance current = kBalance;

  Balance copyWith({
    double? costGrowth,
    double? firstWisdomMl,
    double? bonusPerWisdom,
    double? basePricePerMl,
    double? baseTapMl,
    double? tapSeconds,
    double? baseTankMl,
    double? baseBufferSeconds,
    double? maxBufferSeconds,
    List<int>? milestones,
    double? firstGeneratorCost,
    double? tierCostRatio,
    double? firstGeneratorOutput,
    double? tierOutputRatio,
  }) =>
      Balance(
        costGrowth: costGrowth ?? this.costGrowth,
        firstWisdomMl: firstWisdomMl ?? this.firstWisdomMl,
        bonusPerWisdom: bonusPerWisdom ?? this.bonusPerWisdom,
        basePricePerMl: basePricePerMl ?? this.basePricePerMl,
        baseTapMl: baseTapMl ?? this.baseTapMl,
        tapSeconds: tapSeconds ?? this.tapSeconds,
        baseTankMl: baseTankMl ?? this.baseTankMl,
        baseBufferSeconds: baseBufferSeconds ?? this.baseBufferSeconds,
        maxBufferSeconds: maxBufferSeconds ?? this.maxBufferSeconds,
        milestones: milestones ?? this.milestones,
        firstGeneratorCost: firstGeneratorCost ?? this.firstGeneratorCost,
        tierCostRatio: tierCostRatio ?? this.tierCostRatio,
        firstGeneratorOutput: firstGeneratorOutput ?? this.firstGeneratorOutput,
        tierOutputRatio: tierOutputRatio ?? this.tierOutputRatio,
      );
}

/// Действующие числа.
///
/// Найдены перебором (`dart run tools/balance_sweep.dart`), а не подобраны на
/// глаз. Проверяются тестом `test/balance_test.dart` — если правка выведет
/// игру за цели из [BalanceTargets], тест упадёт.
const Balance kBalance = Balance(
  costGrowth: 1.26,
  firstWisdomMl: 2.5e8,
  bonusPerWisdom: 0.08,
  basePricePerMl: 0.1,
  baseTapMl: 5.0,
  tapSeconds: 0.25,
  baseTankMl: 2000,
  baseBufferSeconds: 120,
  maxBufferSeconds: 1800,
  milestones: [10, 25, 50, 100],
  firstGeneratorCost: 15,
  tierCostRatio: 30.0,
  firstGeneratorOutput: 1,
  tierOutputRatio: 6.05,
);

/// Прогнать код на другом балансе и вернуть всё как было.
///
/// Только для симулятора и тестов. В игре баланс не меняется на ходу.
T withBalance<T>(Balance balance, T Function() body) {
  final saved = Balance.current;
  Balance.current = balance;
  try {
    return body();
  } finally {
    Balance.current = saved;
  }
}

/// Что поменялось в выпуске баланса.
class BalanceRelease {
  /// Версия, которую этот выпуск вводит.
  final int version;

  /// Заголовок для игрока.
  final String title;

  /// Пункты списка — человеческим языком, без формул.
  final List<String> changes;

  /// Стало ли кому-то хуже. Если да — игра извинится и объяснит, за что.
  final bool isNerf;

  /// Сколько мудрости начислить в качестве извинения.
  final int compensationWisdom;

  const BalanceRelease({
    required this.version,
    required this.title,
    required this.changes,
    this.isNerf = false,
    this.compensationWisdom = 0,
  });
}

/// История изменений баланса. Показывается игроку при первом запуске после
/// обновления — все выпуски новее того, на котором он играл.
///
/// Записи не переписываются задним числом: игрок мог увидеть старую формулировку.
const List<BalanceRelease> kBalanceLog = [
  BalanceRelease(
    version: 2,
    title: 'Гараж перебрали',
    isNerf: true,
    // Первому заходу возвращаем примерно то, что он успел накопить до правки.
    compensationWisdom: 3,
    changes: [
      'Аппараты дорожают быстрее. Раньше десятый по счёту стоил как второй, '
          'и через пять минут покупать было уже нечего.',
      'До первой мудрости теперь дальше. Раньше похмелье наступало на третьей '
          'минуте и обесценивало всё, что было до него.',
      'У бака появился потолок — полчаса производства. Раньше улучшения '
          'перемножались до четырёх часов, бак переставал наполняться, '
          'и продавать было незачем.',
      'За перетряску — три мудрости сверху. Извини.',
    ],
  ),
  BalanceRelease(
    version: 3,
    title: 'Нажимать стало не нужно',
    isNerf: true,
    compensationWisdom: 2,
    changes: [
      'Касание больше не даёт самогон. Раньше выигрывал тот, кто быстрее '
          'долбит по экрану, и ждать хороший сорт было проигрышно.',
      'Теперь палец держат, а не долбят: пока держишь жар в окне, копится '
          'СЕРИЯ — она множит всё производство втрое.',
      'Серия не срывается, когда отвлёкся: угли держат жар ещё три секунды, '
          'а сама серия тает медленно. Обнуляет её только перегрев.',
      'Покупатель остался один. Трое выглядели выбором, но выбора не было — '
          'решение принимается раньше, когда ждёшь сорт.',
      'Витя начинает с банкой: гнать он начал до нашего прихода.',
      'За перетряску — две мудрости сверху.',
    ],
  ),
  BalanceRelease(
    version: 4,
    title: 'Похмелье наконец работает',
    isNerf: true,
    // Мудрость и так пересчитается по новой формуле и вырастет сильнее, чем на
    // эти две единицы. Сначала я хотел на этом основании компенсацию не
    // начислять — и тест не дал: правило «ослабил цены → дай что-то сверху»
    // написано ровно против таких рассуждений. Аппараты действительно
    // подорожали, и объяснение этого не отменяет.
    compensationWisdom: 2,
    changes: [
      'Похмелье больше не запирает игру. Витя просыпался в пустом гараже без '
          'единого аппарата, а касание самогона не даёт — заработать на первую '
          'банку было нечем. Теперь банка остаётся: весь цех Вите причудился, '
          'а с чего он начинал, то при нём и осталось.',
      'До первой мудрости в десять раз ближе. Похмелье было задумано как '
          'обычный ход игры, а получалось раз в вечер.',
      'Аппараты подорожали: каждый следующий вдвое дороже прежнего. Лестница '
          'считалась на игре, которая обрывалась на первом похмелье, — поэтому '
          'числа и разъехались.',
      'Мудрость за уже нагнанное пересчитается сама и станет заметно больше — '
          'а сверху ещё две за беспокойство.',
    ],
  ),
];

/// Выпуски, которые игрок ещё не видел.
List<BalanceRelease> releasesSince(int seenVersion) =>
    [for (final r in kBalanceLog) if (r.version > seenVersion) r];

/// Сколько мудрости причитается за переход с [seenVersion] на текущую версию.
int compensationSince(int seenVersion) => releasesSince(seenVersion)
    .fold(0, (sum, r) => sum + r.compensationWisdom);
