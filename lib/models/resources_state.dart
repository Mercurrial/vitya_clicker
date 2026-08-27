import 'package:equatable/equatable.dart';

/// Что есть у Вити прямо сейчас.
///
/// Две валюты намеренно разделены: самогон — товар, рубли — деньги. Покупать
/// оборудование за самогон было бы всё равно что платить за бидон бензином;
/// именно из этого разделения растут рынок, цена и решение «когда продавать».
class ResourcesState extends Equatable {
  /// Самогон в баке, в МИЛЛИЛИТРАХ. Единица мелкая намеренно: начало игры
  /// должно ощущаться как «капает по чуть-чуть», а не сразу литрами.
  final double ml;

  /// Рубли — на них покупается всё.
  final double money;

  const ResourcesState({this.ml = 0.0, this.money = 0.0});

  ResourcesState copyWith({double? ml, double? money}) => ResourcesState(
        ml: ml ?? this.ml,
        money: money ?? this.money,
      );

  @override
  List<Object?> get props => [ml, money];

  @override
  bool get stringify => true;
}
