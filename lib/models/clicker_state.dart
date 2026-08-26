import 'package:equatable/equatable.dart';

/// Ручной труд Вити.
class ClickerState extends Equatable {
  /// Базовые литры за одно нажатие (до множителей).
  final double baseTapPower;

  /// Сколько раз всего нажали — для достижений и статистики.
  final int totalTaps;

  const ClickerState({this.baseTapPower = 1.0, this.totalTaps = 0});

  ClickerState copyWith({double? baseTapPower, int? totalTaps}) => ClickerState(
        baseTapPower: baseTapPower ?? this.baseTapPower,
        totalTaps: totalTaps ?? this.totalTaps,
      );

  @override
  List<Object?> get props => [baseTapPower, totalTaps];

  @override
  bool get stringify => true;
}
