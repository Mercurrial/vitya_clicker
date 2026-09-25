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
///
/// Журнал подставной: в выпуске 1.0.0 запись одна, а вёрстку надо видеть на
/// худшем случае — несколько выпусков, ослабление и компенсация.
void main() {
  const releases = [
    BalanceRelease(
      version: 2,
      title: 'Гараж перебрали',
      isNerf: true,
      compensationWisdom: 3,
      changes: [
        'Аппараты дорожают быстрее. Раньше десятый по счёту стоил как второй, '
            'и через пять минут покупать было уже нечего.',
        'До первой мудрости теперь дальше: похмелье наступало слишком рано '
            'и обесценивало всё, что было до него.',
        'За перетряску — три мудрости сверху. Извини.',
      ],
    ),
    BalanceRelease(
      version: 3,
      title: 'Бак побольше',
      changes: [
        'В бак влезает вдвое больше, и продавать можно реже. Кто играет '
            'урывками, теряет меньше.',
        'Петрович платит по рынку чуть щедрее, когда сорт хороший.',
      ],
    ),
    BalanceRelease(
      version: 4,
      title: 'Мудрость ценнее',
      isNerf: true,
      compensationWisdom: 2,
      changes: [
        'До первой мудрости дальше, зато она удваивает всё производство, а '
            'каждая следующая прибавляет ещё половину.',
        'За ожидание — две мудрости сверху.',
      ],
    ),
  ];

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
                onPressed: () => showBalanceNews(context, releases),
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
