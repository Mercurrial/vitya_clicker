import 'package:equatable/equatable.dart';

class ResourcesState extends Equatable {
  final double gold;

  const ResourcesState({
    this.gold = 0.0,
  });

  ResourcesState copyWith({
    double? gold,
  }) {
    return ResourcesState(
      gold: gold ?? this.gold,
    );
  }

  @override
  List<Object?> get props => [gold];

  @override
  bool get stringify => true;
}
