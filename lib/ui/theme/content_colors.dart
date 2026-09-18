/// Мост между контентом и рисованием.
///
/// Контент хранит цвета числами ARGB и не импортирует Flutter — благодаря
/// этому правила игры можно прогонять обычным `dart run` (симулятор баланса,
/// отчёты). Превращать числа в [Color] — работа интерфейса, и делается она
/// ровно здесь, а не в десяти местах по виджетам.
library;

import 'package:flutter/painting.dart';

import '../../content/sorts.dart';

extension SortPalette on Sort {
  /// Тусклый край градиента.
  Color get fromColor => Color(from);

  /// Яркий край — им же красим подписи и пипки.
  Color get toColor => Color(to);
}
