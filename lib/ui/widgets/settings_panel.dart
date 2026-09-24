/// Настройки: звук и вибрация.
///
/// Две галочки, и обе про одно — про право играть молча. В игру про самогон
/// играют в транспорте и на работе; звук по умолчанию включён, но выключить
/// его должно быть проще, чем найти.
///
/// Переключатель даёт отдачу СОБОЙ: включил звук — сразу слышно, включил
/// вибрацию — сразу чувствуется. Иначе проверить, что настройка подействовала,
/// можно только вернувшись в игру, а это уже не настройка, а лотерея.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sfx.dart';
import '../../providers/feedback_provider.dart';
import '../theme/garage.dart';

class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sound = ref.watch(soundEnabledProvider);
    final haptics = ref.watch(hapticsEnabledProvider);

    return Container(
      padding: const EdgeInsets.all(GS.s4),
      decoration: BoxDecoration(
        color: GColors.surface1,
        borderRadius: BorderRadius.circular(GR.card),
        border: Border.all(color: GColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('НАСТРОЙКИ', style: GType.label()),
          const SizedBox(height: GS.s3),
          _Switch(
            label: 'Звук',
            note: 'удары, покупки, перегрев',
            on: sound,
            onChanged: (on) {
              ref.read(soundEnabledProvider.notifier).set(on);
              // Пример нового состояния: включили — услышали. Выключили —
              // тишина, и это тоже ответ.
              if (on) ref.read(feedbackProvider).play(Sfx.buy);
            },
          ),
          const SizedBox(height: GS.s3),
          _Switch(
            label: 'Вибрация',
            note: 'отдача на нажатия',
            on: haptics,
            onChanged: (on) {
              ref.read(hapticsEnabledProvider.notifier).set(on);
              if (on) ref.read(feedbackProvider).buzz(Buzz.medium);
            },
          ),
        ],
      ),
    );
  }
}

/// Переключатель. Свой, а не `Switch` из Material: тот приносит с собой чужую
/// палитру и скруглениями выбивается из гаража.
class _Switch extends StatelessWidget {
  final String label;
  final String note;
  final bool on;
  final ValueChanged<bool> onChanged;

  const _Switch({
    required this.label,
    required this.note,
    required this.on,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!on),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GType.ui(size: 14, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(note, style: GType.num(size: 10, color: GColors.textMid)),
              ],
            ),
          ),
          const SizedBox(width: GS.s3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 46,
            height: 26,
            padding: const EdgeInsets.all(3),
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: on ? GColors.copper : GColors.wellBg,
              borderRadius: BorderRadius.circular(GR.pill),
              border: Border.all(color: on ? GColors.amber : GColors.border),
            ),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: on ? GColors.textHi : GColors.textLo,
                borderRadius: BorderRadius.circular(GR.pill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
