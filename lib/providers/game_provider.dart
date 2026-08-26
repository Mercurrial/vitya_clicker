import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/game_content.dart';
import '../engine/formulas.dart';
import '../engine/game_engine.dart';
import '../models/game_state.dart';
import '../models/generator.dart';
import '../models/upgrade.dart';

final timeProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final formulasProvider = Provider<Formulas>((ref) => const Formulas());

final gameEngineProvider = Provider<GameEngine>(
  (ref) => GameEngine(formulas: ref.watch(formulasProvider)),
);

/// Контент отдаётся через провайдеры — так его можно подменить в тестах.
final generatorsContentProvider = Provider<List<Generator>>((ref) => kGenerators);
final upgradesContentProvider = Provider<List<Upgrade>>((ref) => kUpgrades);

class GameNotifier extends Notifier<GameState> {
  Timer? _timer;

  /// Шаг симуляции. 200 мс достаточно для плавности (счётчик в интерфейсе
  /// сглаживается отдельно) и заметно бережнее к батарее, чем 16 мс.
  static const _tickInterval = Duration(milliseconds: 200);

  @override
  GameState build() {
    _timer = Timer.periodic(_tickInterval, (_) => _tick());
    ref.onDispose(() => _timer?.cancel());

    return GameState.initial(
      initialGenerators: ref.watch(generatorsContentProvider),
      initialUpgrades: ref.watch(upgradesContentProvider),
    );
  }

  void _tick() {
    final engine = ref.read(gameEngineProvider);
    state = engine.processTick(state, ref.read(timeProvider)());
  }

  /// Нажатие по Вите. [heatMultiplier] приходит от шкалы ГРАДУСА.
  void tap({double heatMultiplier = 1.0}) {
    final engine = ref.read(gameEngineProvider);
    state = engine.processTap(
      state,
      ref.read(timeProvider)(),
      heatMultiplier: heatMultiplier,
    );
  }

  void buyGenerator(String id) {
    final engine = ref.read(gameEngineProvider);
    state = engine.buyGenerator(state, id, ref.read(timeProvider)());
  }

  void buyUpgrade(String id) {
    final engine = ref.read(gameEngineProvider);
    state = engine.buyUpgrade(state, id, ref.read(timeProvider)());
  }

  /// Уйти в похмелье: сброс гаража ради мудрости.
  void sleepItOff() {
    final engine = ref.read(gameEngineProvider);
    state = engine.prestige(
      state,
      ref.read(generatorsContentProvider),
      ref.read(upgradesContentProvider),
      ref.read(timeProvider)(),
    );
  }

  /// Начисление за отсутствие игрока. Считается тем же тиком — доход обязан
  /// быть чистой функцией состояния и времени.
  void applyOffline(Duration credited) {
    if (credited <= Duration.zero) return;
    final engine = ref.read(gameEngineProvider);
    final now = ref.read(timeProvider)();
    state = state.copyWith(lastUpdateTime: now.subtract(credited));
    state = engine.processTick(state, now);
  }
}

final gameProvider = NotifierProvider<GameNotifier, GameState>(GameNotifier.new);
