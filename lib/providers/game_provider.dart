import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/game_content.dart';
import '../models/achievement.dart';
import '../core/game_clock.dart';
import '../core/game_serializer.dart';
import '../core/save.dart';
import '../engine/formulas.dart';
import '../engine/game_engine.dart';
import '../models/game_state.dart';
import '../models/generator.dart';
import '../models/upgrade.dart';

final timeProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Состояние, поднятое из сейва. Подменяется в `main` через override —
/// сейв читается до первого кадра, поэтому игрок сразу видит свой гараж.
final initialStateProvider = Provider<GameState?>((ref) => null);

/// Сервис сохранений. Тоже приходит из `main`; без него игра работает, но
/// прогресс не пишется (удобно для тестов).
final saveServiceProvider = Provider<SaveService?>((ref) => null);

final serializerProvider = Provider<GameSerializer>((ref) => const GameSerializer());

final clockProvider = Provider<GameClock>((ref) => const GameClock());

final formulasProvider = Provider<Formulas>((ref) => const Formulas());

final gameEngineProvider = Provider<GameEngine>(
  (ref) => GameEngine(formulas: ref.watch(formulasProvider)),
);

/// Контент отдаётся через провайдеры — так его можно подменить в тестах.
final generatorsContentProvider = Provider<List<Generator>>((ref) => kGenerators);
final upgradesContentProvider = Provider<List<Upgrade>>((ref) => kUpgrades);

class GameNotifier extends Notifier<GameState> {
  Timer? _timer;
  Timer? _saveTimer;

  /// Шаг симуляции. 200 мс достаточно для плавности (счётчик в интерфейсе
  /// сглаживается отдельно) и заметно бережнее к батарее, чем 16 мс.
  static const _tickInterval = Duration(milliseconds: 200);

  /// Периодичность автосейва. Чаще писать в хранилище незачем: при сворачивании
  /// и выходе мы сохраняемся отдельно, а тут страховка от «убили процесс».
  static const _autosaveInterval = Duration(seconds: 20);

  @override
  GameState build() {
    _timer = Timer.periodic(_tickInterval, (_) => _tick());
    _saveTimer = Timer.periodic(_autosaveInterval, (_) => saveNow());
    ref.onDispose(() {
      _timer?.cancel();
      _saveTimer?.cancel();
    });

    return ref.watch(initialStateProvider) ??
        GameState.initial(
          initialGenerators: ref.watch(generatorsContentProvider),
          initialUpgrades: ref.watch(upgradesContentProvider),
        );
  }

  /// Записать прогресс. Вызывается по таймеру, при сворачивании и после
  /// значимых событий вроде похмелья.
  Future<void> saveNow() async {
    final saves = ref.read(saveServiceProvider);
    if (saves == null) return;
    final json = ref.read(serializerProvider).toJson(
          state,
          lastSeenMillis: ref.read(clockProvider).nowMillis(),
        );
    await saves.save(json);
  }

  /// Текущий жар под аппаратом. Ставится интерфейсом со шкалы ГРАДУСА и
  /// множит ВЕСЬ пассивный поток — ради этого игрок и тапает.
  double _heatMultiplier = 1.0;

  void setHeat(double multiplier) => _heatMultiplier = multiplier;

  /// Достижения, открывшиеся с прошлого тика — интерфейс показывает по ним
  /// всплывающие плашки.
  final List<Achievement> freshAchievements = [];

  void _tick() {
    final engine = ref.read(gameEngineProvider);
    final now = ref.read(timeProvider)();

    var next = engine.processTick(state, now, heatMultiplier: _heatMultiplier);

    // Автопродажа: открывается достижением, а не выдаётся сразу. Именно так
    // неудобство превращается в цель, из которой игрок выкупается.
    if (next.achievements.hasPerk(AchievementPerk.autoSell) && next.isTankFull) {
      next = engine.sell(next, now);
    }

    final checked = engine.checkAchievements(next);
    if (checked.fresh.isNotEmpty) freshAchievements.addAll(checked.fresh);

    state = checked.state;
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

  /// Сдать весь бак по текущей цене.
  void sell() {
    final engine = ref.read(gameEngineProvider);
    state = engine.sell(state, ref.read(timeProvider)());
  }

  void buyGenerator(String id, {int count = 1}) {
    final engine = ref.read(gameEngineProvider);
    final now = ref.read(timeProvider)();
    state = count <= 1
        ? engine.buyGenerator(state, id, now)
        : engine.buyGeneratorBulk(state, id, count, now);
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
    // Событие необратимое — пишем сразу, не дожидаясь автосейва.
    saveNow();
  }

  /// Полный сброс: стереть сейв и начать с нуля.
  ///
  /// Нужен и для честного тестирования баланса, и как выход для игрока,
  /// который хочет пройти заново без похмелья.
  Future<void> hardReset() async {
    await ref.read(saveServiceProvider)?.wipe();
    state = GameState.initial(
      initialGenerators: ref.read(generatorsContentProvider),
      initialUpgrades: ref.read(upgradesContentProvider),
      lastUpdateTime: ref.read(timeProvider)(),
    );
    await saveNow();
  }

  /// Начисление за отсутствие игрока. Считается тем же тиком — доход обязан
  /// быть чистой функцией состояния и времени.
  void applyOffline(Duration credited) {
    final engine = ref.read(gameEngineProvider);
    state = engine
        .creditOffline(state, credited, ref.read(timeProvider)())
        .state;
  }
}

final gameProvider = NotifierProvider<GameNotifier, GameState>(GameNotifier.new);
