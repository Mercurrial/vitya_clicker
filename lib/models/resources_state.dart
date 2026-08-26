import 'package:equatable/equatable.dart';

/// Что стоит в гараже прямо сейчас.
class ResourcesState extends Equatable {
  /// Литры самогона — основная валюта.
  final double litres;

  const ResourcesState({this.litres = 0.0});

  ResourcesState copyWith({double? litres}) =>
      ResourcesState(litres: litres ?? this.litres);

  @override
  List<Object?> get props => [litres];

  @override
  bool get stringify => true;
}
