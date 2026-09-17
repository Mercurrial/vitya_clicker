@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/balance.dart';
import 'package:idle_game/ui/screens/balance_news.dart';
import 'package:idle_game/ui/theme/garage.dart';

/// Снимок экрана «что изменилось».
///
/// Этот экран игрок увидит ровно один раз за выпуск и именно в тот момент,
/// когда решает, не сломалась ли игра. Проверять его вёрстку глазами
/// обязательно: второго шанса объясниться не будет.
void main() {
  testWidgets('что изменилось: список и компенсация', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 700)
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
                onPressed: () => showBalanceNews(context, kBalanceLog),
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
      matchesGoldenFile('goldens/balance_news.png'),
    );
  });
}
