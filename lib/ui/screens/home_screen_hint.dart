/// «Поставь на экран Домой» — подсказка на iPhone во вкладке браузера.
///
/// Кому и почему — в `core/home_screen.dart`. Здесь только слова: как
/// поставить, зачем и почему сейчас. Их мало, потому что экран один раз и до
/// игры, и влезть он обязан в 320×640.
library;

import 'package:flutter/material.dart';

import '../theme/garage.dart';

Future<void> showHomeScreenHint(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xCC0B0806),
    builder: (context) => const HomeScreenHint(),
  );
}

class HomeScreenHint extends StatelessWidget {
  const HomeScreenHint({super.key});

  @override
  Widget build(BuildContext context) {
    final strong = GType.body().copyWith(
      color: GColors.textHi,
      fontWeight: FontWeight.w600,
    );
    return AlertDialog(
      backgroundColor: GColors.surface1,
      // Крупный шрифт в настройках телефона не должен уносить кнопку за
      // край экрана.
      scrollable: true,
      title: Text('Поставь игру на экран «Домой»',
          style: GType.ui(size: 17, weight: FontWeight.w600)),
      // Ширина — как у колонки игры, см. test_save_notice.dart.
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Text.rich(
          TextSpan(
            style: GType.body(),
            children: [
              TextSpan(
                text: 'Safari → «Поделиться» → «На экран Домой».',
                style: strong,
              ),
              const TextSpan(
                text: '\n\nВо вкладке Safari iPhone стирает прогресс, если '
                    'неделю не заходить в игру. С иконки — нет.'
                    '\n\nСтавь сейчас: у иконки своё хранилище, и прогресс '
                    'из Safari туда сам не переедет. Уже играл здесь — '
                    'перенеси его кодом: вкладка «Витя», ',
              ),
              TextSpan(text: 'ПЕРЕНОС ПРОГРЕССА', style: strong),
              const TextSpan(text: '.'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Понятно', style: GType.body()),
        ),
      ],
    );
  }
}
