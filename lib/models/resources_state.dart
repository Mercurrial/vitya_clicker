import 'package:equatable/equatable.dart';

/// Что стоит в гараже прямо сейчас.
class ResourcesState extends Equatable {
  /// Самогон в МИЛЛИЛИТРАХ. Базовая единица намеренно мелкая: начало игры
  /// должно ощущаться как «капает по чуть-чуть», а не сразу литрами.
  final double ml;

  const ResourcesState({this.ml = 0.0});

  ResourcesState copyWith({double? ml}) => ResourcesState(ml: ml ?? this.ml);

  @override
  List<Object?> get props => [ml];

  @override
  bool get stringify => true;
}
