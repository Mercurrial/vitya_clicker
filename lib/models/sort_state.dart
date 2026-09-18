import 'package:equatable/equatable.dart';

import '../content/sorts.dart';

/// Текущий сорт и продвижение к следующему.
///
/// Хранится в состоянии игры, а не в интерфейсе: сорт влияет на выручку,
/// переживает сохранение и проверяется достижениями.
class SortState extends Equatable {
  /// Индекс в [kSorts].
  final int index;

  /// Продвижение к следующей ступени, 0..1.
  final double progress;

  const SortState({this.index = 0, this.progress = 0.0});

  Sort get current => kSorts[index.clamp(0, kSorts.length - 1)];

  String get name => current.name;

  /// Множитель к цене за литр.
  double get multiplier => current.multiplier;

  bool get isTop => index >= kSorts.length - 1;

  /// Продвинуть сорт на [delta] долей ступени, перенося через границы.
  ///
  /// Возвращает новое состояние; рост выше верхней ступени и падение ниже
  /// первой упираются в границы, а не уходят в никуда.
  SortState advance(double delta) {
    var i = index;
    var p = progress + delta;

    while (p >= 1.0 && i < kSorts.length - 1) {
      p -= 1.0;
      i += 1;
    }
    if (p >= 1.0) p = 1.0; // выше верхней ступени расти некуда

    while (p < 0.0 && i > 0) {
      p += 1.0;
      i -= 1;
    }
    if (p < 0.0) p = 0.0;

    return SortState(index: i, progress: p);
  }

  /// Сброс на ступень вниз — плата за продажу хорошему покупателю.
  SortState dropOneStep() =>
      SortState(index: index > 0 ? index - 1 : 0, progress: 0.0);

  SortState copyWith({int? index, double? progress}) => SortState(
        index: index ?? this.index,
        progress: progress ?? this.progress,
      );

  @override
  List<Object?> get props => [index, progress];

  @override
  bool get stringify => true;
}
