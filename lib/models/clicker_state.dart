import 'package:equatable/equatable.dart';

import '../content/balance.dart';

/// Ручной труд Вити.
class ClickerState extends Equatable {
  /// Сколько раз всего нажали — для достижений и статистики.
  final int totalTaps;

  const ClickerState({this.totalTaps = 0});

  /// Базовые миллилитры за одно нажатие (до множителей).
  ///
  /// Держит только самое начало — дальше отдача считается от производства.
  /// Число из баланса, а не из состояния: это настройка экономики, и в сейв
  /// ей попадать нельзя, иначе правка перестанет действовать на тех, кто уже
  /// играет.
  double get baseTapPower => Balance.current.baseTapMl;

  ClickerState copyWith({int? totalTaps}) =>
      ClickerState(totalTaps: totalTaps ?? this.totalTaps);

  @override
  List<Object?> get props => [totalTaps];

  @override
  bool get stringify => true;
}
