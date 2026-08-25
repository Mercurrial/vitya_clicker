import 'package:equatable/equatable.dart';
import 'generator.dart';

class GeneratorsState extends Equatable {
  final List<Generator> items;

  const GeneratorsState({
    this.items = const [],
  });

  GeneratorsState copyWith({
    List<Generator>? items,
  }) {
    return GeneratorsState(
      items: items != null ? List<Generator>.unmodifiable(items) : this.items,
    );
  }

  @override
  List<Object?> get props => [items];

  @override
  bool get stringify => true;
}
