import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// ГРАДУС — состояние аппарата.
///
/// Тап подкидывает жару, жар со временем спадает. Держишь стрелку в зелёной
/// зоне — выход ×3, перегрел — брак.
///
/// Ключевая деталь: **зелёная зона медленно гуляет**. На живом аппарате режим
/// не стоит на месте, и это же решает главную проблему кликеров — автокликер с
/// ровной частотой зону не удержит, потому что она уезжает. Нужно смотреть на
/// шкалу и подстраиваться, то есть тап становится навыком, а не долблением.
///
/// Механика намеренно НЕобязательная: аппараты всегда работают сами, зелёная
/// зона — только бонус для того, кто сейчас в игре (idle-жанр награждает
/// отсутствие, и мини-игра не должна этому противоречить).
class HeatController extends ChangeNotifier {
  /// Сколько жара добавляет одно нажатие.
  static const double heatPerTap = 0.075;

  /// Скорость остывания в секунду.
  static const double decayPerSecond = 0.20;

  /// Полуширина зелёной зоны.
  static const double zoneHalfWidth = 0.08;

  /// Выше этого — перегрев и брак.
  static const double overheatAt = 0.94;

  /// Множители выхода.
  static const double greenMultiplier = 3.0;
  static const double nearMultiplier = 1.5;
  static const double coldMultiplier = 1.0;
  static const double overheatMultiplier = 0.4;

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  double _heat = 0.0;
  double _seconds = 0.0;

  HeatController({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_onTick)..start();
  }

  /// Текущий жар, 0..1.
  double get heat => _heat;

  /// Центр зелёной зоны прямо сейчас (гуляет).
  ///
  /// Сумма двух синусов с некратными периодами: движение не выглядит
  /// механическим, но остаётся плавным и честно читаемым по шкале.
  double get zoneCenter {
    final a = math.sin(_seconds * 0.55);
    final b = math.sin(_seconds * 0.23 + 1.3);
    final wave = (a * 0.65 + b * 0.35); // -1..1
    return 0.54 + wave * 0.22; // ≈0.32..0.76
  }

  double get zoneStart => zoneCenter - zoneHalfWidth;
  double get zoneEnd => zoneCenter + zoneHalfWidth;

  bool get isOverheated => _heat > overheatAt;
  bool get isInZone => !isOverheated && (_heat - zoneCenter).abs() <= zoneHalfWidth;

  /// Множитель к добыче за нажатие в текущем состоянии.
  double get multiplier {
    if (isOverheated) return overheatMultiplier;
    final d = (_heat - zoneCenter).abs();
    if (d <= zoneHalfWidth) return greenMultiplier;
    if (d <= zoneHalfWidth * 2) return nearMultiplier;
    return coldMultiplier;
  }

  /// Подкинуть жару. Возвращает множитель, действовавший В МОМЕНТ нажатия, —
  /// поэтому награда соответствует тому, что игрок видел на шкале.
  double stoke() {
    final applied = multiplier;
    _heat = math.min(1.0, _heat + heatPerTap);
    notifyListeners();
    return applied;
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.016
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _seconds += dt;

    if (_heat > 0) {
      _heat = math.max(0.0, _heat - decayPerSecond * dt);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
