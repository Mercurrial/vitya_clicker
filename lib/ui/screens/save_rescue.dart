/// Сейв, который эта версия игры не читает.
///
/// Раньше и битый сейв, и сейв новой версии игра молча меняла на пустой
/// гараж, а через 20 секунд автосейв писал его поверх — прогресс пропадал
/// без следа и без слова. Самый вероятный путь туда — iPhone: игра с экрана
/// «Домой» открывается закэшированной старой сборкой и видит сейв «из
/// будущего».
///
/// Три экрана, по одному на случай:
///
/// * [SaveFromFutureScreen] — сейв записан новой версией. Он цел, и эта
///   версия его не тронет: вместо игры — просьба обновиться.
/// * [showBrokenSaveNotice] — сейв испорчен. Гараж начинается заново, а
///   строка отложена отдельно, и её можно скопировать разработчику.
/// * [offerRescuedGarage] — отложенная копия теперь читается: вернуть?
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/page_reload.dart';
import '../../models/game_state.dart';
import '../theme/garage.dart';

/// Вместо игры, когда сейв записан более новой версией.
///
/// Именно вместо, а не поверх гаража: в старой версии играть нельзя вовсе,
/// любая её запись затёрла бы новый прогресс. Гаража нет — нет и соблазна
/// «поиграть пока так».
class SaveFromFutureScreen extends StatelessWidget {
  /// Есть ли у страницы кнопка перезагрузки. По умолчанию — только в вебе;
  /// тесты подменяют, чтобы проверить вёрстку с кнопкой.
  final bool canReload;

  /// Что делает кнопка. По умолчанию — перезагружает вкладку.
  final VoidCallback onReload;

  const SaveFromFutureScreen({
    super.key,
    this.canReload = canReloadPage,
    this.onReload = reloadPage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GColors.bg,
      body: SafeArea(
        child: Center(
          // Прокрутка — на случай крупного шрифта в системе: кнопка не должна
          // уехать за край экрана, а другой дороги дальше у игрока нет.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GS.s6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('ГАРАЖ ЦЕЛ', style: GType.label()),
                  const SizedBox(height: GS.s2),
                  Text(
                    'Сейв записан более новой версией игры',
                    style: GType.ui(size: 22, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: GS.s4),
                  Text(
                    'Эта версия старее и новый сейв не прочитает, поэтому '
                    'ничего в нём не трогает и ничего не пишет.',
                    style: GType.body(),
                  ),
                  const SizedBox(height: GS.s3),
                  Text(
                    canReload
                        ? 'Обычно так бывает, когда браузер открыл игру из '
                            'своей памяти. Обнови её — перезагрузи страницу.'
                        : 'Обнови игру — поставь свежую версию, гараж '
                            'откроется в ней.',
                    style: GType.body().copyWith(color: GColors.textHi),
                  ),
                  if (canReload) ...[
                    const SizedBox(height: GS.s6),
                    _PrimaryButton(label: 'ПЕРЕЗАГРУЗИТЬ', onTap: onReload),
                    const SizedBox(height: GS.s3),
                    // Первая перезагрузка может снова достать старую версию:
                    // новая докачивается в фоне и встаёт со следующего раза.
                    Text(
                      'Окно вернулось — подожди минуту и перезагрузи ещё раз: '
                      'новая версия докачивается.',
                      style: GType.body().copyWith(color: GColors.textLo),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Сейв не читается» — гараж начат заново, строка отложена.
///
/// [kept] — легла ли копия (см. `SaveService.rescue`). Если нет, «отложено»
/// говорить нельзя: остаётся только скопировать строку сейчас.
Future<void> showBrokenSaveNotice(
  BuildContext context, {
  required String save,
  required bool kept,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xCC0B0806),
    builder: (context) => _BrokenSaveNotice(save: save, kept: kept),
  );
}

class _BrokenSaveNotice extends StatefulWidget {
  final String save;
  final bool kept;

  const _BrokenSaveNotice({required this.save, required this.kept});

  @override
  State<_BrokenSaveNotice> createState() => _BrokenSaveNoticeState();
}

class _BrokenSaveNoticeState extends State<_BrokenSaveNotice> {
  bool _copied = false;

  /// Браузер не дал буфер обмена — строка показывается целиком, выделить
  /// руками. Отказ бывает во встроенных браузерах мессенджеров и во вкладке
  /// без фокуса; промолчать о нём — то же, что не дать скопировать.
  bool _manual = false;

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.save));
    } catch (_) {
      if (mounted) setState(() => _manual = true);
      return;
    }
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Текст длинный, а экран бывает 320×640 с крупным шрифтом: кнопки не
      // должны уехать за край.
      scrollable: true,
      backgroundColor: GColors.surface1,
      title: Text('Сейв не читается',
          style: GType.ui(size: 17, weight: FontWeight.w600)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сохранение повредилось, и игра не смогла его прочитать. Гараж '
              'начинается заново.',
              style: GType.body(),
            ),
            const SizedBox(height: GS.s3),
            Text(
              widget.kept
                  ? 'Старый сейв отложен отдельно и не сотрётся. Если новая '
                      'версия игры сможет его прочитать, она сама предложит '
                      'вернуть гараж.'
                  : 'Отложить старый сейв не вышло. Скопируй его сейчас — '
                      'потом его уже не будет.',
              style: GType.body().copyWith(
                color: widget.kept ? GColors.textMid : GColors.amber,
              ),
            ),
            const SizedBox(height: GS.s3),
            Text(
              'Пришли его разработчику: по нему видно, что сломалось.',
              style: GType.body(),
            ),
            if (_copied) ...[
              const SizedBox(height: GS.s3),
              Text('Скопировано. Отправь в сообщения.',
                  style: GType.body().copyWith(color: GColors.green)),
            ],
            if (_manual) ...[
              const SizedBox(height: GS.s3),
              Text(
                'Браузер не дал скопировать сам. Выдели текст целиком.',
                style: GType.body().copyWith(color: GColors.amber),
              ),
              const SizedBox(height: GS.s2),
              _RawSave(save: widget.save),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _copy,
          child: Text('Скопировать', style: GType.body()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Понятно', style: GType.body()),
        ),
      ],
    );
  }
}

/// Строка сейва целиком — выделить и скопировать руками.
class _RawSave extends StatelessWidget {
  final String save;
  const _RawSave({required this.save});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      padding: const EdgeInsets.all(GS.s2),
      decoration: BoxDecoration(
        color: GColors.wellBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GColors.border),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          save,
          style: GType.num(size: 11, color: GColors.textMid),
        ),
      ),
    );
  }
}

/// «Старый гараж нашёлся» — отложенная копия теперь читается.
///
/// `true` — игрок выбрал вернуть. Нынешний гараж при этом пропадает, поэтому
/// рядом стоят оба итога: решать вслепую нельзя. `false` — оставить
/// нынешний; копия тогда выбрасывается, иначе вопрос повторялся бы на
/// каждом запуске.
Future<bool> offerRescuedGarage(
  BuildContext context, {
  required GameState copy,
  required GameState current,
}) async {
  final restore = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xCC0B0806),
    builder: (context) => AlertDialog(
      scrollable: true,
      backgroundColor: GColors.surface1,
      title: Text('Старый гараж нашёлся',
          style: GType.ui(size: 17, weight: FontWeight.w600)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сейв, который раньше не читался, теперь открывается. Вернуть '
              'тот гараж? Нынешний тогда пропадёт.',
              style: GType.body(),
            ),
            const SizedBox(height: GS.s3),
            _Garage(label: 'СТАРЫЙ', state: copy),
            const SizedBox(height: GS.s2),
            _Garage(label: 'НЫНЕШНИЙ', state: current),
            const SizedBox(height: GS.s3),
            Text(
              'Оставишь нынешний — копия старого выбросится.',
              style: GType.body(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Оставить нынешний', style: GType.body()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Вернуть старый',
              style: GType.body().copyWith(color: GColors.amber)),
        ),
      ],
    ),
  );
  return restore ?? false;
}

/// Итог гаража одной строкой — чтобы сравнить старый с нынешним.
class _Garage extends StatelessWidget {
  final String label;
  final GameState state;

  const _Garage({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final wisdom = state.prestige.wisdom;
    // Подпись над числом, а не слева: на 320 точках строка в одну линию
    // переносила число на середине.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: GS.s3, vertical: GS.s2),
      decoration: BoxDecoration(
        color: GColors.wellBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GType.label()),
          const SizedBox(height: 2),
          Text(
            // Нагнанное за всё время — главный итог: из него растёт
            // мудрость, и его игрок узнаёт по статистике.
            'нагнано ${Fmt.volume(state.prestige.totalEverEarned)}'
            '${wisdom > 0 ? ' · мудрость $wisdom' : ''}',
            style: GType.num(size: 13, color: GColors.textHi),
          ),
        ],
      ),
    );
  }
}

/// Главная кнопка — как на экране «что изменилось».
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: GColors.amber,
          borderRadius: BorderRadius.circular(GR.pill),
        ),
        child: Text(
          label,
          style: GType.ui(
            size: 14,
            weight: FontWeight.w700,
            color: GColors.onAmber,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
