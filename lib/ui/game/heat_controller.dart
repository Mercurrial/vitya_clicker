import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// В каком состоянии жар под кубом.
enum HeatStatus {
  /// Мимо окна — сорт медленно сползает.
  off,

  /// В окне — сорт растёт.
  inWindow,

  /// Перегрев — сорт горит.
  overheated,
}

/// ЖАР ПОД КУБОМ.
///
/// Тап подкидывает дров, жар остывает до тлеющих углей. Но главное не в самом
/// жаре, а в **окне**: держишь стрелку внутри — растёт СОРТ самогона, а сорт
/// напрямую умножает цену за литр и открывает хороших покупателей.
///
/// Окно медленно ходит по шкале. Из-за этого автокликер с ровной частотой его
/// не удержит: нужно смотреть и подстраиваться. И из-за этого же появляется
/// смысл ждать — раньше продать было выгодно всегда, потому что ожидание
/// ничего не давало.
class HeatController extends ChangeNotifier {
  /// Сколько жара добавляет одно нажатие.
  static const double heatPerTap = 0.13;

  /// Скорость остывания в секунду.
  static const double decayPerSecond = 0.055;

  /// Ниже этого жар не падает — под кубом всегда тлеют угли.
  static const double emberFloor = 0.28;

  /// Ширина окна по шкале.
  static const double windowSize = 0.16;

  /// Скорость хода окна в секунду.
  static const double windowSpeed = 0.022;

  static const double windowMin = 0.10;
  static const double windowMax = 0.78;

  /// Выше этого — перегрев, сорт горит.
  static const double overheatAt = 0.90;

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  double _heat = emberFloor;
  double _windowPos = 0.46;
  int _windowDir = 1;

  /// Состояние относительно окна отдельным уведомителем.
  ///
  /// Сам контроллер уведомляет каждый кадр — этого требует движущаяся шкала.
  /// Но подписи («В САМЫЙ РАЗ», «сорт растёт») меняются раз в несколько
  /// секунд, и перестраивать их шестьдесят раз в секунду незачем. Замер
  /// показал, что именно такие мелочи и съедали кадр.
  final ValueNotifier<HeatStatus> statusNotifier =
      ValueNotifier(HeatStatus.off);

  HeatController({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_onTick)..start();
  }

  double get heat => _heat;
  double get windowStart => _windowPos;
  double get windowEnd => _windowPos + windowSize;

  bool get isOverheated => _heat > overheatAt;
  bool get isInWindow =>
      !isOverheated && _heat >= _windowPos && _heat <= _windowPos + windowSize;

  HeatStatus get status => isOverheated
      ? HeatStatus.overheated
      : (isInWindow ? HeatStatus.inWindow : HeatStatus.off);

  /// Подпись под шкалой.
  String get label => switch (status) {
        HeatStatus.overheated => 'ПЕРЕГРЕВ',
        HeatStatus.inWindow => 'В САМЫЙ РАЗ',
        HeatStatus.off => 'МИМО',
      };

  /// Что происходит с сортом — короткая подсказка рядом со шкалой.
  String get sortHint => switch (status) {
        HeatStatus.overheated => 'сорт горит',
        HeatStatus.inWindow => 'сорт растёт',
        HeatStatus.off => _heat < _windowPos ? 'мало жара' : 'жара много',
      };

  /// Подкинуть дров.
  void stoke() {
    _heat = math.min(1.0, _heat + heatPerTap);
    statusNotifier.value = status;
    notifyListeners();
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.016
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;

    _heat = math.max(emberFloor, _heat - decayPerSecond * dt);

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
