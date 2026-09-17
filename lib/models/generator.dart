import 'package:equatable/equatable.dart';

/// Аппарат: сколько стоит, сколько гонит, сколько их у Вити.
///
/// Скорости удорожания здесь НЕТ намеренно. Она одна на всю игру и живёт в
/// `Balance` — это главный тормоз экономики, и настраивать его надо в одном
/// месте, а не в тринадцати. Пока поле стояло у каждого аппарата, правка
/// требовала тринадцати одинаковых изменений, а симулятор не мог перебрать
/// варианты, не переписав контент.
class Generator extends Equatable {
  final String id;
  final String name;
  final double baseCost;
  final double baseProduction;
  final int ownedCount;

  const Generator({
    required this.id,
    required this.name,
    required this.baseCost,
    required this.baseProduction,
    this.ownedCount = 0,
  });

  Generator copyWith({
    String? id,
    String? name,
    double? baseCost,
    double? baseProduction,
    int? ownedCount,
  }) {
    return Generator(
      id: id ?? this.id,
      name: name ?? this.name,
      baseCost: baseCost ?? this.baseCost,
      baseProduction: baseProduction ?? this.baseProduction,
      ownedCount: ownedCount ?? this.ownedCount,
    );
  }

  @override
  List<Object?> get props => [id, name, baseCost, baseProduction, ownedCount];

  @override
  bool get stringify => true;
}
