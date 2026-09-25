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

  /// Сейв не прочитался — строка, как она лежала. Гараж начат заново, и
  /// игроку надо сказать это и дать строку скопировать: её можно прислать
  /// разработчику.
  final String? brokenSave;

  /// Легла ли копия [brokenSave] отдельно (см. [SaveService.rescue]). Если
  /// нет, игроку нельзя говорить «отложено» — только «скопируй сейчас».
  final bool brokenSaveKept;

  /// Сейв записан более новой версией игры. Играть в этой версии нельзя:
  /// любой её автосейв затёр бы новый прогресс старым гаражом. Поэтому
  /// `main` не показывает гараж и не отдаёт игре сервис сейва.
  final bool saveFromFuture;

  /// Отложенная раньше копия, которая теперь читается, — например, после
  /// обновления. Игроку предложат вернуть из неё гараж.
  final RescuedGarage? rescuedGarage;

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
    this.brokenSave,
    this.brokenSaveKept = false,
    this.saveFromFuture = false,
    this.rescuedGarage,
    this.testSaveDropped = false,
    this.balanceNews = const [],
  });

  /// Сейв не прочитался, и игра начата заново.
  bool get saveWasLost => brokenSave != null;

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
  GameState fresh() =>
      newGame(content: kGenerators, upgrades: kUpgrades, now: now);

  // Сейв новой версии не читается и не трогается: ни копии, ни нового
  // гаража поверх. Состояние — заглушка, игру не покажут.
  if (loaded.fromFuture) {
    return Bootstrap(
      state: fresh(),
      saves: saves,
      settings: storages.settings,
      offline: OfflineResult.none,
      fluxGained: 0,
      saveFromFuture: true,
    );
  }

  final data = loaded.data;
  var state = data == null ? null : _readState(serializer, data, now);

  // Сейв, который кодек разобрал, но сериализатор не собрал, — тоже
  // нечитаемый. Упади он здесь, игрок видел бы белый экран на каждом
  // запуске.
  final broken =
      loaded.wasCorrupt || (data != null && state == null) ? loaded.raw : null;

  // Копия — до первой записи. Запуск идёт до первого кадра, а автосейв и
  // запись при сворачивании появляются только с игрой, так что поверх
  // битого сейва никто не успеет написать новый гараж.
  final kept = broken != null && await saves.rescue(broken);
  final rescued = await _readableCopy(saves, serializer, now);

  if (data == null || state == null) {
    return Bootstrap(
      state: fresh(),
      saves: saves,
      settings: storages.settings,
      offline: OfflineResult.none,
      fluxGained: 0,
      brokenSave: broken,
      brokenSaveKept: kept,
      rescuedGarage: rescued,
      testSaveDropped: loaded.fromTestVersion,
    );
  }

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
    rescuedGarage: rescued,
    balanceNews: news,
  );
}

/// Отложенная копия, которая теперь читается.
class RescuedGarage {
  /// Строка, как она лежит среди копий: по ней гараж и возвращают, и
  /// копию выбрасывают.
  final String raw;

  /// Во что копия читается сейчас — показать игроку, что он вернёт.
  final GameState state;

  const RescuedGarage({required this.raw, required this.state});
}

GameState? _readState(
  GameSerializer serializer,
  Map<String, dynamic> data,
  DateTime now,
) {
  try {
    return serializer.fromJson(
      data,
      content: kGenerators,
      upgrades: kUpgrades,
      now: now,
    );
  } catch (_) {
    return null;
  }
}

/// Копия, которую теперь можно прочитать, — после обновления, починившего
/// разбор. Если таких несколько, предлагаем ту, где нагнано больше всего:
/// спрашивать игрока «какую из двух» — хуже, чем выбрать дорогую ему.
Future<RescuedGarage?> _readableCopy(
  SaveService saves,
  GameSerializer serializer,
  DateTime now,
) async {
  RescuedGarage? best;
  for (final raw in await saves.rescued()) {
    final data = saves.codec.decode(raw).data;
    final state = data == null ? null : _readState(serializer, data, now);
    if (state == null) continue;
    final earned = state.prestige.totalEverEarned;
    if (best == null || earned > best.state.prestige.totalEverEarned) {
      best = RescuedGarage(raw: raw, state: state);
    }
  }
  return best;
}

