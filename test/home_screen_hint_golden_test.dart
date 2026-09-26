@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/ui/screens/home_screen_hint.dart';
import 'package:idle_game/ui/theme/garage.dart';

/// Снимок подсказки «поставь на экран Домой».
///
/// Её видят один раз, до игры, и на самом узком экране, какой поддерживаем, —
/// 320×640. Переносы строк на нём и решают, читается ли путь «Поделиться,
/// затем На экран Домой» одним взглядом. Смотреть и на буквы: символа, которого
/// нет в шрифте, тест без снимка не заметит — так в подсказку попала «→».
void main() {
  testWidgets('подсказка «на экран Домой» на 320×640', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: GType.uiFamily,
          useMaterial3: true,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: GColors.bg,
            body: Center(
              child: ElevatedButton(
                onPressed: () => showHomeScreenHint(context),
                child: const Text('открыть'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Dialog),
      matchesGoldenFile('goldens/home_screen_hint.png'),
    );
  });
}
