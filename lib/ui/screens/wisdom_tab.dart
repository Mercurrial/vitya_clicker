import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/game_content.dart';
import '../../content/wisdom_milestones.dart';
import '../../core/formatters.dart';
import '../../models/prestige_state.dart';
import '../../providers/game_provider.dart';
import '../theme/garage.dart';
import '../widgets/fill_bar.dart';
import '../widgets/panel.dart';

/// Вкладка «МУДРОСТЬ»: мудрость, похмелье и дорожка вех.
///
/// Похмелье объясняется ЗАРАНЕЕ, ещё до того как станет доступным, поэтому
/// вкладка видна с первого запуска. Это не вежливость: игры теряют игроков
/// ровно перед кнопкой престижа, потому что никто не понимает, что она
/// делает, — подсказка с превью даёт заметный прирост удержания.
///
/// Раньше мудрость и похмелье жили на вкладке «Витя», вперемешку со
/// статистикой и настройками. Вехам нужно место под целую дорожку, и всё,
/// что про мудрость, переехало сюда (docs/DECISIONS.md, «Интерфейс»).
class WisdomTab extends ConsumerWidget {
  const WisdomTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(gameProvider.select((s) => s.prestige));

    return ListView(
      padding: const EdgeInsets.fromLTRB(GS.s4, GS.s2, GS.s4, GS.s6),
      children: [
        _Summary(prestige: p),
        const SizedBox(height: GS.s3),
        _SleepPanel(prestige: p),
        const SizedBox(height: GS.s3),
        _MilestonesPanel(prestige: p),
      ],
    );
  }
}

/// «×2.5», а большое — суффиксом: «×182», «×1.5К».
String _times(double x) => x < 10 ? Fmt.mult(x) : '×${Fmt.short(x)}';

class _Summary extends StatelessWidget {
  final PrestigeState prestige;
  const _Summary({required this.prestige});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        children: [
          Text('МУДРОСТЬ', style: GType.label()),
          Text(
            '${prestige.wisdom}',
            style: GType.num(size: 36, weight: FontWeight.w700, color: GColors.amber),
          ),
          Text(
            // Вместе с вехами «всё ×N»: это то, во сколько раз быстрее идёт
            // заход. Вехи ступеней — в дорожке ниже.
            'всё производство ${_times(prestige.productionMultiplier)}',
            key: const Key('wisdom-multiplier'),
            style: GType.body(),
          ),
        ],
      ),
    );
  }
}

class _SleepPanel extends ConsumerWidget {
  final PrestigeState prestige;
  const _SleepPanel({required this.prestige});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = prestige;
    final pending = p.pendingWisdom;
    final progress = p.progressToNext;
    // Какие вехи откроет сон — ради них и ложатся.
    final opens = [
      for (final m in PrestigeState.milestonesFor(p.potentialWisdom))
        if (m.wisdom > p.wisdom) m,
    ];

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ПОХМЕЛЬЕ', style: GType.label()),
          const SizedBox(height: GS.s2),
          Text(
            pending > 0
                ? 'Витя проспится — и весь цех окажется сном. Останется тот '
                    'же гараж и та же банка на табурете, с которой всё '
                    'начиналось. Но руки помнят: мудрость никуда не денется, '
                    'и следующий заход пойдёт быстрее.'
                : 'Витя пока бодр. Когда нагонит достаточно, ляжет проспаться '
                    '— и нагнанное ему причудится. Кроме мудрости: она '
                    'остаётся навсегда и множит всё производство.',
            style: GType.body(),
          ),
          if (opens.isNotEmpty) ...[
            const SizedBox(height: GS.s2),
            Text(
              opens.length == 1
                  ? 'Проспится — откроется веха: ${milestoneText(opens.first.effect)}'
                  : 'Проспится — откроются вехи: ${milestoneText(opens.first.effect)} '
                      'и ещё ${opens.length - 1}',
              key: const Key('wisdom-opens'),
              style: GType.ui(size: 12, weight: FontWeight.w600, color: GColors.amber),
            ),
          ],
          const SizedBox(height: GS.s3),
          if (pending <= 0) ...[
            FillBar(value: progress, height: 6, color: GColors.copper),
            const SizedBox(height: GS.s2),
            Text(
              'До следующей мудрости: ${(progress * 100).toStringAsFixed(0)}%',
              style: GType.num(size: 11, color: GColors.textMid),
            ),
          ],
          const SizedBox(height: GS.s3),
          WideButton(
            key: const Key('wisdom-sleep'),
            label: pending > 0 ? 'ЛЕЧЬ ПРОСПАТЬСЯ · +$pending' : 'ЕЩЁ РАНО',
            enabled: pending > 0,
            onTap: () => _confirm(context, ref, pending),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref, int pending) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GColors.surface3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GR.card)),
        title: Text('Лечь проспаться?', style: GType.ui(size: 16, weight: FontWeight.w600)),
        content: Text(
          'Аппараты, улучшения и деньги окажутся сном. Витя проснётся при '
          'той же банке, с которой начинал.\n'
          'Мудрости станет больше на $pending — и это уже навсегда.',
          style: GType.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: GType.ui(size: 14, color: GColors.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Спать',
              style: GType.ui(size: 14, weight: FontWeight.w700, color: GColors.amber),
            ),
          ),
        ],
      ),
    );
    if (ok ?? false) ref.read(gameProvider.notifier).sleepItOff();
  }
}

/// Дорожка вех: взятые, следующая и те, что впереди.
///
/// Показана вся, а не только следующая: у всех один путь, и видеть, куда он
/// ведёт, — половина удовольствия. Следующая выделена и говорит, сколько до
/// неё осталось.
class _MilestonesPanel extends StatelessWidget {
  final PrestigeState prestige;
  const _MilestonesPanel({required this.prestige});

  @override
  Widget build(BuildContext context) {
    final wisdom = prestige.wisdom;
    final next = prestige.nextMilestone;
    final path = PrestigeState.pathOf();

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ВЕХИ', style: GType.label()),
          const SizedBox(height: GS.s1),
          Text(
            'Мудрость не тратится: веха открывается сама, как только мудрости '
            'хватает, и остаётся навсегда.',
            style: GType.body(),
          ),
          const SizedBox(height: GS.s2),
          Text(
            next == null
                ? 'Дорожка пройдена.'
                : 'Следующая — на ${next.wisdom} мудрости, ещё ${next.wisdom - wisdom}',
            key: const Key('wisdom-next'),
            style: GType.num(size: 12, weight: FontWeight.w700, color: GColors.textHi),
          ),
          const SizedBox(height: GS.s3),
          for (final (i, m) in path.indexed) ...[
            if (i > 0) const SizedBox(height: GS.s2),
            _MilestoneRow(
              key: Key('milestone-$i'),
              milestone: m,
              state: m.wisdom <= wisdom
                  ? _Stage.taken
                  : identical(m, next)
                      ? _Stage.next
                      : _Stage.ahead,
            ),
          ],
        ],
      ),
    );
  }
}

enum _Stage { taken, next, ahead }

class _MilestoneRow extends StatelessWidget {
  final WisdomMilestone milestone;
  final _Stage state;

  const _MilestoneRow({super.key, required this.milestone, required this.state});

  @override
  Widget build(BuildContext context) {
    final taken = state == _Stage.taken;
    final next = state == _Stage.next;
    return Semantics(
      label: '${milestone.wisdom} мудрости: ${milestoneText(milestone.effect)}, '
          '${taken ? 'взята' : next ? 'следующая' : 'впереди'}',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: taken ? GColors.amber : GColors.wellBg,
              border: Border.all(
                color: taken ? GColors.amber : (next ? GColors.copper : GColors.border),
                width: next ? 2 : 1,
              ),
            ),
            child: Text(
              '${milestone.wisdom}',
              style: GType.num(
                size: 12,
                weight: FontWeight.w700,
                color: taken ? GColors.onAmber : (next ? GColors.textHi : GColors.textLo),
              ),
            ),
          ),
          const SizedBox(width: GS.s3),
          Expanded(
            child: Text(
              milestoneText(milestone.effect),
              style: GType.ui(
                size: 13,
                weight: next ? FontWeight.w600 : FontWeight.w400,
                color: taken ? GColors.textHi : (next ? GColors.textHi : GColors.textLo),
              ),
            ),
          ),
          if (taken) Text('✓', style: GType.num(size: 14, weight: FontWeight.w700, color: GColors.amber)),
        ],
      ),
    );
  }
}
