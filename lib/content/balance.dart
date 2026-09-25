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
///
/// До выпуска 1.0.0 — всегда 1. Пока в `test/fixtures/` нет ни одного
/// эталона, игроков нет, объяснять правку некому, и версия не поднимается;
/// первый эталон снимает выпуск, и с ним правило включается само — это
/// стережёт `test/release_contract_test.dart`. Тестовые сборки дошли до v7,
/// но их сейвы выпуск не читает (docs/DECISIONS.md, «Чистый старт»).
const int kBalanceVersion = 1;

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
  /// Не подбирается, а снимается с кривой: столько «считает» нагоняет к 2,5 ч
  /// игры (docs/DECISIONS.md, «Экономика и мудрость»). Подбирать его как
  /// ручку бесполезно: к этому моменту производство растёт экспоненциально,
  /// и порог ×4 сдвигал похмелье всего на 10 минут. Длину захода задаёт
  /// кривая — лестница и улучшения, — а порог только ставит отметку на ней.
  final double firstWisdomMl;

  /// Прибавка к производству за первую мудрость: +100 %, то есть ×2.
  ///
  /// Отдельно от [bonusPerWisdom], потому что первая мудрость — рывок. При
  /// ровных +8 % за каждую второй заход был всего на 20 % короче первого, и
  /// похмелье не ощущалось наградой.
  final double firstWisdomBonus;

  /// Прибавка за каждую мудрость после первой.
  final double bonusPerWisdom;

  /// Базовая цена за миллилитр, ₽.
  final double basePricePerMl;

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

  /// Цены улучшений «×2 этой ступени» — в базовых ценах самой ступени.
  ///
  /// Улучшения строятся по формуле вдоль всей лестницы, как сами аппараты.
  /// Раньше их было 22 штуки руками, и они обрывались на 60 млн ₽: дальше
  /// рост шёл только поштучной покупкой, которая дорожает геометрически, и
  /// заход после первого часа вставал. Множители должны идти до конца
  /// лестницы — тогда окупаемость не уезжает в часы.
  final List<double> tierUpgradeCosts;

  /// Во сколько раз улучшение ступени поднимает её выход.
  final double tierUpgradeMultiplier;

  /// Цена улучшения «все аппараты» на каждой ступени — в её базовых ценах.
  final double globalUpgradeCost;

  /// Во сколько раз «все аппараты» поднимает выход всей лестницы.
  final double globalUpgradeMultiplier;

  /// Цена улучшения качества на каждой ступени — в её базовых ценах.
  final double qualityUpgradeCost;

  /// Во сколько раз качество поднимает цену за литр.
  final double qualityUpgradeMultiplier;

  /// Во сколько раз больше гонит каждый следующий аппарат лестницы.
  ///
  /// Вместе с [tierCostRatio] это главный регулятор длины игры: отношение
  /// «дороже / продуктивнее» задаёт, насколько каждая следующая ступень
  /// невыгоднее предыдущей, а значит — сколько её придётся зарабатывать.
  final double tierOutputRatio;

  const Balance({
    required this.costGrowth,
    required this.firstWisdomMl,
    required this.firstWisdomBonus,
    required this.bonusPerWisdom,
    required this.basePricePerMl,
    required this.baseTankMl,
    required this.baseBufferSeconds,
    required this.maxBufferSeconds,
    required this.milestones,
    required this.firstGeneratorCost,
    required this.tierCostRatio,
    required this.firstGeneratorOutput,
    required this.tierOutputRatio,
    required this.tierUpgradeCosts,
    required this.tierUpgradeMultiplier,
    required this.globalUpgradeCost,
    required this.globalUpgradeMultiplier,
    required this.qualityUpgradeCost,
    required this.qualityUpgradeMultiplier,
  });

  /// Действующий баланс.
  static Balance current = kBalance;

  Balance copyWith({
    double? costGrowth,
    double? firstWisdomMl,
    double? firstWisdomBonus,
    double? bonusPerWisdom,
    double? basePricePerMl,
    double? baseTankMl,
    double? baseBufferSeconds,
    double? maxBufferSeconds,
    List<int>? milestones,
    double? firstGeneratorCost,
    double? tierCostRatio,
    double? firstGeneratorOutput,
    double? tierOutputRatio,
    List<double>? tierUpgradeCosts,
    double? tierUpgradeMultiplier,
    double? globalUpgradeCost,
    double? globalUpgradeMultiplier,
    double? qualityUpgradeCost,
    double? qualityUpgradeMultiplier,
  }) =>
      Balance(
        costGrowth: costGrowth ?? this.costGrowth,
        firstWisdomMl: firstWisdomMl ?? this.firstWisdomMl,
        firstWisdomBonus: firstWisdomBonus ?? this.firstWisdomBonus,
        bonusPerWisdom: bonusPerWisdom ?? this.bonusPerWisdom,
        basePricePerMl: basePricePerMl ?? this.basePricePerMl,
        baseTankMl: baseTankMl ?? this.baseTankMl,
        baseBufferSeconds: baseBufferSeconds ?? this.baseBufferSeconds,
        maxBufferSeconds: maxBufferSeconds ?? this.maxBufferSeconds,
        milestones: milestones ?? this.milestones,
        firstGeneratorCost: firstGeneratorCost ?? this.firstGeneratorCost,
        tierCostRatio: tierCostRatio ?? this.tierCostRatio,
        firstGeneratorOutput: firstGeneratorOutput ?? this.firstGeneratorOutput,
        tierOutputRatio: tierOutputRatio ?? this.tierOutputRatio,
        tierUpgradeCosts: tierUpgradeCosts ?? this.tierUpgradeCosts,
        tierUpgradeMultiplier: tierUpgradeMultiplier ?? this.tierUpgradeMultiplier,
        globalUpgradeCost: globalUpgradeCost ?? this.globalUpgradeCost,
        globalUpgradeMultiplier: globalUpgradeMultiplier ?? this.globalUpgradeMultiplier,
        qualityUpgradeCost: qualityUpgradeCost ?? this.qualityUpgradeCost,
        qualityUpgradeMultiplier: qualityUpgradeMultiplier ?? this.qualityUpgradeMultiplier,
      );
}

/// Действующие числа.
///
/// Найдены прогоном, а не подобраны на глаз. Лестница — вариант C из
/// docs/PLAN-1.0.md (ступень ×28, выход ×6, штука ×1.15); цены улучшений —
/// перебором вокруг него (`tools/balance_sweep.dart`); порог первой мудрости
/// снят с кривой (`firstWisdomFromCurve`). Проверяются тестом
/// `test/balance_test.dart` — если правка выведет игру за цели из
/// [BalanceTargets], тест упадёт.
const Balance kBalance = Balance(
  costGrowth: 1.15,
  firstWisdomMl: 8.4e13,
  firstWisdomBonus: 1.0,
  bonusPerWisdom: 0.5,
  basePricePerMl: 0.1,
  baseTankMl: 2000,
  baseBufferSeconds: 120,
  maxBufferSeconds: 1800,
  milestones: [10, 25, 50, 100, 150, 200, 250, 300, 400, 500],
  firstGeneratorCost: 15,
  tierCostRatio: 28.0,
  firstGeneratorOutput: 1,
  tierOutputRatio: 6.0,
  tierUpgradeCosts: [30, 1e3, 1e5],
  tierUpgradeMultiplier: 2,
  globalUpgradeCost: 500,
  globalUpgradeMultiplier: 2,
  qualityUpgradeCost: 5e4,
  qualityUpgradeMultiplier: 1.3,
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
///
/// Запись v1 не видит никто: сейв без пометки считается v1, а новичку
/// новости не показываются. Она нужна как точка отсчёта — версия баланса
/// обязана быть объявлена в журнале. Семь записей тестовых сборок свёрнуты
/// в неё при чистом старте: их игроки начинают заново и старых цифр не
/// увидят, так что объяснять разницу некому.
const List<BalanceRelease> kBalanceLog = [
  BalanceRelease(
    version: 1,
    title: 'Первый выпуск',
    changes: [
      'Гараж открывается: тринадцать аппаратов от банки до коллайдера, '
          'улучшения, цели и похмелье ради мудрости.',
      'Все числа выпуска — точка отсчёта. Следующие правки будут объявлены '
          'здесь же, а если станет хуже — с компенсацией.',
    ],
  ),
];

/// Выпуски, которые игрок ещё не видел.
///
/// Журнал подставляется в тестах: в выпуске в нём одна запись, а проверять
/// надо, как игра ведёт себя, когда записей много.
List<BalanceRelease> releasesSince(
  int seenVersion, [
  List<BalanceRelease> log = kBalanceLog,
]) =>
    [for (final r in log) if (r.version > seenVersion) r];

/// Сколько мудрости причитается за переход с [seenVersion] на текущую версию.
int compensationSince(
  int seenVersion, [
  List<BalanceRelease> log = kBalanceLog,
]) =>
    releasesSince(seenVersion, log)
        .fold(0, (sum, r) => sum + r.compensationWisdom);
