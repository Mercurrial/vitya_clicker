@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/models/prestige_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/screens/wisdom_tab.dart';
import 'package:idle_game/ui/theme/garage.dart';

import 'support/moments.dart';

/// Снимок вкладки «МУДРОСТЬ» в середине игры: часть вех взята, следующая
/// выделена, сон откроет ещё одну. Высота — на всю дорожку: вкладку смотрят
/// целиком, а не первый экран.
///
/// Шрифты настоящие: на Ahem не видно, влезает ли описание вехи в строку.
///
/// Переснимается только в CI (docs/DECISIONS.md, «Процесс»):
///   gh workflow run goldens.yml --ref <ветка>
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

  testWidgets('мудрость и дорожка вех', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 1900)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 21 мудрость забрана, нагнано ещё на две — сон откроет веху на 22.
    final first = PrestigeState.firstWisdomMl;
    var state = newGame(content: kGenerators, upgrades: kUpgrades, now: quietMoment);
    state = state.copyWith(
      prestige: state.prestige.copyWith(
        claimedMl: first * ((1 << 21) - 1),
        totalEverEarned: first * ((1 << 23) - 1) * 1.0001,
        hangovers: 8,
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
        home: const Scaffold(body: WisdomTab()),
      ),
    ));

    await expectLater(find.byType(WisdomTab), matchesGoldenFile('goldens/wisdom_tab.png'));
    expect(tester.takeException(), isNull);
  });
}
