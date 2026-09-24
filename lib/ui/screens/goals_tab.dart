import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/achievements.dart';
import '../../core/formatters.dart';
import '../../core/sfx.dart';
import '../../models/achievement.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/game_provider.dart';
import '../pixel/goal_icons.dart';
import '../pixel/pixel_sprite.dart';
import '../theme/garage.dart';
import '../widgets/panel.dart';

/// Какая цель раскрыта в карточке сверху. `null` — ближайшая невзятая.
final _selectedGoalProvider = StateProvider<String?>((ref) => null);

/// Вкладка «Цели» — достижения сеткой рядов.
///
/// Открытое достижение множит производство, а **полностью закрытый ряд — ещё
/// раз и заметно сильнее**. Из-за этого ряд хочется добить, и список галочек
/// превращается в систему прогресса.
///
/// Сверху — карточка цели. По умолчанию в ней ближайшая невзятая: вкладка
/// работает гидом «что делать дальше», и открывать её имеет смысл, даже когда
/// ничего не менялось. Касание ячейки показывает в карточке её.
///
/// Прошлая версия показывала в ячейках одни значки, а название и условие —
/// во всплывающей подсказке по наведению мыши. На телефоне мыши нет, и цели
/// оставались ребусом из двадцати картинок.
class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ach = ref.watch(gameProvider.select((s) => s.achievements));
    final selectedId = ref.watch(_selectedGoalProvider);

    final next = kAllAchievements.where((a) => !ach.unlocked.contains(a.id)).firstOrNull;
    final shown = kAllAchievements.where((a) => a.id == selectedId).firstOrNull ?? next;

    return ListView(
      padding: const EdgeInsets.fromLTRB(GS.s3, GS.s1, GS.s3, GS.s6),
      children: [
        _Summary(
          multiplier: ach.multiplier,
          count: ach.count,
          rows: ach.completedRows,
        ),
        const SizedBox(height: GS.s2),
        if (shown != null)
          _GoalCard(
            goal: shown,
            done: ach.unlocked.contains(shown.id),
            isNext: shown == next && selectedId == null,
          ),
        const SizedBox(height: GS.s3),
        for (final row in kAchievementRows) ...[
          _AchievementRowView(
            row: row,
            unlocked: ach.unlocked,
            selected: shown?.id,
          ),
          const SizedBox(height: GS.s3),
        ],
      ],
    );
  }
}

/// Итог одной строкой: сколько взято и во сколько это множит.
class _Summary extends StatelessWidget {
  final double multiplier;
  final int count;
  final int rows;

  const _Summary({required this.multiplier, required this.count, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ЦЕЛИ МНОЖАТ ВСЁ ПРОИЗВОДСТВО', style: GType.label()),
                const SizedBox(height: 4),
                Text(
                  'взято $count из ${kAllAchievements.length} · '
                  'рядов $rows из ${kAchievementRows.length}',
                  style: GType.num(size: 11, color: GColors.textMid),
                ),
              ],
            ),
          ),
          Text(
            Fmt.mult(multiplier),
            style: GType.num(size: 26, weight: FontWeight.w700, color: GColors.amber),
          ),
        ],
      ),
    );
  }
}

/// Карточка одной цели: название, условие и что за неё дают.
class _GoalCard extends StatelessWidget {
  final Achievement goal;
  final bool done;
  final bool isNext;

  const _GoalCard({required this.goal, required this.done, required this.isNext});

  @override
  Widget build(BuildContext context) {
    final perk = switch (goal.perk) {
      AchievementPerk.autoSell => 'открывает автопродажу: полный бак сдаётся сам',
      AchievementPerk.bulkBuy => 'открывает покупку пачками: ×10, ×100, МАКС',
      AchievementPerk.none => null,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(GS.s3),
      decoration: BoxDecoration(
        color: done ? const Color(0x1F8FBF4D) : GColors.surface2,
        borderRadius: BorderRadius.circular(GR.button),
        border: Border.all(color: done ? const Color(0x668FBF4D) : const Color(0x55E8A33D)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x40000000),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Opacity(
              opacity: done ? 1 : 0.55,
              child: PixelImage(sprite: goalIcon(goal.id), size: 32),
            ),
          ),
          const SizedBox(width: GS.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done ? 'ВЗЯТО' : (isNext ? 'СЛЕДУЮЩАЯ ЦЕЛЬ' : 'ЦЕЛЬ'),
                  style: GType.label().copyWith(
                    fontSize: 9,
                    color: done ? GColors.green : GColors.amber,
                  ),
                ),
                const SizedBox(height: 2),
                Text(goal.name, style: GType.ui(size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(goal.hint, style: GType.ui(size: 12, color: GColors.textMid, height: 1.3)),
                const SizedBox(height: 4),
                Text(
                  perk == null
                      ? '${Fmt.mult(kAchievementMultiplier)} ко всему производству'
                      : '${Fmt.mult(kAchievementMultiplier)} и $perk',
                  style: GType.ui(size: 11, weight: FontWeight.w600, color: GColors.copper, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementRowView extends StatelessWidget {
  final AchievementRow row;
  final Set<String> unlocked;
  final String? selected;

  const _AchievementRowView({
    required this.row,
    required this.unlocked,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final done = row.items.where((a) => unlocked.contains(a.id)).length;
    final closed = done == row.items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(row.title.toUpperCase(), style: GType.label()),
            const SizedBox(width: GS.s2),
            Text(
              '$done/${row.items.length}',
              style: GType.num(size: 10, color: GColors.textLo),
            ),
            const Spacer(),
            Text(
              closed
                  ? 'ряд закрыт · ${Fmt.mult(kRowMultiplier)}'
                  : 'весь ряд — ещё ${Fmt.mult(kRowMultiplier)}',
              style: GType.num(
                size: 10,
                weight: closed ? FontWeight.w700 : FontWeight.w400,
                color: closed ? GColors.green : GColors.textLo,
              ),
            ),
          ],
        ),
        const SizedBox(height: GS.s2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final a in row.items) ...[
              Expanded(
                child: _AchievementCell(
                  a: a,
                  done: unlocked.contains(a.id),
                  selected: a.id == selected,
                ),
              ),
              if (a != row.items.last) const SizedBox(width: GS.s2),
            ],
          ],
        ),
      ],
    );
  }
}

class _AchievementCell extends ConsumerWidget {
  final Achievement a;
  final bool done;
  final bool selected;

  const _AchievementCell({required this.a, required this.done, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(feedbackProvider).buzz(Buzz.select);
        ref.read(_selectedGoalProvider.notifier).state = a.id;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 86,
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
        decoration: BoxDecoration(
          color: done ? const Color(0xFF3A2A1B) : const Color(0x33000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? GColors.lamp
                : (done ? const Color(0x99E8A33D) : GColors.hairline),
            width: selected ? 2 : 1,
          ),
          boxShadow: done ? const [BoxShadow(color: Color(0x33E8A33D), blurRadius: 10)] : null,
        ),
        child: Column(
          children: [
            // Незакрытая цель показывается тем же значком, но приглушённым:
            // силуэт видно, поэтому понятно, про что она, а «уже взято» и
            // «ещё нет» различаются мгновенно.
            Opacity(
              opacity: done ? 1.0 : 0.3,
              child: PixelImage(sprite: goalIcon(a.id), size: 30),
            ),
            const Spacer(),
            Text(
              a.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GType.ui(
                size: 9.5,
                weight: FontWeight.w600,
                color: done ? GColors.textHi : GColors.textLo,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
