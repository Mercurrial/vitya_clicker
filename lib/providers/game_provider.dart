import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/achievements.dart';
import '../content/buyers.dart';
import '../content/game_content.dart';
import '../content/sorts.dart';
import '../content/vitya_quotes.dart';
import '../core/formatters.dart';
import '../ui/widgets/vitya_toast.dart';
import '../models/achievement.dart';
import '../core/game_clock.dart';
import '../core/game_serializer.dart';
import '../core/save.dart';
import '../core/save_code.dart';
import '../core/sfx.dart';
import 'feedback_provider.dart';
import '../engine/formulas.dart';
import '../engine/game_engine.dart';
import '../models/game_state.dart';
import '../models/generator.dart';
import '../models/upgrade.dart';
import '../ui/game/heat_controller.dart' show HeatStatus;

final timeProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Состояние, поднятое из сейва. Подменяется в `main` через override —
/// сейв читается до первого кадра, поэтому игрок сразу видит свой гараж.
final initialStateProvider = Provider<GameState?>((ref) => null);

/// Сервис сохранений. Тоже приходит из `main`; без него игра работает, но
/// прогресс не пишется (удобно для тестов).
final saveServiceProvider = Provider<SaveService?>((ref) => null);

final serializerProvider = Provider<GameSerializer>((ref) => const GameSerializer());

final clockProvider = Provider<GameClock>((ref) => const GameClock());

/// Текущий множитель жара. Живёт в провайдере, а не приватным полем, потому
/// что его должен видеть и движок (для тика), и интерфейс (чтобы показывать
/// фактическую скорость, а не базовую).
final heatMultiplierProvider = StateProvider<double>((ref) => 1.0);

/// Состояние жара относительно окна — от него зависит, растёт сорт или горит.
final heatStatusProvider = StateProvider<HeatStatus>((ref) => HeatStatus.off);

/// Держат ли зажим прямо сейчас — для «времени зажима» в статистике.
final heatHoldingProvider = StateProvider<bool>((ref) => false);

/// Видна ли игра по жизненному циклу приложения. Ставит экран.
///
/// Нужен, потому что «тикает таймер — значит, играют» неверно: браузер не
/// останавливает таймеры свёрнутой вкладки, а только прореживает их.
final onScreenProvider = StateProvider<bool>((ref) => true);

/// Пульс экрана: сколько раз гараж перерисовался.
///
/// Жизненного цикла мало — проверка в браузере это показала. Страница,
/// открытая сразу в фоне, событий цикла не присылает вовсе, пока её не
/// покажут; встроенный браузер отвечает «видна» про вкладку, которую не
/// показывает. Таймеры у таких страниц идут без замедления, и время в игре
/// набегало без игрока.
///
/// Кадры не врут: всё, что не на экране, браузер не рисует. Шкала жара
/// движется непрерывно, поэтому, пока гараж виден, кадр приходит каждые
/// 16 мс, а тик — раз в 200. Нет кадра между тиками — игры на экране нет.
class FramePulse {
  int _beats = 0;
  int get beats => _beats;
  void beat() => _beats++;
}

final framePulseProvider = Provider<FramePulse>((ref) => FramePulse());

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

  /// Пульс экрана на прошлом тике — см. [FramePulse].
  int _seenBeats = 0;

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
        newGame(
          content: ref.watch(generatorsContentProvider),
          upgrades: ref.watch(upgradesContentProvider),
          now: ref.read(timeProvider)(),
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

  /// Множитель СЕРИИ — множит ВЕСЬ пассивный поток. Это единственное, что
  /// даёт активная игра.
  double get _heatMultiplier => ref.read(heatMultiplierProvider);

  void setHeat(double multiplier) =>
      ref.read(heatMultiplierProvider.notifier).state = multiplier;

  void _tick() {
    final engine = ref.read(gameEngineProvider);
    final now = ref.read(timeProvider)();

    var next = engine.processTick(state, now, heatMultiplier: _heatMultiplier);

    // Сорт двигается тем же тиком: держишь жар в окне — растёт, перегрел —
    // горит, отвлёкся — медленно сползает.
    final dt = _tickInterval.inMilliseconds / 1000.0;
    final heat = ref.read(heatStatusProvider);
    next = engine.advanceSort(next, switch (heat) {
      HeatStatus.inWindow => kSortGainPerSecond * dt,
      HeatStatus.overheated => -kSortBurnPerSecond * dt,
      HeatStatus.off => -kSortDecayPerSecond * dt,
    });

    // Время в игре — тоже тиком и тем же шагом, а не разницей часов.
    // Timer.periodic обещает не больше n срабатываний за n шагов, поэтому
    // насчитать больше, чем прошло, так нельзя в принципе: замерший на минуту
    // браузер даст одну пятую секунды, а не минуту.
    final beats = ref.read(framePulseProvider).beats;
    final drawn = beats != _seenBeats;
    _seenBeats = beats;
    if (drawn && ref.read(onScreenProvider)) {
      next = engine.recordPlay(
        next,
        dt,
        holding: ref.read(heatHoldingProvider),
        inWindow: heat == HeatStatus.inWindow,
      );
    }

    // Автопродажа: открывается достижением, а не выдаётся сразу. Именно так
    // неудобство превращается в цель, из которой игрок выкупается.
    if (next.achievements.hasPerk(AchievementPerk.autoSell) && next.isTankFull) {
      next = engine.sell(next, now);
    }

    // Сорт поднялся — это событие, его надо показать. Момент редкий, поэтому
    // здесь уместна и реплика Вити.
    if (next.sort.index > state.sort.index) {
      ref.read(toastProvider.notifier).show(
            kind: 'СОРТ ПОДНЯЛСЯ',
            title: next.sort.name,
            note: 'цена за литр ${Fmt.mult(next.sort.multiplier)}',
            event: VityaEvent.gradeUp,
          );
    }
    // Падение сорта и обычную продажу больше не объявляем: плашки сыпались
    // десятками за сеанс и превращались в шум, который перестают читать.
    // Остаётся редкое и важное — поднялся сорт, случилось похмелье.

    // Взятая цель — событие, и о нём надо сказать. Раньше открытые цели
    // складывались в список, который никто не читал: плашки не было вовсе,
    // и множитель рос молча, а автопродажа включалась без объяснений.
    final checked = engine.checkAchievements(next);
    if (checked.fresh.isNotEmpty) _announceGoals(checked.fresh);

    state = checked.state;
  }

  /// Плашка о взятой цели. Если открылось сразу несколько — одна плашка на
  /// все: очередь из пяти плашек подряд читали бы как шум.
  void _announceGoals(List<Achievement> fresh) {
    final first = fresh.first;
    final perk = fresh.map((a) => a.perk).firstWhere(
          (p) => p != AchievementPerk.none,
          orElse: () => AchievementPerk.none,
        );
    ref.read(toastProvider.notifier).show(
          kind: 'ЦЕЛЬ ВЗЯТА',
          title: fresh.length == 1
              ? first.name
              : '${first.name} и ещё ${fresh.length - 1}',
          note: switch (perk) {
            AchievementPerk.autoSell => 'открыта автопродажа: полный бак сдаётся сам',
            AchievementPerk.bulkBuy => 'открыта покупка пачками: ×10, ×100, МАКС',
            AchievementPerk.none => 'всё производство ${Fmt.mult(kAchievementMultiplier)}',
          },
          goalId: first.id,
        );
  }

  /// Отдача — звук и вибрация. Живёт здесь, а не в кнопках, намеренно:
  /// действие одно, а кнопок к нему может быть несколько, и каждая новая
  /// иначе обязана была бы помнить про звук.
  Feedback get _feedback => ref.read(feedbackProvider);

  /// Игрок коснулся гаража. Самогона это не даёт — только счётчик и
  /// достижения; производство двигает жар, а его держат зажимом.
  void registerTouch() {
    final engine = ref.read(gameEngineProvider);
    state = engine.registerTouch(state, ref.read(timeProvider)());
    _feedback.hit(Sfx.stoke, Buzz.light);
  }

  /// Сдать бак конкретному покупателю.
  void sellTo(Buyer buyer) {
    final engine = ref.read(gameEngineProvider);
    final now = ref.read(timeProvider)();
    if (!engine.canSellTo(state, buyer)) return;
    state = engine.sellTo(state, buyer, now);
    _feedback.hit(Sfx.sell, Buzz.medium);
  }

  /// Сдать бак соседу — он берёт всегда. Этим пользуется автопродажа, поэтому
  /// звука здесь нет: она срабатывает сама, в том числе пока игрок смотрит в
  /// другую сторону, и звенеть за него незачем.
  void sell() {
    final engine = ref.read(gameEngineProvider);
    state = engine.sell(state, ref.read(timeProvider)());
  }

  void buyGenerator(String id, {int count = 1}) {
    final engine = ref.read(gameEngineProvider);
    final now = ref.read(timeProvider)();
    final before = state;
    state = count <= 1
        ? engine.buyGenerator(state, id, now)
        : engine.buyGeneratorBulk(state, id, count, now);
    // Только если покупка ДЕЙСТВИТЕЛЬНО случилась: щелчок в ответ на нажатие
    // по недоступной кнопке — это обещание, которого игра не выполнила.
    if (!identical(state, before) && state != before) {
      _feedback.hit(Sfx.buy, Buzz.select);
    }
  }

  void buyUpgrade(String id) {
    final engine = ref.read(gameEngineProvider);
    final before = state;
    state = engine.buyUpgrade(state, id, ref.read(timeProvider)());
    if (!identical(state, before) && state != before) {
      _feedback.hit(Sfx.buy, Buzz.select);
    }
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
    ref.read(toastProvider.notifier).show(
          kind: 'ПОХМЕЛЬЕ',
          title: 'Мудрость: ${state.prestige.wisdom}',
          note: 'всё причудилось, но руки помнят',
          event: VityaEvent.hangover,
        );
    _feedback.hit(Sfx.hangover, Buzz.medium);

    // Событие необратимое — пишем сразу, не дожидаясь автосейва.
    saveNow();
  }

  /// Свернуть текущий прогресс в строку.
  ///
  /// Берём состояние из памяти, а не с диска: игрок жмёт «скопировать» ровно
  /// затем, чтобы сохранить то, что видит сейчас, а автосейв мог не успеть.
  String exportCode() {
    final json = ref.read(serializerProvider).toJson(
          state,
          lastSeenMillis: ref.read(clockProvider).nowMillis(),
        );
    return encodeSaveCode(const SaveCodec().encode(json));
  }

  /// Принять прогресс из строки.
  ///
  /// Возвращает `null`, если получилось, иначе — почему нет. Состояние
  /// применяется сразу: заставлять игрока перезапускать игру после переноса
  /// значит дать ему лишний повод усомниться, что перенос вообще случился.
  Future<SaveCodeError?> importCode(String? code) async {
    final parsed = decodeSaveCode(code);
    if (!parsed.isOk) return parsed.error;

    // Через тот же кодек, что и обычная загрузка: код может быть записан
    // старой версией игры, и миграции обязаны отработать.
    final loaded = const SaveCodec().decode(parsed.save);
    if (loaded.isEmpty || loaded.wasCorrupt) return SaveCodeError.damaged;

    state = ref.read(serializerProvider).fromJson(
          loaded.data!,
          content: ref.read(generatorsContentProvider),
          upgrades: ref.read(upgradesContentProvider),
          now: ref.read(timeProvider)(),
        );
    await saveNow();
    return null;
  }

  /// Полный сброс: стереть сейв и начать с нуля.
  ///
  /// Нужен и для честного тестирования баланса, и как выход для игрока,
  /// который хочет пройти заново без похмелья.
  Future<void> hardReset() async {
    await ref.read(saveServiceProvider)?.wipe();
    state = newGame(
      content: ref.read(generatorsContentProvider),
      upgrades: ref.read(upgradesContentProvider),
      now: ref.read(timeProvider)(),
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
