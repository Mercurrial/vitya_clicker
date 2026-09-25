import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/core/bootstrap.dart';
import 'package:idle_game/core/game_clock.dart';
import 'package:idle_game/core/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/moments.dart';

/// Чистый старт выпуска 1.0.0.
///
/// До выпуска игра раздавалась своим, и владелец решил, что выпуск у всех
/// начинается заново (docs/DECISIONS.md, «Чистый старт»). Проверяется
/// настоящий запуск поверх настоящего хранилища: тестовый сейв не читается,
/// но игроку говорят почему; обучение начинается сначала; звук и вибрация —
/// как были.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final clock = GameClock(now: () => quietMoment);

  // Так хранилище выглядело у того, кто играл в тестовую сборку: сейв v5
  // под старым ключом, пройденное обучение, выключенный звук.
  final testBuild = <String, Object>{
    'vitya_save_v1': '{"version": 5, "ml": 0, "money": 5000000, '
        '"lifetime": 8400000000, "claimedMl": 0, "stills": {"banka": 30}, '
        '"balanceVersion": 7, "lastSeen": 1780000000000}',
    'vitya_setting_tutorial_step': 'sell',
    'vitya_setting_sound': 'off',
    'vitya_setting_haptics': 'off',
  };

  test('сейв тестовой сборки даёт чистый гараж и объяснение', () async {
    SharedPreferences.setMockInitialValues(testBuild);
    final boot = await bootstrapGame(clock: clock);

    expect(boot.testSaveDropped, isTrue,
        reason: 'пустой гараж без объяснения читается как потеря прогресса');
    expect(boot.saveWasLost, isFalse,
        reason: 'это решение, а не порча сейва');
    expect(boot.state.resources.money, 0);
    expect(boot.state.prestige.totalEverEarned, 0);
    expect(
      boot.state.generators.items.firstWhere((g) => g.id == 'banka').ownedCount,
      lessThan(30),
      reason: 'аппараты тестовой сборки не переехали',
    );
    expect(boot.hasBalanceNews, isFalse,
        reason: 'журнал тестовых сборок новичку показывать незачем');
  });

  test('обучение — с начала, звук и вибрация — как были', () async {
    SharedPreferences.setMockInitialValues(testBuild);
    final boot = await bootstrapGame(clock: clock);

    expect(boot.settings.read(SettingsKeys.tutorial), isNull,
        reason: 'новый гараж без подсказок был бы странным');
    expect(boot.settings.read(SettingsKeys.sound), 'off');
    expect(boot.settings.read(SettingsKeys.haptics), 'off');
  });

  test('после первого сохранения объяснение не повторяется', () async {
    SharedPreferences.setMockInitialValues(testBuild);
    final first = await bootstrapGame(clock: clock);
    await first.saves.save({'ml': 42.0, 'lastSeen': 1});

    final second = await bootstrapGame(clock: clock);
    expect(second.testSaveDropped, isFalse);
    expect(second.state.resources.ml, greaterThan(0),
        reason: 'свой сейв выпуска читается как обычно');
  });

  test('у нового игрока объяснения нет', () async {
    SharedPreferences.setMockInitialValues({});
    final boot = await bootstrapGame(clock: clock);
    expect(boot.testSaveDropped, isFalse);
    expect(boot.saveWasLost, isFalse);
  });
}
