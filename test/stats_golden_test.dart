@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/models/stats_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/theme/garage.dart';
import 'package:idle_game/ui/widgets/stats_panel.dart';

import 'support/moments.dart';

/// Снимок панели статистики на самом узком экране.
///
/// Шрифты настоящие, а не Ahem: панель — это двадцать строк текста, и по
/// квадратикам не видно ни переносов, ни того, влезло ли значение рядом с
/// подписью. Числа — как у игрока после пары недель: не круглые и разной
/// длины.
///
/// Запуск:
///   flutter test --tags golden --run-skipped --update-goldens
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

  testWidgets('статистика на 320 точках', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final start = quietMoment.subtract(const Duration(days: 12, hours: 5));
    var state = newGame(content: kGenerators, upgrades: kUpgrades, now: quietMoment);
    state = state.copyWith(
      clicker: state.clicker.copyWith(totalTaps: 1873),
      prestige: state.prestige.copyWith(totalEverEarned: 8.4e9, hangovers: 3),
      stats: StatsState(
        firstLaunch: start,
        runStart: start,
        playSeconds: 14 * 3600 + 20 * 60,
        holdSeconds: 6 * 3600 + 2 * 60,
        windowSeconds: 3 * 3600 + 41 * 60,
        soldMl: 1.24e7,
        earned: 3.2e6,
        sales: 240,
        bestSale: 410e3,
        guestSales: 9,
        stillsBought: 1107,
        upgradesBought: 58,
        fastestRunSeconds: 3600 + 48 * 60,
      ),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        initialStateProvider.overrideWithValue(state),
        timeProvider.overrideWithValue(() => quietMoment),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: GColors.bg,
          fontFamily: GType.uiFamily,
          useMaterial3: true,
        ),
        // Отступы — как у списка на вкладке «Витя».
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(GS.s4),
            child: StatsPanel(),
          ),
        ),
      ),
    ));

    await expectLater(
      find.byType(StatsPanel),
      matchesGoldenFile('goldens/stats_panel.png'),
    );
    expect(tester.takeException(), isNull);
  });
}
