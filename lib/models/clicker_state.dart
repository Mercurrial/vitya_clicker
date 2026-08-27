import 'package:equatable/equatable.dart';

/// Ручной труд Вити.
class ClickerState extends Equatable {
  /// Базовые миллилитры за одно нажатие (до множителей).
  /// Держит только самое начало — дальше отдача считается от производства.
  final double baseTapPower;

  /// Сколько раз всего нажали — для достижений и статистики.
  final int totalTaps;

  const ClickerState({this.baseTapPower = 5.0, this.totalTaps = 0});

  ClickerState copyWith({double? baseTapPower, int? totalTaps}) => ClickerState(
        baseTapPower: baseTapPower ?? this.baseTapPower,
        totalTaps: totalTaps ?? this.totalTaps,
      );

  @override
  List<Object?> get props => [baseTapPower, totalTaps];

  @override
  bool get stringify => true;
}
