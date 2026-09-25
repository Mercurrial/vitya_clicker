import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/game_provider.dart';
import '../theme/garage.dart';
import '../widgets/fill_bar.dart';
import '../widgets/panel.dart';
import '../widgets/settings_panel.dart';
import '../widgets/stats_panel.dart';
import '../widgets/transfer_progress.dart';

/// Вкладка «Витя»: похмелье, статистика и сброс.
///
/// Похмелье объясняется ЗАРАНЕЕ, ещё до того как станет доступным. Это не
/// вежливость: игры теряют игроков ровно перед кнопкой престижа, потому что
/// никто не понимает, что она делает, — подсказка с превью даёт заметный
/// прирост удержания.
class VityaTab extends ConsumerWidget {
  const VityaTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(gameProvider.select((s) => s.prestige));
    final pending = p.pendingWisdom;
    final progress = p.progressToNext;

    return ListView(
      padding: const EdgeInsets.fromLTRB(GS.s4, GS.s2, GS.s4, GS.s6),
      children: [
        Panel(
          child: Column(
            children: [
              Text('МУДРОСТЬ', style: GType.label()),
              Text(
                '${p.wisdom}',
                style: GType.num(
                  size: 36,
                  weight: FontWeight.w700,
                  color: GColors.amber,
                ),
              ),
              Text(
                '+${((p.globalMultiplier - 1) * 100).toStringAsFixed(0)}% ко всему производству',
                style: GType.body(),
              ),
            ],
          ),
        ),
        const SizedBox(height: GS.s3),
        Panel(
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
                label: pending > 0 ? 'ЛЕЧЬ ПРОСПАТЬСЯ · +$pending' : 'ЕЩЁ РАНО',
                enabled: pending > 0,
                onTap: () => _confirmPrestige(context, ref, pending),
              ),
            ],
          ),
        ),
        const SizedBox(height: GS.s3),
        // Статистика — под похмельем, а не над ним: на вкладку заходят
        // проспаться, и кнопка не должна уезжать под двадцать строк цифр.
        const StatsPanel(),
        const SizedBox(height: GS.s3),
        const SettingsPanel(),
        const SizedBox(height: GS.s3),
        const TransferProgress(),
        const SizedBox(height: GS.s6),
        WideButton(
          label: 'НАЧАТЬ ЗАНОВО',
          enabled: true,
          danger: true,
          onTap: () => _confirmReset(context, ref),
        ),
        const SizedBox(height: GS.s2),
        Text(
          'Сброс стирает всё, включая мудрость.',
          textAlign: TextAlign.center,
          style: GType.num(size: 11, color: GColors.textLo),
        ),
      ],
    );
  }

  Future<void> _confirmPrestige(
      BuildContext context, WidgetRef ref, int pending) async {
    final ok = await _ask(
      context,
      title: 'Лечь проспаться?',
      body: 'Аппараты, улучшения и деньги окажутся сном. Витя проснётся при '
          'той же банке, с которой начинал.\n'
          'Мудрости станет больше на $pending — и это уже навсегда.',
      confirm: 'Спать',
    );
    if (ok) ref.read(gameProvider.notifier).sleepItOff();
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await _ask(
      context,
      title: 'Начать заново?',
      body: 'Сотрётся весь прогресс, включая мудрость и историю. '
          'Отменить это будет нельзя.',
      confirm: 'Стереть',
      danger: true,
    );
    if (ok) await ref.read(gameProvider.notifier).hardReset();
  }

  Future<bool> _ask(
    BuildContext context, {
    required String title,
    required String body,
    required String confirm,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GColors.surface3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GR.card),
        ),
        title: Text(title, style: GType.ui(size: 16, weight: FontWeight.w600)),
        content: Text(body, style: GType.body()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена',
                style: GType.ui(size: 14, color: GColors.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirm,
              style: GType.ui(
                size: 14,
                weight: FontWeight.w700,
                color: danger ? GColors.hot : GColors.amber,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

