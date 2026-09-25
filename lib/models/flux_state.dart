import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../content/balance.dart';

/// Поток времени: то, что копится, пока игра не шла, и тратится ускорением.
///
/// Хранятся только факты: сколько потока накоплено (ресурс, как деньги) и
/// сколько уровней двух линеек куплено. Скорость начисления, размер копилки
/// и цены вычисляются из уровней по текущему балансу — иначе правка чисел
/// потока не дошла бы до тех, кто уже играет.
///
/// Похмелье поток не трогает: это время игрока, а не имущество гаража.
class FluxState extends Equatable {
  /// Накоплено, секунд потока.
  final double seconds;

  /// Куплено уровней «Крепкого сна» — по +1 минуте потока за час AFK.
  final int rateLevel;

  /// Куплено уровней «Долгого сна» — по +1 часу копилки.
  final int bankLevel;

  const FluxState({this.seconds = 0, this.rateLevel = 0, this.bankLevel = 0});

  static Balance get _b => Balance.current;

  /// Минут потока за час AFK.
  double get minutesPerHour =>
      math.min(_b.fluxMinutesPerHour + rateLevel, _b.fluxMaxMinutesPerHour);

  /// Сколько потока помещается в копилку, секунд.
  double get bankSeconds =>
      math.min(_b.fluxBankHours + bankLevel, _b.fluxMaxBankHours) * 3600;

  bool get isBankFull => seconds >= bankSeconds - 1e-6;

  /// Поток уже был: копится или хоть что-то куплено. До этого вкладка
  /// потока не показывается — пустая копилка новичку ничего не говорит.
  bool get opened => seconds > 0 || rateLevel > 0 || bankLevel > 0;

  /// Скорость дошла до предела — больше часа в час нельзя.
  bool get rateMaxed => minutesPerHour >= _b.fluxMaxMinutesPerHour;

  bool get bankMaxed => bankSeconds >= _b.fluxMaxBankHours * 3600;

  /// Цена следующего уровня «Крепкого сна», секунд потока.
  double get rateCostSeconds =>
      (_b.fluxRateCostBase + _b.fluxRateCostStep * rateLevel) * 60;

  /// Цена следующего уровня «Долгого сна», секунд потока.
  double get bankCostSeconds =>
      (_b.fluxBankCostBase + _b.fluxBankCostStep * bankLevel) * 60;

  bool get canBuyRate => !rateMaxed && seconds >= rateCostSeconds;
  bool get canBuyBank => !bankMaxed && seconds >= bankCostSeconds;

  /// Сколько потока принесёт отсутствие [awaySeconds] — без учёта копилки.
  double earnedFor(double awaySeconds) => awaySeconds * minutesPerHour / 60;

  FluxState copyWith({double? seconds, int? rateLevel, int? bankLevel}) => FluxState(
        seconds: seconds ?? this.seconds,
        rateLevel: rateLevel ?? this.rateLevel,
        bankLevel: bankLevel ?? this.bankLevel,
      );

  @override
  List<Object?> get props => [seconds, rateLevel, bankLevel];
}
