import 'package:equatable/equatable.dart';

/// Статистика игрока — то, что иначе не восстановить.
///
/// Здесь только счётчики и отметки времени, то есть ФАКТЫ: сколько держал
/// жар, сколько продал, когда начал заход. Всё производное — доля времени в
/// окне, средняя цена литра, пересчёт нагнанного в банки и бассейны — сюда
/// не кладётся, а считается при показе. Сохранённое среднее застыло бы с той
/// формулой, по которой его посчитали, и новая формула до него не дошла бы.
///
/// Счётчики — за всю игру: похмелье их не сбрасывает. Сбрасывает только
/// «Начать заново» — там стирается всё.
///
/// Уже существующие факты сюда не переехали: касания живут в
/// [ClickerState], нагнанное и похмелья — в [PrestigeState]. Перенос
/// потребовал бы миграции сейва ради одной красоты.
class StatsState extends Equatable {
  /// Когда игра запущена впервые — от него «дней с первого запуска».
  final DateTime firstLaunch;

  /// Сколько секунд игра была на экране.
  ///
  /// Оффлайн и свёрнутая вкладка сюда не попадают: время приходит тиком
  /// игры, и только пока гараж рисуется на экране (см. `FramePulse`).
  final double playSeconds;

  /// Сколько из них держали зажим — главное действие игры.
  final double holdSeconds;

  /// Сколько из них жар простоял в окне. Держать и попадать — разное: жар
  /// проходит окно и без пальца, пока остывает.
  final double windowSeconds;

  /// Сколько продано, мл.
  final double soldMl;

  /// Сколько рублей выручено продажами.
  final double earned;

  /// Сколько было сделок, включая автопродажу.
  final int sales;

  /// Самая дорогая сделка, ₽.
  final double bestSale;

  /// Сколько сделок было с гостями — теми, кто заходит по расписанию.
  final int guestSales;

  /// Сколько аппаратов куплено за всю игру. Стартовая банка — не покупка.
  final int stillsBought;

  /// Сколько улучшений куплено за всю игру.
  final int upgradesBought;

  /// Когда начался текущий заход: первый запуск или последнее похмелье.
  final DateTime runStart;

  /// Самый быстрый заход — от пробуждения до похмелья, в секундах. `null`,
  /// пока похмелья не было.
  ///
  /// По обычным часам, вместе с оффлайном: игра idle, и заход, прожитый в
  /// основном с закрытой игрой, — всё равно заход.
  final double? fastestRunSeconds;

  const StatsState({
    required this.firstLaunch,
    required this.runStart,
    this.playSeconds = 0,
    this.holdSeconds = 0,
    this.windowSeconds = 0,
    this.soldMl = 0,
    this.earned = 0,
    this.sales = 0,
    this.bestSale = 0,
    this.guestSales = 0,
    this.stillsBought = 0,
    this.upgradesBought = 0,
    this.fastestRunSeconds,
  });

  /// Статистика новой игры, запущенной в [now].
  factory StatsState.startedAt(DateTime now) =>
      StatsState(firstLaunch: now, runStart: now);

  /// Прошло [seconds] секунд игры на экране.
  StatsState addPlay(
    double seconds, {
    required bool holding,
    required bool inWindow,
  }) =>
      copyWith(
        playSeconds: playSeconds + seconds,
        holdSeconds: holding ? holdSeconds + seconds : holdSeconds,
        windowSeconds: inWindow ? windowSeconds + seconds : windowSeconds,
      );

  /// Состоялась сделка: [ml] ушло за [revenue] рублей.
  StatsState addSale(double ml, double revenue, {required bool guest}) =>
      copyWith(
        soldMl: soldMl + ml,
        earned: earned + revenue,
        sales: sales + 1,
        bestSale: revenue > bestSale ? revenue : bestSale,
        guestSales: guest ? guestSales + 1 : guestSales,
      );

  /// Заход закончился похмельем в [now]; следующий начинается тут же.
  StatsState finishRun(DateTime now) {
    final run = now.difference(runStart).inMilliseconds / 1000.0;
    final best = fastestRunSeconds;
    // Часы, переведённые назад, дали бы заход отрицательной длины — и он
    // навсегда остался бы рекордом.
    final fastest = run <= 0
        ? best
        : (best == null || run < best ? run : best);
    return StatsState(
      firstLaunch: firstLaunch,
      runStart: now,
      playSeconds: playSeconds,
      holdSeconds: holdSeconds,
      windowSeconds: windowSeconds,
      soldMl: soldMl,
      earned: earned,
      sales: sales,
      bestSale: bestSale,
      guestSales: guestSales,
      stillsBought: stillsBought,
      upgradesBought: upgradesBought,
      fastestRunSeconds: fastest,
    );
  }

  StatsState copyWith({
    double? playSeconds,
    double? holdSeconds,
    double? windowSeconds,
    double? soldMl,
    double? earned,
    int? sales,
    double? bestSale,
    int? guestSales,
    int? stillsBought,
    int? upgradesBought,
  }) =>
      StatsState(
        firstLaunch: firstLaunch,
        runStart: runStart,
        playSeconds: playSeconds ?? this.playSeconds,
        holdSeconds: holdSeconds ?? this.holdSeconds,
        windowSeconds: windowSeconds ?? this.windowSeconds,
        soldMl: soldMl ?? this.soldMl,
        earned: earned ?? this.earned,
        sales: sales ?? this.sales,
        bestSale: bestSale ?? this.bestSale,
        guestSales: guestSales ?? this.guestSales,
        stillsBought: stillsBought ?? this.stillsBought,
        upgradesBought: upgradesBought ?? this.upgradesBought,
        fastestRunSeconds: fastestRunSeconds,
      );

  @override
  List<Object?> get props => [
        firstLaunch,
        playSeconds,
        holdSeconds,
        windowSeconds,
        soldMl,
        earned,
        sales,
        bestSale,
        guestSales,
        stillsBought,
        upgradesBought,
        runStart,
        fastestRunSeconds,
      ];

  @override
  bool get stringify => true;
}
