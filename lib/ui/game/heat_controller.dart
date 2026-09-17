import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// В каком состоянии жар под кубом.
enum HeatStatus {
  /// Мимо окна — серия тает.
  off,

  /// В окне — серия растёт.
  inWindow,

  /// Перегрев — серия сгорает.
  overheated,
}

/// ЖАР ПОД КУБОМ — единственное, ради чего игрок касается экрана.
///
/// ## Почему зажим, а не тапы
///
/// Раньше нажатие давало и самогон, и жар. Из-за этого выигрывал тот, кто
/// быстрее долбит по экрану: спам приносил больше, чем любая осмысленная
/// игра, а «подождать хороший сорт» становилось проигрышной стратегией.
/// Навыка в этом не было никакого — только выносливость пальца.
///
/// Теперь нажатие не даёт самогон вовсе. Оно даёт **жар**, а жар множит всё
/// производство. И подаётся он **зажимом**: держишь палец — поддуваешь,
/// отпустил — остывает. Долбить по экрану бессмысленно физически, а держать
/// ровно — это навык, который можно осваивать.
///
/// ## СЕРИЯ
///
/// Сам по себе жар ничего не стоит: важно **удержать его в окне**. Пока
/// удерживаешь, копится СЕРИЯ — она и есть множитель. Окно при этом медленно
/// ходит по шкале, поэтому «зажал и забыл» тоже не работает: надо вести.
///
/// ## Почему серия не срывается, когда отвлёкся
///
/// Самое раздражающее, что может сделать такая механика, — обнулить всё
/// потому, что игрок потянулся к магазину. Поэтому:
///
/// * **Угли.** Отпустил палец — жар держится ещё [emberSeconds] секунд и
///   только потом начинает падать. Угли не гаснут мгновенно.
/// * **Серия тает, а не обнуляется.** Вне окна она сползает за [seriesFadeSeconds],
///   и этого с запасом хватает, чтобы что-то купить.
/// * **Обнуляет её только перегрев.** Это единственное настоящее наказание,
///   и оно за настоящую ошибку, а не за поход в магазин.
/// * **Покупка подкидывает жару** (см. [stokeOnPurchase]): купил аппарат —
///   Витя его растопил. Магазин не мешает серии, а помогает.
class HeatController extends ChangeNotifier {
  /// Насколько быстро растёт жар, пока палец на экране.
  static const double risePerSecond = 0.42;

  /// Скорость остывания в секунду, когда не поддувают.
  static const double decayPerSecond = 0.30;

  /// Сколько секунд после отпускания жар ещё держится.
  ///
  /// Это и есть запас на «отвлёкся»: вместе с таянием серии он даёт около
  /// тринадцати секунд, чтобы спокойно зайти в магазин.
  static const double emberSeconds = 3.0;

  /// За сколько секунд вне окна серия сползает с максимума до нуля.
  static const double seriesFadeSeconds = 10.0;

  /// За сколько секунд ровной работы серия набирается до предела.
  static const double seriesFillSeconds = 45.0;

  /// Во сколько раз полная серия множит производство.
  ///
  /// Втрое: активная игра заметно выгоднее фоновой, но не обязывает сидеть в
  /// телефоне. Не поиграл вечером — отстал в три раза, а не в десять.
  static const double maxSeriesMultiplier = 3.0;

  /// Импульс жара за покупку — «растопил новый аппарат».
  static const double purchaseStoke = 0.18;

  /// Ширина окна по шкале.
  static const double windowSize = 0.18;

  /// Скорость хода окна в секунду.
  static const double windowSpeed = 0.022;

  static const double windowMin = 0.10;
  static const double windowMax = 0.72;

  /// Выше этого — перегрев, серия сгорает.
  static const double overheatAt = 0.93;

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  double _heat = 0.0;
  double _windowPos = 0.40;
  int _windowDir = 1;

  /// 0..1 — сколько набрано серии.
  double _series = 0.0;

  /// Поддувают ли прямо сейчас.
  bool _stoking = false;

  /// Сколько секунд углям ещё держать жар.
  double _embers = 0.0;

  /// Состояние относительно окна отдельным уведомителем.
  ///
  /// Сам контроллер уведомляет каждый кадр — этого требует движущаяся шкала.
  /// Но подписи меняются раз в несколько секунд, и перестраивать их
  /// шестьдесят раз в секунду незачем: замер показал, что именно такие
  /// мелочи и съедали кадр.
  final ValueNotifier<HeatStatus> statusNotifier =
      ValueNotifier(HeatStatus.off);

  HeatController({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_onTick)..start();
  }

  double get heat => _heat;
  double get windowStart => _windowPos;
  double get windowEnd => _windowPos + windowSize;
  double get series => _series;
  bool get isStoking => _stoking;

  bool get isOverheated => _heat > overheatAt;
  bool get isInWindow =>
      !isOverheated && _heat >= _windowPos && _heat <= _windowPos + windowSize;

  HeatStatus get status => isOverheated
      ? HeatStatus.overheated
      : (isInWindow ? HeatStatus.inWindow : HeatStatus.off);

  /// Во сколько раз серия множит производство прямо сейчас.
  double get multiplier => 1.0 + (maxSeriesMultiplier - 1.0) * _series;

  /// Подпись под шкалой.
  String get label => switch (status) {
        HeatStatus.overheated => 'ПЕРЕГРЕВ',
        HeatStatus.inWindow => 'В САМЫЙ РАЗ',
        HeatStatus.off => _heat < _windowPos ? 'МАЛО ЖАРА' : 'МНОГО ЖАРА',
      };

  /// Что делать прямо сейчас. Подсказка обязана быть про ДЕЙСТВИЕ, а не про
  /// состояние: «много жара» не говорит новичку, что отпустить.
  String get hint => switch (status) {
        HeatStatus.overheated => 'отпусти, сейчас сгорит',
        HeatStatus.inWindow => 'так и держи',
        HeatStatus.off => _heat < _windowPos ? 'держи палец' : 'отпусти немного',
      };

  /// Начать поддув.
  void startStoking() {
    if (_stoking) return;
    _stoking = true;
    notifyListeners();
  }

  /// Прекратить поддув — угли подхватывают.
  void stopStoking() {
    if (!_stoking) return;
    _stoking = false;
    _embers = emberSeconds;
    notifyListeners();
  }

  /// Покупка растопила новый аппарат.
  ///
  /// Не украшение: без этого поход в магазин ощущался бы наказанием, потому
  /// что ради него приходится снимать палец.
  void stokeOnPurchase() {
    _heat = math.min(1.0, _heat + purchaseStoke);
    _embers = math.max(_embers, emberSeconds);
    statusNotifier.value = status;
    notifyListeners();
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.016
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;

    // --- Жар ---------------------------------------------------------
    if (_stoking) {
      _heat = math.min(1.0, _heat + risePerSecond * dt);
    } else if (_embers > 0) {
      _embers -= dt; // угли держат
    } else {
      _heat = math.max(0.0, _heat - decayPerSecond * dt);
    }

    // --- Серия -------------------------------------------------------
    switch (status) {
      case HeatStatus.overheated:
        // Единственное настоящее наказание — и оно за настоящую ошибку.
        _series = 0.0;
      case HeatStatus.inWindow:
        _series = math.min(1.0, _series + dt / seriesFillSeconds);
      case HeatStatus.off:
        _series = math.max(0.0, _series - dt / seriesFadeSeconds);
    }

    // --- Окно --------------------------------------------------------
    _windowPos += _windowDir * windowSpeed * dt;
    if (_windowPos > windowMax) {
      _windowPos = windowMax;
      _windowDir = -1;
    } else if (_windowPos < windowMin) {
      _windowPos = windowMin;
      _windowDir = 1;
    }

    statusNotifier.value = status;
    notifyListeners();
  }

  @override
  void dispose() {
    statusNotifier.dispose();
    _ticker.dispose();
    super.dispose();
  }
}
