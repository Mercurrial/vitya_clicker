import '../models/game_state.dart';

/// Что достижение открывает, кроме множителя.
///
/// Автоматизация в серьёзных инкрементальных играх не выдаётся, а
/// **зарабатывается** — и это же лечит «игра неудобная»: неудобство перестаёт
/// быть недоделкой и становится содержанием, из которого игрок выкупается.
enum AchievementPerk {
  /// Ничего сверх множителя.
  none,

  /// Бак продаётся сам, как только наполнится.
  autoSell,

  /// Появляются кнопки покупки ×10 / ×100 / МАКС.
  bulkBuy,
}

/// Одно достижение.
///
/// Условие — чистая функция состояния: его можно проверить в любой момент,
/// оно одинаково считается на любом устройстве и не требует ловить события.
class Achievement {
  final String id;
  final String name;

  /// Подсказка, что нужно сделать. Служит встроенным гидом: игрок всегда
  /// видит ближайшую осмысленную цель.
  final String hint;

  final bool Function(GameState) check;
  final AchievementPerk perk;

  const Achievement({
    required this.id,
    required this.name,
    required this.hint,
    required this.check,
    this.perk = AchievementPerk.none,
  });
}

/// Ряд достижений. Заполненный ряд даёт отдельный множитель — именно это
/// превращает список галочек в систему, ради которой доигрывают ряд до конца.
class AchievementRow {
  final String title;
  final List<Achievement> items;

  const AchievementRow({required this.title, required this.items});
}
