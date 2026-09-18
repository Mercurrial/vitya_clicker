@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';
import 'package:idle_game/ui/theme/garage.dart';

import 'support/moments.dart';

/// Снимок всего экрана, а не отдельного виджета.
///
/// Плейтест жаловался на обрезанную вёрстку, а проверить это можно только
/// глазами и только целиком: по отдельности все блоки помещаются.
///
/// На снимке две вещи выглядят «сломанными», но сломанными не являются:
/// текст — квадратиками (в тестах шрифт подменяется на Ahem) и портрет —
/// ровной заливкой (фотография декодируется асинхронно, а тестовый кадр её
/// не ждёт). Настоящую заливку портрета ловит pixel_portrait_test.dart —
/// именно этой ошибкой он и вызван к жизни.
///
/// Запуск:
///   flutter test --tags golden --run-skipped --update-goldens
GameState _stateWith({required int banki, required double money}) {
  var state = newGame(
    content: kGenerators,
    upgrades: kUpgrades,
    now: DateTime.utc(2026),
  );
  final items = [
    for (final g in state.generators.items)
      g.id == 'banka' ? g.copyWith(ownedCount: banki) : g,
  ];
  return state.copyWith(
    generators: state.generators.copyWith(items: items),
    resources: state.resources.copyWith(money: money, ml: 640),
  );
}

void main() {
  /// Часы подменяются намеренно: от них зависит и цена на рынке, и то, стоит
  /// ли в гараже гость. См. `test/support/moments.dart`.
  Future<void> open(WidgetTester tester, DateTime now) async {
    // Размер средней «рабочей лошадки»: на ней вёрстка и жаловалась.
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialStateProvider
              .overrideWithValue(_stateWith(banki: 7, money: 1840)),
          timeProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: GColors.bg,
            fontFamily: GType.uiFamily,
            useMaterial3: true,
          ),
          home: const Scaffold(
            backgroundColor: GColors.bg,
            body: GarageScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('гараж целиком помещается на экране телефона', (tester) async {
    await open(tester, quietMoment);

    // Снимок делается ДО проверки на исключения намеренно: переполнение
    // Flutter рисует жёлто-чёрной полосой, и по картинке сразу видно, какой
    // именно блок вылез. Проверка идёт следом и всё равно валит тест.
    await expectLater(
      find.byType(GarageScreen),
      matchesGoldenFile('goldens/screen_garage.png'),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('с гостем в гараже верхняя панель не разъезжается',
      (tester) async {
    // Второй покупатель — единственное, что может появиться на экране само,
    // без действий игрока. Поэтому у него свой снимок.
    await open(tester, eventMoment);

    await expectLater(
      find.byType(GarageScreen),
      matchesGoldenFile('goldens/screen_garage_event.png'),
    );

    expect(tester.takeException(), isNull);
  });
}
