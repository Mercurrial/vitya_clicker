import 'package:equatable/equatable.dart';

class ClickerState extends Equatable {
  final double baseClickPower;
  final int totalClicks;

  const ClickerState({
    this.baseClickPower = 1.0,
    this.totalClicks = 0,
  });

  ClickerState copyWith({
    double? baseClickPower,
    int? totalClicks,
  }) {
    return ClickerState(
      baseClickPower: baseClickPower ?? this.baseClickPower,
      totalClicks: totalClicks ?? this.totalClicks,
    );
  }

  @override
  List<Object?> get props => [baseClickPower, totalClicks];

  @override
  bool get stringify => true;
}
