import 'package:equatable/equatable.dart';

/// Ручной труд Вити.
class ClickerState extends Equatable {
  /// Сколько раз всего нажали — для достижений и статистики.
  final int totalTaps;

  const ClickerState({this.totalTaps = 0});

  ClickerState copyWith({int? totalTaps}) =>
      ClickerState(totalTaps: totalTaps ?? this.totalTaps);

  @override
  List<Object?> get props => [totalTaps];

  @override
  bool get stringify => true;
}
