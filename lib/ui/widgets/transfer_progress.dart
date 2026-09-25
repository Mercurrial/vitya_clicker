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
import '../../core/sfx.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/game_provider.dart';
import '../theme/garage.dart';

class TransferProgress extends ConsumerStatefulWidget {
  const TransferProgress({super.key});

  @override
  ConsumerState<TransferProgress> createState() => _TransferProgressState();
}

class _TransferProgressState extends ConsumerState<TransferProgress> {
  String? _note;

  // Буфер обмена в браузере — не гарантия, а просьба. Встроенные браузеры
  // мессенджеров, вкладка без фокуса, запрет в настройках — и браузер
  // отказывает. Раньше отказ улетал необработанным исключением: игрок жал
  // «СКОПИРОВАТЬ», не видел ничего и уходил в уверенности, что код у него.
  // Поэтому у обеих кнопок есть ручной путь: код показывается целиком, а
  // вставить его можно в поле.

  Future<void> _copy() async {
    final code = ref.read(gameProvider.notifier).exportCode();
    try {
      await Clipboard.setData(ClipboardData(text: code));
    } catch (_) {
      if (mounted) await _showCode(code);
      return;
    }
    if (!mounted) return;
    setState(() => _note = 'Код скопирован. Отправь его себе в сообщения.');
  }

  Future<void> _paste() async {
    final confirmed = await _confirmOverwrite();
    if (!confirmed || !mounted) return;

    String? code;
    try {
      code = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {
      code = null;
    }
    // Пустой буфер — то же, что недоступный: код, скорее всего, в другом
    // приложении, и его проще вставить руками, чем читать «это не код».
    if (code == null || code.trim().isEmpty) {
      if (!mounted) return;
      code = await _askForCode();
      if (code == null || !mounted) return;
    }

    final error = await ref.read(gameProvider.notifier).importCode(code);
    if (!mounted) return;
    setState(() {
      // Объяснения живут рядом с самим форматом кода — здесь их не дублируем.
      _note = error == null
          ? 'Прогресс принят.'
          : SaveCodeResult.failed(error).message;
    });
  }

  /// Код целиком — чтобы скопировать руками, когда браузер не дал сам.
  Future<void> _showCode(String code) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: GColors.surface1,
          title: Text('Скопируй вручную',
              style: GType.ui(size: 17, weight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Браузер не дал скопировать сам. Выдели код целиком и отправь '
                'себе в сообщения.',
                style: GType.body(),
              ),
              const SizedBox(height: GS.s3),
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                padding: const EdgeInsets.all(GS.s2),
                decoration: BoxDecoration(
                  color: GColors.wellBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GColors.border),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    code,
                    style: GType.num(size: 11, color: GColors.textMid),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Готово', style: GType.body()),
            ),
          ],
        ),
      );

  /// Поле для кода — когда прочитать буфер браузер не дал или он пуст.
  /// `null` — игрок передумал.
  Future<String?> _askForCode() => showDialog<String>(
        context: context,
        builder: (context) => const _CodeDialog(),
      );

  /// Нажатие кнопки: отдача — через общий фасад, чтобы выключатель вибрации
  /// в настройках действовал и здесь.
  void _tap(Future<void> Function() action) {
    ref.read(feedbackProvider).buzz(Buzz.select);
    action();
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
              Expanded(
                child: _Action(label: 'СКОПИРОВАТЬ', onTap: () => _tap(_copy)),
              ),
              const SizedBox(width: GS.s2),
              Expanded(
                child: _Action(
                  label: 'ВСТАВИТЬ',
                  onTap: () => _tap(_paste),
                  quiet: true,
                ),
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
      onTap: onTap,
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

/// Диалог с полем для кода.
///
/// Отдельный виджет, а не `TextEditingController` в методе экрана: диалог
/// ещё доигрывает анимацию закрытия, когда ответ уже получен, и контроллер,
/// уничтоженный сразу после ответа, ронял поле посреди этой анимации.
class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GColors.surface1,
      title: Text('Вставь код', style: GType.ui(size: 17, weight: FontWeight.w600)),
      content: TextField(
        controller: _field,
        autofocus: true,
        maxLines: 4,
        minLines: 2,
        style: GType.num(size: 11, color: GColors.textHi),
        decoration: InputDecoration(
          hintText: '$kSaveCodePrefix…',
          hintStyle: GType.num(size: 11, color: GColors.textLo),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Отмена', style: GType.body()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _field.text),
          child: Text(
            'Принять',
            style: GType.ui(size: 14, weight: FontWeight.w600, color: GColors.amber),
          ),
        ),
      ],
    );
  }
}
