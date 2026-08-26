/// Запуск игры: поднять сейв, восстановить состояние, начислить за отсутствие.
///
/// Делается ДО первого кадра, чтобы игрок сразу увидел свой гараж, а не пустой
/// экран, который через мгновение подменится загруженными данными.
library;

import '../content/game_content.dart';
import '../models/game_state.dart';
import 'game_clock.dart';
import 'game_serializer.dart';
import 'prefs_storage.dart';
import 'save.dart';

/// Что получилось при запуске.
class Bootstrap {
  final GameState state;
  final SaveService saves;

  /// Сколько накапало, пока игра была закрыта (для экрана возвращения).
  final OfflineResult offline;

  /// Сколько литров принесло отсутствие.
  final double offlineGain;

  /// Сейв был испорчен и игра начата заново — об этом честно скажем игроку.
  final bool saveWasLost;

  const Bootstrap({
    required this.state,
    required this.saves,
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
  final saves = SaveService(storage: await PrefsSaveStorage.open());
  final loaded = await saves.load();
  final now = clock.nowUtc();

  if (loaded.isEmpty) {
    return Bootstrap(
      state: newGame(content: kGenerators, upgrades: kUpgrades, now: now),
      saves: saves,
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
  var gained = 0.0;
  if (offline.credited > Duration.zero && state.mlPerSecond > 0) {
    final before = state.resources.ml;
    state = state.copyWith(lastUpdateTime: now.subtract(offline.credited));
    state = const _TickOnly().apply(state, now);
    gained = state.resources.ml - before;
  }

  return Bootstrap(
    state: state,
    saves: saves,
    offline: offline,
    offlineGain: gained,
    saveWasLost: false,
  );
}

/// Тонкая обёртка, чтобы не тащить сюда весь движок ради одного тика.
class _TickOnly {
  const _TickOnly();

  GameState apply(GameState state, DateTime now) {
    final seconds =
        now.difference(state.lastUpdateTime).inMilliseconds / 1000.0;
    if (seconds <= 0) return state.copyWith(lastUpdateTime: now);
    final produced = state.mlPerSecond * seconds;
    return state.copyWith(
      resources: state.resources.copyWith(
        ml: state.resources.ml + produced,
      ),
      prestige: state.prestige.copyWith(
        totalEverEarned: state.prestige.totalEverEarned + produced,
      ),
      lastUpdateTime: now,
    );
  }
}
