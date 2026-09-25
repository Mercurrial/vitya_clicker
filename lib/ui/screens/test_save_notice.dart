/// «Это выпуск» — объяснение пустого гаража у того, кто играл в тестовую
/// сборку.
///
/// До 1.0.0 игра раздавалась своим, и владелец решил, что выпуск начинает
/// с нуля у всех (docs/DECISIONS.md, «Чистый старт»). Тестовый сейв не
/// читается, но молча показать пустой гараж нельзя: игрок решит, что
/// прогресс потерян из-за поломки, и будет прав в своём недоверии.
library;

import 'package:flutter/material.dart';

import '../theme/garage.dart';

Future<void> showTestSaveNotice(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xCC0B0806),
    builder: (context) => AlertDialog(
      backgroundColor: GColors.surface1,
      title: Text('Гараж с чистого листа',
          style: GType.ui(size: 17, weight: FontWeight.w600)),
      // Ширина — как у колонки игры: на широком экране длинная строка
      // растягивала окно на всю вкладку браузера.
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Text(
          'Ты играл в тестовую версию. Это первый выпуск, и прогресс тестовой '
          'версии в него не переносится — гараж начинается заново. Звук и '
          'вибрация остались как были.',
          style: GType.body(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Понятно', style: GType.body()),
        ),
      ],
    ),
  );
}
