/// Перенос прогресса: выгрузить кодом и принять кодом.
///
/// Нужен потому, что на iPhone игра живёт как сайт, а сейв — в хранилище
/// браузера. Хранилище браузера теряется: при очистке данных сайта, при смене
/// телефона, иногда само. Код — это запасной выход, и он должен быть на виду
/// ДО того, как понадобится, а не после.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/save_code.dart';
import '../../providers/game_provider.dart';
import '../theme/garage.dart';

class TransferProgress extends ConsumerStatefulWidget {
  const TransferProgress({super.key});

  @override
  ConsumerState<TransferProgress> createState() => _TransferProgressState();
}

class _TransferProgressState extends ConsumerState<TransferProgress> {
  String? _note;

  Future<void> _copy() async {
    final code = ref.read(gameProvider.notifier).exportCode();
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _note = 'Код скопирован. Отправь его себе в сообщения.');
  }

  Future<void> _paste() async {
    final confirmed = await _confirmOverwrite();
    if (!confirmed || !mounted) return;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final error = await ref.read(gameProvider.notifier).importCode(data?.text);
    if (!mounted) return;
    setState(() {
      // Объяснения живут рядом с самим форматом кода — здесь их не дублируем.
      _note = error == null
          ? 'Прогресс принят.'
          : SaveCodeResult.failed(error).message;
    });
  }

  /// Приём кода стирает текущий гараж. Спрашиваем прямо: это единственное
  /// место в игре, где одно нажатие может обнулить чужой прогресс.
  Future<bool> _confirmOverwrite() async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GColors.surface1,
        title: Text('Заменить прогресс?',
            style: GType.ui(size: 17, weight: FontWeight.w600)),
        content: Text(
          'Текущий гараж будет стёрт и заменён тем, что в коде. '
          'Если нынешний прогресс дорог — сперва скопируй его.',
          style: GType.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена', style: GType.body()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Заменить',
              style: GType.ui(size: 14, weight: FontWeight.w600, color: GColors.hot),
            ),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  @override
  Widget build(BuildContext context) {
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
          Text('ПЕРЕНОС ПРОГРЕССА', style: GType.label()),
          const SizedBox(height: GS.s2),
          Text(
            'Гараж хранится на этом устройстве. Чтобы не потерять его при '
            'смене телефона или очистке браузера — скопируй код и отправь '
            'себе в сообщения.',
            style: GType.body(),
          ),
          const SizedBox(height: GS.s3),
          Row(
            children: [
              Expanded(child: _Action(label: 'СКОПИРОВАТЬ', onTap: _copy)),
              const SizedBox(width: GS.s2),
              Expanded(
                child: _Action(label: 'ВСТАВИТЬ', onTap: _paste, quiet: true),
              ),
            ],
          ),
          if (_note != null) ...[
            const SizedBox(height: GS.s2),
            Text(_note!, style: GType.num(size: 11, color: GColors.textMid)),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool quiet;

  const _Action({required this.label, required this.onTap, this.quiet = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: quiet ? GColors.wellBg : GColors.copper,
          borderRadius: BorderRadius.circular(GR.pill),
          border: quiet ? Border.all(color: GColors.border) : null,
        ),
        child: Text(
          label,
          style: GType.ui(
            size: 12,
            weight: FontWeight.w700,
            color: quiet ? GColors.textMid : GColors.textHi,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
