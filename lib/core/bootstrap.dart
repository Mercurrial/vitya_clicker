/// Запуск игры: поднять сейв, восстановить состояние, начислить за отсутствие.
///
/// Делается ДО первого кадра, чтобы игрок сразу увидел свой гараж, а не пустой
/// экран, который через мгновение подменится загруженными данными.
library;

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

  /// Сколько накапало, пока игра была закрыта (для экрана возвращения).
  final OfflineResult offline;

  /// Сколько литров принесло отсутствие.
  final double offlineGain;

  /// Сейв был испорчен и игра начата заново — об этом честно скажем игроку.
  final bool saveWasLost;

  const Bootstrap({
    required this.state,
    required this.saves,
    required this.settings,
    required this.offline,
    required this.offlineGain,
    required this.saveWasLost,
  });

  bool get shouldGreet => offline.isMeaningful && offlineGain > 0;
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
      offlineGain: 0,
      saveWasLost: loaded.wasCorrupt,
    );
  }

  final data = loaded.data!;
  var state = serializer.fromJson(
    data,
    content: kGenerators,
    upgrades: kUpgrades,
    now: now,
  );

  // Оффлайн-доход считается тем же способом, что и обычный тик: сдвигаем метку
  // назад на засчитанное время и прогоняем одну итерацию. Так пассивный доход
  // остаётся единственной формулой — расходиться нечему.
  final offline = clock.since(serializer.lastSeenOf(data));
  final credited = const GameEngine().creditOffline(state, offline.credited, now);
  state = credited.state;
  final gained = credited.gained;

  return Bootstrap(
    state: state,
    saves: saves,
    settings: storages.settings,
    offline: offline,
    offlineGain: gained,
    saveWasLost: false,
  );
}

