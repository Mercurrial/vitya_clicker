@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/engine/game_engine.dart';
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
/// Шрифты настоящие, а не Ahem. Раньше текст на этих снимках был
/// квадратиками, и по ним нельзя было понять главного — сколько чего видно
/// на экране. Теперь по снимкам шторки владелец принимает главный экран
/// (docs/DECISIONS.md, «Главный экран»).
///
/// Портрет на снимке — ровной заливкой: фотография декодируется асинхронно,
/// а тестовый кадр её не ждёт. Настоящую заливку портрета ловит
/// pixel_portrait_test.dart — именно этой ошибкой он и вызван к жизни.
///
/// Запуск:
///   flutter test --tags golden --run-skipped --update-goldens
///
/// Цели, до которых такой гараж уже дорос, взяты заранее, а сейв записан в
/// ту же минуту, что и снимок: иначе первый тик наливал бы бак за месяцы
/// оффлайна, открывал цели пачкой, и на снимок попадала плашка «цель взята».
GameState _stateWith({
  required int banki,
  required double money,
  required DateTime now,
  double flux = 0,
}) {
  var state = newGame(
    content: kGenerators,
    upgrades: kUpgrades,
    now: now,
  );
  final items = [
    for (final g in state.generators.items)
      g.id == 'banka' ? g.copyWith(ownedCount: banki) : g,
  ];
  state = state.copyWith(
    generators: state.generators.copyWith(items: items),
    resources: state.resources.copyWith(money: money, ml: 640),
    flux: state.flux.copyWith(seconds: flux),
  );
  return const GameEngine().checkAchievements(state).state;
}

void main() {
  setUpAll(() async {
    const fonts = {
      GType.uiFamily: ['Rubik-Variable.ttf'],
      GType.numFamily: [
        'IBMPlexMono-Regular.ttf',
        'IBMPlexMono-Medium.ttf',
        'IBMPlexMono-SemiBold.ttf',
        'IBMPlexMono-Bold.ttf',
      ],
    };
    for (final MapEntry(key: family, value: files) in fonts.entries) {
      final loader = FontLoader(family);
      for (final file in files) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
  });

  /// Часы подменяются намеренно: от них зависит и цена на рынке, и то, стоит
  /// ли в гараже гость. См. `test/support/moments.dart`.
  Future<void> open(WidgetTester tester, DateTime now, Size size, {double flux = 0}) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialStateProvider
              .overrideWithValue(_stateWith(banki: 7, money: 840, now: now, flux: flux)),
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

  /// Развернуть магазин и дать шторке доехать.
  Future<void> expand(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('shelf-grabber')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  // 390×844 — средняя «рабочая лошадка», на ней вёрстка и жаловалась;
  // 390×740 — телефон владельца: Android, Chrome с адресной строкой.
  for (final (size, name) in const [
    (Size(390, 844), '844'),
    (Size(390, 740), '740'),
  ]) {
    testWidgets('гараж целиком помещается на экране ${size.width.toInt()}×$name',
        (tester) async {
      await open(tester, quietMoment, size);

      // Снимок делается ДО проверки на исключения намеренно: переполнение
      // Flutter рисует жёлто-чёрной полосой, и по картинке сразу видно, какой
      // именно блок вылез. Проверка идёт следом и всё равно валит тест.
      await expectLater(
        find.byType(GarageScreen),
        matchesGoldenFile('goldens/screen_garage_$name.png'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('развёрнутый магазин на ${size.width.toInt()}×$name',
        (tester) async {
      await open(tester, quietMoment, size);
      await expand(tester);

      await expectLater(
        find.byType(GarageScreen),
        matchesGoldenFile('goldens/screen_shop_$name.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('с гостем в гараже верхняя панель не разъезжается',
      (tester) async {
    // Второй покупатель — единственное, что может появиться на экране само,
    // без действий игрока. Поэтому у него свой снимок.
    await open(tester, eventMoment, const Size(390, 844));

    await expectLater(
      find.byType(GarageScreen),
      matchesGoldenFile('goldens/screen_garage_event.png'),
    );

    expect(tester.takeException(), isNull);
  });

  // Поток: кнопка ускорения рядом с пультом и вкладка потока. По этим
  // снимкам смотрится, что кнопка не отняла у магазина строку.
  for (final (size, name) in const [
    (Size(390, 844), '844'),
    (Size(320, 640), '640'),
  ]) {
    testWidgets('кнопка ускорения на ${size.width.toInt()}×$name', (tester) async {
      await open(tester, quietMoment, size, flux: 42 * 60);
      await expectLater(
        find.byType(GarageScreen),
        matchesGoldenFile('goldens/screen_flux_button_$name.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('вкладка потока на 390×844', (tester) async {
    await open(tester, quietMoment, const Size(390, 844), flux: 42 * 60);
    await expand(tester);
    await tester.tap(find.text('ПОТОК'));
    // Два кадра: на первом подложка вкладки только трогается с места.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(GarageScreen),
      matchesGoldenFile('goldens/screen_flux_tab.png'),
    );
    expect(tester.takeException(), isNull);
  });
}
