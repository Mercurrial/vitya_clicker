/// Запуск игры: поднять сейв, восстановить состояние, начислить поток за
/// отсутствие.
///
/// Делается ДО первого кадра, чтобы игрок сразу увидел свой гараж, а не пустой
/// экран, который через мгновение подменится загруженными данными.
library;

import '../content/balance.dart';
import '../content/game_content.dart';
import '../engine/game_engine.dart';
import '../models/game_state.dart';
import 'game_clock.dart';
import 'game_serializer.dart';
import 'prefs_storage.dart';
import 'save.dart';
import 'settings.dart';

/// Что получилось при запуске.
class Bootstrap {
  final GameState state;
  final SaveService saves;

  /// Настройки интерфейса — их надо знать до первого кадра, иначе игрок
  /// увидит стиль по умолчанию и через мгновение подмену на свой.
  final SettingsStore settings;

  /// Сколько игры не было (для экрана возвращения).
  final OfflineResult offline;

  /// Сколько потока принесло отсутствие, секунд.
  final double fluxGained;

  /// Сейв был испорчен и игра начата заново — об этом честно скажем игроку.
  final bool saveWasLost;

  /// Своего сейва нет, но есть сейв тестовой сборки: гараж новый, и игроку
  /// надо объяснить почему, до того как он решит, что прогресс пропал.
  final bool testSaveDropped;

  /// Правки баланса, случившиеся с прошлого запуска игрока.
  ///
  /// Пусто у новичка и у того, кто уже видел этот выпуск. Если не пусто —
  /// игре есть что объяснить, и она обязана это сделать сама, а не оставить
  /// игрока гадать, почему цифры поехали.
  final List<BalanceRelease> balanceNews;

  const Bootstrap({
    required this.state,
    required this.saves,
    required this.settings,
    required this.offline,
    required this.fluxGained,
    required this.saveWasLost,
    this.testSaveDropped = false,
    this.balanceNews = const [],
  });

  /// Показать экран возвращения. С полной копилкой — тоже, хотя ничего не
  /// прибавилось: игрок должен узнать, что поток переливается мимо.
  bool get shouldGreet =>
      offline.isMeaningful && (fluxGained > 0 || state.flux.isBankFull);

  /// Есть ли что рассказать про обновление.
  bool get hasBalanceNews => balanceNews.isNotEmpty;
}

/// Поднимает сохранение и готовит состояние к первому кадру.
Future<Bootstrap> bootstrapGame({
  GameClock clock = const GameClock(),
  GameSerializer serializer = const GameSerializer(),
}) async {
  final storages = await openStorages();
  final saves = SaveService(storage: storages.saves);
  final loaded = await saves.load();
  final now = clock.nowUtc();

  if (loaded.isEmpty) {
    return Bootstrap(
      state: newGame(content: kGenerators, upgrades: kUpgrades, now: now),
      saves: saves,
      settings: storages.settings,
      offline: OfflineResult.none,
      fluxGained: 0,
      saveWasLost: loaded.wasCorrupt,
      testSaveDropped: loaded.fromTestVersion,
    );
  }

  final data = loaded.data!;
  var state = serializer.fromJson(
    data,
    content: kGenerators,
    upgrades: kUpgrades,
    now: now,
  );

  // Баланс мог поменяться, пока игрок не заходил.
  //
  // Сам пересчёт при этом НЕ нужен: в сейве лежат только факты (сколько чего
  // куплено, сколько всего нагнано), а доход, цены и мудрость вычисляются по
  // текущим числам при загрузке. Новый баланс применился сам, строкой выше.
  //
  // Остаётся человеческая часть: сказать, что изменилось, и если изменение
  // болезненное — извиниться делом. Молча уронить игроку доход нельзя.
  final seenBalance = serializer.balanceVersionOf(data);
  final news = releasesSince(seenBalance);
  final compensation = compensationSince(seenBalance);
  if (compensation > 0) {
    state = state.copyWith(
      prestige: state.prestige.withCompensation(compensation),
    );
  }

  // Закрытая игра не гнала: за отсутствие — поток, а не самогон. Сколько
  // именно, решает движок; здесь только «сколько игры не было».
  final offline = clock.since(serializer.lastSeenOf(data));
  final credited = const GameEngine().creditAfk(state, offline.elapsed);
  state = credited.state;

  return Bootstrap(
    state: state,
    saves: saves,
    settings: storages.settings,
    offline: offline,
    fluxGained: credited.gained,
    saveWasLost: false,
    balanceNews: news,
  );
}

