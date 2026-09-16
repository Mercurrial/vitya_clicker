/// СОРТ самогона — что именно Витя нагнал.
///
/// Это ответ на настоящую дыру в экономике: цена гуляла ±35 %, но ждать пика
/// не имело смысла — выгоднее продать дешевле и сразу купить улучшение, оно
/// ускорит всё. Механика была, решения не было.
///
/// Теперь ожидание работает: жар в окне **поднимает сорт**, перегрев его
/// **сжигает**, а хорошие покупатели требуют сорт и **сбрасывают его на
/// ступень**. Появляется настоящий выбор — сдать сейчас дёшево и сохранить
/// сорт или доводить до «Дедова запаса» ради свадьбы.
library;

import 'package:flutter/painting.dart';

class Sort {
  final String name;

  /// Множитель к цене за литр.
  final double multiplier;

  /// Цвета для шкалы и пипок: от тусклого к золотому.
  final Color from;
  final Color to;

  const Sort({
    required this.name,
    required this.multiplier,
    required this.from,
    required this.to,
  });
}

/// Лестница сортов — от мутного первача до дедова запаса.
const List<Sort> kSorts = [
  Sort(
    name: 'Первач',
    multiplier: 1.0,
    from: Color(0xFF4E6B8A),
    to: Color(0xFF6A8CAF),
  ),
  Sort(
    name: 'Средняк',
    multiplier: 1.25,
    from: Color(0xFF7A6E5E),
    to: Color(0xFFA89681),
  ),
  Sort(
    name: 'Двойной перегон',
    multiplier: 1.6,
    from: Color(0xFFB0975F),
    to: Color(0xFFD8C48A),
  ),
  Sort(
    name: 'На кедраче',
    multiplier: 2.1,
    from: Color(0xFFB87C24),
    to: Color(0xFFE8A33D),
  ),
  Sort(
    name: 'Дедов запас',
    multiplier: 2.8,
    from: Color(0xFFE8A33D),
    to: Color(0xFFFFD089),
  ),
];

/// Насколько быстро сорт растёт, пока жар держат в окне (доля в секунду).
const double kSortGainPerSecond = 0.17;

/// Насколько быстро сорт горит при перегреве — вдвое быстрее, чем растёт.
/// Перегрев должен быть по-настоящему обидным, иначе окно можно игнорировать.
const double kSortBurnPerSecond = 0.42;

/// Медленная утечка, когда жар мимо окна: без внимания сорт сползает.
const double kSortDecayPerSecond = 0.06;
