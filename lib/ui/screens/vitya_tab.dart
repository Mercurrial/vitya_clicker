import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/game_provider.dart';
import '../theme/garage.dart';
import '../widgets/panel.dart';
import '../widgets/settings_panel.dart';
import '../widgets/stats_panel.dart';
import '../widgets/transfer_progress.dart';

/// Вкладка «Витя»: статистика, настройки, перенос и сброс.
///
/// Мудрость и похмелье отсюда переехали на свою вкладку вместе с дорожкой
/// вех (см. WisdomTab): здесь остаётся то, что про игрока и игру целиком.
class VityaTab extends ConsumerWidget {
  const VityaTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(GS.s4, GS.s2, GS.s4, GS.s6),
      children: [
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

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GColors.surface3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GR.card),
        ),
        title: Text('Начать заново?', style: GType.ui(size: 16, weight: FontWeight.w600)),
        content: Text(
          'Сотрётся весь прогресс, включая мудрость и историю. '
          'Отменить это будет нельзя.',
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
              'Стереть',
              style: GType.ui(size: 14, weight: FontWeight.w700, color: GColors.hot),
            ),
          ),
        ],
      ),
    );
    if (ok ?? false) await ref.read(gameProvider.notifier).hardReset();
  }
}
